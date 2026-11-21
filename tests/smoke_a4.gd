extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_ComboCounter := preload("res://scripts/combo_counter.gd")
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_MoveListUI := preload("res://scripts/move_list.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_StickInput := preload("res://scripts/stick_input.gd")
const CLS_TouchButtons := preload("res://scripts/touch_buttons.gd")
## Stage A4 suite: combos and the SUPER strike. Direction+PUNCH variants
## (forward lunge, backfist counter, uppercut launcher), the jab-cross-hook
## chain, the combo counter, the SUPER meter filling from hits and parries,
## the super strike shockwave, the MOVES screen, the training dummy and the
## one-time prompts.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CLS_Player
var _dummy: CLS_Enemy
var _thug: CLS_Enemy
var _hud: CLS_TouchButtons


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("A4 FAIL: ", what)
	else:
		print("A4 ok: ", what)


var _stick: CLS_StickInput


## Drive movement through the REAL stick (its anti-drift loop owns move).
func _set_move(v: Vector2) -> void:
	if _stick:
		_stick.debug_set_move(v)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player") as CLS_Player
	_stick = _main.get_node("UI/Joystick")
	_hud = _main.get_node("UI") as CLS_TouchButtons
	_dummy = _main.get_node("Dummy") as CLS_Enemy
	_thug = _main.get_node("Thug") as CLS_Enemy
	InputBus.locked = false
	# isolate: dummy beside the player, thug parked far away
	_dummy.set("kind", 0)
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.hp = 99
	_dummy.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
	_thug.set("kind", 0)
	_thug.state = CLS_Enemy.State.IDLE
	_thug.global_position = Vector3(30.0, 0.02, 30.0)
	_player.global_position = Vector3(0.0, 0.02, 3.0)
	SuperMeter.value = 0.0
	Settings.set_value("hints", {})  # prompts are checked per-run
	# face the dummy
	_player._body.rotation.y = atan2(-(_dummy.global_position - _player.global_position).x,
			-(_dummy.global_position - _player.global_position).z)
	_player._yaw = _player._body.rotation.y

	await _test_chain_and_counter()
	await _test_variants()
	await _test_super_meter_and_strike()
	await _test_moves_screen_and_prompts()

	if _fails == 0:
		print("A4 PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("A4 FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_ground(max_f := 120) -> void:
	for i in max_f:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND:
			return


# --- the light chain and the on-screen counter -----------------------------------


func _test_chain_and_counter() -> void:
	var combo := _main.get_node("UI/ComboCounter") as CLS_ComboCounter
	_check(combo != null, "the combo counter exists")
	# tap three light punches into the dummy: jab -> cross -> hook
	for tap in 3:
		InputBus.clear_queues()
		_wait_ground()
		InputBus.punch_press()
		await _frame(2)
		InputBus.punch_release()
		await _frame(14)
	_check(_player._punch_stage >= 2 or _player.state == CLS_Player.State.PUNCH,
			"the light chain progresses (stage %d)" % _player._punch_stage)
	_check(combo.count >= 2, "the combo counter counts landed hits (x%d)" % combo.count)
	_check(_dummy.hp < 99, "the dummy takes the hits (hp %d)" % _dummy.hp)
	# decay: after 1.5 s idle the counter resets
	await _frame(95)
	_check(combo.count == 0, "the combo counter decays (x%d after idle)" % combo.count)


# --- direction + PUNCH variants -----------------------------------------------------


func _test_variants() -> void:
	# forward + tap = lunge: covers clearly more ground than a neutral jab
	_wait_ground()
	var x0 := _player.global_position.x
	_set_move(Vector2(0.0, -0.9))  # pushing forward (away)
	InputBus.punch_press()
	await _frame(2)
	InputBus.punch_release()
	await _frame(14)
	var lunge_d := _player.global_position.x - x0
	_set_move(Vector2.ZERO)
	await _frame(40)
	_check(absf(lunge_d) > 0.8, "forward + punch lunges (%.2f m travelled)" % absf(lunge_d))

	# back + tap = backfist: the hero steps AWAY and the dummy flinches
	_wait_ground()
	var hp0 := _dummy.hp
	var px := _player.global_position.distance_to(_dummy.global_position)
	_set_move(Vector2(0.0, 0.9))  # pulling back (toward the player)
	InputBus.punch_press()
	await _frame(2)
	InputBus.punch_release()
	await _frame(20)
	_set_move(Vector2.ZERO)
	var back_kind := _player._punch_variant
	await _frame(50)
	_check(back_kind == "back", "back + punch registers the variant (%s)" % back_kind)
	_check(_dummy.hp < hp0, "the backfist lands (hp %d -> %d)" % [hp0, _dummy.hp])
	_check(_player.global_position.distance_to(_dummy.global_position) >= px - 0.05,
			"the backfist keeps the hero out of range (%.2f -> %.2f m)" % [px,
					_player.global_position.distance_to(_dummy.global_position)])

	# back + hold = uppercut launcher: the dummy leaves the ground
	_wait_ground()
	# re-stage: the backfist knocked the dummy out of reach
	_dummy.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
	_dummy.state = CLS_Enemy.State.IDLE
	_player._body.rotation.y = atan2(-(_dummy.global_position - _player.global_position).x,
			-(_dummy.global_position - _player.global_position).z)
	_player._yaw = _player._body.rotation.y
	_set_move(Vector2(0.0, 0.9))
	InputBus.punch_press()
	# hold long enough to become a heavy (0.30 s)
	for i in 26:
		await _frame(1)
		if _player.state == CLS_Player.State.PUNCH and _player._punch_heavy:
			break
	InputBus.punch_release()
	_set_move(Vector2.ZERO)
	var launched := false
	for i in 60:
		await _frame(1)
		if _dummy.state == CLS_Enemy.State.LAUNCHED or _dummy.velocity.y > 1.0:
			launched = true
			break
	_check(launched, "stick back + hold PUNCH launches the dummy (state %s, vy %.1f)" % [
			CLS_Enemy.State.find_key(_dummy.state), _dummy.velocity.y])
	await _frame(80)
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE


# --- the SUPER meter and strike --------------------------------------------------------


func _test_super_meter_and_strike() -> void:
	SuperMeter.value = 0.0
	# re-stage the dummy beside the hero (the uppercut may have drifted her)
	_dummy.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE
	# hits fill the meter
	var hits := 0
	while SuperMeter.value < SuperMeter.GAIN_HIT * 2 and hits < 12:
		_wait_ground()
		InputBus.punch_press()
		await _frame(2)
		InputBus.punch_release()
		await _frame(30)
		hits += 1
	_check(SuperMeter.value >= SuperMeter.GAIN_HIT * 2,
			"landed hits fill the SUPER meter (%.0f after %d hits)" % [SuperMeter.value, hits])

	# top it up and fire the super at BOTH enemies gathered close
	while not SuperMeter.is_full():
		SuperMeter.gain(SuperMeter.GAIN_HIT)
	_dummy.global_position = _player.global_position + Vector3(1.3, 0.02, 0.4)
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE
	_thug.global_position = _player.global_position + Vector3(-1.3, 0.02, 0.3)
	_thug.hp = 99
	_thug.state = CLS_Enemy.State.IDLE
	var super_btn := _hud._buttons["SuperBtn"] as CLS_ActionButton
	_check(super_btn != null and super_btn.charged, "the SUPER button glows when full")
	_wait_ground()
	InputBus.queue_super()
	var fired := false
	for i in 160:  # real frames: the slow-mo stretches game time
		await _frame(1)
		if _player._punch_stage == 4:
			fired = true
			break
	_check(fired, "the SUPER button triggers the super strike")
	_check(SuperMeter.value == 0.0, "the super spends the whole meter")
	# watch every frame: the training dummy RESETS itself after falling
	var d_down := false
	var t_down := false
	for i in 160:  # real frames: the slow-mo stretches game time
		await _frame(1)
		if _dummy.state in [CLS_Enemy.State.DOWN, CLS_Enemy.State.LAUNCHED]:
			d_down = true
		if _thug.state in [CLS_Enemy.State.DOWN, CLS_Enemy.State.LAUNCHED]:
			t_down = true
	_check(d_down, "the super flattens the dummy (saw %s)" % CLS_Enemy.State.find_key(_dummy.state))
	_check(t_down, "the super flattens the second enemy too (saw %s)" % CLS_Enemy.State.find_key(_thug.state))
	_check(not super_btn.charged, "the glow goes out after spending")
	await _frame(60)


# --- the MOVES screen, the dummy, one-time prompts ---------------------------------------


func _test_moves_screen_and_prompts() -> void:
	var ml := _main.get_node("MoveListUI") as CLS_MoveListUI
	_check(ml != null, "the MOVES screen exists")
	ml.open()
	await _frame(2)
	_check(ml.visible, "MOVES opens from the pause menu path")
	var rows := ml.find_children("*", "Label", true, false)
	var texts := []
	for r in rows:
		texts.append((r as Label).text)
	var has_lunge := false
	var has_super := false
	for t in texts:
		if "Lunge cross" in t:
			has_lunge = true
		if "SUPER strike" in t:
			has_super = true
	_check(has_lunge and has_super, "the move list covers the new moves")
	ml._close()
	await _frame(2)
	_check(not ml.visible, "MOVES closes back to the pause menu")
	# the training dummy is part of the scene and trains combos
	_check(is_instance_valid(_main.get_node("Dummy")), "the training dummy is in the scene")
	# one-time prompts: backfist/uppercut/super were used above -> flagged
	_check(Settings.hint_done("backfist"), "the backfist prompt fired once")
	_check(Settings.hint_done("uppercut"), "the uppercut prompt fired once")
	_check(Settings.hint_done("super_ready"), "the super prompt fired once")