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
	print("=== 场景冒烟 %s ===" % ("通过" if ok else "失败"))
	get_tree().quit(0 if ok else 1)
