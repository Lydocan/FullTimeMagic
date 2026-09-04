extends CharacterBody2D
## 玩家探索控制：四向移动、交互检测、移动距离上报（暗雷步数用）。

const SPEED := 150.0

@onready var sprite: Sprite2D = $Sprite
@onready var interact_zone: Area2D = $InteractZone

## 每帧实际移动的距离（世界场景用于累计遇敌步数）。
signal moved(distance: float)

var input_enabled := true
var _bob_time := 0.0


func _ready() -> void:
	add_to_group("player")  # NPC/篝火的交互高亮按组找玩家


func _physics_process(delta: float) -> void:
	# 双保险锁：input_enabled 之外，对话面板可见期间一律禁止走动
	# （无论锁由谁负责，只要对话在演，人物就不该动）
	if not input_enabled or Dialogue.visible:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir.length_squared() > 0.01:
		_bob_time += delta * 10.0
		sprite.offset.y = -absf(sin(_bob_time)) * 2.0
		if absf(dir.x) > 0.1:
			sprite.flip_h = dir.x < 0
		moved.emit(velocity.length() * delta)
	else:
		sprite.offset.y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and input_enabled:
		for area in interact_zone.get_overlapping_areas():
			if area.has_method("interact"):
				area.interact()
				break
