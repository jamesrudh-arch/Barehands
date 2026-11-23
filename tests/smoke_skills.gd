extends Node
## S5.10 THE SKILLS PASS: disciplines are learned from people -
## M2's Tony teaches Kickboxing, M3's Dee teaches the Drunken hint,
## M4's third answer clears the owner's book (the grille opens),
## the stall sells jackets.
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
		print("SKILL PASS %s" % what)
	else:
		_fail += 1
		print("SKILL FAIL %s" % what)

func _combat() -> Node:
	var h := get_tree().get_first_node_in_group("player") as Node3D
	if h == null:
		return null
	return h.get_node_or_null("Combat")

func _down_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)

func _ready() -> void:
	var dog := get_tree().create_timer(220.0, true, false, true)
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
	var c := _combat()
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	_check(c != null and str(c.style_id) == "brawler",
			"you start in the Brawler stance")
	# --- locked styles refuse
	c.set_style("kickboxing")
	_check(str(c.style_id) == "brawler",
			"a locked discipline is refused (kickboxing)")
	c.set_style("grappling")
	_check(str(c.style_id) == "brawler",
			"grappling stays a teacher you haven't met")
	# --- M2 teaches Kickboxing
	var ms := get_tree().get_first_node_in_group("missions")
	ms.start("res://data/missions/m2.tres")
	await _wait_s(0.3)
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await _wait_s(0.6)
	_down_all()
	for i in 16:
		if WorldState.flag("mission_done:m2") \
				or ms.stage_index >= 2:
			break
		_down_all()
		await _wait_s(0.4)
	_check(ms.stage_index >= 2, "the gym fight ends at the counter")
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.set("hp", 100.0)
	hero.global_position = Vector3(-35.5, 0.05, 5.0)
	await _wait_s(0.3)
	_check(ms.try_grab(hero), "Tony's counter answers the grab")
	_check(WorldState.flag("skill_kickboxing"),
			"the KICKBOXING flag lands")
	_check((WorldState.get_value("unlocked_styles",
			[]) as Array).has("kickboxing"),
			"kickboxing is learned (in the unlocked list)")
	_check(str(_combat().style_id) == "kickboxing",
			"the stance arrives already worn")
	# --- M3 teaches the Drunken hint
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	ms.start("res://data/missions/m3.tres")
	await _wait_s(0.4)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-4.6, 0.05, 5.4)
	await _wait_s(0.3)
	ms.try_grab(hero)  # Marla's ask
	await _wait_s(1.8)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-40.4, 0.05, 5.4)  # the bottle
	await _wait_s(0.8)
	hero.global_position = Vector3(-4.6, 0.05, 5.4)  # Marla
	await _wait_s(0.8)
	_check(ms.stage_index >= 3, "the bottle is delivered")
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-40.4, 0.05, 5.4)  # Dee's counter
	await _wait_s(0.3)
	ms.try_grab(hero)
	await _wait_s(0.3)
	_check(WorldState.flag("skill_drunken")
			and str(_combat().style_id) == "drunken",
			"Old Dee teaches the DRUNKEN hint (worn)")
	_check(WorldState.flag("mission_done:m3"), "M3 completes")
	# --- M4's third answer: clear the book
	WorldState.set_value("clean_cash", 400.0)
	WorldState.set_value("stash_cash", 0.0)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-18.0, 0.05, 5.4)
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	_check(mkt.try_grab(hero), "the owner's doorstep answers")
	_check(WorldState.flag("pawn_paid"),
			"the book is cleared ($300 clean)")
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 100.0), "400 - 300 = 100 clean")
	_check(str(Doors._doors["THE PAWN DESK"]["state"]) == "open",
			"THE PAWN DESK grille opens")
	# --- the stall sells jackets
	WorldState.set_value("clean_cash", 100.0)
	hero.global_position = Vector3(6.0, 0.05, 5.4)
	_check(mkt.try_grab(hero), "the stall answers")
	_check(int(float(WorldState.get_value("outfit", 0))) == 1
			and hero.outfit_name() == "THE CRIMSON",
			"the CRIMSON jacket is bought and worn ($40)")
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 60.0), "100 - 40 = 60 clean")
	_finish()

func _finish() -> void:
	print("SKILL RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
