extends MapBase
## 测试荒野：M1 核心循环原型的沙盒地图，现为 MapBase 的最小示例。
##
## 与灰雾林地同源（同地块、同遇敌表、同精英「独眼魔狼王」），
## 不接入章节剧情；正式流程走 博城 ↔ 灰雾林地。

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
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
]

const CAMP_CELL := Vector2i(6, 19)
const SPAWN_CELL := Vector2i(6, 20)


func map_rows() -> Array:
	return MAP


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
