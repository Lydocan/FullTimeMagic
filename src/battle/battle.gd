extends Node2D
## 回合制战斗：星辰增幅（星辉）+ 魔盾破魔，歧路旅人式指令战斗。
##
## 设计见 docs/gameplay.md。逻辑函数与 UI 分离：
## tools/smoke_test.tscn 通过 run_simulation() 直接驱动战斗逻辑做无头验证。

enum Phase { INTRO, COMMAND, SPELL_SELECT, ITEM_SELECT, TARGET, RESOLVING, ENEMY, VICTORY, DEFEAT }

## 按路径引用单位视图脚本：不依赖 class_name 全局缓存，
## 避免 .godot 缓存过期时改动不生效（项目既有坑，见 map_base 注释）。
const BattleActorScript := preload("res://src/battle/battle_actor.gd")

const WORLD_SCENE := "res://src/world/test_wilds/test_wilds.tscn"
const BG_TEXTURE := "res://assets/images/battle_bg_proto.png"

## —— 界面设计变量（深紫夜色 + 金色强调，与探索 HUD 同一观感体系） ——
const COL_PANEL_BG := Color(0.055, 0.04, 0.11, 0.94)
const COL_PANEL_EDGE := Color(0.48, 0.38, 0.72, 0.55)
const COL_GOLD := Color("ffd166")
const COL_STAR := Color("c792ff")
const COL_HP := Color("c0504d")
const COL_MP := Color("4f7dc9")
const COL_DMG := Color("ff6b5e")
const COL_HEAL := Color("7dde8a")

## 每回合行动者积攒的星辉上限（出招时消耗，1 点 = 法术 +1 段）。
const MAX_STARS := 3

var _party: Array[CharacterState] = []
var _party_actors: Array[BattleActorScript] = []
var _enemies: Array[Dictionary] = []  # {data, hp, shield, broken, burn, paralyzed, discovered, actor}
var _order: Array[Dictionary] = []    # {"side": "party"/"enemy", "index": int}
var _turn := 0
var _phase := Phase.INTRO
var _member: CharacterState
var _spell: SpellData
var _boost := 0
var _target_entry := -1

# UI 引用
var _cmd_root: Control
var _spell_box: VBoxContainer
var _cmd_buttons: Array[Button] = []
var _spell_buttons: Array[Button] = []
var _last_spell_index := 0
var _info_label: Label
var _rank_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _stars_label: Label
var _boost_value: Label
var _log_label: Label
var _order_box: HBoxContainer
var _order_chips: Array[Label] = []
var _target_hint: Label
# 演出层：震屏 / 闪光 / 濒死红晕 / 伤害数字
var _fx_layer: CanvasLayer
var _vignette: TextureRect
var _shake_amt := 0.0


func _ready() -> void:
	_party.clear()
	if GameState.pending_party_ids.is_empty():
		_party = GameState.party.duplicate()
	else:
		# 出战成员子集（毕业决斗等）：未部署成员观战，不参战、不结算
		for m in GameState.party:
			if m.id in GameState.pending_party_ids:
				_party.append(m)
	for m in _party:
		m.reset_battle_state()
	_build_background()
	_spawn_enemies()
	_spawn_party_actors()
	_build_ui()
	_log("遭遇妖魔：%s" % "、".join(_enemy_names()))
	_stamp("遭 遇 战", Color("ff8a7a"))
	Audio.play_bgm("battle")
	_start_round()


## —— 场景构建 ——

func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.size = Vector2(1280, 720)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)


func _spawn_enemies() -> void:
	var ids: Array = GameState.pending_enemies
	if ids.is_empty():
		ids = ["rat_swarm"]
	for i in ids.size():
		var data := GameData.load_monster(ids[i])
		var actor := BattleActorScript.new()
		actor.setup(load(data.texture_path), data.monster_name, data.sprite_scale)
		actor.position = Vector2(640 + (i - (ids.size() - 1) * 0.5) * 220.0, 210)
		actor.set_weaknesses(data.weaknesses, [])
		add_child(actor)
		# 登场演出：自上方压入场 + 落地震屏，错峰登场压出压迫感
		var target := actor.position
		actor.position = target + Vector2(0, -70)
		actor.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.08 + i * 0.14)
		tw.tween_callback(func() -> void: Audio.play_sfx("encounter"))
		tw.set_parallel(true)
		tw.tween_property(actor, "position", target, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(actor, "modulate:a", 1.0, 0.22)
		_enemies.append({
			"data": data, "hp": data.max_hp, "shield": data.shield,
			"broken": false, "burn": 0, "paralyzed": false, "discovered": [],
			"actor": actor,
		})
	_shake(6.0)


func _spawn_party_actors() -> void:
	var textures := ["res://assets/images/char_mofan.png", "res://assets/images/char_muningxue.png"]
	for i in _party.size():
		var actor := BattleActorScript.new()
		var tex_path: String = textures[i] if i < textures.size() else textures[0]
		actor.setup(load(tex_path), _party[i].char_name, 2.2)
		actor.position = Vector2(500 + i * 260.0, 480)
		actor.set_shield(0, 0)
		add_child(actor)
		_party_actors.append(actor)


func _build_ui() -> void:
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 5
	add_child(_fx_layer)
	_build_gradation()
	_build_vignette()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# 顶部左：行动顺序铭牌（当前行动者金色高亮）
	_order_box = HBoxContainer.new()
	_order_box.position = Vector2(16, 10)
	_order_box.add_theme_constant_override("separation", 6)
	layer.add_child(_order_box)

	# 顶部右：操作提示
	var keys_hint := Label.new()
	keys_hint.text = "方向键/WASD 选择 · 回车/E 确认 · Z 循环增幅 · Esc 返回"
	keys_hint.add_theme_font_size_override("font_size", 12)
	keys_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	keys_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	keys_hint.add_theme_constant_override("outline_size", 3)
	keys_hint.position = Vector2(1280 - 420, 12)
	layer.add_child(keys_hint)

	_target_hint = Label.new()
	_target_hint.position = Vector2(340, 40)
	_target_hint.add_theme_font_size_override("font_size", 15)
	_target_hint.add_theme_color_override("font_color", COL_GOLD)
	_target_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_target_hint.add_theme_constant_override("outline_size", 4)
	_target_hint.text = "选择目标：←→ 切换 · 回车 确认 · Esc 返回（鼠标点击亦可）"
	_target_hint.visible = false
	layer.add_child(_target_hint)

	# 战报行：底部指令台上方居中
	_log_label = Label.new()
	_log_label.position = Vector2(40, 536)
	_log_label.size = Vector2(1200, 24)
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_log_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_log_label)

	# 底部指令台：成员卡 │ 指令 │ 法术+增幅 一体化面板
	_cmd_root = Control.new()
	_cmd_root.position = Vector2(16, 566)
	layer.add_child(_cmd_root)

	var deck := PanelContainer.new()
	deck.custom_minimum_size = Vector2(1248, 144)
	_style_panel(deck)
	_cmd_root.add_child(deck)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	deck.add_child(row)

	# 左：当前行动成员卡
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(292, 0)
	card.add_theme_constant_override("separation", 2)
	row.add_child(card)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 17)
	card.add_child(_info_label)
	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 13)
	card.add_child(_rank_label)
	var hp_pack := _bar(COL_HP)
	_hp_bar = hp_pack["bar"]
	_hp_text = hp_pack["text"]
	card.add_child(_hp_bar)
	var mp_pack := _bar(COL_MP)
	_mp_bar = mp_pack["bar"]
	_mp_text = mp_pack["text"]
	card.add_child(_mp_bar)
	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 14)
	_stars_label.add_theme_color_override("font_color", COL_STAR)
	card.add_child(_stars_label)

	# 中：指令
	var cmd_panel := VBoxContainer.new()
	cmd_panel.custom_minimum_size = Vector2(204, 0)
	cmd_panel.add_theme_constant_override("separation", 3)
	row.add_child(cmd_panel)
	_add_cmd_button(cmd_panel, "法术", _open_spell_list)
	_add_cmd_button(cmd_panel, "道具", _open_battle_items)
	_add_cmd_button(cmd_panel, "切换形态", _on_switch_form)
	_add_cmd_button(cmd_panel, "防御（+1 星辉）", _on_defend)
	_add_cmd_button(cmd_panel, "逃跑", _on_flee)

	# 右：法术列表 + 星辉增幅
	var sbox := VBoxContainer.new()
	sbox.custom_minimum_size = Vector2(680, 0)
	sbox.add_theme_constant_override("separation", 2)
	row.add_child(sbox)
	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 8)
	sbox.add_child(boost_row)
	var boost_down := _mk_btn("▼", 13)
	boost_down.pressed.connect(func() -> void: _adjust_boost(-1))
	boost_row.add_child(boost_down)
	_boost_value = Label.new()
	_boost_value.add_theme_font_size_override("font_size", 14)
	_boost_value.add_theme_color_override("font_color", COL_STAR)
	boost_row.add_child(_boost_value)
	var boost_up := _mk_btn("Z 循环增幅", 13)
	boost_up.pressed.connect(_cycle_boost)
	boost_row.add_child(boost_up)
	var boost_note := Label.new()
	boost_note.text = "每点星辉 = 法术 +1 段"
	boost_note.add_theme_font_size_override("font_size", 11)
	boost_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	boost_row.add_child(boost_note)
	_spell_box = VBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 2)
	sbox.add_child(_spell_box)

	_hide_command()


## 氛围渐变：上下压暗（占位背景太亮太素，压出战场阴影感，UI 区也更聚焦）。
func _build_gradation() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.62, 1.0])
	g.colors = PackedColorArray([
		Color(0.02, 0.01, 0.05, 0.72),
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.0),
		Color(0.02, 0.01, 0.05, 0.85),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 64
	tex.height = 64
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(rect)


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_offset(0, 0.55)
	g.set_color(0, Color(0.55, 0.04, 0.04, 0.0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(0.55, 0.04, 0.04, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, -0.1)
	tex.width = 640
	tex.height = 360
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_fx_layer.add_child(_vignette)


func _process(delta: float) -> void:
	# 震屏衰减（只摇世界层，UI 层稳如桌面）
	if _shake_amt > 0.15:
		_shake_amt = lerpf(_shake_amt, 0.0, 9.0 * delta)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amt
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	# 濒死红晕：有人血线告急就持续脉动
	var crit := false
	for m in _party:
		if m.hp > 0 and m.hp < m.eff_max_hp() * 0.28:
			crit = true
	var target_a := (0.7 + 0.3 * sin(Time.get_ticks_msec() / 180.0)) if crit else 0.0
	_vignette.modulate.a = lerpf(_vignette.modulate.a, target_a, 4.0 * delta)


## —— 样式与演出辅助 ——

func _style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL_BG
	sb.border_color = COL_PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.1, 0.22, 0.9)
	normal.border_color = Color(0.4, 0.3, 0.62, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.15, 0.34, 0.95)
	hover.border_color = COL_GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.3, 0.22, 0.48, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.1, 0.09, 0.14, 0.6)
	disabled.border_color = Color(0.3, 0.3, 0.36, 0.4)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = COL_GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", focus)


func _mk_btn(text: String, font_size := 14) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	_style_button(btn)
	return btn


func _bar(fill_color: Color) -> Dictionary:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 17)
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
	return {"bar": bar, "text": text}


func _add_cmd_button(parent: Node, text: String, action: Callable) -> void:
	var btn := _mk_btn(text, 14)
	btn.pressed.connect(action)
	parent.add_child(btn)
	_cmd_buttons.append(btn)


## 伤害/回复数字：从单位头顶飘起消散。
func _popup(pos: Vector2, text: String, color: Color, size := 20) -> void:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("outline_size", 5)
	lb.position = pos + Vector2(randf_range(-16, 16), -36)
	lb.z_index = 60
	add_child(lb)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", lb.position.y - 48.0, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lb.queue_free)


func _shake(strength: float) -> void:
	_shake_amt = maxf(_shake_amt, strength)


func _flash_screen(color: Color, dur := 0.28) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, dur)
	tw.tween_callback(rect.queue_free)


## 大字盖章：破魔/胜利等关键演出，缩放砸下再消隐。
func _stamp(text: String, color: Color) -> void:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 58)
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("outline_size", 10)
	lb.set_anchors_preset(Control.PRESET_CENTER)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.z_index = 70
	_fx_layer.add_child(lb)
	lb.reset_size()
	lb.pivot_offset = lb.size / 2.0
	lb.scale = Vector2(1.6, 1.6)
	lb.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lb, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(0.45)
	tw.chain().tween_property(lb, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(lb.queue_free)


## —— 元素法术演出 ——
## 每段命中对应一道特效：雷=天降闪电、火=火球抛射爆裂、冰=冰棱突起、
## 其余=白刃横扫。约定见 design.md「战斗演出基调」：出手必须可读。
## 特效在命中瞬间返回，余韵（消隐、火花）自行播放不阻塞结算。

## 无头冒烟置真：跳过特效体只留节拍，回归测试时长保持稳定。
var _fx_mute := false

## 一波演出：多目标错峰 0.1s 依次落下（落雷扫过全体的观感）。
## 特效全部用 tween 排程（不用协程），本函数只在末发命中点 await 一次，
## 结算伤害与此刻对齐；余韵（消隐、火星）自行播放不阻塞。
func _cast_fx(element: int, from_pos: Vector2, to_points: Array) -> void:
	if _fx_mute:
		await _pause(0.05)
		return
	if to_points.is_empty():
		return
	var last := 0.1 * (to_points.size() - 1)
	for i in to_points.size():
		match element:
			GameTypes.Element.LIGHTNING:
				_spawn_bolt(to_points[i], i * 0.1)
			GameTypes.Element.FIRE:
				_spawn_fireball(from_pos, to_points[i], i * 0.1)
			GameTypes.Element.ICE:
				_spawn_ice(to_points[i], i * 0.1)
			_:
				_spawn_slash(to_points[i], i * 0.1)
	# 火球飞行最久（0.2s）：末发落点炸开即返回
	await _pause(last + (0.24 if element == GameTypes.Element.FIRE else 0.12))


## 径向光斑贴图（爆闪/火球通用）：白核向元素色透明过渡。
func _glow_tex(color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex


## 爆闪：光斑在 pos 炸开（放大 + 消隐），雷击/火球/冰棱的落点反馈。
func _fx_burst(pos: Vector2, color: Color, size: float) -> void:
	var s := Sprite2D.new()
	s.texture = _glow_tex(color)
	s.position = pos
	s.scale = Vector2.ONE * size * 0.4
	s.z_index = 40
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * size, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(s.queue_free)


## 雷：闪电自天顶而降——9 段折线 + 逐点抖动，终点锁定目标。
## 辉光层 + 白核双层描线；到点瞬间显形、雷鸣、震屏、爆闪。
func _spawn_bolt(to_pos: Vector2, delay: float) -> void:
	var start := Vector2(to_pos.x + randf_range(-52, 52), -36)
	var pts := PackedVector2Array([start])
	for i in range(1, 10):
		var t := float(i) / 9.0
		var jitter := 0.0 if i == 9 else randf_range(-17.0, 17.0)
		pts.append(Vector2(lerpf(start.x, to_pos.x, t) + jitter, lerpf(start.y, to_pos.y, t)))
	for cfg in [[9.0, Color(0.31, 0.8, 0.88, 0.5)], [3.2, Color(0.95, 0.99, 1.0, 0.95)]]:
		var line := Line2D.new()
		line.points = pts
		line.width = cfg[0]
		line.default_color = cfg[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = 40
		line.modulate.a = 0.0
		add_child(line)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(line, "modulate:a", 1.0, 0.03)
		tw.tween_interval(0.06)
		tw.tween_property(line, "modulate:a", 0.0, 0.22)
		tw.tween_callback(line.queue_free)
	var impact := create_tween()
	impact.tween_interval(delay + 0.04)
	impact.tween_callback(func() -> void: Audio.play_sfx("spell_thunder"))
	impact.tween_callback(func() -> void: _fx_burst(to_pos, Color(0.62, 0.9, 1.0), 1.5))
	impact.tween_callback(func() -> void: _shake(8.0))


## 火：火球自施法者抛出（二次贝塞尔弧线），落点爆裂 + 火星四溅。
func _spawn_fireball(from_pos: Vector2, to_pos: Vector2, delay: float) -> void:
	var ball := Sprite2D.new()
	ball.texture = _glow_tex(Color(1.0, 0.52, 0.12))
	ball.position = from_pos + Vector2(0, -18)
	ball.scale = Vector2(0.55, 0.55)
	ball.z_index = 40
	add_child(ball)
	var a := ball.position
	var m := (from_pos + to_pos) * 0.5 + Vector2(0, -64)
	var b := to_pos
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: Audio.play_sfx("spell_fire"))
	tw.tween_method(_set_bezier.bind(a, m, b, ball), 0.0, 1.0, 0.2)
	tw.tween_callback(func() -> void: _explode_fireball(ball, to_pos))


## 二次贝塞尔插值：火球沿弧线飞行（bind 携带端点与球体）。
func _set_bezier(t: float, a: Vector2, m: Vector2, b: Vector2, ball: Sprite2D) -> void:
	ball.position = a.lerp(m, t).lerp(m.lerp(b, t), t)


## 火球落点：爆闪 + 震屏 + 六道火星向外飞散。
func _explode_fireball(ball: Sprite2D, to_pos: Vector2) -> void:
	ball.queue_free()
	_fx_burst(to_pos, Color(1.0, 0.6, 0.2), 1.7)
	_shake(6.0)
	for i in 6:
		var dir := Vector2.RIGHT.rotated(TAU * i / 6.0 + randf_range(-0.3, 0.3))
		var spark := Line2D.new()
		spark.points = PackedVector2Array([to_pos, to_pos + dir * randf_range(16.0, 26.0)])
		spark.width = 2.0
		spark.default_color = Color(1.0, 0.68, 0.3, 0.9)
		spark.z_index = 40
		add_child(spark)
		var stw := create_tween()
		stw.set_parallel(true)
		stw.tween_property(spark, "position", dir * 26.0, 0.26).set_ease(Tween.EASE_OUT)
		stw.tween_property(spark, "modulate:a", 0.0, 0.26)
		stw.chain().tween_callback(spark.queue_free)


## 冰：三根冰棱自目标脚下错峰突起（三角形 Polygon2D），碎冰光斑收尾。
func _spawn_ice(to_pos: Vector2, delay: float) -> void:
	var ground := to_pos + Vector2(0, 24)
	var sfx := create_tween()
	sfx.tween_interval(delay)
	sfx.tween_callback(func() -> void: Audio.play_sfx("spell_ice"))
	for i in 3:
		var spike := Polygon2D.new()
		var h := randf_range(20.0, 30.0)
		spike.polygon = PackedVector2Array([
			Vector2(-5, 0), Vector2(5, 0), Vector2(0, -h),
		])
		spike.color = Color(0.75, 0.91, 1.0, 0.92)
		spike.position = ground + Vector2((i - 1) * 15.0 + randf_range(-3.0, 3.0), 0)
		spike.z_index = 40
		spike.scale = Vector2(1.0, 0.1)
		spike.modulate.a = 0.0
		add_child(spike)
		var tw := create_tween()
		tw.tween_interval(delay + 0.04 * i)
		tw.set_parallel(true)
		tw.tween_property(spike, "scale:y", 1.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(spike, "modulate:a", 0.92, 0.05)
		tw.chain().tween_interval(0.1)
		tw.chain().tween_property(spike, "modulate:a", 0.0, 0.22)
		tw.chain().tween_callback(spike.queue_free)
	var burst := create_tween()
	burst.tween_interval(delay + 0.08)
	burst.tween_callback(func() -> void: _fx_burst(ground + Vector2(0, -14), Color(0.7, 0.9, 1.0), 1.1))


## 兜底：白刃弧光横掠目标（无属/物理感）。
func _spawn_slash(to_pos: Vector2, delay: float) -> void:
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for i in 13:
		var ang := PI * (0.12 + 0.76 * i / 12.0)
		pts.append(to_pos + Vector2(cos(ang), -sin(ang)) * Vector2(36, 24))
	line.points = pts
	line.width = 3.0
	line.default_color = Color(1, 1, 1, 0.9)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 40
	line.modulate.a = 0.0
	add_child(line)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(line, "modulate:a", 0.9, 0.05)
	tw.tween_property(line, "position:x", 10.0, 0.14)
	tw.chain().tween_property(line, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(line.queue_free)


## —— 回合流转 ——

func _start_round() -> void:
	_order.clear()
	for i in _party.size():
		if _party[i].hp > 0:
			_order.append({"side": "party", "index": i})
	for i in _enemies.size():
		if _enemies[i]["hp"] > 0:
			_order.append({"side": "enemy", "index": i})
	_order.sort_custom(func(a, b): return _speed_of(a) > _speed_of(b))
	_turn = 0
	for m in _party:
		if m.hp > 0:
			m.battle_stars = mini(m.battle_stars + 1, MAX_STARS)
	_update_order_label()
	_next_turn()


func _speed_of(entry: Dictionary) -> int:
	if entry["side"] == "party":
		return _party[entry["index"]].speed
	return _enemies[entry["index"]]["data"].speed


## 行动顺序铭牌：一枚单位一枚圆角铭牌，轮到谁谁亮金。
func _update_order_label() -> void:
	for chip in _order_chips:
		chip.queue_free()
	_order_chips.clear()
	for entry in _order:
		var name_text: String
		var color: Color
		if entry["side"] == "party":
			name_text = _party[entry["index"]].char_name
			color = Color("9fd8ff")
		else:
			name_text = _enemies[entry["index"]]["data"].monster_name
			color = Color("ff9d8a")
		var chip := Label.new()
		chip.text = name_text
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_color_override("font_color", color)
		chip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		chip.add_theme_constant_override("outline_size", 3)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.04, 0.1, 0.75)
		sb.border_color = Color(0.4, 0.3, 0.62, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 9
		sb.content_margin_right = 9
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		chip.add_theme_stylebox_override("normal", sb)
		_order_box.add_child(chip)
		_order_chips.append(chip)


func _mark_order_turn() -> void:
	for i in _order_chips.size():
		if i == _turn:
			_order_chips[i].add_theme_color_override("font_color", COL_GOLD)
			_order_chips[i].add_theme_font_size_override("font_size", 15)
		else:
			var entry: Dictionary = _order[i] if i < _order.size() else {}
			var alive: bool = not entry.is_empty() and (
				(entry["side"] == "party" and _party[entry["index"]].hp > 0)
				or (entry["side"] == "enemy" and _enemies[entry["index"]]["hp"] > 0))
			var base_color := Color("9fd8ff") if entry.get("side") == "party" else Color("ff9d8a")
			_order_chips[i].add_theme_color_override("font_color", base_color if alive else Color(0.5, 0.5, 0.5, 0.6))
			_order_chips[i].add_theme_font_size_override("font_size", 13)


func _next_turn() -> void:
	if _turn >= _order.size():
		_end_of_round()
		return
	_mark_order_turn()
	var cur: Dictionary = _order[_turn]
	if cur["side"] == "party":
		var m := _party[cur["index"]]
		if m.hp <= 0:
			_advance()
		elif m.paralyzed:
			m.paralyzed = false
			_log("%s 麻痹中，无法行动！" % m.char_name)
			_advance()
		else:
			_begin_command(m)
	else:
		var e: Dictionary = _enemies[cur["index"]]
		if e["hp"] <= 0:
			_advance()
		elif e["paralyzed"]:
			e["paralyzed"] = false
			_log("%s 麻痹中，无法行动！" % e["data"].monster_name)
			_advance()
		elif e["broken"]:
			e["broken"] = false
			e["shield"] = e["data"].shield
			e["actor"].set_shield(e["shield"], e["data"].shield)
			_log("%s 重整魔盾。" % e["data"].monster_name)
			_advance()
		else:
			_enemy_act(e)


func _advance() -> void:
	_turn += 1
	if _check_battle_end():
		return
	_next_turn()


func _end_of_round() -> void:
	# 燃烧结算
	for m in _party:
		if m.hp > 0 and m.burn_turns > 0:
			m.burn_turns -= 1
			m.change_hp(-8)
			_log("%s 被燃烧灼伤（8 伤害）。" % m.char_name)
	for e in _enemies:
		if e["hp"] > 0 and e["burn"] > 0:
			e["burn"] -= 1
			e["hp"] = maxi(e["hp"] - 8, 0)
			_log("%s 被燃烧灼伤（8 伤害）。" % e["data"].monster_name)
			if e["hp"] <= 0:
				e["actor"].fade_out()
	_sync_all()
	if _check_battle_end():
		return
	_start_round()


## —— 玩家指令 ——

func _begin_command(m: CharacterState) -> void:
	_member = m
	_phase = Phase.COMMAND
	_boost = 0
	_show_command(m)


func _show_command(m: CharacterState) -> void:
	_cmd_root.visible = true
	var el := m.form_element()
	_info_label.text = "%s%s" % [m.char_name, "【%s形态】" % GameTypes.element_name(el) if m.can_switch_form else ""]
	_rank_label.text = "%s系位阶：%s   速度 %d" % [GameTypes.element_name(el), m.rank_label(el), m.speed]
	_update_member_panel(m)
	_fill_spell_list(m)
	_set_cmd_buttons_enabled(true)
	if _cmd_buttons.size() > 0:
		_cmd_buttons[0].grab_focus()


func _update_member_panel(m: CharacterState) -> void:
	_hp_bar.max_value = m.eff_max_hp()
	_hp_bar.value = m.hp
	_mp_bar.max_value = m.eff_max_mp()
	_mp_bar.value = m.mp
	_hp_text.text = "HP %d/%d" % [m.hp, m.eff_max_hp()]
	_mp_text.text = "MP %d/%d" % [m.mp, m.eff_max_mp()]
	_stars_label.text = "星辉 " + "◆".repeat(m.battle_stars) + "◇".repeat(MAX_STARS - m.battle_stars)
	_refresh_boost_label()


func _fill_spell_list(m: CharacterState) -> void:
	for child in _spell_box.get_children():
		child.queue_free()
	_spell_buttons.clear()
	_last_spell_index = 0
	var el := m.form_element()
	var index := 0
	for s in m.usable_spells(el):
		var spell := s
		var spell_index := index
		var btn := _mk_btn("%s   威力%d ×%d段   MP%d%s" % [
			spell.spell_name, spell.power, spell.hits, spell.mp_cost,
			"  全体" if spell.target_all else "",
		], 13)
		btn.disabled = m.mp < spell.mp_cost
		btn.pressed.connect(func() -> void:
			_last_spell_index = spell_index
			_on_spell_chosen(spell)
		)
		_spell_box.add_child(btn)
		_spell_buttons.append(btn)
		index += 1
	var back := _mk_btn("返回", 13)
	back.pressed.connect(_back_to_command)
	_spell_box.add_child(back)


func _set_cmd_buttons_enabled(on: bool) -> void:
	for btn in _cmd_buttons:
		btn.disabled = not on


func _adjust_boost(delta: int) -> void:
	if _phase != Phase.COMMAND and _phase != Phase.SPELL_SELECT:
		return
	_boost = clampi(_boost + delta, 0, mini(_member.battle_stars, MAX_STARS))
	_refresh_boost_label()


## Z 循环星辉增幅：0 → 1 → … → 当前可用上限 → 0。
func _cycle_boost() -> void:
	if _phase != Phase.COMMAND and _phase != Phase.SPELL_SELECT:
		return
	var max_boost := mini(_member.battle_stars, MAX_STARS)
	_boost = (_boost + 1) % (max_boost + 1)
	_refresh_boost_label()


func _refresh_boost_label() -> void:
	_boost_value.text = "增幅 ×%d（Z 循环 或 ▲▼）" % _boost


func _open_spell_list() -> void:
	_phase = Phase.SPELL_SELECT
	_set_cmd_buttons_enabled(false)
	_focus_spell(_last_spell_index)


## —— 道具（战斗）——

var _pending_item := ""


## 道具 → 选目标成员 → 生效，消耗一次行动。
func _open_battle_items() -> void:
	_phase = Phase.ITEM_SELECT
	_set_cmd_buttons_enabled(false)
	for child in _spell_box.get_children():
		child.queue_free()
	_spell_buttons.clear()
	var first := true
	for item_id in GameState.items:
		var item: ItemData = GameData.load_item(item_id)
		if item == null:
			continue
		var btn := _mk_btn("%s ×%d（%s）" % [item.item_name, GameState.items[item_id], item.effect_text()], 13)
		btn.pressed.connect(_choose_battle_item.bind(item_id))
		_spell_box.add_child(btn)
		_spell_buttons.append(btn)
		if first:
			btn.grab_focus()
			first = false
	var back := _mk_btn("返回", 13)
	back.pressed.connect(_back_to_command)
	_spell_box.add_child(back)
	_spell_buttons.append(back)
	if not first:
		return
	back.grab_focus()


func _item_targets_ok(item: ItemData, m: CharacterState) -> bool:
	match item.kind:
		"heal_hp": return m.hp > 0 and m.hp < m.eff_max_hp()
		"heal_mp": return m.hp > 0 and m.mp < m.eff_max_mp()
		"revive": return m.hp <= 0
		_:
			return false


func _choose_battle_item(item_id: String) -> void:
	var item: ItemData = GameData.load_item(item_id)
	if item == null or GameState.items.get(item_id, 0) <= 0:
		return
	_pending_item = item_id
	for child in _spell_box.get_children():
		child.queue_free()
	_spell_buttons.clear()
	var hint := Label.new()
	hint.text = "对谁使用？"
	hint.add_theme_font_size_override("font_size", 13)
	_spell_box.add_child(hint)
	var first := true
	for m in _party:
		var ok := _item_targets_ok(item, m)
		var btn := _mk_btn("%s  HP %d/%d  MP %d/%d" % [m.char_name, m.hp, m.eff_max_hp(), m.mp, m.eff_max_mp()], 13)
		btn.disabled = not ok
		btn.pressed.connect(_use_battle_item.bind(m))
		_spell_box.add_child(btn)
		_spell_buttons.append(btn)
		if ok and first:
			btn.grab_focus()
			first = false
	var back := _mk_btn("返回", 13)
	back.pressed.connect(_open_battle_items)
	_spell_box.add_child(back)
	_spell_buttons.append(back)
	if first:
		back.grab_focus()


func _use_battle_item(m: CharacterState) -> void:
	var item: ItemData = GameData.load_item(_pending_item)
	if item == null or not GameState.take_item(_pending_item):
		return
	match item.kind:
		"heal_hp":
			m.change_hp(item.amount)
		"heal_mp":
			m.change_mp(item.amount)
		"revive":
			m.change_hp(m.eff_max_hp() * item.amount / 100)
			m.reset_battle_state()
	Audio.play_sfx("rest")
	_log("%s 使用了 %s（%s）。" % [_member.char_name, item.item_name, m.char_name])
	var actor := _party_actors[_party.find(m)]
	_popup(actor.position + Vector2(0, -actor._half_h), "+%d" % item.amount if item.kind != "revive" else "复苏", COL_HEAL, 22)
	_sync_all()
	_hide_command()
	_advance()


## 键盘焦点落在第一个可用（精神力足够）的法术上；找不到就退回指令菜单。
func _focus_spell(index: int) -> void:
	for i in range(clampi(index, 0, _spell_buttons.size() - 1), _spell_buttons.size()):
		if not _spell_buttons[i].disabled:
			_spell_buttons[i].grab_focus()
			return
	for btn in _spell_buttons:
		if not btn.disabled:
			btn.grab_focus()
			return


func _back_to_command() -> void:
	_phase = Phase.COMMAND
	_show_command(_member)


func _on_switch_form() -> void:
	if not _member.can_switch_form:
		return
	_member.form = (_member.form + 1) % _member.elements.size()
	var el := _member.form_element()
	_log("%s 切换为【%s形态】。" % [_member.char_name, GameTypes.element_name(el)])
	_hide_command()
	_advance()


func _on_defend() -> void:
	_member.defending = true
	_member.battle_stars = mini(_member.battle_stars + 1, MAX_STARS)
	_log("%s 摆出防御姿态。" % _member.char_name)
	_hide_command()
	_advance()


func _on_flee() -> void:
	_hide_command()
	if randf() < 0.6:
		_log("逃跑成功！")
		_finish(false, true)
	else:
		_log("逃跑失败！")
		_advance()


func _on_spell_chosen(spell: SpellData) -> void:
	_spell = spell
	if spell.target_all:
		_resolve_player_spell()
	else:
		_phase = Phase.TARGET
		_target_hint.visible = true
		_set_cmd_buttons_enabled(false)
		var alive := _alive_enemies()
		if not alive.is_empty():
			_target_entry = _enemies.find(alive[0])
		_refresh_target_highlight()


func _refresh_target_highlight() -> void:
	for i in _enemies.size():
		var e: Dictionary = _enemies[i]
		var alive: bool = e["hp"] > 0
		e["actor"].set_highlight(alive and i == _target_entry and _phase == Phase.TARGET)


func _hide_command() -> void:
	_cmd_root.visible = false
	_target_hint.visible = false
	_refresh_target_highlight()


## —— 输入（目标选择 / 点击目标） ——

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.TARGET:
		var alive := _alive_enemies()
		if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
			if alive.size() > 1:
				var idx := alive.find(_enemies[_target_entry])
				idx = (idx + 1) % alive.size() if event.is_action_pressed("ui_right") else (idx - 1 + alive.size()) % alive.size()
				_target_entry = _enemies.find(alive[idx])
				_refresh_target_highlight()
		elif event.is_action_pressed("ui_accept"):
			_target_hint.visible = false
			_resolve_player_spell()
		elif event.is_action_pressed("ui_cancel"):
			_phase = Phase.SPELL_SELECT
			_target_hint.visible = false
			_refresh_target_highlight()
			_focus_spell(_last_spell_index)
		return
	if _phase == Phase.COMMAND or _phase == Phase.SPELL_SELECT:
		# 全键盘：WASD=方向键导航（ui_* 映射），回车/E=确认，Z 循环增幅，Esc 返回指令菜单
		if event.is_action_pressed("boost_cycle"):
			_cycle_boost()
			get_viewport().set_input_as_handled()
		elif _phase == Phase.SPELL_SELECT and event.is_action_pressed("ui_cancel"):
			_back_to_command()
			get_viewport().set_input_as_handled()
	elif _phase == Phase.ITEM_SELECT and event.is_action_pressed("ui_cancel"):
		_back_to_command()
		get_viewport().set_input_as_handled()
	if _phase == Phase.COMMAND and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for e in _enemies:
				if e["hp"] > 0 and e["actor"].position.distance_to(get_global_mouse_position()) < 90.0:
					var known := []
					for el in e["discovered"]:
						known.append(GameTypes.element_name(el))
					_log("%s：已探明弱点 %s" % [
						e["data"].monster_name,
						"、".join(known) if known.size() > 0 else "未知（命中弱点后揭示）",
					])
					break


## —— 结算逻辑（UI 无关，可被冒烟测试直接驱动） ——

func _resolve_player_spell() -> void:
	_phase = Phase.RESOLVING
	_hide_command()
	var m := _member
	var s := _spell
	var boost := _boost
	m.change_mp(-s.mp_cost)
	if boost > 0:
		m.battle_stars -= boost
	_boost = 0
	var hits := s.hits + boost
	_log("%s 施展「%s」%s（%d 段）" % [
		m.char_name, s.spell_name, "◆星辉增幅 " if boost > 0 else "", hits,
	])
	# 施法演出：行动者后仰起手 + 星辉增幅时紫光一闪
	var caster := _party_actors[_party.find(m)]
	caster.windup()
	if boost > 0:
		_flash_screen(Color(0.66, 0.45, 1.0, 0.22), 0.3)
	var targets: Array = _alive_enemies() if s.target_all else [_enemies[_target_entry]]
	var from_pos := caster.position + Vector2(0, -24)
	for h in hits:
		var alive := targets.filter(func(e): return e["hp"] > 0)
		if not alive.is_empty():
			# 每段命中一道元素演出：全体目标错峰落下，命中瞬间结算伤害
			await _cast_fx(s.element, from_pos, alive.map(func(e) -> Vector2:
				return e["actor"].position - Vector2(0, e["actor"]._half_h * 0.5)))
			for e in alive:
				_hit_enemy(m, e, s)
		_sync_all()
		await _pause(0.22)
	# 附加状态（每次施法判定一次）
	for e in targets:
		if e["hp"] > 0 and s.status_effect != "" and randf() < s.status_chance:
			_apply_enemy_status(e, s.status_effect)
	_sync_all()
	_advance()


func _hit_enemy(user: CharacterState, e: Dictionary, s: SpellData) -> void:
	var data: MonsterData = e["data"]
	var is_weak: bool = s.element in data.weaknesses
	var raw := (s.power + user.eff_magic()) * randf_range(0.9, 1.1) - data.defense
	var dmg := maxi(1, roundi(raw))
	if e["broken"]:
		dmg = roundi(dmg * 1.5)
	if is_weak:
		if not (s.element in e["discovered"]):
			e["discovered"].append(s.element)
			e["actor"].set_weaknesses(data.weaknesses, e["discovered"])
		if e["shield"] > 0:
			e["shield"] = maxi(e["shield"] - s.break_power, 0)
			Audio.play_sfx("weak_hit")
			_log("命中弱点！%s 的魔盾被削弱。" % data.monster_name)
			if e["shield"] <= 0 and not e["broken"]:
				e["broken"] = true
				Audio.play_sfx("break")
				_log("◆ 破魔！%s 眩晕，承伤加深！" % data.monster_name)
				# 破魔大演出：金字盖章 + 白闪 + 重震
				_stamp("破 魔 ！", COL_GOLD)
				_flash_screen(Color(1.0, 0.95, 0.75, 0.4))
				_shake(13.0)
	e["hp"] = maxi(e["hp"] - dmg, 0)
	Audio.play_sfx("hit")
	_log("%s 对 %s 造成 %d 伤害%s。" % [user.char_name, data.monster_name, dmg, "（破魔）" if e["broken"] else ""])
	# 命中反馈：弱点金色大字，普伤白字；破魔状态下伤害更深用大号
	if is_weak:
		_popup(e["actor"].position + Vector2(0, -e["actor"]._half_h), "%d！" % dmg, COL_GOLD, 24)
		_shake(7.0)
	else:
		_popup(e["actor"].position + Vector2(0, -e["actor"]._half_h), str(dmg), COL_DMG if not e["broken"] else COL_GOLD, 20 if not e["broken"] else 24)
		_shake(3.5)
	if e["hp"] <= 0:
		e["actor"].fade_out()
		_popup(e["actor"].position, "击破", Color(1, 1, 1, 0.9), 18)
		_shake(6.0)
		_log("%s 被击败！" % data.monster_name)
	else:
		e["actor"].hurt()


func _apply_enemy_status(e: Dictionary, status: String) -> void:
	match status:
		"burn":
			e["burn"] = 2
			_log("%s 被点燃！" % e["data"].monster_name)
		"paralyze":
			e["paralyzed"] = true
			_log("%s 被麻痹！" % e["data"].monster_name)


func _enemy_act(e: Dictionary) -> void:
	_phase = Phase.ENEMY
	await _pause(0.3)
	var d: MonsterData = e["data"]
	# 技能判定：普攻兜底，技能表逐技掷骰先中先用（小怪一技，Boss 多技）
	var use_skill := false
	var skill: Dictionary = {"name": "撞击", "power": d.attack_power, "chance": 1.0,
			"target_all": false, "status": "", "status_chance": 0.0, "element": d.element}
	for s in d.skills:
		if randf() < float(s.get("chance", 0.2)):
			skill = s
			use_skill = true
			break
	_log("%s 使用「%s」！" % [d.monster_name, skill["name"]])
	var targets: Array = _alive_members()
	if targets.is_empty():
		return
	var victims: Array = targets if skill.get("target_all", false) else [targets.pick_random()]
	# 攻击演出：扑向首个受害者；技能按元素放出真演出（狼王咆哮=雷暴、炎爆=火球……）
	var victim: CharacterState = victims[0]
	var victim_actor := _party_actors[_party.find(victim)]
	var attacker: BattleActorScript = e["actor"]
	var dir: Vector2 = (victim_actor.global_position - attacker.global_position).normalized()
	attacker.lunge(dir)
	if use_skill:
		var el: int = int(skill.get("element", d.element))
		var victim_points: Array = []
		for v in victims:
			var a: BattleActorScript = _party_actors[_party.find(v)]
			victim_points.append(a.position - Vector2(0, a._half_h * 0.5))
		await _cast_fx(el, attacker.position + Vector2(0, -attacker._half_h * 0.6), victim_points)
	await _pause(0.16)
	for m in victims:
		var raw: float = (skill["power"] + d.attack * 0.3) * randf_range(0.9, 1.1) - m.defense * 1.2
		var dmg := maxi(1, roundi(raw))
		if m.defending:
			dmg = maxi(1, roundi(dmg * 0.5))
		m.change_hp(-dmg)
		_log("%s 受到 %d 伤害。" % [m.char_name, dmg])
		var actor := _party_actors[_party.find(m)]
		actor.hurt()
		_popup(actor.position + Vector2(0, -actor._half_h), str(dmg), COL_DMG, 22)
		_shake(6.0 if not use_skill else 9.0)
		var status: String = skill.get("status", "")
		if status != "" and randf() < float(skill.get("status_chance", 1.0)):
			match status:
				"burn":
					m.burn_turns = 2
					_log("%s 被点燃！" % m.char_name)
				"paralyze":
					m.paralyzed = true
					_log("%s 被麻痹！" % m.char_name)
		if m.hp <= 0:
			_log("%s 倒下了……" % m.char_name)
	_sync_all()
	await _pause(0.2)
	_advance()


## —— 胜负与结算 ——

func _check_battle_end() -> bool:
	if _alive_enemies().is_empty():
		_win()
		return true
	if _alive_members().is_empty():
		_lose()
		return true
	return false


func _win() -> void:
	_phase = Phase.VICTORY
	_log("战斗胜利！")
	Audio.play_sfx("victory")
	_stamp("战 斗 胜 利", COL_GOLD)
	_flash_screen(Color(1.0, 0.95, 0.75, 0.3), 0.5)
	var xp_each := 0
	var gold := 0
	var essences: Array = []
	for e in _enemies:
		xp_each += e["data"].xp_value
		gold += e["data"].gold_value
		if e["data"].essence_id != "" and randf() < e["data"].essence_chance:
			essences.append(e["data"].essence_id)
	var summary := GameState.grant_battle_rewards(xp_each, gold, essences, _party)
	if GameState.pending_flag != "":
		GameState.flags[GameState.pending_flag] = true
		GameState.pending_flag = ""
	_show_result(true, xp_each, gold, essences, summary["events"])


func _lose() -> void:
	_phase = Phase.DEFEAT
	_log("队伍溃败……")
	Audio.play_sfx("defeat")
	_stamp("溃 败 ……", Color("8ecbff"))
	_vignette.modulate.a = 0.6
	_show_result(false, 0, 0, [], [])


func _finish(victory: bool, fled: bool) -> void:
	GameEvents.battle_finished.emit(victory, fled)
	GameState.pending_party_ids = []
	var target: String = GameState.battle_return_scene
	if target == "" or not ResourceLoader.exists(target):
		target = WORLD_SCENE
	GameState.battle_return_scene = ""
	get_tree().change_scene_to_file(target)


func _show_result(victory: bool, xp_each: int, gold: int, essences: Array, events: Array) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	_style_panel(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "—— 战斗胜利 ——" if victory else "—— 队伍溃败 ——"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD if victory else Color("8ecbff"))
	box.add_child(title)

	if victory:
		box.add_child(_result_label("每位成员修为 +%d    金币 +%d" % [xp_each, gold]))
		for eid in essences:
			box.add_child(_result_label("获得精魄：%s" % eid))
		for entry in events:
			var ev: Dictionary = entry["ev"]
			var m_name: String = entry["member"]
			match ev["type"]:
				"star":
					var member := _find_member(m_name)
					var el: int = ev["element"]
					box.add_child(_result_label("◆ %s %s系 星子连线 → %s" % [
						m_name, GameTypes.element_name(el),
						GameTypes.rank_text(el, ev["stage"], ev["star"]),
					]))
				"bottleneck":
					box.add_child(_result_label("★ %s 达到三星圆满，进入瓶颈（去营地突破）" % m_name))
	else:
		box.add_child(_result_label("众人力竭倒下……再睁眼，已回到上次的安歇之地。"))
		box.add_child(_result_label("（读回最近存档；尚无存档则从新的旅程开始）"))

	var btn := _mk_btn("继续（回车）" if victory else "回到存档点（回车）", 15)
	btn.pressed.connect(func() -> void:
		if not victory:
			# 战败：读回最近存档（无存档重开新旅程），永不回原地再战
			GameEvents.battle_finished.emit(false, false)
			get_tree().change_scene_to_file(SaveSystem.defeat_return_scene())
			return
		_finish(true, false)
	)
	box.add_child(btn)
	btn.grab_focus()


func _result_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l


func _find_member(member_name: String) -> CharacterState:
	for m in _party:
		if m.char_name == member_name:
			return m
	return null


## —— 工具 ——

func _alive_enemies() -> Array:
	var out := []
	for e in _enemies:
		if e["hp"] > 0:
			out.append(e)
	return out


func _alive_members() -> Array[CharacterState]:
	var out: Array[CharacterState] = []
	for m in _party:
		if m.hp > 0:
			out.append(m)
	return out


func _enemy_names() -> Array:
	var out := []
	for e in _enemies:
		out.append(e["data"].monster_name)
	return out


func _sync_all() -> void:
	for i in _party.size():
		var actor := _party_actors[i]
		var m := _party[i]
		actor.set_hp(float(m.hp) / m.eff_max_hp())
		actor.visible = m.hp > 0
	for e in _enemies:
		var a: BattleActorScript = e["actor"]
		a.set_hp(float(e["hp"]) / e["data"].max_hp)
		a.set_shield(e["shield"], e["data"].shield)
	if _phase == Phase.COMMAND or _phase == Phase.SPELL_SELECT:
		_update_member_panel(_member)


func _log(text: String) -> void:
	if _log_label != null:
		_log_label.text = text
	print("[battle] ", text)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## —— 冒烟测试入口：跳过 UI 等待，直接驱动战斗逻辑直到结束 ——

func run_simulation() -> Dictionary:
	_fx_mute = true  # 无头模拟跳过演出体，只留节拍
	var guard := 0
	var actions := 0  # 玩家出招次数（≈回合数，供平衡区间验收）
	while _phase != Phase.VICTORY and _phase != Phase.DEFEAT and guard < 800:
		guard += 1
		if _phase == Phase.COMMAND:
			actions += 1
			# 模拟决策：随机可用法术打首个存活敌人（防御兜底）
			var affordable := _member.usable_spells(_member.form_element()).filter(
				func(s: SpellData) -> bool: return s.mp_cost <= _member.mp
			)
			if affordable.is_empty():
				_member.defending = true
				_advance()
				continue
			_spell = affordable.pick_random()
			_boost = mini(1, _member.battle_stars)
			var alive := _alive_enemies()
			if alive.is_empty():
				_advance()
				continue
			_target_entry = _enemies.find(alive[0])
			await _resolve_player_spell()
		else:
			await _pause(0.05)  # 等待敌方/回合结算演出链自行推进
	return {"victory": _phase == Phase.VICTORY, "rounds": actions}
