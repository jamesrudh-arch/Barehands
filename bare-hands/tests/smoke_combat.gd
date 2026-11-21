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
var _posture_peak := 0.0
var _posture_broke := false
var _posture_hold := false
var _posture_landed := 0
var _posture_hp_last := 30
var _posture_pf := -1
var _posture_saw_heavy := false
var _posture_opener := false
var _marks_c := {}  # the composure phase's little state machine
var _tele_at := -1
var _dodged := false
var _counter_punched := false
var _hitstunned := false


var _stick: StickInput


## Drive movement through the REAL stick (its anti-drift loop owns move).
func _set_move(v: Vector2) -> void:
	if _stick:
		_stick.debug_set_move(v)


func _ready() -> void:
	# one pair of eyes on the street: the witness multiplier sits at
	# x1.0 and every heat assertion in this suite is deterministic
	Heat.test_pin_eyes = 1
	Settings.set_value("first_run_done", true)  # the picker would lock input
	# batch 7: estrange every friend - this suite owns the knockdown
	# offer path, and a Close friend would save the blow (smoke_friends
	# owns the save path)
	for id in Trust.FRIENDS:
		Trust.add(id, -100.0, "suite")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_stick = _main.get_node("UI/Joystick")
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
		4:
			_posture()
		5:
			_composure()
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
	_set_move(Vector2(0, -1))  # walk east toward the dummy
	if _pf == 10:
		InputBus.queue_punch()  # jab
	if _pf == 28:
		InputBus.queue_punch()  # buffered during the jab -> chains the cross
	if _pf >= 20 and _pf <= 60:
		var a: String = (_player.get_node("Body/Hero") as HeroRig).current()
		if a in ["Punch_Jab", "Punch_Cross"]:
			_saw_punch_anim = true
	if _pf >= 90:
		_set_move(Vector2.ZERO)
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
		_set_move(Vector2(0, -1))  # dodge forward, into the swing
		InputBus.queue_dodge()
	elif _dodged and _pf == impact_at + 5:
		_set_move(Vector2.ZERO)
	if _tele_at > 0 and _pf > impact_at and _pf < impact_at + 200:
		if Engine.time_scale < 1.0:
			_saw_slowmo = true
		if _thug.state == Enemy.State.STAGGER and not _counter_punched:
			_counter_punched = true
			InputBus.queue_punch()  # counter-hit inside the slow-mo window
	# advance on success: the counter knockdown, not a fixed frame budget
	if _counter_punched and _thug.state == Enemy.State.DOWN:
		_set_move(Vector2.ZERO)
		var kind: String = _style.get("_last")
		_check(_saw_slowmo, "well-timed dodge triggered slow motion")
		_check(not _hitstunned, "parry evaded the strike (hero never flinched)")
		_check(_thug.state == Enemy.State.DOWN, "counter-hit knocked the thug down (state %d)" % _thug.state)
		_check(kind == "counter", "style meter recorded the counter (got %s)" % kind)
		_next()
	elif _pf > 400:
		_set_move(Vector2.ZERO)
		_check(false, "parry sequence never completed (thug state %d)" % _thug.state)
		_next()


func _slam() -> void:
	if _pf == 1:  # dummy right beside the street crate, player east of it
		InputBus.clear_queues()  # drop any input carried over
		_set_move(Vector2.ZERO)
		_dummy.global_position = Vector3(-1.4, 0.02, -4.5)
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 5)
		_player.global_position = Vector3(0.1, 0.05, -4.5)
		_player.velocity = Vector3.ZERO
		_player.state = Player.State.GROUND
		_face_west()
	_set_move(Vector2(0, -1))  # herd the dummy toward the crate
	if _pf == 10:
		InputBus.queue_punch()  # jab (light: no slam yet)
	if _pf == 30:
		InputBus.queue_punch()  # buffered cross (heavy) -> slam into the crate
	if _pf >= 130:
		_set_move(Vector2.ZERO)
		var kind: String = _style.get("_last")
		_check(_dummy.state == Enemy.State.DOWN, "cross slammed the dummy into the crate (state %d)" % _dummy.state)
		_check(kind.begins_with("slam"), "style meter recorded the slam (got %s)" % kind)
		_check(Engine.time_scale == 1.0, "time scale restored after the slam")
		_next()


# --- 4: posture break opens the finisher (Batch 2, bible 4A) ------------------


func _posture() -> void:
	if _pf == 1:
		# a FRESH dummy with plenty of hp: the finisher must come from the
		# posture break, not from a low-hp read
		# far WEST, clear of the crate the slam phase left behind: the
		# heavies knock the dummy east ~2 m each and the chase must have room
		_dummy.global_position = Vector3(-14.5, 0.02, 0.5)
		_dummy.velocity = Vector3.ZERO
		_dummy.state = Enemy.State.IDLE
		_dummy.set("hp", 30)
		_dummy.set("posture", 0.0)
		_player.global_position = Vector3(-15.6, 0.05, 0.5)
		_player.velocity = Vector3.ZERO
		_face_east()
		_posture_peak = 0.0
		_posture_broke = false
		_posture_hold = false
		_posture_landed = 0
		_posture_hp_last = 30
	# a fresh HEAVY only when free. The hold must outlast the 0.30 s
	# heavy threshold - releasing early fires the LIGHT instead - so hold
	# until the heavy swing has actually started, then release once it
	# ends. Before each press the dummy is re-snapped in front of the
	# hero: knockback drift must not decide whether the test can reach
	# the bar (the street's props are not this phase's subject).
	_set_move(Vector2(0, -1))
	if _pf >= 10 and not _posture_hold \
			and _player.state != Player.State.PUNCH and not _posture_broke:
		_dummy.velocity = Vector3.ZERO
		_dummy.global_position = _player.global_position + Vector3(1.1, 0.0, 0.0)
		InputBus.punch_press()
		_posture_hold = true
	if _posture_hold:
		if _player.state == Player.State.PUNCH and bool(_player.get("_punch_heavy")):
			_posture_saw_heavy = true
		if _posture_saw_heavy and _player.state != Player.State.PUNCH:
			InputBus.punch_release()
			_posture_hold = false
			_posture_saw_heavy = false
	_posture_peak = maxf(_posture_peak, float(_dummy.get("posture")))
	if _dummy.state == Enemy.State.STAGGER and bool(_dummy.get("_posture_break")):
		_posture_broke = true
		if _posture_pf < 0:
			_posture_pf = _pf
	if _posture_broke and _pf == _posture_pf + 30:
		InputBus.punch_release()
		_set_move(Vector2.ZERO)
		_check(_posture_peak >= 80.0, "heavies fill the posture bar (max %.0f)" % _posture_peak)
		_check(float(_dummy.get("hp")) > 2.0, "finisher came from posture, not low hp (hp %.0f)" % float(_dummy.get("hp")))
	# the opener: a HEAVY on a broken enemy - pressed ONCE when the hero is
	# free (a press every frame would reset the hold age and the heavy
	# threshold would never be reached; a press mid-swing buffers a light)
	if _posture_broke and not _posture_opener and _pf > _posture_pf + 30 \
			and _player.state != Player.State.PUNCH:
		_posture_opener = true
		_dummy.velocity = Vector3.ZERO
		_dummy.global_position = _player.global_position + Vector3(1.1, 0.0, 0.0)
		InputBus.punch_press()
	if _posture_broke and _posture_opener and _posture_saw_heavy \
			and _player.state != Player.State.PUNCH and _pf > _posture_pf + 40:
		InputBus.punch_release()
		_posture_opener = false
	if _posture_broke and _pf == _posture_pf + 160:
		InputBus.punch_release()
		_check(_dummy.state == Enemy.State.DOWN, "the opener executes the broken enemy (state %d)" % _dummy.state)
		_check(Engine.time_scale == 1.0, "time scale clean after the break flow")
		_next()
	if _pf == 800 and not _posture_broke:
		# the break never came - fail honestly and move on
		InputBus.punch_release()
		_set_move(Vector2.ZERO)
		_check(false, "the bar never broke (peak %.0f, landed pattern off)" % _posture_peak)
		_next()


# --- 5: Composure - the guard breaks and heals (Batch 2, bible 4A) ------------


func _composure() -> void:
	if _pf == 1:
		_thug.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
		_thug.velocity = Vector3.ZERO
		_thug.state = Enemy.State.IDLE
		_thug.set("hp", 40)
		_player.velocity = Vector3.ZERO
		_set_move(Vector2.ZERO)
		_face_east()
		_marks_c = {"broke": false, "hitstun_while_broken": false, "healed": false}
		InputBus.dodge_press()  # hold DODGE: the block stance
		# speed the story up: leave a sliver, one blocked strike breaks it
		Composure.reset()
		Composure.drain(Composure.value - Tuning.v("composure_block_drain") - 1.0, "test")
	# The suite has been fighting for minutes by now and the CITY keeps
	# sending heat responders - this phase tests Composure, not the
	# street. Sweep every outsider across the map on every tick and cool
	# the heat; while the guard story plays out the suite thug is held
	# close instead (knockback drift is not this phase's subject).
	var calm_phase: bool = _marks_c.get("broke", false) and _marks_c.get("hitstun_while_broken", false)
	if _pf % 15 == 0:
		Heat.heat = 0.0
		for e in get_tree().get_nodes_in_group("enemy"):
			if calm_phase or e != _thug:
				e.global_position = Vector3(19.0, 0.02, 19.0)
				e.velocity = Vector3.ZERO
	if not calm_phase and _pf % 30 == 0:
		_thug.global_position = _player.global_position + Vector3(1.4, 0.0, 0.0)
		_thug.velocity = Vector3.ZERO
	if not _marks_c["broke"]:
		if Composure.guard_broken():
			_marks_c["broke"] = true
			_marks_c["broke_pf"] = _pf
		if _pf > 900:  # ~15 s without a break: something is wrong
			_check(false, "the guard never broke (composure %.1f)" % Composure.value)
			InputBus.dodge_release()
			_next()
	elif not _marks_c["hitstun_while_broken"]:
		# still holding the (dead) guard: the next strike must GO THROUGH
		if _player.get("_hitstun_until") > _player.get("_t"):
			_marks_c["hitstun_while_broken"] = true
			_marks_c["heal_pf"] = _pf
			_check(true, "a broken guard stops nothing: the strike landed")
			# the knockdown blow puts a RETRY on the table (bible 2-min loop)
			_check(_player.get("_retry_offer") != null, "the knockdown blow offers an instant retry")
		if _pf - _marks_c["broke_pf"] > 360:
			_check(false, "no strike landed while the guard was broken")
			InputBus.dodge_release()
			_next()
	else:
		# release and let the break heal + calm regen refill the bar
		# (the sweep above has cleared the whole street by now)
		InputBus.dodge_release()
		if _pf % 60 == 0:
			print("CPDEBUG pf=%d val=%.1f broken=%s since_drain=%d" % [_pf,
					Composure.value, Composure.guard_broken(),
					Time.get_ticks_msec() - Composure._last_drain_msec])
		# >11 s: past the retry offer's 10 s window AND enough calm regen
		if _pf - _marks_c["heal_pf"] > 660 and not _marks_c["healed"]:
			_marks_c["healed"] = true
			_check(not Composure.guard_broken(), "the break heals on its timer")
			_check(Composure.value > 50.0, "calm regen refills Composure (%.0f)" % Composure.value)
			# the fight this phase fought must have scored a rank at resolve
			_check(FightScore.last_rank >= 0, "the fight scored a rank card at resolve (%s)" % FightScore.RANKS[maxi(FightScore.last_rank, 0)])
			_check(_player.get("_retry_offer") == null, "the retry offer lapsed cleanly")
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