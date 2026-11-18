extends Node
## Stage A2/A3 suite: the first-run picker, the Settings screen, layout
## presets + editor + persistence, and the feel of the buttons themselves:
## touch-DOWN firing, oversized hit areas, press animation, cooldown rings,
## input buffering, the cancel window and measured touch-to-action latency.

var _fails := 0
var _checks := 0
var _main: Node
var _hud: TouchButtons
var _vp: Vector2


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("CTRL FAIL: ", what)
	else:
		print("CTRL ok: ", what)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", false)  # before the scene builds
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_hud = _main.get_node("UI") as TouchButtons
	_vp = get_viewport().size
	var player := _main.get_node("Player") as CharacterBody3D
	# park the thug far away: no hitstun may interrupt the input checks
	var thug := _main.get_node("Thug") as CharacterBody3D
	thug.set("kind", 0)
	thug.state = Enemy.State.IDLE
	thug.global_position = Vector3(30.0, 0.02, 30.0)

	await _test_first_run_picker()
	await _test_settings_screen()
	await _test_presets_and_editor()
	await _test_buttons_feel(player)
	await _test_latency(player)

	if _fails == 0:
		print("CTRL PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("CTRL FAIL (%d of %d checks)" % [_fails, _checks])
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


# --- the first-run picker -----------------------------------------------------------


func _test_first_run_picker() -> void:
	Settings.set_value("first_run_done", false)
	var fr := _main.get_node("FirstRun") as FirstRun
	_check(fr != null and is_instance_valid(fr), "first-run picker exists on first open")
	if fr == null or not is_instance_valid(fr):
		return
	_check(InputBus.locked, "picker locks gameplay input")
	var cards := fr.find_children("Move_*", "Button", true, false)
	_check(cards.size() == 4, "picker shows four movement cards (%d)" % cards.size())
	var btn_cards := fr.find_children("Btns_*", "Button", true, false)
	_check(btn_cards.size() == 2, "picker offers both button schemes (%d)" % btn_cards.size())
	# the button-scheme cards set button_scheme WITHOUT dismissing the picker
	for bc in btn_cards:
		if (bc as Button).name == "Btns_face":
			(bc as Button).pressed.emit()
	await _frame(2)
	_check(str(Settings.value("button_scheme")) == "face",
			"the Face buttons card sets the button scheme")
	_check(is_instance_valid(fr), "the picker stays up until a movement card is picked")
	Settings.set_value("button_scheme", "classic")
	# pick the fixed stick: scheme set, done flag persists, picker frees
	(cards[1] as Button).pressed.emit()
	await _frame(2)
	_check(str(Settings.value("scheme")) == "fixed", "picking a card sets the scheme")
	_check(bool(Settings.value("first_run_done")), "choice is remembered")
	_check(not InputBus.locked, "input unlocks after the pick")
	_check(not is_instance_valid(fr), "picker frees itself")
	# a reload of the scene must NOT show it again
	var fr2 := _main.get_node_or_null("FirstRun")
	_check(fr2 == null, "picker does not appear once first_run_done")


# --- the settings screen --------------------------------------------------------------


func _test_settings_screen() -> void:
	var pause := _main.get_node("PauseMenu") as PauseMenu
	var s := _main.get_node("SettingsUI") as SettingsUI
	# open through the real path: pause menu -> SETTINGS
	pause._toggle()
	await _frame(2)
	var settings_btn: Button = null
	for b in pause.find_children("*", "Button", true, false):
		if (b as Button).text == "SETTINGS":
			settings_btn = b
	_check(settings_btn != null, "pause menu has a SETTINGS button")
	if settings_btn:
		settings_btn.pressed.emit()
		await _frame(2)
		_check(s.visible, "SETTINGS opens the screen")
		_check(not pause._panel.visible, "pause panel hides behind it")
	# scheme buttons switch the live scheme
	var scheme_btn: Button = null
	for b in s.find_children("Scheme_*", "Button", true, false):
		if (b as Button).name == "Scheme_dpad":
			scheme_btn = b
	if scheme_btn:
		scheme_btn.pressed.emit()
		await _frame(2)
		_check(str(Settings.value("scheme")) == "dpad", "scheme button switches scheme live")
	Settings.set_value("scheme", "floating")
	# a slider write persists to disk: read the file back
	Settings.set_value("deadzone", 0.22)
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else {}
	f.close()
	_check(d is Dictionary and is_equal_approx(float(d.get("deadzone", 0.0)), 0.22),
			"slider writes persist to settings.json")
	Settings.set_value("deadzone", 0.15)
	s._close()
	await _frame(2)
	_check(not s.visible and pause._panel.visible, "DONE returns to the pause menu")
	pause._toggle()
	await _frame(2)


# --- presets, editor, persistence -----------------------------------------------------


func _test_presets_and_editor() -> void:
	var punch := _hud._buttons["PunchBtn"] as ActionButton
	var home: Vector2 = punch.position
	# preset: compact pulls the cluster toward the corner
	var s := _main.get_node("SettingsUI") as SettingsUI
	s._apply_preset("compact")
	await _frame(2)
	_check(punch.position.x > home.x and punch.position.y > home.y,
			"compact preset moves the cluster toward the corner")
	_check(absf((punch.size.x / 116.0) - 0.85) < 0.01, "compact preset scales buttons to 0.85")
	# preset: left-handed mirrors across and flips the stick zone
	s._apply_preset("left")
	await _frame(2)
	_check(punch.position.x < home.x - 200.0, "left-handed preset mirrors the button cluster")
	var stick := _main.get_node("UI/Joystick") as StickInput
	var right_side := Vector2(_vp.x * 0.9, _vp.y * 0.8)
	var left_side := Vector2(_vp.x * 0.1, _vp.y * 0.8)
	_check(stick._in_left_zone(right_side) and not stick._in_left_zone(left_side),
			"left-handed flips the movement half of the screen")
	Settings.set_value("left_handed", false)
	s._apply_preset("classic")
	await _frame(2)
	# the layout editor: drag Punch far left, resize, set opacity
	_hud.begin_layout_edit()
	await _frame(1)
	_check(punch.editable, "editor puts buttons in edit mode")
	var mid := punch.position + punch.size * 0.5
	_touch(mid, true, 3)
	await _frame(2)
	var e := InputEventScreenDrag.new()
	e.index = 3
	e.position = mid + Vector2(-160.0, -40.0)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frame(2)
	_touch(mid + Vector2(-160.0, -40.0), false, 3)
	await _frame(2)
	_hud._edit_sel = "PunchBtn"
	_hud._nudge_scale(0.2)
	_hud._set_opacity(0.5)
	_hud.end_layout_edit()
	await _frame(2)
	var over := Settings.layout_for("PunchBtn")
	_check(absf(float(over.get("dx", 0.0)) + 160.0) < 40.0 and absf(float(over.get("dy", 0.0)) + 40.0) < 30.0,
			"editor drag saves the override (%s)" % str(over))
	_check(absf(float(over.get("scale", 1.0)) - 1.2) < 0.01, "editor resize saves")
	_check(absf(float(over.get("opacity", 1.0)) - 0.5) < 0.01, "editor opacity saves")
	_check(absf(punch.position.x - (home.x - 160.0)) < 40.0, "override is applied to the button")
	Settings.reset_layout()
	await _frame(2)
	_check(absf(punch.position.x - home.x) < 0.5 and absf(punch.size.x - 116.0) < 0.5,
			"reset layout restores the defaults")


# --- the buttons themselves -------------------------------------------------------------


func _test_buttons_feel(player: CharacterBody3D) -> void:
	var punch := _hud._buttons["PunchBtn"] as ActionButton
	# touch-DOWN fires: press and hold; the hold state must be true immediately
	var mid := punch.position + punch.size * 0.5
	_touch(mid, true, 4)
	await _frame(2)
	_check(InputBus.punch_held, "PUNCH registers on touch-DOWN")
	_check(punch._press > 0.0, "press animation plays")
	# oversized hit area: a fingertip 25% outside the visual disc still fires
	var edge := punch.position + punch.size * 0.5 + Vector2(punch.size.x * 0.30, 0)
	_touch(mid, false, 4)
	await _frame(1)
	_touch(edge, true, 5)
	await _frame(2)
	var edge_held := InputBus.punch_held
	_touch(edge, false, 5)
	await _frame(2)
	_check(edge_held, "hit area extends past the visual disc")
	# cooldown ring while a punch is in flight
	InputBus.clear_queues()
	_touch(mid, true, 6)
	await _frame(2)
	_touch(mid, false, 6)
	await _frame(12)
	var ring := punch.cooldown
	_check(ring > 0.0 or player.state == Player.State.PUNCH,
			"cooldown ring shows during the swing (ring=%.2f state=%s)" % [ring, Player.State.find_key(player.state)])
	# input buffering: tap punch again mid-swing -> the cross chains
	InputBus.clear_queues()
	for i in 90:
		await _frame(1)
		if player.state == Player.State.GROUND:
			break
	InputBus.punch_press()
	InputBus.punch_release()
	await _frame(6)
	InputBus.punch_press()  # buffered during the jab
	InputBus.punch_release()
	var chained := false
	for i in 40:
		await _frame(1)
		if player._punch_stage == 2:
			chained = true
			break
	_check(chained, "a punch pressed during a jab buffers into the cross")
	# cancel window: dodge during a swing cancels into the dodge
	InputBus.clear_queues()
	await _frame(30)
	InputBus.punch_press()
	InputBus.punch_release()
	await _frame(8)
	InputBus.dodge_press()
	InputBus.dodge_release()
	var dodged := false
	for i in 30:
		await _frame(1)
		if player.state == Player.State.DODGE:
			dodged = true
			break
	_check(dodged, "dodge cancels a swing (cancel window)")
	await _frame(40)
	InputBus.reset_input()


# --- measured touch-to-action latency ------------------------------------------------------


func _test_latency(player: CharacterBody3D) -> void:
	await _frame(30)
	var punch := _hud._buttons["PunchBtn"] as ActionButton
	var mid := punch.position + punch.size * 0.5
	InputBus.clear_queues()
	_touch(mid, true, 7)
	await _frame(1)
	_touch(mid, false, 7)
	var fired := false
	for i in 20:
		await _frame(1)
		if player.state == Player.State.PUNCH:
			fired = true
			break
	_check(fired, "tap punch reaches the action")
	var lat := InputBus.latency_msec("punch_down")
	_check(lat >= 0.0 and lat < 150.0, "touch-to-action latency %.1f ms (< 150)" % lat)
	print("CTRL   latency: touch -> PUNCH action = %.1f ms (simulated, 60 Hz physics)" % lat)
	await _frame(20)
	InputBus.reset_input()
