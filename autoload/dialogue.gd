extends CanvasLayer
## 对话系统（autoload：Dialogue）。
##
## 用法（剧情事件内）：
##   await Dialogue.say("莫凡", "台词……", Color.WHITE)
##   var i: int = await Dialogue.choose("如何回应？", ["选项甲", "选项乙"])
## 键盘：回车/E 推进或快进打字机；选项用方向键导航 + 回车。
## 台词序列结束（推进后无新台词/选项接续）时面板自动收起，剧情侧无需手动隐藏。

signal _advanced
signal _chose(index: int)

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _options_box: HBoxContainer
var _typing := false
var _seq := 0  # 台词序号：新台词/选项接续时递增，用于判定序列结束并自动收起


func _ready() -> void:
	layer = 100
	visible = false
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 120
	_panel.offset_right = -120
	_panel.offset_top = -210
	_panel.offset_bottom = -48
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 15)
	box.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 92)
	_text.add_theme_font_size_override("font_size", 17)
	box.add_child(_text)

	_options_box = HBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 12)
	_options_box.visible = false
	box.add_child(_options_box)


## 显示一页对话并等待玩家推进。
func say(speaker_name: String, text: String, color := Color.WHITE) -> void:
	_seq += 1
	visible = true
	_options_box.visible = false
	_speaker.text = speaker_name
	_speaker.add_theme_color_override("font_color", color.lightened(0.2))
	_text.text = text
	_text.visible_characters = 0
	_typing = true
	while _typing and _text.visible_characters < text.length():
		await get_tree().process_frame
		if _typing:
			_text.visible_characters = mini(_text.visible_characters + 2, text.length())
	_typing = false
	_text.visible_characters = text.length()
	await _advanced
	# 序列自动收起：本页推进后，若下一帧没有新台词接续（剧情说完），
	# 就隐藏面板——否则对话框会跨场景残留，一路挂到战斗画面上。
	# 连续台词的隐藏与再显示发生在同一帧内，肉眼不可见。
	var seq := _seq
	await get_tree().process_frame
	if _seq == seq:
		visible = false


## 显示选项，返回被选中的下标。
func choose(prompt: String, options: Array) -> int:
	_seq += 1  # 与 say 相同：使前一页挂起的自动收起检查失效
	visible = true
	_speaker.text = ""
	_text.text = prompt
	_text.visible_characters = -1
	for child in _options_box.get_children():
		child.queue_free()
	var index := 0
	for opt in options:
		var idx := index
		var btn := Button.new()
		btn.text = str(opt)
		btn.pressed.connect(func() -> void: _chose.emit(idx))
		_options_box.add_child(btn)
		index += 1
	_options_box.visible = true
	(_options_box.get_child(0) as Button).grab_focus()
	var chosen: int = await _chose
	_options_box.visible = false
	visible = false
	return chosen


func _input(event: InputEvent) -> void:
	if not visible or _options_box.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
			_text.visible_characters = -1
		else:
			_advanced.emit()
