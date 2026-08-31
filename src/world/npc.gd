extends Area2D
## 剧情 NPC：站在剧情点的人物实体（歧路旅人式——剧情有"人"在场）。
##
## 头顶显示名字与「!」浮动标记；走近由地图 trigger 自动演出剧情，
## 按 E 也可手动触发（与篝火同一交互通道）。剧情完成后 hide_flag 点亮，
## 地图会让人物退场（见 MapBase._spawn_npc）。

var display_name := ""
var hide_flag := ""
var event: Callable = Callable()

var _bob_time := 0.0
var _mark: Label


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	name_label.position = Vector2(-30, -56)
	name_label.size = Vector2(60, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_size_override("font_size", 18)
	_mark.add_theme_color_override("font_color", Color("ffd166"))
	_mark.position = Vector2(-4, -80)
	add_child(_mark)


func _process(delta: float) -> void:
	_bob_time += delta * 4.0
	_mark.position.y = -80.0 + sin(_bob_time) * 3.0


func interact() -> void:
	if event.is_valid():
		event.call()
