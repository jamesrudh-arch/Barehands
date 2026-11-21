extends Node
## B19 batch 9: INTERIORS. Five real rooms: the furnished apartment
## and noodle shop, and three NEW venues on the market block - IRON
## PALM GYM (swinging bags, mats, a coach), THE RAIN GLASS bar
## (counter, stools, sofa corner, a bartender) and THE VELVET ROOM
## club (dance floor, DJ booth, speakers that pulse, dancers on the
## UAL Dance clip). Every room is enterable through its street door
## (fade), lit, collidable and furnished from the CC0 kits.
## Run: godot --headless --path . res://tests/smoke_interiors.tscn

var _fails := 0
var _checks := 0
var _main: Node
var _player: Node3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("ROOMS FAIL: ", what)
	else:
		print("ROOMS ok: ", what)


func _kits_under(node: Node) -> int:
	return node.find_children("Kit_*", "Node3D", true, false).size()


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout
	_player = get_tree().get_first_node_in_group("player")

	# 1. the apartment: a real home (bed, shelf, tv corner, boxes...)
	var apartment := get_tree().get_nodes_in_group("safehouse").filter(
		func(n): return str((n as Node).get_meta("door_name", "")) == "APARTMENT DOOR")
	var a_kits := 0
	if not apartment.is_empty():
		a_kits = _kits_under(apartment[0])
	_check(a_kits >= 10, "the apartment is furnished (%d kit pieces)" % a_kits)

	# 2. the noodle shop: a working business
	var noodle := get_tree().get_nodes_in_group("safehouse").filter(
		func(n): return str((n as Node).get_meta("door_name", "")) == "NOODLE SHOP DOOR")
	var n_kits := 0
	if not noodle.is_empty():
		n_kits = _kits_under(noodle[0])
	_check(n_kits >= 10, "the noodle shop dresses like a business (%d)" % n_kits)

	# 3. travel to the market: the three venues exist with doors
	Blocks.call("_ensure", "market")
	await get_tree().create_timer(1.5).timeout
	var venues := {}
	for n in get_tree().get_nodes_in_group("door_prompt"):
		var dn := str((n as Node).get_meta("door_name", ""))
		venues[dn] = n
	_check(venues.has("IRON PALM GYM DOOR"), "the gym has a street door")
	_check(venues.has("THE RAIN GLASS DOOR"), "the bar has a street door")
	_check(venues.has("THE VELVET ROOM DOOR"), "the club has a street door")

	# 4. each venue is a furnished, lit room off the world axis
	for pair in [["IRON PALM GYM DOOR", 6, "gym"],
			["THE RAIN GLASS DOOR", 8, "bar"],
			["THE VELVET ROOM DOOR", 8, "club"]]:
		var v: Node = venues.get(pair[0])
		var kits := _kits_under(v) if v else 0
		var lit := false
		if v:
			for l in v.find_children("*", "OmniLight3D", true, false):
				lit = true
				break
		_check(v != null and kits >= pair[1] and lit,
				"the %s is furnished and lit (%d pieces)" % [pair[2], kits])

	# 5. the gym bags swing (not static props)
	var gym: Node = venues.get("IRON PALM GYM DOOR")
	var swinging := 0
	if gym:
		for c in gym.get_children():
			if c is Node3D and (c as Node3D).position.y > 2.5 \
					and (c as Node3D).get_child_count() >= 2:
				swinging += 1
	_check(gym != null and swinging >= 3, "the heavy bags hang and swing (%d)" % swinging)

	# 6. the club dancers are on the Dance clip
	var club: Node = venues.get("THE VELVET ROOM DOOR")
	var dancing := 0
	if club:
		for c in club.find_children("*", "Node3D", true, false):
			var sc = c.get_script()
			if sc == null or not ("npc_rig" in str(sc.resource_path)):
				continue
			if str(c.call("current")) == "Dance":
				dancing += 1
	_check(club != null and dancing >= 3, "the club dances (%d on the floor)" % dancing)

	# 7. entering works: the real flow - walk into the market, then
	#    through the gym door and back out
	if gym and _player:
		Blocks.call("travel", "market", "west")
		await get_tree().create_timer(1.5).timeout
		(gym as Node).call("enter")
		await get_tree().create_timer(1.2).timeout
		var inside := absf(_player.global_position.x - 840.0) < 8.0
		_check(inside, "the gym door fades you inside")
		(gym as Node).call("exit_to_street")
		await get_tree().create_timer(1.2).timeout
		# the exit lands at the gym's own street door on the market block
		_check(absf(_player.global_position.x - 233.5) < 3.0
				and absf(_player.global_position.z - 7.6) < 3.0,
				"the gym door fades you back to the street")

	if _fails == 0:
		print("ROOMS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("ROOMS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
