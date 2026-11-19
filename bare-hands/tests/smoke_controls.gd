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
	await _test_feel_targets(player)
	await _test_accessibility(player, thug)
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


# --- the bible 4A feel targets (Batch 4) ----------------------------------------------------
## The four Tuning feel numbers, wired: dodge leniency ~120 ms (a tap a
## beat too early is held, not eaten), the light-cancel window 150-350 ms
## (dodge interrupts a LIGHT swing only inside it; heavies commit), the
## chain flowing at the window instead of the full lock, and the parry
## window 300 ms widened 1.5x by DRUNKEN.

func _test_feel_targets(player: CharacterBody3D) -> void:
	await _frame(10)
	InputBus.clear_queues()

	# 1. DODGE LENIENCY: a tap 80 ms before hitstun ends is held (never
	# fires DURING the stun) and fires the first free frame after it.
	player._hitstun_until = player._t + 0.08
	InputBus.queue_dodge()
	await _frame(2)
	_check(player.state != Player.State.DODGE,
			"leniency: no dodge while still stunned")
	var fired := false
	for i in 15:
		await _frame(1)
		if player.state == Player.State.DODGE:
			fired = true
			break
	_check(fired, "leniency: a dodge tapped 80 ms early fires when the stun ends")
	await _frame(40)  # let the dodge finish
	InputBus.clear_queues()

	# 2. Too early even for leniency (400 ms of stun left > 120 ms
	# window): the tap is eaten, exactly as before - leniency never
	# becomes a long buffer.
	player._hitstun_until = player._t + 0.4
	InputBus.queue_dodge()
	var leaked := false
	for i in 30:
		await _frame(1)
		if player.state == Player.State.DODGE:
			leaked = true
			break
	_check(not leaked, "a dodge tapped 400 ms early is dropped (no long buffer)")
	player._hitstun_until = 0.0
	await _frame(2)

	# 3. THE LIGHT-CANCEL WINDOW: a dodge ~70 ms into a jab does not
	# interrupt the swing; the held tap fires when the window opens.
	InputBus.clear_queues()
	InputBus.punch_press()
	InputBus.punch_release()
	await _frame(4)  # the jab is ~65 ms in
	InputBus.dodge_press()
	InputBus.dodge_release()
	await _frame(3)
	_check(player.state == Player.State.PUNCH,
			"a dodge before the window does not interrupt the jab")
	var cancelled := false
	for i in 12:
		await _frame(1)
		if player.state == Player.State.DODGE:
			cancelled = true
			break
	_check(cancelled, "the held dodge cancels the jab when the window opens (150 ms)")
	await _frame(40)
	InputBus.clear_queues()

	# 4. HEAVIES COMMIT (bible: cancel is lights only): a dodge tapped
	# mid-heavy never interrupts the swing, and the heavy's 750 ms lock
	# outlasts the 400 ms queue life - the tap lapses. Commitment costs
	# the dodge's timing; re-tap after the swing.
	InputBus.clear_queues()
	InputBus.punch_press()  # hold: the heavy at 300 ms
	var h := 0
	while not (player._punch_stage == 3 and player._punch_heavy):
		await _frame(1)
		h += 1
		if h > 40:
			break
	_check(player._punch_stage == 3 and player._punch_heavy, "the hold becomes a heavy")
	await _frame(5)  # ~80 ms into the heavy
	InputBus.dodge_press()
	InputBus.dodge_release()
	await _frame(8)
	_check(player.state == Player.State.PUNCH, "a dodge mid-heavy never interrupts the swing")
	InputBus.consume_punch_hold()
	InputBus.punch_release()  # consumed: no light queues on the release
	var leaked2 := false
	for i in 55:  # through the 750 ms lock, past the 400 ms queue life
		await _frame(1)
		if player.state == Player.State.DODGE:
			leaked2 = true
			break
	_check(not leaked2, "the heavy outlasts the dodge tap (re-tap to evade)")
	InputBus.clear_queues()
	await _frame(5)

	# 5. THE CHAIN FLOWS AT THE WINDOW: a buffered cross starts at the
	# cancel window (never before the jab's 200 ms impact), not at the
	# full 420 ms lock - recovery is the next swing's wind-up.
	InputBus.clear_queues()
	InputBus.punch_press()
	InputBus.punch_release()
	var sw := 0
	while player.state != Player.State.PUNCH:
		await _frame(1)
		sw += 1
		if sw > 10:
			break
	await _frame(3)  # buffer the cross at ~65 ms
	InputBus.punch_press()
	InputBus.punch_release()
	var f2 := 0
	while player._punch_stage != 2:
		await _frame(1)
		f2 += 1
		if f2 > 30:
			break
	# impact 200 ms = ~12 frames from the swing's start; the old lock
	# path chained at ~25 frames
	_check(f2 >= 8 and f2 <= 18,
			"the buffered cross flows at the cancel window (%d frames, ~25 at the old lock)" % f2)
	await _frame(30)
	InputBus.clear_queues()

	# 6. THE PARRY WINDOW (Tuning, 300 ms): a block 200 ms old still
	# parries - the shipped const was 150 ms.
	InputBus.clear_queues()
	InputBus.dodge_held = true
	player._enter_block()
	for i in 12:  # 200 ms of guard
		await _frame(1)
	var res: String = player.take_hit(Vector3(1.0, 0.0, 0.0))
	_check(res == "parried",
			"a 200 ms-old block parries (window %.0f ms)" % (player._parry_window() * 1000.0))
	InputBus.dodge_held = false
	await _frame(3)
	InputBus.clear_queues()

	# 7. DRUNKEN reads punches (1.5x): a 350 ms-old block parries in
	# that style only - past the 300 ms base window.
	Styles.unlock_all_for_test()
	Styles.switch_to("drunken")
	_check(Styles.parry_mult() == 1.5, "drunken's parry mult is 1.5")
	InputBus.dodge_held = true
	player._enter_block()
	for i in 21:  # 350 ms of guard
		await _frame(1)
	var res2: String = player.take_hit(Vector3(1.0, 0.0, 0.0))
	_check(res2 == "parried", "a 350 ms-old DRUNKEN block parries (1.5x the window)")
	InputBus.dodge_held = false
	await _frame(3)
	Styles.switch_to("brawler")
	InputBus.clear_queues()


# --- the accessibility four (bible 7, Batch 4) ------------------------------------------------
## block_hold_ms (Tuning): the hold-DODGE -> block threshold, and the
## input bus's tap-vs-hold split follows it. button_scale (Settings):
## every button's size, rebuilt live. shake_scale (Settings): impact
## shake attenuation. autotarget_mult (Tuning): the soft auto-target's
## reach.

func _test_accessibility(player: CharacterBody3D, thug: CharacterBody3D) -> void:
	await _frame(10)
	InputBus.clear_queues()

	# 1. BLOCK HOLD: at the default 250 ms a 133 ms hold is still a
	# tap-wait, not a block; at 100 ms the same hold guards.
	InputBus.dodge_press()
	await _frame(8)
	_check(player.state != Player.State.BLOCK,
			"at 250 ms a 133 ms hold does not block yet")
	InputBus.consume_dodge_hold()
	InputBus.dodge_release()
	await _frame(3)
	Tuning.set_v("block_hold_ms", 100.0)
	InputBus.dodge_press()
	await _frame(8)  # 133 ms >= 100 ms
	_check(player.state == Player.State.BLOCK,
			"at 100 ms a 133 ms hold blocks (easier guard)")
	InputBus.consume_dodge_hold()
	InputBus.dodge_release()
	await _frame(3)
	Tuning.set_v("block_hold_ms", 250.0)
	InputBus.clear_queues()

	# 2. BUTTON SIZE: the slider rebuilds every button 1.3x.
	var punch_btn := _hud._buttons["PunchBtn"] as ActionButton
	var sz0: float = punch_btn.size.x
	Settings.set_value("button_scale", 1.3)
	await _frame(2)
	var sz1: float = (_hud._buttons["PunchBtn"] as ActionButton).size.x
	_check(sz1 > sz0 * 1.2, "button size 1.3 grows the punch button (%.0f -> %.0f)" % [sz0, sz1])
	Settings.set_value("button_scale", 1.0)
	await _frame(2)
	var sz2: float = (_hud._buttons["PunchBtn"] as ActionButton).size.x
	_check(absf(sz2 - sz0) < 1.0, "button size restores (%.0f -> %.0f)" % [sz1, sz2])

	# 3. REDUCED SHAKE: the scale attenuates every impact shake.
	var cam := get_tree().get_first_node_in_group("camera")
	Settings.set_value("shake_scale", 0.0)
	Fx.shake(0.9)
	_check(absf(float(cam._shake)) < 0.01,
			"shake 0 kills the impact shake (%.2f)" % float(cam._shake))
	Settings.set_value("shake_scale", 0.5)
	Fx.shake(0.8)
	_check(absf(float(cam._shake) - 0.4) < 0.01,
			"shake 0.5 halves it (%.2f)" % float(cam._shake))
	Settings.set_value("shake_scale", 1.0)

	# 4. AUTO-TARGET STRENGTH: the reach multiplier. A thug at 2.0 m sits
	# beyond the default 1.7 m reach, inside 1.5x (2.55 m) - read and
	# step away in the same breath so its AI never wakes.
	var park := thug.global_position
	thug.global_position = player.global_position + Vector3(2.0, 0.02, 0.0)
	var far: CharacterBody3D = player._punch_target(-0.5, 0.25)
	Tuning.set_v("autotarget_mult", 1.5)
	var near: CharacterBody3D = player._punch_target(-0.5, 0.25)
	Tuning.set_v("autotarget_mult", 1.0)
	thug.global_position = park
	thug.state = Enemy.State.IDLE
	_check(far == null, "a thug at 2.0 m is beyond the default reach")
	_check(near == thug, "auto-target 1.5x reaches it")
	InputBus.clear_queues()


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
