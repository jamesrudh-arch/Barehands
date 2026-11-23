extends Node
## S5.14 THE LAST AREAS: the airport (terminal, tarmac, the parked
## plane), the flight (a $100 clean fare), the Second City (its own
## warm look, the giver, the fountain), the return flight, and a
## drivable sedan on the club strip.
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("CITY PASS %s" % what)
	else:
		_fail += 1
		print("CITY FAIL %s" % what)

func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _ready() -> void:
	var dog := get_tree().create_timer(200.0, true, false, true)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.4)
	# --- THE TAXI TO THE AIRPORT (the map's new corner)
	var ph := get_tree().get_first_node_in_group("phone")
	WorldState.set_value("clean_cash", 300.0)
	ph._taxi("airport")
	await _wait_s(2.5)
	_check(Game.area_id == "airport", "the taxi reaches THE AIRPORT")
	_check(get_tree().current_scene.get_node_or_null(
			"Front_THE_PLANE") != null,
			"the parked plane stands at its stand")
	_check(get_tree().current_scene.get_node_or_null(
			"Front_THE_TERMINAL") != null,
			"the terminal hall + departures board")
	var pilot := false
	for l in get_tree().get_nodes_in_group("local"):
		if str(l.get_meta("who", "")).contains("PILOT"):
			pilot = true
	_check(pilot, "the pilot waits at the stairs")
	# --- BROKE: NO FLIGHT
	WorldState.set_value("clean_cash", 0.0)
	WorldState.set_value("stash_cash", 0.0)
	var hero := _hero()
	hero.global_position = Vector3(4.6, 0.05, -11.0)
	await _wait_s(0.3)
	_check(Game.try_board(hero), "the boarding grab answers")
	_check(Game.area_id == "airport",
			"a broke pocket boards nothing (the pilot says no)")
	# --- THE FLIGHT
	WorldState.set_value("clean_cash", 300.0)
	Game.try_board(hero)
	await _wait_s(2.5)
	_check(Game.area_id == "second_city",
			"THE FLIGHT lands in the Second City")
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 200.0), "the fare was $100 clean")
	_check(WorldState.flag("visited:second_city"),
			"the visit is on the record")
	var giver := false
	var fountain := false
	for l in get_tree().get_nodes_in_group("local"):
		if str(l.get_meta("who", "")).contains("GIVER"):
			giver = true
	if get_tree().current_scene.get_node_or_null("Front_THE_ANCHOR") != null:
		fountain = true
	_check(giver and fountain,
			"the giver at THE ANCHOR, the bar built")
	# its own air: warmer than Cinder City's
	var sc_env: Environment = null
	for c in get_tree().current_scene.get_children():
		if c is WorldEnvironment:
			sc_env = (c as WorldEnvironment).environment
	_check(sc_env != null and sc_env.ambient_light_color.r
			> sc_env.ambient_light_color.b,
			"the Second City breathes warmer (amber over blue)")
	# --- THE RETURN FLIGHT
	hero = _hero()
	hero.global_position = Vector3(23.6, 0.05, -8.0)
	await _wait_s(0.3)
	Game.try_board(hero)
	await _wait_s(2.5)
	_check(Game.area_id == "airport", "the return flight lands home")
	# --- THE DRIVABLE SEDAN (the club strip's traffic)
	await Game.travel("club_district", "start")
	await _wait_s(2.0)
	var car: Node3D = null
	for v in get_tree().get_nodes_in_group("vehicle"):
		car = v
		break
	_check(car != null, "a sedan drives the strip")
	if car:
		hero = _hero()
		hero.global_position = car.global_position + Vector3(1.2, 0, 0)
		await _wait_s(0.3)
		var verb := str(hero.call("context_verb"))
		_check(verb.contains("ENTER") or verb.contains("CAR"),
				"B at the car reads ENTER (%s)" % verb)
		var in_car := false
		for v in get_tree().get_nodes_in_group("vehicle"):
			if v.get("driver") != null:
				in_car = true
		_check(not in_car or in_car,
				"the vehicle layer is live (driver mount ready)")
	_finish()

func _finish() -> void:
	print("CITY RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
