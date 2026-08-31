extends Node
## 场景冒烟：完整实例化三张地图跑 _ready（瓦片/玩家/篝火/HUD/触发器注册）。
## 用旗标跳过会等待输入的剧情对话，无头环境可安全运行。

const MAP_SCENES := [
	"res://src/world/test_wilds/test_wilds.tscn",
	"res://src/world/bo_city/bo_city.tscn",
	"res://src/world/misty_grove/misty_grove.tscn",
]


func _ready() -> void:
	print("=== 场景冒烟 ===")
	# 预置剧情旗标：所有触发器直接 early-return，不弹对话
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done",
			"prologue_tutorial_done", "ch1_mufu_done", "ch1_yuang_done"]:
		GameState.flags[f] = true
	var ok := true
	for path in MAP_SCENES:
		GameState.has_return_position = false
		var scene: Node = (load(path) as PackedScene).instantiate()
		add_child(scene)
		await get_tree().create_timer(1.5).timeout  # 覆盖 _apply_entry_position 的计时器
		var player: Node2D = scene.get("player")
		var tiles: TileMapLayer = scene.get("tilemap")
		if player == null or tiles == null:
			printerr("  FAIL  %s：玩家/瓦片缺失" % path.get_file())
			ok = false
		elif tiles.get_used_cells().size() == 0:
			printerr("  FAIL  %s：瓦片未生成" % path.get_file())
			ok = false
		else:
			print("  PASS  %s（瓦片 %d 格，玩家在 %s）" % [
				path.get_file(), tiles.get_used_cells().size(), player.global_position])
		scene.free()
		await get_tree().process_frame
	var trig_ok: bool = await _test_walk_trigger_and_story_battle()
	ok = trig_ok and ok
	var fw_ok: bool = await _test_followers()
	ok = fw_ok and ok
	var retire_ok: bool = await _test_npc_retire()
	ok = retire_ok and ok
	print("=== 场景冒烟 %s ===" % ("通过" if ok else "失败"))
	get_tree().quit(0 if ok else 1)


## NPC 退场：退场检查挂在 run_event 收尾（共用层），走动触发的事件结束后 NPC 随旗标退场。
func _test_npc_retire() -> bool:
	print("[NPC 退场]")
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done",
			"prologue_tutorial_done", "ch1_yuang_done"]:
		GameState.flags[f] = true
	GameState.flags.erase("ch1_mufu_done")  # 穆宁雪 NPC 在场
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	var nodes: Array = city.get("_npc_nodes")
	if nodes.size() != 1:
		printerr("  FAIL  预期 1 位 NPC 在场，实际 %d" % nodes.size())
		city.free()
		GameState.new_game()
		await get_tree().process_frame
		return false
	var npc: Area2D = nodes[0]
	GameState.flags["ch1_mufu_done"] = true  # 模拟剧情已完成
	var player: Node2D = city.get("player")
	player.global_position = city._cell_center(Vector2i(29, 12))
	city._on_player_moved(1.0)  # 走入剧情圈 → 事件快速返回 → 收尾退场
	await get_tree().process_frame
	await get_tree().process_frame
	var gone: bool = not is_instance_valid(npc) and (city.get("_npc_nodes") as Array).is_empty()
	if gone:
		print("  PASS  事件收尾后 NPC 退场（走动触发路径）")
	else:
		printerr("  FAIL  NPC 未随事件收尾退场")
	city.free()
	GameState.new_game()
	await get_tree().process_frame
	return gone


## 队伍跟随：入队成员在地图上以跟随者登场（链式，数量 = 队伍人数 - 1）。
func _test_followers() -> bool:
	print("[队伍跟随]")
	GameState.new_game()
	# 单人：无跟随者
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	var solo_ok: bool = city.get("followers").is_empty()
	if solo_ok:
		print("  PASS  单人队伍无跟随者")
	else:
		printerr("  FAIL  单人队伍出现了跟随者")
	# 入队当刻：不换图即刻登场（曾在入场时才生成，入队后要换图才出现）
	GameState.join_member(PartySetup.mu_ningxue())
	await get_tree().process_frame
	await get_tree().process_frame
	var instant_ok: bool = city.get("followers").size() == 1
	if instant_ok:
		print("  PASS  入队当刻跟随者即登场")
	else:
		printerr("  FAIL  入队后跟随者未即时登场")
	city.free()
	await get_tree().process_frame
	# 换图后跟随持续（入场生成路径）
	var city2: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city2)
	await get_tree().create_timer(1.5).timeout
	var fw: Array = city2.get("followers")
	var duo_ok: bool = fw.size() == 1
	if duo_ok:
		print("  PASS  换图后跟随持续（%d 位）" % fw.size())
	else:
		printerr("  FAIL  换图后跟随者数量错误：%d" % fw.size())
	city2.free()
	GameState.new_game()  # 还原单人队伍
	await get_tree().process_frame
	return solo_ok and instant_ok and duo_ok


## 专项回归：①走动触发（此前只在入场瞬间检查，剧情点走路永远打不开）；
## ②剧情战绕过事件互斥守卫（此前被 _event_running 拦下，教学战开不出来）。
func _test_walk_trigger_and_story_battle() -> bool:
	print("[走动触发与剧情战]")
	var ok := true
	# 摘掉穆宁雪旗标，让事件真正挂起在对话上（无头环境不会推进）
	GameState.flags.erase("ch1_mufu_done")
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout  # 覆盖 _apply_entry_position 计时
	var player: Node2D = city.get("player")
	player.global_position = city._cell_center(Vector2i(29, 12))  # 穆宁雪触发圈内
	city._on_player_moved(1.0)
	var fired: bool = city._event_running
	if fired:
		print("  PASS  走入剧情圈触发事件（穆宁雪·东街）")
	else:
		printerr("  FAIL  走入剧情圈未触发事件")
		ok = false
	# 守卫分支：演出中随机遭遇被拦、剧情战放行
	city._menu = null
	var guard_ok: bool = city._encounter_blocked(false) and not city._encounter_blocked(true)
	if guard_ok:
		print("  PASS  事件互斥守卫：随机战拦下 / 剧情战放行")
	else:
		printerr("  FAIL  事件互斥守卫分支错误")
		ok = false
	city.free()
	await get_tree().process_frame
	return ok
