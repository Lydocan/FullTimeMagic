extends SceneTree
## 生成法术与妖魔的 .tres 数据文件（一次性脚手架，之后可在编辑器中直接调整）。
##
## 运行：godot --headless --path . --script res://tools/generate_data.gd

const SPELL_DIR := "res://resources/spells/"
const MONSTER_DIR := "res://resources/monsters/"


func _initialize() -> void:
	_gen_spells()
	_gen_monsters()
	quit(0)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("保存 %s -> %s" % [path, "成功" if err == OK else "失败(%d)" % err])


func _gen_spells() -> void:
	_spell("lei_yin", "雷印", GameTypes.Element.LIGHTNING, 0, {
		"power": 13, "mp_cost": 4, "break_power": 1,
		"status_effect": "paralyze", "status_chance": 0.2,
		"description": "雷系初阶法术，单体雷击，概率麻痹。（原著法术名，数值为原型设计）",
	})
	_spell("luo_lei", "落雷", GameTypes.Element.LIGHTNING, 0, {
		"power": 9, "mp_cost": 8, "break_power": 1, "target_all": true,
		"description": "雷系初阶法术，落雷打击全体。（占位名，待核对）",
	})
	_spell("huoyanquan", "火焰拳", GameTypes.Element.FIRE, 0, {
		"power": 14, "mp_cost": 4, "break_power": 1,
		"status_effect": "burn", "status_chance": 0.35,
		"description": "火系初阶法术，灼热拳劲，概率点燃。（原著法术名）",
	})
	_spell("huoxing", "火星迸溅", GameTypes.Element.FIRE, 0, {
		"power": 8, "mp_cost": 7, "break_power": 1, "target_all": true,
		"status_effect": "burn", "status_chance": 0.15,
		"description": "火系初阶法术，火星四溅波及全体。（占位名，待核对）",
	})
	_spell("bingzhui", "冰锥术", GameTypes.Element.ICE, 0, {
		"power": 13, "mp_cost": 4, "break_power": 1,
		"description": "冰系初阶法术，凝冰为锥刺击单体。（占位名，待核对）",
	})
	_spell("binghuan", "冰环术", GameTypes.Element.ICE, 0, {
		"power": 8, "mp_cost": 7, "break_power": 1, "target_all": true,
		"description": "冰系初阶法术，冰环扫过全体。（占位名，待核对）",
	})


func _spell(id: String, spell_name: String, element: int, tier: int, cfg: Dictionary) -> void:
	var s := SpellData.new()
	s.id = id
	s.spell_name = spell_name
	s.element = element
	s.tier = tier
	s.power = cfg.get("power", 10)
	s.mp_cost = cfg.get("mp_cost", 4)
	s.break_power = cfg.get("break_power", 1)
	s.target_all = cfg.get("target_all", false)
	s.status_effect = cfg.get("status_effect", "")
	s.status_chance = cfg.get("status_chance", 0.0)
	s.description = cfg.get("description", "")
	_save(s, SPELL_DIR + id + ".tres")


func _gen_monsters() -> void:
	_monster({
		"id": "rat_swarm", "monster_name": "鼠潮", "tier_name": "奴仆级",
		"max_hp": 26, "speed": 7, "attack": 6, "defense": 1, "shield": 1,
		"weaknesses": [GameTypes.Element.FIRE],
		"xp_value": 8, "gold_value": 6,
		"texture_path": "res://assets/images/monster_rat.png",
		"attack_power": 8, "special_name": "噬咬", "special_power": 12, "special_chance": 0.2,
	})
	_monster({
		"id": "one_eye_wolf", "monster_name": "独眼魔狼", "tier_name": "战将级",
		"max_hp": 60, "speed": 10, "attack": 10, "defense": 3, "shield": 2,
		"weaknesses": [GameTypes.Element.LIGHTNING],
		"xp_value": 20, "gold_value": 15,
		"essence_id": "essence_lightning", "essence_chance": 0.4,
		"texture_path": "res://assets/images/monster_wolf.png",
		"attack_power": 13, "special_name": "独眼魔光", "special_power": 18,
		"special_chance": 0.25, "special_status": "paralyze",
	})
	_monster({
		"id": "wolf_alpha", "monster_name": "独眼魔狼王", "tier_name": "统领级",
		"max_hp": 160, "speed": 11, "attack": 12, "defense": 5, "shield": 3,
		"weaknesses": [GameTypes.Element.LIGHTNING, GameTypes.Element.FIRE],
		"xp_value": 60, "gold_value": 60,
		"essence_id": "essence_lightning", "essence_chance": 1.0,
		"texture_path": "res://assets/images/monster_wolf.png", "sprite_scale": 1.6,
		"attack_power": 18, "special_name": "狼王咆哮", "special_power": 20,
		"special_chance": 0.3, "special_target_all": true, "special_status": "burn",
	})


func _monster(cfg: Dictionary) -> void:
	var m := MonsterData.new()
	for key in cfg:
		m.set(key, cfg[key])
	_save(m, MONSTER_DIR + cfg["id"] + ".tres")
