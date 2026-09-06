extends Resource
## 消耗品数据（.tres 数据驱动，实例见 resources/items/）。

@export var id: String = ""
@export var item_name: String = ""
@export var price: int = 10
## 效果类型："heal_hp" 回复生命 / "heal_mp" 回复精神力 / "revive" 复活倒下成员。
@export var kind: String = "heal_hp"
## 效果数值（revive 时为回复的生命比例，0-1；其余为固定点数）。
@export var amount: int = 30
## 仅战斗中可用（如复活）。
@export var battle_only: bool = false
@export var description: String = ""


## 使用效果文本（列表展示用）。
func effect_text() -> String:
	match kind:
		"heal_hp": return "回复生命 %d" % amount
		"heal_mp": return "回复精神力 %d" % amount
		"revive": return "复活并回复 %d%% 生命" % amount
	return description
