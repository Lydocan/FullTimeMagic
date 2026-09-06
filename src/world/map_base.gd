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
const MINIMAP_SCRIPT := preload("res://src/ui/minimap.gd")
const BATTLE_SCENE := "res://src/battle/battle.tscn"

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const CharacterState := preload("res://src/data/character_state.gd")
const GameData := preload("res://src/data/game_data.gd")
const GameTypes := preload("res://src/data/game_types.gd")
const ItemData := preload("res://src/data/item_data.gd")
const EquipData := preload("res://src/data/equip_data.gd")
const ClothingData := preload("res://src/data/clothing_data.gd")

## 成员 id → 地图跟随立绘（战斗立绘同源；新增成员时在此登记）。
const MEMBER_TEXTURES := {
	"mo_fan": "res://assets/images/char_mofan.png",
	"mu_ningxue": "res://assets/images/char_muningxue.png",
}

## 成员换装槽位（渲染顺序 = 从内到外；穿连衣裙时上/下装层隐藏）。
## 无配置的成员不参与换装（跟随者保持单贴图）。
const MEMBER_WARDROBE_SLOTS := {
	"mo_fan": ["hat", "top", "pants"],
	"mu_ningxue": ["hosiery", "pants", "top", "dress", "hat"],
}

## 成员换装的基础身体贴图（分层渲染最底层，无衣）。
const MEMBER_OUTFIT_BASE := {
	"mo_fan": "res://assets/images/char_mofan_base.png",
	"mu_ningxue": "res://assets/images/char_muningxue_base.png",
}

## 成员显示名（衣柜分页 / 背包衣装归属标注）。
const MEMBER_NAMES := {
	"mo_fan": "莫凡",
	"mu_ningxue": "穆宁雪",
}

## 高清立绘目录（分层纸娃娃，规格见 docs/art_spec.md）。
## 角色 base.png 存在即切高清轨；缺失自动回落像素占位。
const ART_DIR := "res://assets/images/art/"


## 高清轨判定：该角色存在 art/<id>/base.png 即用高清纸娃娃。
func _art_track(member_id: String) -> bool:
	return ResourceLoader.exists(ART_DIR + member_id + "/base.png")

# tiles_proto.png 的 11 格横向图块。
const T_GRASS := Vector2i(0, 0)
const T_TALL := Vector2i(1, 0)
const T_PATH := Vector2i(2, 0)
const T_TREE := Vector2i(3, 0)
const T_ROCK := Vector2i(4, 0)
const T_WATER := Vector2i(5, 0)
const T_ROOF := Vector2i(6, 0)   # 'F' 屋顶（蓝瓦）
const T_WALL := Vector2i(7, 0)   # 'B' 墙体
const T_DOOR := Vector2i(8, 0)   # 'D' 门（建筑立面，不可进入）
const T_SROOF := Vector2i(9, 0)  # 'C' 校舍红瓦
const T_SPIRE := Vector2i(10, 0) # 'U' 校舍尖塔

var player: CharacterBody2D
var tilemap: TileMapLayer
var followers: Array[Node2D] = []

var _triggers: Array[Dictionary] = []  # {cell, radius, event}
var _portals: Array[Dictionary] = []   # {cell, target, spawn}
var _npcs: Array[Dictionary] = []      # {cell, texture, name, hide_flag, event}
var _npc_nodes: Array[Area2D] = []     # 已生成的 NPC 实体（部分注册项可能未生成）
var _campfire_cells: Array[Vector2i] = []  # 篝火格（野外安全半径的圆心）
var _event_running := false
var _encounter_gauge := 0.0
var _encounter_threshold := 200.0
var _cooling := true
var _menu: Control = null
var _menu_result: Label = null
var _wealth_label: Label
var _objective_label: Label
var _party_box: VBoxContainer
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


## 地图名称（底部书卷显示）。子类必须覆盖——每个地图都有名字。
func map_display_name() -> String:
	return "未知之地"


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


## 注册剧情 NPC：hide_flag 点亮后不再出现（人物退场）。event 传无效
## Callable（Callable()）则为纯装饰 NPC（无交互）。
func add_npc(cell: Vector2i, texture: String, display_name: String, hide_flag: String, event: Callable) -> void:
	_npcs.append({"cell": cell, "texture": texture, "name": display_name, "hide_flag": hide_flag, "event": event})


## 注册商人 NPC：按 E 打开商店（常驻，不随旗标退场）。
func add_merchant(cell: Vector2i, texture: String, display_name: String, wares: Array) -> void:
	_npcs.append({"cell": cell, "texture": texture, "name": display_name, "hide_flag": "", "wares": wares})


func add_portal(cell: Vector2i, target_scene: String, spawn_cell: Vector2i) -> void:
	_portals.append({"cell": cell, "target": target_scene, "spawn": spawn_cell})


func add_campfire(cell: Vector2i) -> void:
	_campfire_cells.append(cell)  # 野外的安全半径圆心（in_safe_zone）
	var fire: Area2D = CAMPFIRE_SCRIPT.new()
	fire.position = _cell_center(cell)
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


## 剧情战斗。party_ids 非空时限定出战成员子集（如毕业决斗限莫凡单人）。
func start_story_battle(ids: Array, win_flag: String, party_ids: Array = []) -> void:
	_start_encounter(ids, win_flag, true, party_ids)


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
	_refresh_hud()  # 事件可能推进了剧情旗标，目标提示随之更新


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
	for i in 11:
		src.create_tile(Vector2i(i, 0))
	# 先挂到 TileSet（图块数据才知道有几个物理层），再配置碰撞。
	ts.add_source(src, 0)
	for blocked in [T_TREE, T_ROCK, T_WATER, T_ROOF, T_WALL, T_DOOR, T_SROOF, T_SPIRE]:
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
				"F": coords = T_ROOF
				"B": coords = T_WALL
				"D": coords = T_DOOR
				"C": coords = T_SROOF
				"U": coords = T_SPIRE
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


## 入场处理：战斗返回位置 → 队伍跟随 → 区域过场 → 剧情触发检查 → 解除操作冷却。
## 过场盖在已就位的世界之上（先落世界、再上演出），输入全程保持锁定。
func _apply_entry_position() -> void:
	if GameState.has_return_position:
		player.global_position = GameState.return_position
		GameState.has_return_position = false
	_sync_followers()
	await _maybe_zone_transition()
	await get_tree().create_timer(0.2).timeout
	for t in _triggers:
		if player.global_position.distance_to(_cell_center(t["cell"])) <= float(t["radius"]):
			run_event(t["event"])
			break
	await get_tree().create_timer(1.0).timeout
	_cooling = false
	# 入场收尾不得覆盖菜单/事件的锁：入场窗口内开了菜单（背包/系统菜单
	# 不经 input_enabled 检查即可打开），这里的无条件解锁会把菜单里的
	# 人物放出来——方向键同时驱动菜单和行走（试玩反馈的移动穿透 bug）。
	# 菜单关闭时 _close_rest_menu 自会解锁。
	if _menu == null and not _event_running:
		player.input_enabled = true


## —— 安全区 / 野外区 ——
##
## 有遇敌表的地图即野外：全域可行走格都积累遇敌计量（深草更快），
## 篝火半径与子类登记的据点为安全区（计量消退）。无遇敌表的地图
## （城镇/室内）整图安全。

func is_wild() -> bool:
	return not encounter_table().is_empty()


## 子类可追加安全据点（格矩形），如林地入口的安全带。
func safe_zones() -> Array[Rect2i]:
	return []


func in_safe_zone(cell: Vector2i) -> bool:
	if not is_wild():
		return true
	for c in _campfire_cells:
		if absi(c.x - cell.x) <= 3 and absi(c.y - cell.y) <= 3:
			return true
	for r in safe_zones():
		if cell.x >= r.position.x and cell.y >= r.position.y \
				and cell.x < r.end.x and cell.y < r.end.y:
			return true
	return false


## 跨区过场：从安全区进入野外（或反向）时演出一次，方向随进出而定。
## GameState 记录上一张图的野性状态；同图内往返不重复触发。
func _maybe_zone_transition() -> void:
	var wild := is_wild()
	if GameState.has_prev_wildness and GameState.prev_map_wild != wild:
		await _play_zone_transition(wild)
	GameState.prev_map_wild = wild
	GameState.has_prev_wildness = true


## 双向过场（约 5s）：进野外=妖兽包围的压迫演出；回安全区=归来的宁静演出。
## 期间玩家输入保持锁定（_cooling 尚未解除），演完才交给玩家。
func _play_zone_transition(entering_wild: bool) -> void:
	Audio.play_sfx("zone_wild" if entering_wild else "zone_safe")
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var text := Label.new()
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.grow_vertical = Control.GROW_DIRECTION_BOTH
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 25)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text.add_theme_constant_override("outline_size", 8)
	text.modulate.a = 0.0
	layer.add_child(text)

	# 黑暗中的妖兽之眼：成对的猩红光斑渐次睁开（进野外专属）
	var eyes: Array[Sprite2D] = []
	if entering_wild:
		text.text = "妖兽的气息在四周蔓延——准备战斗！"
		text.add_theme_color_override("font_color", Color("ff8a6a"))
		for i in 7:
			var eye := Sprite2D.new()
			var g := Gradient.new()
			g.set_offset(0, 0.0)
			g.set_color(0, Color(1.0, 0.35, 0.25, 0.95))
			g.set_offset(1, 1.0)
			g.set_color(1, Color(0.6, 0.08, 0.05, 0.0))
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(0.5, 0.0)
			tex.width = 32
			tex.height = 32
			eye.texture = tex
			var vp := get_viewport_rect().size
			var side := 1.0 if i % 2 == 0 else -1.0
			var base := Vector2(vp.x * 0.5 + side * vp.x * randf_range(0.18, 0.42),
					vp.y * randf_range(0.2, 0.8))
			eye.position = base
			eye.scale = Vector2.ONE * randf_range(0.7, 1.6)
			eye.modulate.a = 0.0
			layer.add_child(eye)
			eyes.append(eye)
			# 同一只眼的双瞳
			var twin := eye.duplicate() as Sprite2D
			twin.position = base + Vector2(side * randf_range(14.0, 22.0), randf_range(-4.0, 4.0))
			layer.add_child(twin)
			eyes.append(twin)
	else:
		text.text = "暂时摆脱了妖兽的追踪……回营地休整吧"
		text.add_theme_color_override("font_color", Color("ffe9a3"))

	var target_bg := Color(0.06, 0.01, 0.02, 0.96) if entering_wild else Color(0.16, 0.12, 0.04, 0.9)
	var tw := create_tween()
	tw.tween_property(bg, "color", target_bg, 0.8)
	if entering_wild:
		# 妖兽之眼渐次睁开（1.0s ~ 2.6s），文字 2.2s 压上
		for i in eyes.size():
			var et := create_tween()
			et.tween_interval(1.0 + 0.12 * i)
			et.tween_property(eyes[i], "modulate:a", 1.0, 0.3)
		tw.tween_interval(1.4)
	else:
		tw.tween_interval(0.7)
	tw.tween_property(text, "modulate:a", 1.0, 0.7)
	tw.tween_interval(2.2)
	tw.tween_property(text, "modulate:a", 0.0, 0.6)
	tw.tween_property(bg, "color:a", 0.0, 0.7)
	for eye in eyes:
		tw.parallel().tween_property(eye, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)
	await tw.finished


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
		if MEMBER_WARDROBE_SLOTS.has(m.id):  # 衣柜成员：基础身体 + 分层换装
			follower.member_id = m.id
			follower.wardrobe_slots = MEMBER_WARDROBE_SLOTS[m.id]
			follower.texture = load(MEMBER_OUTFIT_BASE[m.id])
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
	npc.texture = load(n["texture"])
	npc.display_name = n["name"]
	npc.hide_flag = n["hide_flag"]
	if n.has("wares"):
		npc.event = func() -> void: _open_shop(n["wares"])
	elif n["event"].is_valid():
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
	# 暗雷：野外全域都有概率遇敌（深草更快）；篝火半径等安全区计量消退
	var table := encounter_table()
	if table.is_empty():
		return
	if in_safe_zone(cell):
		_encounter_gauge = maxf(_encounter_gauge - distance * 0.6, 0.0)
	elif _cell_char(cell) == "H":
		_encounter_gauge += distance * 1.5  # 深草：妖兽巢穴，格外危险
	else:
		_encounter_gauge += distance
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
func _start_encounter(ids: Array, win_flag: String, from_event := false, party_ids: Array = []) -> void:
	if _encounter_blocked(from_event):
		return
	Audio.play_sfx("encounter")
	_cooling = true
	player.input_enabled = false
	GameState.return_position = player.global_position
	GameState.has_return_position = true
	GameState.pending_enemies = ids
	GameState.pending_flag = win_flag
	GameState.pending_party_ids = party_ids
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
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 4)
	panel.add_child(_party_box)
	for m in GameState.party:
		_ensure_member_block(m)
	_hud.add_child(panel)

	var vw := get_viewport_rect().size.x
	var mm := MINIMAP_SCRIPT.new()
	mm.setup(self)
	_hud.add_child(mm)
	mm.position = Vector2(vw - mm.size.x - 12, 12)

	# 底部中央：书卷式地图名（入场时缓缓展开）
	_build_map_scroll()

	# 右上信息列：小地图 → 目标提示（与黄三角同色联动）→ 金币/精魄，右缘对齐
	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 14)
	_objective_label.add_theme_color_override("font_color", Color("ffd166"))
	_objective_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # 长文本向左展开，右缘不跑出屏
	_objective_label.position = Vector2(vw - 12, mm.size.y + 22)
	_hud.add_child(_objective_label)

	_wealth_label = Label.new()
	_wealth_label.add_theme_font_size_override("font_size", 13)
	_wealth_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wealth_label.position = Vector2(vw - 12, mm.size.y + 46)
	_hud.add_child(_wealth_label)

	var hint := Label.new()
	hint.text = "WASD/方向键 移动 · E 交互 · I/Tab 背包 · Esc 系统/关闭菜单 · 野外可行走区域均会遇敌（深草更危险）· 篝火处休息/修炼/突破/存档"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	hint.position = Vector2(12, get_viewport_rect().size.y - 34)
	_hud.add_child(hint)


## —— 底部书卷地图名 ——
##
## 左右卷轴杆 + 中间羊皮纸面；入场时从中心横向展开，停驻不碍事。

func _build_map_scroll() -> void:
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	var scroll := HBoxContainer.new()
	scroll.add_theme_constant_override("separation", 0)
	var rod_style := StyleBoxFlat.new()
	rod_style.bg_color = Color("6b4a2f")
	rod_style.set_corner_radius_all(4)
	rod_style.border_width_top = 2
	rod_style.border_width_bottom = 2
	rod_style.border_color = Color("8a6238")
	var rod_l := PanelContainer.new()
	rod_l.add_theme_stylebox_override("panel", rod_style)
	rod_l.custom_minimum_size = Vector2(9, 40)
	scroll.add_child(rod_l)
	var parchment := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("d8c9a8")
	p_style.border_color = Color("8a734f")
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(2)
	p_style.content_margin_left = 20.0
	p_style.content_margin_right = 20.0
	p_style.content_margin_top = 4.0
	p_style.content_margin_bottom = 5.0
	parchment.add_theme_stylebox_override("panel", p_style)
	var name_label := Label.new()
	name_label.text = "　%s　" % map_display_name()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("4a3520"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parchment.add_child(name_label)
	scroll.add_child(parchment)
	# 右杆再补一根（左-纸-右）
	var rod_r := PanelContainer.new()
	rod_r.add_theme_stylebox_override("panel", rod_style)
	rod_r.custom_minimum_size = Vector2(9, 40)
	scroll.add_child(rod_r)
	scroll.position = Vector2((vw - 260.0) * 0.5, vh - 92.0)
	_hud.add_child(scroll)
	# 展开动画：以纸面中心为轴向两侧摊开
	scroll.reset_size()
	scroll.pivot_offset = scroll.size * 0.5
	scroll.position = Vector2((vw - scroll.size.x) * 0.5, vh - 92.0)
	scroll.scale = Vector2(0.05, 1.0)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(scroll, "scale", Vector2.ONE, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## —— 队员状态块：姓名行 + HP/MP 进度条（条上叠数值） ——

## 取队员的状态块，没有则现建（中途入队的成员也能即时补上）。
## 跨场景后旧块已随旧 HUD 销毁，失效时重建。
func _ensure_member_block(m: CharacterState) -> void:
	if m.has_meta("hud_block"):
		var blk: Dictionary = m.get_meta("hud_block")
		if is_instance_valid(blk["name"]):
			return
		m.remove_meta("hud_block")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	_party_box.add_child(col)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 13)
	col.add_child(name_label)
	m.set_meta("hud_block", {
		"name": name_label,
		"hp": _make_stat_bar(Color("c0504d"), col),
		"mp": _make_stat_bar(Color("4f7dc9"), col),
	})


func _make_stat_bar(fill_color: Color, parent: Control) -> Dictionary:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 15)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	var text := Label.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 10)
	text.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	text.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(text)
	parent.add_child(bar)
	return {"bar": bar, "text": text}


func _update_stat_bar(stat: Dictionary, value: int, max_value: int, prefix: String) -> void:
	var bar: ProgressBar = stat["bar"]
	bar.max_value = maxi(max_value, 1)
	bar.value = value
	(stat["text"] as Label).text = "%s %d/%d" % [prefix, value, max_value]


func _refresh_hud() -> void:
	_objective_label.text = "◆ " + _objective_text()
	for m in GameState.party:
		_ensure_member_block(m)
		var blk: Dictionary = m.get_meta("hud_block")
		var el: int = m.form_element() if m.can_switch_form else m.main_element
		var name_label: Label = blk["name"]
		name_label.text = "%s · %s" % [m.char_name, m.rank_label(el)]
		name_label.add_theme_color_override("font_color", GameTypes.element_color(el).lightened(0.3))
		_update_stat_bar(blk["hp"], m.hp, m.eff_max_hp(), "HP")
		_update_stat_bar(blk["mp"], m.mp, m.eff_max_mp(), "MP")
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


## 当前主线目标（按剧情旗标推进，序章 → 第一章前半 → 毕业决斗）。
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
	if not flag("duel_done"):
		return "目标：天澜高中门口——毕业决斗，夺得地圣泉名额"
	return "毕业决斗·完——地圣泉修行将在后续版本开放"


## 当前主线目标在本图的落点（世界坐标），小地图黄三角据此指向。
## 目标不在本图 / 剧情完结时返回 Vector2.INF（不画三角）。子类按旗标覆盖。
func objective_target() -> Vector2:
	return Vector2.INF


## —— 菜单骨架（篝火/商店/背包共用） ——

## 构建居中菜单面板，返回可动态重建的内容容器（标题常驻，Esc 由 _unhandled_input 统一关闭）。
## 华丽化：深紫夜色面板 + 金色饰线标题 + 统一按钮主题（与战斗 UI 同一观感体系）。
func _menu_base(title_text: String, width := 360.0) -> VBoxContainer:
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.theme = _menu_theme()
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.04, 0.11, 0.96)
	panel_style.border_color = Color("7a68b0")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", panel_style)
	# 面板里的微渐变底：纵向深紫过渡，撑出质感
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(0.16, 0.11, 0.26, 0.55))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(0.02, 0.01, 0.05, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = g
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 32
	gtex.height = 128
	grad.texture = gtex
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grad)
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)
	# 饰线标题：两侧金线夹「◆ 标题 ◆」
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	for side in 2:
		var line := ColorRect.new()
		line.color = Color(1.0, 0.82, 0.4, 0.35)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(line)
		if side == 0:
			var title := Label.new()
			title.text = "◆ %s ◆" % title_text
			title.add_theme_font_size_override("font_size", 20)
			title.add_theme_color_override("font_color", Color("ffd166"))
			title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			title.add_theme_constant_override("outline_size", 4)
			title_row.add_child(title)
	panel_box.add_child(title_row)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.custom_minimum_size = Vector2(width, 0)
	panel_box.add_child(body)
	_menu.add_child(panel)  # 面板挂进菜单容器（漏掉这行曾让所有菜单渲染成空壳）
	_hud.add_child(_menu)
	return body


## 菜单统一按钮主题：暗底细边、悬停金边、焦点金环——键盘导航的落点一眼可见。
func _menu_theme() -> Theme:
	var t := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.045)
	normal.border_color = Color(1, 1, 1, 0.10)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.09)
	hover.border_color = Color(1.0, 0.82, 0.4, 0.55)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(1, 1, 1, 0.14)
	pressed.border_color = Color(1.0, 0.82, 0.4, 0.75)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.02)
	disabled.border_color = Color(1, 1, 1, 0.05)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.82, 0.4, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.93, 0.91, 0.86))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.82))
	t.set_color("font_focus_color", "Button", Color(1, 0.95, 0.82))
	t.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.28))
	t.set_font_size("font_size", "Button", 14)
	return t


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
		btn.text = "修炼·%s系（+5 修为，设为主修）" % GameTypes.element_name(el_i)
		btn.pressed.connect(func() -> void:
			mofan.main_element = el_i
			_apply_cultivate(mofan, el_i, 5)
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
			# 记录归属：突破后精魄数量变化，_refresh_menu 按此刷新文案与可点性
			btn.set_meta("breakthrough_btn", {"member": m, "element": el_i})
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
		# 突破按钮随精魄存量/瓶颈状态实时刷新——突破用掉最后一组精魄后，
		# 按钮的「持有 N」与可点性若停留在旧值，就是"还提示有精魄可用"的假象
		if btn.has_meta("breakthrough_btn"):
			var info: Dictionary = btn.get_meta("breakthrough_btn")
			var mm: CharacterState = info["member"]
			var el_i: int = info["element"]
			if not mm.is_bottleneck(el_i):
				btn.disabled = true  # 该系已突破，按钮退场前置（下一轮重建时消失）
				(btn as Button).text = "%s 已突破%s" % [mm.char_name, GameTypes.stage_name(mm.stage_of(el_i))]
			else:
				var need: String = GameState.essence_for_element(el_i)
				(btn as Button).text = "%s 突破%s（需 %s×%d，持有 %d）" % [
					mm.char_name, GameTypes.stage_name(mm.stage_of(el_i) + 1),
					_essence_short(need), GameState.ESSENCE_COST, GameState.essence_count(need),
				]
				btn.disabled = GameState.essence_count(need) < GameState.ESSENCE_COST


## —— 商店：买断制货架，金币结算 ——

var _wares: Array = []
var _shop_box: VBoxContainer
var _shop_list: VBoxContainer  # 滚动区内的货架列表（随刷新重建）


## 货架由地图注册（见 add_merchant），条目 {"kind": "item"/"equip", "id": 数据id}。
## 货架装在滚动容器里，衣柜/离开固定底部——衣装多了按钮不再被顶出屏幕。
func _open_shop(wares: Array) -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	_wares = wares
	_shop_box = _menu_base("杂货铺", 500)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_list)
	_shop_box.add_child(scroll)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	var wardrobe_btn := Button.new()
	wardrobe_btn.text = "衣柜 · 更换衣装"
	wardrobe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wardrobe_btn.pressed.connect(func() -> void:
		_close_rest_menu()
		_open_wardrobe()
	)
	footer.add_child(wardrobe_btn)
	var close_btn := Button.new()
	close_btn.text = "离开"
	close_btn.pressed.connect(_close_rest_menu)
	footer.add_child(close_btn)
	_shop_box.add_child(footer)
	_refresh_shop()


func _refresh_shop() -> void:
	for child in _shop_list.get_children():
		child.queue_free()
	var gold_label := Label.new()
	gold_label.text = "金币 %d" % GameState.gold
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", Color("ffd166"))
	_shop_list.add_child(gold_label)
	var message := _menu_message(_shop_list)
	for w in _wares:
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 13)
		if w["kind"] == "item":
			var item: ItemData = GameData.load_item(w["id"])
			btn.text = "%s · %s —— %d 金币（持有 %d）" % [
				item.item_name, item.effect_text(), item.price, GameState.items.get(w["id"], 0)]
			btn.pressed.connect(_buy_ware.bind(w))
		elif w["kind"] == "clothing":
			var c: ClothingData = GameData.load_clothing(w["id"])
			var owned: bool = GameState.is_clothing_owned(c.owner_id, w["id"])
			var owner_tag := "" if c.owner_id == "mo_fan" else "· 穆宁雪"
			btn.text = "%s（%s%s · 华丽度 +%d）—— %d 金币%s" % [
				c.clothing_name, c.slot_name(), owner_tag, c.glamour, c.price,
				"（已拥有）" if owned else ""]
			btn.disabled = owned
			btn.pressed.connect(_buy_ware.bind(w))
		else:
			var eq: EquipData = GameData.load_equip(w["id"])
			btn.text = "%s（%s）· %s —— %d 金币" % [
				eq.equip_name, eq.slot_name(), eq.bonus_text(), eq.price]
			btn.pressed.connect(_buy_ware.bind(w))
		_shop_list.add_child(btn)
	_focus_menu()  # 首个可点按钮（自动跳过已拥有的禁用项）


## —— 衣柜：只能在杂货铺进入（试玩需求）——
## 更换衣装、查看华丽度与时尚称号（华丽度 = 拥有所有衣装的华丽度总和）。

var _wardrobe_box: VBoxContainer
var _wardrobe_columns: HBoxContainer
var _wardrobe_tabs: HBoxContainer
var _preview_layers: Array[TextureRect] = []
var _wardrobe_member := "mo_fan"
var _wardrobe_from := "shop"  # 衣柜入口来路（"shop"/"bag"），返回键随之


func _open_wardrobe(from: String = "shop") -> void:
	if _menu != null or _event_running:
		return
	_wardrobe_from = from
	player.input_enabled = false
	var body: VBoxContainer = _menu_base("衣柜", 560)
	_wardrobe_tabs = HBoxContainer.new()
	_wardrobe_tabs.add_theme_constant_override("separation", 10)
	body.add_child(_wardrobe_tabs)
	_wardrobe_columns = HBoxContainer.new()
	_wardrobe_columns.add_theme_constant_override("separation", 16)
	body.add_child(_wardrobe_columns)
	# 左：试穿预览（按当前角色构建）
	_wardrobe_columns.add_child(_build_outfit_preview(_wardrobe_member))
	# 右：槽位分组列表装进滚动容器（衣装多了不再溢出屏幕）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 撑满剩余宽度
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_wardrobe_box = VBoxContainer.new()
	_wardrobe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_wardrobe_box)
	_wardrobe_columns.add_child(scroll)
	# 底部固定：返回来路（不随列表滚动）
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	var back_btn := Button.new()
	back_btn.text = "返回杂货铺" if _wardrobe_from == "shop" else "返回背包"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		_close_rest_menu()  # 同帧内重进来源菜单：解锁后立刻重锁，无输入窗口
		if _wardrobe_from == "bag":
			_open_bag()
		else:
			_open_shop(_wares)
	)
	back_btn.focus_entered.connect(_refresh_outfit_preview)  # 移出列表 → 预览回到当前穿着
	footer.add_child(back_btn)
	body.add_child(footer)
	_refresh_wardrobe_tabs()
	_refresh_wardrobe()


## 角色分页：莫凡常驻；穆宁雪入队后出现（她的衣柜她做主）。
func _refresh_wardrobe_tabs() -> void:
	for child in _wardrobe_tabs.get_children():
		child.queue_free()
	var in_party := false
	for m in GameState.party:
		if m.id == "mu_ningxue":
			in_party = true
	for member_id in MEMBER_WARDROBE_SLOTS:
		if member_id == "mu_ningxue" and not in_party:
			continue
		var tab := Button.new()
		tab.text = "%s的衣柜" % MEMBER_NAMES.get(member_id, member_id)
		tab.disabled = member_id == _wardrobe_member  # 当前页禁用，键盘焦点自然跳过
		tab.add_theme_font_size_override("font_size", 14)
		tab.pressed.connect(_switch_wardrobe_member.bind(member_id))
		_wardrobe_tabs.add_child(tab)


func _switch_wardrobe_member(member_id: String) -> void:
	if _wardrobe_member == member_id:
		return
	_wardrobe_member = member_id
	_refresh_wardrobe_tabs()
	# 预览按角色重建（base 贴图与层数都不同）：滚动容器保留，其余重建
	_preview_layers.clear()
	for child in _wardrobe_columns.get_children():
		if child is ScrollContainer:
			continue
		child.queue_free()
	_wardrobe_columns.add_child(_build_outfit_preview(member_id))
	_wardrobe_columns.move_child(_wardrobe_columns.get_child(_wardrobe_columns.get_child_count() - 1), 0)
	_refresh_wardrobe()


## 试穿预览面板：base 身体 + 按角色槽位顺序的层贴图。
## 高清轨（art/<角色>/base.png 存在）：2D 动建立绘 768x1152 线性过滤缩放显示；
## 像素轨（默认占位）：24x32 → 4x，NEAREST 保像素锐利。规格见 docs/art_spec.md。
func _build_outfit_preview(member_id: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.14, 0.94)
	style.border_color = Color("c792ff")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # 贴住内容高度，不随列表拉满
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "穿着预览"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("c792ff"))
	box.add_child(title)
	var hires := _art_track(member_id)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(216, 324) if hires else Vector2(96, 128)
	box.add_child(frame)
	_preview_layers.clear()
	var base_path: String = ART_DIR + member_id + "/base.png" if hires \
			else MEMBER_OUTFIT_BASE.get(member_id, "res://assets/images/char_mofan_base.png")
	var layer_paths: Array = [base_path]
	for slot in MEMBER_WARDROBE_SLOTS.get(member_id, []):
		layer_paths.append("")
	var tex_filter := CanvasItem.TEXTURE_FILTER_LINEAR if hires else CanvasItem.TEXTURE_FILTER_NEAREST
	for layer_path in layer_paths:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 贴图原始尺寸不当最小尺寸，才能缩进画框
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = tex_filter
		if layer_path != "":
			tr.texture = load(layer_path)
		frame.add_child(tr)
		_preview_layers.append(tr)
	panel.add_child(box)
	return panel


## 预览 = 当前穿着；焦点停在某件衣装上时该槽位即时试穿（override）。
## 穿连衣裙时上/下装层隐藏（连衣裙覆盖其外观），腿袜在裙摆下仍露出。
func _refresh_outfit_preview(override_slot: String = "", override_id: String = "") -> void:
	var slots: Array = MEMBER_WARDROBE_SLOTS.get(_wardrobe_member, [])
	var worn: Dictionary = GameState.worn_clothes.get(_wardrobe_member, {})
	var dress_on := (override_slot == "dress" and override_id != "") \
			or str(worn.get("dress", "")) != ""
	var hires := _art_track(_wardrobe_member)
	for i in slots.size():
		var slot: String = slots[i]
		var tr: TextureRect = _preview_layers[i + 1]
		var id := override_id if slot == override_slot else str(worn.get(slot, ""))
		var path: String = (ART_DIR + _wardrobe_member + "/" + id + ".png") if hires \
				else ("res://assets/images/clothes/%s.png" % id)
		tr.texture = load(path) if id != "" and ResourceLoader.exists(path) else null
		tr.visible = tr.texture != null and not (dress_on and (slot == "top" or slot == "pants"))


func _refresh_wardrobe() -> void:
	for child in _wardrobe_box.get_children():
		child.queue_free()
	_menu_message(_wardrobe_box)
	var banner := Label.new()
	banner.text = "华丽度 %d · 称号「%s」" % [
		GameState.glamour_total(_wardrobe_member), GameState.fashion_title(_wardrobe_member)]
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", Color("ffd166"))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wardrobe_box.add_child(banner)
	for slot in MEMBER_WARDROBE_SLOTS.get(_wardrobe_member, []):
		_bag_section(_wardrobe_box, "「%s」槽位" % GameTypes.clothing_slot_name(slot))
		var worn_id: String = str(GameState.worn_clothes.get(_wardrobe_member, {}).get(slot, ""))
		# 「不穿」选项：脱下露出基础身体的内衣打底（如脱连衣裙换回上下装搭配）
		var bare_btn := _bag_item_button(
				"不穿 · 内衣打底", "该槽位留空", Color("6f6f78"), 0,
				_unwear_from_wardrobe.bind(_wardrobe_member, slot))
		bare_btn.disabled = worn_id == ""
		bare_btn.focus_entered.connect(_refresh_outfit_preview.bind(slot, ""))  # 预览留空效果
		_wardrobe_box.add_child(bare_btn)
		var any := false
		for clothing_id in GameState.owned_clothes.get(_wardrobe_member, []):
			var c: ClothingData = GameData.load_clothing(clothing_id)
			if c == null or c.slot != slot:
				continue
			any = true
			var worn: bool = worn_id == clothing_id
			var btn := _bag_item_button(
					c.clothing_name + ("（穿着中）" if worn else ""),
					"华丽度 +%d" % c.glamour, _glamour_color(c.glamour), 1,
					_wear_from_wardrobe.bind(_wardrobe_member, slot, clothing_id))
			btn.disabled = worn
			btn.focus_entered.connect(_refresh_outfit_preview.bind(slot, clothing_id))  # 选中即试穿
			_wardrobe_box.add_child(btn)
		if not any:
			var empty := Label.new()
			empty.text = "（这个槽位还没有衣装）"
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
			_wardrobe_box.add_child(empty)
	_focus_menu()
	_refresh_outfit_preview()


func _wear_from_wardrobe(member_id: String, slot: String, clothing_id: String) -> void:
	if GameState.wear_clothing(member_id, slot, clothing_id):
		var c: ClothingData = GameData.load_clothing(clothing_id)
		_menu_result.text = "%s换上了%s（%s）。" % [
			MEMBER_NAMES.get(member_id, member_id), c.clothing_name, c.slot_name()]
	_refresh_wardrobe()


func _unwear_from_wardrobe(member_id: String, slot: String) -> void:
	if GameState.unwear_clothing(member_id, slot):
		_menu_result.text = "%s脱下了%s，换回内衣打底。" % [
			MEMBER_NAMES.get(member_id, member_id), GameTypes.clothing_slot_name(slot)]
	_refresh_wardrobe()


## 华丽度 → 色标（档位越高越接近金色）。
func _glamour_color(glamour: int) -> Color:
	if glamour >= 1000:
		return Color("ffd166")
	if glamour >= 100:
		return Color("c792ff")
	if glamour >= 50:
		return Color("5a8ae0")
	if glamour >= 10:
		return Color("7dde8a")
	return Color("6f6f78")


func _buy_ware(w: Dictionary) -> void:
	var data_name := ""
	var price := 0
	var buying_for := ""
	if w["kind"] == "item":
		var item: ItemData = GameData.load_item(w["id"])
		data_name = item.item_name
		price = item.price
	elif w["kind"] == "clothing":
		var cloth: ClothingData = GameData.load_clothing(w["id"])
		data_name = cloth.clothing_name
		price = cloth.price
		buying_for = cloth.owner_id
		if GameState.is_clothing_owned(buying_for, w["id"]):
			_menu_result.text = "这件衣装已经在衣柜里了。"
			return
	else:
		var eq: EquipData = GameData.load_equip(w["id"])
		data_name = eq.equip_name
		price = eq.price
	if not GameState.try_spend(price):
		_menu_result.text = "金币不够……"
		return
	if w["kind"] == "item":
		GameState.add_item(w["id"])
	elif w["kind"] == "clothing":
		GameState.add_clothing(buying_for, w["id"])
	else:
		GameState.add_equip(w["id"])
	Audio.play_sfx("coin")
	if w["kind"] == "clothing":
		var cloth: ClothingData = GameData.load_clothing(w["id"])
		_menu_result.text = "买下了 %s（华丽度 +%d）。%s的称号：%s" % [
			data_name, cloth.glamour, MEMBER_NAMES.get(buying_for, buying_for),
			GameState.fashion_title(buying_for)]
	else:
		_menu_result.text = "买下了 %s。" % data_name
	GameEvents.party_status_changed.emit()  # 刷新 HUD 金币
	_refresh_shop()


## —— 背包：使用消耗品 / 穿戴装备 ——

var _bag_box: VBoxContainer  # 滚动区内的背包列表（随刷新重建）
var _pending_bag_item := ""


## 背包装在滚动容器里，「衣柜/关闭」固定底部——物品多时不溢出屏幕。
## 衣柜入口常驻背包：爱美之心不问场合（试玩期"只在杂货铺"的限制取消）。
func _open_bag() -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	var body: VBoxContainer = _menu_base("背包", 480)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_box = VBoxContainer.new()
	_bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bag_box)
	body.add_child(scroll)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	var wardrobe_btn := Button.new()
	wardrobe_btn.text = "衣柜 · 更换衣装"
	wardrobe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wardrobe_btn.pressed.connect(func() -> void:
		_close_rest_menu()
		_open_wardrobe("bag")
	)
	footer.add_child(wardrobe_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭（Esc）"
	close_btn.pressed.connect(_close_rest_menu)
	footer.add_child(close_btn)
	body.add_child(footer)
	_refresh_bag()


func _refresh_bag() -> void:
	for child in _bag_box.get_children():
		child.queue_free()
	_menu_message(_bag_box)
	# —— 消耗品 ——
	_bag_section(_bag_box, "消耗品")
	if GameState.items.is_empty():
		_bag_empty_hint(_bag_box, "（空空如也）")
	for item_id in GameState.items:
		var item: ItemData = GameData.load_item(item_id)
		if item == null:
			continue
		var btn := _bag_item_button(item.item_name, item.effect_text(), _item_kind_color(item),
				GameState.items[item_id], _pick_field_target.bind(item_id))
		_bag_box.add_child(btn)
	# —— 成员装备（点击卸下，可再分配 = 更选）——
	_bag_section(_bag_box, "成员装备 · 点击卸下")
	var any_worn := false
	for m in GameState.party:
		for slot in m.equips:
			any_worn = true
			var eq: EquipData = GameData.load_equip(m.equips[slot])
			if eq == null:
				continue
			var btn := _bag_item_button("%s · %s：%s" % [m.char_name, eq.slot_name(), eq.equip_name],
					"%s（点击卸下回背包）" % eq.bonus_text(), Color("c8b04a"), 1,
					_unequip_member.bind(m, slot))
			_bag_box.add_child(btn)
	if not any_worn:
		_bag_empty_hint(_bag_box, "（成员们还没有穿戴装备）")
	# —— 背包装备（点击穿戴）——
	_bag_section(_bag_box, "背包装备 · 点击为成员穿戴")
	if GameState.equip_bag.is_empty():
		_bag_empty_hint(_bag_box, "（未携带装备）")
	for equip_id in GameState.equip_bag:
		var eq: EquipData = GameData.load_equip(equip_id)
		if eq == null:
			continue
		var btn := _bag_item_button("%s（%s）" % [eq.equip_name, eq.slot_name()], eq.bonus_text(),
				Color("c8b04a"), 1, _pick_equip_target.bind(equip_id))
		_bag_box.add_child(btn)
	# —— 衣装（点击直达衣柜更换）——
	_bag_section(_bag_box, "衣装 · 点击前往衣柜更换")
	for member_id in MEMBER_WARDROBE_SLOTS:
		for clothing_id in GameState.owned_clothes.get(member_id, []):
			var c: ClothingData = GameData.load_clothing(clothing_id)
			if c == null:
				continue
			var worn: bool = str(GameState.worn_clothes.get(member_id, {}).get(c.slot, "")) == clothing_id
			var who := "" if member_id == "mo_fan" else "穆宁雪 · "
			var btn := _bag_item_button(
					who + c.clothing_name + ("（穿着中）" if worn else ""),
					"%s · 华丽度 +%d（点击前往衣柜）" % [c.slot_name(), c.glamour],
					_glamour_color(c.glamour), 1,
					func() -> void:
						_close_rest_menu()
						_open_wardrobe("bag"))
			_bag_box.add_child(btn)
	_focus_menu()  # 「关闭」已在 _open_bag 固定于滚动区外


## 空状态的置灰居中提示行。
func _bag_empty_hint(box: VBoxContainer, text: String) -> void:
	var empty := Label.new()
	empty.text = text
	empty.add_theme_font_size_override("font_size", 12)
	empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(empty)


## 卸下成员身上的一件装备回背包（配合背包装备行实现更选）。
func _unequip_member(m: CharacterState, slot: String) -> void:
	var old: String = m.equips.get(slot, "")
	if old == "":
		return
	m.equips.erase(slot)
	GameState.add_equip(old)
	m.hp = mini(m.hp, m.eff_max_hp())
	m.mp = mini(m.mp, m.eff_max_mp())
	Audio.play_sfx("ui_confirm")
	GameEvents.party_status_changed.emit()
	_refresh_bag()


## 分节头：金菱 + 金字 + 渐隐饰线。
func _bag_section(box: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var gem := Label.new()
	gem.text = "◆"
	gem.add_theme_font_size_override("font_size", 12)
	gem.add_theme_color_override("font_color", Color("ffd166"))
	row.add_child(gem)
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", Color("ffd166"))
	row.add_child(lb)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.82, 0.4, 0.22)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	box.add_child(row)


## 物品行按钮：左侧类型色标 + 名称/数量 + 次行说明；外观由菜单主题接管。
func _bag_item_button(title: String, sub: String, chip_color: Color, count: int, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = chip_color
	chip_style.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.custom_minimum_size = Vector2(7, 0)
	chip.size_flags_vertical = Control.SIZE_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lb := Label.new()
	name_lb.text = title
	name_lb.add_theme_font_size_override("font_size", 14)
	name_lb.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_lb)
	if count > 1:
		var count_lb := Label.new()
		count_lb.text = "×%d" % count
		count_lb.add_theme_font_size_override("font_size", 13)
		count_lb.add_theme_color_override("font_color", Color("ffd166"))
		count_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(count_lb)
	col.add_child(name_row)
	var sub_lb := Label.new()
	sub_lb.text = sub
	sub_lb.add_theme_font_size_override("font_size", 11)
	sub_lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	sub_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub_lb)
	row.add_child(col)
	btn.add_child(row)
	btn.pressed.connect(on_press)
	return btn


## 物品类型 → 色标颜色（血红/魔蓝/复活金，未知归紫）。
func _item_kind_color(item: ItemData) -> Color:
	match item.kind:
		"heal_hp":
			return Color("e0655a")
		"heal_mp":
			return Color("5a8ae0")
		"revive":
			return Color("ffd166")
	return Color("9a8fd0")


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
	elif _menu == null and not _event_running and not _cooling and event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_bag()
	elif _menu == null and not _event_running and not _cooling and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_system_menu()


## —— 系统菜单（Esc 呼出）：继续 / 背包 / 回主菜单 / 退出 ——

func _open_system_menu() -> void:
	if _menu != null or _event_running:
		return
	player.input_enabled = false
	var box := _menu_base("系统菜单")
	var note := _menu_message(box)
	note.add_theme_font_size_override("font_size", 12)
	note.text = "未存档的进度会丢失。存档请到篝火处。"

	var resume_btn := Button.new()
	resume_btn.text = "继续旅程"
	resume_btn.pressed.connect(_close_rest_menu)
	box.add_child(resume_btn)

	var bag_btn := Button.new()
	bag_btn.text = "背包（I/Tab）"
	bag_btn.pressed.connect(func() -> void:
		_close_rest_menu()
		_open_bag()
	)
	box.add_child(bag_btn)

	var title_btn := Button.new()
	title_btn.text = "回到主菜单"
	title_btn.pressed.connect(_return_to_title)
	box.add_child(title_btn)

	var quit_btn := Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	_focus_menu()


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://src/main/main.tscn")
