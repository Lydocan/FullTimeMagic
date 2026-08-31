extends Node
## 全局游戏状态（autoload：GameState）。
##
## 持有队伍、资源、剧情旗标与场景往返数据。持久化（存档）属 M2 范围。

## 精魄突破所需数量（原型期统一 1 个）。
const ESSENCE_COST := 1

var party: Array[CharacterState] = []
var gold: int = 30
## 精魄持有：{essence_id: count}
var essences: Dictionary = {}
## 剧情旗标：{flag: true}
var flags: Dictionary = {}
## 遇敌与场景往返（原型期全局暂存，正式版走场景传参）。
var pending_enemies: Array = []
## 战斗胜利后要点亮的剧情旗标（"" 为无，如明雷精英战）。
var pending_flag: String = ""
var return_position := Vector2.ZERO
var has_return_position := false


func _ready() -> void:
	_setup_cjk_font()
	new_game()


## 开新档（原型期：启动即组队）。
func new_game() -> void:
	party.clear()
	party.append(PartySetup.mo_fan())
	party.append(PartySetup.mu_ningxue())
	GameEvents.party_status_changed.emit()


## 元素对应的精魄 id（命名约定：essence_<拼音>）。
func essence_for_element(element: int) -> String:
	match element:
		GameTypes.Element.FIRE: return "essence_fire"
		GameTypes.Element.ICE: return "essence_ice"
		GameTypes.Element.LIGHTNING: return "essence_lightning"
		GameTypes.Element.WIND: return "essence_wind"
		GameTypes.Element.EARTH: return "essence_earth"
	return ""


func add_gold(delta: int) -> int:
	gold = maxi(gold + delta, 0)
	GameEvents.gold_changed.emit(gold)
	return gold


func essence_count(id: String) -> int:
	return essences.get(id, 0)


func add_essence(id: String) -> int:
	essences[id] = essence_count(id) + 1
	GameEvents.essence_changed.emit(id, essences[id])
	return essences[id]


func take_essence(id: String, count: int = 1) -> bool:
	if essence_count(id) < count:
		return false
	essences[id] = essence_count(id) - count
	GameEvents.essence_changed.emit(id, essences[id])
	return true


## 战斗胜利结算：每位存活成员向主修系注入修为，金币与精魄入账。
## 返回结算摘要（含成长事件），供战斗结果面板展示。
func grant_battle_rewards(xp_each: int, gold_gain: int, essence_ids: Array) -> Dictionary:
	var summary := {"xp": xp_each, "gold": gold_gain, "essences": [], "events": []}
	for m in party:
		if m.hp <= 0:
			continue
		var el := m.main_element
		for ev in m.gain_xp(el, xp_each):
			var entry := {"member": m.char_name, "ev": ev}
			summary["events"].append(entry)
			match ev["type"]:
				"dust":
					GameEvents.xp_gained.emit(m.char_name, el, ev["amount"])
				"star":
					GameEvents.star_advanced.emit(m.char_name, el, ev["stage"], ev["star"])
				"bottleneck":
					GameEvents.bottleneck_reached.emit(m.char_name, el)
	add_gold(gold_gain)
	for eid in essence_ids:
		add_essence(eid)
		summary["essences"].append(eid)
	GameEvents.party_status_changed.emit()
	return summary


## 突破晋升：需该系处于瓶颈且持有对应精魄。
func try_breakthrough(member: CharacterState, element: int) -> bool:
	if not member.is_bottleneck(element):
		return false
	if not take_essence(essence_for_element(element), ESSENCE_COST):
		return false
	member.breakthrough(element)
	GameEvents.stage_advanced.emit(member.char_name, element, member.stage_of(element))
	GameEvents.party_status_changed.emit()
	return true


## 营地休息：全体恢复。
func rest_at_camp() -> void:
	for m in party:
		m.full_restore()
	GameEvents.party_status_changed.emit()


## —— 原型期辅助：中文界面字体兜底（Windows 系统字体） ——

func _setup_cjk_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "PingFang SC", "sans-serif",
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	get_window().theme = theme
