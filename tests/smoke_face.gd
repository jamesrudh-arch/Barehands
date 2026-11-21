extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_StickInput := preload("res://scripts/stick_input.gd")
const CLS_TouchButtons := preload("res://scripts/touch_buttons.gd")
## Combo pass PART 1: the face-button layout. The A/B/X/Y diamond builds,
## every face button fires its action on touch-DOWN, all four work under
## multi-touch, the kick (code-built Kick_Code) hits and launches, the
## SUPER button appears only when the meter is full, schemes switch live
## and both keep the layout editor working.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CLS_Player
var _dummy: CLS_Enemy
var _hud: CLS_TouchButtons
var _stick: CLS_StickInput


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FACE FAIL: ", what)
	else:
		print("FACE ok: ", what)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	Settings.set_value("button_scheme", "face")
	Settings.set_value("hints", {})
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player") as CLS_Player
	_hud = _main.get_node("UI") as CLS_TouchButtons
	_stick = _main.get_node("UI/Joystick") as CLS_StickInput
	_dummy = _main.get_node("Dummy") as CLS_Enemy
	InputBus.locked = false
	var thug := _main.get_node("Thug") as CLS_Enemy
	thug.set("kind", 0)
	thug.state = CLS_Enemy.State.IDLE
	thug.global_position = Vector3(30.0, 0.02, 30.0)
	_dummy.set("kind", 0)
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
	_player._body.rotation.y = atan2(-(_dummy.global_position - _player.global_position).x,
			-(_dummy.global_position - _player.global_position).z)
	_player._yaw = _player._body.rotation.y
	SuperMeter.value = 0.0

	await _test_face_layout()
	await _test_face_actions()
	await _test_kick()
	await _test_multi_touch()
	await _test_super_visibility()
	await _test_scheme_switch_and_editor()

	Settings.set_value("button_scheme", "classic")
	if _fails == 0:
		print("FACE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("FACE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _touch(pos: Vector2, pressed: bool, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _center(name: String) -> Vector2:
	var b := _hud._buttons[name] as CLS_ActionButton
	return b.position + b.size * 0.5


func _wait_ground(max_f := 120) -> void:
	# two CONSECUTIVE grounded frames: the spawn-landing dip must not eat
	# an input queue (a punch consumed mid-air is discarded by design)
	var grounded := 0
	for i in max_f:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND:
			grounded += 1
			if grounded >= 2:
				return
		else:
			grounded = 0


# --- the diamond exists and is placed ------------------------------------------------


func _test_face_layout() -> void:
	for name in ["FaceA", "FaceB", "FaceX", "FaceY", "JumpBtn", "DodgeBtn",
			"SprintBtn", "LockBtn", "SuperBtn"]:
		_check(_hud._buttons.has(name), "face scheme builds %s" % name)
	# diamond geometry: Y above A, X left of B
	var a := _center("FaceA")
	var y := _center("FaceY")
	var x := _center("FaceX")
	var b := _center("FaceB")
	_check(y.y < a.y - 60.0, "Y sits above A (diamond top)")
	_check(x.x < b.x - 60.0, "X sits left of B (diamond)")
	# captions: A LIGHT, B HEAVY, X KICK, Y GRAB
	_check((_hud._buttons["FaceA"] as CLS_ActionButton).sub == "LIGHT"
			and (_hud._buttons["FaceX"] as CLS_ActionButton).sub == "KICK",
			"face buttons carry their move captions")


# --- every face button fires its action ----------------------------------------------


func _test_face_actions() -> void:
	# A: light punch
	_wait_ground()
	_touch(_center("FaceA"), true, 0)
	await _frame(6)
	_touch(_center("FaceA"), false, 0)
	var saw_light := _player.state == CLS_Player.State.PUNCH and _player._punch_stage in [1, 2]
	_check(saw_light, "A fires a light punch (stage %d)" % _player._punch_stage)
	await _frame(50)
	# B: instant heavy - no hold needed
	_wait_ground()
	_touch(_center("FaceB"), true, 1)
	await _frame(6)
	_touch(_center("FaceB"), false, 1)
	var saw_heavy := false
	for i in 30:
		await _frame(1)
		if _player.state == CLS_Player.State.PUNCH and _player._punch_stage == 3 and _player._punch_heavy:
			saw_heavy = true
			break
	_check(saw_heavy, "B fires an instant heavy (no hold)")
	await _frame(60)
	# X: the kick
	_wait_ground()
	_touch(_center("FaceX"), true, 2)
	await _frame(6)
	_touch(_center("FaceX"), false, 2)
	var saw_kick := false
	for i in 30:
		await _frame(1)
		if _player._punch_stage == 5:
			saw_kick = true
			break
	_check(saw_kick, "X fires the kick (stage 5)")
	await _frame(60)
	# Y: grab the dummy
	_wait_ground()
	_dummy.global_position = _player.global_position + _player._body.global_transform.basis.z * -1.0
	_dummy.state = CLS_Enemy.State.IDLE
	_touch(_center("FaceY"), true, 3)
	await _frame(6)
	_touch(_center("FaceY"), false, 3)
	var saw_grab := _player.state == CLS_Player.State.GRAB or _dummy.state == CLS_Enemy.State.GRABBED
	if not saw_grab:
		for i in 30:
			await _frame(1)
			if _player.state == CLS_Player.State.GRAB or _dummy.state == CLS_Enemy.State.GRABBED:
				saw_grab = true
				break
	_check(saw_grab, "Y grabs (hero %s / dummy %s)" % [
			CLS_Player.State.find_key(_player.state), CLS_Enemy.State.find_key(_dummy.state)])
	# release the grab for later tests
	if _player.state == CLS_Player.State.GRAB:
		InputBus.queue_grab()
		await _frame(40)
	InputBus.reset_input()
	await _frame(30)


# --- the kick lands and juggles -------------------------------------------------------


func _test_kick() -> void:
	_wait_ground()
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.global_position = _player.global_position + Vector3(1.4, 0.02, 0.0)
	_player._body.rotation.y = atan2(-(_dummy.global_position - _player.global_position).x,
			-(_dummy.global_position - _player.global_position).z)
	_player._yaw = _player._body.rotation.y
	var hp0 := _dummy.hp
	InputBus.queue_kick()
	var kicked := false
	for i in 40:
		await _frame(1)
		if _dummy.hp < hp0:
			kicked = true
			break
	_check(kicked, "the kick damages the dummy (hp %d -> %d)" % [hp0, _dummy.hp])
	await _frame(60)
	# a kick on a STAGGERED enemy launches (the juggle entry)
	_wait_ground()
	_dummy.state = CLS_Enemy.State.STAGGER
	_dummy.global_position = _player.global_position + Vector3(1.3, 0.02, 0.0)
	InputBus.queue_kick()
	var launched := false
	for i in 50:
		await _frame(1)
		if _dummy.state == CLS_Enemy.State.LAUNCHED:
			launched = true
			break
	_check(launched, "a kick on a staggered enemy launches them (state %s)" %
			CLS_Enemy.State.find_key(_dummy.state))
	await _frame(80)
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.hp = 99


# --- four fingers at once --------------------------------------------------------------


func _test_multi_touch() -> void:
	_wait_ground()
	# hold SPRINT with one finger, then tap A and X together
	_touch(_center("SprintBtn"), true, 4)
	await _frame(2)
	_check(InputBus.sprint, "sprint holds while other buttons are tapped")
	_touch(_center("FaceA"), true, 5)
	_touch(_center("FaceX"), true, 6)
	await _frame(8)
	var both := _player.state == CLS_Player.State.PUNCH  # one of them is swinging
	_check(both, "a second simultaneous face button still acts (state %s stage %d)" % [
			CLS_Player.State.find_key(_player.state), _player._punch_stage])
	_touch(_center("FaceA"), false, 5)
	_touch(_center("FaceX"), false, 6)
	# all four at once: every queue must fire, nothing may hang
	InputBus.reset_input()
	_wait_ground()
	for pair in [["FaceA", 10], ["FaceB", 11], ["FaceX", 12], ["FaceY", 13]]:
		_touch(_center(pair[0]), true, pair[1])
	await _frame(6)
	for pair in [["FaceA", 10], ["FaceB", 11], ["FaceX", 12], ["FaceY", 13]]:
		_touch(_center(pair[0]), false, pair[1])
	var alive := _player.state in [CLS_Player.State.PUNCH, CLS_Player.State.GRAB, CLS_Player.State.GROUND]
	_check(alive, "all four face buttons at once: the hero acts, nothing hangs (%s)" %
			CLS_Player.State.find_key(_player.state))
	_touch(_center("SprintBtn"), false, 4)
	_check(not InputBus.sprint, "sprint releases cleanly after the mash")
	await _frame(60)
	InputBus.reset_input()


# --- the SUPER button appears only when full -------------------------------------------


func _test_super_visibility() -> void:
	SuperMeter.value = 20.0
	await _frame(2)
	_check(not (_hud._buttons["SuperBtn"] as CLS_ActionButton).visible,
			"face scheme: SUPER hidden while the meter fills")
	SuperMeter.value = 100.0
	await _frame(2)
	_check((_hud._buttons["SuperBtn"] as CLS_ActionButton).visible,
			"face scheme: SUPER appears when the meter is full")
	SuperMeter.value = 0.0
	await _frame(2)
	_check(not (_hud._buttons["SuperBtn"] as CLS_ActionButton).visible,
			"face scheme: SUPER hides again after spending")


# --- schemes switch live; the editor follows --------------------------------------------


func _test_scheme_switch_and_editor() -> void:
	Settings.set_value("button_scheme", "classic")
	await _frame(3)
	_check(_hud._buttons.has("PunchBtn") and not _hud._buttons.has("FaceA"),
			"switching to classic rebuilds the classic set")
	_check((_hud._buttons["SuperBtn"] as CLS_ActionButton).visible,
			"classic keeps SUPER visible with its fill ring")
	Settings.set_value("button_scheme", "face")
	await _frame(3)
	_check(_hud._buttons.has("FaceA") and not _hud._buttons.has("PunchBtn"),
			"switching back to face rebuilds the diamond")
	# the layout editor still works on the face set
	_hud.begin_layout_edit()
	await _frame(1)
	_check((_hud._buttons["FaceB"] as CLS_ActionButton).editable,
			"the layout editor covers the face buttons")
	var mid := _center("FaceB")
	_touch(mid, true, 20)
	await _frame(2)
	var e := InputEventScreenDrag.new()
	e.index = 20
	e.position = mid + Vector2(-80.0, -30.0)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frame(2)
	_touch(mid + Vector2(-80.0, -30.0), false, 20)
	await _frame(2)
	var over := Settings.layout_for("FaceB")
	_check(absf(float(over.get("dx", 0.0)) + 80.0) < 30.0,
			"the editor drags face buttons (saved %s)" % str(over))
	_hud.end_layout_edit()
	Settings.reset_layout()
	await _frame(2)
	# left-handed preset mirrors the diamond too
	_hud.apply_preset("left")
	await _frame(2)
	var fa := _hud._buttons["FaceA"] as CLS_ActionButton
	_check(fa.position.x < 1280.0 * 0.45, "left-handed mirrors the diamond to the left half (%.0f)" % fa.position.x)
	_hud.apply_preset("classic")
	Settings.set_value("left_handed", false)
	Settings.set_value("preset", "classic")
	await _frame(2)
