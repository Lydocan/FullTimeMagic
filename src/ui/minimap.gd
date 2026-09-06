extends Control
## 右上角小地图：整图地块缩略 + 玩家白点 + 主线目标黄三角。
##
## 静态地块层只烘焙一次（ImageTexture），每帧仅叠加玩家/目标两个动态标记。
## 目标落点由地图的 objective_target() 给出（世界坐标），不在本图则不画三角。

const SCALE_PX := 4  # 每格地块的像素数
const PAD := 5       # 面板内边距
const OBJECTIVE_COLOR := Color("ffd166")  # 与左下目标文字同色

## 地块字符 → 缩略色（与 tiles_proto.png 的观感对齐）。
const TILE_COLORS := {
	"G": Color("4d7a3a"),  # 草地
	"H": Color("35602c"),  # 深草（暗雷区）
	"P": Color("c9a86a"),  # 道路
	"T": Color("1f4526"),  # 树墙
	"R": Color("6f6f78"),  # 岩石
	"W": Color("3a6ea8"),  # 水面
	"F": Color("41608f"),  # 民居屋顶
	"B": Color("8d8271"),  # 墙体
	"D": Color("5f4028"),  # 门
	"C": Color("9c4a3c"),  # 校舍红瓦
	"U": Color("7a352c"),  # 校舍尖塔
}

var _map  # 地图基类；按鸭子类型引用，避免与 map_base.gd 形成 preload 环
var _tiles_tex: ImageTexture


func setup(map) -> void:
	_map = map
	var size_cells: Vector2i = map.map_size()
	var inner := Vector2(size_cells) * SCALE_PX
	custom_minimum_size = inner + Vector2(PAD, PAD) * 2.0
	size = custom_minimum_size
	_bake_tiles()


## 整图烘焙成一张小纹理：每格 1 像素 → 最近邻放大，保持像素块干净。
func _bake_tiles() -> void:
	var size_cells: Vector2i = _map.map_size()
	var img := Image.create(size_cells.x, size_cells.y, false, Image.FORMAT_RGBA8)
	for y in size_cells.y:
		for x in size_cells.x:
			img.set_pixel(x, y, TILE_COLORS.get(_map._cell_char(Vector2i(x, y)), TILE_COLORS["G"]))
	img.resize(size_cells.x * SCALE_PX, size_cells.y * SCALE_PX, Image.INTERPOLATE_NEAREST)
	_tiles_tex = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var inner := size - Vector2(PAD, PAD) * 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.09, 0.78))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22), false, 1.0)
	if _tiles_tex != null:
		draw_texture_rect(_tiles_tex, Rect2(Vector2(PAD, PAD), inner), false)
	_draw_marker(_map.player.global_position, Color(1, 1, 1))
	_draw_objective()


## 世界坐标 → 小地图像素（含内边距偏移）。
func _to_minimap(world_pos: Vector2) -> Vector2:
	var size_cells: Vector2i = _map.map_size()
	var world_size := Vector2(size_cells) * float(_map.TILE)
	return Vector2(PAD, PAD) + world_pos / world_size * (size - Vector2(PAD, PAD) * 2.0)


func _draw_marker(world_pos: Vector2, color: Color) -> void:
	var pos := _to_minimap(world_pos)
	draw_circle(pos + Vector2(0.5, 0.5), 3.5, Color(0, 0, 0, 0.6))
	draw_circle(pos, 2.5, color)


## 主线目标标记：目标本体画脉动圆点；同时一枚黄三角骑在面板内切圆的
## 边缘上，箭头指向目标方位——随玩家移动沿圆边游动（方向指向牌），
## 目标不在本图时省略。
func _draw_objective() -> void:
	var target: Vector2 = _map.objective_target()
	if target == Vector2.INF:
		return
	var bob := sin(Time.get_ticks_msec() / 250.0) * 1.5
	# 目标本体：小圆点 + 呼吸外圈
	var tpos := _to_minimap(target)
	draw_circle(tpos + Vector2(0.5, 0.5), 4.0 + bob * 0.5, Color(0, 0, 0, 0.4))
	draw_circle(tpos, 2.5, OBJECTIVE_COLOR)
	# 圆边指向牌：由玩家指向目标的方位角决定三角在圆边上的位置
	var center := size * 0.5
	var rail := minf(size.x, size.y) * 0.5 - 4.0
	draw_arc(center, rail, 0, TAU, 48, Color(1, 1, 1, 0.08), 1.0)
	var dir := (tpos - _to_minimap(_map.player.global_position))
	if dir.length() < 2.0:
		return
	dir = dir.normalized()
	var pos := center + dir * rail
	var perp := Vector2(-dir.y, dir.x)
	var r := 5.0
	var points := PackedVector2Array([
		pos + dir * r,
		pos - dir * r * 0.6 + perp * r * 0.8,
		pos - dir * r * 0.6 - perp * r * 0.8,
	])
	draw_colored_polygon(points, OBJECTIVE_COLOR)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.55), 1.0)
