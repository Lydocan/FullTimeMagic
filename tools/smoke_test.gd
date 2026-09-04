extends Node
## M2 冒烟测试：无头验证位阶成长、瓶颈突破、战斗模拟、存档序列化与地图完整性。
##
## 运行：godot --headless --path . res://tools/smoke_test.tscn
## 退出码 0 = 全部通过，1 = 存在失败项。
## 注意：只测 make_save_data / apply_save_data 纯数据往返，不写 savegame.json，
## 避免覆盖玩家的真实存档。

var _failures: Array[String] = []
var _total := 0

## 场景路径 → 脚本路径（地图完整性测试用）。
const MAP_SCRIPTS := {
	"res://src/world/test_wilds/test_wilds.tscn": "res://src/world/test_wilds/test_wilds.gd",
	"res://src/world/bo_city/bo_city.tscn": "res://src/world/bo_city/bo_city.gd",
	"res://src/world/misty_grove/misty_grove.tscn": "res://src/world/misty_grove/misty_grove.gd",
	"res://src/world/arena/duel_arena.tscn": "res://src/world/arena/duel_arena.gd",
}
const BLOCKED := "TRWFBD"  # 树/岩石/水/屋顶/墙/门为阻挡格

## 按路径引用基类，避免 class_name 全局缓存过期时解析失败
const MapBaseScript := preload("res://src/world/map_base.gd")


func _check(cond: bool, label: String) -> void:
	_total += 1
	if cond:
		print("  PASS  ", label)
	else:
		_failures.append(label)
		printerr("  FAIL  ", label)


func _ready() -> void:
	print("=== FullTimeMagic M2 冒烟测试 ===")
	_test_rank_progression()
	_test_breakthrough()
	await _test_battle_simulation()
	_test_character_serialization()
	_test_save_roundtrip()
	_test_defeat_recovery()
	_test_npc_and_objective()
	_test_input_map()
	_test_economy()
	await _test_duel_boss()
	await _test_audio()
	await _test_dialogue_autoclose()
	_test_map_integrity()
	if _failures.is_empty():
		print("=== 全部通过（%d 项）===" % _total)
		get_tree().quit(0)
	else:
		printerr("=== 失败 %d / %d 项 ===" % [_failures.size(), _total])
		get_tree().quit(1)


## 位阶成长：修为 → 点亮星子 → 星级 → 三星圆满瓶颈。
func _test_rank_progression() -> void:
	print("[位阶成长]")
	var m := PartySetup.mo_fan()
	_check(m.stage_of(GameTypes.Element.LIGHTNING) == 0, "莫凡雷系初阶")
	_check(m.star_of(GameTypes.Element.LIGHTNING) == 0, "莫凡雷系一星")
	m.change_hp(-30)
	m.gain_xp(GameTypes.Element.LIGHTNING, 7)
	_check(m.star_of(GameTypes.Element.LIGHTNING) == 1, "+7 修为 → 二星")
	_check(m.hp == m.eff_max_hp() and m.mp == m.eff_max_mp(), "星子连线脱胎换骨：状态回满")
	_check(m.eff_max_hp() == 90 + 7 * 6, "星子加成：HP 90+42")
	_check(m.rank_label(GameTypes.Element.LIGHTNING) == "雷系·初阶二星", "位阶文本")
	m.gain_xp(GameTypes.Element.LIGHTNING, 7)
	_check(m.star_of(GameTypes.Element.LIGHTNING) == 2, "再 +7 → 三星")
	_check(not m.is_bottleneck(GameTypes.Element.LIGHTNING), "三星但未圆满，不算瓶颈")
	m.gain_xp(GameTypes.Element.LIGHTNING, 6)
	_check(m.dust_of(GameTypes.Element.LIGHTNING) == 6 and not m.is_bottleneck(GameTypes.Element.LIGHTNING),
			"圆满前夜：星子 6/7 未触发瓶颈")
	var hp_before := m.eff_max_hp()
	m.gain_xp(GameTypes.Element.LIGHTNING, 1)
	_check(m.is_bottleneck(GameTypes.Element.LIGHTNING), "第 21 颗星子点亮 → 三星圆满进入瓶颈")
	_check(m.eff_max_hp() > hp_before, "圆满星子带来属性成长")
	_check(m.gain_xp(GameTypes.Element.LIGHTNING, 10).is_empty(), "瓶颈期修为封存")
	# 双系独立：雷系瓶颈不影响火系修炼
	m.gain_xp(GameTypes.Element.FIRE, 7)
	_check(m.star_of(GameTypes.Element.FIRE) == 1 and not m.is_bottleneck(GameTypes.Element.FIRE), "双系独立修炼")


## 突破：瓶颈 + 对应精魄 → 晋升下一阶，解锁该阶法术。
func _test_breakthrough() -> void:
	print("[突破晋升]")
	var m := PartySetup.mo_fan()
	m.gain_xp(GameTypes.Element.FIRE, 99)
	_check(m.is_bottleneck(GameTypes.Element.FIRE), "火系进入瓶颈")
	_check(not GameState.try_breakthrough(m, GameTypes.Element.FIRE), "无精魄不可突破")
	GameState.add_essence("essence_fire")
	_check(GameState.try_breakthrough(m, GameTypes.Element.FIRE), "持精魄突破成功")
	_check(m.stage_of(GameTypes.Element.FIRE) == 1 and m.star_of(GameTypes.Element.FIRE) == 0,
			"晋升中阶一星")
	_check(GameState.essence_count("essence_fire") == 0, "突破消耗精魄")

	var mid := SpellData.new()
	mid.element = GameTypes.Element.FIRE
	mid.tier = 1
	mid.mp_cost = 0
	m.spells.append(mid)
	_check(m.usable_spells(GameTypes.Element.FIRE).has(mid), "晋升后可施展中阶法术")

	var rookie := PartySetup.mo_fan()
	rookie.spells.append(mid)
	_check(not rookie.usable_spells(GameTypes.Element.FIRE).has(mid), "初阶不能施展中阶法术")


## 战斗模拟：无头跑完一场真实战斗（星辉增幅/破魔/结算全走正式逻辑）。
func _test_battle_simulation() -> void:
	print("[战斗模拟]")
	GameState.new_game()
	GameState.join_member(PartySetup.mu_ningxue())
	_check(GameState.party.size() == 2, "剧情入队：莫凡 + 穆宁雪")
	GameState.pending_enemies = ["rat_swarm", "rat_swarm"]
	GameState.pending_flag = ""
	var battle: Node2D = (load("res://src/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	var result: Dictionary = await battle.run_simulation()
	print("  模拟结果：", result)
	_check(result["victory"], "队伍击败双鼠潮")
	_check(GameState.gold == 30 + 12, "金币结算 30+12")
	var mofan := GameState.party[0]
	var xue := GameState.party[1]
	_check(mofan.dust_of(GameTypes.Element.LIGHTNING) > 0 or mofan.star_of(GameTypes.Element.LIGHTNING) > 0,
			"莫凡主修系获得修为")
	_check(xue.is_bottleneck(GameTypes.Element.ICE)
			and xue.dust_of(GameTypes.Element.ICE) == GameTypes.STARDUST_PER_STAR,
			"穆宁雪瓶颈期修为封存（星子保持圆满 7/7）")
	battle.queue_free()
	await get_tree().process_frame


## 角色序列化：to_dict → JSON → from_dict 往返（真实存档路径）。
func _test_character_serialization() -> void:
	print("[角色序列化]")
	var m := PartySetup.mo_fan()
	m.gain_xp(GameTypes.Element.LIGHTNING, 8)
	m.main_element = GameTypes.Element.FIRE
	m.hp = 55
	m.mp = 7
	# JSON.parse_string 返回 Variant，不能用 := 推断（项目将其视为错误）
	var json = JSON.parse_string(JSON.stringify(m.to_dict()))
	var m2 := CharacterState.from_dict(json)
	_check(m2.id == m.id and m2.char_name == m.char_name, "角色往返：id 与名字")
	_check(m2.elements == m.elements and m2.main_element == m.main_element, "角色往返：元素与主修")
	_check(m2.stage_of(GameTypes.Element.LIGHTNING) == m.stage_of(GameTypes.Element.LIGHTNING)
			and m2.star_of(GameTypes.Element.LIGHTNING) == m.star_of(GameTypes.Element.LIGHTNING)
			and m2.dust_of(GameTypes.Element.LIGHTNING) == m.dust_of(GameTypes.Element.LIGHTNING),
			"角色往返：位阶进度（阶/星/修为）")
	_check(m2.spells.size() == m.spells.size(), "角色往返：法术表")
	_check(m2.max_hp == m.max_hp and m2.magic == m.magic and m2.speed == m.speed, "角色往返：基础属性")
	_check(m2.hp == 55 and m2.mp == 7, "角色往返：当前 HP/MP")
	_check(m2.eff_max_hp() == m.eff_max_hp(), "角色往返：星子加成恢复")


## 存档往返：make_save_data → JSON → apply_save_data（不落盘）。
func _test_save_roundtrip() -> void:
	print("[存档往返]")
	GameState.new_game()
	GameState.gold = 77
	GameState.add_essence("essence_fire")
	GameState.add_essence("essence_fire")
	GameState.flags["test_flag"] = true
	GameState.join_member(PartySetup.mu_ningxue())
	GameState.return_position = Vector2(123, 456)
	GameState.has_return_position = true
	var save = JSON.parse_string(JSON.stringify(SaveSystem.make_save_data()))
	GameState.new_game()
	_check(GameState.party.size() == 1, "new_game 后仅莫凡一人")
	_check(SaveSystem.apply_save_data(save), "存档数据应用成功")
	_check(GameState.gold == 77, "读档：金币")
	_check(GameState.essence_count("essence_fire") == 2, "读档：精魄")
	_check(GameState.flags.get("test_flag", false), "读档：剧情旗标")
	_check(GameState.party.size() == 2 and GameState.party[1].char_name == "穆宁雪", "读档：队伍含穆宁雪")
	_check(GameState.return_position == Vector2(123, 456) and GameState.has_return_position, "读档：返回坐标")
	_check(GameState.pending_enemies.is_empty() and GameState.pending_flag == "", "读档：战斗残留清空")


## 战败恢复：读回存档（状态还原、战斗残留清空）；无存档重开新旅程。
## 用隔离存档路径跑，不碰真实 savegame.json。
func _test_defeat_recovery() -> void:
	print("[战败恢复]")
	var real_path: String = SaveSystem.save_path
	SaveSystem.save_path = "user://ftm_smoke_save.json"
	if FileAccess.file_exists(SaveSystem.save_path):
		DirAccess.remove_absolute(SaveSystem.save_path)
	# 无存档：重开新旅程（状态重置 + 去首场景）
	GameState.gold = 999
	GameState.join_member(PartySetup.mu_ningxue())
	var scene: String = SaveSystem.defeat_return_scene()
	_check(scene == SaveSystem.FIRST_SCENE, "无存档战败 → 重开新旅程（首场景）")
	_check(GameState.gold == 30 and GameState.party.size() == 1, "无存档战败 → 状态重置")
	# 有存档：读回存档场景与状态，战斗残留清空（不再原地循环再战）
	GameState.new_game()
	GameState.gold = 123
	GameState.flags["smoke_defeat"] = true
	GameState.battle_return_scene = "res://src/battle/battle.tscn"
	SaveSystem.save_game()
	GameState.gold = 777
	GameState.flags = {}
	var saved_scene: String = get_tree().current_scene.scene_file_path
	scene = SaveSystem.defeat_return_scene()
	_check(scene == saved_scene, "战败读档 → 去向为存档场景")
	_check(GameState.gold == 123 and GameState.flags.get("smoke_defeat", false), "战败读档 → 状态还原")
	_check(GameState.battle_return_scene == "" and GameState.pending_enemies.is_empty(),
			"战败读档 → 战斗残留清空")
	if FileAccess.file_exists(SaveSystem.save_path):
		DirAccess.remove_absolute(SaveSystem.save_path)
	SaveSystem.save_path = real_path


## 输入映射：WASD 导航、E 确认、Z 循环增幅（战斗与菜单全键盘简化）。
func _test_input_map() -> void:
	print("[输入映射]")
	_check(_has_key("ui_up", KEY_W) and _has_key("ui_down", KEY_S), "W/S 等同上下导航")
	_check(_has_key("ui_left", KEY_A) and _has_key("ui_right", KEY_D), "A/D 等同左右导航")
	_check(_has_key("ui_accept", KEY_E), "E 等同回车确认")
	_check(_has_key("boost_cycle", KEY_Z), "Z 循环星辉增幅")
	_check(_has_key("ui_up", KEY_UP) and _has_key("ui_accept", KEY_ENTER), "方向键/回车原生键保留")
	_check(_has_key("move_up", KEY_W) and _has_key("move_left", KEY_A), "探索移动 WASD 保留")


func _has_key(action: String, keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null and k.physical_keycode == keycode:
			return true
	return false


## 音频：清单文件齐全，BGM 切换与同名去重，SFX 播放不异常。
func _test_audio() -> void:
	print("[音频]")
	var missing := []
	for key in Audio.BGM:
		if not ResourceLoader.exists(Audio.BGM[key]):
			missing.append(key)
	for key in Audio.SFX:
		if not ResourceLoader.exists(Audio.SFX[key]):
			missing.append(key)
	_check(Audio.BGM.size() == 4 and Audio.SFX.size() >= 14 and missing.is_empty(),
			"音频清单齐全（BGM %d + SFX %d）%s" % [Audio.BGM.size(), Audio.SFX.size(), missing])
	Audio.play_bgm("town")
	_check(Audio.current_bgm == "town", "BGM 切换为城镇")
	Audio.play_bgm("battle")
	_check(Audio.current_bgm == "battle", "BGM 切换为战斗")
	Audio.play_sfx("hit")
	Audio.play_sfx("hit")  # 并发播放走不同通道
	_check(Audio.current_bgm == "battle", "SFX 不影响 BGM")
	Audio.play_bgm("")


## 经济闭环：道具/装备数据、背包存档往返、装备加成、商店扣款、道具使用。
func _test_economy() -> void:
	print("[经济闭环]")
	# 数据注册表完整
	var missing := []
	for key in GameData.ITEMS:
		if ResourceLoader.exists(GameData.ITEMS[key]) == false:
			missing.append(key)
	for key in GameData.EQUIPS:
		if ResourceLoader.exists(GameData.EQUIPS[key]) == false:
			missing.append(key)
	_check(GameData.ITEMS.size() >= 3 and GameData.EQUIPS.size() >= 3 and missing.is_empty(),
			"道具/装备注册表齐全 %s" % [missing])
	# 商店扣款
	GameState.new_game()
	GameState.gold = 100
	_check(GameState.try_spend(30) and GameState.gold == 70, "商店扣款成功")
	_check(not GameState.try_spend(999) and GameState.gold == 70, "余额不足拒绝扣款")
	GameState.add_item("yuelu")
	GameState.add_equip("leiwen_zhang", 2)
	_check(GameState.item_count("yuelu") == 1, "道具入包计数")
	# 背包 + 装备 存档往返
	GameState.gold = 55
	var m := GameState.party[0]
	m.equips["weapon"] = "leiwen_zhang"
	var save = JSON.parse_string(JSON.stringify(SaveSystem.make_save_data()))
	GameState.new_game()
	GameState.items = {"mojingjie": 5}
	GameState.equip_bag = {"yuebai_pao": 1}
	SaveSystem.apply_save_data(save)
	_check(GameState.gold == 55 and GameState.item_count("yuelu") == 1 and GameState.items.size() == 1,
			"读档：金币与道具")
	_check(GameState.equip_bag.get("leiwen_zhang", 0) == 2, "读档：装备背包")
	var m2 := GameState.party[0]
	_check(m2.equips.get("weapon", "") == "leiwen_zhang", "读档：装备槽")
	# 装备加成
	var bare := PartySetup.mo_fan()
	var armed := PartySetup.mo_fan()
	armed.equips["weapon"] = "leiwen_zhang"
	armed.equips["armor"] = "yuebai_pao"
	_check(armed.eff_magic() == bare.eff_magic() + 4, "法杖加成：法攻+4")
	_check(armed.eff_max_hp() == bare.eff_max_hp() + 30, "护袍加成：生命+30")
	_check(armed.eff_defense() == bare.eff_defense() + 2, "护袍加成：防御+2")
	# 道具使用
	var wounded := PartySetup.mo_fan()
	wounded.change_hp(-30)
	var yuelu: ItemData = GameData.load_item("yuelu")
	wounded.change_hp(yuelu.amount)
	_check(wounded.hp == wounded.eff_max_hp() - 30 + 40 or wounded.hp == wounded.eff_max_hp(),
			"月露回复生效")
	var feather: ItemData = GameData.load_item("fuhuo_yumao")
	_check(feather.battle_only, "复活羽毛仅战斗可用")
	GameState.new_game()


## M3.1 毕业决斗：出战成员子集（单人决斗）与 Boss 模拟战。
func _test_duel_boss() -> void:
	print("[毕业决斗]")
	_check(ResourceLoader.exists(GameData.MONSTERS["yu_ang"]), "宇昂 Boss 数据就绪")
	GameState.new_game()
	GameState.join_member(PartySetup.mu_ningxue())
	# 决斗时点的基准练度：雷系初阶三星（瓶颈）
	GameState.party[0].gain_xp(GameTypes.Element.LIGHTNING, 21)
	GameState.pending_enemies = ["yu_ang"]
	GameState.pending_flag = "duel_won"
	GameState.pending_party_ids = ["mo_fan"]
	var battle: Node2D = (load("res://src/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	var result: Dictionary = await battle.run_simulation()
	_check(result["victory"], "莫凡单人击败宇昂")
	_check(int(result["rounds"]) <= 24, "决斗回合数在设计区间（%s）" % result["rounds"])
	_check(GameState.flags.get("duel_won", false), "胜利点亮旗标 duel_won")
	var mofan: CharacterState = GameState.party[0]
	var xue: CharacterState = GameState.party[1]
	_check(mofan.dust_of(GameTypes.Element.LIGHTNING) > 0 or mofan.star_of(GameTypes.Element.LIGHTNING) > 0,
			"出战者莫凡获得修为")
	_check(xue.dust_of(GameTypes.Element.ICE) == GameTypes.STARDUST_PER_STAR
			and xue.star_of(GameTypes.Element.ICE) == 2,
			"观战者穆宁雪不结算修为（保持瓶颈封存态）")
	battle.queue_free()
	await get_tree().process_frame
	GameState.new_game()


## 对话自动收起：台词进行中面板保持，连续台词不闪烁，序列结束后下一帧隐藏。
func _test_dialogue_autoclose() -> void:
	print("[对话收起]")
	var seq := func() -> void:
		await Dialogue.say("甲", "第一页台词。")
		await Dialogue.say("乙", "第二页台词。")
	seq.call()
	await _wait_typed()
	_check(Dialogue.visible, "台词进行中：面板保持显示")
	Dialogue._advanced.emit()  # 推进第一页 → 剧情接续第二页
	await get_tree().process_frame
	_check(Dialogue.visible, "连续台词：面板不中途收起")
	await _wait_typed()
	Dialogue._advanced.emit()  # 推进最后一页 → 序列结束
	await get_tree().process_frame
	_check(not Dialogue.visible, "序列结束：面板自动收起")


## 等当前打字机逐字完成（say 满字后停在 await _advanced）。
func _wait_typed() -> void:
	for i in 30:
		if not Dialogue._typing:
			break
		await get_tree().process_frame
	await get_tree().process_frame


## 剧情引导：NPC 注册完整性（站格可通行/退场旗标有效/立绘存在）与目标提示推进。
func _test_npc_and_objective() -> void:
	print("[剧情引导]")
	var known_flags := ["prologue_awaken_done", "prologue_done", "ch1_mufu_done", "ch1_yuang_done", "duel_done"]
	var npc_total := 0
	var npc_ok := true
	for scene_path in MAP_SCRIPTS:
		var m: MapBaseScript = (load(MAP_SCRIPTS[scene_path]) as GDScript).new()
		m.setup_triggers()
		for n in m._npcs:
			npc_total += 1
			if BLOCKED.contains(m._cell_char(n["cell"])):
				npc_ok = false
				printerr("    NPC 站在阻挡格：%s %s %s" % [scene_path.get_file(), n["name"], n["cell"]])
			if n["hide_flag"] != "" and not (n["hide_flag"] in known_flags):
				npc_ok = false
			if not ResourceLoader.exists(n["texture"]):
				npc_ok = false
		m.free()
	_check(npc_total >= 4, "剧情 NPC 已上场（%d 位）" % npc_total)
	_check(npc_ok, "NPC 站格可通行、退场旗标与立绘有效")
	# 目标提示随旗标逐段推进
	var city: MapBaseScript = (load(MAP_SCRIPTS["res://src/world/bo_city/bo_city.tscn"]) as GDScript).new()
	GameState.new_game()
	_check(city._objective_text().contains("觉醒典礼"), "目标提示：序章·觉醒典礼")
	GameState.flags["prologue_awaken_done"] = true
	_check(city._objective_text().contains("灰雾林地"), "目标提示：林地试练")
	GameState.flags["prologue_done"] = true
	_check(city._objective_text().contains("东街"), "目标提示：东街重逢")
	GameState.flags["ch1_mufu_done"] = true
	GameState.flags["ch1_yuang_done"] = true
	_check(city._objective_text().contains("狼王"), "目标提示：讨伐狼王")
	GameState.flags["elite_wolf_dead"] = true
	_check(city._objective_text().contains("查看"), "目标提示：查看狼王异常")
	GameState.flags["chapter1_half_done"] = true
	_check(city._objective_text().contains("毕业决斗"), "目标提示：毕业决斗")
	GameState.flags["duel_done"] = true
	_check(city._objective_text().contains("后续版本"), "目标提示：决斗完结")
	GameState.new_game()
	city.free()


## 地图完整性：行列结构、出生点/触发点/传送门两端/精英格均可通行。
func _test_map_integrity() -> void:
	print("[地图完整性]")
	var maps := {}
	for scene_path in MAP_SCRIPTS:
		var map: MapBaseScript = (load(MAP_SCRIPTS[scene_path]) as GDScript).new()
		map.setup_triggers()  # 注册触发器/传送门/篝火（不入树，仅数据层校验）
		maps[scene_path] = map
	for scene_path in maps:
		var map: MapBaseScript = maps[scene_path]
		var name: String = scene_path.get_file()
		var rows := map.map_rows()
		_check(rows.size() % 4 == 0, "%s：地图行数为 4 的倍数" % name)
		var width_ok := true
		for r in rows:
			if str(r).length() != 10:
				width_ok = false
		_check(width_ok, "%s：每段恰好 10 格" % name)
		_check(not BLOCKED.contains(map._cell_char(map.start_cell())), "%s：出生点可通行" % name)
		var trig_ok := true
		for t in map._triggers:
			if BLOCKED.contains(map._cell_char(t["cell"])):
				trig_ok = false
		_check(trig_ok, "%s：剧情触发点均可通行" % name)
		var portal_ok := true
		for p in map._portals:
			if BLOCKED.contains(map._cell_char(p["cell"])):
				portal_ok = false
			# 目的地出生格在目标地图上也要能站人（跨地图校验）
			var target: MapBaseScript = maps.get(p["target"])
			if target != null and BLOCKED.contains(target._cell_char(p["spawn"])):
				portal_ok = false
		_check(portal_ok, "%s：传送门两端均可通行" % name)
		var elite_bad := ""
		for e in map.elite_spawns():
			var ch: String = map._cell_char(e["cell"])
			if BLOCKED.contains(ch):
				elite_bad += "%s=%s " % [e["cell"], ch]
		_check(elite_bad.is_empty(), "%s：精英格可通行 %s" % [name, elite_bad])
	for map in maps.values():
		map.free()
