class_name BattleActor
extends Node2D
## 战斗单位视图：精灵、名字、血条、魔盾、弱点标记。
## 数值状态由 battle.gd 持有，本节点只负责显示。

var _sprite: Sprite2D
var _name_label: Label
var _hp_bar: ProgressBar
var _shield_label: Label
var _weak_label: Label


func _init() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	_name_label = _make_label(13)
	_name_label.position = Vector2(-50, 20)
	_name_label.size = Vector2(100, 16)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(-36, 38)
	_hp_bar.size = Vector2(72, 8)
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.show_percentage = false
	add_child(_hp_bar)

	_shield_label = _make_label(12)
	_shield_label.position = Vector2(-50, 48)
	_shield_label.size = Vector2(100, 14)
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_label.add_theme_color_override("font_color", Color("8ecbff"))
	add_child(_shield_label)

	_weak_label = _make_label(11)
	_weak_label.position = Vector2(-50, 64)
	_weak_label.size = Vector2(100, 14)
	_weak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_weak_label)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


func setup(texture: Texture2D, actor_name: String, sprite_scale := 1.0) -> void:
	_sprite.texture = texture
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_name_label.text = actor_name


func set_hp(ratio: float) -> void:
	_hp_bar.value = clampf(ratio, 0.0, 1.0)


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
	modulate = Color(1.5, 1.5, 1.15) if on else Color.WHITE


func flash() -> void:
	modulate = Color(8, 2.5, 2.5)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)


func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
