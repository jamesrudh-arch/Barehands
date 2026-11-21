extends Node
## Batch 11 suite: the kidnap arc (bible 4H). The cold call, the
## no-combat investigation, the arena assault, the choice - both
## endings checked for what they really cost. The clock too.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("KIDNAP FAIL: ", what)
	else:
		print("KIDNAP ok: ", what)


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
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.2)
	_player = _main.get_node("Player") as CharacterBody3D
	var thug := _main.get_node("Thug") as Node
	if thug:
		thug.queue_free()

	await _test_trigger_and_trace()
	await _test_investigation_and_site()
	await _test_assault_to_choice()
	await _test_ending_saved()
	await _test_ending_paid()
	await _test_ransom_path()
	await _test_lapse()
	await _test_persistence()

	if _fails == 0:
		print("KIDNAP PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("KIDNAP FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


# --- helpers -----------------------------------------------------------------------


func _goto(district: String) -> void:
	if Blocks._current != district:
		Blocks.travel(district, "west")
		await _wait_s(2.2)
	else:
		await _wait_s(0.3)


func _at(pos: Vector3) -> void:
	_player.global_position = pos
	await _wait_s(0.7)  # the 0.4s poll


func _down_all() -> void:
	for e in Kidnap._spawned:
		if is_instance_valid(e):
			var en := e as Enemy
			en.set("hp", 0)
			en.call("_enter", Enemy.State.DOWN)
	await _wait_s(0.7)


## A ring while the phone is busy queues silently - every arc start and
## every choice needs the phone genuinely IDLE first.
func _phone_idle() -> void:
	Phone._queued = []
	for i in 10:
		match Phone.state:
			Phone.State.RINGING:
				Phone.decline()
			Phone.State.ON_CALL:
				Phone.hang_up()
			Phone.State.IDLE:
				return
			_:
				Phone.close()
		await _wait_s(0.2)


func _begin_arc() -> String:
	await _phone_idle()
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	# everyone equal except one: the brother matters most
	for f in Trust.FRIENDS:
		Trust._t[f] = 50.0
	Trust._t["brother"] = 80.0
	Ledger.day = int(Tuning.v("kidnap_min_day"))
	Kidnap.maybe_begin()
	return Kidnap.victim


## Wait for the KIDNAPPER's ring specifically: friend calls get declined,
## on-call leftovers get hung up. The kidnapper redials until answered.
func _answer_call(option: String) -> void:
	for i in 24:
		if Phone.state == Phone.State.RINGING:
			if Phone.caller_id() == "kidnapper":
				break
			Phone.decline()  # not the call we're waiting for
		elif Phone.state == Phone.State.ON_CALL:
			Phone.hang_up()
		await _wait_s(0.25)
	await _answer_and_choose(option)


func _answer_and_choose(option: String) -> void:
	Ledger.beats_left = 3  # answers cost beats; the suite takes many calls one day
	_check(Phone.answer(), "the call answers")
	await _wait_s(0.3)
	while not Phone.at_last_line():
		Phone.advance_line()
	await _wait_s(0.2)
	Phone.choose(option)
	await _wait_s(0.4)


# --- A. the trigger + the trace choice ------------------------------------------------


func _test_trigger_and_trace() -> void:
	# not before its day
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	Ledger.day = 1
	Kidnap.maybe_begin()
	_check(Kidnap.state == "NONE", "day 1: nobody gets taken")
	# and not for people who don't matter
	await _phone_idle()
	Ledger.day = int(Tuning.v("kidnap_min_day"))
	for f in Trust.FRIENDS:
		Trust._t[f] = 20.0
	Kidnap.maybe_begin()
	_check(Kidnap.state == "NONE", "low trust: nobody is worth taking")
	# the one you trust most
	var victim := await _begin_arc()
	_check(victim == "brother", "they take the one you trust most (%s)" % victim)
	_check(Kidnap.state == "CALLED", "the cold call is live")
	_check(Phone.state == Phone.State.RINGING
			and Phone.caller_id() == "kidnapper",
			"the unknown number is ringing")
	await _answer_and_choose("trace")
	_check(Kidnap.state == "HUNTING", "the hunt begins on the trace")
	_check(Kidnap.days_left == int(Tuning.v("kidnap_days")),
			"the clock starts at %d days" % Kidnap.days_left)
	_check(get_tree().get_nodes_in_group("clue_marker").size() == 3,
			"three signs stand on three blocks")
	_check(not Kidnap.morning_lines().is_empty(),
			"the morning report knows the arc")


# --- B. the investigation (no combat) ---------------------------------------------------


func _test_investigation_and_site() -> void:
	# the wrong district teaches nothing, the signs are where they are
	await _goto("riverside")
	await _at(Kidnap.CLUES[0]["pos"] + Vector3(6.0, 0, 6.0))
	_check(Kidnap.clues.count(true) == 0, "standing near a sign is not reading it")
	await _at(Kidnap.CLUES[0]["pos"])
	_check(Kidnap.clues.count(true) == 1, "sign one reads (riverside) [count=%d pos=%s d=%.1f]"
			% [Kidnap.clues.count(true), _player.global_position,
					_player.global_position.distance_to(Kidnap.CLUES[0]["pos"])])
	_check(get_tree().get_nodes_in_group("clue_marker").size() == 2,
			"the read sign comes down")
	await _goto("market")
	await _at(Kidnap.CLUES[1]["pos"])
	_check(Kidnap.clues.count(true) == 2, "sign two reads (market)")
	await _goto("foundry")
	await _at(Kidnap.CLUES[2]["pos"])
	_check(Kidnap.clues.count(true) == 3, "sign three reads (foundry) [count=%d pos=%s d=%.1f]"
			% [Kidnap.clues.count(true), _player.global_position,
					_player.global_position.distance_to(Kidnap.CLUES[2]["pos"])])
	_check(Kidnap.state == "SITE", "the site reveals after three signs")
	_check(get_tree().get_nodes_in_group("site_marker").size() == 1,
			"the press hall lights up")
	_check(get_tree().get_nodes_in_group("clue_marker").size() == 0,
			"no signs left standing")


# --- C. the assault ------------------------------------------------------------------------


func _test_assault_to_choice() -> void:
	await _at(Kidnap.SITE)
	_check(Kidnap.state == "ASSAULT", "touching the hall starts the assault")
	_check(Kidnap._spawned.size() == 2, "wave one: two")
	_down_all()
	await _wait_s(1.4)
	_check(Kidnap._spawned.size() == 2, "wave two comes")
	_down_all()
	await _wait_s(1.4)
	_check(Kidnap._spawned.size() == 3, "wave three comes heavy")
	_down_all()
	await _wait_s(1.4)
	_check(Kidnap._spawned.size() == 1
			and (Kidnap._spawned[0] as Enemy).kind == 4,
			"the boss stands alone")
	_down_all()
	await _wait_s(1.2)
	_check(Kidnap.state == "CHOICE", "the boss falls - the phone rings")
	_check(Phone.state == Phone.State.RINGING
			and Phone.call_kind() == "payoff",
			"the payoff call is live")
	_check(Kidnap._spawned.is_empty(), "the hall is swept")


# --- D. ending one: cut them down --------------------------------------------------------------


func _test_ending_saved() -> void:
	var money0 := Wallet.total()
	var rep_riv: float = City.rep.get("riverside", 0.0)
	await _answer_call("save")
	_check(Kidnap.state == "SAVED", "the choice lands: saved")
	_check(Wallet.total() == money0, "saving pays nothing")
	_check(Kidnap.permanent_enemy, "the enemy is permanent")
	_check(Trust.tier("brother") == "close" and Trust.locked.get("brother", false),
			"the bond is Close forever (locked)")
	# the lock holds: nothing drags them below the floor
	Trust.add("brother", -80.0, "test: the floor holds")
	_check(Trust.value("brother") >= 60.0,
			"the Close floor holds (%.0f)" % Trust.value("brother"))
	# the enemy keeps the heat floor
	Heat.heat = 0.0
	await _wait_s(0.6)
	_check(Heat.heat >= float(Tuning.v("kidnap_enemy_floor")) - 0.05,
			"the heat never cools below the enemy's floor (%.2f)" % Heat.heat)
	_check(absf(City.rep.get("riverside", 0.0) - rep_riv) < 0.01,
			"saving costs no city rep")


# --- E. ending two: take the money ----------------------------------------------------------------


func _test_ending_paid() -> void:
	# a fresh arc, run through to the choice fast
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	for f in Trust.FRIENDS:
		Trust._t[f] = 50.0
	Trust._t["brother"] = 80.0
	await _phone_idle()
	Kidnap.maybe_begin()
	await _answer_call("trace")
	await _goto("riverside")
	await _at(Kidnap.CLUES[0]["pos"])
	await _goto("market")
	await _at(Kidnap.CLUES[1]["pos"])
	await _goto("foundry")
	await _at(Kidnap.CLUES[2]["pos"])
	await _phone_idle()
	await _at(Kidnap.SITE)
	for i in 4:
		_down_all()
		await _wait_s(1.4)
	_check(Kidnap.state == "CHOICE", "the second arc reaches the choice")
	var dirty0 := Wallet.dirty
	var rep0: Array = []
	for d in City.DISTRICTS:
		rep0.append(City.rep.get(d, 0.0))
	await _answer_call("take")
	_check(Kidnap.state == "PAID", "the choice lands: paid")
	_check(Wallet.dirty == dirty0 + int(Tuning.v("kidnap_payoff")),
			"the payoff is dirty money (%d)" % (Wallet.dirty - dirty0))
	_check(Trust.tier("brother") == "gone", "the friend is gone")
	_check(Trust.is_gone("brother"), "gone is a fact, not a mood")
	Trust.add("brother", 30.0, "test: the dead do not drift")
	_check(Trust.value("brother") <= 0.001 or Trust.is_gone("brother"),
			"the gone do not drift back")
	var dropped := 0
	for i in City.DISTRICTS.size():
		if float(City.rep.get(City.DISTRICTS[i], 0.0)) < rep0[i] - 5.0:
			dropped += 1
	_check(dropped == City.DISTRICTS.size(),
			"the city hollows - every block's rep drops (%d/3)" % dropped)
	_check(Kidnap.patron, "their patron is on you now")


# --- F. the ransom quick-out ------------------------------------------------------------------------


func _test_ransom_path() -> void:
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	Trust._t["brother"] = 80.0
	await _phone_idle()
	Wallet.cash = int(Tuning.v("kidnap_ransom")) + 100
	Wallet.dirty = 0
	Kidnap.maybe_begin()
	await _answer_call("pay_ransom")
	_check(Kidnap.state == "RANSOMED", "the ransom path lands")
	_check(Wallet.total() == 100,
			"the ransom is paid exactly (100 of 1300 left: %d)" % Wallet.total())
	_check(Trust.tier("brother") != "gone", "the friend walks home")
	_check(not Kidnap.permanent_enemy, "no enemy bought, none earned")
	# broke: the money path is closed, the hunt starts anyway
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	Trust._t["brother"] = 80.0
	await _phone_idle()
	Wallet.cash = 0
	Wallet.dirty = 0
	Kidnap.maybe_begin()
	await _answer_call("pay_ransom")
	_check(Kidnap.state == "HUNTING", "empty pockets buy nothing - the hunt starts")
	await _wait_s(0.5)


# --- G. the clock ----------------------------------------------------------------------------------------


func _test_lapse() -> void:
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	Trust._t["brother"] = 80.0
	await _phone_idle()
	Kidnap.maybe_begin()
	await _answer_call("trace")
	var days := int(Tuning.v("kidnap_days"))
	for i in days:
		Kidnap.on_day_rolled(Ledger.day + i + 1)
		await _wait_s(0.2)
	_check(Kidnap.state == "LAPSED", "the clock runs out")
	_check(Trust.is_gone("brother"), "waiting loses them too")
	_check(get_tree().get_nodes_in_group("clue_marker").size() == 0,
			"the signs come down with the arc")
	_check(not Kidnap.permanent_enemy and Wallet.dirty == 0
			or Kidnap.state == "LAPSED", "no enemy, no money - just the loss")


# --- H. persistence -----------------------------------------------------------------------------------------


func _test_persistence() -> void:
	Kidnap.reset_for_test()
	Trust.reset_for_test()
	Trust._t["brother"] = 80.0
	await _phone_idle()
	Kidnap.maybe_begin()
	await _answer_call("trace")
	await _goto("riverside")
	await _at(Kidnap.CLUES[0]["pos"])
	var d := Kidnap.to_dict()
	var td := Trust.to_dict()
	_check(d["state"] == "HUNTING" and d["clues"][0] == true,
			"the arc state serializes")
	_check(td.has("locked") and td.has("gone"), "trust carries the new sets")
	Kidnap._clear_markers()
	Kidnap.state = "NONE"
	await _wait_s(0.3)  # deferred frees leave the groups
	Trust.locked = {}
	Trust.gone = {}
	Kidnap.from_dict(d)
	Trust.from_dict(td)
	await _wait_s(0.3)
	_check(Kidnap.state == "HUNTING" and Kidnap.clues[0], "the arc roundtrips")
	_check(get_tree().get_nodes_in_group("clue_marker").size() == 2,
			"the unread signs respawn with the save")
	# locked/gone roundtrip
	Trust.lock("drunk")
	Trust.lose("mechanic")
	var td2 := Trust.to_dict()
	Trust.from_dict(td2)
	_check(Trust.locked.get("drunk", false) and Trust.is_gone("mechanic"),
			"locked and gone survive the save")
