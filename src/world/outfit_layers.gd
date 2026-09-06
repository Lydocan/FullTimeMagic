extends RefCounted
## 分层换装共用逻辑——玩家 / 跟随者 / 战斗单位三处共用的唯一权威（P14）。
##
## 槽位顺序即渲染顺序（内 → 外）；穿连衣裙时上/下装层隐藏，腿袜在裙摆下露出。
## 高清立绘（docs/art_spec.md）仅用于衣柜预览与战斗立绘合成；
## 世界与战斗的像素小人统一走 clothes 目录。

const SLOTS_BY_MEMBER := {
	"mo_fan": ["hat", "top", "pants"],
	"mu_ningxue": ["hosiery", "pants", "top", "dress", "hat"],
}

const BASE_BY_MEMBER := {
	"mo_fan": "res://assets/images/char_mofan_base.png",
	"mu_ningxue": "res://assets/images/char_muningxue_base.png",
}

const CLOTHES_DIR := "res://assets/images/clothes/"
const ART_DIR := "res://assets/images/art/"


static func has_wardrobe(member_id: String) -> bool:
	return SLOTS_BY_MEMBER.has(member_id)


## 像素衣装纹理（地图/战斗小人）。槽位留空返回 null（层隐藏）。
static func pixel_texture(worn: Dictionary, slot: String) -> Texture2D:
	var id: String = str(worn.get(slot, ""))
	if id == "":
		return null
	var path := CLOTHES_DIR + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## 刷新一组槽位精灵：设纹理与可见性（连衣裙覆盖上/下装外观）。
## layer_sprites: {slot: Sprite2D}，调用方保证挂载位置与缩放正确。
static func refresh_layers(worn: Dictionary, layer_sprites: Dictionary) -> void:
	var dress_on: bool = str(worn.get("dress", "")) != ""
	for slot in layer_sprites:
		var s: Sprite2D = layer_sprites[slot]
		s.texture = pixel_texture(worn, slot)
		s.visible = s.texture != null and not (dress_on and (slot == "top" or slot == "pants"))
