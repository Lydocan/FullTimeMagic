extends SceneTree
## 生成原型占位音频 WAV（程序化合成 chiptune，正式音频就位后整体替换）。
##
## 运行：godot --headless --path . --script res://tools/gen_placeholder_audio.gd
## 产物：assets/audio/ 下 4 首 BGM 循环 + 14 个音效。BGM 循环点由
## Audio.play_bgm 在运行时设置（AudioStreamWAV.LOOP_FORWARD 全长循环）。

const DIR := "res://assets/audio/"
const RATE := 22050

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 20260831
	_bgm_tracks()
	_sfx_tracks()
	quit(0)


func _f(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## 在 buf 上叠加一段带包络的音（attack 8ms / release 末 25%）。
func _tone(buf: PackedFloat32Array, start_s: float, dur: float, freq: float, vol: float, wave := "square") -> void:
	var n0 := int(start_s * RATE)
	var n1 := mini(int((start_s + dur) * RATE), buf.size())
	for i in range(n0, n1):
		var t := float(i - n0) / RATE
		var ph := t * freq
		var v: float
		match wave:
			"sine": v = sin(ph * TAU)
			"tri": v = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
			"saw": v = fmod(ph, 1.0) * 2.0 - 1.0
			"noise": v = rng.randf_range(-1.0, 1.0)
			_: v = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		var env := 1.0
		if t < 0.008:
			env = t / 0.008
		var rel := dur * 0.75
		if t > rel:
			env = maxf(0.0, 1.0 - (t - rel) / maxf(dur * 0.25, 0.001))
		buf[i] += v * vol * env


## 线性扫频（f0→f1）。
func _sweep(buf: PackedFloat32Array, start_s: float, dur: float, f0: float, f1: float, vol: float, wave := "square") -> void:
	var n0 := int(start_s * RATE)
	var n1 := mini(int((start_s + dur) * RATE), buf.size())
	for i in range(n0, n1):
		var t := float(i - n0) / dur
		var freq := lerpf(f0, f1, t)
		var ph := t * dur * (f0 + (f1 - f0) * t * 0.5)
		var v: float
		match wave:
			"saw": v = fmod(ph, 1.0) * 2.0 - 1.0
			"noise": v = rng.randf_range(-1.0, 1.0)
			_: v = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		var env := 1.0 - t * 0.4
		buf[i] += v * vol * env


## 顺序旋律：notes 为 MIDI 音高（0 = 休止），每个音占 steps_per_note 步。
func _melody(buf: PackedFloat32Array, notes: Array, step_s: float, steps_per_note: int, wave: String, vol: float) -> void:
	var t := 0.0
	for n in notes:
		if n > 0:
			_tone(buf, t, step_s * steps_per_note * 0.92, _f(n), vol, wave)
		t += step_s * steps_per_note


func _stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _save(s: AudioStreamWAV, name: String) -> void:
	var err := s.save_to_wav(DIR + name)
	print("生成 %s -> %s" % [name, "成功" if err == OK else "失败(%d)" % err])


## —— BGM ——##

func _bgm_tracks() -> void:
	# 标题：安静琶音（C - Am - F - G）
	var title := _buf(10.8)
	_melody(title, [72, 76, 79, 76, 69, 72, 76, 72, 65, 69, 72, 69, 67, 71, 74, 71],
			0.3375, 2, "sine", 0.17)
	_melody(title, [48, 45, 41, 43], 0.3375, 8, "tri", 0.13)
	_save(_stream(title), "bgm_title.wav")

	# 博城：明快小调进行
	var town := _buf(10.56)
	_melody(town, [76, 79, 72, 79, 81, 79, 76, 72, 74, 76, 77, 74, 76, 72, 67, 72,
			77, 76, 74, 71, 72, 76, 79, 84], 0.22, 2, "square", 0.13)
	_melody(town, [48, 43, 48, 43, 45, 40, 45, 40, 41, 48, 41, 48], 0.22, 4, "tri", 0.13)
	_save(_stream(town), "bgm_town.wav")

	# 灰雾林地：神秘小调
	var grove := _buf(13.6)
	_melody(grove, [69, 72, 71, 69, 76, 74, 72, 71, 69, 72, 76, 79, 77, 76, 74, 71,
			72, 71, 69, 67, 69, 0, 64, 0], 0.34, 2, "tri", 0.16)
	_melody(grove, [45, 45, 41, 41, 38, 38, 40, 40], 0.34, 5, "sine", 0.14)
	_save(_stream(grove), "bgm_grove.wav")

	# 战斗：紧迫短句
	var battle := _buf(9.6)
	_melody(battle, [64, 64, 67, 69, 71, 69, 67, 64, 67, 69, 71, 74, 72, 71, 69, 67,
			64, 64, 67, 69, 71, 74, 72, 71, 69, 67, 66, 64, 64, 0, 64, 0],
			0.15, 2, "square", 0.15)
	_melody(battle, [40, 40, 52, 40, 40, 52, 40, 52, 45, 45, 57, 45, 43, 43, 55, 43],
			0.15, 2, "saw", 0.11)
	_save(_stream(battle), "bgm_battle.wav")


## —— SFX ——##

func _sfx_tracks() -> void:
	# UI
	var b := _buf(0.16)
	_melody(b, [85], 0.05, 2, "square", 0.16)
	_save(_stream(b), "ui_move.wav")

	b = _buf(0.3)
	_melody(b, [76, 83], 0.08, 2, "square", 0.2)
	_save(_stream(b), "ui_confirm.wav")

	b = _buf(0.3)
	_melody(b, [71, 64], 0.08, 2, "square", 0.2)
	_save(_stream(b), "ui_cancel.wav")

	# 战斗
	b = _buf(0.55)
	_sweep(b, 0.0, 0.35, 250.0, 950.0, 0.28, "saw")
	_sweep(b, 0.3, 0.2, 400.0, 900.0, 0.2, "noise")
	_save(_stream(b), "encounter.wav")

	b = _buf(0.2)
	_tone(b, 0.0, 0.12, 95.0, 0.34, "square")
	_tone(b, 0.0, 0.1, 0.0, 0.3, "noise")
	_save(_stream(b), "hit.wav")

	b = _buf(0.2)
	_sweep(b, 0.0, 0.12, 760.0, 320.0, 0.3, "square")
	_tone(b, 0.0, 0.08, 0.0, 0.22, "noise")
	_save(_stream(b), "weak_hit.wav")

	b = _buf(0.4)
	_sweep(b, 0.0, 0.28, 900.0, 170.0, 0.3, "square")
	_tone(b, 0.0, 0.06, 0.0, 0.3, "noise")
	_save(_stream(b), "break.wav")

	# 元素法术（与战斗演出配套：雷=天降闪电、火=火球、冰=冰棱）
	b = _buf(0.5)
	_tone(b, 0.0, 0.06, 0.0, 0.5, "noise")           # 炸裂
	_sweep(b, 0.03, 0.35, 320.0, 55.0, 0.4, "saw")   # 低频轰鸣余震
	_tone(b, 0.1, 0.1, 0.0, 0.22, "noise")
	_save(_stream(b), "spell_thunder.wav")

	b = _buf(0.45)
	_sweep(b, 0.0, 0.2, 180.0, 820.0, 0.24, "noise") # 火球呼啸
	_tone(b, 0.2, 0.22, 90.0, 0.4, "square")         # 爆裂
	_tone(b, 0.22, 0.16, 0.0, 0.28, "noise")
	_save(_stream(b), "spell_fire.wav")

	b = _buf(0.4)
	_melody(b, [108, 112, 115], 0.06, 1, "sine", 0.28)  # 冰晶高频脆响
	_tone(b, 0.18, 0.14, 0.0, 0.12, "noise")
	_save(_stream(b), "spell_ice.wav")

	# 区域过场：进野外=低鸣与远方嚎叫；回安全区=安宁上行琶音
	b = _buf(2.2)
	_sweep(b, 0.0, 1.6, 110.0, 55.0, 0.32, "saw")    # 低频压迫鸣
	_tone(b, 0.2, 1.4, 0.0, 0.12, "noise")           # 尘霾噪声
	_tone(b, 0.7, 0.5, _f(45), 0.2, "sine")          # 远方低嚎
	_sweep(b, 1.2, 0.5, 240.0, 380.0, 0.12, "sine")  # 嚎声上扬
	_save(_stream(b), "zone_wild.wav")

	b = _buf(1.6)
	_melody(b, [64, 69, 73, 76], 0.16, 2, "sine", 0.2)  # 归家琶音
	_tone(b, 0.64, 0.7, _f(76), 0.14, "tri")
	_save(_stream(b), "zone_safe.wav")

	# 技能呼喊兜底音（TTS 无中文嗓音时替代"喊招"）：短促人声式上扬
	b = _buf(0.22)
	_sweep(b, 0.0, 0.14, 330.0, 660.0, 0.34, "tri")
	_tone(b, 0.13, 0.07, 0.0, 0.1, "noise")
	_save(_stream(b), "voice_blip.wav")

	b = _buf(0.9)
	_melody(b, [72, 76, 79, 84], 0.14, 2, "square", 0.22)
	_tone(b, 0.56, 0.3, _f(84), 0.2, "square")
	_save(_stream(b), "victory.wav")

	b = _buf(1.1)
	_melody(b, [64, 60, 57], 0.3, 2, "sine", 0.24)
	_save(_stream(b), "defeat.wav")

	# 系统反馈
	b = _buf(0.4)
	_melody(b, [76, 81], 0.1, 2, "sine", 0.22)
	_save(_stream(b), "save.wav")

	b = _buf(0.7)
	_melody(b, [60, 64, 67], 0.18, 2, "sine", 0.2)
	_save(_stream(b), "rest.wav")

	b = _buf(0.8)
	_melody(b, [57, 60, 64, 69, 72, 76], 0.075, 2, "square", 0.2)
	_tone(b, 0.45, 0.3, _f(81), 0.18, "sine")
	_save(_stream(b), "breakthrough.wav")

	b = _buf(0.25)
	_melody(b, [83, 88], 0.05, 2, "square", 0.2)
	_save(_stream(b), "coin.wav")

	b = _buf(0.3)
	_melody(b, [88, 93], 0.06, 2, "sine", 0.22)
	_save(_stream(b), "star.wav")
