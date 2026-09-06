extends Node
## 全局游戏状态（autoload：GameState）。
##
## 持有队伍、资源、剧情旗标与场景往返数据。持久化（存档）属 M2 范围。

## 精魄突破所需数量（原型期统一 1 个）。
const ESSENCE_COST := 1

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const CharacterState := preload("res://src/data/character_state.gd")
const PartySetup := preload("res://src/data/party_setup.gd")
const GameData := preload("res://src/data/game_data.gd")
const GameTypes := preload("res://src/data/game_types.gd")
const ClothingData := preload("res://src/data/clothing_data.gd")

var party: Array[CharacterState] = []
var gold: int = 30
## 精魄持有：{essence_id: count}
var essences: Dictionary = {}
## 消耗品背包：{item_id: count}
var items: Dictionary = {}
## 未装备的装备：{equip_id: count}
var equip_bag: Dictionary = {}
## 衣柜：拥有的衣装 id（纯外观 + 华丽度，见衣装数据定义）。
var owned_clothes: Array = []
## 当前穿着：{"hat"/"top"/"pants": clothing_id}。
var worn_clothes: Dictionary = {}
## 剧情旗标：{flag: true}
var flags: Dictionary = {}
## 遇敌与场景往返（原型期全局暂存，正式版走场景传参）。
var pending_enemies: Array = []
## 战斗胜利后要点亮的剧情旗标（"" 为无，如明雷精英战）。
var pending_flag: String = ""
## 出战成员子集（成员 id 列表；空 = 全队出战，如毕业决斗限莫凡单人）。
var pending_party_ids: Array = []
## 战斗来源地图（战斗结束回这里）。
var battle_return_scene: String = ""
## 传送门目标出生格（-1, -1 表示无）。
var next_spawn := Vector2i(-1, -1)
var return_position := Vector2.ZERO
var has_return_position := false
## 上一张地图的野性状态（跨区过场动画的方向判定，见地图基类的 _maybe_zone_transition）。
var prev_map_wild := false
var has_prev_wildness := false


func _ready() -> void:
	_setup_cjk_font()
	new_game()


## 开新档：只有莫凡（序章中穆宁雪入队）。
func new_game() -> void:
	party.clear()
	party.append(PartySetup.mo_fan())
	gold = 30
	essences = {}
	items = {}
	equip_bag = {}
	_init_wardrobe()
	flags = {}
	pending_enemies = []
	pending_flag = ""
	pending_party_ids = []
	battle_return_scene = ""
	next_spawn = Vector2i(-1, -1)
	return_position = Vector2.ZERO
	has_return_position = false
	GameEvents.party_status_changed.emit()


## 初始衣柜：三套免费套装全数入手（骑士/魔法师/剑士，各 0 华丽度），
## 默认穿着魔法师套装（莫凡的本行）。
func _init_wardrobe() -> void:
	owned_clothes = [
		"cloth_knight_hat", "cloth_knight_top", "cloth_knight_pants",
		"cloth_mage_hat", "cloth_mage_top", "cloth_mage_pants",
		"cloth_sword_hat", "cloth_sword_top", "cloth_sword_pants",
	]
	worn_clothes = {"hat": "cloth_mage_hat", "top": "cloth_mage_top", "pants": "cloth_mage_pants"}


## —— 衣柜：华丽度与称号 ——

func is_clothing_owned(clothing_id: String) -> bool:
	return clothing_id in owned_clothes


## 购得新衣装（重复入手忽略）。返回是否实际入手。
func add_clothing(clothing_id: String) -> bool:
	if is_clothing_owned(clothing_id):
		return false
	owned_clothes.append(clothing_id)
	return true


## 换上某件已拥有的衣装。返回是否成功。
func wear_clothing(slot: String, clothing_id: String) -> bool:
	if not is_clothing_owned(clothing_id):
		return false
	var c: ClothingData = GameData.load_clothing(clothing_id)
	if c == null or c.slot != slot:
		return false
	worn_clothes[slot] = clothing_id
	GameEvents.clothes_changed.emit()  # 玩家分层外观即时刷新
	return true


## 华丽度 = 拥有所有衣装的华丽度总和（与是否穿着无关）。
func glamour_total() -> int:
	var total := 0
	for clothing_id in owned_clothes:
		var c: ClothingData = GameData.load_clothing(clothing_id)
		if c != null:
			total += c.glamour
	return total


## 当前时尚称号（华丽度阶梯，见全局类型表的 FASHION_TITLES）。
func fashion_title() -> String:
	return GameTypes.fashion_title(glamour_total())


## 剧情入队。
func join_member(member: CharacterState) -> void:
	member.full_restore()  # 入队即以巅峰状态并肩（试玩反馈：入队不应带伤）
	party.append(member)
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


## —— 背包与商店 ——

func add_item(item_id: String, count: int = 1) -> int:
	items[item_id] = items.get(item_id, 0) + count
	return items[item_id]


func item_count(item_id: String) -> int:
	return items.get(item_id, 0)


func take_item(item_id: String, count: int = 1) -> bool:
	if items.get(item_id, 0) < count:
		return false
	items[item_id] -= count
	if items[item_id] <= 0:
		items.erase(item_id)
	return true


func add_equip(equip_id: String, count: int = 1) -> int:
	equip_bag[equip_id] = equip_bag.get(equip_id, 0) + count
	return equip_bag[equip_id]


func take_equip(equip_id: String, count: int = 1) -> bool:
	if equip_bag.get(equip_id, 0) < count:
		return false
	equip_bag[equip_id] -= count
	if equip_bag[equip_id] <= 0:
		equip_bag.erase(equip_id)
	return true


## 商店购买：余额充足则扣款。入包由调用方处理。
func try_spend(amount: int) -> bool:
	if gold < amount:
		return false
	add_gold(-amount)
	return true


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
## 战斗结算：修为入账给 members（空 = 全队存活成员）、金币与精魄入包。
func grant_battle_rewards(xp_each: int, gold_gain: int, essence_ids: Array, members: Array = []) -> Dictionary:
	var summary := {"xp": xp_each, "gold": gold_gain, "essences": [], "events": []}
	var receivers := members if not members.is_empty() else party
	for m in receivers:
		if m.hp <= 0:
			continue
		var el: int = m.main_element
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
