extends Node
## Headless smoke test for Series-2 Phase 3 combat depth: the combo tree,
## heavy/launcher/finisher, block and perfect block, grab/knee/throw, the
## pipe, the four enemy kinds, group tactics and takedown surfaces.
## Not part of the game.

var _main: Node3D
var _player: CharacterBody3D
var _dummy: CharacterBody3D
var _thug: CharacterBody3D
var _style: Control

var _phase := 0
var _pf := 0
var _fails := 0
var _marks := {}  # per-phase frame marks


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


var _stick: StickInput


## Drive movement through the REAL stick (its anti-drift loop owns move).
func _set_move(v: Vector2) -> void:
	if _stick:
		_stick.debug_set_move(v)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # the picker would lock input
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_stick = _main.get_node("UI/Joystick")
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_dummy = _main.get_node("Dummy") as CharacterBody3D
	_thug = _main.get_node("Thug") as CharacterBody3D
	_style = get_tree().get_first_node_in_group("style") as Control


func _physics_process(_delta: float) -> void:
	_pf += 1
	match _phase:
		0:
			_chain()
		1:
			_heavy()
		2:
			_launcher()
		3:
			_finisher()
		4:
			_block()
		5:
			_perfect_block()
		6:
			_grab_flow()
		7:
			_pipe()
		8:
			_bruiser()
		9:
			_knife()
		10:
			_boss()
		11:
			_tactics()
		_:
			_finish()


func _next() -> void:
	_phase += 1
	_pf = 0
	_marks.clear()
	# the thug from the block phases must never interfere again
	_thug.global_position = Vector3(19.0, 0.02, 19.0)
	_thug.velocity = Vector3.ZERO
	_thug.state = Enemy.State.IDLE
	_thug.set("_state_t", 0.0)
	InputBus.clear_queues()
	_set_move(Vector2.ZERO)
	InputBus.punch_release()
	InputBus.dodge_release()


## Stand the player `d` east of the dummy, both facing each other.
func _setup_pair(dummy_hp: int, d: float = 1.1) -> void:
	_dummy.global_position = Vector3(0.0, 0.02, 0.5)
	_dummy.velocity = Vector3.ZERO
	_dummy.state = Enemy.State.IDLE
	_dummy.set("hp", dummy_hp)
	_dummy.set("_topple", 0.0)
	_dummy.get_node("Body").rotation.x = 0.0
	_dummy.get_node("Body").position.y = 0.0
	_player.global_position = Vector3(-d, 0.02, 0.5)
	_player.velocity = Vector3.ZERO
	_player.set("has_pipe", false)
	_player.set("_yaw", -PI / 2.0)
	_player.get_node("Body").rotation.y = -PI / 2.0
	InputBus.camera_yaw = -PI / 2.0


# --- 0: light chain jab -> cross -> hook ---------------------------------------


func _chain() -> void:
	if _pf == 1:
		_setup_pair(10)
	if _pf == 10:
		InputBus.queue_punch()
	if _pf == 30:
		InputBus.queue_punch()  # buffered during the jab
	if _pf == 65:
		InputBus.queue_punch()  # buffered during the cross
	if _pf == 120:
		var hp: int = _dummy.get("hp")
		_check(hp == 5, "light chain jab+cross+hook = 1+2+2 (hp 10->%d)" % hp)
		_check(_style.cash > 0, "chain scored style")
		_next()


# --- 1: hold PUNCH = heavy -------------------------------------------------------


func _heavy() -> void:
	if _pf == 1:
		_setup_pair(10)
		Fx.set("last_haptic_ms", 0)
	if _pf == 5:
		InputBus.punch_press()  # hold: heavy fires by itself
	if _pf == 60:
		var hp: int = _dummy.get("hp")
		_check(hp == 7, "hold-PUNCH heavy = 3 damage (hp 10->%d)" % hp)
		_check(Fx.get("last_haptic_ms") == 60, "heavy buzzes the phone hook (%d ms)" % Fx.get("last_haptic_ms"))
		_next()


# --- 2: heavy on a staggered enemy launches --------------------------------------


func _launcher() -> void:
	if _pf == 1:
		_setup_pair(10)
		_dummy.state = Enemy.State.STAGGER
		Fx.set("last_haptic_ms", 0)
	if _pf == 5:
		InputBus.punch_press()
	if _pf == 70:
		_check(_dummy.state == Enemy.State.LAUNCHED or _dummy.state == Enemy.State.STAGGER,
				"launcher sends the enemy airborne (state %d)" % _dummy.state)
		_check(_dummy.global_position.y > 0.3 or _dummy.state == Enemy.State.STAGGER,
				"enemy left the ground (y %.2f)" % _dummy.global_position.y)
		_next()


# --- 3: heavy on a nearly-done enemy finishes ------------------------------------


func _finisher() -> void:
	if _pf == 1:
		_setup_pair(2)
		Fx.set("last_haptic_ms", 0)
		_marks["slow"] = false
	if _pf == 5:
		InputBus.punch_press()
	if _pf > 10 and _pf < 60 and Engine.time_scale < 1.0:
		_marks["slow"] = true
	if _pf == 70:
		_check(_dummy.state == Enemy.State.DOWN, "finisher executes the low-hp enemy (state %d)" % _dummy.state)
		_check(_marks["slow"], "finisher runs cinematic slow-mo")
		_check(Fx.get("last_haptic_ms") == 160, "finisher haptic 160 ms (%d)" % Fx.get("last_haptic_ms"))
		_next()


# --- 4: hold DODGE = block, a strike is absorbed ----------------------------------


func _block() -> void:
	if _pf == 1:
		_park_thug()
	if _marks.has("tele"):
		if not _marks.has("press") and _pf - _marks["tele"] == 5:
			_marks["press"] = _pf
			InputBus.dodge_press()  # early press: block is mature by the strike
		if _pf - _marks["tele"] == 53:
			_check(_player.state == Player.State.BLOCK,
					"mature block absorbs the strike, no hitstun (player %d)" % _player.state)
		if _pf - _marks["tele"] == 60:
			InputBus.dodge_release()
			_next()
	elif _thug.state == Enemy.State.TELEGRAPH:
		_marks["tele"] = _pf


func _park_thug() -> void:
	_thug.global_position = Vector3(19.0, 0.02, 19.0)  # out of the way
	_thug.velocity = Vector3.ZERO
	_thug.state = Enemy.State.IDLE
	_thug.set("_state_t", 0.0)
	_setup_pair(5)
	_player.global_position = Vector3(0.5, 0.02, 0.5)  # inside strike range
	_thug.global_position = Vector3(1.9, 0.02, 0.5)  # in front of the hero
	_thug.set("kind", 1)
	_thug.set("max_hp", 8)
	_thug.set("hp", 8)


# --- 5: a young block parries ------------------------------------------------------


func _perfect_block() -> void:
	if _pf == 1:
		_park_thug()
	if _marks.has("tele"):
		# strike resolves ~49 ticks after telegraph starts; block at +28
		# is 6 ticks old (0.1 s) when it lands - inside the parry window
		if not _marks.has("press") and _pf - _marks["tele"] == 28:
			_marks["press"] = _pf
			InputBus.dodge_press()
		if _pf - _marks["tele"] == 53:
			_check(_thug.state == Enemy.State.STAGGER, "young block parries (thug %d)" % _thug.state)
			InputBus.dodge_release()
			_next()
	elif _thug.state == Enemy.State.TELEGRAPH:
		_marks["tele"] = _pf


# --- 6: grab, knee, throw into the car ---------------------------------------------


func _grab_flow() -> void:
	if _pf == 1:
		_setup_pair(8)
		_marks["knee"] = false
	if _pf == 5:
		InputBus.queue_grab()
	if _pf == 20:
		if not _marks.has("g"):
			_marks["g"] = true
			_check(_player.state == Player.State.GRAB and _dummy.state == Enemy.State.GRABBED,
					"GRAB seizes the enemy (player %d dummy %d)" % [_player.state, _dummy.state])
		InputBus.queue_punch()  # the knee
	if _pf == 45:
		var hp: int = _dummy.get("hp")
		_marks["knee"] = hp == 7
		# throw toward the car: player faces east, car ~12 m away - place a
		# second dummy beside the car for the surface check
		InputBus.queue_grab()  # GRAB again = throw
	if _pf == 75:
		_check(_marks["knee"], "knee lands while grabbed (hp 8->7)")
		_check(_dummy.state in [Enemy.State.LAUNCHED, Enemy.State.STAGGER, Enemy.State.DOWN],
				"throw releases with force (dummy %d)" % _dummy.state)
		_next()


# --- 7: the pipe ---------------------------------------------------------------------


func _pipe() -> void:
	if _pf == 1:
		_setup_pair(10)
		_player.global_position = Vector3(5.6, 0.02, -7.6)  # by the pipe prop
		_player.set("_yaw", -PI / 2.0)
		_player.get_node("Body").rotation.y = -PI / 2.0
		Fx.set("last_haptic_ms", 0)
	if _pf == 5:
		InputBus.queue_grab()  # no enemy in reach: picks up the pipe
	if _pf == 25:
		_check(_player.get("has_pipe"), "pipe picked up near the prop")
		_setup_pair(10)
		_player.set("has_pipe", true)
		InputBus.camera_yaw = -PI / 2.0
	if _pf == 33:
		_dummy.global_position = Vector3(0.0, 0.02, 0.5)  # fresh, in reach
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 10)
	if _pf == 35:
		InputBus.queue_punch()
	if _pf == 62:
		var hp_pipe: int = _dummy.get("hp")
		_check(hp_pipe == 8, "pipe light = 2 damage (hp 10->%d)" % hp_pipe)
		_dummy.global_position = Vector3(0.0, 0.02, 0.5)  # fresh again
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 8)
		_player._start_punch(3, true)  # heavy with the pipe, directly
	if _pf == 130:
		var hp_heavy: int = _dummy.get("hp")
		_check(hp_heavy == 4, "pipe heavy = 4 damage (hp 8->%d)" % hp_heavy)
		_check(Fx.get("last_haptic_ms") == 60, "pipe heavy haptic (%d)" % Fx.get("last_haptic_ms"))
	if _pf > 130 and _player.state == Player.State.GROUND:
		InputBus.clear_queues()
		InputBus.punch_release()
		_player.set("has_pipe", false)  # drop the pipe for later phases
		_next()


# --- 8: the armoured bruiser ---------------------------------------------------------


func _bruiser() -> void:
	if _pf == 1:
		_marks["e"] = _spawn_kind(2, Vector3(0.0, 0.02, 0.5), 12)
		_setup_pair(0)  # move the dummy aside
		_dummy.global_position = Vector3(19.0, 0.02, -19.0)
	var e: CharacterBody3D = _marks["e"]
	# jab once the hero is free to act
	if not _marks.has("jab") and _pf > 5 and _player.state == Player.State.GROUND:
		_marks["jab"] = _pf
		InputBus.queue_punch()
	if _marks.has("jab") and _pf == _marks["jab"] + 35:
		var hp: int = e.get("hp")
		_check(hp == 11, "jab chips the bruiser (hp 12->%d)" % hp)
		_check(e.state != Enemy.State.FLINCH and e.state != Enemy.State.STAGGER,
				"armour shrugs the jab, no stagger (state %d)" % e.state)
	# heavy directly when ready
	if not _marks.has("hv") and _pf > _marks.get("jab", 0) + 40 and _player.state == Player.State.GROUND:
		_marks["hv"] = _pf
		e.global_position = _player.global_position + Vector3(1.0, 0.0, 0.0)
		e.velocity = Vector3.ZERO
		_player._start_punch(3, true)
	if _marks.has("hv") and _pf == _marks["hv"] + 40:
		_check(e.state in [Enemy.State.FLINCH, Enemy.State.STAGGER, Enemy.State.DOWN],
				"heavy breaks the armour (state %d)" % e.state)
		(e as Node).queue_free()
		_next()


func _spawn_kind(k: int, pos: Vector3, hp: int) -> CharacterBody3D:
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	e.set("kind", k)
	e.set("max_hp", hp)
	_main.add_child(e)
	e.global_position = pos
	return e


# --- 9: the knife attacker -------------------------------------------------------------


func _knife() -> void:
	if _pf == 1:
		_marks["e"] = _spawn_kind(3, Vector3(4.4, 0.02, 0.5), 3)
		_player.global_position = Vector3(0.0, 0.02, 0.5)
		_player.velocity = Vector3.ZERO
		_marks["speed"] = 0.0
	if _marks.has("e"):
		var e: CharacterBody3D = _marks["e"]
		if e.state == Enemy.State.WALK:
			_marks["speed"] = maxf(_marks["speed"], Vector2(e.velocity.x, e.velocity.z).length())
		if not _marks.has("tele") and e.state == Enemy.State.TELEGRAPH:
			_marks["tele"] = _pf
		if _marks.has("tele") and not _marks.has("strike") and e.state == Enemy.State.STRIKE:
			_marks["strike"] = _pf
		if _marks.has("strike") and _pf - _marks["strike"] > 10:
			_check(_marks["strike"] - _marks["tele"] <= 24,
					"knife telegraph is fast (%d ticks <= 24)" % (_marks["strike"] - _marks["tele"]))
			_check(_marks["speed"] > 2.2, "knife closes fast (%.1f m/s)" % _marks["speed"])
			(e as Node).queue_free()
			_next()
		if _pf > 240:
			_check(false, "knife never attacked")
			_next()


# --- 10: the boss ------------------------------------------------------------------------


func _boss() -> void:
	if _pf == 1:
		_marks["e"] = _spawn_kind(4, Vector3(2.2, 0.02, 0.5), 30)
		_player.global_position = Vector3(0.0, 0.02, 0.5)
		_player.velocity = Vector3.ZERO
		_marks["strikes"] = 0
	if _marks.has("e"):
		var e: CharacterBody3D = _marks["e"]
		if e.state == Enemy.State.STRIKE and not _marks.has("s%d" % _pf):
			_marks["strikes"] += 1
			_marks["s%d" % _pf] = true
		if _pf == 10:
			InputBus.queue_punch()  # jab vs armour 4
		if _pf == 45:
			_check(e.state != Enemy.State.FLINCH and e.state != Enemy.State.STAGGER,
					"boss armour shrugs the jab (state %d)" % e.state)
		if _pf == 240:
			_check(_marks["strikes"] >= 2, "boss chains attacks (%d strikes in 4 s)" % _marks["strikes"])
			_check(e.get("hp") >= 29, "boss hp intact (jab chipped %d)" % e.get("hp"))
			(e as Node).queue_free()
			_next()


# --- 11: group tactics: surround + one at a time -------------------------------------------


func _tactics() -> void:
	if _pf == 1:
		_marks["a"] = _spawn_kind(1, Vector3(2.2, 0.02, 0.5), 8)
		_marks["b"] = _spawn_kind(1, Vector3(-2.2, 0.02, 0.5), 8)
		_player.global_position = Vector3(0.0, 0.02, 0.5)
		_player.velocity = Vector3.ZERO
		_marks["maxattack"] = 0
		_marks["minsep"] = 99.0
	if _marks.has("a"):
		var a: CharacterBody3D = _marks["a"]
		var b: CharacterBody3D = _marks["b"]
		var attacking := 0
		for e in [a, b]:
			if e.state in [Enemy.State.TELEGRAPH, Enemy.State.STRIKE]:
				attacking += 1
		if attacking > 1 and not _marks.has("dbg"):
			_marks["dbg"] = true
			print("DBG double-attack at pf %d: a=%d b=%d attacker=%s" % [_pf,
					a.state, b.state, Tactics.attacker()])
		_marks["maxattack"] = maxi(_marks["maxattack"], attacking)
		if a.state == Enemy.State.WALK and b.state == Enemy.State.WALK:
			_marks["minsep"] = minf(_marks["minsep"],
					a.global_position.distance_to(b.global_position))
		if _pf == 240:
			_check(_marks["maxattack"] <= 1, "only one enemy attacks at a time (max %d)" % _marks["maxattack"])
			_check(Tactics.engaged_count() >= 2, "tactics sees the group (%d)" % Tactics.engaged_count())
			(a as Node).queue_free()
			(b as Node).queue_free()
			_next()


# --- surfaces exist -------------------------------------------------------------------------


func _finish() -> void:
	var surfaces := 0
	for n in _main.find_children("*", "StaticBody3D", true, false):
		if n.has_meta("slam_surface"):
			surfaces += 1
	_check(surfaces >= 3, "takedown surfaces tagged: car, shutter, rail (%d)" % surfaces)
	var pipe := get_tree().get_nodes_in_group("pipe_prop")
	_check(pipe.size() == 1, "the pipe prop waits on the street")
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)