extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_TouchButtons := preload("res://scripts/touch_buttons.gd")
## Batch 5 suite: the phone (bible 4C). The ring under fire (combat
## keeps swinging, no input lock), the buzz pulse, one answer per ring,
## the answered call (dim + slow + choice), decline/miss costs on Trust
## (4D: -6), demand pay/refuse, invitation promises, Last Call once,
## the map's fog of war + heat tint, the HUD phone button, countdown
## texts and the save/load roundtrip.

var _fails := 0
var _checks := 0
var _player: CharacterBody3D
var _ui: CanvasLayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("PHONE FAIL: ", what)
	else:
		print("PHONE ok: ", what)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)  # the picker owns its own suite
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = main.get_node("Player") as CharacterBody3D
	_ui = get_node("/root/Phone/PhoneUI") as CanvasLayer
	var thug := main.get_node("Thug") as CharacterBody3D
	thug.state = CLS_Enemy.State.IDLE
	thug.global_position = Vector3(30.0, 0.02, 30.0)

	await _test_ring_under_fire()
	await _test_answer_and_pay()
	await _test_decline_and_miss()
	await _test_refuse_and_promise()
	await _test_last_call()
	await _test_map_and_button()
	await _test_texts_and_save()

	if _fails == 0:
		print("PHONE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("PHONE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _calm() -> void:
	Phone.close()
	# batch 6: answering costs beats - every phase starts with a fresh
	# day's budget (the beat economy itself is smoke_debt's to test)
	Ledger.reset_for_test()
	for i in 120:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Phone.state == Phone.State.IDLE:
			break
	InputBus.clear_queues()


# --- A. the ring under fire -----------------------------------------------------


func _test_ring_under_fire() -> void:
	Phone.reset_for_test()
	await _calm()
	var ok := Phone.ring("brother", "demand")
	_check(ok and Phone.state == Phone.State.RINGING, "the ring starts")
	_check(not InputBus.locked, "the ring never locks input (answer while swinging)")
	await _frame(2)
	_check(Phone._buzz_count >= 1, "the buzz pulse fires (slow low pulse)")
	_check(_ui.get_node("RingBanner").visible, "the ring banner shows")
	_check(Phone.ring_progress() > 0.5, "the answer window counts down")
	# combat continues under the ring
	InputBus.queue_punch()
	var swung := false
	for i in 20:
		await _frame(1)
		if _player.state == CLS_Player.State.PUNCH:
			swung = true
			break
	_check(swung, "the hero still swings while the phone rings")
	Phone.decline()  # clean the slate (cost logged below in phase C)
	Phone.reset_for_test()


# --- B. answer, pay ------------------------------------------------------------


func _test_answer_and_pay() -> void:
	await _calm()
	Phone.ring("brother", "demand")
	var answered := Phone.answer()
	await _frame(2)
	_check(answered and Phone.state == Phone.State.ON_CALL, "answering starts the call")
	_check(InputBus.locked, "the call locks input (dim + slow)")
	_check(Engine.time_scale < 0.9, "the world slows while talking (%.2f)" % Engine.time_scale)
	_check(_ui.get_node("Screen").visible, "the call screen dims the world")
	_check(not Phone.answer(), "one answer per ring - the second is refused")
	var card := _ui.get_node("Screen/CallCard") as PanelContainer
	_check(card.visible and Phone.call_lines().size() >= 1,
			"the call card shows the caller's lines")
	while Phone.advance_line():
		await _frame(1)
	_check(Phone.at_last_line() and Phone.call_choice().has("pay"),
			"the demand ends on a choice (pay/refuse)")
	var cash0: int = Wallet.cash
	Phone.choose("pay")
	await _frame(2)
	_check(Wallet.cash == cash0 - int(Tuning.v("phone_demand_cost")),
			"paying the demand costs $%d (%d -> %d)" % [int(Tuning.v("phone_demand_cost")), cash0, Wallet.cash])
	_check(Phone.state == Phone.State.IDLE and not InputBus.locked,
			"the choice ends the call and unlocks")
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored after the call")
	var paid: bool = Phone.log_entries().any(func(e): return e.get("outcome") == "paid")
	_check(paid, "the log records the paid demand")


# --- C. decline and miss cost Trust ---------------------------------------------


func _test_decline_and_miss() -> void:
	await _calm()
	Phone.ring("brother", "demand")
	Phone.decline()
	_check(is_equal_approx(Trust.value("brother"), 64.0),
			"declining costs -6 Trust (70 -> %.0f)" % Trust.value("brother"))
	_check(Phone.state == Phone.State.IDLE, "declining ends the ring")
	# a missed ring: shorten the window, let it expire
	Tuning.set_v("phone_ring_seconds", 0.5)
	Phone.ring("brother", "invitation")
	var missed := false
	for i in 60:
		await _frame(1)
		if Phone.state == Phone.State.IDLE:
			missed = true
			break
	_check(missed, "the ring expires unanswered")
	Tuning.set_v("phone_ring_seconds", 8.0)
	_check(is_equal_approx(Trust.value("brother"), 58.0),
			"missing the ring costs -6 more (64 -> %.0f)" % Trust.value("brother"))
	var voicemail: bool = Phone.log_entries().any(
			func(e): return e.get("outcome") == "missed" and e.has("voicemail"))
	_check(voicemail, "the missed call leaves a replayable voicemail")


# --- D. refuse a demand, promise an invitation -----------------------------------


func _test_refuse_and_promise() -> void:
	await _calm()
	Phone.ring("mechanic", "demand")
	Phone.answer()
	while Phone.advance_line():
		pass
	Phone.choose("refuse")
	_check(is_equal_approx(Trust.value("mechanic"), 66.0),
			"refusing the ask costs -4 (70 -> %.0f)" % Trust.value("mechanic"))
	await _calm()
	Phone.ring("club_owner", "invitation")
	Phone.answer()
	while Phone.advance_line():
		pass
	Phone.choose("in")
	_check(Phone.promises().size() == 1 and Phone.promises()[0]["caller"] == "club_owner",
			"accepting the invitation logs a promise (batch 7 redeems it)")
	_check(Phone.log_entries()[0].get("outcome") == "promised", "the log records the promise")


# --- E. Last Call, once -----------------------------------------------------------


func _test_last_call() -> void:
	await _calm()
	_check(Phone.last_call_ready(), "Last Call is armed after a first call")
	var ok := Phone.last_call_redial()
	_check(ok and Phone.state == Phone.State.RINGING, "Last Call redials the last number")
	Phone.answer()
	Phone.hang_up()
	_check(not Phone.last_call_redial() and not Phone.last_call_ready(),
			"Last Call works once per run")
	_check(Phone.log_entries()[0].get("outcome") == "answered",
			"a plain call (no choice) logs as answered")


# --- F. the map app + the HUD button ----------------------------------------------


func _test_map_and_button() -> void:
	await _calm()
	# batch 8: the home block is never fogged; walks lift the rest
	_check(Phone.has_visited("riverside"), "the home block is never fogged")
	_check(not Phone.has_visited("market") and not Phone.has_visited("foundry"),
			"unwalked blocks stay fogged (market, foundry)")
	City.set_current_district("market")
	_check(Phone.has_visited("market"), "a walked block lifts its fog")
	# the HUD button opens the apps; the map unfogs by walk, tints by heat
	var hud := get_tree().get_first_node_in_group("hud") as CLS_TouchButtons
	if hud == null:
		hud = _player.get_parent().get_node("UI") as CLS_TouchButtons
	_check(hud._buttons.has("PhoneBtn"), "the HUD has the PHONE button (both schemes)")
	hud._on_down("PhoneBtn")
	await _frame(2)
	_check(Phone.state == Phone.State.OPEN and InputBus.locked,
			"the HUD button opens the phone (locked + slow)")
	var map_btn := _ui.get_node("Screen/Apps/MapBtn") as Button
	map_btn.pressed.emit()
	await _frame(2)
	_check(_ui.get_node("Screen/AppBody").visible, "the map app opens")
	# heat tints a visited block (2.0 of 5: mid-red, responders stay asleep)
	Heat.heat = 2.0
	map_btn.pressed.emit()
	await _frame(2)
	var row := _ui.get_node("Screen/AppBody").get_child(0) as HBoxContainer
	var card := row.get_child(1) as PanelContainer  # market = the walked block
	var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sb.bg_color.r > 0.1, "heat tints the walked block (r=%.2f vs fog 0.02)" % sb.bg_color.r)
	Heat.heat = 0.0
	hud._on_down("PhoneBtn")  # toggle closed
	await _frame(2)
	_check(Phone.state == Phone.State.IDLE and not InputBus.locked
			and is_equal_approx(Engine.time_scale, 1.0),
			"closing the phone unlocks and restores time")


# --- G. countdown texts + save/load -------------------------------------------------


func _test_texts_and_save() -> void:
	await _calm()
	Phone.push_text("drunk", "The Drunk: \"Midnight. The river. Bring gloves.\"", 120)
	var txt: Dictionary = {}
	for e in Phone.log_entries():
		if e.get("outcome") == "text":
			txt = e
	_check(not txt.is_empty() and float(txt.get("countdown", 0.0)) == 120.0,
			"countdown texts ride the log (the ledger batch pushes them)")
	# the estranged stop calling (bible 4D)
	Trust.add("drunk", -45.0, "test")
	_check(Trust.tier("drunk") == "estranged" and not Phone.ring("drunk"),
			"an estranged friend does not get through")
	Trust.reset_for_test()
	# save -> wipe -> load: the phone and trust survive
	Phone._on_district("foundry", "cold")  # (district, mood)
	Trust.add("brother", -3.0, "test")
	var before_log: int = Phone.log_entries().size()
	var before_trust := Trust.value("brother")
	_check(SaveGame.save_all(), "the save writes (v5 carries phone + trust)")
	Phone.reset_for_test()
	SaveGame.load_all()
	await _frame(2)
	_check(Phone.has_visited("foundry") and Phone.log_entries().size() == before_log,
			"the save round-trips the log and the fog")
	_check(is_equal_approx(Trust.value("brother"), before_trust),
			"the save round-trips Trust (%.0f)" % Trust.value("brother"))
