extends SceneTree
## 生成法术与妖魔的 .tres 数据文件（一次性脚手架，之后可在编辑器中直接调整）。
##
## 运行：godot --headless --path . --script res://tools/generate_data.gd

const SPELL_DIR := "res://resources/spells/"
const MONSTER_DIR := "res://resources/monsters/"

# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const ClothingData := preload("res://src/data/clothing_data.gd")
const GameTypes := preload("res://src/data/game_types.gd")
const SpellData := preload("res://src/data/spell_data.gd")
const MonsterData := preload("res://src/data/monster_data.gd")


func _initialize() -> void:
	_gen_spells()
	_gen_monsters()
	_gen_clothes()
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
	# 数值与 resources/monsters/*.tres 保持同步（2026-09-05 严峻化调整：
	# 攻击普涨 ~25-35%——初阶打小怪也要吃力；等阶 + 压制系数 + Boss 二阶段。
	# 同阶妖兽强于人类（world.md：等级压制感）；压制系数 0=人类对等，
	# 0.5=虚弱个体，1.0=完整压制，保底可攻略——见 battle.gd _tier_gap）
	_monster({
		"id": "rat_swarm", "monster_name": "鼠潮", "tier": GameTypes.MonsterTier.SERVANT,
		"element": -1,
		"max_hp": 45, "speed": 7, "attack": 11, "defense": 2, "shield": 1,
		"weaknesses": [GameTypes.Element.FIRE],
		"xp_value": 2, "gold_value": 6,
		"drop_id": "yuelu", "drop_chance": 0.25,  # 鼠群巢穴常翻出遗落的草药
		"texture_path": "res://assets/images/monster_rat.png", "sprite_scale": 2.6,
		"attack_power": 14,
		"skills": [{"name": "撕咬", "power": 18, "chance": 0.25,
			"target_all": false, "status": "", "status_chance": 0.0}],
	})
	_monster({
		"id": "one_eye_wolf", "monster_name": "独眼魔狼", "tier": GameTypes.MonsterTier.SERVANT,
		"element": GameTypes.Element.LIGHTNING,
		"max_hp": 130, "speed": 10, "attack": 13, "defense": 5, "shield": 2,
		"weaknesses": [GameTypes.Element.LIGHTNING],
		"xp_value": 8, "gold_value": 18,
		"essence_id": "essence_lightning", "essence_chance": 0.4,
		"drop_id": "mojingjie", "drop_chance": 0.2,  # 雷魔狼体内凝出的结晶
		"texture_path": "res://assets/images/monster_wolf.png", "sprite_scale": 2.2,
		"attack_power": 18,
		"skills": [{"name": "独眼魔光", "power": 23, "chance": 0.25,
			"target_all": false, "status": "paralyze", "status_chance": 0.6}],
	})
	_monster({
		"id": "wolf_alpha", "monster_name": "独眼魔狼王", "tier": GameTypes.MonsterTier.COMMANDER,
		"element": GameTypes.Element.LIGHTNING,
		"max_hp": 280, "speed": 11, "attack": 15, "defense": 7, "shield": 3,
		"weaknesses": [GameTypes.Element.LIGHTNING, GameTypes.Element.FIRE],
		"xp_value": 30, "gold_value": 70,
		"essence_id": "essence_lightning", "essence_chance": 1.0,
		"drop_id": "fuhuo_yumao", "drop_chance": 0.5,  # 王级稀有掉落
		"portrait_path": "res://assets/images/portrait_wolf_king.png",
		# 林地这只为先遣的虚弱分身（suppression_scale 0.5）：战将级对初阶
		# 仍需可攻略——完整体的压制将在博城之变（M3.3）兑现
		"suppression_scale": 0.5,
		# 狼王独占贴图（双角+异变赤纹）：与战将级狼群同阶但体型威压全开，
		# 2.6 倍下的 132x86 画布 ≈ 屏上 343x224，体积压过在场所有单位
		"texture_path": "res://assets/images/monster_wolf_king.png", "sprite_scale": 2.6,
		"attack_power": 24,
		# 双血条：第一管 280 打空 → 狂化换上第二管 200，攻防大幅强化
		"phase2_hp": 200, "phase2_attack": 5, "phase2_defense": 3,
		"phase2_name": "狼王狂化",
		"skills": [
			{"name": "狼王咆哮", "power": 25, "chance": 0.3,
				"target_all": true, "status": "burn", "status_chance": 0.5},
			{"name": "雷霆扑杀", "power": 31, "chance": 0.25,
				"target_all": false, "status": "", "status_chance": 0.0},
		],
	})
	_monster({
		"id": "yu_ang", "monster_name": "宇昂", "tier": GameTypes.MonsterTier.COMMANDER,
		"element": GameTypes.Element.FIRE,
		"max_hp": 240, "speed": 10, "attack": 14, "defense": 6, "shield": 4,
		"weaknesses": [GameTypes.Element.LIGHTNING],
		"xp_value": 20, "gold_value": 80,
		# 人类对手不受等级压制（毕业决斗是技能对等的镜像局，初阶莫凡打赢
		# 战将级宇昂是原著定局）；双血条：第一管打空后炎纹觉醒，攻防强化
		"suppression_scale": 0.0,
		"phase2_hp": 140, "phase2_attack": 4, "phase2_defense": 3,
		"phase2_name": "炎纹觉醒",
		"portrait_path": "res://assets/images/portrait_yu_ang.png",
		"texture_path": "res://assets/images/char_yuang.png", "sprite_scale": 2.6,
		"attack_power": 18,
		"skills": [
			{"name": "炎爆", "power": 27, "chance": 0.3,
				"target_all": false, "status": "burn", "status_chance": 0.5},
			{"name": "连珠火弹", "power": 17, "chance": 0.25,
				"target_all": true, "status": "", "status_chance": 0.0},
		],
	})


func _monster(cfg: Dictionary) -> void:
	var m := MonsterData.new()
	for key in cfg:
		m.set(key, cfg[key])
	m.tier_name = GameTypes.monster_tier_name(m.tier)  # 显示名由等阶唯一决定
	_save(m, MONSTER_DIR + cfg["id"] + ".tres")


const CLOTHES_DIR := "res://resources/clothes/"


## 衣装：初始三套（骑士/魔法师/剑士，各帽子/上衣/裤子，全部 0 华丽度）+
## 商店四档价位 10/50/100/1000（华丽度与售价对应）。纯外观，不加属性。
func _gen_clothes() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLOTHES_DIR))
	var starters := [
		# 骑士装
		{"id": "cloth_knight_hat", "name": "骑士头盔", "slot": "hat"},
		{"id": "cloth_knight_top", "name": "骑士胸甲", "slot": "top"},
		{"id": "cloth_knight_pants", "name": "骑士护腿", "slot": "pants"},
		# 魔法师套装
		{"id": "cloth_mage_hat", "name": "法师尖帽", "slot": "hat"},
		{"id": "cloth_mage_top", "name": "法师长袍", "slot": "top"},
		{"id": "cloth_mage_pants", "name": "法师束裤", "slot": "pants"},
		# 剑士套装
		{"id": "cloth_sword_hat", "name": "剑士头巾", "slot": "hat"},
		{"id": "cloth_sword_top", "name": "剑士劲装", "slot": "top"},
		{"id": "cloth_sword_pants", "name": "剑士束腿", "slot": "pants"},
	]
	for c in starters:
		_clothing({"id": c["id"], "clothing_name": c["name"], "slot": c["slot"],
				"glamour": 0, "price": 0})
	var shop_tiers := [
		{"glamour": 10, "price": 10, "names": ["旅人草帽", "旅人布衣", "旅人长裤"]},
		{"glamour": 50, "price": 50, "names": ["猎人风帽", "猎人皮衣", "猎人长裤"]},
		{"glamour": 100, "price": 100, "names": ["贵族礼帽", "贵族华服", "贵族礼裤"]},
		{"glamour": 1000, "price": 1000, "names": ["君王冠冕", "君王华服", "君王护胫"]},
	]
	var slots := ["hat", "top", "pants"]
	for tier in shop_tiers:
		for i in 3:
			_clothing({"id": "cloth_shop_%d_%s" % [tier["price"], slots[i]],
					"clothing_name": tier["names"][i], "slot": slots[i],
					"glamour": tier["glamour"], "price": tier["price"]})


func _clothing(cfg: Dictionary) -> void:
	var c := ClothingData.new()
	for key in cfg:
		c.set(key, cfg[key])
	_save(c, CLOTHES_DIR + cfg["id"] + ".tres")
