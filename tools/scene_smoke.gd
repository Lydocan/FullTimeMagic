extends Node
## 场景冒烟：完整实例化三张地图跑 _ready（瓦片/玩家/篝火/HUD/触发器注册）。
## 用旗标跳过会等待输入的剧情对话，无头环境可安全运行。

const MAP_SCENES := [
	"res://src/world/test_wilds/test_wilds.tscn",
	"res://src/world/bo_city/bo_city.tscn",
	"res://src/world/misty_grove/misty_grove.tscn",
	"res://src/world/arena/duel_arena.tscn",
]


func _ready() -> void:
	print("=== 场景冒烟 ===")
	# 预置剧情旗标：所有触发器直接 early-return，不弹对话
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done",
			"prologue_tutorial_done", "ch1_mufu_done", "ch1_yuang_done",
			"chapter1_half_done", "duel_intro_done", "duel_fought", "duel_won", "duel_done"]:
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
	var trig_ok: bool = await _test_npc_interact_and_story_battle()
	ok = trig_ok and ok
	var fw_ok: bool = await _test_followers()
	ok = fw_ok and ok
	var retire_ok: bool = await _test_npc_retire()
	ok = retire_ok and ok
	var eq_ok: bool = await _test_equip_flow()
	ok = eq_ok and ok
	print("=== 场景冒烟 %s ===" % ("通过" if ok else "失败"))
	get_tree().quit(0 if ok else 1)


## 装备流程回归：背包 → 选装备 → 选成员。曾因菜单重建帧内焦点被抢给
## queue_free 的幽灵按钮而丢失，成员列表按 E 无响应。
func _test_equip_flow() -> bool:
	print("[装备流程]")
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done",
			"prologue_tutorial_done", "ch1_mufu_done", "ch1_yuang_done"]:
		GameState.flags[f] = true
	GameState.add_equip("leiwen_zhang")
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	city._open_bag()
	await get_tree().process_frame
	await get_tree().process_frame
	for btn in (city.get("_bag_box") as VBoxContainer).get_children():
		if btn is Button and btn.text.contains("雷纹杖"):
			btn.pressed.emit()
	await get_tree().process_frame
	var focus: Control = get_viewport().gui_get_focus_owner()
	var focus_ok: bool = focus != null and not focus.is_queued_for_deletion()
	if focus_ok and focus.text.contains("莫凡"):
		focus.pressed.emit()  # 模拟回车/E 确认
	await get_tree().process_frame
	await get_tree().process_frame
	var equipped: bool = GameState.party[0].equips.get("weapon", "") == "leiwen_zhang" \
			and GameState.equip_bag.is_empty()
	if focus_ok and equipped:
		print("  PASS  背包装备流程（重建后焦点有效 + 穿戴成功）")
	else:
		printerr("  FAIL  装备流程异常（focus_ok=%s equipped=%s）" % [focus_ok, equipped])
	city.free()
	GameState.new_game()
	await get_tree().process_frame
	return focus_ok and equipped


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
	var npc: Area2D = null
	var merchant: Area2D = null
	for node in nodes:
		if node.hide_flag == "ch1_mufu_done":
			npc = node
		elif node.hide_flag == "":
			merchant = node  # 常驻商人
	if npc == null or merchant == null:
		printerr("  FAIL  预期穆宁雪与商人在场")
		city.free()
		GameState.new_game()
		await get_tree().process_frame
		return false
	# 立绘渲染断言：NPC 必须真的画出人物（曾有 texture 参数收了但没建精灵）
	var sprite_ok := false
	for child in npc.get_children():
		if child is Sprite2D and child.texture != null:
			sprite_ok = true
	if sprite_ok:
		print("  PASS  NPC 立绘已渲染（贴图非空）")
	else:
		printerr("  FAIL  NPC 缺少立绘精灵")
	GameState.flags["ch1_mufu_done"] = true  # 模拟剧情已完成
	var obj_before: String = (city.get("_objective_label") as Label).text
	npc.interact()  # 按 E → 事件快速返回（旗标守卫）→ 收尾退场
	await get_tree().process_frame
	await get_tree().process_frame
	# 事件推进旗标后目标提示必须刷新（曾滞留入场时的旧目标）
	var obj_after: String = (city.get("_objective_label") as Label).text
	var hint_ok: bool = obj_after == "◆ " + (city._objective_text() as String) and obj_before != obj_after
	if hint_ok:
		print("  PASS  事件后目标提示已刷新")
	else:
		printerr("  FAIL  目标提示未随事件刷新（%s → %s）" % [obj_before, obj_after])
	var gone: bool = not is_instance_valid(npc) and is_instance_valid(merchant)
	if gone:
		print("  PASS  事件收尾后 NPC 退场（按 E 路径，常驻商人不受影响）")
	else:
		printerr("  FAIL  NPC 未随事件收尾退场")
	city.free()
	GameState.new_game()
	await get_tree().process_frame
	return gone and sprite_ok and hint_ok


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


## 专项回归：①NPC 对话只按 E 主动触发（曾一靠近就自动演出）；
## ②剧情战绕过事件互斥守卫（此前被 _event_running 拦下，教学战开不出来）。
func _test_npc_interact_and_story_battle() -> bool:
	print("[NPC交互与剧情战]")
	var ok := true
	# 摘掉穆宁雪旗标，让事件真正挂起在对话上（无头环境不会推进）
	GameState.flags.erase("ch1_mufu_done")
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout  # 覆盖 _apply_entry_position 计时
	var player: Node2D = city.get("player")
	player.global_position = city._cell_center(Vector2i(29, 12))  # 站到穆宁雪身旁
	city._on_player_moved(1.0)
	var not_fired: bool = not city._event_running
	if not_fired:
		print("  PASS  靠近 NPC 不自动触发对话")
	else:
		printerr("  FAIL  靠近 NPC 仍自动触发对话")
		ok = false
	# 找到穆宁雪 NPC，模拟按 E
	var npc: Area2D = null
	for node in (city.get("_npc_nodes") as Array):
		if node.hide_flag == "ch1_mufu_done":
			npc = node
	if npc != null:
		npc.interact()
	var fired: bool = city._event_running
	if fired:
		print("  PASS  按 E 触发对话（穆宁雪·东街）")
	else:
		printerr("  FAIL  按 E 未触发对话")
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
