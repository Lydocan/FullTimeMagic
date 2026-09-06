## 初始队伍配置。
##
## 原型期硬编码；正式版迁移为 CharacterData .tres + 剧情加入事件。

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const CharacterState := preload("res://src/data/character_state.gd")
const GameData := preload("res://src/data/game_data.gd")
const GameTypes := preload("res://src/data/game_types.gd")

static func mo_fan() -> CharacterState:
	var c := CharacterState.new()
	c.build_from({
		"id": "mo_fan",
		"name": "莫凡",
		"elements": [GameTypes.Element.LIGHTNING, GameTypes.Element.FIRE],
		"main_element": GameTypes.Element.LIGHTNING,
		"can_switch_form": true,
		"max_hp": 90, "max_mp": 30, "magic": 10, "defense": 4, "speed": 8,
	})
	c.spells = [
		GameData.load_spell("lei_yin"),
		GameData.load_spell("luo_lei"),
		GameData.load_spell("huoyanquan"),
		GameData.load_spell("huoxing"),
	]
	return c


static func mu_ningxue() -> CharacterState:
	var c := CharacterState.new()
	c.build_from({
		"id": "mu_ningxue",
		"name": "穆宁雪",
		"elements": [GameTypes.Element.ICE],
		"main_element": GameTypes.Element.ICE,
		"max_hp": 80, "max_mp": 34, "magic": 9, "defense": 3, "speed": 9,
	})
	# 天才设定：开局压着初阶瓶颈，剧情节点突破中阶（见 docs/characters.md）。
	c.ranks[GameTypes.Element.ICE] = {"stage": 0, "star": 2, "dust": GameTypes.STARDUST_PER_STAR, "bottleneck": true}
	c.spells = [
		GameData.load_spell("bingzhui"),
		GameData.load_spell("binghuan"),
	]
	return c
