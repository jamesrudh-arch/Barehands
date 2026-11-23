extends Node
## B18.3 Part 6E.6: VOICE AND NARRATION. Autoloaded as "Narrator".
## Every line is SPOKEN if the platform TTS allows it (Godot's
## DisplayServer TTS: enabled by the project setting
## audio/general/text_to_speech; the docs confirm the system libraries
## are installed by default on iOS) and ALWAYS shown as a subtitle with
## the speaker name. If TTS is off, unavailable or returns no English
## voice (the docs warn the list can come back empty), a synthesized
## radio-voice babble plays timed to the text so a line is never
## silent. Phone callers get distinct pitch/rate per speaker.

const LINES := {
	"intro_0": ["", "The city keeps its books in rain and neon."],
	"intro_1": ["", "Everyone owes. Everyone is owed."],
	"intro_2": ["", "You came home with empty hands and a name that still opens doors."],
	"intro_3": ["", "The Family lent you a room over the noodle shop."],
	"intro_4": ["", "They will want it repaid. They always do."],
	"intro_5": ["", "Find the door. Follow the green light."],
	"intro_6": ["", "The street will teach your fists what your name forgot."],
	"intro_7": ["", "Leverage. Everyone has leverage on you."],
	"tut_door": ["", "The glowing frame is the door. Walk to it."],
	"tut_open": ["", "Stand close and press B to open it."],
	"tut_out": ["", "Breathe. The street is yours tonight."],
	"tut_dummy": ["", "The dummy waits. X to punch, Y for heavy."],
	"call_demand": ["BROTHER", "You sleeping good up there? The Family ain't. Five hundred by Friday, or I bring friends."],
	"call_invite": ["CLUB OWNER", "Your knuckles still remember the work? Private floor, Saturday. Cash questions, no names."],
	"voicemail": ["LIEUTENANT", "Word of advice: the Corporation is buying the block your room sits on. Doors close fast around here. Keep moving."],
}

var _voice_id := ""
var _tts_tried := false
var _layer: CanvasLayer
var _label: Label
var _speaker: Label
var _hide_t := 0.0
var _babble_player: AudioStreamPlayer
var _babble_by_key: Dictionary = {}
# B28 VOICE: the recorded lines (assets/voice/narrator_XX.wav) - the
# real delivery outranks platform TTS and the radio babble
var _clip_player: AudioStreamPlayer
var _clip_now := ""
var narration_used := false
var fallback_used := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)
	_speaker = Label.new()
	_speaker.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speaker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speaker.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speaker.offset_bottom = -46.0
	_speaker.offset_top = -72.0
	_speaker.add_theme_font_size_override("font_size", 13)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_speaker)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -18.0
	_label.offset_top = -44.0
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.97))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_label)
	_hide()


func _process(delta: float) -> void:
	if _hide_t > 0.0:
		_hide_t -= delta
		if _hide_t <= 0.0:
			_hide()


## Speak + subtitle. speaker "" = the narrator. The subtitle ALWAYS
## shows; a RECORDED line (B28) plays when one exists for the key;
## then platform TTS; the babble only when nothing real is available.
func say(text: String, speaker := "", key := "") -> void:
	narration_used = true
	_speaker.text = speaker.to_upper() if speaker != "" else ""
	_speaker.visible = speaker != ""
	_label.text = text
	_layer.visible = true
	_hide_t = clampf(float(text.length()) * 0.055, 2.4, 6.5)
	if _play_clip(key):
		pass  # the recorded voice is the line
	elif _tts_ok():
		var pitch := 1.0
		var rate := 1.0
		match speaker.to_lower():
			"brother":
				pitch = 0.8
				rate = 0.92
			"club owner":
				pitch = 1.1
				rate = 1.05
			"lieutenant":
				pitch = 0.9
				rate = 1.0
			"family boss":
				pitch = 0.72
				rate = 0.88
			"corporation":
				pitch = 1.2
				rate = 1.18
			"crew":
				pitch = 0.95
				rate = 1.1
		# tts_speak(text, voice, pitch, volume 0..100, rate, interrupt)
		DisplayServer.tts_speak(text, _voice_id, pitch, 70.0, rate, false)
	else:
		fallback_used = true
		_babble(text, speaker)


## Say one of the scripted LINES by key.
func say_key(key: String) -> void:
	var l: Array = LINES.get(key, [])
	if l.size() == 2:
		say(l[1], l[0], key)


## B28 VOICE: the recorded narrator lines, keyed by LINES key. The
## bank lives beside the cast recordings; a missing file degrades to
## the old ladder (TTS, then babble) so a partial bank never breaks
## a boot.
const CLIP_BY_KEY := {
	"call_demand": "res://assets/voice/narrator_01.wav",
	"call_invite": "res://assets/voice/narrator_02.wav",
	"voicemail": "res://assets/voice/narrator_03.wav",
}


func has_clip(key: String) -> bool:
	return CLIP_BY_KEY.has(key) \
			and ResourceLoader.exists(CLIP_BY_KEY[key])


## Plays the recorded clip for a key. True when one actually played.
func _play_clip(key: String) -> bool:
	if key == "" or not CLIP_BY_KEY.has(key):
		return false
	var path: String = CLIP_BY_KEY[key]
	if not ResourceLoader.exists(path):
		return false
	if _clip_player == null:
		_clip_player = AudioStreamPlayer.new()
		_clip_player.bus = "Voice"
		add_child(_clip_player)
	_clip_player.stream = load(path)
	_clip_player.play()
	_clip_now = key
	Log.info("Narrator: recorded line plays (%s)" % key)
	return true


func clip_playing() -> String:
	if _clip_player and _clip_player.playing:
		return _clip_now
	return ""


func stop() -> void:
	_hide()
	if _tts_ok():
		DisplayServer.tts_stop()
	if _babble_player and _babble_player.playing:
		_babble_player.stop()
	if _clip_player and _clip_player.playing:
		_clip_player.stop()
	_clip_now = ""


func _hide() -> void:
	_layer.visible = false
	_speaker.text = ""
	_label.text = ""


## TTS is usable: the project setting is on AND an English voice came
## back (the docs warn the list can be empty - check before indexing).
func _tts_ok() -> bool:
	if not Settings.value("narrator_on"):
		return false
	if not _tts_tried:
		_tts_tried = true
		if not DisplayServer.has_method("tts_speak"):
			return false
		var voices := PackedStringArray()
		if DisplayServer.has_method("tts_get_voices_for_language"):
			voices = DisplayServer.tts_get_voices_for_language("en")
		if voices.size() > 0:
			_voice_id = voices[0]
			Log.info("Narrator: TTS voice %s" % _voice_id)
		else:
			Log.warn("Narrator: no TTS voices - the babble fallback speaks")
	if _voice_id == "":
		return false
	return true


func tts_enabled() -> bool:
	return _voice_id != ""


## The fallback voice: short filtered blips, one per few characters,
## distinct pitch per speaker - a radio crackle that paces the line.
func _babble(text: String, speaker: String) -> void:
	var pitch := 1.0
	match speaker.to_lower():
		"brother":
			pitch = 0.7
		"club owner":
			pitch = 1.15
		"lieutenant":
			pitch = 0.9
		"corporation":
			pitch = 1.25
		"crew":
			pitch = 0.95
	if _babble_player == null:
		_babble_player = AudioStreamPlayer.new()
		_babble_player.bus = "Voice"
		add_child(_babble_player)
	_babble_player.stream = _babble_stream(pitch)
	_babble_player.volume_db = -14.0
	_babble_player.play()


func _babble_stream(pitch: float) -> AudioStreamWAV:
	if _babble_by_key.has(pitch):
		return _babble_by_key[pitch]
	var rate := 22050
	var syllables := 8
	var syl_len := int(rate * 0.07)
	var data := PackedByteArray()
	data.resize(syllables * syl_len * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch * 1000.0)
	for s in syllables:
		var f := 220.0 * pitch * pow(1.12, rng.randi_range(0, 7))
		for i in syl_len:
			var t := float(i) / float(rate)
			var env: float = sin(PI * t / 0.07) * 0.5
			var v := int(clampf(sin(TAU * f * t) * env, -1.0, 1.0) * 9000.0)
			data.encode_s16((s * syl_len + i) * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_babble_by_key[pitch] = wav
	return wav
