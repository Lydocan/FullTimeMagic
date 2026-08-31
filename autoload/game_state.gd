extends Node
## 全局游戏状态（autoload：GameState）。
##
## 存放跨场景共享的运行时数据。持久化请交给存档系统，不要只依赖内存数据。

var player_name: String = "旅行者"
var player_max_health: int = 100
var player_health: int = 100
var gold: int = 0


## 修改玩家生命值，正数为治疗、负数为伤害。返回修改后的当前生命值。
func change_player_health(delta: int) -> int:
	player_health = clampi(player_health + delta, 0, player_max_health)
	GameEvents.player_health_changed.emit(player_health, player_max_health)
	return player_health


## 增减金币，正数为获得、负数为消耗。返回修改后的总金币。
func change_gold(delta: int) -> int:
	gold = maxi(gold + delta, 0)
	GameEvents.gold_changed.emit(gold)
	return gold
