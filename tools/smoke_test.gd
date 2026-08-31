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
}
const BLOCKED := "TRW"  # 树/岩石/水为阻挡格

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
	m.gain_xp(GameTypes.Element.LIGHTNING, 7)
	_check(m.star_of(GameTypes.Element.LIGHTNING) == 1, "+7 修为 → 二星")
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
