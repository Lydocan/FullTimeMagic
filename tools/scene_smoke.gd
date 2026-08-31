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
	print("=== 场景冒烟 %s ===" % ("通过" if ok else "失败"))
	get_tree().quit(0 if ok else 1)


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
