extends CharacterBody2D
## 玩家探索控制：四向移动、交互检测、移动距离上报（暗雷步数用）。
## 分层换装：身体之上叠 裤→上衣→帽 三层精灵（cloth 层与 base 身体 24x32 分区对位），
## 随 worn_clothes 换图，行走跳动与朝向翻转同 base 一并同步。

const SPEED := 150.0
const CLOTHES_DIR := "res://assets/images/clothes/"

@onready var sprite: Sprite2D = $Sprite
@onready var _pants_sprite: Sprite2D = $PantsSprite
@onready var _top_sprite: Sprite2D = $TopSprite
@onready var _hat_sprite: Sprite2D = $HatSprite
@onready var _layers: Array[Sprite2D] = [sprite, _pants_sprite, _top_sprite, _hat_sprite]
@onready var interact_zone: Area2D = $InteractZone

## 每帧实际移动的距离（世界场景用于累计遇敌步数）。
signal moved(distance: float)

var input_enabled := true
var _bob_time := 0.0


func _ready() -> void:
	add_to_group("player")  # NPC/篝火的交互高亮按组找玩家
	GameEvents.clothes_changed.connect(_refresh_outfit)
	_refresh_outfit()  # 入场/读档/跨图重建时按当前穿着初始化外观


## 换装广播 → 刷新三层衣装贴图。
func _refresh_outfit() -> void:
	_set_outfit_layer(_pants_sprite, "pants")
	_set_outfit_layer(_top_sprite, "top")
	_set_outfit_layer(_hat_sprite, "hat")


func _set_outfit_layer(layer: Sprite2D, slot: String) -> void:
	var id: String = GameState.worn_clothes.get(slot, "")
	var path := "%s/%s.png" % [CLOTHES_DIR, id]
	layer.texture = load(path) if id != "" and ResourceLoader.exists(path) else null
	layer.visible = layer.texture != null


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
		if absf(dir.x) > 0.1:
			var flip := dir.x < 0
			for layer in _layers:
				layer.flip_h = flip
		for layer in _layers:
			layer.offset.y = -absf(sin(_bob_time)) * 2.0
		moved.emit(velocity.length() * delta)
	else:
		for layer in _layers:
			layer.offset.y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and input_enabled:
		for area in interact_zone.get_overlapping_areas():
			if area.has_method("interact"):
				area.interact()
				break
