extends "res://src/world/map_base.gd"
## 灰雾林地：博城郊外狩猎场。深草暗雷 + 明雷精英「独眼魔狼王」。
## 序章教学战与第一章前半的黑教廷线索都在这里。
## 继承与剧情事件按路径 preload，不依赖 class_name 全局缓存。

const Story := preload("res://src/story/story_events.gd")

const MAP := [
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGHGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGRGGGGGGT",
	"TGGHHGGGGG", "HHHHHHGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGHGGGHH", "HHHHHHGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGHH", "HHHHHHGGGG", "GGGGGGWWGG", "GGGGGGGGGT",
	"TGGGGGGGHH", "HHHHGGGGGG", "GGGGGGWWWG", "GGGGGGGGGT",
	"TGGGGGGGGG", "HHHGGGGGGG", "GGGGGGWWWG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GHGGGGGGGG", "GGGGGGGWGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGHHHGGT",
	"TGGRGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGHHHHHGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGHHHHHHGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGHHHHGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGHHGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGPPGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TGGGPPPPGG", "GGGGGGGGGG", "GGGGGGGGGG", "GGGGGGGGGT",
	"TTTTTTGTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
]

const CAMP_CELL := Vector2i(6, 19)
const SPAWN_CELL := Vector2i(7, 20)
const SOUTH_GATE := Vector2i(6, 20)
const BO_CITY_SCENE := "res://src/world/bo_city/bo_city.tscn"


func map_rows() -> Array:
	return MAP


func bgm_name() -> String:
	return "grove"


func start_cell() -> Vector2i:
	return SPAWN_CELL


func encounter_table() -> Array:
	return [
		{"ids": ["rat_swarm"], "weight": 5},
		{"ids": ["rat_swarm", "rat_swarm"], "weight": 3},
		{"ids": ["one_eye_wolf"], "weight": 2},
		{"ids": ["rat_swarm", "one_eye_wolf"], "weight": 1},
	]


func elite_spawns() -> Array:
	return [
		{"cell": Vector2i(34, 14), "flag": "elite_wolf_dead", "ids": ["wolf_alpha"]},
	]


func setup_triggers() -> void:
	add_campfire(CAMP_CELL)
	add_portal(SOUTH_GATE, BO_CITY_SCENE, Vector2i(20, 2))
	# 讨伐狼王后的黑教廷线索（场景事件：战归来到尸体旁自动演出，非 NPC 对话）
	add_trigger(Vector2i(34, 13), 96.0, func() -> void: await Story.grove_after_boss(self))
	# 唐月在林地入口等莫凡（教学战期间在场，按 E 触发教学战）
	add_npc(Vector2i(8, 18), "res://assets/images/char_tangyue.png",
			"唐月", "prologue_done",
			func() -> void: await Story.grove_tutorial(self))


## 主线落点：教学战唐月 → 狼王 → 狼王尸体旁的黑教廷线索。
func objective_target() -> Vector2:
	if not flag("prologue_done"):
		return _cell_center(Vector2i(8, 18))   # 入口等待的唐月
	if not flag("elite_wolf_dead"):
		return _cell_center(Vector2i(34, 14))  # 独眼魔狼王
	if not flag("chapter1_half_done"):
		return _cell_center(Vector2i(34, 13))  # 尸体旁线索触发点
	return Vector2.INF
