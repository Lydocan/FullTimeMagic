extends Control
## 标题界面：新的旅程 / 继续旅程 / 退出。全键盘可操作（方向键 + 回车）。


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14101f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "FullTimeMagic"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "全职法师 · 同人 RPG（垂直切片）"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "新的旅程"
	new_btn.pressed.connect(_on_new_game)
	box.add_child(new_btn)

	var continue_btn := Button.new()
	continue_btn.text = "继续旅程"
	continue_btn.disabled = not SaveSystem.has_save()
	continue_btn.pressed.connect(_on_continue)
	box.add_child(continue_btn)

	var quit_btn := Button.new()
	quit_btn.text = "退出"
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	var hint := Label.new()
	hint.text = "方向键选择 · 回车确认"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)

	if not continue_btn.disabled:
		continue_btn.grab_focus()
	else:
		new_btn.grab_focus()


func _on_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(SaveSystem.FIRST_SCENE)


func _on_continue() -> void:
	if not SaveSystem.load_game():
		# 存档损坏时回退为新游戏
		GameState.new_game()
		get_tree().change_scene_to_file(SaveSystem.FIRST_SCENE)
