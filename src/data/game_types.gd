## 全局类型与常量：元素、位阶、显示名与颜色。
##
## 位阶体系见 docs/world.md：阶 × 星级，每个元素系独立修炼。

enum Element { FIRE, ICE, LIGHTNING, WIND, EARTH }

enum Stage { BEGINNER, INTERMEDIATE, ADVANCED, SUPER }

## 妖魔等阶（对照 docs/world.md「妖魔等级」，与玩家 Stage 同尺度：
## 初阶≈奴仆级、中阶≈战将级、高阶≈统领级、超阶≈君主级）。
enum MonsterTier { SERVANT, COMMANDER, OVERLORD, MONARCH }

## 每阶的星级数（一星~三星）。
const STARS_PER_STAGE := 3
## 每个星级需点亮的星子数（原著设定待核对：7 颗星子连成星轨）。
const STARDUST_PER_STAR := 7
## 三星圆满（达成瓶颈）所需的总星子数。
const STARDUST_PER_STAGE := STARS_PER_STAGE * STARDUST_PER_STAR

const ELEMENT_NAMES := {
	Element.FIRE: "火",
	Element.ICE: "冰",
	Element.LIGHTNING: "雷",
	Element.WIND: "风",
	Element.EARTH: "土",
}

const ELEMENT_COLORS := {
	Element.FIRE: Color("ff7a45"),
	Element.ICE: Color("7ecbff"),
	Element.LIGHTNING: Color("c792ff"),
	Element.WIND: Color("7ddba3"),
	Element.EARTH: Color("d8b06a"),
}

const STAGE_NAMES := ["初阶", "中阶", "高阶", "超阶"]
const STAR_NAMES := ["一星", "二星", "三星"]
const MONSTER_TIER_NAMES := ["奴仆级", "战将级", "统领级", "君主级"]

## 衣柜部位名（衣装数据的 slot 字段 → 显示名）。
const CLOTHING_SLOT_NAMES := {"hat": "帽子", "top": "上衣", "pants": "裤子"}

## 华丽度称号阶梯——参考战力体系称呼（奴仆级化用为初始的「布衣级」，
## 其余对齐妖魔等阶：战将级/统领级/君主级）。取满足的最高档。
const FASHION_TITLES := [
	{"min": 0, "name": "布衣级"},
	{"min": 10, "name": "新锐级"},
	{"min": 50, "name": "战将级"},
	{"min": 100, "name": "统领级"},
	{"min": 1000, "name": "君主级"},
]


static func element_name(element: int) -> String:
	return ELEMENT_NAMES.get(element, "?")


static func element_color(element: int) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


static func stage_name(stage: int) -> String:
	return STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)]


static func monster_tier_name(tier: int) -> String:
	return MONSTER_TIER_NAMES[clampi(tier, 0, MONSTER_TIER_NAMES.size() - 1)]


static func clothing_slot_name(slot: String) -> String:
	return CLOTHING_SLOT_NAMES.get(slot, slot)


## 华丽度对应的时尚称号（取满足门槛的最高档）。
static func fashion_title(glamour: int) -> String:
	var name := FASHION_TITLES[0]["name"]
	for entry in FASHION_TITLES:
		if glamour >= int(entry["min"]):
			name = entry["name"]
	return name


static func star_name(star: int) -> String:
	return STAR_NAMES[clampi(star, 0, STAR_NAMES.size() - 1)]


## 位阶显示文本，如「雷系·初阶二星」。
static func rank_text(element: int, stage: int, star: int) -> String:
	return "%s系·%s%s" % [element_name(element), stage_name(stage), star_name(star)]
