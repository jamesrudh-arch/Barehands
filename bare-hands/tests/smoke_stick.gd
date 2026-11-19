extends Node
## Stage A1/A2 suite: the analog stick and every way a phone finger can go
## wrong. Touches are simulated as real InputEventScreenTouch/Drag events
## fed through the scene's StickInput. A check fails if the stick ever
## leaks movement after a disturbance. Numbers printed at the end.

var _fails := 0
var _checks := 0
var _stick: StickInput
var _vp: Vector2


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("STICK FAIL: ", what)
	else:
		print("STICK ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_stick = main.get_node("UI/Joystick") as StickInput
	_vp = get_viewport().size
	print("STICK scheme=%s deadzone=%.2f curve=%.2f smoothing=%.2fs sensitivity=%.2f" % [
			str(Settings.value("scheme")), float(Settings.value("deadzone")),
			float(Settings.value("curve")), float(Settings.value("smoothing")),
			float(Settings.value("sensitivity"))])

	await _test_floating_and_pipeline()
	await _test_second_finger_and_mash()
	await _test_focus_loss()
	await _test_pause_mid_hold()
	await _test_jitter()
	await _test_all_schemes()
	await _test_auto_sprint_and_snap()
	await _test_idle_drift_10s()

	Settings.set_value("scheme", "floating")
	Settings.set_value("auto_sprint", false)
	Settings.set_value("snap8", false)
	if _fails == 0:
		print("STICK PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("STICK FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


# --- event helpers ----------------------------------------------------------------


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.tilt = Vector2.ZERO
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _moved() -> float:
	return InputBus.move.length()


# --- the tests ----------------------------------------------------------------------


## Floating scheme + the response pipeline numbers, printed.
func _test_floating_and_pipeline() -> void:
	_check(str(Settings.value("scheme")) == "floating", "default scheme is floating")
	# land the thumb mid-left; the pad must plant there
	var start := Vector2(_vp.x * 0.2, _vp.y * 0.75)
	_touch(0, start, true)
	await _frame(2)
	_check(_stick._active, "floating pad engages where the thumb lands")
	# small push: inside the dead zone -> no movement at all
	_drag(0, start + Vector2(10, 0))
	await _frame(20)
	_check(_moved() == 0.0, "inside the 15%% dead zone: move=%.4f" % _moved())
	# just past the dead zone: slow, precise walking (curve prints its number)
	_drag(0, start + Vector2(70, 0))
	await _frame(30)
	var small := _moved()
	_check(small > 0.0 and small < 0.45, "past the zone: small push is SLOW (%.3f)" % small)
	# full edge: ~1.0
	_drag(0, start + Vector2(150, 0))
	await _frame(30)
	var big := _moved()
	_check(big > 0.9, "full edge reaches ~1.0 (%.3f)" % big)
	_check(big > small * 2.0, "curve separates small and full pushes (%.3f vs %.3f)" % [big, small])
	# release zeroes immediately, no smoothing float
	_touch(0, start, false)
	await _frame(2)
	_check(_moved() == 0.0, "release zeroes instantly (move=%.4f)" % _moved())
	print("STICK   pipeline: dz=%.2f curve=%.2f | 70px=%.3f 150px=%.3f (should be <0.45, ~1.0)" % [
			float(Settings.value("deadzone")), float(Settings.value("curve")), small, big])


## A second finger on the stick area must not take over; button mashing
## (more touches) must not move the stick either.
func _test_second_finger_and_mash() -> void:
	var start := Vector2(_vp.x * 0.2, _vp.y * 0.75)
	_touch(1, start, true)
	_drag(1, start + Vector2(120, 0))
	await _frame(25)
	var first := InputBus.move
	# a second finger lands ON the stick zone: ignored
	_touch(2, start + Vector2(20, 20), true)
	_drag(2, start + Vector2(-100, 0))
	await _frame(10)
	_check(absf(InputBus.move.x - first.x) < 0.3,
			"second finger on the stick is ignored (x %.3f -> %.3f)" % [first.x, InputBus.move.x])
	# button mashing: rapid taps elsewhere
	for i in 12:
		_touch(9 + i % 2, Vector2(_vp.x * 0.9, _vp.y * 0.8), true)
		await _frame(1)
		_touch(9 + i % 2, Vector2(_vp.x * 0.9, _vp.y * 0.8), false)
		await _frame(1)
	_check(_stick._touch == 1, "stick still owned by its own touch index")
	# a NEW touch replacing the released one (index reuse after OS reuse)
	_touch(1, start, false)
	await _frame(2)
	_touch(1, start, true)  # same index again, fresh stroke
	_drag(1, start + Vector2(150, 0))
	await _frame(25)
	_check(_moved() > 0.9, "a fresh stroke with a reused index works (%.3f)" % _moved())
	_touch(1, start, false)
	await _frame(2)
	_check(_moved() == 0.0, "final release zeroes")


## Focus lost mid-hold: everything must drop.
func _test_focus_loss() -> void:
	var start := Vector2(_vp.x * 0.25, _vp.y * 0.7)
	_touch(3, start, true)
	_drag(3, start + Vector2(140, 0))
	await _frame(25)
	_check(_moved() > 0.8, "holding before focus loss (%.3f)" % _moved())
	# simulate the OS dropping focus mid-hold (Window notification)
	_stick._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	# and the gameplay path: anything locking input must also drop it
	InputBus.locked = true
	InputBus.locked = false
	await _frame(5)
	_check(_moved() == 0.0, "focus loss mid-hold zeroes the stick (%.4f)" % _moved())
	_check(_stick._touch == -1, "focus loss releases the touch index")


## Pause menu open/close mid-hold (tree paused, then resumed).
func _test_pause_mid_hold() -> void:
	var start := Vector2(_vp.x * 0.3, _vp.y * 0.75)
	_touch(4, start, true)
	_drag(4, start + Vector2(130, 0))
	await _frame(25)
	_check(_moved() > 0.7, "holding before pause (%.3f)" % _moved())
	get_tree().paused = true
	_stick._notification(Node.NOTIFICATION_PAUSED)
	await _frame(5)
	_check(_moved() == 0.0, "pause mid-hold zeroes the stick (%.4f)" % _moved())
	get_tree().paused = false
	await _frame(5)
	_check(_moved() == 0.0, "still zero after resume (%.4f)" % _moved())


## Thumb jitter near the rim: the stick must not flicker to full/zero wildly.
func _test_jitter() -> void:
	var start := Vector2(_vp.x * 0.22, _vp.y * 0.72)
	_touch(5, start, true)
	var values := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_drag(5, start + Vector2(90 + rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		await _frame(2)
		values.append(_moved())
	var mx := 0.0
	var mn := 2.0
	for v in values:
		mx = maxf(mx, v)
		mn = minf(mn, v)
	_check(mx - mn < 0.35, "jitter is smoothed (min %.3f max %.3f spread %.3f)" % [mn, mx, mx - mn])
	_touch(5, start, false)
	await _frame(2)


## All four schemes move the hero input; fixed and dpad and drag each engage.
func _test_all_schemes() -> void:
	var start := Vector2(_vp.x * 0.2, _vp.y * 0.75)
	for scheme in ["fixed", "dpad", "drag", "floating"]:
		Settings.set_value("scheme", scheme)
		await _frame(2)
		_touch(6, start, true)
		await _frame(3)
		# fixed needs the press INSIDE the drawn pad (bottom-left home)
		if scheme == "fixed":
			var home := _stick._fixed_center()
			_touch(6, start, false)
			await _frame(2)
			_touch(6, home, true)
			_drag(6, home + Vector2(140, 0))
		elif scheme == "dpad":
			_drag(6, start + Vector2(80, -20))   # a diagonal wedge
		else:
			_drag(6, start + Vector2(150, 0))
		await _frame(30)
		var m := InputBus.move
		var ok := _stick._active and m.length() > 0.5
		_check(ok, "scheme %-9s engages (move=%.3f active=%s)" % [scheme, m.length(), _stick._active])
		_touch(6, start, false)
		await _frame(3)
		_check(_moved() == 0.0, "scheme %-9s releases clean" % scheme)
	Settings.set_value("scheme", "floating")


## Auto-sprint at the edge; 8-direction snap quantizes the angle.
func _test_auto_sprint_and_snap() -> void:
	Settings.set_value("auto_sprint", true)
	var start := Vector2(_vp.x * 0.25, _vp.y * 0.7)
	_touch(7, start, true)
	_drag(7, start + Vector2(150, 0))
	await _frame(30)
	_check(InputBus.sprint, "auto-sprint at the stick edge")
	_drag(7, start + Vector2(70, 0))
	await _frame(30)
	_check(not InputBus.sprint, "auto-sprint off when pulled back")
	_touch(7, start, false)
	Settings.set_value("auto_sprint", false)
	# snap8: a 30-degree push must land on the 0/45-degree lattice
	Settings.set_value("snap8", true)
	_touch(8, start, true)
	_drag(8, start + Vector2(130, 75))  # ~30 degrees
	await _frame(30)
	var snapped := InputBus.move.angle()
	_check(absf(absf(snapped) - 0.0) < 0.01 or absf(absf(snapped) - PI / 4.0) < 0.01,
			"snap8 quantizes to 45-degree lattice (angle=%.3f rad)" % snapped)
	_touch(8, start, false)
	Settings.set_value("snap8", false)
	await _frame(3)


## Nothing touching, 10 seconds: the maximum stick value must stay exactly 0
## and the camera yaw must not change at all.
func _test_idle_drift_10s() -> void:
	var yaw0 := InputBus.camera_yaw
	var max_drift := 0.0
	for i in 600:
		await get_tree().physics_frame
		max_drift = maxf(max_drift, _moved())
	var yaw_drift := absf(InputBus.camera_yaw - yaw0)
	_check(max_drift == 0.0, "10 s idle: max stick drift %.5f (must be 0)" % max_drift)
	_check(yaw_drift < 0.0001, "10 s idle: camera yaw drift %.5f rad" % yaw_drift)
	print("STICK   idle 10s: max stick %.5f, camera yaw drift %.5f rad" % [max_drift, yaw_drift])
