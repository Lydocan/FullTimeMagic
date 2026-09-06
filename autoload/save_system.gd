extends Node
## 存档系统（autoload：SaveSystem）。
##
## 单存档位 JSON（user://savegame.json）。存/读数据与场景切换分离：
## make_save_data / apply_save_data 可独立测试，save_game / load_game 面向玩家。

const FIRST_SCENE := "res://src/world/bo_city/bo_city.tscn"
## 存档路径用 var 而非 const：冒烟测试重定向到隔离文件，不碰真实存档。
var save_path := "user://savegame.json"

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const CharacterState := preload("res://src/data/character_state.gd")


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 收集当前状态为可序列化字典（不落盘）。
func make_save_data() -> Dictionary:
	var data := {
		"version": 1,
		"scene": "",
		"gold": GameState.gold,
		"essences": GameState.essences,
		"items": GameState.items,
		"equip_bag": GameState.equip_bag,
		"owned_clothes": GameState.owned_clothes,
		"worn_clothes": GameState.worn_clothes,
		"flags": GameState.flags,
		"party": [],
		"return_position": [GameState.return_position.x, GameState.return_position.y],
		"has_return_position": GameState.has_return_position,
	}
	var cs := get_tree().current_scene
	if cs != null:
		data["scene"] = cs.scene_file_path
		var player: Node2D = cs.get("player")
		if player != null:
			data["return_position"] = [player.global_position.x, player.global_position.y]
			data["has_return_position"] = true
	for m in GameState.party:
		data["party"].append(m.to_dict())
	return data


## 应用存档数据到 GameState（不切换场景）。返回是否成功。
func apply_save_data(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	GameState.gold = int(d.get("gold", 0))
	GameState.essences = {}
	for key in d.get("essences", {}):
		GameState.essences[str(key)] = int(d["essences"][key])
	GameState.items = {}
	for key in d.get("items", {}):
		GameState.items[str(key)] = int(d["items"][key])
	GameState.equip_bag = {}
	for key in d.get("equip_bag", {}):
		GameState.equip_bag[str(key)] = int(d["equip_bag"][key])
	GameState.owned_clothes = []
	GameState.worn_clothes = {}
	if d.has("owned_clothes"):
		for clothing_id in d.get("owned_clothes", []):
			GameState.owned_clothes.append(str(clothing_id))
		for slot in d.get("worn_clothes", {}):
			GameState.worn_clothes[str(slot)] = str(d["worn_clothes"][slot])
	else:
		GameState._init_wardrobe()  # 旧存档无衣柜字段：补发初始三套
	GameState.flags = {}
	for key in d.get("flags", {}):
		GameState.flags[str(key)] = bool(d["flags"][key])
	GameState.party.clear()
	for pd in d.get("party", []):
		GameState.party.append(CharacterState.from_dict(pd))
	var pos: Array = d.get("return_position", [0, 0])
	GameState.return_position = Vector2(float(pos[0]), float(pos[1])) if pos.size() == 2 else Vector2.ZERO
	GameState.has_return_position = bool(d.get("has_return_position", false))
	GameState.pending_enemies = []
	GameState.pending_flag = ""
	GameState.pending_party_ids = []
	GameState.battle_return_scene = ""
	GameState.next_spawn = Vector2i(-1, -1)
	GameEvents.party_status_changed.emit()
	return true


func save_game() -> Error:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：%s" % save_path)
		return FAILED
	f.store_string(JSON.stringify(make_save_data(), "\t"))
	f.close()
	return OK


## 读出存档数据（不应用、不切场景）。不存在或损坏返回空字典。
func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("存档解析失败")
		return {}
	return parsed


## 读档并切换到存档场景。返回是否成功。
func load_game() -> bool:
	var d := _read_save()
	if d.is_empty() or not apply_save_data(d):
		return false
	var scene: String = d.get("scene", "")
	if scene != "" and ResourceLoader.exists(scene):
		get_tree().change_scene_to_file(scene)
		return true
	push_error("存档场景无效：%s" % scene)
	return false


## 战败恢复（歧路旅人式）：读回最近存档——状态与剧情进度回到存档时刻；
## 无存档或存档不可用则重开新旅程。只恢复状态并返回去向场景路径，
## 场景切换由调用方执行。战败永不回原地，避免同一场战斗无限重打。
func defeat_return_scene() -> String:
	var d := _read_save()
	if not d.is_empty() and apply_save_data(d):
		var scene: String = d.get("scene", "")
		if scene != "" and ResourceLoader.exists(scene):
			return scene
	GameState.new_game()
	return FIRST_SCENE
