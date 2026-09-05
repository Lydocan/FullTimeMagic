class_name ClothingData
extends Resource
## 衣装数据（.tres 数据驱动，实例见 resources/clothes/）。
## 纯外观：不加属性，只贡献华丽度（拥有即计入，与是否穿着无关）。

@export var id: String = ""
@export var clothing_name: String = ""
## 部位："hat" 帽子 / "top" 上衣 / "pants" 裤子。
@export var slot: String = "top"
## 华丽度：所有已拥有衣装的华丽度总和决定玩家的时尚称号。
@export var glamour: int = 0
## 售价（0 = 初始赠送，商店不出售）。
@export var price: int = 0


func slot_name() -> String:
	return GameTypes.clothing_slot_name(slot)
