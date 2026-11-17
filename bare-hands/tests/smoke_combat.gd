extends Node
## Headless smoke test for Batch 3 combat — not part of the game.
## Run from the project folder:  godot --headless res://tests/smoke_combat.tscn
## Checks: jab->cross combo with buffering, dummy flinch/knockback, per-enemy
## materials, style repetition penalty, thug telegraph -> parry slow-mo ->
## counter knockdown, environmental slam into a crate, time_scale restored.

# states live in the named enums (scripts/enemy.gd, scripts/player.gd)

var _main: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _dummy: CharacterBody3D
var _thug: CharacterBody3D
var _style: Control
var _fails := 0
var _phase := 0
var _pf := 0

var _saw_punch_anim := false
var _saw_slowmo := false
var _tele_at := -1
var _dodged := false
var _counter_punched := false
var _hitstunned := false


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()  # tests drive input themselves
	_player = _main.get_node("Player") as CharacterBody3D
	_camera = _main.get_node("Camera") as Camera3D
	_dummy = _main.get_node("Dummy") as CharacterBody3D
	_thug = _main.get_node("Thug") as CharacterBody3D
	_style = get_tree().get_first_node_in_group("style") as Control


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _flat(p: CharacterBody3D) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _physics_process(_delta: float) -> void:
	_pf += 1
	if _player.get("_hitstun_until") > _player.get("_t"):
		_hitstunned = true
	match _phase:
		0:
			_combo()
		1:
			_repeat()
		2:
			_parry()
		3:
			_slam()
		_:
			_finish()


func _next() -> void:
	_phase += 1
	_pf = 0


func _face_east() -> void:
	_camera.set("_yaw", -PI / 2.0)
	_camera.global_position = _player.global_position + Vector3(-6.5, 3.0, 0.0)


func _face_west() -> void:
	_camera.set("_yaw", PI / 2.0)
	_camera.global_position = _player.global_position + Vector3(6.5, 3.0, 0.0)


func _combo() -> void:
	if _pf == 1:  # dummy mid-street, nothing behind it to slam into
		_dummy.global_position = Vector3(-4.5, 0.02, 0.5)
		_dummy.velocity = Vector3.ZERO
		_player.global_position = Vector3(-5.6, 0.05, 0.5)
		_player.velocity = Vector3.ZERO
		_face_east()
	InputBus.move = Vector2(0, -1)  # walk east toward the dummy
	if _pf == 10:
		InputBus.queue_punch()  # jab
	if _pf == 28:
		InputBus.queue_punch()  # buffered during the jab -> chains the cross
	if _pf >= 20 and _pf <= 60:
		var a: String = (_player.get_node("Body/Hero") as HeroRig).current()
		if a in ["Punch_Jab", "Punch_Cross"]:
			_saw_punch_anim = true
	if _pf >= 90:
		InputBus.move = Vector2.ZERO
		var hp: int = _dummy.get("hp")
		_check(_saw_punch_anim, "punch clips play (Punch_Jab / Punch_Cross)")
		_check(hp == 2, "jab+cross landed, dummy hp 5->2 (got %d)" % hp)
		_check(_dummy.global_position.x > -4.3, "dummy knocked back east (x %.2f)" % _dummy.global_position.x)
		_check(_dummy.state != Enemy.State.DOWN, "dummy flinched rather than died")
		_check(_style.cash >= 14, "style cash earned from the combo ($%d)" % _style.cash)
		_check(_thug.get("_flash") == 0.0, "thug materials independent (no cross-flash)")
		_check(Engine.time_scale == 1.0, "hit-stop restored time scale")
		_next()


func _repeat() -> void:
	if _pf == 1:
		var g1: float = _style.add("jab")
		var g2: float = _style.add("jab")
		_check(g2 < g1, "repeating the same move earns less (%.1f then %.1f)" % [g1, g2])
		_next()


func _parry() -> void:
	if _pf == 1:
		_thug.global_position = Vector3(-13.0, 0.02, 0.0)
		_thug.velocity = Vector3.ZERO
		_thug.state = Enemy.State.IDLE
		_thug.set("_state_t", 0.0)
		_player.global_position = Vector3(-11.5, 0.02, 0.0)
		_player.velocity = Vector3.ZERO
		_player.set("_yaw", PI / 2.0)  # face the thug (west)
		_player.get_node("Body").rotation.y = PI / 2.0
		_face_west()
	if _tele_at < 0 and _thug.state == Enemy.State.TELEGRAPH:
		_tele_at = _pf
	# thug: 0.6 s telegraph, then the fist lands 0.22 s into the strike
	var impact_at := _tele_at + 36 + 13
	if _tele_at > 0 and _pf == impact_at - 9 and not _dodged:
		_dodged = true
		InputBus.move = Vector2(0, -1)  # dodge forward, into the swing
		InputBus.queue_dodge()
	elif _dodged and _pf == impact_at + 5:
		InputBus.move = Vector2.ZERO
	if _tele_at > 0 and _pf > impact_at and _pf < impact_at + 200:
		if Engine.time_scale < 1.0:
			_saw_slowmo = true
		if _thug.state == Enemy.State.STAGGER and not _counter_punched:
			_counter_punched = true
			InputBus.queue_punch()  # counter-hit inside the slow-mo window
	# advance on success: the counter knockdown, not a fixed frame budget
	if _counter_punched and _thug.state == Enemy.State.DOWN:
		InputBus.move = Vector2.ZERO
		var kind: String = _style.get("_last")
		_check(_saw_slowmo, "well-timed dodge triggered slow motion")
		_check(not _hitstunned, "parry evaded the strike (hero never flinched)")
		_check(_thug.state == Enemy.State.DOWN, "counter-hit knocked the thug down (state %d)" % _thug.state)
		_check(kind == "counter", "style meter recorded the counter (got %s)" % kind)
		_next()
	elif _pf > 400:
		InputBus.move = Vector2.ZERO
		_check(false, "parry sequence never completed (thug state %d)" % _thug.state)
		_next()


func _slam() -> void:
	if _pf == 1:  # dummy right beside the street crate, player east of it
		InputBus.clear_queues()  # drop any input carried over
		InputBus.move = Vector2.ZERO
		_dummy.global_position = Vector3(-1.4, 0.02, -4.5)
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 5)
		_player.global_position = Vector3(0.1, 0.05, -4.5)
		_player.velocity = Vector3.ZERO
		_player.state = Player.State.GROUND
		_face_west()
	InputBus.move = Vector2(0, -1)  # herd the dummy toward the crate
	if _pf == 10:
		InputBus.queue_punch()  # jab (light: no slam yet)
	if _pf == 30:
		InputBus.queue_punch()  # buffered cross (heavy) -> slam into the crate
	if _pf >= 130:
		InputBus.move = Vector2.ZERO
		var kind: String = _style.get("_last")
		_check(_dummy.state == Enemy.State.DOWN, "cross slammed the dummy into the crate (state %d)" % _dummy.state)
		_check(kind == "slam", "style meter recorded the slam (got %s)" % kind)
		_check(Engine.time_scale == 1.0, "time scale restored after the slam")
		_next()


func _finish() -> void:
	_check(Engine.time_scale == 1.0, "Engine.time_scale back to 1.0 at exit")
	_check(_style.cash > 0, "cash points banked for the batch ($%d)" % _style.cash)
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)
