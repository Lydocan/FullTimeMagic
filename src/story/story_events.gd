class_name StoryEvents
## 剧情事件：序章与第一章前半。
##
## 每个函数是一段可重入的演出，由地图触发器调用、旗标驱动进度：
## 战斗/跨场景通过 start_story_battle（胜利点亮旗标）与 warp 衔接，
## 战斗或传送后玩家回到触发点，事件再次进入时从旗标处续演。
## 文本与数值为原型占位，随剧情细化推进。

const BO_CITY := "res://src/world/bo_city/bo_city.tscn"
const MISTY_GROVE := "res://src/world/misty_grove/misty_grove.tscn"
const DUEL_ARENA := "res://src/world/arena/duel_arena.tscn"

const COL_MO := Color("c792ff")      # 莫凡（雷紫）
const COL_TANG := Color("ffb3c8")    # 唐月
const COL_XUE := Color("7ecbff")     # 穆宁雪（冰蓝）
const COL_YU := Color("ff9d6b")      # 宇昂
const COL_SYS := Color(0.85, 0.85, 0.85, 0.9)


## 序章：穿越独白 → 觉醒典礼（双系）→ 传送灰雾林地。
static func prologue(ctx) -> void:
	if ctx.flag("prologue_done"):
		return
	ctx.lock_player()
	if not ctx.flag("prologue_intro_done"):
		await Dialogue.say("", "意识浮出水面时，耳边是陌生的市井喧闹。", COL_SYS)
		await Dialogue.say("莫凡", "这里是……博城？胸口的小泥鳅吊坠还在发烫。", COL_MO)
		await Dialogue.say("莫凡", "一个魔法取代了科学的世界。行吧——既来之，则安之。", COL_MO)
		ctx.set_flag("prologue_intro_done")
	if not ctx.flag("prologue_awaken_done"):
		await Dialogue.say("唐月", "安静。一年一度的觉醒典礼，现在开始。", COL_TANG)
		await Dialogue.say("唐月", "莫凡，把手放上去。", COL_TANG)
		await Dialogue.say("", "觉醒石轰然亮起——紫色雷光与赤红火焰交织盘旋，久久不散！", COL_SYS)
		await Dialogue.say("唐月", "雷、火……双系觉醒？！百年未有的天赋……", COL_TANG)
		await Dialogue.say("唐月", "你的力量初醒不稳。去城北的灰雾林地试练一番，我在林地入口等你。", COL_TANG)
		ctx.set_flag("prologue_awaken_done")
		ctx.unlock_player()
		ctx.warp(MISTY_GROVE)
		return
	ctx.unlock_player()


## 灰雾林地入口：唐月指导 → 教学战（鼠潮）→ 战后叮嘱，序章完成。
static func grove_tutorial(ctx) -> void:
	if ctx.flag("prologue_done") or not ctx.flag("prologue_awaken_done"):
		return
	ctx.lock_player()
	if not ctx.flag("prologue_tutorial_done"):
		await Dialogue.say("唐月", "前面的鼠潮不算强，正好试试你新觉醒的力量。", COL_TANG)
		await Dialogue.say("", "战斗提示：↑↓ 选指令，回车确认；W/S 消耗星辉可增加法术段数；命中弱点削减魔盾，盾碎即「破魔」。鼠潮怕火。", COL_SYS)
		ctx.unlock_player()
		ctx.start_story_battle(["rat_swarm"], "prologue_tutorial_done")
		return
	await Dialogue.say("唐月", "感觉如何？雷主速攻麻痹，火主范围灼烧——双系并修，是你最大的本钱。", COL_TANG)
	await Dialogue.say("唐月", "先回城吧。对了，城东街口常能碰到穆家的大小姐，你们两家有旧谊。", COL_TANG)
	await Dialogue.say("", "序章·完。深草区可继续练手；篝火处可休息、修炼、存档。", COL_SYS)
	ctx.set_flag("prologue_done")
	ctx.unlock_player()
	ctx.warp(BO_CITY)


## 博城东街：重逢穆宁雪，选择回应后入队。
static func meet_mu_ningxue(ctx) -> void:
	if ctx.flag("ch1_mufu_done") or not ctx.flag("prologue_done"):
		return
	ctx.lock_player()
	await Dialogue.say("穆宁雪", "……莫凡。好久不见。", COL_XUE)
	await Dialogue.say("莫凡", "穆大小姐。听说你同龄就进了帝都学院，怎么回博城了。", COL_MO)
	await Dialogue.say("穆宁雪", "家中事务。……也顺便看看某人有没有堕落成废物。", COL_XUE)
	var choice: int = await Dialogue.choose("如何回应？", [
		"「我会用实力证明，那份婚约值得保留。」",
		"「那你可要看好了。」",
	])
	if choice == 0:
		await Dialogue.say("穆宁雪", "……还是老样子，嘴硬。", COL_XUE)
	else:
		await Dialogue.say("穆宁雪", "哼。那我拭目以待。", COL_XUE)
	await Dialogue.say("穆宁雪", "最近灰雾林地的妖魔在异动，我探过一次，没敢深入。", COL_XUE)
	await Dialogue.say("穆宁雪", "既然要猎妖，一起吧。别拖我后腿。", COL_XUE)
	await Dialogue.say("", "穆宁雪加入了队伍！（冰系·初阶三星，正压着瓶颈）", COL_SYS)
	GameState.join_member(PartySetup.mu_ningxue())
	ctx.set_flag("ch1_mufu_done")
	ctx.unlock_player()


## 天澜高中门口：宇昂挑衅（决斗正战留第一章后半）。
static func yu_ang_taunt(ctx) -> void:
	if ctx.flag("ch1_yuang_done") or not ctx.flag("prologue_done"):
		return
	ctx.lock_player()
	await Dialogue.say("宇昂", "哟，这不是穆家的……未婚夫吗？双系觉醒，很风光啊。", COL_YU)
	await Dialogue.say("宇昂", "可惜。博城能去地圣泉的名额只有一个。毕业决斗上，我会当众碾碎你的雷火把戏。", COL_YU)
	await Dialogue.say("莫凡", "决斗台上见。到时候别哭。", COL_MO)
	await Dialogue.say("", "（毕业决斗将在第一章后半上演——当前版本可先去城北林地修炼。）", COL_SYS)
	ctx.set_flag("ch1_yuang_done")
	ctx.unlock_player()


## 狼王被讨伐后的剧情：黑教廷线索，第一章前半完。
static func grove_after_boss(ctx) -> void:
	if not ctx.flag("elite_wolf_dead") or ctx.flag("chapter1_half_done") or not ctx.flag("prologue_done"):
		return
	ctx.lock_player()
	await Dialogue.say("唐月", "狼王的独眼在死后仍泛着紫光……这不是天然生成的妖兽。", COL_TANG)
	await Dialogue.say("唐月", "有人在操控妖魔。这股气息……和传闻中「黑教廷」的手法很像。", COL_TANG)
	await Dialogue.say("莫凡", "黑教廷？", COL_MO)
	await Dialogue.say("唐月", "此事我会呈报判庭。你先回城休整——变强的路，还很长。", COL_TANG)
	await Dialogue.say("", "—— 第一章·前半 完 ——\n（后续将推进：地圣泉修行、毕业决斗、博城之变）", COL_SYS)
	ctx.set_flag("chapter1_half_done")
	ctx.unlock_player()


## 天澜高中门口：先宇昂挑衅，第一章前半完后触发毕业决斗约定。
static func school_gate(ctx) -> void:
	if not ctx.flag("ch1_yuang_done"):
		await yu_ang_taunt(ctx)
		return
	if not ctx.flag("duel_intro_done") and ctx.flag("chapter1_half_done"):
		await graduation_duel_intro(ctx)


## 毕业决斗·约定：天澜高中门口，赌上地圣泉名额（M3.1）。
static func graduation_duel_intro(ctx) -> void:
	ctx.lock_player()
	await Dialogue.say("宇昂", "哟，有胆子来了。地圣泉的名额只有一个——敢不敢现在就去决斗台做个了断？", COL_YU)
	await Dialogue.say("莫凡", "正合我意。决斗台上见真章。", COL_MO)
	await Dialogue.say("唐月", "规则按校规来：一对一，点到为止……不，这次你们随意。我在台上看着。", COL_TANG)
	await Dialogue.say("", "毕业决斗开始——只有莫凡一人可以上场。（决斗失败会读回最近的存档）", COL_SYS)
	ctx.set_flag("duel_intro_done")
	ctx.unlock_player()
	ctx.warp(DUEL_ARENA)


## 决斗台：入场开战（莫凡单人 vs 宇昂）→ 胜利演出 → 夺得名额（M3.1）。
static func duel_arena(ctx) -> void:
	if ctx.flag("duel_done") or not ctx.flag("duel_intro_done"):
		return
	ctx.lock_player()
	if not ctx.flag("duel_fought"):
		await Dialogue.say("宇昂", "全校都看着呢。让我看看，「百年一遇的双系天才」有几斤几两！", COL_YU)
		await Dialogue.say("莫凡", "几招之后就知道了。……雷与火，可不止一种用法。", COL_MO)
		ctx.set_flag("duel_fought")
		ctx.unlock_player()
		# 决斗限定莫凡单人出战（出战成员子集）
		ctx.start_story_battle(["yu_ang"], "duel_won", ["mo_fan"])
		return
	# 胜利归来：战后演出
	await Dialogue.say("宇昂", "不可能……我的炎爆怎么会输给……", COL_YU)
	await Dialogue.say("宇昂", "……哼。决斗输了，名额归你。但博城的天，不会一直这么晴。——走着瞧。", COL_YU)
	await Dialogue.say("", "宇昂转身离场，袖口滑出一角暗紫色的纹章，快得没人看清……只有莫凡眯了眯眼。", COL_SYS)
	await Dialogue.say("唐月", "地圣泉的名额是你的了。三日后泉门开启，去准备吧。", COL_TANG)
	await Dialogue.say("莫凡", "（那枚纹章……和狼王尸体上的气息，是同一路东西。）", COL_MO)
	await Dialogue.say("", "—— 毕业决斗·完 ——\n夺得地圣泉修行资格！（地圣泉修行将在后续版本开放）", COL_SYS)
	ctx.set_flag("duel_done")
	ctx.unlock_player()
	ctx.warp(BO_CITY)


## 决斗台·唐月（裁判）闲谈。
static func arena_referee(ctx) -> void:
	if ctx.flag("duel_done"):
		await Dialogue.say("唐月", "赢了决斗只是开始。地圣泉里，好好想想你的雷与火该怎么走。", COL_TANG)
	elif ctx.flag("duel_fought"):
		await Dialogue.say("唐月", "伤没好透就别急着再挑一场——决斗随时可以重来。", COL_TANG)
	else:
		await Dialogue.say("唐月", "决斗台上不许下死手。其他……你们自己解决。", COL_TANG)
