extends "res://src/world/map_base.gd"
## 决斗台：天澜高中校内竞技场，毕业决斗（M3.1）舞台。
## 中央石台 + 四周围栏，唐月任裁判，学生观战；南门通回博城。
## 继承与剧情事件均按路径 preload，不依赖 class_name 全局缓存。

const Story := preload("res://src/story/story_events.gd")
const BO_CITY_SCENE := "res://src/world/bo_city/bo_city.tscn"

const MAP := [
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGPPPP", "PPPPGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGPPPP", "PPPPGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TTTTTTGTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
]

const SPAWN_CELL := Vector2i(19, 6)
const STAGE_CELL := Vector2i(10, 4)
const SOUTH_GATE := Vector2i(6, 7)


func map_rows() -> Array:
	return MAP


func start_cell() -> Vector2i:
	return SPAWN_CELL


func map_display_name() -> String:
	return "天澜高中·决斗台"


func bgm_name() -> String:
	return "battle"


func setup_triggers() -> void:
	add_portal(SOUTH_GATE, BO_CITY_SCENE, Vector2i(13, 9))
	# 台中央：决斗开战 / 胜利演出
	add_trigger(STAGE_CELL, 96.0, func() -> void: await Story.duel_arena(self))
	# —— NPC：裁判与观战者（常驻；Callable() 为纯装饰无交互）——
	add_npc(Vector2i(12, 2), "res://assets/images/char_tangyue.png",
			"唐月（裁判）", "",
			func() -> void: await Story.arena_referee(self))
	add_npc(Vector2i(7, 5), "res://assets/images/char_student.png",
			"学生", "", Callable())
	add_npc(Vector2i(13, 5), "res://assets/images/char_student.png",
			"学生", "", Callable())
	add_npc(Vector2i(24, 3), "res://assets/images/char_merchant.png",
			"围观大婶", "", Callable())


## 主线落点：决斗结束前始终指向台中央。
func objective_target() -> Vector2:
	if not flag("duel_done"):
		return _cell_center(STAGE_CELL)
	return Vector2.INF
