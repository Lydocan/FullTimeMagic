class_name MonsterData
extends Resource
## 妖魔数据（.tres 数据驱动，实例见 resources/monsters/）。

@export var id: String = ""
@export var monster_name: String = ""
## 妖魔等阶（GameTypes.MonsterTier）：奴仆/战将/统领/君主，与玩家位阶同尺度。
## 与玩家阶差（tier - 队伍最高阶）驱动战斗内的等级压制，见 battle.gd。
@export var tier: int = 0
## 妖魔等级显示名（由 tier 决定，数据里冗余一份便于编辑器查看）。
@export var tier_name: String = "奴仆级"
## 等级压制的强弱系数：0 = 不受压制（人类对手/决斗对等），
## 0.5 = 虚弱个体（如林地先遣狼王），1.0 = 完整压制。
@export_range(0.0, 1.0) var suppression_scale: float = 1.0
## 元素归属（GameTypes.Element；-1 = 野性无属）。技能名与施法特效配色用。
@export var element: int = -1
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
## 概率掉落的物品 id（"" 为不掉落）与掉率：不同妖魔掉不同东西，
## 战斗胜利时掷骰入背包（见 battle.gd 结算）。
@export var drop_id: String = ""
@export_range(0.0, 1.0) var drop_chance: float = 0.0
## 战斗立绘（大图，出招时在画面两侧切换展示；"" 为无立绘）。
@export var portrait_path: String = ""
@export var texture_path: String = ""
@export var sprite_scale: float = 1.0
## 普攻威力（技能未命中时的兜底攻击「撞击」）。
@export var attack_power: int = 8
## 技能表，与自身元素匹配：小怪一技，Boss/关键对手多技。每项：
## {"name", "power", "chance"(发动概率，逐技掷骰先中先用), "target_all",
##  "status"("burn"/"paralyze"/""), "status_chance"(命中后附加状态的概率)}
@export var skills: Array = []
## —— 二阶段（Boss/关键人物）：双血条——第一管血打空后不死亡，
## 换上第二管满血条（phase2_hp）并强化攻防，盖章演出。0 = 无二阶段。
@export var phase2_hp: int = 0
@export var phase2_attack: int = 0
@export var phase2_defense: int = 0
@export var phase2_name: String = ""
