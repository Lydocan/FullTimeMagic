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


## 24x32 人物占位（莫凡 / 穆宁雪）。
func _characters() -> void:
	var fan := _img(24, 32)
	_rect(fan, 7, 2, 10, 6, Color("2a2a35"))   # 头发
	_rect(fan, 8, 7, 8, 5, Color("e8c39a"))    # 脸
	_rect(fan, 9, 8, 2, 1, Color("303038"))    # 眼
	_rect(fan, 13, 8, 2, 1, Color("303038"))
	_rect(fan, 6, 12, 12, 10, Color("3b4a8c")) # 上衣
	_rect(fan, 4, 13, 2, 7, Color("324077"))   # 左臂
	_rect(fan, 18, 13, 2, 7, Color("324077"))
	_rect(fan, 8, 22, 3, 7, Color("2c2c34"))   # 腿
	_rect(fan, 13, 22, 3, 7, Color("2c2c34"))
	_rect(fan, 8, 29, 3, 2, Color("1d1d24"))   # 鞋
	_rect(fan, 13, 29, 3, 2, Color("1d1d24"))
	_save(fan, "char_mofan.png")

	var xue := _img(24, 32)
	_rect(xue, 5, 2, 14, 10, Color("cfd8e6"))  # 银白长发
	_rect(xue, 8, 7, 8, 5, Color("f2dcc0"))    # 脸
	_rect(xue, 9, 8, 2, 1, Color("4a6d9c"))    # 眼
	_rect(xue, 13, 8, 2, 1, Color("4a6d9c"))
	_rect(xue, 6, 12, 12, 12, Color("9cc4e8")) # 冰蓝裙
	_rect(xue, 7, 24, 3, 6, Color("7fa8cf"))   # 裙摆
	_rect(xue, 14, 24, 3, 6, Color("7fa8cf"))
	_rect(xue, 8, 29, 3, 2, Color("5d84ad"))
	_rect(xue, 13, 29, 3, 2, Color("5d84ad"))
	_save(xue, "char_muningxue.png")

	var tang := _img(24, 32)
	_rect(tang, 5, 1, 14, 12, Color("1f1f28"))  # 黑长发
	_rect(tang, 8, 7, 8, 5, Color("eec9a0"))    # 脸
	_rect(tang, 9, 8, 2, 1, Color("a03030"))    # 眼
	_rect(tang, 13, 8, 2, 1, Color("a03030"))
	_rect(tang, 5, 12, 3, 12, Color("1f1f28"))  # 发披肩
	_rect(tang, 16, 12, 3, 12, Color("1f1f28"))
	_rect(tang, 6, 12, 12, 11, Color("b03434")) # 火红外套
	_rect(tang, 11, 12, 2, 11, Color("8c2626")) # 衣襟
	_rect(tang, 4, 13, 2, 7, Color("9c2c2c"))   # 臂
	_rect(tang, 18, 13, 2, 7, Color("9c2c2c"))
	_rect(tang, 8, 23, 3, 6, Color("2c2c34"))   # 腿
	_rect(tang, 13, 23, 3, 6, Color("2c2c34"))
	_rect(tang, 8, 29, 3, 2, Color("1d1d24"))   # 鞋
	_rect(tang, 13, 29, 3, 2, Color("1d1d24"))
	_save(tang, "char_tangyue.png")

	var yu := _img(24, 32)
	_rect(yu, 6, 2, 12, 6, Color("d8b44a"))    # 金发
	_rect(yu, 8, 7, 8, 5, Color("eec9a0"))     # 脸
	_rect(yu, 9, 8, 2, 1, Color("3c4c8c"))     # 眼
	_rect(yu, 13, 8, 2, 1, Color("3c4c8c"))
	_rect(yu, 6, 12, 12, 10, Color("e8e4da"))  # 白华服
	_rect(yu, 6, 12, 12, 2, Color("c8b04a"))   # 金镶边
	_rect(yu, 11, 14, 2, 8, Color("b8a840"))   # 衣襟
	_rect(yu, 4, 13, 2, 7, Color("d8d4ca"))    # 臂
	_rect(yu, 18, 13, 2, 7, Color("d8d4ca"))
	_rect(yu, 8, 22, 3, 7, Color("4a4a58"))    # 腿
	_rect(yu, 13, 22, 3, 7, Color("4a4a58"))
	_rect(yu, 8, 29, 3, 2, Color("2c2c34"))    # 鞋
	_rect(yu, 13, 29, 3, 2, Color("2c2c34"))
	_save(yu, "char_yuang.png")

	var zhou := _img(24, 32)
	_rect(zhou, 7, 2, 10, 5, Color("4a3524"))  # 短发
	_rect(zhou, 8, 7, 8, 5, Color("e8c39a"))   # 脸
	_rect(zhou, 9, 8, 2, 1, Color("303038"))   # 眼
	_rect(zhou, 13, 8, 2, 1, Color("303038"))
	_rect(zhou, 8, 10, 8, 2, Color("6b5138"))  # 胡子
	_rect(zhou, 6, 12, 12, 11, Color("7a5c38")) # 褐布衫
	_rect(zhou, 10, 13, 4, 9, Color("c8b088")) # 围裙
	_rect(zhou, 4, 13, 2, 7, Color("6b5030"))  # 臂
	_rect(zhou, 18, 13, 2, 7, Color("6b5030"))
	_rect(zhou, 8, 23, 3, 6, Color("4a4a44"))  # 腿
	_rect(zhou, 13, 23, 3, 6, Color("4a4a44"))
	_rect(zhou, 8, 29, 3, 2, Color("2c2c28"))  # 鞋
	_rect(zhou, 13, 29, 3, 2, Color("2c2c28"))
	_save(zhou, "char_merchant.png")

	var stu := _img(24, 32)
	_rect(stu, 7, 2, 10, 5, Color("2a2a35"))   # 学生短发
	_rect(stu, 8, 7, 8, 5, Color("e8c39a"))    # 脸
	_rect(stu, 9, 8, 2, 1, Color("303038"))    # 眼
	_rect(stu, 13, 8, 2, 1, Color("303038"))
	_rect(stu, 6, 12, 12, 10, Color("4a5c7c")) # 校服
	_rect(stu, 6, 12, 12, 2, Color("38486a"))  # 领口
	_rect(stu, 4, 13, 2, 7, Color("41516f"))   # 臂
	_rect(stu, 18, 13, 2, 7, Color("41516f"))
	_rect(stu, 8, 22, 3, 7, Color("3a3a44"))   # 腿
	_rect(stu, 13, 22, 3, 7, Color("3a3a44"))
	_rect(stu, 8, 29, 3, 2, Color("1d1d24"))   # 鞋
	_rect(stu, 13, 29, 3, 2, Color("1d1d24"))
	_save(stu, "char_student.png")


## 妖魔占位。
func _monsters() -> void:
	var rat := _img(36, 24)
	_rect(rat, 6, 8, 22, 11, Color("8d8d94"))  # 身体
	_rect(rat, 24, 6, 8, 7, Color("8d8d94"))   # 头
	_rect(rat, 25, 3, 3, 4, Color("7c7c83"))   # 耳
	_rect(rat, 30, 9, 2, 2, Color("d03a3a"))   # 红眼
	_rect(rat, 2, 12, 5, 2, Color("6f6f76"))   # 尾
	_rect(rat, 8, 19, 3, 4, Color("7c7c83"))   # 腿
	_rect(rat, 20, 19, 3, 4, Color("7c7c83"))
	_save(rat, "monster_rat.png")

	var wolf := _img(56, 36)
	_rect(wolf, 8, 12, 34, 14, Color("3a3a44"))  # 躯干
	_rect(wolf, 38, 10, 14, 10, Color("444450")) # 头
	_rect(wolf, 46, 6, 4, 5, Color("444450"))    # 耳
	_rect(wolf, 48, 13, 5, 4, Color("e03434"))   # 独眼
	_rect(wolf, 52, 16, 4, 3, Color("2c2c34"))   # 前颚
	_rect(wolf, 2, 14, 7, 4, Color("32323c"))    # 尾
	_rect(wolf, 11, 26, 4, 9, Color("2c2c34"))   # 腿
	_rect(wolf, 19, 26, 4, 9, Color("2c2c34"))
	_rect(wolf, 32, 26, 4, 9, Color("2c2c34"))
	_rect(wolf, 38, 26, 4, 9, Color("2c2c34"))
	_rect(wolf, 12, 15, 26, 2, Color("4c4c58"))  # 背脊
	_save(wolf, "monster_wolf.png")


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
