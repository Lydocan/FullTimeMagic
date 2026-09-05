extends Area2D
## 营地篝火交互点：靠近按 E 打开休息/修炼/突破/存档菜单。
## 玩家进入交互距离时篝火描金光边亮起（即是交互提示，不再浮 E 字样）。

signal camp_used

const OUTLINE_SHADER := preload("res://shaders/interact_outline.gdshader")
const INTERACT_RANGE := 42.0  # 与玩家 InteractZone 的实际可达范围对齐

var _bob_time := 0.0
var _glow: ShaderMaterial


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


func _process(_delta: float) -> void:
	var near := false
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) <= INTERACT_RANGE:
			near = true
			break
	_glow.set_shader_parameter("active", 1.0 if near else 0.0)


func interact() -> void:
	camp_used.emit()
