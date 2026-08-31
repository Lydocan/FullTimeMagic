class_name MonsterData
extends Resource
## 妖魔数据（.tres 数据驱动，实例见 resources/monsters/）。

@export var id: String = ""
@export var monster_name: String = ""
## 妖魔等级：奴仆级 / 战将级 / 统领级 / 君主级（对照玩家位阶，见 docs/world.md）。
@export var tier_name: String = "奴仆级"
@export var max_hp: int = 30
@export var speed: int = 5
@export var attack: int = 6
@export var defense: int = 2
## 魔盾数：命中弱点削减，归零即破魔（眩晕一回合，承伤加深）。
@export_range(0, 5) var shield: int = 1
## 弱点元素列表（元素为 GameTypes.Element 的 int）。
@export var weaknesses: Array = []
## 击杀修为（每位存活成员各得）。
@export var xp_value: int = 8
@export var gold_value: int = 5
## 掉落精魄 id（"" 为不掉落），命名约定 essence_<元素>。
@export var essence_id: String = ""
@export_range(0.0, 1.0) var essence_chance: float = 0.0
@export var texture_path: String = ""
@export var sprite_scale: float = 1.0
## 敌方普攻与特殊技能。
@export var attack_power: int = 8
@export var special_name: String = ""
@export var special_power: int = 12
@export_range(0.0, 1.0) var special_chance: float = 0.2
@export var special_target_all: bool = false
## 特殊技能附加状态："burn" / "paralyze"。
@export var special_status: String = ""
