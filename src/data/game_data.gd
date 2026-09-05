class_name GameData
## 数据注册表：法术 / 妖魔资源的路径与加载入口。
##
## 正式版可迁移为自动扫描 resources/ 目录，原型期用显式注册表。

## 衣装脚本：按路径 preload，不依赖 class_name 全局缓存（docs/lessons.md 踩坑 12/18）。
const ClothingDataScript := preload("res://src/data/clothing_data.gd")

const SPELLS := {
	"lei_yin": "res://resources/spells/lei_yin.tres",
	"luo_lei": "res://resources/spells/luo_lei.tres",
	"huoyanquan": "res://resources/spells/huoyanquan.tres",
	"huoxing": "res://resources/spells/huoxing.tres",
	"bingzhui": "res://resources/spells/bingzhui.tres",
	"binghuan": "res://resources/spells/binghuan.tres",
}

const MONSTERS := {
	"rat_swarm": "res://resources/monsters/rat_swarm.tres",
	"one_eye_wolf": "res://resources/monsters/one_eye_wolf.tres",
	"wolf_alpha": "res://resources/monsters/wolf_alpha.tres",
	"yu_ang": "res://resources/monsters/yu_ang.tres",
}

const ITEMS := {
	"yuelu": "res://resources/items/yuelu.tres",
	"mojingjie": "res://resources/items/mojingjie.tres",
	"fuhuo_yumao": "res://resources/items/fuhuo_yumao.tres",
}

const EQUIPS := {
	"leiwen_zhang": "res://resources/equips/leiwen_zhang.tres",
	"yuebai_pao": "res://resources/equips/yuebai_pao.tres",
	"lansui_zhui": "res://resources/equips/lansui_zhui.tres",
}

## 衣装（纯外观 + 华丽度）：初始三套 + 商店四档价位。
const CLOTHES := {
	# 初始赠送：骑士装
	"cloth_knight_hat": "res://resources/clothes/cloth_knight_hat.tres",
	"cloth_knight_top": "res://resources/clothes/cloth_knight_top.tres",
	"cloth_knight_pants": "res://resources/clothes/cloth_knight_pants.tres",
	# 初始赠送：魔法师套装
	"cloth_mage_hat": "res://resources/clothes/cloth_mage_hat.tres",
	"cloth_mage_top": "res://resources/clothes/cloth_mage_top.tres",
	"cloth_mage_pants": "res://resources/clothes/cloth_mage_pants.tres",
	# 初始赠送：剑士套装
	"cloth_sword_hat": "res://resources/clothes/cloth_sword_hat.tres",
	"cloth_sword_top": "res://resources/clothes/cloth_sword_top.tres",
	"cloth_sword_pants": "res://resources/clothes/cloth_sword_pants.tres",
	# 商店 10 金（华丽度 10）
	"cloth_shop_10_hat": "res://resources/clothes/cloth_shop_10_hat.tres",
	"cloth_shop_10_top": "res://resources/clothes/cloth_shop_10_top.tres",
	"cloth_shop_10_pants": "res://resources/clothes/cloth_shop_10_pants.tres",
	# 商店 50 金（华丽度 50）
	"cloth_shop_50_hat": "res://resources/clothes/cloth_shop_50_hat.tres",
	"cloth_shop_50_top": "res://resources/clothes/cloth_shop_50_top.tres",
	"cloth_shop_50_pants": "res://resources/clothes/cloth_shop_50_pants.tres",
	# 商店 100 金（华丽度 100）
	"cloth_shop_100_hat": "res://resources/clothes/cloth_shop_100_hat.tres",
	"cloth_shop_100_top": "res://resources/clothes/cloth_shop_100_top.tres",
	"cloth_shop_100_pants": "res://resources/clothes/cloth_shop_100_pants.tres",
	# 商店 1000 金（华丽度 1000）
	"cloth_shop_1000_hat": "res://resources/clothes/cloth_shop_1000_hat.tres",
	"cloth_shop_1000_top": "res://resources/clothes/cloth_shop_1000_top.tres",
	"cloth_shop_1000_pants": "res://resources/clothes/cloth_shop_1000_pants.tres",
}


static func load_spell(id: String) -> SpellData:
	return load(SPELLS[id]) as SpellData


static func load_monster(id: String) -> MonsterData:
	return load(MONSTERS[id]) as MonsterData


static func load_item(id: String) -> ItemData:
	return load(ITEMS[id]) as ItemData


static func load_equip(id: String) -> EquipData:
	return load(EQUIPS[id]) as EquipData


static func load_clothing(id: String) -> ClothingDataScript:
	return load(CLOTHES[id]) as ClothingDataScript
