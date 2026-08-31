class_name MapBase
extends Node2D
## 通用地图基类：瓦片构建、玩家、暗雷遇敌、传送门、剧情触发器、精英、篝火、HUD。
##
## 子类覆盖 map_rows / start_cell / encounter_table / elite_spawns，
## 并在 setup_triggers 中用 add_trigger / add_portal / add_campfire 搭建内容。
## 剧情事件见 src/story/story_events.gd（由旗标驱动，可重入）。

const TILE := 32
const CHUNK := 10  # 每段字符串的格数

const PLAYER_SCENE := preload("res://src/world/player/player.tscn")
const CAMPFIRE_SCRIPT := preload("res://src/world/campfire.gd")
const NPC_SCRIPT := preload("res://src/world/npc.gd")
const FOLLOWER_SCRIPT := preload("res://src/world/follower.gd")
const BATTLE_SCENE := "res://src/battle/battle.tscn"

## 成员 id → 地图跟随立绘（战斗立绘同源；新增成员时在此登记）。
const MEMBER_TEXTURES := {
	"mo_fan": "res://assets/images/char_mofan.png",
	"mu_ningxue": "res://assets/images/char_muningxue.png",
}

# tiles_proto.png 的 6 格横向图块。
const T_GRASS := Vector2i(0, 0)
const T_TALL := Vector2i(1, 0)
const T_PATH := Vector2i(2, 0)
const T_TREE := Vector2i(3, 0)
const T_ROCK := Vector2i(4, 0)
const T_WATER := Vector2i(5, 0)

var player: CharacterBody2D
var tilemap: TileMapLayer
var followers: Array[Node2D] = []

var _triggers: Array[Dictionary] = []  # {cell, radius, event}
var _portals: Array[Dictionary] = []   # {cell, target, spawn}
var _npcs: Array[Dictionary] = []      # {cell, texture, name, hide_flag, event}
var _npc_nodes: Array[Area2D] = []     # 已生成的 NPC 实体（部分注册项可能未生成）
var _event_running := false
var _encounter_gauge := 0.0
var _encounter_threshold := 200.0
var _cooling := true
var _menu: Control = null
var _menu_result: Label = null
var _wealth_label: Label
var _objective_label: Label
var _hud: CanvasLayer


func _ready() -> void:
	_build_tilemap()
	_spawn_player()
	_build_content()
	_build_hud()
	_apply_entry_position()
	GameEvents.party_status_changed.connect(_refresh_hud)
	GameEvents.party_status_changed.connect(_sync_followers)
	_refresh_hud()
	Audio.play_bgm(bgm_name())


## —— 子类接口 ——

## 地图 BGM 名（Audio.BGM 的键；"" 为静默）。
func bgm_name() -> String:
	return ""


func map_rows() -> Array:
	return []


func map_size() -> Vector2i:
	var rows := map_rows()
	return Vector2i(CHUNK * 4, rows.size() / 4)


func start_cell() -> Vector2i:
	return Vector2i(2, 2)


## 空 = 城镇，无暗雷。
func encounter_table() -> Array:
	return []


## [{cell, flag, ids}]
func elite_spawns() -> Array:
	return []


func setup_triggers() -> void:
	pass


func _build_content() -> void:
	setup_triggers()
	for e in elite_spawns():
		if not GameState.flags.get(e["flag"], false):
			_spawn_elite(e)
	for n in _npcs:
		if not GameState.flags.get(n["hide_flag"], false):
			_spawn_npc(n)


## —— 给子类/剧情用的注册与辅助 API ——

func add_trigger(cell: Vector2i, radius: float, event: Callable) -> void:
	_triggers.append({"cell": cell, "radius": radius, "event": event})


## 注册剧情 NPC：hide_flag 点亮后不再出现（人物退场）。
func add_npc(cell: Vector2i, texture: String, display_name: String, hide_flag: String, event: Callable) -> void:
	_npcs.append({"cell": cell, "texture": texture, "name": display_name, "hide_flag": hide_flag, "event": event})


## 注册商人 NPC：按 E 打开商店（常驻，不随旗标退场）。
func add_merchant(cell: Vector2i, texture: String, display_name: String, wares: Array) -> void:
	_npcs.append({"cell": cell, "texture": texture, "name": display_name, "hide_flag": "", "wares": wares})


func add_portal(cell: Vector2i, target_scene: String, spawn_cell: Vector2i) -> void:
	_portals.append({"cell": cell, "target": target_scene, "spawn": spawn_cell})


func add_campfire(cell: Vector2i) -> void:
	var fire: Area2D = CAMPFIRE_SCRIPT.new()
	fire.position = _cell_center(cell)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	fire.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/images/campfire.png")
	sprite.position = Vector2(0, -4)
	fire.add_child(sprite)
	fire.camp_used.connect(_open_rest_menu)
	add_child(fire)


func flag(f: String) -> bool:
	return GameState.flags.get(f, false)


func set_flag(f: String) -> void:
	GameState.flags[f] = true


func lock_player() -> void:
	player.input_enabled = false


func unlock_player() -> void:
	player.input_enabled = true


func start_story_battle(ids: Array, win_flag: String) -> void:
	_start_encounter(ids, win_flag, true)


func warp(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func run_event(event: Callable) -> void:
	if _event_running:
		return
	_event_running = true
	player.input_enabled = false
	await event.call()
	if is_instance_valid(player):
		player.input_enabled = true
	_event_running = false
	_retire_npcs()


## 事件收尾统一退场检查：hide_flag 已点亮的 NPC 当场离场。
## 挂在 run_event 收尾（所有剧情路径的共用层），无论走动触发还是按 E 触发都生效。
func _retire_npcs() -> void:
	for node in _npc_nodes.duplicate():
		if is_instance_valid(node) and GameState.flags.get(node.hide_flag, false):
			_npc_nodes.erase(node)
			node.queue_free()


## —— 地图构建 ——

func _cell_char(cell: Vector2i) -> String:
	var rows := map_rows()
	# 每 4 段为一个地图行；rows.size() 为 4 的倍数，整除即地图行数
	if cell.x < 0 or cell.y < 0 or cell.y >= rows.size() / 4:
		return "T"
	var row: String = rows[cell.y * 4 + int(cell.x / float(CHUNK))]
	if cell.x % CHUNK >= row.length():
		return "T"
	return row[cell.x % CHUNK]


func _build_tilemap() -> void:
	var size := map_size()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/images/tiles_proto.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in 6:
		src.create_tile(Vector2i(i, 0))
	# 先挂到 TileSet（图块数据才知道有几个物理层），再配置碰撞。
	ts.add_source(src, 0)
	for blocked in [T_TREE, T_ROCK, T_WATER]:
		var td := src.get_tile_data(blocked, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
		]))
	tilemap = TileMapLayer.new()
	tilemap.tile_set = ts
	add_child(tilemap)
	for y in size.y:
		for x in size.x:
			var coords := T_GRASS
			match _cell_char(Vector2i(x, y)):
				"H": coords = T_TALL
				"P": coords = T_PATH
				"T": coords = T_TREE
				"R": coords = T_ROCK
				"W": coords = T_WATER
			tilemap.set_cell(Vector2i(x, y), 0, coords)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	var cell := start_cell()
	if GameState.next_spawn != Vector2i(-1, -1):
		cell = GameState.next_spawn
		GameState.next_spawn = Vector2i(-1, -1)
	player.position = _cell_center(cell)
	add_child(player)
	player.moved.connect(_on_player_moved)
	var cam: Camera2D = player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_top = 0
	var size := map_size()
	cam.limit_right = size.x * TILE
	cam.limit_bottom = size.y * TILE


## 入场处理：战斗返回位置 → 队伍跟随 → 剧情触发检查 → 解除操作冷却。
func _apply_entry_position() -> void:
	if GameState.has_return_position:
		player.global_position = GameState.return_position
		GameState.has_return_position = false
	_sync_followers()
	await get_tree().create_timer(0.2).timeout
	for t in _triggers:
		if player.global_position.distance_to(_cell_center(t["cell"])) <= float(t["radius"]):
			run_event(t["event"])
			break
	await get_tree().create_timer(1.0).timeout
	_cooling = false
	player.input_enabled = true


## 队伍跟随：除首位（玩家操控）外的成员以跟随者链式登场。
## 挂在 party_status_changed 上增量同步——入队当刻即登场，无需换图；
## 信号高频触发（休息/修炼等），故只补缺不重建，已站位的跟随者不被重置。
func _sync_followers() -> void:
	var prev: Node2D = player
	if not followers.is_empty():
		prev = followers.back()
	while followers.size() < GameState.party.size() - 1:
		var m: CharacterState = GameState.party[followers.size() + 1]
		var follower: Node2D = FOLLOWER_SCRIPT.new()
		follower.texture = load(MEMBER_TEXTURES.get(m.id, MEMBER_TEXTURES["mo_fan"]))
		follower.target = prev
		follower.position = prev.position
		add_child(follower)
		follower.prime(Vector2(-FOLLOWER_SCRIPT.GAP, 0))  # 侧后方站定，不与主角重叠
		followers.append(follower)
		prev = follower


## 剧情 NPC 实体：退场统一由 _retire_npcs 在事件收尾处理。
## 带 wares 的为商人：按 E 直接打开商店（不走 run_event，商店自管输入锁）。
func _spawn_npc(n: Dictionary) -> void:
	var npc: Area2D = NPC_SCRIPT.new()
	npc.position = _cell_center(n["cell"])
	npc.display_name = n["name"]
	npc.hide_flag = n["hide_flag"]
	if n.has("wares"):
		npc.event = func() -> void: _open_shop(n["wares"])
	else:
		npc.event = func() -> void: run_event(n["event"])
	add_child(npc)
	_npc_nodes.append(npc)


func _spawn_elite(e: Dictionary) -> void:
	var area := Area2D.new()
	area.position = _cell_center(e["cell"])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	shape.shape = rect
	area.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/images/monster_wolf.png")
	sprite.scale = Vector2(1.5, 1.5)
	area.add_child(sprite)
	area.body_entered.connect(func(_body: Node2D) -> void:
		if not GameState.flags.get(e["flag"], false):
			_start_encounter(e["ids"], e["flag"])
	)
	add_child(area)


## —— 遇敌与传送 ——

func _on_player_moved(distance: float) -> void:
	if _cooling or _menu != null or _event_running:
		return
	var cell := tilemap.local_to_map(tilemap.to_local(player.global_position))
	# 传送门
	for p in _portals:
		if cell == p["cell"]:
			GameState.next_spawn = p["spawn"]
			get_tree().change_scene_to_file(p["target"])
			return
	# 剧情触发器（走近即演；事件内部自带旗标守卫，可安全重入）
	for t in _triggers:
		if player.global_position.distance_to(_cell_center(t["cell"])) <= float(t["radius"]):
			run_event(t["event"])
			return
	# 暗雷
	var table := encounter_table()
	if table.is_empty():
		return
	if _cell_char(cell) == "H":
		_encounter_gauge += distance
	else:
		_encounter_gauge = maxf(_encounter_gauge - distance * 0.6, 0.0)
	if _encounter_gauge >= _encounter_threshold:
		_encounter_gauge = 0.0
		_encounter_threshold = randf_range(160.0, 280.0)
		_start_encounter(_pick_encounter(table), "")


func _pick_encounter(table: Array) -> Array:
	var total := 0
	for e in table:
		total += e["weight"]
	var roll := randi_range(1, total)
	for e in table:
		roll -= e["weight"]
		if roll <= 0:
			return e["ids"]
	return table[0]["ids"]


## 遇敌入口。from_event=true 表示由剧情事件内部发起（教学战等）：
## 此时正处于 run_event 互斥中，必须绕过事件守卫，否则剧情战永远开不出来。
## 随机遭遇与明雷精英仍受守卫约束（演出中/菜单中不乱入）。
func _start_encounter(ids: Array, win_flag: String, from_event := false) -> void:
	if _encounter_blocked(from_event):
		return
	Audio.play_sfx("encounter")
	_cooling = true
	player.input_enabled = false
	GameState.return_position = player.global_position
	GameState.has_return_position = true
	GameState.pending_enemies = ids
	GameState.pending_flag = win_flag
	GameState.battle_return_scene = scene_file_path
	GameEvents.encounter_started.emit(ids)
	get_tree().change_scene_to_file(BATTLE_SCENE)


## 遭遇是否应被拦下：随机/精英遭遇在演出中或菜单中拦下；剧情战（事件内部发起）放行。
func _encounter_blocked(from_event: bool) -> bool:
	return not from_event and (_event_running or _menu != null)


## —— HUD ——

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for m in GameState.party:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		m.set_meta("hud_label", label.get_instance_id())
	_hud.add_child(panel)

	var hint := Label.new()
	hint.text = "WASD/方向键 移动 · E 交互 · I/Tab 背包 · Esc 关闭菜单 · 深草区遇敌 · 篝火处休息/修炼/突破/存档"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	hint.position = Vector2(12, get_viewport_rect().size.y - 34)
	_hud.add_child(hint)

	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 14)
	_objective_label.add_theme_color_override("font_color", Color("ffd166"))
	_objective_label.position = Vector2(12, get_viewport_rect().size.y - 58)
	_hud.add_child(_objective_label)

	_wealth_label = Label.new()
	_wealth_label.add_theme_font_size_override("font_size", 13)
	_wealth_label.position = Vector2(get_viewport_rect().size.x - 300, 12)
	_hud.add_child(_wealth_label)


func _refresh_hud() -> void:
	_objective_label.text = "◆ " + _objective_text()
	for m in GameState.party:
		var id: int = m.get_meta("hud_label", 0)
		var label := instance_from_id(id) as Label
		if label == null:
			continue
		var el: int = m.form_element() if m.can_switch_form else m.main_element
		label.text = "%s  %s\nHP %d/%d   MP %d/%d" % [
			m.char_name, m.rank_label(el),
			m.hp, m.eff_max_hp(), m.mp, m.eff_max_mp(),
		]
		label.add_theme_color_override("font_color", GameTypes.element_color(el).lightened(0.3))
	var ess := []
	for eid in GameState.essences:
		if GameState.essences[eid] > 0:
			ess.append("%s×%d" % [_essence_short(eid), GameState.essences[eid]])
	_wealth_label.text = "金币 %d   精魄 %s" % [GameState.gold, " ".join(ess) if ess.size() > 0 else "无"]


func _essence_short(eid: String) -> String:
	for el in GameTypes.ELEMENT_NAMES:
		if eid == GameState.essence_for_element(el):
			return GameTypes.element_name(el)
	return eid


## 当前主线目标（按剧情旗标推进，序章 → 第一章前半）。
func _objective_text() -> String:
	if not flag("prologue_awaken_done"):
		return "目标：参加觉醒典礼"
	if not flag("prologue_done"):
		return "目标：在灰雾林地试练——唐月在林地入口等你"
	if not flag("ch1_mufu_done"):
		return "目标：去博城东街，那里有位旧识"
	if not flag("ch1_yuang_done"):
		return "目标：路过天澜高中门口看看"
	if not flag("elite_wolf_dead"):
		return "目标：讨伐灰雾林地深处的「独眼魔狼王」"
	if not flag("chapter1_half_done"):
		return "目标：狼王死后有异样，去林地深处查看"
	return "第一章·前半 完——地圣泉修行与博城之变将在后续版本推进"


## —— 菜单骨架（篝火/商店/背包共用） ——

## 构建居中菜单面板，返回可动态重建的内容容器（标题常驻，Esc 由 _unhandled_input 统一关闭）。
func _menu_base(title_text: String, width := 360.0) -> VBoxContainer:
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 6)
	panel.add_child(panel_box)
	_menu.add_child(panel)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	panel_box.add_child(title)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.custom_minimum_size = Vector2(width, 0)
	panel_box.add_child(body)
	_hud.add_child(_menu)
	return body


## 菜单的结果提示行（每次重建时新建）。
func _menu_message(body: VBoxContainer) -> Label:
	_menu_result = Label.new()
	_menu_result.add_theme_color_override("font_color", Color("ffd166"))
	body.add_child(_menu_result)
	return _menu_result


## 聚焦菜单里第一个可用按钮（方向键导航、回车/E 确认、Esc 离开）。
## 跳过排队删除的幽灵节点：菜单重建用 queue_free 延迟移除，本帧内
## 旧按钮仍在树上，抢到它们的焦点会在下帧随节点销毁而丢失。
func _focus_menu() -> void:
	for node in _menu.find_children("*", "Button", true, false):
		var b := node as Button
		if b != null and not b.is_queued_for_deletion() and not b.disabled:
			b.grab_focus()
			return


## —— 篝火菜单：休息 / 修炼 / 突破 / 存档 ——

func _open_rest_menu() -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	var box := _menu_base("营地篝火")

	_menu_message(box)

	var rest_btn := Button.new()
	rest_btn.text = "休息（恢复全体 HP/MP）"
	rest_btn.pressed.connect(func() -> void:
		GameState.rest_at_camp()
		Audio.play_sfx("rest")
		_menu_result.text = "队伍在篝火旁休整，状态全满。"
		_refresh_menu()
	)
	box.add_child(rest_btn)

	var save_btn := Button.new()
	save_btn.text = "在此存档"
	save_btn.pressed.connect(func() -> void:
		var err := SaveSystem.save_game()
		if err == OK:
			Audio.play_sfx("save")
		_menu_result.text = "旅程已记录。" if err == OK else "保存失败。"
	)
	box.add_child(save_btn)

	var mofan: CharacterState = GameState.party[0]
	for el in mofan.elements:
		var el_i: int = el
		var btn := Button.new()
		btn.text = "修炼·%s系（+15 修为，设为主修）" % GameTypes.element_name(el_i)
		btn.pressed.connect(func() -> void:
			mofan.main_element = el_i
			_apply_cultivate(mofan, el_i, 15)
		)
		box.add_child(btn)
		btn.set_meta("cultivate_element", el_i)

	for m in GameState.party:
		for el in m.elements:
			var el_i: int = el
			if not m.is_bottleneck(el_i):
				continue
			var btn := Button.new()
			var need := GameState.essence_for_element(el_i)
			btn.text = "%s 突破%s（需 %s×%d，持有 %d）" % [
				m.char_name, GameTypes.stage_name(m.stage_of(el_i) + 1),
				_essence_short(need), GameState.ESSENCE_COST, GameState.essence_count(need),
			]
			btn.disabled = GameState.essence_count(need) < GameState.ESSENCE_COST
			btn.pressed.connect(func() -> void:
				if GameState.try_breakthrough(m, el_i):
					Audio.play_sfx("breakthrough")
					_menu_result.text = "%s 的%s系突破成功！晋升%s。" % [
						m.char_name, GameTypes.element_name(el_i),
						GameTypes.rank_text(el_i, m.stage_of(el_i), m.star_of(el_i)),
					]
				_refresh_menu()
			)
			box.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "离开"
	close_btn.pressed.connect(_close_rest_menu)
	box.add_child(close_btn)

	_refresh_menu()
	_focus_menu()


func _apply_cultivate(m: CharacterState, el: int, amount: int) -> void:
	var events := m.gain_xp(el, amount)
	for ev in events:
		match ev["type"]:
			"star":
				GameEvents.star_advanced.emit(m.char_name, el, ev["stage"], ev["star"])
				Audio.play_sfx("star")
				_menu_result.text = "%s 星子连线！晋升%s。" % [m.char_name, m.rank_label(el)]
			"bottleneck":
				GameEvents.bottleneck_reached.emit(m.char_name, el)
				Audio.play_sfx("star")
				_menu_result.text = "%s 的%s系三星圆满，进入瓶颈——收集精魄方可突破。" % [m.char_name, GameTypes.element_name(el)]
	if events.is_empty() or events.size() == 1:
		_menu_result.text = "静静修炼了一晚。（%s系修为+%d）" % [GameTypes.element_name(el), amount]
	GameEvents.party_status_changed.emit()
	_refresh_menu()


func _refresh_menu() -> void:
	_refresh_hud()
	for btn in _menu.find_children("*", "Button", true, false):
		if btn.has_meta("cultivate_element"):
			var el: int = btn.get_meta("cultivate_element")
			btn.disabled = GameState.party[0].is_bottleneck(el)


## —— 商店：买断制货架，金币结算 ——

var _wares: Array = []
var _shop_box: VBoxContainer


## 货架由地图注册（见 add_merchant），条目 {"kind": "item"/"equip", "id": 数据id}。
func _open_shop(wares: Array) -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	_wares = wares
	_shop_box = _menu_base("杂货铺", 500)
	_refresh_shop()


func _refresh_shop() -> void:
	for child in _shop_box.get_children():
		child.queue_free()
	var gold_label := Label.new()
	gold_label.text = "金币 %d" % GameState.gold
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", Color("ffd166"))
	_shop_box.add_child(gold_label)
	var message := _menu_message(_shop_box)
	var first := true
	for w in _wares:
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 13)
		if w["kind"] == "item":
			var item: ItemData = GameData.load_item(w["id"])
			btn.text = "%s · %s —— %d 金币（持有 %d）" % [
				item.item_name, item.effect_text(), item.price, GameState.items.get(w["id"], 0)]
			btn.pressed.connect(_buy_ware.bind(w))
		else:
			var eq: EquipData = GameData.load_equip(w["id"])
			btn.text = "%s（%s）· %s —— %d 金币" % [
				eq.equip_name, eq.slot_name(), eq.bonus_text(), eq.price]
			btn.pressed.connect(_buy_ware.bind(w))
		_shop_box.add_child(btn)
		if first:
			btn.grab_focus()
			first = false
	var close_btn := Button.new()
	close_btn.text = "离开"
	close_btn.pressed.connect(_close_rest_menu)
	_shop_box.add_child(close_btn)


func _buy_ware(w: Dictionary) -> void:
	var data_name := ""
	var price := 0
	if w["kind"] == "item":
		var item: ItemData = GameData.load_item(w["id"])
		data_name = item.item_name
		price = item.price
	else:
		var eq: EquipData = GameData.load_equip(w["id"])
		data_name = eq.equip_name
		price = eq.price
	if not GameState.try_spend(price):
		_menu_result.text = "金币不够……"
		return
	if w["kind"] == "item":
		GameState.add_item(w["id"])
	else:
		GameState.add_equip(w["id"])
	Audio.play_sfx("coin")
	_menu_result.text = "买下了 %s。" % data_name
	GameEvents.party_status_changed.emit()  # 刷新 HUD 金币
	_refresh_shop()


## —— 背包：使用消耗品 / 穿戴装备 ——

var _bag_box: VBoxContainer
var _pending_bag_item := ""


func _open_bag() -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	_bag_box = _menu_base("背包", 420)
	_refresh_bag()


func _refresh_bag() -> void:
	for child in _bag_box.get_children():
		child.queue_free()
	var message := _menu_message(_bag_box)
	var head := Label.new()
	head.text = "—— 消耗品 ——"
	head.add_theme_font_size_override("font_size", 13)
	_bag_box.add_child(head)
	if GameState.items.is_empty():
		var empty := Label.new()
		empty.text = "（空空如也）"
		empty.add_theme_font_size_override("font_size", 12)
		_bag_box.add_child(empty)
	for item_id in GameState.items:
		var item: ItemData = GameData.load_item(item_id)
		var btn := Button.new()
		btn.text = "%s ×%d · %s" % [item.item_name, GameState.items[item_id], item.effect_text()]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_pick_field_target.bind(item_id))
		_bag_box.add_child(btn)
	var equip_head := Label.new()
	equip_head.text = "—— 装备（选择后为领队穿戴） ——"
	equip_head.add_theme_font_size_override("font_size", 13)
	_bag_box.add_child(equip_head)
	for equip_id in GameState.equip_bag:
		var eq: EquipData = GameData.load_equip(equip_id)
		var btn := Button.new()
		btn.text = "%s（%s）· %s" % [eq.equip_name, eq.slot_name(), eq.bonus_text()]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_pick_equip_target.bind(equip_id))
		_bag_box.add_child(btn)
	var close_btn := Button.new()
	close_btn.text = "关闭（Esc）"
	close_btn.pressed.connect(_close_rest_menu)
	_bag_box.add_child(close_btn)
	_focus_menu()


func _pick_field_target(item_id: String) -> void:
	var item: ItemData = GameData.load_item(item_id)
	_pending_bag_item = item_id
	for child in _bag_box.get_children():
		child.queue_free()
	var message := _menu_message(_bag_box)
	var hint := Label.new()
	hint.text = "对谁使用 %s？" % item.item_name
	hint.add_theme_font_size_override("font_size", 14)
	_bag_box.add_child(hint)
	for m in GameState.party:
		var btn := Button.new()
		btn.text = "%s  HP %d/%d  MP %d/%d" % [m.char_name, m.hp, m.eff_max_hp(), m.mp, m.eff_max_mp()]
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not _field_item_ok(item, m)
		btn.pressed.connect(_use_field_item.bind(m))
		_bag_box.add_child(btn)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(_refresh_bag)
	_bag_box.add_child(back)
	_focus_menu()


func _field_item_ok(item: ItemData, m: CharacterState) -> bool:
	if item.battle_only:
		return false
	match item.kind:
		"heal_hp": return m.hp > 0 and m.hp < m.eff_max_hp()
		"heal_mp": return m.hp > 0 and m.mp < m.eff_max_mp()
	return false


func _use_field_item(m: CharacterState) -> void:
	var item: ItemData = GameData.load_item(_pending_bag_item)
	if item == null or not GameState.take_item(_pending_bag_item):
		return
	match item.kind:
		"heal_hp": m.change_hp(item.amount)
		"heal_mp": m.change_mp(item.amount)
	Audio.play_sfx("rest")
	GameEvents.party_status_changed.emit()
	_refresh_bag()


func _pick_equip_target(equip_id: String) -> void:
	var eq: EquipData = GameData.load_equip(equip_id)
	for child in _bag_box.get_children():
		child.queue_free()
	var message := _menu_message(_bag_box)
	var hint := Label.new()
	hint.text = "谁装备 %s（%s）？" % [eq.equip_name, eq.slot_name()]
	hint.add_theme_font_size_override("font_size", 14)
	_bag_box.add_child(hint)
	for m in GameState.party:
		var btn := Button.new()
		var old: String = m.equips.get(eq.slot, "")
		var old_name: String = GameData.load_equip(old).equip_name if old != "" else "无"
		btn.text = "%s（当前：%s）" % [m.char_name, old_name]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_do_equip.bind(m, equip_id))
		_bag_box.add_child(btn)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(_refresh_bag)
	_bag_box.add_child(back)
	_focus_menu()


func _do_equip(m: CharacterState, equip_id: String) -> void:
	var eq: EquipData = GameData.load_equip(equip_id)
	if eq == null or not GameState.take_equip(equip_id):
		return
	if m.equips.has(eq.slot):
		GameState.add_equip(m.equips[eq.slot])  # 换下的回背包
	m.equips[eq.slot] = equip_id
	m.hp = mini(m.hp, m.eff_max_hp())
	m.mp = mini(m.mp, m.eff_max_mp())
	Audio.play_sfx("ui_confirm")
	GameEvents.party_status_changed.emit()
	_refresh_bag()


func _close_rest_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_menu_result = null
	player.input_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_rest_menu()
	elif _menu == null and not _event_running and event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_bag()
