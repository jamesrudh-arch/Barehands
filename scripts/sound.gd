extends Node
## The whole sound layer. Autoloaded as "Sound" (see project.godot).
## Banks every clip under bare-hands/assets/audio, runs a small player pool
## for one-shots, layers impacts by kind, picks footsteps by surface with a
## raycast plus puddle proximity, and keeps the city bed (rain, traffic,
## neon hum, distant sirens) alive on the Ambience bus. Volume sliders and
## their persistence live here too.

const BUSES := ["Master", "Music", "SFX", "Ambience", "Voice", "UI"]
const SETTINGS := "user://settings.cfg"

var _bank: Dictionary = {}  # clip name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _amb: Dictionary = {}  # loop name -> AudioStreamPlayer
var _hum_at: Array[Vector3] = []
var _puddles: Array = []  # [{pos: Vector3, r: float}]
var _puddles_scanned := false
var _siren_at := 40.0
var last_played := ""  # test hook: most recent one-shot name
var layers_played: Array[String] = []  # test hook: names from the last layered hit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bank()
	_make_pool(_pool, 10, "SFX")
	_make_pool(_voice_pool, 2, "Voice")
	_load_volumes()
	Fx.hit_landed.connect(_on_hit)
	call_deferred("_start_city")


func _process(delta: float) -> void:
	_siren_at -= delta
	if _siren_at <= 0.0:
		_siren_at = randf_range(45.0, 110.0)
		play("siren", -20.0, 1.0, 0.02, "Ambience")


# --- bank ----------------------------------------------------------------------


func _load_bank() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir == null:
		Log.warn("Sound: no assets/audio folder")
	else:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".ogg") or name.ends_with(".wav"):
				var key := name.get_basename()
				_bank[key] = load("res://assets/audio/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	_ensure_generated()
	Log.info("Sound: bank has %d clips" % _bank.size())


## B18.3: stingers and cues the file bank does not carry, synthesized in
## code so missions, the guide and the phone are never silent even if a
## fresh import loses an audio file.
func _ensure_generated() -> void:
	var recipes := {
		"mission_start": {"freqs": [330.0, 440.0, 550.0], "dur": 0.5, "wave": "saw", "vol": 0.55},
		"mission_success": {"freqs": [523.0, 659.0, 784.0, 1047.0], "dur": 0.6, "wave": "sine", "vol": 0.5},
		"mission_fail": {"freqs": [440.0, 370.0, 294.0, 220.0], "dur": 0.8, "wave": "saw", "vol": 0.45},
		"guide_chime": {"freqs": [880.0, 1320.0], "dur": 0.3, "wave": "sine", "vol": 0.4},
		"phone_buzz": {"freqs": [160.0, 0.0, 160.0, 0.0, 160.0], "dur": 0.8, "wave": "square", "vol": 0.35},
	}
	for key in recipes:
		if _bank.has(key):
			continue
		_bank[key] = _synth_clip(recipes[key])


func _synth_clip(spec: Dictionary) -> AudioStreamWAV:
	var rate := 22050
	var total := int(rate * float(spec["dur"]))
	var data := PackedByteArray()
	data.resize(total * 2)
	var seg := maxi(1, total / maxi(1, (spec["freqs"] as Array).size()))
	var idx := 0
	for f0 in spec["freqs"]:
		var f: float = f0
		for i in mini(seg, total - idx):
			var t := float(i) / float(rate)
			var env: float = minf(1.0, t * 80.0) * exp(-t * 3.5)
			var s := 0.0
			if f > 0.0:
				match spec["wave"]:
					"saw":
						s = 2.0 * fmod(f * t, 1.0) - 1.0
					"square":
						s = 1.0 if fmod(f * t, 1.0) < 0.5 else -1.0
					_:
						s = sin(TAU * f * t)
			data.encode_s16((idx + i) * 2, int(clampf(s * env * float(spec["vol"]), -1.0, 1.0) * 16000.0))
		idx += seg
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## B18.3 Part 6E.1: TEST SOUND - a clear tone on every bus, one by one,
## with a log line per bus. Returns the log so the DEVICE REPORT and the
## debug panel can show exactly what played where.
func test_buses() -> String:
	var log_lines: Array[String] = []
	var order := ["Master", "Music", "SFX", "Ambience", "Voice", "UI"]
	for bus in order:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			log_lines.append("%s: NO SUCH BUS" % bus)
			continue
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.stream = _synth_clip({"freqs": [660.0 if bus != "Master" else 440.0],
				"dur": 0.25, "wave": "sine", "vol": 0.6})
		p.volume_db = -6.0
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		var state := "MUTE" if AudioServer.is_bus_mute(idx) else "ok"
		log_lines.append("%s: tone played (vol %.0f dB, %s)"
				% [bus, AudioServer.get_bus_volume_db(idx), state])
		Log.info("Sound: TEST %s" % log_lines[-1])
	return "\n".join(log_lines)


func _make_pool(into: Array[AudioStreamPlayer], count: int, bus: String) -> void:
	for i in count:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		into.append(p)


# --- one-shots -----------------------------------------------------------------


## One-shot with random pitch jitter so repeats never sound mechanical.
## UI clips always ride the UI bus; the Voice pool serves Voice only,
## every other bus shares the bigger SFX pool.
func play(clip: String, vol_db := 0.0, pitch := 1.0, jitter := 0.05, bus := "SFX") -> void:
	if bus == "SFX" and clip.begins_with("ui_"):
		bus = "UI"
	var stream: AudioStream = _bank.get(clip)
	if stream == null:
		Log.warn("Sound: missing clip %s" % clip)
		return
	last_played = clip
	for p in _voice_pool if bus == "Voice" else _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = vol_db
			p.pitch_scale = maxf(0.05, pitch + randf_range(-jitter, jitter))
			p.bus = bus
			p.play()
			return
	# pool busy: steal the first slot rather than drop the sound
	var steal: AudioStreamPlayer = (_voice_pool[0] if bus == "Voice" else _pool[0])
	steal.stream = stream
	steal.volume_db = vol_db
	steal.pitch_scale = pitch
	steal.play()


## A variant pick: base_0..base_(n-1) chosen at random.
func play_v(base: String, n: int, vol_db := 0.0, pitch := 1.0, jitter := 0.05) -> void:
	play("%s_%d" % [base, randi() % n], vol_db, pitch, jitter)


## Layered hit: names + per-layer volume db.
func play_layers(names: Array, vols: Array) -> void:
	layers_played.clear()
	for i in names.size():
		play(names[i], vols[i] if i < vols.size() else 0.0)
		layers_played.append(names[i])


# --- impacts -------------------------------------------------------------------


func _on_hit(kind: String, _pos: Vector3) -> void:
	match kind:
		"jab":
			play_layers(["punch_med_%d" % (randi() % 3), "body_med_0"], [0.0, -6.0])
		"cross":
			play_layers(["punch_heavy_%d" % (randi() % 3), "body_heavy_%d" % (randi() % 2),
					"sub_hit_0"], [0.0, -5.0, -9.0])
		"counter":
			play_layers(["punch_heavy_%d" % (randi() % 3), "body_heavy_0",
					"sub_hit_1", "metal_ring_1"], [0.0, -4.0, -7.0, -12.0])
		"slam":
			play_layers(["wood_heavy_0", "sub_hit_0", "glass_med_0"], [0.0, -7.0, -14.0])
		"parry":
			play_layers(["metal_ring_0", "latch_0"], [0.0, -8.0])
		"player_hit":
			play_layers(["body_heavy_1", "cloth_%d" % (randi() % 3)], [0.0, -7.0])
		"gun_test":
			play_v("gun_test", 2, -4.0, 1.0, 0.03)
		"finisher":
			play_layers(["punch_heavy_2", "sub_hit_1", "bell_heavy_0"], [0.0, -5.0, -10.0])
		_:
			play_v("punch_med", 3, -2.0)


# --- footsteps -----------------------------------------------------------------


## Surface under a position: raycast metadata first, puddle proximity second.
func surface_at(pos: Vector3) -> String:
	if not _puddles_scanned:
		_scan_puddles()
	var space := get_tree().root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * 0.9, pos + Vector3.DOWN * 0.6, 1))
	var surf := "asphalt"
	if not hit.is_empty() and hit.collider.has_meta("surface"):
		surf = hit.collider.get_meta("surface")
	for p in _puddles:
		var flat := Vector2(pos.x - p.pos.x, pos.z - p.pos.z)
		if flat.length() < p.r:
			return "puddle"
	return surf


## One footstep on a surface. Metal is wood pitched down plus a click layer.
func step(surface: String) -> void:
	match surface:
		"asphalt":
			play_v("step_asphalt", 4, -8.0, 1.0, 0.06)
		"wood":
			play_v("step_wood", 4, -8.0, 1.0, 0.06)
		"carpet":
			play_v("step_carpet", 3, -12.0, 1.0, 0.06)
		"metal":
			play_v("step_wood", 4, -12.0, 0.82, 0.05)
			play("metal_click_0", -14.0, 1.1, 0.08)
		"puddle":
			play_v("splash", 3, -6.0, 1.0, 0.08)


func _scan_puddles() -> void:
	_puddles_scanned = true
	_puddles.clear()
	for n in get_tree().get_nodes_in_group("puddle"):
		var qm: QuadMesh = (n as MeshInstance3D).mesh
		if qm:
			_puddles.append({"pos": (n as Node3D).global_position, "r": qm.size.x * 0.5})


# --- ambience ------------------------------------------------------------------


func _start_city() -> void:
	_amb_loop("rain_asphalt", -8.0)
	_amb_loop("traffic", -16.0)
	_amb_loop("rain_metal", -22.0)
	# spatial hum at every neon light
	var neon := get_tree().get_first_node_in_group("neon") as Node3D
	if neon:
		for c in neon.get_children():
			if c is OmniLight3D:
				var p := AudioStreamPlayer3D.new()
				p.stream = _bank.get("hum")
				p.bus = "Ambience"
				p.unit_size = 1.2
				p.max_db = -8.0
				p.volume_db = 0.0
				neon.add_child(p)
				p.global_position = (c as Node3D).global_position
				p.play()


func _amb_loop(clip: String, vol_db: float) -> void:
	var stream: AudioStream = _bank.get(clip)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
		(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2  # 16-bit mono
	var p := AudioStreamPlayer.new()
	p.bus = "Ambience"
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	p.play()
	_amb[clip] = p


# --- volumes -------------------------------------------------------------------


func set_bus_vol(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear < 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.01)))
	_save_volumes()


func get_bus_vol(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("audio", b, get_bus_vol(b))
	cfg.save(SETTINGS)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	for b in BUSES:
		if cfg.has_section_key("audio", b):
			set_bus_vol(b, cfg.get_value("audio", b))
