extends Node
## 音频管理（autoload：Audio）。BGM 单通道循环，SFX 小通道池并发。
##
## 跨场景持续（autoload 常驻）：探索 ↔ 战斗切换时 play_bgm 自动换曲，
## 遇敌音效不会因场景切换被打断。音频文件为程序生成占位
## （tools/gen_placeholder_audio.gd），正式音频按同名文件替换即可。

const BGM := {
	"title": "res://assets/audio/bgm_title.wav",
	"town": "res://assets/audio/bgm_town.wav",
	"grove": "res://assets/audio/bgm_grove.wav",
	"battle": "res://assets/audio/bgm_battle.wav",
}
const SFX := {
	"ui_move": "res://assets/audio/ui_move.wav",
	"ui_confirm": "res://assets/audio/ui_confirm.wav",
	"ui_cancel": "res://assets/audio/ui_cancel.wav",
	"encounter": "res://assets/audio/encounter.wav",
	"hit": "res://assets/audio/hit.wav",
	"weak_hit": "res://assets/audio/weak_hit.wav",
	"break": "res://assets/audio/break.wav",
	"victory": "res://assets/audio/victory.wav",
	"defeat": "res://assets/audio/defeat.wav",
	"save": "res://assets/audio/save.wav",
	"rest": "res://assets/audio/rest.wav",
	"breakthrough": "res://assets/audio/breakthrough.wav",
	"coin": "res://assets/audio/coin.wav",
	"star": "res://assets/audio/star.wav",
	"spell_thunder": "res://assets/audio/spell_thunder.wav",
	"spell_fire": "res://assets/audio/spell_fire.wav",
	"spell_ice": "res://assets/audio/spell_ice.wav",
	"zone_wild": "res://assets/audio/zone_wild.wav",
	"zone_safe": "res://assets/audio/zone_safe.wav",
	"voice_blip": "res://assets/audio/voice_blip.wav",
}

## 技能呼喊的音色档案（pitch/rate 即使共用系统嗓音也能拉开角色区分度）。
const VOICE_PROFILES := {
	"mo_fan": {"pitch": 0.8, "rate": 0.95, "female": false},
	"mu_ningxue": {"pitch": 1.3, "rate": 1.05, "female": true},
	"tangyue": {"pitch": 1.1, "rate": 1.0, "female": true},
	"yu_ang": {"pitch": 0.9, "rate": 0.9, "female": false},
}

var _zh_voices: Array = []
var _voice_male := ""
var _voice_female := ""
const SFX_CHANNELS := 6

var current_bgm := ""
var music_volume := 0.6  # 线性音量 0-1（音量设置界面待做）
var sfx_volume := 0.9

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	for i in SFX_CHANNELS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


## 切换 BGM：同名不重播；传 "" 停止。
func play_bgm(bgm_name: String) -> void:
	if bgm_name == current_bgm:
		return
	current_bgm = bgm_name
	if bgm_name == "" or not BGM.has(bgm_name):
		push_warning("未知 BGM：%s" % bgm_name)
		_bgm_player.stop()
		_bgm_player.stream = null
		return
	var stream: AudioStream = load(BGM[bgm_name])
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit 单声道，每帧 2 字节
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(music_volume)
	_bgm_player.play()


## 播放音效：空闲通道池，全占用时抢占第一个。pitch 用于同音变调（呼喊兜底）。
func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not SFX.has(sfx_name):
		push_warning("未知音效：%s" % sfx_name)
		return
	var stream: AudioStream = load(SFX[sfx_name])
	var player := _sfx_players[0]
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(sfx_volume)
	player.play()


## 技能呼喊：优先用系统 TTS 念出技能名（按角色分配男女声 + 音高/语速）；
## 无中文语音包的环境（无头测试/精简系统）退化为按角色音高的短促喊招音，
## 视觉上的技能名飘字始终存在，战斗节奏不受影响。
func speak(text: String, char_id: String) -> void:
	var p: Dictionary = VOICE_PROFILES.get(char_id, {"pitch": 1.0, "rate": 1.0, "female": false})
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		if _zh_voices.is_empty():
			for v in DisplayServer.tts_get_voices():
				if String(v.get("language", "")).begins_with("zh"):
					_zh_voices.append(v)
			for v in _zh_voices:
				var n := String(v.get("name", "")).to_lower()
				# Windows 中文嗓音：Kangkang/Yunyang/Yunxi 为男声，其余（Huihui/
				# Yaoyao/Xiaoxiao…）按女声兜底
				if n.contains("kangkang") or n.contains("yunyang") or n.contains("yunxi"):
					if _voice_male == "":
						_voice_male = v.get("id", "")
				elif _voice_female == "":
					_voice_female = v.get("id", "")
			if _voice_male == "":
				_voice_male = _voice_female
		if not _zh_voices.is_empty():
			var voice := _voice_female if p["female"] else _voice_male
			DisplayServer.tts_speak(text, voice, 80, p["pitch"], 1.0, p["rate"])
			return
	play_sfx("voice_blip", p["pitch"])
