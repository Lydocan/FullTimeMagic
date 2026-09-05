extends SceneTree
## 生成原型占位美术 PNG（程序化绘制，正式美术就位后整体替换）。
##
## 运行：godot --headless --path . --script res://tools/gen_placeholder_art.gd

const DIR := "res://assets/images/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 20260831
	_tiles()
	_characters()
	_portraits()
	_monsters()
	_battle_bg()
	_campfire()
	quit(0)


func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


func _speckle(img: Image, c: Color, n: int) -> void:
	for i in n:
		img.set_pixel(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1), c)


func _save(img: Image, name: String) -> void:
	var err := img.save_png(DIR + name)
	print("生成 %s -> %s" % [name, "成功" if err == OK else "失败(%d)" % err])


## 图块集：32px × 11（草地/深草/小径/树/岩石/水/屋顶/墙体/门/红瓦/尖塔），横向排布。
func _tiles() -> void:
	var img := _img(32 * 11, 32)
	for i in 11:
		var ox := i * 32
		match i:
			0: # 草地
				_rect(img, ox, 0, 32, 32, Color("4d8044"))
				_speckle(img, Color("43703b"), 40)
				_speckle(img, Color("5b904f"), 20)
			1: # 深草（遇敌区）
				_rect(img, ox, 0, 32, 32, Color("3f6e38"))
				for b in 14:
					var bx := rng.randi_range(ox + 2, ox + 29)
					_rect(img, bx, rng.randi_range(6, 18), 1, rng.randi_range(4, 8), Color("568a48"))
			2: # 小径
				_rect(img, ox, 0, 32, 32, Color("b39b72"))
				_speckle(img, Color("a08a63"), 30)
				_speckle(img, Color("c2ac82"), 15)
			3: # 树（阻挡）
				_rect(img, ox, 0, 32, 32, Color("4d8044"))
				_speckle(img, Color("43703b"), 25)
				_rect(img, ox + 13, 18, 6, 12, Color("6b4a2f"))
				_rect(img, ox + 6, 4, 20, 14, Color("2f5d2b"))
				_rect(img, ox + 9, 2, 14, 6, Color("386a31"))
				_rect(img, ox + 8, 14, 16, 4, Color("27501f"))
			4: # 岩石（阻挡）
				_rect(img, ox, 0, 32, 32, Color("4d8044"))
				_speckle(img, Color("43703b"), 25)
				_rect(img, ox + 7, 13, 18, 13, Color("8a8a86"))
				_rect(img, ox + 10, 13, 7, 4, Color("a5a5a0"))
				_rect(img, ox + 7, 24, 18, 2, Color("6f6f6b"))
			5: # 水（阻挡）
				_rect(img, ox, 0, 32, 32, Color("3c6ea5"))
				_rect(img, ox + 4, 7, 10, 1, Color("5586b8"))
				_rect(img, ox + 16, 15, 12, 1, Color("5586b8"))
				_rect(img, ox + 8, 24, 9, 1, Color("4d7cae"))
			6: # 屋顶（蓝瓦，阻挡）
				_rect(img, ox, 0, 32, 32, Color("3e4c6e"))
				_rect(img, ox, 0, 32, 3, Color("55679a"))
				for ry in [8, 16, 24]:
					_rect(img, ox, ry, 32, 2, Color("2e3a57"))
			7: # 墙体（米白 + 木框窗，阻挡）
				_rect(img, ox, 0, 32, 32, Color("d8cdb8"))
				_rect(img, ox, 28, 32, 4, Color("b8ac96"))
				_rect(img, ox + 8, 8, 14, 12, Color("6b4a2f"))
				_rect(img, ox + 10, 10, 10, 8, Color("9cc4e8"))
			8: # 门（墙体 + 拱形木门，阻挡）
				_rect(img, ox, 0, 32, 32, Color("d8cdb8"))
				_rect(img, ox + 6, 4, 20, 28, Color("6b4a2f"))
				_rect(img, ox + 8, 6, 16, 26, Color("8a6238"))
				_rect(img, ox + 21, 18, 2, 2, Color("ffd166"))
			9: # 校舍红瓦（阻挡）
				_rect(img, ox, 0, 32, 32, Color("a03c3c"))
				_rect(img, ox, 0, 32, 3, Color("c25858"))
				for ry in [8, 16, 24]:
					_rect(img, ox, ry, 32, 2, Color("7c2c2c"))
			10: # 校舍尖塔（红瓦金字塔 + 金顶饰，阻挡）
				_rect(img, ox, 14, 32, 18, Color("a03c3c"))
				for r in 7:
					var w := 8 + r * 4
					_rect(img, ox + (32 - w) / 2, r * 2, w, 2, Color("a03c3c"))
					_rect(img, ox + (32 - w) / 2, r * 2 + 1, w, 1, Color("7c2c2c"))
				_rect(img, ox + 14, 0, 4, 3, Color("ffd166"))
	_save(img, "tiles_proto.png")


## 24x32 人物占位。造型要点：发丝双色分层、眼睛有眼白+高光点、
## 衣服带衣褶阴影与领口、双脚分开——去掉"方块人"的呆气。
func _characters() -> void:
	# 莫凡：微乱短发 + 高领蓝衣，右手握拳侧身
	var fan := _img(24, 32)
	_rect(fan, 7, 2, 10, 6, Color("2a2a35"))
	_rect(fan, 6, 3, 2, 4, Color("2a2a35"))      # 侧发翘起
	_rect(fan, 16, 3, 2, 3, Color("2a2a35"))
	_rect(fan, 8, 2, 7, 2, Color("3d3d4d"))      # 发顶高光
	_rect(fan, 8, 7, 8, 5, Color("e8c39a"))
	_rect(fan, 8, 7, 8, 1, Color("d4a884"))      # 发影投在额头
	_rect(fan, 9, 9, 2, 2, Color("e8e8f0"))      # 眼白
	_rect(fan, 10, 9, 1, 2, Color("303038"))     # 瞳
	_rect(fan, 13, 9, 2, 2, Color("e8e8f0"))
	_rect(fan, 14, 9, 1, 2, Color("303038"))
	_rect(fan, 10, 9, 1, 1, Color("ffffff"))     # 眼高光
	_rect(fan, 14, 9, 1, 1, Color("ffffff"))
	_rect(fan, 9, 8, 6, 1, Color("303038"))      # 剑眉
	_rect(fan, 10, 12, 4, 1, Color("c9946a"))    # 嘴
	_rect(fan, 6, 13, 12, 9, Color("3b4a8c"))
	_rect(fan, 6, 13, 12, 2, Color("46569e"))    # 高领
	_rect(fan, 11, 15, 2, 7, Color("324077"))    # 衣襟
	_rect(fan, 7, 20, 10, 1, Color("2c3a70"))    # 下摆阴影
	_rect(fan, 4, 14, 2, 6, Color("324077"))
	_rect(fan, 18, 14, 3, 5, Color("324077"))    # 右臂前摆
	_rect(fan, 19, 19, 2, 2, Color("e8c39a"))    # 握拳手
	_rect(fan, 8, 22, 3, 7, Color("2c2c34"))
	_rect(fan, 13, 22, 3, 7, Color("26262e"))
	_rect(fan, 7, 29, 4, 2, Color("1d1d24"))
	_rect(fan, 13, 29, 3, 2, Color("1d1d24"))
	_save(fan, "char_mofan.png")

	# 穆宁雪：银发披肩 + 冰蓝长裙，发丝垂到腰际
	var xue := _img(24, 32)
	_rect(xue, 5, 2, 14, 9, Color("cfd8e6"))
	_rect(xue, 6, 2, 10, 2, Color("e8f0f8"))     # 发顶高光
	_rect(xue, 4, 8, 3, 14, Color("b8c8dc"))     # 左发披至腰
	_rect(xue, 17, 8, 3, 14, Color("b8c8dc"))
	_rect(xue, 4, 20, 3, 2, Color("a4b8d0"))     # 发尾层次
	_rect(xue, 17, 20, 3, 2, Color("a4b8d0"))
	_rect(xue, 8, 7, 8, 5, Color("f2dcc0"))
	_rect(xue, 8, 7, 8, 1, Color("d8c0a8"))
	_rect(xue, 9, 9, 2, 2, Color("e8e8f0"))
	_rect(xue, 10, 9, 1, 2, Color("4a6d9c"))
	_rect(xue, 13, 9, 2, 2, Color("e8e8f0"))
	_rect(xue, 14, 9, 1, 2, Color("4a6d9c"))
	_rect(xue, 10, 9, 1, 1, Color("ffffff"))
	_rect(xue, 14, 9, 1, 1, Color("ffffff"))
	_rect(xue, 10, 12, 4, 1, Color("c98c8c"))    # 嘴
	_rect(xue, 6, 12, 12, 10, Color("9cc4e8"))
	_rect(xue, 6, 12, 12, 2, Color("b0d4f0"))    # 领口雪白
	_rect(xue, 11, 14, 2, 8, Color("84aed4"))    # 衣襟
	_rect(xue, 6, 20, 12, 2, Color("8ab4dc"))    # 束腰
	_rect(xue, 5, 22, 14, 4, Color("9cc4e8"))    # 裙摆展开
	_rect(xue, 4, 26, 16, 3, Color("7fa8cf"))
	_rect(xue, 4, 29, 16, 1, Color("6d97be"))    # 裙摆阴影
	_save(xue, "char_muningxue.png")

	# 唐月：黑长直披肩 + 火红外套
	var tang := _img(24, 32)
	_rect(tang, 5, 1, 14, 11, Color("1f1f28"))
	_rect(tang, 6, 1, 10, 2, Color("343444"))    # 发顶高光
	_rect(tang, 4, 9, 3, 16, Color("1f1f28"))
	_rect(tang, 17, 9, 3, 16, Color("1f1f28"))
	_rect(tang, 4, 22, 3, 3, Color("16161e"))
	_rect(tang, 17, 22, 3, 3, Color("16161e"))
	_rect(tang, 8, 7, 8, 5, Color("eec9a0"))
	_rect(tang, 8, 7, 8, 1, Color("c8a480"))
	_rect(tang, 9, 9, 2, 2, Color("e8e8f0"))
	_rect(tang, 10, 9, 1, 2, Color("a03030"))
	_rect(tang, 13, 9, 2, 2, Color("e8e8f0"))
	_rect(tang, 14, 9, 1, 2, Color("a03030"))
	_rect(tang, 10, 9, 1, 1, Color("ffffff"))
	_rect(tang, 14, 9, 1, 1, Color("ffffff"))
	_rect(tang, 9, 8, 6, 1, Color("2a2a30"))     # 平眉
	_rect(tang, 10, 12, 4, 1, Color("b06a5a"))
	_rect(tang, 6, 12, 12, 11, Color("b03434"))
	_rect(tang, 6, 12, 12, 2, Color("c44a4a"))   # 肩高光
	_rect(tang, 11, 14, 2, 9, Color("8c2626"))
	_rect(tang, 6, 21, 12, 1, Color("7c2020"))
	_rect(tang, 4, 13, 2, 7, Color("9c2c2c"))
	_rect(tang, 18, 13, 2, 7, Color("9c2c2c"))
	_rect(tang, 8, 23, 3, 6, Color("2c2c34"))
	_rect(tang, 13, 23, 3, 6, Color("26262e"))
	_rect(tang, 7, 29, 4, 2, Color("1d1d24"))
	_rect(tang, 13, 29, 3, 2, Color("1d1d24"))
	_save(tang, "char_tangyue.png")

	# 宇昂：金发后梳 + 白金华服，下巴微扬
	var yu := _img(24, 32)
	_rect(yu, 6, 2, 12, 6, Color("d8b44a"))
	_rect(yu, 7, 2, 9, 2, Color("eacc6e"))
	_rect(yu, 5, 4, 2, 3, Color("c8a038"))       # 鬓角
	_rect(yu, 17, 4, 2, 3, Color("c8a038"))
	_rect(yu, 8, 7, 8, 5, Color("eec9a0"))
	_rect(yu, 8, 7, 8, 1, Color("c8a480"))
	_rect(yu, 9, 9, 2, 2, Color("e8e8f0"))
	_rect(yu, 10, 9, 1, 2, Color("3c4c8c"))
	_rect(yu, 13, 9, 2, 2, Color("e8e8f0"))
	_rect(yu, 14, 9, 1, 2, Color("3c4c8c"))
	_rect(yu, 10, 9, 1, 1, Color("ffffff"))
	_rect(yu, 14, 9, 1, 1, Color("ffffff"))
	_rect(yu, 9, 8, 6, 1, Color("8c6c2a"))       # 挑眉
	_rect(yu, 10, 12, 4, 1, Color("b06a5a"))
	_rect(yu, 6, 12, 12, 10, Color("e8e4da"))
	_rect(yu, 6, 12, 12, 2, Color("c8b04a"))     # 金领
	_rect(yu, 11, 14, 2, 8, Color("b8a840"))
	_rect(yu, 7, 20, 10, 1, Color("c2b8a8"))     # 腰线
	_rect(yu, 4, 13, 2, 7, Color("d8d4ca"))
	_rect(yu, 18, 13, 2, 7, Color("d8d4ca"))
	_rect(yu, 8, 22, 3, 7, Color("4a4a58"))
	_rect(yu, 13, 22, 3, 7, Color("40404c"))
	_rect(yu, 7, 29, 4, 2, Color("2c2c34"))
	_rect(yu, 13, 29, 3, 2, Color("2c2c34"))
	_save(yu, "char_yuang.png")

	# 杂货商老周：短发胡子 + 褐衫围裙
	var zhou := _img(24, 32)
	_rect(zhou, 7, 2, 10, 5, Color("4a3524"))
	_rect(zhou, 7, 2, 8, 1, Color("5c4430"))
	_rect(zhou, 8, 7, 8, 5, Color("e8c39a"))
	_rect(zhou, 8, 7, 8, 1, Color("c8a480"))
	_rect(zhou, 9, 9, 2, 1, Color("303038"))
	_rect(zhou, 13, 9, 2, 1, Color("303038"))
	_rect(zhou, 8, 10, 8, 2, Color("6b5138"))    # 胡子
	_rect(zhou, 9, 13, 1, 1, Color("5c4430"))
	_rect(zhou, 6, 12, 12, 11, Color("7a5c38"))
	_rect(zhou, 6, 12, 12, 1, Color("8c6c44"))
	_rect(zhou, 10, 13, 4, 9, Color("c8b088"))
	_rect(zhou, 10, 13, 4, 1, Color("8a7350"))   # 围裙带
	_rect(zhou, 4, 13, 2, 7, Color("6b5030"))
	_rect(zhou, 18, 13, 2, 7, Color("6b5030"))
	_rect(zhou, 8, 23, 3, 6, Color("4a4a44"))
	_rect(zhou, 13, 23, 3, 6, Color("42423c"))
	_rect(zhou, 7, 29, 4, 2, Color("2c2c28"))
	_rect(zhou, 13, 29, 3, 2, Color("2c2c28"))
	_save(zhou, "char_merchant.png")

	# 学生：短发校服
	var stu := _img(24, 32)
	_rect(stu, 7, 2, 10, 5, Color("2a2a35"))
	_rect(stu, 8, 2, 7, 1, Color("3d3d4d"))
	_rect(stu, 8, 7, 8, 5, Color("e8c39a"))
	_rect(stu, 8, 7, 8, 1, Color("d4a884"))
	_rect(stu, 9, 9, 2, 2, Color("e8e8f0"))
	_rect(stu, 10, 9, 1, 2, Color("303038"))
	_rect(stu, 13, 9, 2, 2, Color("e8e8f0"))
	_rect(stu, 14, 9, 1, 2, Color("303038"))
	_rect(stu, 10, 9, 1, 1, Color("ffffff"))
	_rect(stu, 14, 9, 1, 1, Color("ffffff"))
	_rect(stu, 10, 12, 4, 1, Color("c9946a"))
	_rect(stu, 6, 12, 12, 10, Color("4a5c7c"))
	_rect(stu, 6, 12, 12, 2, Color("38486a"))
	_rect(stu, 11, 14, 2, 8, Color("3c4c6c"))
	_rect(stu, 4, 13, 2, 7, Color("41516f"))
	_rect(stu, 18, 13, 2, 7, Color("41516f"))
	_rect(stu, 8, 22, 3, 7, Color("3a3a44"))
	_rect(stu, 13, 22, 3, 7, Color("34343e"))
	_rect(stu, 7, 29, 4, 2, Color("1d1d24"))
	_rect(stu, 13, 29, 3, 2, Color("1d1d24"))
	_save(stu, "char_student.png")


## 48x72 战斗立绘（3x 缩放到 144x216）。半身像：面向战场中央，
## 发丝/衣甲双色分层 + 元素点缀，出招时在画面两侧切换。
func _portraits() -> void:
	_portrait_mo_fan()
	_portrait_mu_ningxue()
	_portrait_yu_ang()
	_portrait_wolf_king()


## 莫凡立绘：乱发少年握拳前倾，指节绕雷弧。
func _portrait_mo_fan() -> void:
	var p := _img(48, 72)
	# 雷弧背景点缀
	for bolt in [[8, 10], [40, 26], [10, 50]]:
		_bolt(p, [Vector2i(bolt[0], bolt[1]), Vector2i(bolt[0] + 3, bolt[1] + 4),
				Vector2i(bolt[0] + 1, bolt[1] + 8), Vector2i(bolt[0] + 4, bolt[1] + 12)],
				Color("8f9fd0"), Color("44508a"))
	# 后发层
	_rect(p, 14, 6, 22, 18, Color("23232e"))
	_rect(p, 12, 12, 3, 14, Color("23232e"))
	_rect(p, 35, 10, 4, 10, Color("23232e"))
	# 面部
	_rect(p, 16, 12, 18, 20, Color("e8c39a"))
	_rect(p, 16, 12, 18, 3, Color("c89a78"))       # 发影
	_rect(p, 15, 26, 20, 6, Color("e8c39a"))       # 下颌
	_rect(p, 17, 30, 16, 2, Color("d4a884"))       # 颌底影
	_rect(p, 14, 2, 24, 10, Color("2a2a35"))       # 乱发
	_rect(p, 11, 8, 5, 8, Color("2a2a35"))
	_rect(p, 34, 4, 6, 9, Color("2a2a35"))
	_rect(p, 16, 2, 16, 3, Color("3d3d4d"))        # 发高光
	_rect(p, 12, 10, 3, 3, Color("3d3d4d"))
	_rect(p, 36, 6, 3, 4, Color("3d3d4d"))
	_rect(p, 13, 0, 4, 4, Color("2a2a35"))         # 翘起的发梢
	_rect(p, 33, 0, 5, 5, Color("2a2a35"))
	_rect(p, 13, 8, 3, 12, Color("2a2a35"))        # 侧发连到下颌，头发不悬空
	_rect(p, 34, 8, 3, 10, Color("2a2a35"))
	# 眼（看向右）：眼白+瞳+高光+剑眉
	_rect(p, 19, 19, 5, 4, Color("e8e8f0"))
	_rect(p, 21, 19, 2, 4, Color("4a3a8a"))
	_rect(p, 21, 19, 2, 1, Color("ffffff"))
	_rect(p, 28, 19, 5, 4, Color("e8e8f0"))
	_rect(p, 30, 19, 2, 4, Color("4a3a8a"))
	_rect(p, 30, 19, 2, 1, Color("ffffff"))
	_rect(p, 18, 17, 7, 2, Color("2a2a35"))
	_rect(p, 27, 17, 7, 2, Color("2a2a35"))
	_rect(p, 22, 28, 6, 1, Color("c9946a"))        # 抿嘴
	# 高领 + 躯干
	_rect(p, 12, 36, 26, 6, Color("2c3a70"))
	_rect(p, 22, 34, 8, 4, Color("46569e"))
	_rect(p, 8, 42, 34, 30, Color("3b4a8c"))
	_rect(p, 8, 42, 34, 3, Color("4a5aa4"))        # 肩高光
	_rect(p, 23, 45, 4, 27, Color("324077"))       # 衣襟
	_rect(p, 12, 56, 26, 2, Color("2c3a70"))
	_rect(p, 10, 62, 30, 3, Color("2c3a70"))
	# 左臂垂 + 右臂握拳前摆，拳绕雷弧
	_rect(p, 6, 44, 6, 20, Color("324077"))
	_rect(p, 6, 62, 5, 5, Color("e8c39a"))
	_rect(p, 36, 44, 8, 14, Color("324077"))
	_rect(p, 36, 57, 8, 7, Color("e8c39a"))
	_rect(p, 37, 58, 2, 2, Color("d4a884"))
	_bolt(p, [Vector2i(40, 52), Vector2i(44, 55), Vector2i(41, 58), Vector2i(45, 61)],
			Color("c8f4ff"), Color("5a7fa0"))
	_save(p, "portrait_mo_fan.png")


## 穆宁雪立绘：银发飞扬的冰美人，指尖凝霜。
func _portrait_mu_ningxue() -> void:
	var p := _img(48, 72)
	# 冰晶点缀
	for c in [[7, 14], [41, 34], [9, 48]]:
		_rect(p, c[0], c[1], 1, 5, Color("a8d8f0"))
		_rect(p, c[0] - 2, c[1] + 2, 5, 1, Color("a8d8f0"))
	# 后发大层（银发飞扬）
	_rect(p, 10, 8, 28, 22, Color("b8c8dc"))
	_rect(p, 6, 16, 8, 34, Color("b8c8dc"))
	_rect(p, 34, 14, 9, 30, Color("b8c8dc"))
	_rect(p, 5, 44, 8, 6, Color("9cb4d0"))         # 发尾
	_rect(p, 35, 40, 9, 6, Color("9cb4d0"))
	_rect(p, 12, 8, 22, 4, Color("e8f0f8"))        # 发顶高光
	_rect(p, 6, 20, 3, 18, Color("dce8f4"))        # 发丝高光
	_rect(p, 39, 18, 3, 16, Color("dce8f4"))
	# 面部
	_rect(p, 16, 12, 17, 19, Color("f2dcc0"))
	_rect(p, 16, 12, 17, 3, Color("d0b8a0"))
	_rect(p, 15, 25, 19, 6, Color("f2dcc0"))
	_rect(p, 17, 29, 15, 2, Color("dcc0a8"))
	_rect(p, 14, 3, 22, 11, Color("cfd8e6"))       # 刘海
	_rect(p, 14, 3, 20, 3, Color("e8f0f8"))
	_rect(p, 16, 8, 5, 4, Color("cfd8e6"))         # 连成一片的碎刘海
	_rect(p, 22, 8, 4, 6, Color("cfd8e6"))
	_rect(p, 28, 8, 5, 4, Color("cfd8e6"))
	# 眼（清冷）：下垂眉 + 冰蓝瞳
	_rect(p, 19, 19, 5, 4, Color("e8e8f0"))
	_rect(p, 21, 19, 2, 4, Color("4a6d9c"))
	_rect(p, 21, 19, 2, 1, Color("ffffff"))
	_rect(p, 27, 19, 5, 4, Color("e8e8f0"))
	_rect(p, 29, 19, 2, 4, Color("4a6d9c"))
	_rect(p, 29, 19, 2, 1, Color("ffffff"))
	_rect(p, 18, 17, 7, 1, Color("8ca0b8"))
	_rect(p, 27, 17, 7, 1, Color("8ca0b8"))
	_rect(p, 22, 27, 5, 1, Color("c98c8c"))
	# 冰蓝长裙 + 白领
	_rect(p, 12, 34, 24, 5, Color("e8f0f8"))
	_rect(p, 10, 39, 28, 33, Color("9cc4e8"))
	_rect(p, 10, 39, 28, 3, Color("b0d4f0"))
	_rect(p, 22, 42, 4, 30, Color("84aed4"))
	_rect(p, 12, 54, 24, 2, Color("8ab4dc"))
	_rect(p, 8, 62, 32, 4, Color("7fa8cf"))
	_rect(p, 8, 66, 32, 2, Color("6d97be"))
	# 指尖凝霜
	_rect(p, 4, 50, 6, 4, Color("f2dcc0"))
	_rect(p, 3, 47, 3, 3, Color("d8f4ff"))
	_rect(p, 2, 45, 2, 2, Color("ffffff"))
	_rect(p, 38, 46, 6, 4, Color("f2dcc0"))
	_rect(p, 42, 43, 3, 3, Color("d8f4ff"))
	_save(p, "portrait_mu_ningxue.png")


## 宇昂立绘：金发白衣的骄子，指间燃火。
func _portrait_yu_ang() -> void:
	var p := _img(48, 72)
	# 火焰点缀
	for f in [[8, 30], [40, 12]]:
		_rect(p, f[0], f[1], 2, 6, Color("ff9d3c"))
		_rect(p, f[0] + 1, f[1] - 3, 2, 4, Color("ffd166"))
	# 后发
	_rect(p, 13, 5, 24, 16, Color("c8a038"))
	_rect(p, 11, 10, 4, 10, Color("c8a038"))
	_rect(p, 35, 8, 5, 8, Color("c8a038"))
	# 面部（下巴微扬，视角略低）
	_rect(p, 16, 11, 18, 21, Color("eec9a0"))
	_rect(p, 16, 11, 18, 3, Color("c8a480"))
	_rect(p, 15, 26, 20, 6, Color("eec9a0"))
	_rect(p, 17, 30, 16, 2, Color("d4a884"))
	_rect(p, 14, 1, 23, 10, Color("d8b44a"))       # 后梳金发
	_rect(p, 14, 1, 19, 3, Color("eacc6e"))
	_rect(p, 12, 4, 4, 5, Color("c8a038"))
	_rect(p, 35, 2, 5, 6, Color("c8a038"))
	# 眼（骄矜）：挑眉 + 窄瞳
	_rect(p, 19, 18, 5, 4, Color("e8e8f0"))
	_rect(p, 21, 18, 2, 4, Color("3c4c8c"))
	_rect(p, 21, 18, 2, 1, Color("ffffff"))
	_rect(p, 28, 18, 5, 4, Color("e8e8f0"))
	_rect(p, 30, 18, 2, 4, Color("3c4c8c"))
	_rect(p, 30, 18, 2, 1, Color("ffffff"))
	_rect(p, 18, 15, 7, 2, Color("8c6c2a"))
	_rect(p, 27, 15, 7, 2, Color("8c6c2a"))
	_rect(p, 22, 27, 6, 1, Color("b06a5a"))
	_rect(p, 27, 28, 3, 1, Color("a05a4a"))        # 上扬的嘴角
	# 白金华服
	_rect(p, 12, 36, 26, 6, Color("c8b04a"))
	_rect(p, 22, 34, 8, 4, Color("d8c46a"))
	_rect(p, 8, 42, 34, 30, Color("e8e4da"))
	_rect(p, 8, 42, 34, 3, Color("f4f0e8"))
	_rect(p, 23, 45, 4, 27, Color("b8a840"))
	_rect(p, 12, 56, 26, 2, Color("c2b8a8"))
	_rect(p, 10, 62, 30, 3, Color("c2b8a8"))
	# 左手垂，右手燃火
	_rect(p, 6, 44, 6, 20, Color("d8d4ca"))
	_rect(p, 6, 62, 5, 5, Color("eec9a0"))
	_rect(p, 36, 44, 8, 14, Color("d8d4ca"))
	_rect(p, 36, 57, 8, 6, Color("eec9a0"))
	_rect(p, 37, 50, 6, 8, Color("ff9d3c"))
	_rect(p, 38, 47, 4, 4, Color("ffd166"))
	_rect(p, 39, 44, 2, 3, Color("fff2c8"))
	_save(p, "portrait_yu_ang.png")


## 狼王立绘：兽首特写，独眼青光、弯角獠牙、赤纹蔓延。
func _portrait_wolf_king() -> void:
	var p := _img(48, 72)
	# 雷弧背景
	for bolt in [[6, 8], [42, 20], [8, 44]]:
		_bolt(p, [Vector2i(bolt[0], bolt[1]), Vector2i(bolt[0] + 3, bolt[1] + 5),
				Vector2i(bolt[0] + 1, bolt[1] + 10)],
				Color("8fd8f0"), Color("3a6a80"))
	# 头部大轮廓（前倾压向左）
	_rect(p, 10, 14, 32, 34, Color("2a2d3c"))
	_rect(p, 6, 22, 8, 22, Color("272a38"))        # 颊侧鬃毛
	_rect(p, 36, 20, 8, 24, Color("272a38"))
	_rect(p, 12, 12, 26, 4, Color("3a3f52"))       # 头顶高光
	# 双弯角
	_rect(p, 14, 4, 6, 10, Color("e0d8c8"))
	_rect(p, 10, 0, 6, 6, Color("e0d8c8"))
	_rect(p, 7, 0, 4, 3, Color("d0c6ae"))
	_rect(p, 30, 2, 6, 10, Color("e0d8c8"))
	_rect(p, 36, 0, 6, 6, Color("e0d8c8"))
	_rect(p, 41, 0, 4, 3, Color("d0c6ae"))
	# 独眼（青光竖瞳）
	_rect(p, 14, 24, 12, 9, Color("0e2836"))
	_rect(p, 15, 25, 10, 7, Color("4a9cc0"))
	_rect(p, 16, 26, 8, 5, Color("8fe4fa"))
	_rect(p, 17, 27, 5, 3, Color("d2f6ff"))
	_rect(p, 18, 27, 2, 2, Color("ffffff"))
	_rect(p, 21, 25, 2, 7, Color("0e2836"))        # 竖瞳
	# 吻部与裂口獠牙
	_rect(p, 8, 40, 32, 14, Color("2e3142"))
	_rect(p, 8, 40, 32, 3, Color("3c4254"))
	_rect(p, 6, 50, 36, 12, Color("1a0a12"))       # 口腔
	_rect(p, 10, 54, 28, 6, Color("0d040a"))
	for i in 5:                                      # 上獠牙
		var fx := 9 + i * 7
		_rect(p, fx, 50, 3, 6, Color("e8e2d2"))
		_rect(p, fx, 56, 2, 3, Color("d0c6ae"))
	_rect(p, 12, 66, 4, 4, Color("e8e2d2"))        # 下獠牙
	_rect(p, 30, 66, 4, 4, Color("e8e2d2"))
	_rect(p, 44, 24, 2, 2, Color("ff4040"))        # 第二眼的疤痕暗红
	_rect(p, 43, 23, 4, 1, Color("6a2020"))
	# 异变赤纹
	_rect(p, 20, 12, 10, 2, Color("8c2020"))
	_rect(p, 24, 14, 6, 1, Color("b03030"))
	_rect(p, 38, 32, 6, 2, Color("8c2020"))
	_rect(p, 8, 34, 6, 1, Color("8c2020"))
	_save(p, "portrait_wolf_king.png")


## 一段折线雷弧（1px 主干 + 微光晕），妖魔雷系技能的形体暗示。
func _bolt(img: Image, points: Array, bright: Color, dim: Color) -> void:
	for p in points:
		var x: int = p.x
		var y: int = p.y
		img.set_pixel(x, y, bright)
		for off in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nx: int = x + off.x
			var ny: int = y + off.y
			if nx < img.get_width() and ny < img.get_height():
				if img.get_pixel(nx, ny).a == 0.0:
					img.set_pixel(nx, ny, dim)


## 妖魔占位。造型语言：压低的巨颅、发光的眼、外露的獠牙、背脊骨刺——
## 占位美术也要演出 docs/world.md 的「等级压制感」，体积阶梯 奴仆<战将<统领。
## 【长期约定，design.md 已定案】新增妖兽一律按此语言往凶狠画：
## 先问"它哪里让人害怕"，答不上来就重画。
func _monsters() -> void:
	_monster_rat_swarm()
	_monster_wolf()
	_monster_wolf_king()


## 鼠潮 72x46：主鼠压头弓背、双长板牙，背上与尾下各探出一只鼠——
## 三点猩红眼位拉开纵深，读成涌来的鼠群而非一只肥鼠。
func _monster_rat_swarm() -> void:
	var img := _img(72, 46)
	# —— 主鼠（主体：弓背，额高头低，橙色长板牙）——
	_rect(img, 26, 14, 26, 22, Color("554c5a"))      # 躯干
	_rect(img, 40, 10, 14, 8, Color("554c5a"))       # 肩峰
	_rect(img, 28, 14, 22, 2, Color("615666"))       # 背高光
	_rect(img, 40, 10, 12, 2, Color("615666"))
	_rect(img, 20, 24, 12, 12, Color("4a4250"))      # 后臀
	_rect(img, 50, 12, 14, 16, Color("5d5462"))      # 颅
	_rect(img, 52, 9, 8, 4, Color("5d5462"))         # 隆起的额
	_rect(img, 62, 16, 9, 8, Color("554c5a"))        # 下压的吻
	_rect(img, 69, 20, 2, 2, Color("8a5060"))        # 鼻
	_rect(img, 56, 14, 6, 2, Color("241f2b"))        # 眉骨投下阴影
	_rect(img, 55, 15, 4, 4, Color("701d1d"))        # 眼晕
	_rect(img, 56, 16, 2, 2, Color("ff4a4a"))        # 猩红眼
	img.set_pixel(56, 16, Color("ff9a8a"))
	_rect(img, 60, 22, 10, 3, Color("1a1016"))       # 裂口
	_rect(img, 61, 22, 2, 6, Color("e8b84a"))        # 左板牙
	_rect(img, 61, 26, 1, 2, Color("d8a030"))
	_rect(img, 65, 22, 2, 6, Color("e8b84a"))        # 右板牙
	_rect(img, 65, 26, 1, 2, Color("d8a030"))
	_rect(img, 56, 24, 12, 6, Color("4a4250"))       # 下颚
	_rect(img, 70, 21, 2, 1, Color("8a8290"))        # 触须
	_rect(img, 71, 24, 1, 1, Color("8a8290"))
	_rect(img, 70, 27, 2, 1, Color("8a8290"))
	# 背脊硬毛（随弓形起伏，额前最长）
	for sp in [[30, 10, 4], [35, 8, 6], [41, 6, 5], [46, 6, 5], [50, 5, 5]]:
		_rect(img, sp[0], sp[1], 2, sp[2], Color("241f2b"))
	# 前爪扬起 + 长爪，后腿蹲踞
	_rect(img, 46, 28, 8, 5, Color("4a4250"))
	_rect(img, 52, 31, 7, 4, Color("554c5a"))
	_rect(img, 58, 31, 2, 1, Color("c8bfae"))
	_rect(img, 59, 33, 2, 1, Color("c8bfae"))
	_rect(img, 57, 35, 2, 1, Color("c8bfae"))
	_rect(img, 22, 34, 6, 7, Color("4a4250"))
	_rect(img, 18, 40, 10, 3, Color("3a3442"))
	_rect(img, 16, 40, 3, 2, Color("c8bfae"))
	_rect(img, 28, 30, 22, 6, Color("3f3846"))       # 腹部阴影
	# 溃烂斑块 + 旧伤（疫病感）
	_rect(img, 32, 20, 5, 3, Color("5c6b3f"))
	_rect(img, 40, 24, 4, 2, Color("4c5a35"))
	_rect(img, 44, 15, 3, 1, Color("8c3030"))
	# 裸尾：贴地左扫，尾尖上挑
	_rect(img, 12, 26, 10, 3, Color("8a7080"))
	_rect(img, 5, 29, 8, 3, Color("8a7080"))
	_rect(img, 9, 29, 2, 1, Color("6f5a68"))
	_rect(img, 14, 26, 2, 1, Color("6f5a68"))
	_rect(img, 2, 22, 4, 8, Color("6f5a68"))
	# —— 鼠群纵深：背上探出头的一只 ——
	_rect(img, 34, 3, 12, 8, Color("241f2b"))
	_rect(img, 44, 5, 4, 4, Color("241f2b"))
	_rect(img, 38, 0, 2, 3, Color("241f2b"))
	_rect(img, 41, 4, 3, 3, Color("701d1d"))
	img.set_pixel(42, 5, Color("ff4040"))
	_rect(img, 40, 10, 2, 2, Color("241f2b"))        # 前爪扒住肩峰
	_rect(img, 44, 10, 2, 2, Color("241f2b"))
	# —— 鼠群纵深：尾下露头的一只 ——
	_rect(img, 8, 32, 10, 8, Color("241f2b"))
	_rect(img, 10, 29, 2, 3, Color("241f2b"))
	_rect(img, 16, 34, 4, 3, Color("241f2b"))
	_rect(img, 11, 34, 3, 3, Color("701d1d"))
	img.set_pixel(12, 35, Color("ff4040"))
	_save(img, "monster_rat.png")


## 独眼魔狼 112x72（战将级）：耸肩弓背、独眼青光、裂口獠牙、背脊骨刺、雷弧缠身。
func _monster_wolf() -> void:
	var img := _img(112, 72)
	# —— 躯干：耸肩弓背，前重后轻 ——
	_rect(img, 14, 22, 62, 34, Color("2e3140"))
	_rect(img, 44, 14, 30, 12, Color("2e3140"))      # 肩峰
	_rect(img, 46, 14, 26, 2, Color("3c4152"))
	_rect(img, 62, 30, 20, 26, Color("333748"))      # 深胸
	_rect(img, 14, 24, 22, 30, Color("282b38"))      # 后臀
	_rect(img, 18, 46, 54, 10, Color("232633"))      # 腹部阴影
	# —— 背脊骨刺（锁边高光）——
	for sp in [[28, 17, 3, 7], [38, 12, 3, 7], [48, 8, 4, 7], [58, 7, 4, 7], [68, 8, 3, 7]]:
		_rect(img, sp[0], sp[1], sp[2], sp[3], Color("1b1e29"))
		_rect(img, sp[0], sp[1], 1, sp[3], Color("565e74"))
	# —— 残破尾 ——
	_rect(img, 8, 25, 8, 6, Color("262936"))
	_rect(img, 3, 28, 6, 4, Color("222534"))
	_rect(img, 1, 31, 3, 3, Color("1b1e29"))
	# —— 耳（后压=威吓）——
	_rect(img, 74, 5, 5, 8, Color("2a2e3c"))
	_rect(img, 75, 7, 2, 4, Color("161824"))
	_rect(img, 80, 4, 4, 9, Color("2a2e3c"))
	_rect(img, 81, 6, 2, 5, Color("161824"))
	# —— 巨颅压低，眉骨投下阴影 ——
	_rect(img, 72, 12, 26, 20, Color("333748"))
	_rect(img, 72, 12, 26, 3, Color("3f4456"))
	_rect(img, 82, 16, 15, 3, Color("1b1e29"))
	# 独眼：青白光芒 + 竖瞳
	_rect(img, 84, 19, 7, 6, Color("3e8ca8"))
	_rect(img, 85, 20, 5, 4, Color("7fd8f0"))
	_rect(img, 86, 21, 3, 2, Color("c8f4ff"))
	img.set_pixel(86, 21, Color("ffffff"))
	_rect(img, 88, 20, 1, 4, Color("12303c"))
	# —— 裂口獠牙 ——
	_rect(img, 94, 20, 12, 9, Color("2e3140"))
	_rect(img, 94, 20, 12, 2, Color("3a3f50"))
	_rect(img, 104, 22, 3, 3, Color("12141c"))       # 鼻
	_rect(img, 94, 28, 15, 3, Color("2a2e3c"))       # 上颚
	_rect(img, 94, 30, 15, 10, Color("160a12"))      # 口腔
	_rect(img, 97, 33, 8, 6, Color("0d050a"))        # 喉腔
	for f in [[96, 31, 2, 5], [100, 31, 2, 6], [104, 31, 2, 5], [107, 31, 2, 4]]:
		_rect(img, f[0], f[1], f[2], f[3], Color("e6e0d0"))  # 上獠牙
	_rect(img, 92, 40, 16, 5, Color("262a38"))       # 下颚
	_rect(img, 92, 40, 16, 1, Color("31354a"))
	_rect(img, 96, 38, 2, 3, Color("e6e0d0"))        # 下獠牙
	_rect(img, 101, 38, 2, 3, Color("e6e0d0"))
	_rect(img, 92, 44, 14, 2, Color("1e2130"))
	# —— 四肢：前爪扬起扑击 ——
	_rect(img, 14, 52, 8, 14, Color("282b38"))
	_rect(img, 12, 64, 11, 4, Color("232633"))
	_rect(img, 9, 64, 4, 2, Color("ccc4b4"))
	_rect(img, 28, 54, 7, 12, Color("282b38"))
	_rect(img, 26, 64, 10, 4, Color("232633"))
	_rect(img, 24, 64, 3, 2, Color("ccc4b4"))
	_rect(img, 50, 54, 7, 12, Color("2a2d3c"))
	_rect(img, 48, 64, 10, 4, Color("232633"))
	_rect(img, 46, 64, 3, 2, Color("ccc4b4"))
	_rect(img, 64, 38, 12, 12, Color("2e3140"))
	_rect(img, 70, 46, 10, 8, Color("2a2d3c"))
	_rect(img, 76, 50, 10, 6, Color("333748"))
	_rect(img, 84, 49, 4, 2, Color("ccc4b4"))
	_rect(img, 85, 53, 5, 2, Color("ccc4b4"))
	_rect(img, 83, 56, 4, 2, Color("ccc4b4"))
	# 旧伤（暗红）
	_rect(img, 34, 32, 6, 1, Color("6a2020"))
	_rect(img, 36, 34, 4, 1, Color("551a1a"))
	# 雷弧：背刺与尾上炸裂（雷系形骸化）
	_bolt(img, [Vector2i(57, 5), Vector2i(61, 9), Vector2i(59, 13), Vector2i(62, 16)],
			Color("b8f0ff"), Color("4a7f96"))
	_bolt(img, [Vector2i(5, 18), Vector2i(9, 22), Vector2i(7, 25)],
			Color("b8f0ff"), Color("4a7f96"))
	_save(img, "monster_wolf.png")


## 独眼魔狼王 132x86（统领级）：在魔狼骨架上加弯角、更长骨刺、
## 赤红异变纹（黑教廷伏笔的形体暗示），雷弧更盛——体积与凶相全面压过战将级。
func _monster_wolf_king() -> void:
	var img := _img(132, 86)
	# —— 躯干（更大更低伏）——
	_rect(img, 16, 26, 76, 40, Color("2a2d3c"))
	_rect(img, 50, 18, 34, 14, Color("2a2d3c"))      # 肩峰
	_rect(img, 52, 17, 30, 2, Color("424859"))
	_rect(img, 74, 34, 24, 30, Color("2e3142"))      # 深胸
	_rect(img, 16, 28, 26, 34, Color("272a38"))      # 后臀
	_rect(img, 20, 56, 66, 12, Color("20232f"))      # 腹部阴影
	# —— 背脊骨刺（比战将级更长）——
	for sp in [[30, 20, 4, 8], [40, 15, 4, 8], [52, 10, 5, 9], [64, 8, 5, 9], [76, 10, 4, 8]]:
		_rect(img, sp[0], sp[1], sp[2], sp[3], Color("181b26"))
		_rect(img, sp[0], sp[1], 1, sp[3], Color("565e74"))
	# —— 残破尾 ——
	_rect(img, 10, 32, 10, 6, Color("222534"))
	_rect(img, 4, 35, 7, 5, Color("1e212e"))
	_rect(img, 2, 39, 4, 4, Color("181b26"))
	# —— 耳（后压）与双弯角（骨白）——
	_rect(img, 88, 9, 5, 9, Color("2a2e3e"))
	_rect(img, 89, 11, 2, 5, Color("141722"))
	_rect(img, 96, 7, 5, 11, Color("2a2e3e"))
	_rect(img, 97, 9, 2, 6, Color("141722"))
	_rect(img, 92, 4, 6, 6, Color("e0d8c8"))         # 后掠角
	_rect(img, 87, 1, 6, 5, Color("e0d8c8"))
	_rect(img, 82, 0, 6, 3, Color("d0c6ae"))
	_rect(img, 92, 8, 6, 2, Color("b8ae96"))
	_rect(img, 102, 3, 6, 6, Color("e0d8c8"))        # 前掠角
	_rect(img, 108, 0, 6, 4, Color("d0c6ae"))
	_rect(img, 113, 0, 5, 3, Color("d0c6ae"))
	_rect(img, 102, 7, 6, 2, Color("b8ae96"))
	# —— 巨颅压低，眉骨阴影更深 ——
	_rect(img, 88, 16, 30, 24, Color("303446"))
	_rect(img, 88, 16, 30, 3, Color("3c4254"))
	_rect(img, 100, 20, 18, 4, Color("181b26"))
	# 独眼：更亮更凶（白核 + 青环 + 竖瞳）
	_rect(img, 102, 24, 10, 8, Color("4a9cc0"))
	_rect(img, 103, 25, 8, 6, Color("8fe4fa"))
	_rect(img, 104, 26, 6, 4, Color("d2f6ff"))
	_rect(img, 104, 26, 2, 2, Color("ffffff"))
	_rect(img, 107, 25, 2, 6, Color("0e2836"))
	# —— 裂口獠牙（更宽口，齿更长）——
	_rect(img, 114, 26, 12, 10, Color("2a2d3c"))
	_rect(img, 114, 26, 12, 2, Color("363b4c"))
	_rect(img, 124, 28, 4, 4, Color("10121a"))       # 鼻
	_rect(img, 114, 33, 17, 4, Color("2c3040"))      # 上颚
	_rect(img, 114, 36, 17, 12, Color("1a0a12"))     # 口腔
	_rect(img, 117, 39, 9, 7, Color("0d040a"))       # 喉腔
	for f in [[115, 36, 3, 7], [120, 36, 3, 8], [125, 36, 3, 6], [129, 36, 2, 5]]:
		_rect(img, f[0], f[1], f[2], f[3], Color("e8e2d2"))  # 上獠牙
	_rect(img, 112, 47, 18, 6, Color("262a38"))      # 下颚
	_rect(img, 112, 47, 18, 1, Color("31354a"))
	_rect(img, 117, 44, 3, 4, Color("e8e2d2"))       # 下獠牙
	_rect(img, 123, 44, 3, 4, Color("e8e2d2"))
	_rect(img, 112, 52, 16, 3, Color("1c1f2c"))
	# —— 四肢（爪更长）——
	_rect(img, 18, 62, 10, 18, Color("272a38"))
	_rect(img, 16, 78, 13, 5, Color("20232f"))
	_rect(img, 13, 78, 4, 3, Color("d0c8b8"))
	_rect(img, 34, 64, 9, 16, Color("272a38"))
	_rect(img, 32, 78, 12, 5, Color("20232f"))
	_rect(img, 30, 78, 4, 2, Color("d0c8b8"))
	_rect(img, 62, 64, 9, 16, Color("2a2d3c"))
	_rect(img, 60, 78, 12, 5, Color("20232f"))
	_rect(img, 58, 78, 4, 2, Color("d0c8b8"))
	_rect(img, 82, 46, 14, 14, Color("2a2d3c"))
	_rect(img, 88, 56, 12, 10, Color("272a38"))
	_rect(img, 96, 62, 12, 7, Color("2e3142"))
	_rect(img, 106, 61, 5, 3, Color("d0c8b8"))
	_rect(img, 107, 65, 6, 2, Color("d0c8b8"))
	_rect(img, 104, 68, 5, 2, Color("d0c8b8"))
	# —— 异变赤纹（黑教廷伏笔）：背、肩、颈的绯红裂纹 ——
	_rect(img, 56, 26, 12, 2, Color("4a1414"))
	_rect(img, 56, 24, 12, 2, Color("8c2020"))
	_rect(img, 60, 27, 7, 1, Color("b03030"))
	_rect(img, 32, 30, 10, 1, Color("8c2020"))
	_rect(img, 36, 32, 6, 1, Color("b03030"))
	_rect(img, 32, 32, 8, 2, Color("4a1414"))
	_rect(img, 84, 20, 8, 2, Color("8c2020"))
	_rect(img, 20, 40, 8, 1, Color("8c2020"))
	_rect(img, 24, 43, 5, 1, Color("6a1818"))
	# 雷弧更盛：角尖、背刺、尾上三道
	_bolt(img, [Vector2i(116, 4), Vector2i(119, 8), Vector2i(117, 12), Vector2i(121, 16)],
			Color("c8f4ff"), Color("4a8ca8"))
	_bolt(img, [Vector2i(66, 6), Vector2i(70, 10), Vector2i(68, 14), Vector2i(71, 18)],
			Color("b8f0ff"), Color("4a8ca8"))
	_bolt(img, [Vector2i(4, 26), Vector2i(8, 30), Vector2i(6, 34)],
			Color("b8f0ff"), Color("4a8ca8"))
	_save(img, "monster_wolf_king.png")


## 战斗背景 640x360（暗色林地雾气）。
func _battle_bg() -> void:
	var img := _img(640, 360)
	var top := Color("1c2a24")
	var bottom := Color("0d1410")
	for y in 360:
		var t := float(y) / 360.0
		_rect(img, 0, y, 640, 1, top.lerp(bottom, t))
	_rect(img, 0, 130, 640, 90, Color(0.20, 0.28, 0.24, 0.35))  # 雾带
	_rect(img, 0, 280, 640, 80, Color("0a0f0b"))                # 前景地面
	for i in 12:
		var x := rng.randi_range(10, 600)
		_rect(img, x, rng.randi_range(40, 120), rng.randi_range(20, 60), 3, Color(0.10, 0.16, 0.12, 0.8))
	_save(img, "battle_bg_proto.png")


## 篝火 16x16。
func _campfire() -> void:
	var img := _img(16, 16)
	_rect(img, 2, 12, 12, 3, Color("6b4a2f"))  # 木柴
	_rect(img, 5, 5, 6, 8, Color("ff9d3c"))    # 焰
	_rect(img, 6, 7, 4, 5, Color("ffd166"))    # 焰心
	_rect(img, 7, 2, 2, 4, Color("ff9d3c"))
	_save(img, "campfire.png")
