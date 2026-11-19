extends Node
## 5-minute combat stress test (18,000 physics ticks = 5 min at 60 fps).
## A self-driving bot cycles combo / parry / chaos / idle scenarios against the
## dummy and the thug while watching for the "mid-play stop" failure modes:
## stuck states, stuck slow-motion, node/particle leaks, runaway nodes.
## Run:  godot --headless --path . res://tests/stress_combat.tscn

const TOTAL_TICKS := 18000
const CHECK_EVERY := 300
const CYCLE := 600

var _main: Node3D
var _player: CharacterBody3D
var _dummy: CharacterBody3D
var _thug: CharacterBody3D
var _style: Control

var _tick := 0
var _cycle := 0
var _fails := 0
var _punches := 0
var _dodges := 0
var _slowmo_seen := false
var _state_since := {}  # player state -> tick when entered
var _node_baseline := 0
var _node_max := 0
var _max_bursts := 0
var _last_scale_ok_tick := 0  # last tick where time_scale was 1.0
var _tele_at := -1
var _countered := false
var _hits := 0  # landed impacts (Fx.hit_landed), proves punches connect


var _stick: StickInput


## Drive movement through the REAL stick (its anti-drift loop owns move).
func _set_move(v: Vector2) -> void:
	if _stick:
		_stick.debug_set_move(v)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_stick = _main.get_node("UI/Joystick")
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()  # the bot drives input itself
	_player = _main.get_node("Player") as CharacterBody3D
	_dummy = _main.get_node("Dummy") as CharacterBody3D
	_thug = _main.get_node("Thug") as CharacterBody3D
	_style = get_tree().get_first_node_in_group("style") as Control
	Fx.hit_landed.connect(func(_kind: String, _pos: Vector3) -> void: _hits += 1)
	_node_baseline = get_tree().get_node_count()
	_node_max = _node_baseline
	Log.info("stress: begin, baseline nodes %d" % _node_baseline)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_cycle = _tick / CYCLE + 1
	if Engine.time_scale == 1.0:
		_last_scale_ok_tick = _tick
	else:
		_slowmo_seen = true  # slow-mo windows are short: sample every tick
	match _cycle % 4:
		0:
			_drive_combo()
		1:
			_drive_parry()
		2:
			_drive_chaos()
		_:
			_drive_idle()
	_track_player_state()
	if _tick % CHECK_EVERY == 0:
		_health_check()
	if _tick >= TOTAL_TICKS:
		_finish()


func _phase_reset() -> void:
	InputBus.clear_queues()
	_set_move(Vector2.ZERO)
	InputBus.release_sprint()
	_tele_at = -1
	_countered = false


# --- scenarios ---------------------------------------------------------------


func _drive_combo() -> void:
	if _tick % CYCLE == 1:
		_phase_reset()
		_park_thug()
		_dummy.global_position = Vector3(-4.5, 0.02, 0.5)
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 5)
		_player.global_position = Vector3(-5.6, 0.02, 0.5)
		_player.velocity = Vector3.ZERO
		_player.set("_yaw", -PI / 2.0)
		_player.get_node("Body").rotation.y = -PI / 2.0
		var cam := _main.get_node("Camera") as Camera3D
		cam.set("_yaw", -PI / 2.0)
	_set_move(Vector2(0, -1))  # walk east toward the dummy
	var ph := _tick % CYCLE
	if ph in [150, 310, 470]:
		InputBus.queue_punch()
		_punches += 1
	if ph in [155, 315]:  # second press while the jab swings: buffering
		InputBus.queue_punch()
		_punches += 1
	if ph in [230, 390]:
		InputBus.queue_dodge()
		_dodges += 1


func _drive_parry() -> void:
	var ph := _tick % CYCLE
	if ph == 1:
		_phase_reset()
		_thug.global_position = Vector3(-13.0, 0.02, 0.0)
		_thug.velocity = Vector3.ZERO
		_thug.state = Enemy.State.IDLE
		_thug.set("_state_t", 0.0)
		_player.global_position = Vector3(-11.5, 0.02, 0.0)
		_player.velocity = Vector3.ZERO
		_player.set("_yaw", PI / 2.0)
		_player.get_node("Body").rotation.y = PI / 2.0
		var cam := _main.get_node("Camera") as Camera3D
		cam.set("_yaw", PI / 2.0)
	if _tele_at < 0 and _thug.state == Enemy.State.TELEGRAPH:
		_tele_at = ph
	if _tele_at > 0 and ph == _tele_at + 40 and not _countered:
		InputBus.queue_dodge()
		_dodges += 1
		_set_move(Vector2(0, -1))
	elif _tele_at > 0 and ph == _tele_at + 55:
		_set_move(Vector2.ZERO)
	if _tele_at > 0 and ph == _tele_at + 60 and not _countered:
		_countered = true
		InputBus.queue_punch()
		_punches += 1


func _drive_chaos() -> void:
	var ph := _tick % CYCLE
	if ph == 1:
		_phase_reset()
		_park_thug()
		_player.global_position = Vector3(randf_range(-15, 15), 0.02, randf_range(-15, 15))
		_player.velocity = Vector3.ZERO
	if ph % 30 == 0:
		_set_move(Vector2(randf_range(-1, 1), randf_range(-1, 1)).limit_length(1.0))
		InputBus.release_sprint() if randf() <= 0.5 else InputBus.press_sprint()
	if ph % 45 == 0:
		InputBus.queue_jump()
	if ph % 60 == 10:
		InputBus.queue_punch()
		_punches += 1
	if ph % 60 == 40:
		InputBus.queue_dodge()
		_dodges += 1


func _drive_idle() -> void:
	if _tick % CYCLE == 1:
		_phase_reset()
		_park_thug()  # decay, style meter drain, nothing pressed


## The thug follows the player anywhere on the block; only the parry cycle
## wants him around, so the other scenarios park him in a far corner.
func _park_thug() -> void:
	_thug.global_position = Vector3(17.0, 0.02, 17.0)
	_thug.velocity = Vector3.ZERO
	_thug.state = Enemy.State.IDLE
	_thug.set("_state_t", 0.0)


# --- watchdogs ---------------------------------------------------------------


func _track_player_state() -> void:
	var s: int = _player.state
	if _state_since.is_empty() or not _state_since.has(s):
		_state_since = { s: _tick }
	var in_state: int = _tick - int(_state_since[s])
	var limit: int = { Player.State.PUNCH: 90, Player.State.DODGE: 60,
			Player.State.CLIMB: 140 }.get(s, 18000)  # ticks
	if in_state > limit:
		_fail("player stuck in %s for %d ticks" % [Player.State.find_key(s), in_state])
		_state_since = { s: _tick }


func _health_check() -> void:
	if Engine.time_scale != 1.0 and _tick - _last_scale_ok_tick > 360:
		# 6 s with no return to normal scale (watchdog should have caught it)
		_fail("time_scale stuck at %.2f for %d ticks" % [Engine.time_scale, _tick - _last_scale_ok_tick])
		Engine.time_scale = 1.0
	for e in [_dummy, _thug]:
		if e.state < 0 or e.state > 7:
			_fail("enemy %s in invalid state %d" % [e.name, e.state])
		if not (is_finite(e.global_position.x) and is_finite(e.global_position.z)):
			_fail("enemy %s position not finite" % e.name)
	_max_bursts = maxi(_max_bursts, Fx._bursts_alive)
	if Fx._bursts_alive > 40:
		_fail("particle bursts leaking: %d in flight" % Fx._bursts_alive)
	_node_max = maxi(_node_max, get_tree().get_node_count())


func _finish() -> void:
	_health_check()
	var nodes_end := get_tree().get_node_count()
	_check(_node_max - _node_baseline <= 150,
			"node count stable (baseline %d, max %d, end %d)" % [_node_baseline, _node_max, nodes_end])
	_check(Engine.time_scale == 1.0, "time_scale back to 1.0 at exit")
	_check(_slowmo_seen, "parry slow-mo actually exercised")
	_check(_punches > 50 and _dodges > 20, "bot actually fought (%d punches, %d dodges)" % [_punches, _dodges])
	_check(_hits > 20, "punches actually landed (%d impacts)" % _hits)
	print("STRESS summary: ticks %d | punches %d | dodges %d | hits %d | slowmo %s | style $%d | max bursts %d | nodes %d/%d"
			% [_tick, _punches, _dodges, _hits, _slowmo_seen, _style.cash, _max_bursts, _node_baseline, _node_max])
	Log.info("stress: done, %d fails" % _fails)
	if _fails == 0:
		print("STRESS PASS")
		get_tree().quit(0)
	else:
		print("STRESS FAIL (%d problems)" % _fails)
		get_tree().quit(1)


func _fail(what: String) -> void:
	_fails += 1
	print("STRESS FAIL: ", what)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("STRESS ok: " if ok else "STRESS FAIL: ", what)