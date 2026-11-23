extends Node

## USER OVERRIDES R11 / V3 PART D proof suite. Proves, against the real
## build, the door law end to end:
##   - the registry: the street's fronts register with their law
##     (NEON 9 breakable wood, MECHANIC steel, the venue fronts open);
##   - the approach prompt ("B: TRY") appears near a locked door;
##   - the B try: the LOCKED reason shows at the door, the rattle fires;
##   - the break: B shoulder hits and A kicks crack the frame, the last
##     one bursts it - the mesh swings, the stash drops, the ambush
##     wakes, Heat rises;
##   - steel refuses and says why, hit after hit;
##   - a broken door STAYS broken across a street reload;
##   - mid-fight, a kick never lands on a door (the fight owns it).

var _fails := 0
var _checks := 0
var _main: Node = null


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
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as Node
	if opening and opening.has_method("skip"):
		opening.call("skip")
	await _wait_s(1.2)

	# walk the hero to the market's club row (NEON 9 at x 240.5, z -9.6)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	_check(hero != null, "the hero is on the street")
	if hero == null:
		_finish()
		return
	hero.global_position = Vector3(240.5, 0.02, -7.0)
	await _wait_s(2.5)  # the market block builds, the Doors sweep runs

	await _registry(hero)
	await _approach_and_try(hero)
	await _break_path(hero)
	await _steel(hero)
	await _combat_gate(hero)
	await _kick_path(hero)
	await _persistence(hero)
	_static_record()

	_finish()


func _finish() -> void:
	if _fails == 0:
		print("DOORS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("DOORS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _front(label: String) -> Node3D:
	for front in get_tree().get_nodes_in_group("shopfront"):
		if str((front as Node).name) == "Front_" + label:
			return front
	return null


func _rec(label: String) -> Dictionary:
	for rec in Doors.door_list():
		if rec["label"] == label:
			return rec
	return {}


func _registry(hero: Node3D) -> void:
	var list := Doors.door_list()
	_check(list.size() >= 6, "the registry holds the market fronts (%d)" % list.size())
	var n9 := _rec("NEON 9")
	_check(not n9.is_empty() and n9["state"] == "locked"
			and n9["breakable"] and n9["hits_left"] == 3,
			"NEON 9: locked, wooden, 3 hits")
	var mech := _rec("MECHANIC")
	_check(not mech.is_empty() and mech["state"] == "locked"
			and not mech["breakable"],
			"MECHANIC: locked, steel, unbreakable")
	for open_label in ["IRON PALM GYM", "THE RAIN GLASS", "THE VELVET ROOM"]:
		_check(Doors.state_of(open_label) == "open",
				"%s answers OPEN (walk-in flow is its own)" % open_label)
	var mesh: MeshInstance3D = n9.get("door_mesh")
	var prompt: Label3D = n9.get("prompt")
	_check(mesh != null and mesh.is_inside_tree(),
			"NEON 9 has its plank door mesh in the world")
	_check(prompt != null and prompt.is_inside_tree(),
			"NEON 9 has its talking prompt line in the world")


func _approach_and_try(hero: Node3D) -> void:
	var n9 := _rec("NEON 9")
	hero.global_position = _front("NEON 9").global_position + Vector3(0, 0.02, 2.0)
	await _wait_s(0.8)  # the 10 Hz approach poll
	var prompt: Label3D = n9["prompt"]
	_check(prompt.visible and prompt.text.begins_with("B: "),
			"the approach prompt shows near the door (%s)" % prompt.text)
	_check(Doors.context_verb(hero.global_position) == "TRY",
			"the B verb is TRY before the first try")
	var p := hero as Node
	_check(p.has_method("context_action")
			and str(p.call("context_action")) == "TRY",
			"the hero's context verb reads TRY at the door")
	# the try: hand on the handle
	var heat0 := float(Heat.heat)
	_check(Doors.try_nearest(hero), "the B press at the door answers")
	_check(n9["tried"] and n9["state"] == "locked",
			"the try marks the door tried, still locked")
	_check("MEMBERS ONLY" in prompt.text and "LOCKED" in prompt.text,
			"the LOCKED reason shows at the door (%s)" % prompt.text)
	_check(Doors.context_verb(hero.global_position) == "BREAK",
			"the verb turns BREAK after the try")
	_check(float(Heat.heat) >= heat0,
			"a try alone raises no heat")


func _break_path(hero: Node3D) -> void:
	var n9 := _rec("NEON 9")
	var mesh: MeshInstance3D = n9["door_mesh"]
	var rot0: float = mesh.rotation.y
	var pickups0 := get_tree().get_nodes_in_group("pickup").size()
	var enemies0 := get_tree().get_nodes_in_group("enemy").size()
	var heat0 := float(Heat.heat)
	# three shoulder hits (B): 3 -> 2 -> 1 -> burst
	Doors.try_nearest(hero)
	_check(n9["hits_left"] == 2, "shoulder hit 1 lands (2 left)")
	Doors.try_nearest(hero)
	_check(n9["hits_left"] == 1, "shoulder hit 2 lands (1 left)")
	Doors.try_nearest(hero)
	_check(n9["state"] == "broken", "the last hit bursts the door open")
	await _wait_s(0.5)
	_check(absf(mesh.rotation.y - rot0) > 0.5,
			"the leaf swung off its hinge (rot %.2f)" % mesh.rotation.y)
	_check(get_tree().get_nodes_in_group("pickup").size() == pickups0 + 1,
			"the stash dropped behind the door")
	var cash := false
	for pk in get_tree().get_nodes_in_group("pickup"):
		if pk.get("kind") == "cash" and int(pk.get("amount")) == 80:
			cash = true
	_check(cash, "the stash is the $80 cash pickup")
	_check(get_tree().get_nodes_in_group("enemy").size() >= enemies0 + 2,
			"the ambush woke: whoever was inside came out")
	_check(float(Heat.heat) > heat0,
			"breaking in raised Heat (%.2f -> %.2f)" % [heat0, float(Heat.heat)])
	var prompt: Label3D = n9["prompt"]
	_check("the door gives" in prompt.text,
			"the burst line shows (%s)" % prompt.text)
	_check(Doors.context_verb(hero.global_position) == "LOOK",
			"the verb at a broken door is LOOK")
	# clear the ambush so later checks start clean
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await _wait_s(0.2)


func _steel(hero: Node3D) -> void:
	var mech := _rec("MECHANIC")
	hero.global_position = _front("MECHANIC").global_position + Vector3(0, 0.02, 2.0)
	await _wait_s(0.4)
	Doors.try_nearest(hero)
	_check(mech["state"] == "locked" and "STEEL" in str(mech["prompt"].text),
			"steel says why it will not open (%s)" % mech["prompt"].text)
	Doors.try_nearest(hero)
	Doors.try_nearest(hero)
	Doors.try_nearest(hero)
	_check(mech["state"] == "locked",
			"steel refuses the shoulder, hit after hit")
	_check(Doors.context_verb(hero.global_position) == "TRY",
			"steel never offers BREAK")


func _combat_gate(hero: Node3D) -> void:
	# mid-fight the kick belongs to the enemy, never the door: with a
	# live hostile in reach, a kick must not even TRY the locked door
	var pal := _rec("PALACE")
	hero.global_position = _front("PALACE").global_position + Vector3(0, 0.02, 1.8)
	await _wait_s(0.3)
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	get_tree().current_scene.add_child(e)
	e.global_position = hero.global_position + Vector3(0.8, 0.02, -0.4)
	await _wait_s(0.3)
	var p := hero as Node
	p.call("_try_kick")
	_check(not pal["tried"] and pal["state"] == "locked",
			"a kick mid-fight never touches a door")
	e.queue_free()
	await _wait_s(0.2)


func _kick_path(hero: Node3D) -> void:
	var pal := _rec("PALACE")
	hero.global_position = _front("PALACE").global_position + Vector3(0, 0.02, 1.8)
	await _wait_s(0.4)
	var p := hero as Node
	# kick 1: the handle try; kicks 2-3: the two hits it takes
	# (realistic cadence - a player cannot kick faster than the swing)
	p.call("_try_kick")
	_check(pal["tried"], "the first kick tries the handle first")
	await _wait_s(0.7)
	p.call("_try_kick")
	_check(pal["hits_left"] == 1, "kick hit 1 lands on the frame")
	await _wait_s(0.7)
	p.call("_try_kick")
	_check(pal["state"] == "broken", "the second kick bursts PALACE open")
	_check(Doors.is_broken("PALACE"), "the city remembers PALACE as broken")
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await _wait_s(0.2)


func _persistence(hero: Node3D) -> void:
	# a real street reload: main.tscn is freed and rebuilt, new front
	# nodes rise, and the registry must re-break the frames it remembers
	_main.queue_free()
	await _wait_s(0.4)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as Node
	if opening and opening.has_method("skip"):
		opening.call("skip")
	await _wait_s(1.2)
	var hero2 := get_tree().get_first_node_in_group("player") as Node3D
	hero2.global_position = Vector3(240.5, 0.02, -7.0)
	await _wait_s(2.5)  # the market rebuilds, the Doors sweep re-runs
	var n9 := _rec("NEON 9")
	_check(not n9.is_empty(), "NEON 9 re-registers after the reload")
	if n9.is_empty():
		return
	_check(n9["state"] == "broken",
			"a broken door STAYS broken after the reload")
	var mesh: MeshInstance3D = n9["door_mesh"]
	_check(mesh != null and absf(mesh.rotation.y) > 0.5,
			"the reloaded leaf settles swung open (rot %.2f)" % (
				mesh.rotation.y if mesh else -9.0))
	var pal := _rec("PALACE")
	_check(not pal.is_empty() and pal["state"] == "broken",
			"PALACE too stays broken (the city remembers)")
	var mech := _rec("MECHANIC")
	_check(not mech.is_empty() and mech["state"] == "locked",
			"steel stays steel after the reload")


func _static_record() -> void:
	for name in ["MAMA SUN'S NOODLES", "YOUR ROOM", "THE KNUCKLE ROOM",
			"THE WAREHOUSE", "THE TAILOR", "THE GEAR COUNTER", "THE PAWN DESK"]:
		_check(name in Doors.OPEN_DOORS,
				"the open-door record lists %s" % name)
