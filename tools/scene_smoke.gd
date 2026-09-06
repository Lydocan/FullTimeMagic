extends Node
## 场景冒烟：完整实例化三张地图跑 _ready（瓦片/玩家/篝火/HUD/触发器注册）。
## 用旗标跳过会等待输入的剧情对话，无头环境可安全运行。

const MAP_SCENES := [
	"res://src/world/test_wilds/test_wilds.tscn",
	"res://src/world/bo_city/bo_city.tscn",
	"res://src/world/misty_grove/misty_grove.tscn",
	"res://src/world/arena/duel_arena.tscn",
]

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const CharacterState := preload("res://src/data/character_state.gd")
const PartySetup := preload("res://src/data/party_setup.gd")
const MapBaseScript := preload("res://src/world/map_base.gd")


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
	var sys_ok: bool = await _test_system_menu()
	ok = sys_ok and ok
	var il_ok: bool = await _test_interact_lock_and_highlight()
	ok = il_ok and ok
	var bt_ok: bool = await _test_breakthrough_button_refresh()
	ok = bt_ok and ok
	var me_ok: bool = await _test_menu_during_entry()
	ok = me_ok and ok
	var wd_ok: bool = _test_wardrobe()
	ok = wd_ok and ok
	var ov_ok: bool = await _test_outfit_visuals()
	ok = ov_ok and ok
	print("=== 场景冒烟 %s ===" % ("通过" if ok else "失败"))
	get_tree().quit(0 if ok else 1)


## 衣柜：初始三套 0 华丽度；换装；购入衣装累计华丽度并晋升称号；
## 重复入手忽略。
func _test_wardrobe() -> bool:
	print("[衣柜]")
	var ok := true
	GameState.new_game()
	if GameState.owned_clothes["mo_fan"].size() == 9 and GameState.glamour_total("mo_fan") == 0 \
			and GameState.fashion_title("mo_fan") == "布衣级":
		print("  PASS  初始三套 9 件全 0 华丽度，称号布衣级")
	else:
		printerr("  FAIL  初始衣柜异常（%d 件，华丽度 %d，称号 %s）" % [
			GameState.owned_clothes["mo_fan"].size(), GameState.glamour_total("mo_fan"),
			GameState.fashion_title("mo_fan")])
		ok = false
	if GameState.wear_clothing("mo_fan", "hat", "cloth_knight_hat") \
			and GameState.worn_clothes["mo_fan"]["hat"] == "cloth_knight_hat":
		print("  PASS  衣柜换装（帽子 → 骑士头盔）")
	else:
		printerr("  FAIL  换装失败")
		ok = false
	GameState.gold += 100
	if GameState.try_spend(100):
		GameState.add_clothing("mo_fan", "cloth_shop_100_hat")
	var g: int = GameState.glamour_total("mo_fan")
	if g == 100 and GameState.fashion_title("mo_fan") == "统领级":
		print("  PASS  华丽度 100 → 称号统领级")
	else:
		printerr("  FAIL  华丽度 %d，称号 %s" % [g, GameState.fashion_title("mo_fan")])
		ok = false
	if not GameState.add_clothing("mo_fan", "cloth_shop_100_hat"):
		print("  PASS  重复衣装不重复入手")
	else:
		printerr("  FAIL  重复衣装被重复计入")
		ok = false
	# —— 穆宁雪：初始连衣裙 + 白丝袜；女仆装 + 黑丝组合；归属校验 ——
	if GameState.glamour_total("mu_ningxue") == 0 \
			and GameState.worn_clothes["mu_ningxue"]["dress"] == "cloth_xue_dress_uniform":
		print("  PASS  穆宁雪初始衣柜（银白常服 + 白丝袜，0 华丽度）")
	else:
		printerr("  FAIL  穆宁雪初始衣柜异常")
		ok = false
	GameState.gold += 250
	GameState.add_clothing("mu_ningxue", "cloth_xue_hosiery_black")
	GameState.add_clothing("mu_ningxue", "cloth_xue_maid")
	if GameState.wear_clothing("mu_ningxue", "hosiery", "cloth_xue_hosiery_black") \
			and GameState.wear_clothing("mu_ningxue", "dress", "cloth_xue_maid") \
			and GameState.glamour_total("mu_ningxue") == 150:
		print("  PASS  穆宁雪换装（女仆装 + 黑丝，华丽度 150）")
	else:
		printerr("  FAIL  穆宁雪换装异常（华丽度 %d）" % GameState.glamour_total("mu_ningxue"))
		ok = false
	if not GameState.add_clothing("mo_fan", "cloth_xue_maid"):
		print("  PASS  衣装归属校验（莫凡买不到穆宁雪的女仆装）")
	else:
		printerr("  FAIL  归属校验失效")
		ok = false
	# 旧版存档迁移：Array 衣柜 → 迁为莫凡所有，穆宁雪补初始衣柜
	GameState.apply_wardrobe_save(["cloth_mage_hat", "cloth_mage_top"], {"hat": "cloth_mage_hat"})
	if GameState.is_clothing_owned("mo_fan", "cloth_mage_hat") \
			and GameState.is_clothing_owned("mu_ningxue", "cloth_xue_dress_uniform"):
		print("  PASS  旧版存档迁移（莫凡继承 + 穆宁雪补初始）")
	else:
		printerr("  FAIL  旧版存档迁移异常")
		ok = false
	return ok


## 换装可视化：玩家分层衣装随 worn_clothes 换图、地图重建后保持、
## 衣柜焦点即试穿（预览层纹理切换）。
func _test_outfit_visuals() -> bool:
	print("[换装可视化]")
	var ok := true
	GameState.new_game()  # 默认魔法师套装（旗标清空无碍：本测试是最后一项）
	GameState.add_clothing("mo_fan", "cloth_shop_100_top")
	GameState.add_clothing("mo_fan", "cloth_shop_1000_pants")
	GameState.add_clothing("mo_fan", "cloth_shop_100_hat")
	GameState.wear_clothing("mo_fan", "top", "cloth_shop_100_top")
	GameState.wear_clothing("mo_fan", "pants", "cloth_shop_1000_pants")
	GameState.wear_clothing("mo_fan", "hat", "cloth_shop_100_hat")
	var expect := {
		"HatSprite": "res://assets/images/clothes/cloth_shop_100_hat.png",
		"TopSprite": "res://assets/images/clothes/cloth_shop_100_top.png",
		"PantsSprite": "res://assets/images/clothes/cloth_shop_1000_pants.png",
	}
	var scene: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var wrong := ""
	for layer_name in expect:
		var sp: Sprite2D = scene.get("player").get_node(layer_name)
		if sp.texture == null or sp.texture.resource_path != expect[layer_name]:
			wrong += layer_name + " "
	if wrong == "":
		print("  PASS  玩家三层衣装随 worn_clothes 换图")
	else:
		printerr("  FAIL  换装层贴图不符：%s" % wrong)
		ok = false
	# 地图重建（读档/跨图等价路径）→ 外观保持
	scene.free()
	await get_tree().process_frame
	var scene2: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(scene2)
	await get_tree().process_frame
	var hat_sp: Sprite2D = scene2.get("player").get_node("HatSprite")
	if hat_sp.texture != null and hat_sp.texture.resource_path == expect["HatSprite"]:
		print("  PASS  地图重建后外观保持（读档/跨图等价）")
	else:
		printerr("  FAIL  重建后外观丢失")
		ok = false
	# 衣柜焦点即试穿：列表首个按钮已被 _focus_menu 聚焦，先挪到「返回」再聚焦
	# 骑士头盔，保证 focus_entered 必然触发一次切换
	scene2._open_wardrobe()
	await get_tree().process_frame
	var back_btn: BaseButton = null
	var knight_btn: BaseButton = null
	for btn in scene2._menu.find_children("*", "Button", true, false):  # 返回键已固定在滚动区外，查全菜单
		if btn.text == "返回杂货铺":  # 普通按钮有真 text；衣装按钮的文字在内嵌 Label 里
			back_btn = btn
			continue
		for conn in btn.pressed.get_connections():
			var cb: Callable = conn["callable"]
			if cb.get_bound_arguments().has("cloth_knight_hat"):  # 绑定参数含目标衣装 id
				knight_btn = btn
	if back_btn == null or knight_btn == null:
		printerr("  FAIL  衣柜按钮缺失（back=%s knight=%s）" % [back_btn != null, knight_btn != null])
		return false
	back_btn.grab_focus()
	await get_tree().process_frame
	var hat_layer_idx: int = 1 + int(MapBaseScript.MEMBER_WARDROBE_SLOTS["mo_fan"].find("hat"))  # [0]=base，其后按槽位序
	var before: Texture2D = scene2._preview_layers[hat_layer_idx].texture
	knight_btn.grab_focus()
	await get_tree().process_frame
	var after: Texture2D = scene2._preview_layers[hat_layer_idx].texture
	if before != null and after != null \
			and after.resource_path.ends_with("cloth_knight_hat.png"):
		print("  PASS  衣柜焦点即试穿（预览帽层 → 骑士头盔）")
	else:
		printerr("  FAIL  预览未随焦点切换（before=%s after=%s）" % [
			before.resource_path if before != null else "null",
			after.resource_path if after != null else "null"])
		ok = false
	# 跟随者分层换装：穆宁雪入队登场，换连衣裙经信号即时更新跟随者层
	GameState.add_clothing("mu_ningxue", "cloth_xue_hosiery_black")
	GameState.add_clothing("mu_ningxue", "cloth_xue_gothic")
	GameState.join_member(PartySetup.mu_ningxue())
	await get_tree().process_frame
	var xue_fl: Node2D = null
	for f in scene2.followers:
		if f.member_id == "mu_ningxue":
			xue_fl = f
	if xue_fl == null:
		printerr("  FAIL  穆宁雪跟随者未登场")
		ok = false
	else:
		var dress_sp: Sprite2D = xue_fl.layer_sprites.get("dress")
		var dress_before: Texture2D = dress_sp.texture  # 初始银白常服
		GameState.wear_clothing("mu_ningxue", "dress", "cloth_xue_gothic")
		GameState.wear_clothing("mu_ningxue", "hosiery", "cloth_xue_hosiery_black")
		var dress_after: Texture2D = dress_sp.texture
		if dress_before != null and dress_after != null \
				and dress_after.resource_path != dress_before.resource_path \
				and dress_after.resource_path.ends_with("cloth_xue_gothic.png"):
			print("  PASS  跟随者分层换装（穆宁雪银白常服 → 哥特裙）")
		else:
			printerr("  FAIL  跟随者换装层未更新")
			ok = false
	scene2._close_rest_menu()
	scene2.free()
	await get_tree().process_frame
	return ok


## 入场窗口内开菜单，入场收尾不得把人物解锁（曾致菜单中人物仍可行走、
## 方向键同时驱动菜单与角色——试玩反馈的移动穿透）。
func _test_menu_during_entry() -> bool:
	print("[入场窗口菜单锁]")
	var ok := true
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done", "prologue_tutorial_done"]:
		GameState.flags[f] = true
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	city._open_bag()  # 入场收尾（约 1.2s 后）触发前先开菜单
	await get_tree().create_timer(2.5).timeout
	var player: Node2D = city.get("player")
	var still_locked: bool = city._menu != null and player.input_enabled == false
	if still_locked:
		print("  PASS  入场收尾不解锁菜单中的人物")
	else:
		printerr("  FAIL  菜单打开期间人物被入场收尾解锁")
		ok = false
	city._close_rest_menu()
	await get_tree().process_frame
	if player.input_enabled:
		print("  PASS  关闭菜单后恢复正常行走")
	else:
		printerr("  FAIL  关闭菜单后人物仍被锁")
		ok = false
	city.free()
	await get_tree().process_frame
	return ok


## 突破按钮状态必须随精魄存量刷新：曾停留在旧「持有 N」，精魄用完
## 按钮仍可点，读起来像"还提示有精魄可用"（试玩反馈）。
func _test_breakthrough_button_refresh() -> bool:
	print("[突破按钮刷新]")
	var ok := true
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_done", "prologue_tutorial_done"]:
		GameState.flags[f] = true
	var m: CharacterState = GameState.party[0]
	m.gain_xp(m.main_element, 99)  # 直至瓶颈：三星圆满
	var need: String = GameState.essence_for_element(m.main_element)
	GameState.essences[need] = GameState.ESSENCE_COST  # 恰好一次的量
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	city._open_rest_menu()
	await get_tree().process_frame
	var btn: Button = null
	for b in city._menu.find_children("*", "Button", true, false):
		if b.has_meta("breakthrough_btn"):
			btn = b
			break
	if btn == null:
		printerr("  FAIL  找不到突破按钮")
		city.free()
		return false
	btn.pressed.emit()  # 用掉最后一组精魄
	await get_tree().process_frame
	var spent_ok: bool = GameState.essence_count(need) == 0
	var stale_gone: bool = btn.disabled and btn.text.contains("持有 0") == false
	if spent_ok and stale_gone:
		print("  PASS  突破后按钮即时失效（无精魄残留提示）")
	else:
		printerr("  FAIL  突破后按钮状态陈旧（disabled=%s, 文案=%s）" % [btn.disabled, btn.text])
		ok = false
	city.free()
	await get_tree().process_frame
	return ok


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
		# 新版物品行是"无 text 的按钮 + 子 Label"，按子 Label 文案找目标
		if btn is Button:
			for lbl in btn.find_children("*", "Label", true, false):
				if lbl is Label and lbl.text.contains("雷纹杖"):
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


## 系统菜单：Esc 呼出的暂停/退出入口。按钮齐备，关闭后恢复玩家操作。
func _test_system_menu() -> bool:
	print("[系统菜单]")
	GameState.new_game()
	# 预置序章旗标：出生点触发器直接 early-return，不弹对话
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_tutorial_done"]:
		GameState.flags[f] = true
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	city._open_system_menu()
	await get_tree().process_frame
	var texts: Array = []
	for btn in (city.get("_menu") as Control).find_children("*", "Button", true, false):
		texts.append((btn as Button).text)
	var has := func(key: String) -> bool:
		for t in texts:
			if String(t).contains(key):
				return true
		return false
	var buttons_ok: bool = has.call("继续旅程") and has.call("背包") \
			and has.call("回到主菜单") and has.call("退出游戏")
	if buttons_ok:
		print("  PASS  系统菜单按钮齐备（%d 项）" % texts.size())
	else:
		printerr("  FAIL  系统菜单缺按钮：%s" % [texts])
	# 从系统菜单转背包：系统菜单关闭、背包打开
	var bag_btn: Button = null
	for btn in (city.get("_menu") as Control).find_children("*", "Button", true, false):
		if (btn as Button).text.contains("背包"):
			bag_btn = btn
	bag_btn.pressed.emit()
	await get_tree().process_frame
	var bag_ok: bool = city.get("_menu") != null and city.get("_bag_box") != null \
			and city.get("player").input_enabled == false
	if bag_ok:
		print("  PASS  系统菜单转背包（玩家操作保持锁定）")
	else:
		printerr("  FAIL  转背包异常（menu=%s bag=%s）" % [city.get("_menu") != null, city.get("_bag_box") != null])
	city._close_rest_menu()
	await get_tree().process_frame
	var resume_ok: bool = city.get("_menu") == null and city.get("player").input_enabled
	if resume_ok:
		print("  PASS  关闭菜单后恢复玩家操作")
	else:
		printerr("  FAIL  关闭后操作未恢复")
	city.free()
	GameState.new_game()
	await get_tree().process_frame
	return buttons_ok and bag_ok and resume_ok


## 交互高亮与移动锁：进交互圈 NPC/篝火描金出「E」徽标；菜单/对话期间人物锁死。
func _test_interact_lock_and_highlight() -> bool:
	print("[交互高亮与移动锁]")
	var ok := true
	GameState.new_game()
	for f in ["prologue_intro_done", "prologue_awaken_done", "prologue_tutorial_done", "prologue_done"]:
		GameState.flags[f] = true
	var city: Node = (load("res://src/world/bo_city/bo_city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().create_timer(1.5).timeout
	var player: Node2D = city.get("player")
	var fire: Area2D = null
	for child in city.get_children():
		if child is Area2D and child.has_signal("camp_used"):
			fire = child
	if fire == null:
		printerr("  FAIL  找不到篝火")
		city.free()
		return false
	# 高亮：走近篝火亮描金（E 徽标已按试玩反馈移除），走远熄灭
	player.global_position = fire.global_position + Vector2(30, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var glow_on: bool = fire.get("_glow").get_shader_parameter("active") == 1.0 \
			and fire.get("_mark") == null  # E 字样不再存在
	if glow_on:
		print("  PASS  走近篝火：描金高亮（无 E 徽标）")
	else:
		printerr("  FAIL  篝火未高亮")
		ok = false
	player.global_position = fire.global_position + Vector2(200, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	if fire.get("_glow").get_shader_parameter("active") == 0.0:
		print("  PASS  走远后高亮熄灭")
	else:
		printerr("  FAIL  走远后仍高亮")
		ok = false
	# 菜单期间移动锁：开营地菜单后按住方向键，人物不得位移
	player.global_position = fire.global_position + Vector2(30, 0)
	await get_tree().process_frame
	city._open_rest_menu()
	await get_tree().process_frame
	var x0: float = player.global_position.x
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var menu_locked: bool = player.global_position.x == x0
	Input.action_release("move_left")
	if menu_locked:
		print("  PASS  营地菜单期间移动锁死")
	else:
		printerr("  FAIL  菜单期间人物位移了")
		ok = false
	city._close_rest_menu()
	await get_tree().process_frame
	# 对话期间移动锁：按 E 触发穆宁雪事件（挂起在第一页台词上）
	var npc: Area2D = null
	for node in (city.get("_npc_nodes") as Array):
		if node.hide_flag == "ch1_mufu_done":
			npc = node
	if npc == null:
		printerr("  FAIL  找不到穆宁雪 NPC")
		city.free()
		return false
	player.global_position = npc.global_position + Vector2(30, 0)
	npc.interact()
	await get_tree().process_frame
	var dialogue_up: bool = city.get("_event_running") and Dialogue.visible
	var x1: float = player.global_position.x
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dialogue_locked: bool = dialogue_up and player.global_position.x == x1
	Input.action_release("move_right")
	if dialogue_locked:
		print("  PASS  对话期间移动锁死（面板可见时禁走）")
	else:
		printerr("  FAIL  对话期间移动未锁死（event=%s dialogue=%s）" % [
			city.get("_event_running"), Dialogue.visible])
		ok = false
	city.free()
	GameState.new_game()
	await get_tree().process_frame
	return ok


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
