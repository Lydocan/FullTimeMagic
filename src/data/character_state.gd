extends RefCounted
## 角色运行时状态：属性、各系位阶（修为/星子）、法术、战斗形态。
##
## 位阶规则（仿原著，弃用传统等级）见 docs/world.md：
## 每个元素系独立修炼，阶 × 星级，三星圆满进入瓶颈，突破后晋阶。

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const GameTypes := preload("res://src/data/game_types.gd")
const SpellData := preload("res://src/data/spell_data.gd")
const GameData := preload("res://src/data/game_data.gd")

var id: String = ""
var char_name: String = ""
## 觉醒的元素系（元素枚举值），双系者如莫凡为 [雷, 火]。
var elements: Array = []
## 当前主修系。莫凡可在营地改修，战斗中切换形态即切换施法系。
var main_element: int = GameTypes.Element.FIRE
## 战斗形态索引（对 elements 的下标），仅双形态角色使用。
var form: int = 0
## 是否可在战斗中切换形态（莫凡）。
var can_switch_form: bool = false
## 每系修炼进度：{element: {"stage": int, "star": int, "dust": int, "bottleneck": bool}}
var ranks: Dictionary = {}
## 已习得法术。
var spells: Array[SpellData] = []
## 已装备：{slot: equip_id}，槽位 "weapon"/"magic"/"armor"。
var equips: Dictionary = {}

## 基础属性（不含星子加成）。
var max_hp: int = 80
var max_mp: int = 30
var magic: int = 10
var defense: int = 3
var speed: int = 8

var hp: int = 80
var mp: int = 30
## 战斗内临时状态。
var battle_stars: int = 0
var defending: bool = false
var burn_turns: int = 0
var paralyzed: bool = false


## 从预设配置填充属性（原静态工厂 create 改实例方法：消除自引用，
## 使本文件免疫 class_name 全局缓存——见 docs/lessons.md 踩坑 18）。
func build_from(cfg: Dictionary) -> void:
	id = cfg.get("id", "")
	char_name = cfg.get("name", "")
	elements = cfg.get("elements", [])
	main_element = cfg.get("main_element", elements[0] if not elements.is_empty() else GameTypes.Element.FIRE)
	can_switch_form = cfg.get("can_switch_form", false)
	max_hp = cfg.get("max_hp", 80)
	max_mp = cfg.get("max_mp", 30)
	magic = cfg.get("magic", 10)
	defense = cfg.get("defense", 3)
	speed = cfg.get("speed", 8)
	hp = max_hp
	mp = max_mp
	for el in elements:
		ensure_rank(el)


## 确保某系的修炼档位存在。
func ensure_rank(element: int) -> void:
	if not ranks.has(element):
		ranks[element] = {"stage": 0, "star": 0, "dust": 0, "bottleneck": false}


func stage_of(element: int) -> int:
	return ranks.get(element, {}).get("stage", 0)


func star_of(element: int) -> int:
	return ranks.get(element, {}).get("star", 0)


func dust_of(element: int) -> int:
	return ranks.get(element, {}).get("dust", 0)


func is_bottleneck(element: int) -> bool:
	return ranks.get(element, {}).get("bottleneck", false)


func rank_label(element: int) -> String:
	return GameTypes.rank_text(element, stage_of(element), star_of(element))


## 该系累计点亮的星子数（用于属性加成与显示）。
func stars_lit(element: int) -> int:
	var r: Dictionary = ranks.get(element, {})
	return r.get("stage", 0) * GameTypes.STARDUST_PER_STAGE \
			+ r.get("star", 0) * GameTypes.STARDUST_PER_STAR + r.get("dust", 0)


## 星子点亮带来的成长加成（每颗星子：生命+6、精神力上限+2、法攻+1）。
func star_bonus() -> Dictionary:
	var lit := 0
	for el in ranks:
		lit += stars_lit(el)
	return {"max_hp": lit * 6, "max_mp": lit * 2, "magic": lit}


## 装备属性加成（equips 里登记的装备求和）。
func equip_bonus() -> Dictionary:
	var out := {"max_hp": 0, "max_mp": 0, "magic": 0, "defense": 0}
	for slot in equips:
		var e := GameData.load_equip(equips[slot])
		if e == null:
			continue
		out["max_hp"] += e.bonus_hp
		out["max_mp"] += e.bonus_mp
		out["magic"] += e.bonus_magic
		out["defense"] += e.bonus_defense
	return out


func eff_max_hp() -> int:
	return max_hp + star_bonus()["max_hp"] + equip_bonus()["max_hp"]


func eff_max_mp() -> int:
	return max_mp + star_bonus()["max_mp"] + equip_bonus()["max_mp"]


func eff_magic() -> int:
	return magic + star_bonus()["magic"] + equip_bonus()["magic"]


func eff_defense() -> int:
	return defense + equip_bonus()["defense"]


## 获得修为（点亮星子）。返回事件列表：
## [{"type":"dust"},{"type":"star","stage":..,"star":..},{"type":"bottleneck"}]
## 瓶颈期修为无法继续注入（需先突破）。
## 星子连线即"脱胎换骨"：当场回满 HP/MP（升阶回血的规则锚点）。
func gain_xp(element: int, amount: int) -> Array:
	var events: Array = []
	if not ranks.has(element) or amount <= 0:
		return events
	var r: Dictionary = ranks[element]
	if r["bottleneck"]:
		return events
	r["dust"] = r["dust"] + amount
	events.append({"type": "dust", "element": element, "amount": amount})
	while r["dust"] >= GameTypes.STARDUST_PER_STAR and r["star"] < GameTypes.STARS_PER_STAGE - 1:
		r["dust"] -= GameTypes.STARDUST_PER_STAR
		r["star"] += 1
		events.append({"type": "star", "element": element, "stage": r["stage"], "star": r["star"]})
		full_restore()
	if r["star"] >= GameTypes.STARS_PER_STAGE - 1 and r["dust"] >= GameTypes.STARDUST_PER_STAR:
		r["dust"] = GameTypes.STARDUST_PER_STAR
		r["bottleneck"] = true
		events.append({"type": "bottleneck", "element": element})
	return events


## 突破晋升（需处于瓶颈）。成功后进入下一阶一星，气血充盈回满状态。
func breakthrough(element: int) -> bool:
	if not is_bottleneck(element):
		return false
	var r: Dictionary = ranks[element]
	r["stage"] = mini(r["stage"] + 1, GameTypes.Stage.SUPER)
	r["star"] = 0
	r["dust"] = 0
	r["bottleneck"] = false
	full_restore()
	return true


## 当前系可施展的法术（阶位达标的）。
func usable_spells(element: int) -> Array[SpellData]:
	var out: Array[SpellData] = []
	for s in spells:
		if s.element == element and s.tier <= stage_of(element):
			out.append(s)
	return out


## 当前战斗形态对应的元素系。
func form_element() -> int:
	if elements.is_empty():
		return main_element
	return elements[clampi(form, 0, elements.size() - 1)]


func change_hp(delta: int) -> int:
	hp = clampi(hp + delta, 0, eff_max_hp())
	return hp


func change_mp(delta: int) -> int:
	mp = clampi(mp + delta, 0, eff_max_mp())
	return mp


func full_restore() -> void:
	hp = eff_max_hp()
	mp = eff_max_mp()
	reset_battle_state()


func reset_battle_state() -> void:
	battle_stars = 0
	defending = false
	burn_turns = 0
	paralyzed = false


## —— 存档序列化 ——
## 注意：JSON 会把字典 int 键转为字符串、数字转为浮点，两侧需显式转换。

func to_dict() -> Dictionary:
	var spell_ids := []
	for s in spells:
		spell_ids.append(s.id)
	var ranks_out := {}
	for el in ranks:
		ranks_out[str(el)] = ranks[el]
	var equips_out := {}
	for slot in equips:
		equips_out[str(slot)] = equips[slot]
	return {
		"id": id, "name": char_name, "elements": elements,
		"main_element": main_element, "form": form,
		"can_switch_form": can_switch_form, "ranks": ranks_out,
		"spells": spell_ids,
		"equips": equips_out,
		"max_hp": max_hp, "max_mp": max_mp, "magic": magic,
		"defense": defense, "speed": speed,
		"hp": hp, "mp": mp,
	}


## 从存档字典恢复状态（原静态工厂 from_dict 改实例方法，同上消除自引用）。
## 调用方先 CharacterState.new() 再 apply_dict(d)。
func apply_dict(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	char_name = str(d.get("name", ""))
	elements = []
	for el in d.get("elements", []):
		elements.append(int(el))
	main_element = int(d.get("main_element", GameTypes.Element.FIRE))
	form = int(d.get("form", 0))
	can_switch_form = bool(d.get("can_switch_form", false))
	for key in d.get("ranks", {}):
		var r: Dictionary = d["ranks"][key]
		ranks[int(key)] = {
			"stage": int(r.get("stage", 0)),
			"star": int(r.get("star", 0)),
			"dust": int(r.get("dust", 0)),
			"bottleneck": bool(r.get("bottleneck", false)),
		}
	for sid in d.get("spells", []):
		var s := GameData.load_spell(str(sid))
		if s != null:
			spells.append(s)
	for slot in d.get("equips", {}):
		equips[str(slot)] = str(d["equips"][slot])
	max_hp = int(d.get("max_hp", 80))
	max_mp = int(d.get("max_mp", 30))
	magic = int(d.get("magic", 10))
	defense = int(d.get("defense", 3))
	speed = int(d.get("speed", 8))
	hp = int(d.get("hp", max_hp))
	mp = int(d.get("mp", max_mp))
