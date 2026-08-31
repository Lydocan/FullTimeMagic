class_name GameTypes
## 全局类型与常量：元素、位阶、显示名与颜色。
##
## 位阶体系见 docs/world.md：阶 × 星级，每个元素系独立修炼。

enum Element { FIRE, ICE, LIGHTNING, WIND, EARTH }

enum Stage { BEGINNER, INTERMEDIATE, ADVANCED, SUPER }

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


static func element_name(element: int) -> String:
	return ELEMENT_NAMES.get(element, "?")


static func element_color(element: int) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


static func stage_name(stage: int) -> String:
	return STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)]


static func star_name(star: int) -> String:
	return STAR_NAMES[clampi(star, 0, STAR_NAMES.size() - 1)]


## 位阶显示文本，如「雷系·初阶二星」。
static func rank_text(element: int, stage: int, star: int) -> String:
	return "%s系·%s%s" % [element_name(element), stage_name(stage), star_name(star)]
