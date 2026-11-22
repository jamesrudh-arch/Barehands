extends Node3D

## LEVERAGE B18 Part 6C: NEVER LOST. The first-minutes guided intro and
## the permanent guidance layer:
##   - steps: FIND THE DOOR -> OPEN IT -> REACH THE NOODLE SHOP, each
##     with live objective text + distance, a confirmation sound, and a
##     big top-centre label (skippable)
##   - current_target() feeds MapData.nav_target, so the radar, the
##     route line, the 3D marker and the compass all point at the
##     current step automatically
##   - SONAR: a soft repeating ping from the direction of the target,
##     stereo-panned, faster and louder as you close in (a generated
##     stereo WAV - no audio files), toggle in Settings (sonar_on)
##   - after 20 s without progress: a spoken-style hint + the door
##     frame's pulse; the HELP button repeats it, the OBJECTIVE button
##     shows the objective and turns the camera toward it
## After the intro the node stays alive as the guidance layer (sonar +
## objective/help for any live objective or waypoint).

const CLS_MapData := preload("res://scripts/map_data.gd")

const STEP_FIND := 0
const STEP_OPEN := 1
const STEP_REACH := 2
const STEP_DONE := 3
const STEP_STAND := 4  # Gate A: the standing street objective

var step := STEP_DONE
var _hint_t := 0.0
var _best_dist := INF
var _sonar_t := 0.0
var _label: Label
var _skip: Button
var _layer: CanvasLayer
var _ping_by_pan: Dictionary = {}   # pan bucket -> AudioStreamWAV
var _player: Node3D


func _ready() -> void:
	add_to_group("guide")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	call_deferred("_first_run_spawn")


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 0.95))
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 74.0
	_label.offset_bottom = 102.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_label)
	_skip = Button.new()
	_skip.text = "SKIP INTRO"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 12)
	_skip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_skip.offset_top = 104.0
	_skip.offset_left = 128.0
	_skip.offset_right = 216.0
	_skip.offset_bottom = 130.0
	_skip.pressed.connect(_finish)
	_layer.add_child(_skip)


## The hero's boot guidance (Gate A: the guide ALWAYS starts). The
## room intro runs when the hero wakes in or near the apartment - the
## first run OR any boot that lands there. When the intro is done (or
## the hero starts on the street), a standing objective keeps the
## radar, the route and the objective text alive, so nothing ever
## reads "no objective".
func _first_run_spawn() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var in_apartment := absf(_player.global_position.x - 780.0) < 14.0
	if in_apartment and not Settings.hint_done("intro_done"):
		step = STEP_FIND
		_best_dist = INF
		Log.info("Guide: the hero wakes in the apartment - the intro runs")
		Narrator.say_key("tut_door")
		return
	if in_apartment:
		# the intro ran before but the hero is home again: re-offer the
		# door steps (they are the way out - the owner was stuck here)
		step = STEP_FIND
		_best_dist = INF
		return
	# on the street: a standing objective (the training dummy corner)
	step = STEP_STAND
	_best_dist = INF
	Log.info("Guide: standing objective - the trainer's corner")


# --- the navigation target (MapData.nav_target reads this) -------------------


## {text, pos} for the current step, or {} when the intro is done.
func current_target() -> Dictionary:
	match step:
		STEP_FIND, STEP_OPEN:
			return {"text": _step_text(), "pos": _door_pos()}
		STEP_REACH:
			return {"text": _step_text(), "pos": Vector3(-1.3, 0.0, -4.5)}
		STEP_STAND:
			return {"text": _step_text(), "pos": Vector3(-3.4, 1.0, -6.2)}
	return {}


func _step_text() -> String:
	match step:
		STEP_FIND:
			return "FIND THE DOOR - the glowing frame"
		STEP_OPEN:
			return "OPEN THE DOOR - stand close, tap INTERACT"
		STEP_REACH:
			return "REACH THE TRAINING DUMMY - warm up"
		STEP_STAND:
			return "FIND THE TRAINER - learn your moves"
	return ""


func _door_pos() -> Vector3:
	for n in get_tree().get_nodes_in_group("door_prompt"):
		if str(n.name).begins_with("Apartment"):
			return (n as Node3D).global_position + Vector3(0, 1.0, -2.6)
	return Vector3(780.0, 1.0, -3.0)


# --- per frame: step checks, hints, sonar, the label --------------------------


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if step != STEP_DONE:
		_step_check()
	_hint_clock(delta)
	_sonar_clock(delta)
	_refresh_label()


func _step_check() -> void:
	var pos: Vector3 = _player.global_position
	match step:
		STEP_FIND:
			if Vector2(pos.x, pos.z).distance_to(
					Vector2(_door_pos().x, _door_pos().z)) < 2.8:
				_advance()
		STEP_OPEN:
			if pos.x < 700.0:
				_advance()
		STEP_REACH:
			if Vector2(pos.x, pos.z).distance_to(
					Vector2(-1.3, -4.5)) < 3.0:
				_advance()
		STEP_STAND:
			# the standing objective completes at the trainer's corner
			if Vector2(pos.x, pos.z).distance_to(
					Vector2(-3.4, -6.2)) < 3.0:
				_finish()


func _advance() -> void:
	step += 1
	_best_dist = INF
	_hint_t = 0.0
	Sound.play("ui_confirm_0", -6.0, 1.1)
	match step:
		STEP_OPEN:
			Narrator.say_key("tut_open")
		STEP_REACH:
			Narrator.say_key("tut_out")
		STEP_DONE:
			Narrator.say_key("tut_dummy")
	if step == STEP_DONE:
		_finish()
	else:
		Log.info("Guide: step %d - %s" % [step, _step_text()])


func _finish() -> void:
	step = STEP_DONE
	Settings.set_hint_done("intro_done")
	_skip.visible = false
	_label.text = "THE STREET IS YOURS - the radar (top-left) and the compass point the way"
	Sound.play("bell_heavy_0", -10.0, 1.2)
	Log.info("Guide: intro done")


## 20 s without closing in on the target -> a hint (repeats while stuck).
func _hint_clock(delta: float) -> void:
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		return
	var dist := _nav_distance(nav)
	if dist < _best_dist - 0.5:
		_best_dist = dist
		_hint_t = 0.0
		return
	_hint_t += delta
	if _hint_t >= 20.0:
		_hint_t = 0.0
		show_hint()


func _refresh_label() -> void:
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		if step == STEP_DONE:
			_label.text = ""
		return
	var dist := _nav_distance(nav)
	var text: String = str(nav.get("text", ""))
	_label.text = "%s  -  %d m" % [text, int(round(dist))]


func _nav_distance(nav: Dictionary) -> float:
	if _player == null:
		return 0.0
	var p: Vector2 = nav["pos"]
	return p.distance_to(Vector2(_player.global_position.x,
			_player.global_position.z))


# --- the sonar ----------------------------------------------------------------


## Ping interval shortens with distance: 1.6 s far away, 0.28 s close.
func ping_interval(dist: float) -> float:
	return clampf(remap(dist, 3.0, 45.0, 0.28, 1.6), 0.28, 1.6)


func sonar_on() -> bool:
	return bool(Settings.value("sonar_on"))


func _sonar_clock(delta: float) -> void:
	if not sonar_on():
		return
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty() or _player == null:
		return
	var dist := _nav_distance(nav)
	_sonar_t += delta
	if _sonar_t < ping_interval(dist):
		return
	_sonar_t = 0.0
	var p: Vector2 = nav["pos"]
	var dir := (p - Vector2(_player.global_position.x,
			_player.global_position.z)).normalized()
	var yaw: float = InputBus.camera_yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var pan := clampf(dir.dot(right), -1.0, 1.0)
	var vol := clampf(remap(dist, 45.0, 3.0, -24.0, -8.0), -24.0, -8.0)
	_play_ping(pan, vol)


## A decaying stereo sine, pan baked into L/R amplitudes - generated
## once per pan bucket, no audio files, no per-play allocations.
func _play_ping(pan: float, vol_db: float) -> void:
	var bucket := int(round(pan * 4.0)) / 4.0
	var stream: AudioStreamWAV = _ping_by_pan.get(bucket)
	if stream == null:
		var rate := 22050
		var n := int(rate * 0.09)
		var data := PackedByteArray()
		data.resize(n * 4)
		var lgain: float = clampf(1.0 - bucket, 0.0, 1.0)
		var rgain: float = clampf(1.0 + bucket, 0.0, 1.0)
		for i in n:
			var t := float(i) / float(rate)
			var env := exp(-t * 30.0)
			var s := sin(TAU * 1150.0 * t) * env
			var sl := int(clampf(s * lgain, -1.0, 1.0) * 16000.0)
			var sr := int(clampf(s * rgain, -1.0, 1.0) * 16000.0)
			data.encode_s16(i * 4, sl)
			data.encode_s16(i * 4 + 2, sr)
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.stereo = true
		stream.data = data
		_ping_by_pan[bucket] = stream
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol_db
	p.bus = "Ambience"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- the HUD buttons reach in here (OBJECTIVE / HELP) --------------------------


func objective_pressed() -> void:
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		_toast("No objective - pin a waypoint on the map (tap the radar)")
		return
	var dist := _nav_distance(nav)
	_toast("%s - %d m" % [nav.get("text", ""), int(round(dist))])
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("face_point"):
		cam.call("face_point", nav["pos"])
	# the guide orb returns to the hero when OBJECTIVE is tapped
	var orb := get_tree().get_first_node_in_group("guide_orb")
	if orb and orb.has_method("recall"):
		orb.call("recall")


func help_pressed() -> void:
	if step != STEP_DONE:
		show_hint()
		return
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		_toast("Nothing to find - the streets are yours")
	else:
		_toast("%s - follow the compass at the top, the radar's route, or the yellow beam" % nav.get("text", ""))


func show_hint() -> void:
	var text := ""
	match step:
		STEP_FIND:
			text = "The glowing frame on the far wall is the door - walk to it"
		STEP_OPEN:
			text = "Stand at the glowing frame; the INTERACT button appears bottom-right - tap it"
		STEP_REACH:
			text = "Out on the street: the yellow beam marks the dummy - the compass at the top and the radar's route point the way"
		_:
			var nav: Dictionary = CLS_MapData.nav_target()
			text = "%s - follow the compass, the radar route, or the yellow beam" \
					% str(nav.get("text", "the objective"))
	_toast(text)
	Sound.play("ui_click_0", -10.0)


func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.call("show_hint", text, 3.6)
