extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_Hangout := preload("res://scripts/hangout.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_RetryOffer := preload("res://scripts/retry_offer.gd")
## Batch 7 suite: friends and Trust made real (bible 4D). The hangouts
## (four themes, one timing skeleton, a Beat each), the grades (+15
## flat, +8 for a WIDE - first pass), promise redemption through the
## phone's invitation calls, the blocked chips (STOPPED CALLING /
## STREET'S HOT / NO BEATS), and the tier effects in a fight: a Close
## friend saves the knockdown blow once, a Drifting friend hesitates
## through the first one, an Estranged friend never answers.

var _fails := 0
var _checks := 0
var _player: CharacterBody3D
var _ui: CanvasLayer
var _thug: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FRIENDS FAIL: ", what)
	else:
		print("FRIENDS ok: ", what)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
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
	_thug = main.get_node("Thug") as CharacterBody3D
	_thug.state = CLS_Enemy.State.IDLE
	_thug.global_position = Vector3(30.0, 0.02, 30.0)

	await _test_invite_flow()
	await _test_grades()
	await _test_promises()
	await _test_blocked()
	await _test_saves()
	await _test_player_hook()
	await _test_calm_reset()

	if _fails == 0:
		print("FRIENDS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("FRIENDS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _calm() -> void:
	Phone.close()
	for i in 120:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Phone.state == Phone.State.IDLE:
			break
	InputBus.clear_queues()


func _reset_all() -> void:
	Ledger.reset_for_test()
	Phone.reset_for_test()
	Trust.reset_for_test()
	FriendHelp.reset_for_test()
	_thug.state = CLS_Enemy.State.IDLE


# --- A. the invite, end to end: Ledger chip -> hangout -------------------------


func _test_invite_flow() -> void:
	_reset_all()
	await _calm()
	Phone.open()
	await _frame(2)
	(_ui.get_node("Screen/Apps/LedgerBtn") as Button).pressed.emit()
	await _frame(2)
	var invite: Button = null
	for b in _find_buttons(_ui.get_node("Screen/AppBody"), "INVITE"):
		invite = b
		break
	_check(invite != null and not invite.disabled,
			"the Trust column carries a live INVITE chip")
	invite.pressed.emit()
	await _frame(2)
	var hang := _tree_hangout()
	_check(hang != null, "the invite opens a hangout")
	_check(Phone.state == Phone.State.IDLE, "the phone hangs up first")
	_check(Ledger.beats_left == 2, "the hangout spends a Beat (2 left)")
	_check(_find_text(hang, "FISHING - BROTHER"),
			"the Brother's hangout is FISHING")
	# dead center locks PERFECT
	hang._t = 0.5
	hang.lock()
	await _frame(2)
	_check(Trust.value("brother") == 85.0,
			"PERFECT pays the bible's +15 (%.0f)" % Trust.value("brother"))
	_check(_find_text(hang, "PERFECT"), "the grade reads PERFECT")
	hang.close()
	await _frame(2)
	_check(_tree_hangout() == null, "WALK THEM HOME clears out")


func _tree_hangout() -> CLS_Hangout:
	for n in get_tree().root.get_children():
		if n is CLS_Hangout:
			return n
	return null


# --- B. the three grades ---------------------------------------------------------


func _test_grades() -> void:
	_reset_all()
	await _calm()
	for grade in [["GOOD", 0.30, 15.0], ["WIDE", 0.99, 8.0]]:
		var v0 := Trust.value("mechanic")
		var h := CLS_Hangout.new()
		get_tree().root.add_child(h)
		h.open("mechanic")
		await _frame(2)
		h._t = grade[1]
		h.lock()
		await _frame(2)
		_check(Trust.value("mechanic") == v0 + grade[2],
				"%s pays +%d (%.0f)" % [grade[0], int(grade[2]), Trust.value("mechanic") - v0])
		h.close()
		await _frame(2)


# --- C. promises: the invitation call, the redemption -----------------------------


func _test_promises() -> void:
	_reset_all()
	await _calm()
	Phone.ring("drunk", "invitation")
	Phone.answer()
	while Phone.advance_line():
		await _frame(1)
	Phone.choose("in")
	_check(Phone.promises().size() == 1,
			"saying I'M IN banks a promise (%d)" % Phone.promises().size())
	# the friend will not stack asks: a second accept does not double it
	Phone.ring("drunk", "invitation")
	Phone.answer()
	while Phone.advance_line():
		await _frame(1)
	Phone.choose("in")
	_check(Phone.promises().size() == 1,
			"one open promise per friend (still %d)" % Phone.promises().size())
	# the hangout redeems it
	var h := CLS_Hangout.new()
	get_tree().root.add_child(h)
	h.open("drunk")
	await _frame(2)
	h._t = 0.5
	h.lock()
	await _frame(2)
	_check(Phone.promises().is_empty(), "the hangout redeems the promise")
	var redeemed: bool = Phone.log_entries().any(
			func(e): return e.get("outcome") == "redeemed" and e.get("caller") == "drunk")
	_check(redeemed, "the log records the promise kept")
	_check(_find_text(h, "a promise kept"), "the result says it out loud")
	h.close()
	await _frame(2)


# --- D. the blocked chips -----------------------------------------------------------


func _test_blocked() -> void:
	_reset_all()
	await _calm()
	Trust.add("drunk", -45.0, "test")
	_check(Trust.tier("drunk") == "estranged"
			and CLS_Hangout.blocked("drunk") == "STOPPED CALLING",
			"an Estranged friend is done hanging out")
	# freeze the thug's AI so the hand-set state sticks
	_thug.set_physics_process(false)
	_thug.state = CLS_Enemy.State.WALK
	await _frame(2)
	_check(CLS_Hangout.blocked("brother") == "STREET'S HOT",
			"no inviting anyone out while the street hunts")
	_thug.state = CLS_Enemy.State.IDLE
	_thug.set_physics_process(true)
	await _frame(2)
	while Ledger.beats_left > 0:
		Ledger.spend_beat("debug")
	_check(CLS_Hangout.blocked("brother") == "NO BEATS",
			"a spent day has no beats for hangouts")


# --- E. the tier rules of the save ----------------------------------------------------


func _test_saves() -> void:
	_reset_all()
	await _calm()
	# CLOSE: the save comes now, once
	_check(FriendHelp.try_save(_thug, _player.global_position),
			"a Close friend answers the blow")
	_check(_thug.state == CLS_Enemy.State.STAGGER,
			"the attacker eats the gold stagger")
	_check(not FriendHelp.try_save(_thug, _player.global_position),
			"the save is once per fight")
	# DRIFTING: hesitation - the first knockdown plays out
	FriendHelp.reset_for_test()
	Trust.add("brother", -20.0, "test")
	Trust.add("mechanic", -20.0, "test")
	Trust.add("club_owner", -20.0, "test")
	Trust.add("drunk", -20.0, "test")
	_check(not FriendHelp.try_save(_thug, _player.global_position),
			"a Drifting friend hesitates through the first one")
	FriendHelp.note_knockdown()
	_check(FriendHelp.try_save(_thug, _player.global_position),
			"the second knockdown they do answer")
	# ESTRANGED: never (drag everyone under the <30 line)
	FriendHelp.reset_for_test()
	for id in Trust.FRIENDS:
		Trust.add(id, -40.0, "test")
	_check(Trust.tier("brother") == "estranged"
			and not FriendHelp.try_save(_thug, _player.global_position),
			"an Estranged friend never answers")


# --- F. the real hook: the player's guard-broken hit ------------------------------------


func _test_player_hook() -> void:
	_reset_all()
	await _calm()
	Composure.drain(999.0, "test")
	_check(Composure.guard_broken(), "the guard is gone")
	var r: String = _player.take_hit(Vector3(1.0, 0.0, 0.0), _thug)
	await _frame(2)
	_check(r == "hit" and _find_offer() == null,
			"the saved hero never sees the knockdown offer")
	_check(_thug.state == CLS_Enemy.State.STAGGER,
			"the attacker pays for it in gold")
	# the save is spent: the same blow now knocks down + offers the retry
	_player.take_hit(Vector3(1.0, 0.0, 0.0), _thug)
	await _frame(2)
	var offer := _find_offer()
	_check(offer != null, "without the save the offer shows (the knockdown landed)")
	if offer:
		offer.queue_free()


func _find_offer() -> CLS_RetryOffer:
	for n in get_tree().root.get_children():
		if n is CLS_RetryOffer:
			return n
	return null


# --- G. the fight ends, the counters reset ------------------------------------------------


func _test_calm_reset() -> void:
	_reset_all()
	await _calm()
	FriendHelp.try_save(_thug, _player.global_position)
	_thug.state = CLS_Enemy.State.IDLE  # the save staggered him; clear it
	_check(FriendHelp.fighting() == false, "the street is calm")
	await _wait_s(9.5)
	_check(FriendHelp.try_save(_thug, _player.global_position),
			"after the calm the save is fresh again")


# --- finders -------------------------------------------------------------------------------


func _find_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _find_text(child, text):
			return true
	return false


func _find_buttons(node: Node, prefix: String) -> Array:
	var hits: Array = []
	if node is Button and (node as Button).text.begins_with(prefix):
		hits.append(node)
	for child in node.get_children():
		hits.append_array(_find_buttons(child, prefix))
	return hits
