extends Node2D
## 测试荒野：M1 核心循环原型地图。
##
## TileMap 以代码构建（原型期做法，正式版替换为编辑器制作的地图场景）：
## 移动 → 深草暗雷遇敌 → 回合制战斗 → 修为/精魄结算 → 营地休息/修炼/突破。

const TILE := 32
const MAP_W := 40
const MAP_H := 22
const CHUNK := 10  # 每段字符串的格数

const PLAYER_SCENE := preload("res://src/world/player/player.tscn")
const CAMPFIRE_SCRIPT := preload("res://src/world/test_wilds/campfire.gd")

# tiles_proto.png 的 6 格横向图块。
const T_GRASS := Vector2i(0, 0)
const T_TALL := Vector2i(1, 0)
const T_PATH := Vector2i(2, 0)
const T_TREE := Vector2i(3, 0)
const T_ROCK := Vector2i(4, 0)
const T_WATER := Vector2i(5, 0)
const BLOCKED := "TRW"

## 地图（每行 4 段 × 10 格）。T 树 R 岩石 W 水 H 深草 P 小径 G 草地。
const MAP_ROWS := [
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGHGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGRGGGGGGT",
	"TGGHHGGGGG", "HHHHHHGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGHGGGHH", "HHHHHHGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGHH", "HHHHHHGGGG", "GGGGGGWWGG", "GGGGGGGGGT",
	"TGGGGGGGHH", "HHHHGGGGGG", "GGGGGGWWWG", "GGGGGGGGGT",
	"TGGGGGGGGG", "HHHGGGGGGG", "GGGGGGWWWG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GHGGGGGGGG", "GGGGGGGWGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGHHHGGT",
	"TGGRGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGHHHHHGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGHHHHHHGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGHHHHGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGHHGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGPPGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGPPPPGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
]

const START_CELL := Vector2i(6, 20)
const CAMP_CELL := Vector2i(6, 19)
const ELITE_CELL := Vector2i(34, 14)
const ELITE_FLAG := "elite_wolf_dead"

## 暗雷遇敌表（权重随机）。
const ENCOUNTERS := [
	{"ids": ["rat_swarm"], "weight": 5},
	{"ids": ["rat_swarm", "rat_swarm"], "weight": 3},
	{"ids": ["one_eye_wolf"], "weight": 2},
	{"ids": ["rat_swarm", "one_eye_wolf"], "weight": 1},
]

var player: CharacterBody2D
var tilemap: TileMapLayer

var _encounter_gauge := 0.0
var _encounter_threshold := 200.0
var _cooling := true
var _menu: Control = null
var _menu_result: Label = null

@onready var _hud := CanvasLayer.new()


func _ready() -> void:
	_build_tilemap()
	_spawn_player()
	_spawn_campfire()
	if not GameState.flags.get(ELITE_FLAG, false):
		_spawn_elite()
	_build_hud()
	_apply_return_position()
	GameEvents.party_status_changed.connect(_refresh_hud)
	_refresh_hud()


## —— 地图 ——

func _cell_char(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_W or cell.y >= MAP_H:
		return "T"
	return MAP_ROWS[cell.y * 4 + int(cell.x / float(CHUNK))][cell.x % CHUNK]


func _build_tilemap() -> void:
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
	for y in MAP_H:
		for x in MAP_W:
			var ch := _cell_char(Vector2i(x, y))
			var coords := T_GRASS
			match ch:
				"H": coords = T_TALL
				"P": coords = T_PATH
				"T": coords = T_TREE
				"R": coords = T_ROCK
				"W": coords = T_WATER
			tilemap.set_cell(Vector2i(x, y), 0, coords)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


## —— 场景物件 ——

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = _cell_center(START_CELL)
	add_child(player)
	player.moved.connect(_on_player_moved)
	var cam: Camera2D = player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE


func _spawn_campfire() -> void:
	var fire: Area2D = CAMPFIRE_SCRIPT.new()
	fire.position = _cell_center(CAMP_CELL)
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


func _spawn_elite() -> void:
	var area := Area2D.new()
	area.position = _cell_center(ELITE_CELL)
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
		if not GameState.flags.get(ELITE_FLAG, false):
			_start_encounter(["wolf_alpha"], ELITE_FLAG)
	)
	add_child(area)


## —— 暗雷遇敌 ——

func _on_player_moved(distance: float) -> void:
	if _cooling or _menu != null:
		return
	var cell := tilemap.local_to_map(tilemap.to_local(player.global_position))
	if _cell_char(cell) == "H":
		_encounter_gauge += distance
	else:
		_encounter_gauge = maxf(_encounter_gauge - distance * 0.6, 0.0)
	if _encounter_gauge >= _encounter_threshold:
		_encounter_gauge = 0.0
		_encounter_threshold = randf_range(160.0, 280.0)
		_start_encounter(_pick_encounter(), "")


func _pick_encounter() -> Array:
	var total := 0
	for e in ENCOUNTERS:
		total += e["weight"]
	var roll := randi_range(1, total)
	for e in ENCOUNTERS:
		roll -= e["weight"]
		if roll <= 0:
			return e["ids"]
	return ENCOUNTERS[0]["ids"]


func _start_encounter(ids: Array, flag: String) -> void:
	if _menu != null:
		return
	_cooling = true
	player.input_enabled = false
	GameState.return_position = player.global_position
	GameState.has_return_position = true
	GameState.pending_enemies = ids
	GameState.pending_flag = flag
	GameEvents.encounter_started.emit(ids)
	get_tree().change_scene_to_file("res://src/battle/battle.tscn")


func _apply_return_position() -> void:
	if GameState.has_return_position:
		player.global_position = GameState.return_position
		GameState.has_return_position = false
	await get_tree().create_timer(1.2).timeout
	_cooling = false
	player.input_enabled = true


## —— HUD ——

func _build_hud() -> void:
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in GameState.party.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		GameState.party[i].set_meta("hud_label", label.get_instance_id())
	_hud.add_child(panel)

	var hint := Label.new()
	hint.text = "WASD/方向键 移动 · E 交互 · Esc 关闭菜单 · 深草区遇敌 · 篝火处休息/修炼/突破"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	hint.position = Vector2(12, get_viewport_rect().size.y - 34)
	_hud.add_child(hint)

	_wealth_label = Label.new()
	_wealth_label.add_theme_font_size_override("font_size", 13)
	_wealth_label.position = Vector2(get_viewport_rect().size.x - 300, 12)
	_hud.add_child(_wealth_label)


var _wealth_label: Label


func _refresh_hud() -> void:
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


## —— 营地菜单：休息 / 修炼 / 突破 ——

func _open_rest_menu() -> void:
	if _menu != null:
		return
	player.input_enabled = false
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)
	_menu.add_child(panel)

	var title := Label.new()
	title.text = "营地篝火"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	_menu_result = Label.new()
	_menu_result.add_theme_color_override("font_color", Color("ffd166"))
	box.add_child(_menu_result)

	var rest_btn := Button.new()
	rest_btn.text = "休息（恢复全体 HP/MP）"
	rest_btn.pressed.connect(func() -> void:
		GameState.rest_at_camp()
		_menu_result.text = "队伍在篝火旁休整，状态全满。"
		_refresh_menu()
	)
	box.add_child(rest_btn)

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

	_hud.add_child(_menu)
	_refresh_menu()
	# 键盘操作：聚焦第一个可用按钮（方向键导航、回车确认、Esc 离开）
	for node in _menu.find_children("*", "Button", true, false):
		var b := node as Button
		if b != null and not b.disabled:
			b.grab_focus()
			break


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_rest_menu()


func _apply_cultivate(m: CharacterState, el: int, amount: int) -> void:
	var events := m.gain_xp(el, amount)
	for ev in events:
		match ev["type"]:
			"dust":
				pass
			"star":
				GameEvents.star_advanced.emit(m.char_name, el, ev["stage"], ev["star"])
				_menu_result.text = "%s 星子连线！晋升%s。" % [m.char_name, m.rank_label(el)]
			"bottleneck":
				GameEvents.bottleneck_reached.emit(m.char_name, el)
				_menu_result.text = "%s 的%s系三星圆满，进入瓶颈——收集精魄方可突破。" % [m.char_name, GameTypes.element_name(el)]
	if events.is_empty():
		_menu_result.text = "静静修炼了一晚。（修为+%d）" % amount
	GameEvents.party_status_changed.emit()
	_refresh_menu()


func _refresh_menu() -> void:
	_refresh_hud()
	# 修炼按钮在瓶颈期禁用；突破按钮按精魄持有刷新。
	for btn in _menu.find_children("*", "Button", true, false):
		if btn.has_meta("cultivate_element"):
			var el: int = btn.get_meta("cultivate_element")
			btn.disabled = GameState.party[0].is_bottleneck(el)


func _close_rest_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_menu_result = null
	player.input_enabled = true
