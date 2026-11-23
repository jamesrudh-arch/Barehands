extends Node
## S5.6 STORY SUITE: the spine's five new beats end-to-end - M2's
## gym fight, M3's bottle run, M4's grille choice, M5's waves +
## the first CLEAN reward, M6's call (ring, answer, offer, missed
## cost) and the offer's real consequences (ammo line, harder men).
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("STORY PASS %s" % what)
	else:
		_fail += 1
		print("STORY FAIL %s" % what)

func _missions() -> Node:
	return get_tree().get_first_node_in_group("missions")

func _phone() -> Node:
	return get_tree().get_first_node_in_group("phone")

func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _down_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)

func _alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			n += 1
	return n

func _ready() -> void:
	var dog := get_tree().create_timer(180.0, true, false, true)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.2)
	var ms := _missions()
	var ph := _phone()
	_check(ms != null and ph != null, "missions + phone ride Game")
	if ms == null or ph == null:
		_finish()
		return
	# --- M2 FIRST BLOOD (the gym fight)
	ms.start("res://data/missions/m2.tres")
	await _wait_s(0.3)
	_check(ms.active.id == "m2" and ms.stage_index == 0,
			"M2 opens at the gym approach")
	await Game.travel("club_district", "start")
	await _wait_s(1.4)
	_check(ms.stage_index == 1, "arrival advances to the fight")
	await _wait_s(0.6)
	_check(_alive_enemies() >= 2, "the muscle spawns (2 men)")
	_down_all()
	await _wait_s(0.5)
	# S5.10: the fight ends at Tony's counter - the lesson
	for i in 12:
		if ms.stage_index >= 2 \
				or WorldState.flag("mission_done:m2"):
			break
		_down_all()
		await _wait_s(0.4)
	var hero2 := _hero()
	if hero2 and is_instance_valid(hero2):
		hero2.global_position = Vector3(-35.5, 0.05, 5.0)
		hero2.set("hp", 100.0)
	await _wait_s(0.3)
	ms.try_grab(hero2)
	await _wait_s(0.5)
	_check(WorldState.flag("mission_done:m2"),
			"M2 done - first blood paid, the lesson taken")
	_check(is_equal_approx(float(WorldState.get_value(
			"stash_cash", 0.0)), 180.0),
			"M2 pays $180 dirty")
	# --- M3 THE OLD DRUNK (the bottle run)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.4)
	ms.start("res://data/missions/m3.tres")
	await _wait_s(0.4)
	var hero := _hero()
	hero.global_position = Vector3(-4.6, 0.05, 5.4)
	await _wait_s(0.3)
	_check(ms.try_grab(hero), "Marla answers the grab")
	_check(WorldState.flag("m3_talked"), "the ask lands")
	await _wait_s(1.6)  # the chained next-start + package spawn
	hero = _hero()
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	await _wait_s(0.8)
	_check(ms.stage_index >= 2, "the bottle is taken by walking")
	hero.global_position = Vector3(-4.6, 0.05, 5.4)
	await _wait_s(0.8)
	# S5.10: Dee pays in secrets - the Drunken hint
	hero = _hero()
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	await _wait_s(0.3)
	ms.try_grab(hero)
	await _wait_s(0.5)
	_check(WorldState.flag("mission_done:m3"),
			"M3 done - delivered, the hint taken")
	# --- M4 SHAKEDOWN (the grille choice - both answers)
	ms.start("res://data/missions/m4.tres")
	await _wait_s(0.4)
	hero = _hero()
	hero.global_position = Vector3(-18.0, 0.05, 7.2)
	await _wait_s(0.3)
	_check(ms.try_grab(hero), "the owner answers the grab")
	await _wait_s(0.5)
	_check(WorldState.flag("mission_done:m4"),
			"M4 done - talked down")
	# the other answer: the fist through the grille
	WorldState.set_value("m4_talked", false)
	WorldState.bump("heat", -float(WorldState.get_value("heat", 0.0)))
	ms.start("res://data/missions/m4.tres")
	await _wait_s(0.4)
	hero = _hero()
	hero.global_position = Vector3(-18.0, 0.05, 7.2)
	ms._on_hero_action("punch")
	await _wait_s(0.4)
	_check(WorldState.flag("m4_broke")
			and WorldState.flag("door_broken:THE PAWN DESK"),
			"the punch breaks the grille (door_broken flag)")
	_check(float(WorldState.get_value("heat", 0.0)) >= 2.0,
			"the street heard the steel (+2 heat)")
	# --- M5 TURF (waves + the first clean reward)
	WorldState.set_value("stash_cash", 180.0)
	WorldState.set_value("clean_cash", 0.0)
	ms.start("res://data/missions/m5.tres")
	await _wait_s(0.4)
	hero = _hero()
	hero.global_position = Vector3(-42.0, 0.05, 7.2)
	await _wait_s(0.6)
	_check(ms.stage_index == 1, "standing with Dee starts the wave")
	await _wait_s(0.6)
	_check(_alive_enemies() >= 3, "wave 1: three collectors")
	_down_all()
	await _wait_s(1.2)
	_check(ms.stage_index == 2, "wave 1 down - wave 2 comes")
	await _wait_s(0.6)
	_check(_alive_enemies() >= 3, "wave 2: harder men")
	_down_all()
	# a downed man's KO lands after his stun beat - the defeat
	# count crawls in over a few seconds. Wait for the stage.
	for i in 12:
		if ms.stage_index >= 3 \
				or WorldState.flag("mission_done:m5"):
			break
		_down_all()
		await _wait_s(0.4)
	# the clear stage can complete in the same beat (the street
	# is already swept) - reaching or passing it both count
	_check(ms.stage_index >= 3 \
			or WorldState.flag("mission_done:m5"),
			"the street must clear")
	# every body bumps heat, and heat spawns THE COPY - sweep and
	# scrub together until the street actually clears
	for i in 14:
		_down_all()  # the alley watcher counts too
		WorldState.set_value("heat", 0.0)
		if WorldState.flag("mission_done:m5"):
			break
		await _wait_s(0.3)
	_check(WorldState.flag("mission_done:m5"), "M5 done - turf held")
	_check(is_equal_approx(float(WorldState.get_value(
			"stash_cash", 0.0)), 380.0)
			and is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 150.0),
			"M5 pays $200 dirty + $150 CLEAN (the till)")
	# --- M6 THE CALL (the ring, the offer, the consequences)
	WorldState.set_value("debt", 4900.0)
	ms.start("res://data/missions/m6.tres")
	await _wait_s(0.6)
	_check(not ph._ring.is_empty() and ph._ring_panel.visible,
			"the phone RINGS with the banner counting")
	ph._answer()
	await _wait_s(0.3)
	_check(not ph._call.is_empty() and ph._call.get("choices",
			[]).size() == 2, "answered - the offer is on the line")
	ph._choice(0)
	await _wait_s(0.5)
	_check(WorldState.flag("m6_accepted"), "the offer is taken")
	_check(is_equal_approx(float(WorldState.get_value("debt",
			0.0)), 5900.0), "+$1000 on the books (debt 5900)")
	_check(WorldState.flag("mission_done:m6"),
			"M6 done - the call is answered")
	# the missed ring costs what declining costs
	WorldState.bump("heat", -float(WorldState.get_value("heat", 0.0)))
	ph.ring({"from": "THE BROTHER", "duration": 0.3,
			"decline": {"flag": "bro_missed", "heat": 1.5}})
	await _wait_s(1.0)
	_check(WorldState.flag("bro_missed")
			and is_equal_approx(float(WorldState.get_value(
			"heat", 0.0)), 1.5), "a missed ring pays the decline cost")
	# the offer's teeth: the ammo line at half
	await Game.travel("club_district", "start")
	await _wait_s(1.4)
	hero = _hero()
	var gun := hero.get_node_or_null("Gun")
	gun.set("reserve", 0)
	WorldState.set_value("stash_cash", 100.0)
	WorldState.set_value("clean_cash", 0.0)
	hero.global_position = Vector3(-35.5, 0.05, 5.0)
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	mkt.try_grab(hero)
	await _wait_s(0.3)
	# half price = 12.5, paid dirty: +25% surcharge = 15.625
	_check(int(gun.get("reserve")) == 12
			and is_equal_approx(float(WorldState.get_value(
			"stash_cash", 0.0)), 84.375),
			"the Corporation's line: the box at half, dirty ($15.63)")
	# refusing sends harder men
	WorldState.set_flag("m6_declined")
	ms._pending_spawn = [{"pos": Vector3(0, 0.05, 0), "hp": 80.0}]
	ms._spawn_muscle()
	var last: Node = null
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		last = e
	_check(last != null and is_equal_approx(float(last.get("hp")),
			100.0), "refusal escalates: 80 hp x1.25 = 100")
	_finish()

func _finish() -> void:
	print("STORY RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
