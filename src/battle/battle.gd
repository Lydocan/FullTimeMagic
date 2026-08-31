extends Node2D
## 回合制战斗：星辰增幅（星辉）+ 魔盾破魔，歧路旅人式指令战斗。
##
## 设计见 docs/gameplay.md。逻辑函数与 UI 分离：
## tools/smoke_test.tscn 通过 run_simulation() 直接驱动战斗逻辑做无头验证。

enum Phase { INTRO, COMMAND, SPELL_SELECT, TARGET, RESOLVING, ENEMY, VICTORY, DEFEAT }

const WORLD_SCENE := "res://src/world/test_wilds/test_wilds.tscn"
const BG_TEXTURE := "res://assets/images/battle_bg_proto.png"

## 每回合行动者积攒的星辉上限（出招时消耗，1 点 = 法术 +1 段）。
const MAX_STARS := 3

var _party: Array[CharacterState] = []
var _party_actors: Array[BattleActor] = []
var _enemies: Array[Dictionary] = []  # {data, hp, shield, broken, burn, paralyzed, discovered, actor}
var _order: Array[Dictionary] = []    # {"side": "party"/"enemy", "index": int}
var _turn := 0
var _phase := Phase.INTRO
var _member: CharacterState
var _spell: SpellData
var _boost := 0
var _target_entry := -1

# UI 引用
var _cmd_root: Control
var _spell_box: VBoxContainer
var _cmd_buttons: Array[Button] = []
var _spell_buttons: Array[Button] = []
var _last_spell_index := 0
var _info_label: Label
var _rank_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _stars_label: Label
var _boost_value: Label
var _log_label: Label
var _order_label: Label
var _target_hint: Label


func _ready() -> void:
	_party = GameState.party
	for m in _party:
		m.reset_battle_state()
	_build_background()
	_spawn_enemies()
	_spawn_party_actors()
	_build_ui()
	_log("遭遇妖魔：%s" % "、".join(_enemy_names()))
	_start_round()


## —— 场景构建 ——

func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.size = Vector2(1280, 720)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)


func _spawn_enemies() -> void:
	var ids: Array = GameState.pending_enemies
	if ids.is_empty():
		ids = ["rat_swarm"]
	for i in ids.size():
		var data := GameData.load_monster(ids[i])
		var actor := BattleActor.new()
		actor.setup(load(data.texture_path), data.monster_name, data.sprite_scale)
		actor.position = Vector2(640 + (i - (ids.size() - 1) * 0.5) * 170.0, 170)
		actor.set_weaknesses(data.weaknesses, [])
		add_child(actor)
		_enemies.append({
			"data": data, "hp": data.max_hp, "shield": data.shield,
			"broken": false, "burn": 0, "paralyzed": false, "discovered": [],
			"actor": actor,
		})


func _spawn_party_actors() -> void:
	var textures := ["res://assets/images/char_mofan.png", "res://assets/images/char_muningxue.png"]
	for i in _party.size():
		var actor := BattleActor.new()
		var tex_path: String = textures[i] if i < textures.size() else textures[0]
		actor.setup(load(tex_path), _party[i].char_name)
		actor.position = Vector2(540 + i * 200.0, 450)
		actor.set_shield(0, 0)
		add_child(actor)
		_party_actors.append(actor)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_order_label = Label.new()
	_order_label.position = Vector2(16, 10)
	_order_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_order_label)

	var keys_hint := Label.new()
	keys_hint.text = "方向键 选择 · 回车 确认 · Esc 返回 · W/S 调整星辉（鼠标可辅助）"
	keys_hint.position = Vector2(16, 32)
	keys_hint.add_theme_font_size_override("font_size", 12)
	keys_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	layer.add_child(keys_hint)

	_target_hint = Label.new()
	_target_hint.position = Vector2(540, 40)
	_target_hint.add_theme_font_size_override("font_size", 15)
	_target_hint.add_theme_color_override("font_color", Color("ffd166"))
	_target_hint.text = "选择目标：←→ 切换 · 回车 确认 · Esc 返回（鼠标点击亦可）"
	_target_hint.visible = false
	layer.add_child(_target_hint)

	_log_label = Label.new()
	_log_label.position = Vector2(16, 522)
	_log_label.size = Vector2(1250, 26)
	_log_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_log_label)

	_cmd_root = Control.new()
	_cmd_root.position = Vector2(0, 552)
	layer.add_child(_cmd_root)

	# 左：当前行动成员状态
	var info := PanelContainer.new()
	info.position = Vector2(16, 0)
	info.custom_minimum_size = Vector2(300, 156)
	_cmd_root.add_child(info)
	var ibox := VBoxContainer.new()
	info.add_child(ibox)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	ibox.add_child(_info_label)
	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 13)
	ibox.add_child(_rank_label)
	_hp_bar = _bar()
	ibox.add_child(_hp_bar)
	_mp_bar = _bar()
	_mp_bar.modulate = Color(0.7, 0.85, 1.0)
	ibox.add_child(_mp_bar)
	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 13)
	_stars_label.add_theme_color_override("font_color", Color("c792ff"))
	ibox.add_child(_stars_label)

	# 中：指令
	var cmd_panel := PanelContainer.new()
	cmd_panel.position = Vector2(332, 0)
	cmd_panel.custom_minimum_size = Vector2(210, 156)
	_cmd_root.add_child(cmd_panel)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 4)
	cmd_panel.add_child(cbox)
	_add_cmd_button(cbox, "法术", _open_spell_list)
	_add_cmd_button(cbox, "切换形态", _on_switch_form)
	_add_cmd_button(cbox, "防御（+1 星辉）", _on_defend)
	_add_cmd_button(cbox, "逃跑", _on_flee)

	# 右：法术列表 + 星辉增幅
	var spell_panel := PanelContainer.new()
	spell_panel.position = Vector2(558, 0)
	spell_panel.custom_minimum_size = Vector2(430, 156)
	_cmd_root.add_child(spell_panel)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 2)
	spell_panel.add_child(sbox)
	var boost_row := HBoxContainer.new()
	sbox.add_child(boost_row)
	var boost_down := Button.new()
	boost_down.text = "▼"
	boost_down.pressed.connect(func() -> void: _adjust_boost(-1))
	boost_row.add_child(boost_down)
	_boost_value = Label.new()
	_boost_value.add_theme_font_size_override("font_size", 14)
	_boost_value.add_theme_color_override("font_color", Color("c792ff"))
	boost_row.add_child(_boost_value)
	var boost_up := Button.new()
	boost_up.text = "▲ 消耗星辉增幅"
	boost_up.pressed.connect(func() -> void: _adjust_boost(1))
	boost_row.add_child(boost_up)
	_spell_box = VBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 2)
	sbox.add_child(_spell_box)

	_hide_command()


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	return bar


func _add_cmd_button(parent: Node, text: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(action)
	parent.add_child(btn)
	_cmd_buttons.append(btn)


## —— 回合流转 ——

func _start_round() -> void:
	_order.clear()
	for i in _party.size():
		if _party[i].hp > 0:
			_order.append({"side": "party", "index": i})
	for i in _enemies.size():
		if _enemies[i]["hp"] > 0:
			_order.append({"side": "enemy", "index": i})
	_order.sort_custom(func(a, b): return _speed_of(a) > _speed_of(b))
	_turn = 0
	for m in _party:
		if m.hp > 0:
			m.battle_stars = mini(m.battle_stars + 1, MAX_STARS)
	_update_order_label()
	_next_turn()


func _speed_of(entry: Dictionary) -> int:
	if entry["side"] == "party":
		return _party[entry["index"]].speed
	return _enemies[entry["index"]]["data"].speed


func _update_order_label() -> void:
	var names := []
	for entry in _order:
		if entry["side"] == "party":
			names.append(_party[entry["index"]].char_name)
		else:
			names.append(_enemies[entry["index"]]["data"].monster_name)
	_order_label.text = "行动顺序：" + " ▸ ".join(names)


func _next_turn() -> void:
	if _turn >= _order.size():
		_end_of_round()
		return
	var cur: Dictionary = _order[_turn]
	if cur["side"] == "party":
		var m := _party[cur["index"]]
		if m.hp <= 0:
			_advance()
		elif m.paralyzed:
			m.paralyzed = false
			_log("%s 麻痹中，无法行动！" % m.char_name)
			_advance()
		else:
			_begin_command(m)
	else:
		var e: Dictionary = _enemies[cur["index"]]
		if e["hp"] <= 0:
			_advance()
		elif e["paralyzed"]:
			e["paralyzed"] = false
			_log("%s 麻痹中，无法行动！" % e["data"].monster_name)
			_advance()
		elif e["broken"]:
			e["broken"] = false
			e["shield"] = e["data"].shield
			e["actor"].set_shield(e["shield"], e["data"].shield)
			_log("%s 重整魔盾。" % e["data"].monster_name)
			_advance()
		else:
			_enemy_act(e)


func _advance() -> void:
	_turn += 1
	if _check_battle_end():
		return
	_next_turn()


func _end_of_round() -> void:
	# 燃烧结算
	for m in _party:
		if m.hp > 0 and m.burn_turns > 0:
			m.burn_turns -= 1
			m.change_hp(-8)
			_log("%s 被燃烧灼伤（8 伤害）。" % m.char_name)
	for e in _enemies:
		if e["hp"] > 0 and e["burn"] > 0:
			e["burn"] -= 1
			e["hp"] = maxi(e["hp"] - 8, 0)
			_log("%s 被燃烧灼伤（8 伤害）。" % e["data"].monster_name)
			if e["hp"] <= 0:
				e["actor"].fade_out()
	_sync_all()
	if _check_battle_end():
		return
	_start_round()


## —— 玩家指令 ——

func _begin_command(m: CharacterState) -> void:
	_member = m
	_phase = Phase.COMMAND
	_boost = 0
	_show_command(m)


func _show_command(m: CharacterState) -> void:
	_cmd_root.visible = true
	var el := m.form_element()
	_info_label.text = "%s%s" % [m.char_name, "【%s形态】" % GameTypes.element_name(el) if m.can_switch_form else ""]
	_rank_label.text = "%s系位阶：%s   速度 %d" % [GameTypes.element_name(el), m.rank_label(el), m.speed]
	_update_member_panel(m)
	_fill_spell_list(m)
	_set_cmd_buttons_enabled(true)
	if _cmd_buttons.size() > 0:
		_cmd_buttons[0].grab_focus()


func _update_member_panel(m: CharacterState) -> void:
	_hp_bar.max_value = m.eff_max_hp()
	_hp_bar.value = m.hp
	_mp_bar.max_value = m.eff_max_mp()
	_mp_bar.value = m.mp
	_hp_bar.tooltip_text = "HP %d/%d" % [m.hp, m.eff_max_hp()]
	_mp_bar.tooltip_text = "MP %d/%d" % [m.mp, m.eff_max_mp()]
	_stars_label.text = "星辉 " + "◆".repeat(m.battle_stars) + "◇".repeat(MAX_STARS - m.battle_stars)
	_boost_value.text = "增幅 ×%d（W/S 或 ▲▼）" % _boost


func _fill_spell_list(m: CharacterState) -> void:
	for child in _spell_box.get_children():
		child.queue_free()
	_spell_buttons.clear()
	_last_spell_index = 0
	var el := m.form_element()
	var index := 0
	for s in m.usable_spells(el):
		var spell := s
		var spell_index := index
		var btn := Button.new()
		btn.text = "%s   威力%d ×%d段   MP%d%s" % [
			spell.spell_name, spell.power, spell.hits, spell.mp_cost,
			"  全体" if spell.target_all else "",
		]
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = m.mp < spell.mp_cost
		btn.pressed.connect(func() -> void:
			_last_spell_index = spell_index
			_on_spell_chosen(spell)
		)
		_spell_box.add_child(btn)
		_spell_buttons.append(btn)
		index += 1
	var back := Button.new()
	back.text = "返回"
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(_back_to_command)
	_spell_box.add_child(back)


func _set_cmd_buttons_enabled(on: bool) -> void:
	var panel := _cmd_root.get_child(1) as PanelContainer
	for btn in (panel.get_child(0) as VBoxContainer).get_children():
		btn.disabled = not on


func _adjust_boost(delta: int) -> void:
	if _phase != Phase.COMMAND and _phase != Phase.SPELL_SELECT:
		return
	_boost = clampi(_boost + delta, 0, mini(_member.battle_stars, MAX_STARS))
	_boost_value.text = "增幅 ×%d（W/S 或 ▲▼）" % _boost


func _open_spell_list() -> void:
	_phase = Phase.SPELL_SELECT
	_set_cmd_buttons_enabled(false)
	_focus_spell(_last_spell_index)


## 键盘焦点落在第一个可用（精神力足够）的法术上；找不到就退回指令菜单。
func _focus_spell(index: int) -> void:
	for i in range(clampi(index, 0, _spell_buttons.size() - 1), _spell_buttons.size()):
		if not _spell_buttons[i].disabled:
			_spell_buttons[i].grab_focus()
			return
	for btn in _spell_buttons:
		if not btn.disabled:
			btn.grab_focus()
			return


func _back_to_command() -> void:
	_phase = Phase.COMMAND
	_show_command(_member)


func _on_switch_form() -> void:
	if not _member.can_switch_form:
		return
	_member.form = (_member.form + 1) % _member.elements.size()
	var el := _member.form_element()
	_log("%s 切换为【%s形态】。" % [_member.char_name, GameTypes.element_name(el)])
	_hide_command()
	_advance()


func _on_defend() -> void:
	_member.defending = true
	_member.battle_stars = mini(_member.battle_stars + 1, MAX_STARS)
	_log("%s 摆出防御姿态。" % _member.char_name)
	_hide_command()
	_advance()


func _on_flee() -> void:
	_hide_command()
	if randf() < 0.6:
		_log("逃跑成功！")
		_finish(false, true)
	else:
		_log("逃跑失败！")
		_advance()


func _on_spell_chosen(spell: SpellData) -> void:
	_spell = spell
	if spell.target_all:
		_resolve_player_spell()
	else:
		_phase = Phase.TARGET
		_target_hint.visible = true
		_set_cmd_buttons_enabled(false)
		var alive := _alive_enemies()
		if not alive.is_empty():
			_target_entry = _enemies.find(alive[0])
		_refresh_target_highlight()


func _refresh_target_highlight() -> void:
	for i in _enemies.size():
		var e: Dictionary = _enemies[i]
		var alive: bool = e["hp"] > 0
		e["actor"].set_highlight(alive and i == _target_entry and _phase == Phase.TARGET)


func _hide_command() -> void:
	_cmd_root.visible = false
	_target_hint.visible = false
	_refresh_target_highlight()


## —— 输入（目标选择 / 点击目标） ——

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.TARGET:
		var alive := _alive_enemies()
		if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
			if alive.size() > 1:
				var idx := alive.find(_enemies[_target_entry])
				idx = (idx + 1) % alive.size() if event.is_action_pressed("ui_right") else (idx - 1 + alive.size()) % alive.size()
				_target_entry = _enemies.find(alive[idx])
				_refresh_target_highlight()
		elif event.is_action_pressed("ui_accept"):
			_target_hint.visible = false
			_resolve_player_spell()
		elif event.is_action_pressed("ui_cancel"):
			_phase = Phase.SPELL_SELECT
			_target_hint.visible = false
			_refresh_target_highlight()
			_focus_spell(_last_spell_index)
		return
	if _phase == Phase.COMMAND or _phase == Phase.SPELL_SELECT:
		# 纯键盘：W/S 调整星辉增幅（方向键留给焦点导航），Esc 返回指令菜单
		var used := true
		if event.is_action_pressed("move_up"):
			_adjust_boost(1)
		elif event.is_action_pressed("move_down"):
			_adjust_boost(-1)
		elif _phase == Phase.SPELL_SELECT and event.is_action_pressed("ui_cancel"):
			_back_to_command()
		else:
			used = false
		if used:
			get_viewport().set_input_as_handled()
			return
	if _phase == Phase.COMMAND and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for e in _enemies:
				if e["hp"] > 0 and e["actor"].position.distance_to(get_global_mouse_position()) < 70.0:
					var known := []
					for el in e["discovered"]:
						known.append(GameTypes.element_name(el))
					_log("%s：已探明弱点 %s" % [
						e["data"].monster_name,
						"、".join(known) if known.size() > 0 else "未知（命中弱点后揭示）",
					])
					break


## —— 结算逻辑（UI 无关，可被冒烟测试直接驱动） ——

func _resolve_player_spell() -> void:
	_phase = Phase.RESOLVING
	_hide_command()
	var m := _member
	var s := _spell
	var boost := _boost
	m.change_mp(-s.mp_cost)
	if boost > 0:
		m.battle_stars -= boost
	_boost = 0
	var hits := s.hits + boost
	_log("%s 施展「%s」%s（%d 段）" % [
		m.char_name, s.spell_name, "◆星辉增幅 " if boost > 0 else "", hits,
	])
	var targets: Array = _alive_enemies() if s.target_all else [_enemies[_target_entry]]
	for h in hits:
		for e in targets:
			if e["hp"] > 0:
				_hit_enemy(m, e, s)
		_sync_all()
		await _pause(0.22)
	# 附加状态（每次施法判定一次）
	for e in targets:
		if e["hp"] > 0 and s.status_effect != "" and randf() < s.status_chance:
			_apply_enemy_status(e, s.status_effect)
	_sync_all()
	_advance()


func _hit_enemy(user: CharacterState, e: Dictionary, s: SpellData) -> void:
	var data: MonsterData = e["data"]
	var is_weak: bool = s.element in data.weaknesses
	var raw := (s.power + user.eff_magic()) * randf_range(0.9, 1.1) - data.defense
	var dmg := maxi(1, roundi(raw))
	if e["broken"]:
		dmg = roundi(dmg * 1.5)
	if is_weak:
		if not (s.element in e["discovered"]):
			e["discovered"].append(s.element)
			e["actor"].set_weaknesses(data.weaknesses, e["discovered"])
		if e["shield"] > 0:
			e["shield"] = maxi(e["shield"] - s.break_power, 0)
			_log("命中弱点！%s 的魔盾被削弱。" % data.monster_name)
			if e["shield"] <= 0 and not e["broken"]:
				e["broken"] = true
				_log("◆ 破魔！%s 眩晕，承伤加深！" % data.monster_name)
	e["hp"] = maxi(e["hp"] - dmg, 0)
	_log("%s 对 %s 造成 %d 伤害%s。" % [user.char_name, data.monster_name, dmg, "（破魔）" if e["broken"] else ""])
	if e["hp"] <= 0:
		e["actor"].fade_out()
		_log("%s 被击败！" % data.monster_name)
	else:
		e["actor"].flash()


func _apply_enemy_status(e: Dictionary, status: String) -> void:
	match status:
		"burn":
			e["burn"] = 2
			_log("%s 被点燃！" % e["data"].monster_name)
		"paralyze":
			e["paralyzed"] = true
			_log("%s 被麻痹！" % e["data"].monster_name)


func _enemy_act(e: Dictionary) -> void:
	_phase = Phase.ENEMY
	await _pause(0.3)
	var d: MonsterData = e["data"]
	var use_special: bool = d.special_name != "" and randf() < d.special_chance
	var power: int = d.special_power if use_special else d.attack_power
	var skill: String = d.special_name if use_special else "撞击"
	_log("%s 使用「%s」！" % [d.monster_name, skill])
	var targets: Array = _alive_members()
	if targets.is_empty():
		return
	var victims: Array = targets if (use_special and d.special_target_all) else [targets.pick_random()]
	for m in victims:
		var raw: float = (power + d.attack * 0.3) * randf_range(0.9, 1.1) - m.defense * 1.2
		var dmg := maxi(1, roundi(raw))
		if m.defending:
			dmg = maxi(1, roundi(dmg * 0.5))
		m.change_hp(-dmg)
		_log("%s 受到 %d 伤害。" % [m.char_name, dmg])
		if use_special and d.special_status != "" and randf() < 0.35:
			match d.special_status:
				"burn":
					m.burn_turns = 2
					_log("%s 被点燃！" % m.char_name)
				"paralyze":
					m.paralyzed = true
					_log("%s 被麻痹！" % m.char_name)
		if m.hp <= 0:
			_log("%s 倒下了……" % m.char_name)
	_sync_all()
	await _pause(0.2)
	_advance()


## —— 胜负与结算 ——

func _check_battle_end() -> bool:
	if _alive_enemies().is_empty():
		_win()
		return true
	if _alive_members().is_empty():
		_lose()
		return true
	return false


func _win() -> void:
	_phase = Phase.VICTORY
	_log("战斗胜利！")
	var xp_each := 0
	var gold := 0
	var essences: Array = []
	for e in _enemies:
		xp_each += e["data"].xp_value
		gold += e["data"].gold_value
		if e["data"].essence_id != "" and randf() < e["data"].essence_chance:
			essences.append(e["data"].essence_id)
	var summary := GameState.grant_battle_rewards(xp_each, gold, essences)
	if GameState.pending_flag != "":
		GameState.flags[GameState.pending_flag] = true
		GameState.pending_flag = ""
	_show_result(true, xp_each, gold, essences, summary["events"])


func _lose() -> void:
	_phase = Phase.DEFEAT
	_log("队伍溃败……")
	_show_result(false, 0, 0, [], [])


func _finish(victory: bool, fled: bool) -> void:
	GameEvents.battle_finished.emit(victory, fled)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _show_result(victory: bool, xp_each: int, gold: int, essences: Array, events: Array) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "战斗胜利！" if victory else "队伍溃败……"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	if victory:
		box.add_child(_result_label("每位成员修为 +%d    金币 +%d" % [xp_each, gold]))
		for eid in essences:
			box.add_child(_result_label("获得精魄：%s" % eid))
		for entry in events:
			var ev: Dictionary = entry["ev"]
			var m_name: String = entry["member"]
			match ev["type"]:
				"star":
					var member := _find_member(m_name)
					var el: int = ev["element"]
					box.add_child(_result_label("◆ %s %s系 星子连线 → %s" % [
						m_name, GameTypes.element_name(el),
						GameTypes.rank_text(el, ev["stage"], ev["star"]),
					]))
				"bottleneck":
					box.add_child(_result_label("★ %s 达到三星圆满，进入瓶颈（去营地突破）" % m_name))
	else:
		box.add_child(_result_label("众人被路过的巡逻猎人救回营地。（下次小心）"))

	var btn := Button.new()
	btn.text = "继续（回车）"
	btn.pressed.connect(func() -> void:
		if not victory:
			GameState.rest_at_camp()
		_finish(victory, false)
	)
	box.add_child(btn)
	btn.grab_focus()


func _result_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l


func _find_member(member_name: String) -> CharacterState:
	for m in _party:
		if m.char_name == member_name:
			return m
	return null


## —— 工具 ——

func _alive_enemies() -> Array:
	var out := []
	for e in _enemies:
		if e["hp"] > 0:
			out.append(e)
	return out


func _alive_members() -> Array[CharacterState]:
	var out: Array[CharacterState] = []
	for m in _party:
		if m.hp > 0:
			out.append(m)
	return out


func _enemy_names() -> Array:
	var out := []
	for e in _enemies:
		out.append(e["data"].monster_name)
	return out


func _sync_all() -> void:
	for i in _party.size():
		var actor := _party_actors[i]
		var m := _party[i]
		actor.set_hp(float(m.hp) / m.eff_max_hp())
		actor.visible = m.hp > 0
	for e in _enemies:
		var a: BattleActor = e["actor"]
		a.set_hp(float(e["hp"]) / e["data"].max_hp)
		a.set_shield(e["shield"], e["data"].shield)
	if _phase == Phase.COMMAND or _phase == Phase.SPELL_SELECT:
		_update_member_panel(_member)


func _log(text: String) -> void:
	if _log_label != null:
		_log_label.text = text
	print("[battle] ", text)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## —— 冒烟测试入口：跳过 UI 等待，直接驱动战斗逻辑直到结束 ——

func run_simulation() -> Dictionary:
	var guard := 0
	while _phase != Phase.VICTORY and _phase != Phase.DEFEAT and guard < 800:
		guard += 1
		if _turn >= _order.size():
			_end_of_round()
			continue
		var cur: Dictionary = _order[_turn]
		if cur["side"] == "party":
			var m := _party[cur["index"]]
			if m.hp <= 0:
				_advance()
				continue
			if m.paralyzed:
				m.paralyzed = false
				_advance()
				continue
			_member = m
			var affordable := m.usable_spells(m.form_element()).filter(
				func(s: SpellData) -> bool: return s.mp_cost <= m.mp
			)
			if affordable.is_empty():
				m.defending = true
				_advance()
				continue
			_spell = affordable.pick_random()
			_boost = mini(1, m.battle_stars)
			var alive := _alive_enemies()
			if alive.is_empty():
				continue
			_target_entry = _enemies.find(alive[0])
			await _resolve_player_spell()
		else:
			var e: Dictionary = _enemies[cur["index"]]
			if e["hp"] <= 0:
				_advance()
				continue
			if e["paralyzed"]:
				e["paralyzed"] = false
				_advance()
				continue
			if e["broken"]:
				e["broken"] = false
				e["shield"] = e["data"].shield
				_advance()
				continue
			await _enemy_act(e)
	return {"victory": _phase == Phase.VICTORY, "rounds": guard}
