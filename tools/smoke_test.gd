extends Node
## M1 冒烟测试：无头验证位阶成长、瓶颈突破与战斗模拟。
##
## 运行：godot --headless --path . res://tools/smoke_test.tscn
## 退出码 0 = 全部通过，1 = 存在失败项。

var _failures: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		_failures.append(label)
		printerr("  FAIL  ", label)


func _ready() -> void:
	print("=== FullTimeMagic M1 冒烟测试 ===")
	_test_rank_progression()
	_test_breakthrough()
	await _test_battle_simulation()
	if _failures.is_empty():
		print("=== 全部通过 ===")
		get_tree().quit(0)
	else:
		printerr("=== 失败 %d 项 ===" % _failures.size())
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
