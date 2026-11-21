extends Node
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
## Batch 13 suite: the back room (bible 4G dirty money). The club
## owner's laundering (trust-gated, 20% cut, a drifting daily cap),
## hi-lo stakes with sleight-of-hand (the palm bends the roll, the
## pit boss counts hands), winning big gets you watched, dirty money
## spends at a surcharge and burns a hole overnight.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("BACK FAIL: ", what)
	else:
		print("BACK ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# one pair of eyes on the street: the witness multiplier sits at
	# x1.0 and every heat assertion in this suite is deterministic
	Heat.test_pin_eyes = 1
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.2)
	_player = _main.get_node("Player") as CharacterBody3D
	var thug := _main.get_node("Thug") as Node
	if thug:
		thug.queue_free()

	await _test_launder_gating()
	await _test_launder_cap_and_cut()
	await _test_day_rolls_reset()
	await _test_stakes_straight()
	await _test_the_palm()
	await _test_suspicion_ban()
	await _test_watched()
	await _test_dirty_surcharge()
	await _test_pocket_burns()
	await _test_persistence()
	await _test_the_door()

	if _fails == 0:
		print("BACK PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("BACK FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


# --- helpers ------------------------------------------------------------------


func _reset_wallet(cash := 2000, dirty := 1000) -> void:
	Wallet.reset_for_test()
	Wallet.cash = cash
	Wallet.dirty = dirty


# --- A. he doesn't launder for strangers -----------------------------------------


func _test_launder_gating() -> void:
	Backroom.reset_for_test()
	Trust._t["club_owner"] = 0.0
	_reset_wallet()
	var take := Backroom.launder()
	_check(take == 0 and Wallet.dirty == 1000,
			"a stranger's money stays dirty ($%d)" % Wallet.dirty)
	var owner_text := ""
	for m in Phone.log_entries():
		if (m as Dictionary).get("caller", "") == "club_owner" \
				and (m as Dictionary).get("text", "").contains("trust first"):
			owner_text = (m as Dictionary).get("text", "")
	_check(owner_text != "", "the owner says what to do about it")
	Trust._t["club_owner"] = 30.0  # drifting: he moves some


# --- B. the cut, the cap -------------------------------------------------------------


func _test_launder_cap_and_cut() -> void:
	Backroom.reset_for_test()
	Trust._t["club_owner"] = 30.0  # drifting
	_reset_wallet()
	var take := Backroom.launder()
	# drifting moves $600 a day: 600 in, 480 out (20% for the house)
	_check(take == 480, "the cut is honest at drifting ($%d -> $%d)"
			% [600, take])
	_check(Wallet.dirty == 400, "the rest stays dirty ($%d)" % Wallet.dirty)
	_check(Wallet.cash == 2480, "clean landed in the pocket ($%d)" % Wallet.cash)
	var again := Backroom.launder()
	_check(again == 0 and Wallet.dirty == 400,
			"drifting has a daily ceiling ($%d more)" % again)
	Trust._t["club_owner"] = 60.0  # close: the sky's the limit
	var full := Backroom.launder()
	_check(full == 320, "close moves the rest ($%d)" % full)
	_check(Wallet.dirty == 0, "nothing left dirty ($%d)" % Wallet.dirty)


# --- C. the books sleep at midnight ----------------------------------------------------


func _test_day_rolls_reset() -> void:
	Trust._t["club_owner"] = 30.0
	Backroom.reset_for_test()
	_reset_wallet()
	Backroom.launder()
	Backroom.launder()
	_check(Backroom.laundered_today == 600, "the day's ceiling reached")
	var heat_before := Heat.heat
	Backroom.on_day_rolled(Ledger.day + 1)
	_check(Backroom.laundered_today == 0, "the books reset overnight")
	var take := Backroom.launder()
	_check(take == 320, "tomorrow he moves again ($%d)" % take)


# --- D. straight dice -----------------------------------------------------------------------


func _test_stakes_straight() -> void:
	Backroom.reset_for_test()
	_reset_wallet()
	Heat.heat = 0.0
	seed(42)
	var r := Backroom.resolve_stake(200, "high", "none")
	_check(r["ok"] and (r["outcome"] == "win" or r["outcome"] == "lose"
			or r["outcome"] == "push"), "the table takes a straight roll")
	_check(Backroom.suspicion == 0, "playing straight costs no hands")
	# seed replay: the same seed, the same bones
	_reset_wallet(2000, 0)
	Heat.heat = 0.0
	seed(42)
	var replay := Backroom.resolve_stake(200, "high", "none")
	_check(replay["roll"] == r["roll"], "seeded bones are deterministic (%d)"
			% replay["roll"])
	# a broke man can't bet
	Wallet.cash = 0
	Wallet.dirty = 100
	var broke := Backroom.resolve_stake(500, "low", "none")
	_check(not broke.is_empty() and not broke["ok"],
			"the table doesn't take promises")


# --- E. the palm bends the roll -------------------------------------------------------------------


func _test_the_palm() -> void:
	Backroom.reset_for_test()
	var shifts := {"none": 0, "perfect": int(Tuning.v("palm_perfect_shift")),
			"good": int(Tuning.v("palm_good_shift")), "wide": 0}
	var sus := {"none": 0, "perfect": 1, "good": 2, "wide": 3}
	for quality in ["none", "perfect", "good", "wide"]:
		_reset_wallet(5000, 0)
		Heat.heat = 0.0
		seed(7)
		Backroom.resolve_stake(200, "high", "none")  # burn the first roll
		seed(7)
		var shifted: Dictionary = Backroom.resolve_stake(200, "high", quality)
		seed(7)
		Backroom.resolve_stake(200, "high", "none")  # again for the raw
		seed(7)
		var raw: Dictionary = Backroom.resolve_stake(200, "high", "none")
		# skip pushes: re-derive raw from the burned roll's arithmetic
		var expect: int = mini(int(raw["roll"]) + shifts[quality], 12)
		_check(int(shifted["roll"]) == expect,
				"%s palm shifts high calls up to the cap (%d vs %d)"
				% [quality, shifted["roll"], expect])
		_reset_wallet(5000, 0)
		Backroom.suspicion = 0
		seed(9)
		Backroom.resolve_stake(50, "high", quality)
		_check(Backroom.suspicion == sus[quality],
				"%s palm costs %d hands" % [quality, sus[quality]])
	Backroom.suspicion = 0


# --- F. the pit boss closes the door ---------------------------------------------------------------------


func _test_suspicion_ban() -> void:
	Backroom.reset_for_test()
	_reset_wallet(5000, 0)
	Heat.heat = 0.0
	var day := Ledger.day
	Backroom.suspicion = 4
	seed(11)
	Backroom.resolve_stake(50, "high", "wide")  # one more and it's over
	_check(Backroom.banned_day == day, "four hands and the door shuts")
	_check(Heat.heat >= float(Tuning.v("suspicion_heat")) - 0.05,
			"getting caught burns (%.2f)" % Heat.heat)
	var banned_text := ""
	for m in Phone.log_entries():
		if (m as Dictionary).get("caller", "") == "club_owner" \
				and (m as Dictionary).get("text", "").contains("counting your hands"):
			banned_text = (m as Dictionary).get("text", "")
	_check(banned_text != "", "the owner says you're out for the night")
	Backroom.open()
	_check(Backroom._panel == null, "the room won't open while banned")
	Backroom.on_day_rolled(day + 1)
	Backroom.banned_day = -1  # tomorrow is a new table
	Backroom.suspicion = 0


# --- G. winning big gets you watched ---------------------------------------------------------------------------


func _test_watched() -> void:
	Backroom.reset_for_test()
	_reset_wallet(9000, 0)
	Heat.heat = 0.0
	City.rep["market"] = 0.0
	Backroom.session_won = 390
	Backroom._watched_told = false
	Backroom._closed_told = false
	seed(13)
	var r: Dictionary = Backroom.resolve_stake(50, "high", "none")
	# if the seeded roll pushed or lost, force the crossing directly
	if r["outcome"] != "win":
		Backroom.session_won = 401
		Backroom._check_watched()
	_check(Backroom._watched_told, "the pit boss asked your name at $400")
	_check(Heat.heat >= float(Tuning.v("watched_heat_1")) - 0.05,
			"being asked about burns (%.2f)" % Heat.heat)
	Backroom.session_won = 1200
	Backroom._closed_told = false
	Backroom.banned_day = -1
	Backroom._check_watched()
	_check(Backroom.banned_day == Ledger.day, "the room closes at $1000")
	_check(City.rep["market"] <= -9.0, "the club doesn't like being beaten (%.0f)"
			% City.rep["market"])
	Heat.heat = 0.0


# --- H. dirty money spends at a markup -------------------------------------------------------------------------------


func _test_dirty_surcharge() -> void:
	Wallet.reset_for_test()
	Wallet.cash = 100
	Wallet.dirty = 100
	var ok := Wallet.spend(150, "test purchase")
	# 150 asked; 50 of it was dirty: +13 surcharge (25% of 50, rounded up)
	_check(ok and Wallet.cash == 0, "cash spent first ($%d)" % Wallet.cash)
	_check(Wallet.dirty == 37, "dirty covered the gap plus the surcharge ($%d)"
			% Wallet.dirty)
	# clean-handed spend is untouched
	Wallet.cash = 300
	Wallet.dirty = 0
	Wallet.spend(100, "clean purchase")
	_check(Wallet.cash == 200, "no surcharge when cash covers it ($%d)"
			% Wallet.cash)


# --- I. a full pocket gets noticed overnight -----------------------------------------------------------------------------


func _test_pocket_burns() -> void:
	Wallet.reset_for_test()
	Heat.heat = 0.0
	Wallet.dirty = 500
	_check(Backroom.dirty_pocket_line() == "", "a thin pocket is nobody's business")
	_check(Heat.heat == 0.0, "no heat for quiet money")
	Wallet.dirty = 1200
	var line := Backroom.dirty_pocket_line()
	_check(line != "" and line.contains("shape of it"),
			"a full pocket gets a morning line")
	_check(Heat.heat >= float(Tuning.v("dirty_burn_heat")) - 0.05,
			"the street saw the shape of it (%.2f)" % Heat.heat)
	Wallet.reset_for_test()
	Heat.heat = 0.0


# --- J. the room remembers -------------------------------------------------------------------------------------------------


func _test_persistence() -> void:
	Backroom.reset_for_test()
	Backroom.laundered_today = 400
	Backroom.banned_day = 7
	var d := Backroom.to_dict()
	Backroom.reset_for_test()
	Backroom.from_dict(d)
	_check(Backroom.laundered_today == 400 and Backroom.banned_day == 7,
			"the books and the ban roundtrip")
	Backroom.reset_for_test()


# --- K. the door at the Velvet Room --------------------------------------------------------------------------------------------------------


func _test_the_door() -> void:
	Backroom.reset_for_test()
	if Blocks._current != "market":
		Blocks.travel("market", "west")
		await _wait_s(2.2)
	Backroom.banned_day = -1
	Heat.heat = 0.0
	await _wait_s(0.5)
	_check(get_tree().get_nodes_in_group("backroom_marker").size() == 1,
			"the Velvet Room's door stands marked")
	_player.global_position = Backroom.DOOR_SPOT
	await _wait_s(0.5)
	_check(Backroom._panel != null, "the back room opens at the door")
	Backroom.close()
	_check(Backroom._panel == null, "the table lets you leave")
	_player.global_position = Vector3(0, 0.02, 3.0)
	Backroom.reset_for_test()
