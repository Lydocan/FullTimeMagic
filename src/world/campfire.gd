extends Area2D
## 营地篝火交互点：靠近按 E 打开休息/修炼/突破/存档菜单。
## 玩家进入交互距离时篝火描金高亮并浮出「E」徽标，提示可以交互。

signal camp_used

const OUTLINE_SHADER := preload("res://shaders/interact_outline.gdshader")
const INTERACT_RANGE := 42.0  # 与玩家 InteractZone 的实际可达范围对齐

var _bob_time := 0.0
var _near := false
var _glow: ShaderMaterial
var _mark: Label


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/images/campfire.png")
	sprite.position = Vector2(0, -4)
	_glow = ShaderMaterial.new()
	_glow.shader = OUTLINE_SHADER
	sprite.material = _glow
	add_child(sprite)

	_mark = Label.new()
	_mark.text = "E"
	_mark.add_theme_font_size_override("font_size", 16)
	_mark.add_theme_color_override("font_color", Color("ffe9a3"))
	_mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_mark.add_theme_constant_override("outline_size", 3)
	_mark.position = Vector2(-4, -34)
	_mark.visible = false
	add_child(_mark)


func _process(delta: float) -> void:
	_bob_time += delta * 4.0
	var near := false
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) <= INTERACT_RANGE:
			near = true
			break
	if near != _near:
		_near = near
		_mark.visible = near
	_mark.position.y = -34.0 + sin(_bob_time) * 3.0
	_glow.set_shader_parameter("active", 1.0 if near else 0.0)


func interact() -> void:
	camp_used.emit()
