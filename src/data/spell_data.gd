class_name SpellData
extends Resource
## 法术数据（.tres 数据驱动，实例见 resources/spells/）。

@export var id: String = ""
@export var spell_name: String = ""
@export var element: GameTypes.Element = GameTypes.Element.FIRE
## 阶位要求：0=初阶 1=中阶 2=高阶 3=超阶。
@export_range(0, 3) var tier: int = 0
@export var power: int = 10
## 基础段数；星辉增幅每点 +1 段。
@export_range(1, 5) var hits: int = 1
## 精神力消耗。
@export var mp_cost: int = 4
## 命中弱点时每段削减的魔盾数。
@export_range(0, 3) var break_power: int = 1
@export var target_all: bool = false
@export var heals: bool = false
## 附加状态："" 无 / "burn" 燃烧 / "paralyze" 麻痹。
@export var status_effect: String = ""
## 附加状态的触发概率。
@export_range(0.0, 1.0) var status_chance: float = 0.0
@export var description: String = ""
