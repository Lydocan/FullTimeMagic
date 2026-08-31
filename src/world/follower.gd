extends Node2D
## 队伍跟随者：链式跟随——成员 1 跟玩家，成员 2 跟成员 1，以此类推。
##
## 记录目标的历史轨迹点，始终吊在目标后方 GAP 路径距离处；目标静止时
## 走完剩余距离即停（移动手感与玩家一致的摆动 + 翻面）。
## 无碰撞体：不挡玩家路、不参与遇敌与交互。
## 目标瞬移（战斗返回等单帧大位移）时直接吸附，不做跨图奔跑。

const SPEED := 200.0          # 略快于玩家（150），便于归位
const STEP := 6.0             # 目标每移动该距离记录一个轨迹点
const GAP := 26.0             # 与目标保持的路径距离
const SNAP_DISTANCE := 300.0  # 单帧位移超过此值视为瞬移
const MAX_TRAIL := 64         # 轨迹点上限（足够绕 map 尺寸的弯）

var texture: Texture2D
var target: Node2D

var _trail: Array[Vector2] = []  # 目标历史位置，新在前
var _sprite: Sprite2D
var _last_target_pos := Vector2.INF
var _bob_time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	add_child(_sprite)


## 入场预置：站在目标侧后方 offset 处，并伪造半段反向轨迹，
## 使静止待机点落在 offset 处而不是叠到目标身上。
func prime(offset: Vector2) -> void:
	var anchor: Vector2 = target.global_position
	_last_target_pos = anchor
	_trail = [anchor + offset * 0.5, anchor + offset]
	global_position = anchor + offset


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var tpos: Vector2 = target.global_position
	if _last_target_pos == Vector2.INF:
		_last_target_pos = tpos
		_trail.push_front(tpos)
	# 瞬移：清轨迹直接吸附
	if tpos.distance_to(_last_target_pos) > SNAP_DISTANCE:
		_trail.clear()
		_trail.push_front(tpos)
		_last_target_pos = tpos
		global_position = tpos
		return
	# 记录轨迹
	if tpos.distance_to(_last_target_pos) >= STEP:
		_trail.push_front(tpos)
		_last_target_pos = tpos
		if _trail.size() > MAX_TRAIL:
			_trail.pop_back()
	# 沿轨迹回溯 GAP 距离作为去向
	var goal := _trail_point(GAP)
	if global_position.distance_to(goal) > 1.0:
		var before_x := global_position.x
		global_position = global_position.move_toward(goal, SPEED * delta)
		_bob_time += delta * 10.0
		_sprite.offset.y = -absf(sin(_bob_time)) * 2.0
		if absf(global_position.x - before_x) > 0.2:
			_sprite.flip_h = global_position.x < before_x
	else:
		_sprite.offset.y = 0.0


## 从目标当前位置沿历史轨迹回溯 dist 路径距离；轨迹不足时停在最早点。
func _trail_point(dist: float) -> Vector2:
	var acc := 0.0
	var prev: Vector2 = target.global_position
	for p in _trail:
		var d := prev.distance_to(p)
		if d <= 0.01:
			prev = p
			continue
		if acc + d >= dist:
			return prev.lerp(p, (dist - acc) / d)
		acc += d
		prev = p
	return prev
