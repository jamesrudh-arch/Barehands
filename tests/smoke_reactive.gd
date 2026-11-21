extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
## Batch 12 suite: the reactive city (bible 4I). Named heat tiers, the
## fixer's market-gate offer, the style-copier, crowd witnesses, hollow
## prices and closing doors, retold rumors, the radio recap.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("REACT FAIL: ", what)
	else:
		print("REACT ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# NOT pinned: this suite ARRANGES the eyes itself - the empty
	# alley (x0.6) and the two witnesses (x1.5) are the test
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

	await _test_tiers()
	await _test_style_counting()
	await _test_witnesses()
	await _test_fixer()
	await _test_the_copy()
	await _test_hollow_prices()
	await _test_doors_close()
	await _test_rumor_distortion()
	await _test_radio()
	await _test_persistence()

	if _fails == 0:
		print("REACT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("REACT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


# --- helpers -------------------------------------------------------------------------


func _witness_at(pos: Vector3) -> Node3D:
	var w := Node3D.new()
	w.add_to_group("wanderer")
	w.position = pos
	_main.add_child(w)
	return w


# --- A. the named ladder ----------------------------------------------------------------


func _test_tiers() -> void:
	for pair in [[0.5, "quiet"], [1.5, "talked about"], [2.5, "marked"],
			[4.2, "hunted"], [4.8, "the war"]]:
		Heat.heat = pair[0]
		_check(Heat.tier_name() == pair[1], "tier %s at %.1f (got %s)"
				% [pair[1], pair[0], Heat.tier_name()])
	Heat.heat = 0.0


# --- B. the style ledger -------------------------------------------------------------------


func _test_style_counting() -> void:
	Reactive.reset_for_test()
	for i in 6:
		_player.hit_landed.emit("jab", 1)
		_player.hit_landed.emit("cross", 1)
	for i in 3:
		_player.hit_landed.emit("kick", 1)
	_player.hit_landed.emit("launcher", 1)
	var r := Reactive.style_report()
	_check(r["punches"] == 12 and r["kicks"] == 3 and r["launchers"] == 1,
			"the style ledger counts what landed (%s)" % str(r))


# --- C. crowds are witnesses, alleys are not ----------------------------------------------------


func _test_witnesses() -> void:
	# the ambient crowd would muddy the count: the street is empty
	for w in get_tree().get_nodes_in_group("wanderer"):
		(w as Node).queue_free()
	await _wait_s(0.4)
	Heat.heat = 0.0
	# an empty street: it slides
	Heat.add(1.0)
	_check(absf(Heat.heat - float(Tuning.v("alley_mult"))) < 0.01,
			"an empty alley lets it slide (%.2f)" % Heat.heat)
	# a crowd of two: they pay you back
	Heat.heat = 0.0
	var a := _witness_at(_player.global_position + Vector3(3, 0, 0))
	var b := _witness_at(_player.global_position + Vector3(-4, 0, 2))
	Heat.add(1.0)
	_check(absf(Heat.heat - float(Tuning.v("witness_mult"))) < 0.01,
			"two witnesses make it cost (%.2f)" % Heat.heat)
	a.queue_free()
	b.queue_free()
	Heat.heat = 0.0


# --- D. the fixer -------------------------------------------------------------------------------


func _test_fixer() -> void:
	Reactive.reset_for_test()
	Heat.heat = 2.5
	await _wait_s(0.5)
	_check(get_tree().get_nodes_in_group("fixer_marker").size() == 1,
			"the fixer's marker stands at the market gate")
	var cost := Reactive.fixer_cost()
	_check(cost == int(Tuning.v("fixer_base"))
			+ int(Tuning.v("fixer_per_heat")) * 2,
			"the price scales with the heat ($%d)" % cost)
	# too hot to pay: he laughs, the heat stands
	Wallet.cash = 0
	Wallet.dirty = 0
	if Blocks._current != "market":
		Blocks.travel("market", "west")
		await _wait_s(2.2)
	Heat.heat = 2.5
	_player.global_position = Reactive.FIXER_SPOT
	await _wait_s(0.8)
	_check(Heat.heat > 1.8, "broke: the heat stands (%.2f)" % Heat.heat)
	_check(get_tree().get_nodes_in_group("fixer_marker").size() == 1,
			"broke: the marker waits for real money")
	# paper in hand: tonight disappears
	Wallet.cash = cost + 50
	await _wait_s(1.0)
	_check(Heat.heat < 0.7,
			"paid: tonight never happened (%.2f)" % Heat.heat)
	_check(Wallet.total() == 50, "the fixer takes exact change ($%d left)"
			% Wallet.total())
	_check(get_tree().get_nodes_in_group("fixer_marker").size() == 0,
			"paid: the marker comes down")
	# once a day: hot again, he stays gone
	Heat.heat = 3.0
	await _wait_s(0.5)
	_check(get_tree().get_nodes_in_group("fixer_marker").size() == 0,
			"the fixer works a block once a day")
	Heat.heat = 0.0
	_player.global_position = Vector3(0, 0.02, 3.0)


# --- E. the style-copier --------------------------------------------------------------------------


func _test_the_copy() -> void:
	Reactive.reset_for_test()
	# legs heavy: the blade
	Reactive.kicks = 20
	Reactive.punches = 5
	Heat.heat = 4.6
	await _wait_s(0.6)
	_check(is_instance_valid(Reactive._copy), "the copy walks in")
	if is_instance_valid(Reactive._copy):
		_check((Reactive._copy as CLS_Enemy).kind == 3,
				"kicks heavy: he leads with the blade (kind 3)")
		_check((Reactive._copy as CLS_Enemy).max_hp == int(Tuning.v("copy_hp_base")) + 5,
				"his hp ate your landed hits (%d)" % (Reactive._copy as CLS_Enemy).max_hp)
		(Reactive._copy as CLS_Enemy).set("hp", 0)
		(Reactive._copy as CLS_Enemy).call("_enter", CLS_Enemy.State.DOWN)
	await _wait_s(0.6)
	_check(is_instance_valid(Reactive._copy)
			and (Reactive._copy as CLS_Enemy).state == CLS_Enemy.State.DOWN,
			"the copy can go down")
	(Reactive._copy as Node).queue_free()
	Reactive._copy = null
	# the cooldown holds: hot as the war, no second student yet
	Heat.heat = 4.8
	await _wait_s(0.6)
	_check(not is_instance_valid(Reactive._copy),
			"the tape-student waits out his cooldown")
	# hands heavy: the counter-puncher
	Reactive._last_copy_msec = -999999
	Reactive.punches = 40
	Reactive.kicks = 1
	Heat.heat = 4.7
	await _wait_s(0.6)
	if is_instance_valid(Reactive._copy):
		_check((Reactive._copy as CLS_Enemy).kind == 1,
				"hands heavy: he counters like a boxer (kind 1)")
		(Reactive._copy as CLS_Enemy).queue_free()
		Reactive._copy = null
	Heat.heat = 0.0


# --- F. hollow prices -------------------------------------------------------------------------------


func _test_hollow_prices() -> void:
	if Blocks._current != "market":
		Blocks.travel("market", "west")
		await _wait_s(2.2)
	Blocks._planked = {}  # the price test is not the plank test
	City.rep["market"] = 30.0
	var friendly: float = City.price_mult(Vector3(240, 0, 0))
	City.rep["market"] = -30.0  # wary: shelves are thin
	var wary: float = City.price_mult(Vector3(240, 0, 0))
	_check(wary > friendly + 0.05,
			"a wary block charges for its thin shelves (%.2f vs %.2f)"
			% [wary, friendly])
	_check(City.mood_of("market") == "wary", "the market is wary, not hostile")
	_check(City.greeting(Vector3(240, 0, 0)).contains("Shelves are thinning"),
			"the shopkeeper says why it costs")
	City.rep["market"] = -55.0  # turning hostile: they're empty
	var empty: float = City.price_mult(Vector3(240, 0, 0))
	_check(empty > wary, "turning hostile costs more than wary (%.2f)" % empty)
	_check(City.greeting(Vector3(240, 0, 0)).contains("close early"),
			"the shopkeeper says when the doors shut")
	City.rep["market"] = 0.0


# --- G. doors close ------------------------------------------------------------------------------------


func _test_doors_close() -> void:
	if Blocks._current != "market":
		Blocks.travel("market", "west")
		await _wait_s(2.2)
	Blocks._planked = {}
	City.rep["market"] = -30.0  # wary, not hostile - and the boards go up
	Blocks._planks_if_hostile("market")
	await _wait_s(0.4)
	var boards := 0
	for p in get_tree().get_nodes_in_group("plank"):
		if absf((p as Node3D).global_position.x - Blocks.BLOCK_X["market"]) <= 22.0:
			boards += 1
	_check(boards > 0, "a hollow block boards its windows (%d planks)" % boards)
	City.rep["market"] = 0.0


# --- H. rumors distort over beats ---------------------------------------------------------------------------


func _test_rumor_distortion() -> void:
	City.remember("riverside", "he dropped three men by the water")
	var fresh := City.last_heard("riverside")
	_check(fresh.contains("They say") and fresh.contains("three men"),
			"the street starts honest: %s" % fresh)
	Ledger.beats_left = 3
	Ledger.spend_beat("test")
	var once := City.last_heard("riverside")
	_check(once.contains("grows every telling"),
			"one retelling grows it: %s" % once)
	Ledger.spend_beat("test")
	Ledger.spend_beat("test")
	var wild := City.last_heard("riverside")
	_check(wild.contains("SWEAR"),
			"three retellings and they swear it: %s" % wild)


# --- I. the radio recap -----------------------------------------------------------------------------------------


func _test_radio() -> void:
	Reactive.yesterday_peak = 4.5
	var hot := Reactive.radio_lines()
	_check(hot.any(func(l): return l.contains("bare-handed man AGAIN")),
			"a hot yesterday gets named on the radio")
	Reactive.yesterday_peak = 1.2
	var warm := Reactive.radio_lines()
	_check(warm.any(func(l): return l.contains("an incident")),
			"a quiet yesterday stays anonymous")
	Reactive.punches = 30
	Reactive.kicks = 5
	var styled: Array[String] = Reactive.radio_lines()
	_check(styled.any(func(l): return l.contains("his hands")),
			"the radio knows your style (hands)")
	Reactive.punches = 5
	Reactive.kicks = 30
	styled = Reactive.radio_lines()
	_check(styled.any(func(l): return l.contains("his kicks")),
			"the radio knows your style (kicks)")
	Reactive.reset_for_test()


# --- J. persistence -----------------------------------------------------------------------------------------------


func _test_persistence() -> void:
	Reactive.reset_for_test()
	Reactive.punches = 7
	Reactive.kicks = 11
	Reactive.peak_heat = 3.3
	Reactive.yesterday_peak = 2.2
	Heat.heat = 2.4
	await _wait_s(0.5)  # the fixer opens
	var d := Reactive.to_dict()
	_check(d["fixer_live"] == true and d["punches"] == 7,
			"the city's memory serializes")
	Reactive.reset_for_test()
	Heat.heat = 0.0  # the _process watcher must not race the restore
	await _wait_s(0.3)
	Reactive.from_dict(d)
	await _wait_s(0.3)
	var after := Reactive.style_report()
	_check(after["punches"] == 7 and after["kicks"] == 11
			and Reactive.yesterday_peak == 2.2,
			"the city's memory roundtrips")
	_check(get_tree().get_nodes_in_group("fixer_marker").size() == 1,
			"the fixer's marker respawns with the save")
	Heat.heat = 0.0
	await _wait_s(0.3)
	Reactive.reset_for_test()
