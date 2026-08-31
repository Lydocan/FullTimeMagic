class_name EquipData
extends Resource
## 装备数据（.tres 数据驱动，实例见 resources/equips/）。
##
## MVP 为纯属性加成；设计文档中的「魔具提供跨系副技能」留待后续扩展。

## 槽位："weapon" 法杖 / "magic" 魔具 / "armor" 护具。
@export var slot: String = "weapon"
@export var id: String = ""
@export var equip_name: String = ""
@export var price: int = 50
@export var bonus_hp: int = 0
@export var bonus_mp: int = 0
@export var bonus_magic: int = 0
@export var bonus_defense: int = 0
@export var description: String = ""


const SLOT_NAMES := {"weapon": "法杖", "magic": "魔具", "armor": "护具"}


func slot_name() -> String:
	return SLOT_NAMES.get(slot, slot)


## 加成摘要（列表展示用）。
func bonus_text() -> String:
	var parts: Array[String] = []
	if bonus_hp > 0:
		parts.append("生命+%d" % bonus_hp)
	if bonus_mp > 0:
		parts.append("精神力+%d" % bonus_mp)
	if bonus_magic > 0:
		parts.append("法攻+%d" % bonus_magic)
	if bonus_defense > 0:
		parts.append("防御+%d" % bonus_defense)
	return " ".join(parts)
