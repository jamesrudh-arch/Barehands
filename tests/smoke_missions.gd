extends Node

## REBUILD STEP 7 proof suite: THE MISSION SYSTEM + M0/M1 chainable.
##   - a NEW GAME opens M0 WAKE-UP CALL with its first objective;
##   - every stage completes on its REAL condition (move distance,
##     camera yaw, a landed punch on the bag, a tried door, the area
##     change) - the banner and the marker follow;
##   - M0 completes and CHAINS into M1 THE COLLECTION;
##   - M1: the package spawns on the workbench, collects on walk-up,
##     the delivery completes at THE RAIN GLASS, the +$120 lands in
##     the WorldState ledger, the done-flags persist through a save
##     round trip.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(0.8)
	await _m0_flow()
	await _m1_flow()
	_save_roundtrip()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("MISSIONS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("MISSIONS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _missions() -> Node:
	return get_tree().get_first_node_in_group("missions")


func _place(hero: CharacterBody3D, pos: Vector3, yaw: float) -> void:
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.set("_yaw", yaw)


func _objective() -> String:
	return str(_missions().get("_banner").text)


func _m0_flow() -> void:
	var m := _missions()
	_check(m != null and m.get("active") != null,
			"a NEW GAME opens the mission module with a live mission")
	if m == null or m.get("active") == null:
		return
	var active: Resource = m.get("active")
	_check(active.id == "m0" and active.title == "WAKE-UP CALL",
			"the first mission is M0 WAKE-UP CALL")
	_check("Move" in _objective(),
			"the banner opens with the move objective (%s)" % _objective())
	# stage 1: MOVE (real distance)
	var hero := _hero()
	hero.set("move_stick", Vector2(0, -0.8))
	await _wait_s(1.0)
	hero.set("move_stick", Vector2.ZERO)
	await _wait_s(0.3)
	_check("Look" in _objective(),
			"moving 2.5 m completes the stage (%s)" % _objective())
	# stage 2: CAMERA (real yaw)
	Input.action_press("look_right")
	await _wait_s(0.7)
	Input.action_release("look_right")
	await _wait_s(0.3)
	_check("punching bag" in _objective(),
			"turning the camera completes the stage (%s)" % _objective())
	# stage 3: PUNCH LANDED (a real hit on the bag)
	_place(hero, Vector3(8.8, 0.05, 4.4), 0.0)  # the bag is south (+Z): face it
	await _wait_s(0.3)
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.6)
	_check("yard gate" in _objective().to_lower() or "gate" in _objective(),
			"a landed punch completes the stage (%s)" % _objective())
	# stage 4: DOOR TRIED (the real door law event)
	WorldState.push_event("door_tried", {"door": "YardGate"})
	await _wait_s(0.3)
	_check("street" in _objective().to_lower(),
			"trying the gate completes the stage (%s)" % _objective())
	# stage 5: STREET REACHED (the real area change) -> M0 done -> M1
	await Game.travel("neighbourhood", "from_home")
	await _wait_s(1.0)
	_check(WorldState.flag("mission_done:m0"),
			"reaching the street completes M0")
	_check(m.get("active") != null and (m.get("active") as Resource).id == "m1",
			"M0 CHAINS into M1 THE COLLECTION")
	_check(int(m.get("stage_index")) == 0,
			"M1 opens at its first stage")


func _m1_flow() -> void:
	var m := _missions()
	var hero := _hero()
	_check("package" in _objective().to_lower(),
			"M1's banner says take the package (%s)" % _objective())
	# back home for the package (the marker says where)
	await Game.travel("warehouse", "start")
	await _wait_s(0.8)
	_check(get_tree().get_first_node_in_group("player") != null
			and _objective() != "",
			"the mission survives the travel home")
	# the package spawned on the workbench
	var pkg := _find_deep("ThePackage")
	_check(pkg != null, "the package sits on the workbench")
	# walk to it (proximity collect)
	hero = _hero()
	_place(hero, Vector3(-6.5, 0.05, 6.0), 0.0)
	hero.set("move_stick", Vector2(0, -0.9))
	await _wait_s(0.9)
	hero.set("move_stick", Vector2.ZERO)
	await _wait_s(0.4)
	_check(bool(m.get("_has_package")),
			"walking up collects the package")
	_check("RAIN GLASS" in _objective(),
			"the banner turns to the delivery (%s)" % _objective())
	# deliver: the street, THE RAIN GLASS front
	await Game.travel("neighbourhood", "from_home")
	await _wait_s(1.0)
	hero = _hero()
	var front := _find_deep("Front_THE_RAIN_GLASS")
	_check(front != null, "THE RAIN GLASS front exists for the drop")
	if front:
		_place(hero, front.global_position + Vector3(0, 0.05, -1.4), 0.0)
	await _wait_s(1.2)
	_check(WorldState.flag("mission_done:m1"),
			"the delivery completes M1")
	# absolute: no earlier bumps exist in this run (M0 pays $0, no
	# doors broken) - the async completion frame makes deltas racy
	_check(float(WorldState.get_value("stash_cash", 0.0)) >= 120.0,
			"the +$120 reward lands in the ledger (%.0f)" % (
			float(WorldState.get_value("stash_cash", 0.0))))
	_check(not bool(m.get("_has_package")),
			"the package is consumed on delivery")


func _save_roundtrip() -> void:
	var save := WorldState.to_save()
	WorldState.reset()
	WorldState.from_save(save)
	_check(WorldState.flag("mission_done:m0")
			and WorldState.flag("mission_done:m1"),
			"the mission done-flags survive a save round trip")


func _find_deep(name: String) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_named(scene, name)


func _find_named(root: Node, name: String) -> Node3D:
	if str(root.name) == name:
		return root as Node3D
	for c in root.get_children():
		var f := _find_named(c, name)
		if f:
			return f
	return null
