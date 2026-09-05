class_name BattleActor
extends Node2D
## 战斗单位视图：精灵、接地影子、名牌、血条、魔盾、弱点标记、目标箭头。
## 数值状态由 battle.gd 持有，本节点只负责显示与受击/突进等演出。
## 布局按精灵缩放后的实际尺寸自适应，单位放大后名牌不糊脸。

var _sprite: Sprite2D
var _name_label: Label
var _hp_bar: ProgressBar
var _shield_label: Label
var _weak_label: Label
var _half_h := 16.0        # 缩放后精灵半高：影子/名牌的定位基准
var _bob_phase := 0.0      # 待机呼吸的相位错开，避免全场整齐划一
var _highlighted := false
var _phase_notch: ColorRect  # 二段血条的分段刻度（Boss 专用）
var _hp_fill: StyleBoxFlat


func _init() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	_name_label = _make_label(14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(110, 8)
	_hp_bar.size = Vector2(110, 8)
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c0504d")
	fill.set_corner_radius_all(2)
	_hp_fill = fill
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	add_child(_hp_bar)

	_shield_label = _make_label(12)
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_label.add_theme_color_override("font_color", Color("8ecbff"))
	add_child(_shield_label)

	_weak_label = _make_label(12)
	_weak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_weak_label)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	return l


func setup(texture: Texture2D, actor_name: String, sprite_scale := 1.0) -> void:
	_sprite.texture = texture
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_half_h = texture.get_height() * sprite_scale * 0.5
	_name_label.text = actor_name
	_bob_phase = randf() * TAU
	# 名牌组贴着精灵下缘排布：名字 / 血条 / 魔盾 / 弱点，行距拉足防粘连
	# 注意：尺寸在 _ready 统一设置——树外无主题上下文时样式盒最小高度
	# 会虚高（血条被顶到 27px），进树后才回落真实值，setup 里赋不准
	var y := _half_h + 8.0
	var steps := [22.0, 18.0, 20.0, 20.0]
	for i in 4:
		var node: Control = [_name_label, _hp_bar, _shield_label, _weak_label][i]
		node.position = Vector2(-70, y)
		y += steps[i]


func _ready() -> void:
	# 进树后重设尺寸（血条曾被树外虚高最小高度顶成 27px 高的"血块"）
	_name_label.size = Vector2(140, 0)
	_hp_bar.size = Vector2(110, 8)
	_shield_label.size = Vector2(140, 0)
	_weak_label.size = Vector2(140, 0)


func _process(_delta: float) -> void:
	# 待机呼吸：轻微上下浮沉（只动精灵，不影响突进/受击的节点级演出）
	_sprite.position.y = sin(Time.get_ticks_msec() / 1000.0 * 2.2 + _bob_phase) * 2.0
	if _highlighted:
		queue_redraw()  # 目标箭头的浮动需要逐帧重绘


## 接地影子；选中目标时头顶画金色指示箭头。
func _draw() -> void:
	draw_set_transform(Vector2(0, _half_h + 4.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, _half_h * 0.85, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _highlighted:
		var bob := sin(Time.get_ticks_msec() / 90.0) * 2.5
		var tip := Vector2(0, -_half_h - 14.0 + bob)
		var points := PackedVector2Array([
			tip, tip + Vector2(8, 12), tip + Vector2(-8, 12),
		])
		draw_colored_polygon(points, Color("ffd166"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.6), 1.5)


func set_hp(ratio: float) -> void:
	var tw := create_tween()
	tw.tween_property(_hp_bar, "value", clampf(ratio, 0.0, 1.0), 0.25)


## 二段血条：血量刻度上立一道分段金线，暗示 Boss 还有第二管血。
## 分段线跟随血条定位（setup 的名牌组排布：血条在 _half_h+30 处）。
func set_phase_marker(threshold: float) -> void:
	_phase_notch = ColorRect.new()
	_phase_notch.color = Color("ffd166")
	_phase_notch.size = Vector2(3, 12)
	_phase_notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_notch.position = Vector2(-70 + 110.0 * clampf(threshold, 0.05, 0.95) - 1.5, _half_h + 28.0)
	add_child(_phase_notch)


## 进入二阶段：血条转猩红、分段线消失、通体泛红压出狂化压迫感。
func enter_phase2() -> void:
	if _phase_notch != null:
		_phase_notch.queue_free()
		_phase_notch = null
	_hp_fill.bg_color = Color("d8304a")
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.25, 0.85, 0.85), 0.2)
	tw.tween_property(self, "modulate", Color(1.12, 0.94, 0.94), 0.3)


func set_shield(current: int, maximum: int) -> void:
	if maximum <= 0:
		_shield_label.text = ""
		return
	_shield_label.text = "魔盾 " + "◆".repeat(maxi(current, 0)) + "◇".repeat(maxi(maximum - current, 0))


## 已被探测到的弱点显示为黄色 ▲元素名。
func set_weaknesses(elements: Array, discovered: Array) -> void:
	var parts := ""
	for el in elements:
		if el in discovered:
			parts += "▲%s " % GameTypes.element_name(el)
	_weak_label.text = parts
	_weak_label.add_theme_color_override("font_color", Color("ffd166"))


func set_highlight(on: bool) -> void:
	_highlighted = on
	modulate = Color(1.35, 1.3, 1.1) if on else Color.WHITE
	queue_redraw()


## 受击：红闪 + 横向顿挫。
func hurt() -> void:
	modulate = Color(4.0, 1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 5.0, 0.04)
	tw.tween_property(self, "position:x", position.x, 0.08)
	tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.16)


## 突进攻击：向目标方向扑出一小段再弹回（敌方行动演出）。
func lunge(dir: Vector2) -> void:
	var back := position
	var tw := create_tween()
	tw.tween_property(self, "position", back + dir * 34.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", back, 0.16).set_ease(Tween.EASE_IN_OUT)


## 施法起手：微微后仰蓄力（我方施法演出）。
func windup() -> void:
	var back := position
	var tw := create_tween()
	tw.tween_property(self, "position", back + Vector2(-14, 4), 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", back, 0.14).set_ease(Tween.EASE_IN_OUT)


func flash() -> void:
	modulate = Color(3.5, 3.5, 3.5)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)


func fade_out() -> void:
	set_highlight(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
