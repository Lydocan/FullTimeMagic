class_name GameData
## 数据注册表：法术 / 妖魔资源的路径与加载入口。
##
## 正式版可迁移为自动扫描 resources/ 目录，原型期用显式注册表。

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


static func load_spell(id: String) -> SpellData:
	return load(SPELLS[id]) as SpellData


static func load_monster(id: String) -> MonsterData:
	return load(MONSTERS[id]) as MonsterData


static func load_item(id: String) -> ItemData:
	return load(ITEMS[id]) as ItemData


static func load_equip(id: String) -> EquipData:
	return load(EQUIPS[id]) as EquipData
