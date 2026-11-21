extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_RetryOffer := preload("res://scripts/retry_offer.gd")
## Batch 6 suite: the Ledger (bible 14 + 4G + the 30-min loop). The debt
## book engine: the 5000 split, live interest, the day clock (only time
## turns the day - beats are the day's action budget), beats as the
## price of answering, missed payments, DEFAULT (the city hunts), Death
## = Debt on a lapsed offer, S-rank payoffs, dirty/clean money, the 20%
## launder cut, and the phone's LEDGER app with its Trust column.

var _fails := 0
var _checks := 0
var _player: CharacterBody3D
var _ui: CanvasLayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("DEBT FAIL: ", what)
	else:
		print("DEBT ok: ", what)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.2)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# one pair of eyes on the street: the witness multiplier sits at
	# x1.0 and every heat assertion in this suite is deterministic
	Heat.test_pin_eyes = 1
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _frame(2)
	_player = main.get_node("Player") as CharacterBody3D
	_ui = get_node("/root/Phone/PhoneUI") as CanvasLayer
	var thug := main.get_node("Thug") as CharacterBody3D
	thug.state = CLS_Enemy.State.IDLE
	thug.global_position = Vector3(30.0, 0.02, 30.0)
	Tuning.set_v("beat_real_seconds", 1.0)  # a 3-second day, for the suite

	await _test_book()
	await _test_interest_and_srank()
	await _test_death_debt()
	await _test_beats()
	await _test_payments()
	await _test_dirty_money()
	await _test_default()
	await _test_save()

	Tuning.set_v("beat_real_seconds", 360.0)
	if _fails == 0:
		print("DEBT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("DEBT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _calm() -> void:
	Phone.close()
	for i in 120:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Phone.state == Phone.State.IDLE:
			break
	InputBus.clear_queues()


# --- A. the book (the phone's LEDGER app) --------------------------------------


func _test_book() -> void:
	Ledger.reset_for_test()
	Phone.reset_for_test()
	await _calm()
	_check(Ledger.total_debt() == 5000.0 and is_equal_approx(Ledger.debt["family"], 3500.0)
			and is_equal_approx(Ledger.debt["corp"], 1500.0),
			"the book opens at $5000 (Family 3500 / Corporation 1500)")
	Phone.open()
	await _frame(2)
	var ledger_btn := _ui.get_node("Screen/Apps/LedgerBtn") as Button
	_check(ledger_btn != null, "the phone has the LEDGER app tile")
	ledger_btn.pressed.emit()
	await _frame(2)
	var body := _ui.get_node("Screen/AppBody") as VBoxContainer
	_check(body.visible, "the LEDGER app opens")
	var strip := body.get_child(0) as Label
	_check(strip != null and strip.text.begins_with("DAY 1"), "the day strip reads DAY 1")
	var has_trust := _find_text(body, "TRUST")
	var pay_buttons := _count_buttons(body, "PAY")
	_check(has_trust, "the Ledger always shows Trust (bible line 106)")
	_check(pay_buttons >= 2, "the lenders carry pay chips (%d)" % pay_buttons)
	Phone.close()


# --- B. live interest + the S-rank payoff ----------------------------------------


func _test_interest_and_srank() -> void:
	await _calm()
	Ledger.reset_for_test()
	await _wait_s(1.2)
	_check(Ledger.debt["family"] > 3500.5 and Ledger.debt["corp"] > 1500.5,
			"interest ticks live (family %.2f, corp %.2f)" % [Ledger.debt["family"], Ledger.debt["corp"]])
	# each banked S-rank cuts 5% of the balance, compounded per rank
	var t0 := Ledger.total_debt()
	FightScore.pending_s_ranks = 3
	await _frame(3)
	var expected := t0 * 0.95 * 0.95 * 0.95
	_check(FightScore.pending_s_ranks == 0,
			"the Ledger consumes the banked S-ranks")
	# live interest keeps ticking under the cut - the tolerance eats it
	_check(absf(Ledger.total_debt() - expected) < 8.0,
			"3 S-ranks cut 5%% each (%.1f -> %.1f)" % [t0, Ledger.total_debt()])


# --- C. death = debt (the lapsed offer) -------------------------------------------


func _test_death_debt() -> void:
	await _calm()
	Ledger.reset_for_test()
	var fam0: float = Ledger.debt["family"]
	var offer := CLS_RetryOffer.new()
	offer._t = 0.05
	add_child(offer)
	await _wait_s(0.3)
	# the tolerance eats the live interest of the wait itself
	_check(absf(Ledger.debt["family"] - fam0 - 800.0) < 25.0,
			"a lapsed offer is Death = Debt: +$800 to The Family (%+.0f)" % (Ledger.debt["family"] - fam0))
	var text_hit: bool = Phone.log_entries().any(
			func(e): return e.get("outcome") == "text" and e.get("caller") == "family")
	_check(text_hit, "The Family texts the debt you now owe them")
	offer.queue_free()


# --- D. beats: the day's action budget --------------------------------------------


func _test_beats() -> void:
	await _calm()
	Ledger.reset_for_test()
	Phone.reset_for_test()
	await _frame(2)
	Phone.ring("brother", "demand")
	Phone.answer()
	_check(Phone.state == Phone.State.ON_CALL and Ledger.beats_left == 2,
			"answering spends a Beat (2 left)")
	Phone.hang_up()
	Ledger.spend_beat("debug")
	Ledger.spend_beat("debug")
	_check(Ledger.beats_left == 0, "a day holds three beats, no more")
	Phone.ring("brother", "demand")
	await _frame(2)
	_check(Phone.answer() == false and Phone.state == Phone.State.RINGING,
			"no beats left: the answer is refused, the ring burns on")
	var answer_btn := _find_button(_ui.get_node("RingBanner"), "NO BEATS LEFT")
	_check(answer_btn != null and answer_btn.disabled
			and answer_btn.text == "NO BEATS LEFT",
			"the banner says NO BEATS LEFT and will not answer")
	Phone.decline()
	# the day turns on the clock alone: beats refill, the unpaid day counts
	var day0 := Ledger.day
	var waited := 0.0
	while Ledger.day == day0 and waited < 6.0:
		await _wait_s(0.4)
		waited += 0.4
	_check(Ledger.day == day0 + 1 and Ledger.beats_left == 3,
			"the day rolls on the clock; three fresh beats (day %d)" % Ledger.day)
	_check(Ledger.missed_payments == 1,
			"the day's interest went unpaid: missed payment 1 of 3")
	var missed_text: bool = Phone.log_entries().any(
			func(e): return str(e.get("text", "")).contains("MISSED PAYMENT 1 of 3"))
	_check(missed_text, "the missed payment lands as a phone text")
	_check(Ledger._tick_count >= 2, "the faint debt-tick pulse fired (%d)" % Ledger._tick_count)


# --- E. payments cover the day ------------------------------------------------------


func _test_payments() -> void:
	await _calm()
	Wallet.reset_for_test()
	Wallet.earn(10000, "test stake")  # the payoff needs real money
	# align to a FRESH day first: the previous day's books must be closed
	# before this phase pays, or its unpaid interest counts against it
	var d := Ledger.day
	var waited := 0.0
	while Ledger.day == d and waited < 6.0:
		await _wait_s(0.4)
		waited += 0.4
	var misses0 := Ledger.missed_payments
	Ledger.pay("family", int(Ledger.debt["family"]) + 1)
	Ledger.pay("corp", int(Ledger.debt["corp"]) + 1)
	_check(Ledger.total_debt() < 1.0, "paying all clears the book")
	d = Ledger.day
	waited = 0.0
	while Ledger.day == d and waited < 6.0:
		await _wait_s(0.4)
		waited += 0.4
	_check(Ledger.missed_payments == misses0,
			"a day paid in full is not a missed payment")


# --- F. dirty money, laundering -----------------------------------------------------


func _test_dirty_money() -> void:
	await _calm()
	Ledger.reset_for_test()
	Phone.reset_for_test()
	Trust.reset_for_test()
	Wallet.reset_for_test()
	_check(Wallet.total() == 150 and Wallet.dirty == 0,
			"the wallet starts clean ($150)")
	# street style money lands in the dirty pocket
	var style := get_tree().get_first_node_in_group("style") as Node
	var d0: int = Wallet.dirty
	style.add("jab")
	style.add("jab")
	_check(Wallet.dirty > d0, "style show money pays DIRTY (bible 4G)")
	# paying a lender draws clean first, then dirty
	Wallet.earn_dirty(100, "test purse")
	var purse: int = Wallet.dirty - 100  # what the jabs paid
	var f0: float = Ledger.debt["family"]
	Ledger.pay("family", 200)
	_check(is_equal_approx(Ledger.debt["family"], f0 - 200.0),
			"the lender takes $200")
	_check(Wallet.cash == 0 and Wallet.dirty == purse + 50,
			"clean drains first, dirty covers the rest (cash %d dirty %d)" % [Wallet.cash, Wallet.dirty])
	# laundering: 20% cut through the Club Owner, all of the pocket
	var clean0: int = Wallet.cash
	var pocket: int = Wallet.dirty
	var got := Ledger.launder(Wallet.dirty)
	_check(got == int(round(pocket * 0.8)) and Wallet.cash == clean0 + got
			and Wallet.dirty == 0,
			"laundering takes the 20%% cut ($%d -> $%d clean)" % [pocket, got])
	# the estranged are shown the door
	Trust.add("club_owner", -45.0, "test")
	_check(Trust.tier("club_owner") == "estranged" and Ledger.launder(100) == 0,
			"an estranged Club Owner will not launder")
	Trust.reset_for_test()


# --- G. default: the city hunts -------------------------------------------------------


func _test_default() -> void:
	await _calm()
	Ledger.reset_for_test()
	Ledger.debug_default()
	_check(Ledger.defaulted, "three misses = default")
	var all_hostile := true
	for d in City.DISTRICTS:
		all_hostile = all_hostile and City.hostile.get(d, false)
	_check(all_hostile, "every block turns hostile (the manhunt)")
	_check(Heat.heat >= 4.0, "the heat pins high (%.1f)" % Heat.heat)
	var def_text: bool = Phone.log_entries().any(
			func(e): return str(e.get("text", "")).contains("DEFAULT"))
	_check(def_text, "the default lands as a phone text")
	var t0 := Ledger.total_debt()
	await _wait_s(0.8)
	_check(absf(Ledger.total_debt() - t0) < 0.5,
			"default freezes the interest (the hunt is the price now)")
	_check(Ledger.spend_beat("debug") == false,
			"defaulted: no beats, no calls, only running")


# --- H. the save round-trip -----------------------------------------------------------


func _test_save() -> void:
	await _calm()
	Ledger.reset_for_test()
	Phone.reset_for_test()
	Wallet.reset_for_test()
	Ledger.spend_beat("debug")
	Ledger.spend_beat("debug")
	Wallet.earn_dirty(60, "test purse")
	Ledger.pay("corp", 30)
	var d0 := Ledger.total_debt()
	var day0 := Ledger.day
	var beats0 := Ledger.beats_left
	var dirty0: int = Wallet.dirty
	_check(SaveGame.save_all(), "the save writes (v6 carries the debt book)")
	Ledger.reset_for_test()
	Wallet.reset_for_test()
	SaveGame.load_all()
	await _frame(2)
	_check(absf(Ledger.total_debt() - d0) < 10.0 and Ledger.day == day0
			and Ledger.beats_left == beats0,
			"the save round-trips the debt book (day %d, %d beats)" % [Ledger.day, Ledger.beats_left])
	_check(Wallet.dirty == dirty0, "the save round-trips dirty money (%d)" % Wallet.dirty)


# --- node finders (the book builds nested cards) --------------------------------


func _find_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _find_text(child, text):
			return true
	return false


func _count_buttons(node: Node, prefix: String) -> int:
	var n := 0
	if node is Button and (node as Button).text.begins_with(prefix):
		n += 1
	for child in node.get_children():
		n += _count_buttons(child, prefix)
	return n


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var hit := _find_button(child, text)
		if hit:
			return hit
	return null
