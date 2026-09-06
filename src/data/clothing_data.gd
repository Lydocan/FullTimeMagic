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


# 跨模块依赖一律按路径 preload，不依赖 class_name 全局缓存（踩坑 12/18）。
const GameTypes := preload("res://src/data/game_types.gd")


func slot_name() -> String:
	return GameTypes.clothing_slot_name(slot)
