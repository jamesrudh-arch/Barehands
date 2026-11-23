extends Node
## S5.12 THE CITY SURFACE: the schedules, the scars, the boards,
## the thinning street, the heat tax, the gossip.
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
		print("SURF PASS %s" % what)
	else:
		_fail += 1
		print("SURF FAIL %s" % what)

func _ws() -> Node:
	return get_tree().get_first_node_in_group("worldsim")

func _surf() -> Node:
	return get_tree().get_first_node_in_group("surface")

func _dee() -> Node3D:
	for l in get_tree().get_nodes_in_group("local"):
		if str(l.get_meta("who", "")).begins_with("OLD DEE"):
			return l as Node3D
	return null

func _walkers() -> int:
	return get_tree().get_nodes_in_group("pedestrian").size()

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
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	_check(_surf() != null, "the surface rides Game")
	# --- the schedules: Dee keeps his hours
	var dee := _dee()
	_check(dee != null and is_equal_approx(dee.global_position.x,
			-40.4), "DUSK: Dee at his counter")
	_ws().advance_beat()
	_ws().advance_beat()
	await _wait_s(0.4)
	dee = _dee()
	_check(dee != null and is_equal_approx(dee.global_position.x,
			-42.6), "3 AM: Dee inside the doorway")
	_ws().advance_beat()
	await _wait_s(0.4)
	dee = _dee()
	_check(dee != null and is_equal_approx(dee.global_position.x,
			-40.4), "DUSK again: Dee back at the counter")
	# --- scorch persists where crimes burned
	WorldState.push_event("crime", {"pos": Vector3(-30.0, 0.05, 5.0)})
	WorldState.push_event("crime", {"pos": Vector3(-10.0, 0.05, 3.0)})
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	var scorch: int = 0
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("Scorch_"):
			scorch += 1
	_check(scorch >= 2, "the scorch persists across travel (%d)" % scorch)
	# --- a memorial for a named man
	WorldState.push_event("enemy_down", {"who": "THE STUDENT"})
	var lst: Array = WorldState.get_value("memorial_list", [])
	# (the event records only when the named body is findable - the
	# memorial suite drives _remember directly for the persist test)
	if lst.is_empty():
		_surf()._remember("memorial_list", {"area": "neighbourhood",
				"pos": Vector3(-12.0, 0.05, 4.0),
				"who": "THE STUDENT"})
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	var memorial: int = 0
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("Memorial_"):
			memorial += 1
	_check(memorial >= 1, "the memorial persists (FOR THE STUDENT)")
	# --- the boards: broken and unpaid
	WorldState.set_flag("m4_broke")
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	_check(get_tree().current_scene.get_node_or_null(
			"Boards_PAWN") != null,
			"THE PAWN DESK boards up (broken, unpaid)")
	# --- the street thins under heat
	WorldState.set_value("heat", 0.0)
	var w0 := _walkers()
	WorldState.set_value("heat", 10.0)
	_ws().advance_beat()
	await _wait_s(0.5)
	_check(_walkers() <= w0 - 1 and _walkers() < w0,
			"heat thins the street (%d -> %d)" % [w0, _walkers()])
	var thinned := false
	for e in WorldState.event_log().slice(-4,
			WorldState.event_log().size()):
		if str(e.get("kind", "")) == "thinning":
			thinned = true
	_check(thinned, "the thinning is news")
	WorldState.set_value("heat", 0.0)
	# --- the heat tax: 8+ heat prices risk in
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	hero.set("hp", 40.0)
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	WorldState.set_value("heat", 10.0)
	# heat 10 spawns THE COPY into the wait - sweep him, re-stand
	await _wait_s(0.3)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)
	WorldState.set_value("heat", 10.0)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	hero.set("hp", 40.0)
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	WorldState.set_value("clean_cash", 20.0)
	WorldState.set_value("stash_cash", 0.0)
	mkt.try_grab(hero)
	await _wait_s(0.3)
	# the beats have run to MIDNIGHT: night premium x heat tax
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 10.32),
			"the bowl at midnight, on a hot block ($8 x 1.1 x 1.1)")
	WorldState.set_value("heat", 0.0)
	# --- the gossip distorts
	var before := WorldState.event_log().size()
	WorldState.push_event("crime", {"pos": Vector3.ZERO})
	WorldState.push_event("crime", {"pos": Vector3.ZERO})
	WorldState.push_event("crime", {"pos": Vector3.ZERO})
	WorldState.set_value("heat", 0.0)
	_ws().advance_beat()
	await _wait_s(0.4)
	var gossip := ""
	for e in WorldState.event_log().slice(maxi(0,
			WorldState.event_log().size() - 4),
			WorldState.event_log().size()):
		if str(e.get("kind", "")) == "gossip":
			var d: Dictionary = e.get("data", {})
			gossip = str(d.get("line", ""))
	_check(gossip.contains("the street says") and gossip.length() > 20,
			"the gossip distorts over beats (%s)" % gossip)
	_finish()

func _finish() -> void:
	print("SURF RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
