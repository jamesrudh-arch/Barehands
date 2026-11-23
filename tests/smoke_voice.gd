extends Node
## B28 VOICE: the recorded cast. The empty voice hook that shipped
## since Series-2 Phase 7 (dialogue.gd plays assets/voice/<id>_<n>.wav
## "if the recording exists") finally has recordings: 14 named
## speakers x their lines, plus the narrator's three spoken calls.
## Every file is a REAL take (duration-checked, not a stub), the
## narrator plays the brother's call as a recorded line with its
## subtitle, the cast dialogue plays the SPEAKER'S OWN recording, and
## an unrecorded line still falls back down the old ladder cleanly.
## Run: godot --headless --path . res://tests/smoke_voice.tscn

const SPEAKERS := ["velvet", "pilsner", "marrow", "duchess", "mama_sun",
	"ash", "tam", "raz", "drunk", "okafor", "kessler", "mechanic",
	"club_owner", "yuen"]

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("VOICE FAIL: ", what)
	else:
		print("VOICE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	Settings.set_value("dynamic_events", false)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout

	# 1. THE BANK: 14 speakers x 2 lines exist and are real takes
	var total := 0
	var real := 0
	var shortest := 99.0
	for s in SPEAKERS:
		for n in 2:
			var path := "res://assets/voice/%s_%02d.wav" % [s, n + 1]
			if not ResourceLoader.exists(path):
				_check(false, "the bank carries %s" % path)
				continue
			total += 1
			var st := load(path)
			if st is AudioStreamWAV:
				# Godot imports WAV to QOA (compressed) - the stream's
				# own get_length() is the honest duration, not byte math
				var secs: float = (st as AudioStreamWAV).get_length()
				shortest = minf(shortest, secs)
				if secs > 1.2:
					real += 1
	_check(total == 28, "28 cast recordings in the bank (%d of 28)" % total)
	_check(real == total,
			"every cast recording is a real take (shortest %.1f s)" % shortest)

	# 2. the narrator's three calls have recordings
	for k in ["call_demand", "call_invite", "voicemail"]:
		_check(Narrator.has_clip(k),
				"the narrator carries a recording for %s" % k)

	# 3. the brother's call PLAYS as a recorded line, subtitle intact
	Narrator.say_key("call_demand")
	await get_tree().create_timer(0.4).timeout
	_check(Narrator.clip_playing() == "call_demand",
			"the brother's call plays as a recorded line")
	var sub := str(Narrator.get("_label").text)
	_check(sub.contains("Five hundred by Friday"),
			"the subtitle matches the recording ('%s')" % sub.substr(0, 40))
	Narrator.stop()
	await get_tree().create_timer(0.1).timeout
	_check(Narrator.clip_playing() == "",
			"stop() silences the recording")

	# 4. the cast dialogue plays the SPEAKER'S OWN recording
	var lines: Array = [
		{"speaker": "Velvet", "color": Color(0.55, 0.3, 0.35),
			"voice_id": "velvet",
			"text": "You're the one burning through my neighbourhood. Bullets aren't sold, they're rented - from your wallet."},
	]
	Dialogue.run(lines)
	await get_tree().create_timer(0.4).timeout
	var vp: AudioStreamPlayer = Dialogue.get("_voice")
	_check(vp != null and vp.playing and vp.stream != null
			and str(vp.stream.resource_path).contains("velvet_01.wav"),
			"Velvet's line plays HER recording (%s)"
			% str(vp.stream.resource_path if vp and vp.stream else "none"))
	Dialogue.call("_close")

	# 5. an unrecorded line falls back down the old ladder - no phantom
	# clip, no crash, the subtitle still shows
	Narrator.say("A line nobody ever recorded.", "CREW")
	await get_tree().create_timer(0.2).timeout
	_check(Narrator.clip_playing() == "",
			"an unrecorded line never pretends to have a clip")
	_check(str(Narrator.get("_label").text).contains("nobody ever recorded"),
			"the fallback subtitle still shows")
	Narrator.stop()

	_finish()


func _finish() -> void:
	await get_tree().create_timer(0.4).timeout
	print("VOICE RESULT: %d checks, %d fails" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
