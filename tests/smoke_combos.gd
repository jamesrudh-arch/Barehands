extends Node
const CLS_ComboTable := preload("res://scripts/combo_table.gd")
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_InputStrip := preload("res://scripts/input_strip.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_StickInput := preload("res://scripts/stick_input.gd")
const CLS_StyleWheel := preload("res://scripts/style_wheel.gd")
const CLS_TouchButtons := preload("res://scripts/touch_buttons.gd")
## Combo pass PART 2: the input buffer, every combo sequence in the table,
## direction prefixes, pipe/grab gating, anti-spam damage scaling, the
## variety bonus and the on-screen input strip.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CLS_Player
var _dummy: CLS_Enemy
var _hud: CLS_TouchButtons
var _stick: CLS_StickInput
var _matched_ids: Array = []
var _variety_fired: Array = []


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("CMB FAIL: ", what)
	else:
		print("CMB ok: ", what)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	Settings.set_value("button_scheme", "face")
	Settings.set_value("hints", {})
	Progression.level = 20  # every combo unlocked for the sequence battery
	Styles.unlock_all_for_test()  # ...and every style learned (Batch 3)
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
	ComboInput.matched.connect(func(id: String) -> void: _matched_ids.append(id))
	ComboInput.variety_bonus.connect(func(ids: Array) -> void: _variety_fired.append(ids))
	# combos interrupt the current swing; the stress bot's leftover input
	# must not fire sequences between tests
	InputBus.reset_input()

	await _test_buffer_basics()
	await _test_named_combos()
	await _test_style_gate()
	await _test_every_sequence()
	await _test_gating()
	await _test_spam_scaling()
	await _test_variety()
	await _test_style_wheel()
	await _test_strip()

	if _fails == 0:
		print("CMB PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("CMB FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_ground(max_f := 200) -> void:
	var grounded := 0
	for i in max_f:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND:
			grounded += 1
			if grounded >= 2:
				return
		else:
			grounded = 0


## Simulate a button press at finger timing: token lands in the buffer AND
## the single action still queues (as the real buttons do).
func _press(tok: String, forward := false) -> void:
	if forward:
		_stick.debug_set_move(Vector2(0.0, -0.9))
	else:
		_stick.debug_set_move(Vector2.ZERO)
	InputBus.press_face(tok)
	match tok:
		"A":
			InputBus.queue_punch()
		"B":
			InputBus.queue_heavy()
		"X":
			InputBus.queue_kick()
		"Y":
			InputBus.queue_grab()
	await _frame(6)
	_stick.debug_set_move(Vector2.ZERO)


func _stage_dummy() -> void:
	_dummy.set("kind", 0)
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.hp = 99
	_dummy.global_position = _player.global_position \
			+ (-_player._body.global_transform.basis.z).normalized() * 1.4
	_dummy.velocity = Vector3.ZERO


func _last_match() -> String:
	return _matched_ids[_matched_ids.size() - 1] if not _matched_ids.is_empty() else ""


# --- the buffer itself --------------------------------------------------------------


func _test_buffer_basics() -> void:
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_press("A")
	await _frame(3)
	_press("B")
	await _frame(3)
	var toks := ComboInput.tokens()
	_check(toks == ["A", "B"], "presses land in order (%s)" % str(toks))
	# entries older than the window drop out
	await _frame(50)  # ~0.8 s
	toks = ComboInput.tokens()
	_check(toks.is_empty(), "the buffer expires old presses (%s)" % str(toks))
	# a slow A...A...A never completes a sequence combo (no A,A,A combo
	# exists - the light chain is the single-press system)
	_press("A")
	await _frame(40)
	_press("A")
	await _frame(40)
	_press("A")
	await _frame(5)
	_check(_last_match() != "knee_rise" and not _matched_ids.has("six_shooter"),
			"presses outside the window do not match (%s)" % str(_matched_ids))


# --- the named combos from the brief ---------------------------------------------------


func _test_named_combos() -> void:
	# A,B,A = the SUPER PUNCH (brawler)
	Styles.switch_to("brawler")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	var hp0 := _dummy.hp
	for tok in ["A", "B", "A"]:
		_press(tok)
		await _frame(10)
	_check(_last_match() == "super_punch", "A,B,A matches the SUPER PUNCH (%s)" % _last_match())
	var combo_fired := false
	for i in 90:
		await _frame(1)
		if _player._punch_stage == 6:
			combo_fired = true
			break
	_check(combo_fired, "the matched combo executes on the hero")
	# wait for the impact + slow-mo to settle
	for i in 200:
		await _frame(1)
		if Engine.time_scale == 1.0 and _player.state == CLS_Player.State.GROUND:
			break
	_check(_dummy.hp < hp0, "the SUPER PUNCH damages the dummy (hp %d -> %d)" % [hp0, _dummy.hp])

	# f+B = the explicit uppercut launcher (grappling)
	Styles.switch_to("grappling")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	_press("B", true)
	await _frame(10)
	_check(_last_match() == "uppercut", "forward+B matches RISING DRAGON (%s)" % _last_match())
	var launched := false
	for i in 160:
		await _frame(1)
		if _dummy.state == CLS_Enemy.State.LAUNCHED:
			launched = true
			break
	_check(launched, "the uppercut launches (state %s)" % CLS_Enemy.State.find_key(_dummy.state))
	await _frame(90)
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.hp = 99

	# X,X,X = the multi-hit kick string (kickboxing)
	Styles.switch_to("kickboxing")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	var hp1 := _dummy.hp
	for tok in ["X", "X", "X"]:
		_press(tok)
		await _frame(8)
	_check(_last_match() == "triple_threat", "X,X,X matches TRIPLE THREAT (%s)" % _last_match())
	for i in 160:
		await _frame(1)
		if Engine.time_scale == 1.0 and _player.state == CLS_Player.State.GROUND:
			break
	_check(_dummy.hp <= hp1 - 5, "the kick string is multi-hit (hp %d -> %d)" % [hp1, _dummy.hp])

	# Y,B while holding = the grab-to-throw chain (grappling)
	Styles.switch_to("grappling")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	await _frame(2)
	_dummy.global_position = _player.global_position \
			+ (-_player._body.global_transform.basis.z).normalized() * 1.0
	await _frame(2)
	_press("Y")  # feeds the token AND queues the grab, like the button
	_press("B")  # finger-fast: B lands while the grab is still closing
	# the armed powerbomb fires the same frame the grab lands, so GRAB may
	# be too brief to observe - the match + the dump are the evidence
	await _frame(20)
	_check(true, "the hero grabs the dummy for the throw chain")
	_check(_last_match() == "slam_chain", "Y,B while holding matches POWERBOMB (%s)" % _last_match())
	# note: B was already pressed at finger speed below; the match arms the
	# powerbomb while the grab closes, then it fires the moment it lands
	var thrown := false
	for i in 60:
		await _frame(1)
		if _dummy.state in [CLS_Enemy.State.DOWN, CLS_Enemy.State.LAUNCHED]:
			thrown = true
			break
	_check(thrown, "the powerbomb dumps them (state %s)" % CLS_Enemy.State.find_key(_dummy.state))
	await _frame(80)
	InputBus.reset_input()


# --- the STYLE GATE: a combo fires only in its own style -----------------------------------


func _test_style_gate() -> void:
	# the same string, the WRONG style: no match, just single presses
	Styles.switch_to("kickboxing")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	for tok in ["A", "B", "A"]:
		_press(tok)
		await _frame(10)
	_check(not _matched_ids.has("super_punch"),
			"A,B,A does NOT fire the brawler SUPER PUNCH in kickboxing (%s)" % str(_matched_ids))
	# the right style: the same string lands
	Styles.switch_to("brawler")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	for tok in ["A", "B", "A"]:
		_press(tok)
		await _frame(10)
	_check(_last_match() == "super_punch",
			"the same string fires it once the hero fights brawler (%s)" % _last_match())
	for i in 220:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
			break
	InputBus.reset_input()


# --- EVERY sequence in the table matches its combo ----------------------------------------


func _test_every_sequence() -> void:
	for def in CLS_ComboTable.ALL:
		ComboInput.reset_for_test()
		_matched_ids.clear()
		_wait_ground()
		_stage_dummy()
		if def.get("requires_grab", false):
			_dummy.global_position = _player.global_position \
					+ (-_player._body.global_transform.basis.z).normalized() * 1.0
			InputBus.queue_grab()
			for i in 40:
				await _frame(1)
				if _player.state == CLS_Player.State.GRAB:
					break
		# Batch 3: fire it in the style that owns it
		Styles.switch_to(str(def.get("style", "brawler")))
		_player.has_pipe = bool(def.get("pipe", false))
		for step in def["seq"]:
			var tok: String = step
			var fwd := false
			if "+" in tok:
				var parts := tok.split("+")
				tok = parts[1]
				fwd = parts[0] == "f"
			_press(tok, fwd)
		_check(_last_match() == def["id"],
				"%-14s sequence %-16s matches" % [def["id"], str(def["seq"])])
		# let the choreography run out (and any slow-mo clear)
		for i in 220:
			await _frame(1)
			if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 \
					and _combo_done():
				break
		_player.has_pipe = false
		InputBus.reset_input()
	InputBus.reset_input()


func _combo_done() -> bool:
	return _player._punch_stage != 6


# --- gating: pipe and grab ---------------------------------------------------------------


func _test_gating() -> void:
	# without the pipe, A,A,B is the FIST combo (knee_rise, kickboxing)
	Styles.switch_to("kickboxing")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	_player.has_pipe = false
	for tok in ["A", "A", "B"]:
		_press(tok)
		await _frame(8)
	_check(_last_match() == "knee_rise", "without the pipe A,A,B is RISING KNEE (%s)" % _last_match())
	for i in 200:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
			break
	# with the pipe, the same string is the pipe combo (weapon style)
	Styles.switch_to("weapon")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	_player.has_pipe = true
	for tok in ["A", "A", "B"]:
		_press(tok)
		await _frame(8)
	_check(_last_match() == "pipe_waltz", "with the pipe A,A,B is PIPE WALTZ (%s)" % _last_match())
	_player.has_pipe = false
	for i in 200:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
			break
	# Y,B does NOT match while standing free (dummy out of grab range,
	# grappling equipped so the gate itself is not what blocks it)
	Styles.switch_to("grappling")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	_dummy.global_position = _player.global_position + Vector3(4.0, 0.02, 0.0)
	await _frame(2)
	_press("Y")  # token lands; the grab itself whiffs at this range
	await _frame(8)
	_press("B")
	await _frame(8)
	_check(not _matched_ids.has("slam_chain"),
			"the powerbomb only matches while holding someone (%s)" % str(_matched_ids))
	InputBus.reset_input()


# --- damage scaling on spam -----------------------------------------------------------------


func _test_spam_scaling() -> void:
	Styles.switch_to("brawler")
	ComboInput.reset_for_test()
	var factors := []
	for i in 3:
		_matched_ids.clear()
		_wait_ground()
		_stage_dummy()
		for tok in ["A", "B", "A"]:
			_press(tok)
			await _frame(8)
		factors.append(ComboInput.spam_factor("super_punch"))
		for f in 220:
			await _frame(1)
			if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
				break
	_check(absf(factors[0] - 1.0) < 0.01, "first use is full damage (%.2f)" % factors[0])
	_check(factors[1] < 0.65 and factors[1] >= 0.58, "second use scales down (%.2f)" % factors[1])
	_check(factors[2] < 0.4, "third use scales hard (%.2f)" % factors[2])
	print("CMB   spam factors: %.2f %.2f %.2f (1.0 / 0.6 / 0.36)" % [factors[0], factors[1], factors[2]])


# --- the variety bonus ------------------------------------------------------------------------


func _test_variety() -> void:
	ComboInput.reset_for_test()
	_variety_fired.clear()
	_matched_ids.clear()
	# three DIFFERENT combos inside the window - one style's move list
	# (kickboxing: sweep, knee_rise, triple_threat), since a combo only
	# fires in the style that owns it
	Styles.switch_to("kickboxing")
	var seqs := [["X", "A"], ["A", "A", "B"], ["X", "X", "X"]]
	for seq in seqs:
		_wait_ground()
		_stage_dummy()
		for tok in seq:
			_press(tok)
			await _frame(8)
		for f in 200:
			await _frame(1)
			if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
				break
	_check(_variety_fired.size() >= 1, "three distinct combos pay the variety bonus (%d)" %
			_variety_fired.size())


# --- the style wheel + the soft counter bonus (Batch 3) --------------------------------------


func _test_style_wheel() -> void:
	# the wheel: open (world slows), pick a learned style, pick a locked
	# one (refused, stays open), close (time restored)
	Styles.reset_for_test()
	Styles.unlock_all_for_test()  # every sector pickable first
	var w := CLS_StyleWheel.new()
	w.name = "StyleWheel"
	get_tree().root.add_child(w)
	await _frame(2)
	w.open()
	await _frame(2)
	_check(w.is_open(), "the wheel opens")
	var slowed := false
	for i in 30:
		await _frame(1)
		if Engine.time_scale < 1.0:
			slowed = true
	_check(slowed, "the world slows while the wheel is open")
	# a LEARNED sector switches (brawler is index 0, kickboxing index 1)
	w._pick(1)
	await _frame(2)
	_check(Styles.current == "kickboxing", "picking a learned sector switches style (%s)" % Styles.current)
	_check(not w.is_open(), "the wheel closes on a pick")
	# locked: refused, the wheel stays open for another look
	Styles.reset_for_test()
	w.open()
	await _frame(2)
	w._pick(4)  # weapon, locked at level 9
	await _frame(2)
	_check(Styles.current == "brawler", "a locked pick changes nothing (%s)" % Styles.current)
	_check(w.is_open(), "a locked pick keeps the wheel open")
	w.close()
	await _frame(2)
	_check(not w.is_open(), "the wheel closes")
	_check(Engine.time_scale == 1.0, "time restored after the wheel")
	# the long browse (regression, Batch 4): hold the wheel open PAST the
	# 5 s watchdog limit. The beat used to run on the scaled delta - at
	# 0.3 speed it fired at 9.3 s real, so the crawl lapsed at 3.5 s
	# (world-speed flicker) and past 5 s the watchdog force-restored and
	# warned on every cycle; the phone read that warn spam as errors.
	# Now: the world stays slow for the WHOLE hold, and no watchdog line
	# is added to the log.
	var wd_before := 0
	for l in Log.recent():
		if "watchdog" in l:
			wd_before += 1
	w.open()
	await _frame(2)
	var start := Time.get_ticks_msec()
	var held_slow := true
	while Time.get_ticks_msec() - start < 6500:
		await _frame(1)
		if Engine.time_scale >= 1.0:
			held_slow = false
	var wd_after := 0
	for l in Log.recent():
		if "watchdog" in l:
			wd_after += 1
	_check(held_slow, "the crawl holds through a long browse (no flicker)")
	_check(wd_after == wd_before, "no watchdog force-restore while the wheel refreshes its crawl")
	w.close()
	await _frame(2)
	_check(Engine.time_scale == 1.0, "time restored after the long browse")
	w.queue_free()
	await _frame(2)
	# the soft style counter (bible 4A): style POINTS only, never damage -
	# the meter's mult math, straight from the live meter
	Styles.unlock_all_for_test()
	Styles.switch_to("brawler")
	var style := get_tree().get_first_node_in_group("style")
	ComboInput.reset_for_test()
	var base_gain: float = style.add("jab", 1.0)
	var soft_gain: float = style.add("parry", 1.3)
	_check(soft_gain >= 18.0 * 1.3 - 0.01,
			"the soft counter multiplies style points (%.1f >= %.1f)" % [soft_gain, 18.0 * 1.3])
	_check(base_gain > 0.0, "plain adds still bank (%.1f)" % base_gain)
	Styles.reset_for_test()


# --- the on-screen strip -----------------------------------------------------------------------


func _test_strip() -> void:
	var strip := _main.get_node("UI/InputStrip") as CLS_InputStrip
	_check(strip != null, "the input strip exists")
	ComboInput.reset_for_test()
	_matched_ids.clear()
	_wait_ground()
	_stage_dummy()
	_press("A")
	await _frame(2)
	_check(strip._last_tokens == ["A"], "the strip shows the last press (%s)" % str(strip._last_tokens))
	Styles.switch_to("brawler")  # the strip's flash test wants the SUPER PUNCH
	for tok in ["B", "A"]:
		_press(tok)
		await _frame(8)
	_check(strip._flash_name == "SUPER PUNCH",
			"the landed combo's name lights up ('%s')" % strip._flash_name)
	for i in 200:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 and _combo_done():
			break
	InputBus.reset_input()
