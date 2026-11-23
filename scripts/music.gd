extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_Player := preload("res://scripts/player.gd")
## Adaptive music director. Autoloaded as "Music" (see project.godot).
## Five stems, all synthesized placeholders (swap the WAVs in assets/audio
## for recorded stems of the same names): a quiet noir bed, a tension pulse,
## a combat layer whose level follows the style rank, a heartbeat that speeds
## up with heat, and a resolve phrase after combat. Layer volume targets only
## change on bar boundaries (88 BPM, 4/4) so every transition lands on the
## beat and fades over about one bar.

const BPM := 88.0
const BAR := 60.0 / BPM * 4.0

enum State { EXPLORE, TENSION, COMBAT, RESOLVE }

var state: State = State.EXPLORE
var heat := 0.0  # 0..5, driven by the economy phase; combat lends a little
var style_rank := 0
var beat_phase := 0.0  # 0..1 through the current bar

var _layers: Dictionary = {}  # name -> AudioStreamPlayer
var _targets: Dictionary = {}  # name -> target volume db
var _resolve_one := AudioStreamPlayer.new()
var _bar_t := 0.0
var _resolve_until := 0.0
var _combat_calm := 0.0  # seconds since an enemy was engaged
var _resolve_count := 0  # test hook
var _hold_until := 0  # while held, the world scan leaves the state alone


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for stem in ["music_bed", "music_tension", "music_combat", "music_heartbeat"]:
		var stream: AudioStream = load("res://assets/audio/%s.wav" % stem)
		var synth := false
		if stream == null:
			# B18.3 (BUG 13): a fresh device import can lose a file -
			# synthesize the stem in code so music never depends on
			# shipped audio. Logged so the DEVICE REPORT can name it.
			stream = _synth_stem(stem)
			synth = true
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_begin = 0
			(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2
		if stream == null:
			Log.warn("Music: stem %s unavailable entirely" % stem)
			continue
		var p := AudioStreamPlayer.new()
		p.name = stem
		p.bus = "Music"
		p.stream = stream
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_layers[stem] = p
		_targets[stem] = -60.0
		if synth:
			Log.warn("Music: %s synthesized in code (file missing)" % stem)
	_resolve_one.bus = "Music"
	add_child(_resolve_one)
	# Gate A: enter quietly - the bed rises to a LOW target (the old
	# -8 read as one loud wall of sound next to the old hot stems)
	_targets["music_bed"] = -14.0
	Log.info("Music: ready, 88 BPM, bar %.2fs" % BAR)


## B18.3: the menu loop - bed only, state held, while the title or menu
## is up. set_menu_mode(false) hands control back to the director.
func set_menu_mode(on: bool) -> void:
	if on:
		force_state("explore")
		_hold_until = Time.get_ticks_msec() + 1000000
		_targets["music_bed"] = -12.0
		_targets["music_tension"] = -60.0
		_targets["music_combat"] = -60.0
		_targets["music_heartbeat"] = -60.0
	else:
		_hold_until = 0
		_set_explore_targets()


## A code-synthesized stem loop (rough, but never silent) for the case
## where the shipped WAV did not load.
func _synth_stem(stem: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 2.0
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var s := 0.0
		var env := 0.0
		match stem:
			"music_bed":
				env = minf(1.0, t * 2.0) * minf(1.0, (dur - t) * 2.0) * 0.32
				s = (sin(TAU * 220.0 * t) + sin(TAU * 261.6 * t)
						+ sin(TAU * 329.6 * t)) / 3.0
			"music_tension":
				env = (0.5 + 0.5 * sin(TAU * 1.0 * t)) * 0.3
				s = 2.0 * fmod(110.0 * t, 1.0) - 1.0
			"music_combat":
				env = 1.0 if fmod(t * 4.0, 1.0) < 0.45 else 0.0
				env *= 0.3
				s = 1.0 if fmod(220.0 * t, 1.0) < 0.5 else -1.0
			"music_heartbeat":
				var ph := fmod(t, 1.0)
				env = 0.0
				if ph < 0.5:
					env = (exp(-ph * 18.0)
							+ (0.6 * exp(-(ph - 0.18) * 18.0) if ph > 0.18 else 0.0)) * 0.5
				s = sin(TAU * 58.0 * t)
			_:
				env = 0.25
				s = sin(TAU * 440.0 * t)
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 16000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _process(delta: float) -> void:
	_bar_t += delta
	beat_phase = _bar_t / BAR
	if _bar_t >= BAR:
		_bar_t -= BAR
		_on_bar()
	# smooth fades toward targets (about one bar to travel 40 dB)
	for stem in _layers:
		var p: AudioStreamPlayer = _layers[stem]
		p.volume_db = move_toward(p.volume_db, _targets[stem], delta * 40.0 / BAR * 4.0)
	# heartbeat tempo follows heat continuously
	var hb: AudioStreamPlayer = _layers.get("music_heartbeat")
	if hb:
		hb.pitch_scale = lerpf(0.9, 1.55, clampf(heat / 5.0, 0.0, 1.0))


## Volume targets change only here - on the beat, effectively.
func _on_bar() -> void:
	if state == State.RESOLVE:
		if Time.get_ticks_msec() >= _resolve_until:
			state = State.EXPLORE
			_set_explore_targets()
		else:
			return
	if Time.get_ticks_msec() >= _hold_until:
		_scan_game()
	match state:
		State.EXPLORE:
			_set_explore_targets()
		State.TENSION:
			_targets["music_bed"] = -16.0
			_targets["music_tension"] = -12.0
			_targets["music_combat"] = -60.0
			_targets["music_heartbeat"] = -30.0 if heat > 0.5 else -44.0
		State.COMBAT:
			_targets["music_bed"] = -20.0
			_targets["music_tension"] = -15.0
			# the combat layer rises with the style rank (D..S -> -14..-6 dB)
			_targets["music_combat"] = lerpf(-14.0, -6.0, clampf(style_rank / 4.0, 0.0, 1.0))
			_targets["music_heartbeat"] = lerpf(-28.0, -18.0, clampf(heat / 5.0, 0.0, 1.0))


func _set_explore_targets() -> void:
	_targets["music_bed"] = -14.0
	_targets["music_tension"] = -60.0
	_targets["music_combat"] = -60.0
	_targets["music_heartbeat"] = -38.0 if heat > 1.0 else -60.0


## Who is near the hero right now? Sets state and handles the resolve flow.
func _scan_game() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		if state == State.COMBAT or state == State.TENSION:
			state = State.EXPLORE
		return
	var nearest := 999.0
	var engaged := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state == CLS_Enemy.State.DOWN:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		nearest = minf(nearest, d)
		if d < 8.0:
			engaged += 1
	var style := get_tree().get_first_node_in_group("style") as Control
	if style and style.has_method("rank"):
		style_rank = style.rank()
	# provisional heat until the economy phase drives the real value
	var wanted := maxf(heat, clampf(engaged - 1.0, 0.0, 2.0))
	if not is_equal_approx(wanted, heat) and state != State.RESOLVE:
		heat = lerpf(heat, wanted, 0.5)

	if state == State.RESOLVE:
		return
	# rebuild step 3 transitional: the new hero has no `state` yet -
	# null-safe read keeps this poll alive until the audio step replaces it
	var pstate = player.get("state") if player else null
	if nearest < 4.0 or pstate == CLS_Player.State.PUNCH or pstate == CLS_Player.State.DODGE:
		if state == State.COMBAT:
			_combat_calm = 0.0
		else:
			state = State.COMBAT
			_combat_calm = 0.0
	elif state == State.COMBAT:
		_combat_calm += BAR
		if _combat_calm >= 2.0 * BAR:  # two calm bars -> resolve
			_begin_resolve()
	elif nearest < 10.0:
		state = State.TENSION
	else:
		state = State.EXPLORE


func _begin_resolve() -> void:
	state = State.RESOLVE
	_resolve_until = Time.get_ticks_msec() + 6500
	_resolve_count += 1
	for stem in _targets:
		_targets[stem] = -60.0
	_resolve_one.stream = load("res://assets/audio/music_resolve.wav")
	_resolve_one.volume_db = -7.0
	_resolve_one.play()
	Log.info("Music: resolve after combat")


## --- public API (economy, dialogue and tests drive these) --------------------

func set_heat(h: float) -> void:
	heat = clampf(h, 0.0, 5.0)


func set_style_rank(r: int) -> void:
	style_rank = clampi(r, 0, 4)


## Dialogue duck: dip the whole Music bus, restore after `dur` seconds.
func duck(db := -8.0, dur := 1.5) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var base := AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, base + db)
	var t := get_tree().create_timer(dur)
	t.timeout.connect(func() -> void:
		AudioServer.set_bus_volume_db(idx, AudioServer.get_bus_volume_db(idx) - db))


## Force a state (tests, cutscenes). Holds for 15 s against the world scan.
func force_state(s: String) -> void:
	_hold_until = Time.get_ticks_msec() + 15000
	match s:
		"explore":
			state = State.EXPLORE
			_set_explore_targets()
		"tension":
			state = State.TENSION
		"combat":
			state = State.COMBAT
			heat = maxf(heat, 2.0)
		"resolve":
			_begin_resolve()
	_on_bar()


func layer_vol(stem: String) -> float:
	var p: AudioStreamPlayer = _layers.get(stem)
	return p.volume_db if p else -99.0
