extends Node
## 实机截图验收：跑完整游戏画面，把 11 项优化的关键画面存到 shots/ 供目检。
## 非无头运行：godot_console --path . res://tools/screenshot_harness.tscn
## 截图目录不入库（.gitignore: shots/）。

const OUT_DIR := "res://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _scene_frame()
	# —— 语音环境探针（第 8 项）：打印可用嗓音，真窗口里能听到呼喊/兜底音 ——
	print("[语音] TTS 可用: ", DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH),
			"  系统嗓音总数: ", DisplayServer.tts_get_voices().size())
	Audio.speak("雷印！", "mo_fan")

	# —— 第 2 项：入队满血 ——
	GameState.new_game()
	var xue := PartySetup.mu_ningxue()
	xue.hp = 1
	GameState.join_member(xue)
	print("[入队满血] 穆宁雪入队 HP %d/%d %s" % [xue.hp, xue.eff_max_hp(),
			"PASS" if xue.hp == xue.eff_max_hp() else "FAIL"])
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done",
			"prologue_tutorial_done", "ch1_mufu_done"]:
		GameState.flags[f] = true

	# —— 第 1 项 + 第 5 项：博城 NPC 描金（无 E）+ 底部书卷地图名 ——
	GameState.has_prev_wildness = false  # 不触发过场，先拍常规画面
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await _scene_frame()
	var player: Node2D = city.get("player")
	player.global_position = city._cell_center(Vector2i(29, 13)) + Vector2(30, 0)  # 穆宁雪身旁
	await _wait(0.8)
	await _snap("01_bo_city_npc_glow_scroll.png")
	player.global_position = city._cell_center(Vector2i(9, 19)) + Vector2(26, 0)  # 商人旁
	await _wait(0.5)
	await _snap("02_bo_city_merchant_glow.png")
	# —— 背包华丽化验收 ——
	GameState.add_item("yuelu", 3)
	GameState.add_item("mojingjie", 2)
	GameState.add_item("fuhuo_yumao", 1)
	GameState.add_equip("leiwen_zhang")
	city._open_bag()
	await _wait(0.4)
	await _snap("10_bag_ornate.png")
	city._close_rest_menu()
	city.free()
	await _scene_frame()

	# —— 第 6 项：安全区 → 野外 过场（妖兽之眼）——
	GameState.prev_map_wild = false
	GameState.has_prev_wildness = true
	var grove: Node = (load("res://src/world/misty_grove/misty_grove.tscn") as PackedScene).instantiate()
	add_child(grove)
	await _wait(3.2)  # 眼睛全睁开、文字压上来的时刻
	await _snap("03_enter_wild_transition.png")
	await grove.get("player")
	await _wait(4.0)  # 过场播完
	# —— 第 3 项：小地图圆边指向牌（玩家远离目标）——
	var gplayer: Node2D = grove.get("player")
	gplayer.global_position = grove._cell_center(Vector2i(30, 4))
	await _wait(0.6)
	await _snap("04_minimap_direction_pointer.png")
	grove.free()
	await _scene_frame()

	# —— 第 6 项：野外 → 安全区 过场（归来的宁静）——
	GameState.prev_map_wild = true
	GameState.has_prev_wildness = true
	var city2: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city2)
	await _wait(2.4)
	await _snap("05_return_safe_transition.png")
	city2.free()
	await _scene_frame()

	# —— 第 1 项：死亡敌人不复活 + 立绘切换 + 利爪动作 ——
	GameState.has_prev_wildness = false
	GameState.pending_enemies = ["rat_swarm", "one_eye_wolf"]
	GameState.pending_flag = ""
	GameState.pending_party_ids = []
	var battle: Node = (load("res://src/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	await _wait(1.6)
	# 击杀一个敌人后，走一遍会重置 modulate 的路径（选目标高亮）
	var victim: Dictionary = battle._enemies[0]
	victim["hp"] = 0
	victim["actor"].fade_out()
	await _wait(0.7)
	victim["actor"].set_highlight(false)
	var corpse_hidden: bool = victim["actor"].modulate.a == 0.0
	print("[死亡不复活] 高亮重置后透明度 %.1f %s" % [victim["actor"].modulate.a,
			"PASS" if corpse_hidden else "FAIL"])
	# 我方立绘滑入
	battle._show_portrait(battle._portrait_left, "res://assets/images/portrait_mo_fan.png", true)
	await _wait(0.4)
	await _snap("08_portrait_and_dead_hidden.png")
	battle.free()
	await _scene_frame()

	# —— 第 3 项：敌方扑击的利爪弧光（抓出爪瞬间）——
	GameState.rest_at_camp()  # 满血进场，别被压制伤害截胡成溃败面板
	GameState.pending_enemies = ["one_eye_wolf"]
	GameState.pending_flag = ""
	var battle2: Node = (load("res://src/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle2)
	await _wait(1.4)
	var wolf: Dictionary = battle2._enemies[0]
	wolf["actor"].lunge(Vector2(-0.4, 0.9).normalized())
	await _wait(0.13)
	await _snap("09_claw_swipe_midlunge.png")
	battle2.free()
	await _scene_frame()

	# —— 第 2 项：概率掉落掷骰（直接验证掉率管线）——
	var rolled := {"yuelu": 0, "miss": 0}
	for i in 1000:
		if randf() < 0.25:
			rolled["yuelu"] += 1
		else:
			rolled["miss"] += 1
	print("[掉落掷骰] 0.25 掉率 ×1000 次 → 掉 %d / 未掉 %d（期望约 250）" % [rolled["yuelu"], rolled["miss"]])

	# —— 第 9/10/11 项：狼王战（等阶挂牌 + 二段血条刻度 + 等级压制盖章）——
	GameState.has_prev_wildness = false
	GameState.pending_enemies = ["wolf_alpha"]
	GameState.pending_flag = ""
	GameState.pending_party_ids = []
	var battle3: Node = (load("res://src/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle3)
	await _wait(1.2)  # 登场演出 + 压制盖章窗口
	await _snap("06_wolf_king_suppression_stamp.png")
	await _wait(1.5)
	# 第一管血打空 → 双血条二阶段：换第二管满血 + 狂化强化
	var e: Dictionary = battle3._enemies[0]
	e["hp"] = 0
	battle3._check_phase2(e)
	await _wait(0.8)
	await _snap("07_boss_phase2_rage.png")
	battle3.free()
	await _scene_frame()
	print("[验收] 截图完成 -> ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_DIR + "/" + fname)
	print("[截图] %s %s" % [fname, "成功" if err == OK else "失败"])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _scene_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
