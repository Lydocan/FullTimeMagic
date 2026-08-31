extends "res://src/world/map_base.gd"
## 博城：第一章主城。莫家（篝火/存档）、街道、天澜高中。
## 城内无遇敌；北门通灰雾林地。
## 占位美术期：树块代表房屋与围墙，正式地图换编辑器制作。
##
## 注意：继承与剧情事件均按路径 preload，不依赖 class_name 全局缓存，
## 避免 .godot 缓存过期时报 "Could not find base class"。

const Story := preload("res://src/story/story_events.gd")

const MAP := [
	"TTTTTTTTTT", "TTTTTTTTTT", "GTTTTTTTTT", "TTTTTTTTTT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GTTTTTTGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GTTTTTTGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GTTTTTTGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGTTTTTGG", "GGGGGGGGGG", "PGGTTTTTGG", "GGTTTTTGGT",
	"TGGTTTTTGG", "GGGGGGGGGG", "PGGTTTTTGG", "GGTTTTTGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGPPPPPP", "PPPPPPPPPP", "PPPPPPPPPP", "PPPPPPPPGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGTTTTTGG", "GGGGGGGGGG", "PGGTTTTTGG", "GGTTTTTGGT",
	"TGGTTTTTGG", "GGGGGGGGGG", "PGGTTTTTGG", "GGTTTTTGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGPPPP", "PPPPPPPPPP", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TGGGGGGGGG", "GGGGGGGGGG", "PGGGGGGGGG", "GGGGGGGGGT",
	"TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT", "TTTTTTTTTT",
]

const HOME_CELL := Vector2i(6, 19)
const SPAWN_CELL := Vector2i(7, 19)
const NORTH_GATE := Vector2i(20, 1)
const GROVE_SCENE := "res://src/world/misty_grove/misty_grove.tscn"


func map_rows() -> Array:
	return MAP


func bgm_name() -> String:
	return "town"


func start_cell() -> Vector2i:
	return SPAWN_CELL


func setup_triggers() -> void:
	add_campfire(HOME_CELL)
	add_portal(NORTH_GATE, GROVE_SCENE, Vector2i(7, 20))
	# 序章：出生点自动触发（穿越 + 觉醒典礼）
	add_trigger(SPAWN_CELL, 56.0, func() -> void: await Story.prologue(self))
	# 天澜高中门口：宇昂挑衅
	add_trigger(Vector2i(13, 6), 56.0, func() -> void: await Story.yu_ang_taunt(self))
	# 东街：重逢穆宁雪
	add_trigger(Vector2i(30, 12), 56.0, func() -> void: await Story.meet_mu_ningxue(self))
	# —— 剧情 NPC（事件演完后退场）——
	add_npc(Vector2i(8, 19), "res://assets/images/char_tangyue.png",
			"唐月", "prologue_awaken_done",
			func() -> void: await Story.prologue(self))
	add_npc(Vector2i(30, 13), "res://assets/images/char_muningxue.png",
			"穆宁雪", "ch1_mufu_done",
			func() -> void: await Story.meet_mu_ningxue(self))
	add_npc(Vector2i(13, 6), "res://assets/images/char_yuang.png",
			"宇昂", "ch1_yuang_done",
			func() -> void: await Story.yu_ang_taunt(self))
