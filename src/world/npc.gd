extends Area2D
## 剧情 NPC：站在剧情点的人物实体（歧路旅人式——剧情有"人"在场）。
##
## 头顶显示名字与浮动「!」标记；玩家进入交互距离时描金光边亮起（即是
## "可以按 E"的提示，不再额外显示 E 字样）。剧情完成后 hide_flag 点亮，
## 地图会让人物退场（见 MapBase._spawn_npc）。
## 装饰 NPC（event 无效）不显示标记、不高亮、不响应按 E。

const OUTLINE_SHADER := preload("res://shaders/interact_outline.gdshader")
const INTERACT_RANGE := 42.0  # 与玩家 InteractZone 的实际可达范围对齐

var texture: Texture2D
var display_name := ""
var hide_flag := ""
var event: Callable = Callable()

var _bob_time := 0.0
var _near := false
var _sprite: Sprite2D
var _mark: Label
var _glow: ShaderMaterial


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -10)  # 站在格子中心，脚底贴地
	if event.is_valid():
		_glow = ShaderMaterial.new()
		_glow.shader = OUTLINE_SHADER
		_sprite.material = _glow
	add_child(_sprite)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	name_label.position = Vector2(-30, -42)
	name_label.size = Vector2(60, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_size_override("font_size", 18)
	_mark.add_theme_color_override("font_color", Color("ffd166"))
	_mark.position = Vector2(-4, -60)
	add_child(_mark)


func _process(delta: float) -> void:
	_bob_time += delta * 4.0
	_mark.position.y = -60.0 + sin(_bob_time) * 3.0
	if not event.is_valid():
		_mark.visible = false  # 装饰 NPC 不亮「!」，按 E 也无响应
		return
	# 交互距离检测：进圈描金、「!」换「E」徽标（按 E 可交互的即时提示）
	var near := false
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(global_position) <= INTERACT_RANGE:
			near = true
			break
	if near != _near:
		_near = near
		_mark.text = "!"  # 靠近不换「E」字样：描金光边即交互提示（试玩反馈去 E）
		_mark.add_theme_font_size_override("font_size", 18)
	_mark.add_theme_color_override("font_color",
			Color("ffd166") if not near else Color("ffe9a3").lightened(0.1 + 0.1 * sin(_bob_time * 2.0)))
	if _glow != null:
		_glow.set_shader_parameter("active", 1.0 if near else 0.0)


func interact() -> void:
	if event.is_valid():
		event.call()
