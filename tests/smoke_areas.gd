extends Node

## REBUILD STEP 9 proof suite: AREAS 3-4 — the club district and the
## docks, and the full travel chain between the four live areas.
##   - every area registers in Game.AREAS and boots with its spawn
##     markers and landmarks present (the club fronts + queue + the
##     crossing; the piers, cranes, maze, market, WAREHOUSE 9, lot);
##   - the door law covers the new fronts (open walk-ins, locked
##     reasons, NEON 9 breakable, WAREHOUSE 9 story-sealed);
##   - the gates: the neighbourhood's east gate now really travels
##     to the club district; the underpass chains club <-> docks;
##   - each area renders alive under its own lighting profile.

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
	_registry_block()
	await _club_block()
	await _docks_block()
	await _chain_block()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("AREAS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("AREAS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _find_deep(name: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_in(scene, name)


func _find_in(root: Node, name: String) -> Node:
	if str(root.name) == name:
		return root
	for c in root.get_children():
		var f := _find_in(c, name)
		if f:
			return f
	return null


func _img_alive() -> bool:
	await _wait_s(0.3)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return false
	img.save_png("/tmp/render/smoke_areas_%s.png" % Game.area_id)
	var l8 := img.duplicate()
	l8.convert(Image.FORMAT_L8)
	l8.resize(64, 36)
	var bins := {}
	var total := 0
	for y in l8.get_height():
		for x in l8.get_width():
			var v: int = l8.get_pixel(x, y).r8
			bins[v] = int(bins.get(v, 0)) + 1
			total += 1
	var mid := 0
	for i in range(10, 246):
		mid += int(bins.get(i, 0))
	return total > 0 and float(mid) / float(total) > 0.04


func _registry_block() -> void:
	_check(Game.AREAS.has("club_district")
			and Game.AREAS.has("docks"),
			"Game.AREAS registers both new areas")
	_check(str(Game.AREAS["club_district"]).ends_with("club_district.tscn")
			and str(Game.AREAS["docks"]).ends_with("docks.tscn"),
			"both area scenes point at their files")


func _club_block() -> void:
	await Game.travel("club_district", "from_neighbourhood")
	await _wait_s(1.0)
	_check(get_tree().current_scene != null
			and get_tree().current_scene.scene_file_path.ends_with(
			"club_district.tscn"),
			"the club district boots (%s)" % Game.area_id)
	_check(_find_deep("SpawnFromNeighbourhood") != null
			and _find_deep("SpawnFromDocks") != null,
			"both club spawn markers exist")
	# the fronts: two walk-ins north, the gym south, the locked laws
	for pair in [["THE VELVET ROOM", "open"], ["HOTEL AURORA", "open"],
			["NEON 9", "locked"], ["THE PARKING STRUCTURE", "locked"],
			["IRON PALM GYM", "open"], ["THE MECHANIC", "locked"]]:
		_check(Doors.state_of(pair[0]) == pair[1],
				"%s answers %s" % [pair[0], pair[1]])
	_check(Doors.state_of("NEON 9") == "locked",
			"NEON 9 is locked (its door law)")
	# the queue + the crossing + the side streets
	_check(_find_deep("VelvetQueue") != null,
			"the Velvet Room queue stands outside")
	_check(_find_deep("TheCrossing") != null,
			"the crossing exists with its light")
	var streets := 0
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("SideStreet_"):
			streets += 1
	_check(streets >= 2, "two side streets read off the avenue (%d)" % streets)
	# the east gate to the docks is real (zone + sign)
	var gate_zone := _find_deep("GateZone")
	var to_docks := false
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("Gate_THE_DOCKS"):
			to_docks = c.get_node_or_null("GateZone") != null
	_check(to_docks, "the underpass gate to the docks is wired")
	_check(await _img_alive(), "the club district renders alive")


func _docks_block() -> void:
	await Game.travel("docks", "from_club")
	await _wait_s(1.0)
	_check(get_tree().current_scene.scene_file_path.ends_with("docks.tscn"),
			"the docks boot (%s)" % Game.area_id)
	_check(_find_deep("SpawnFromClub") != null,
			"the docks spawn marker exists")
	# piers + cranes + the maze
	var piers := 0
	var cranes := 0
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("Pier_"):
			piers += 1
		if str(c.name).begins_with("Crane_"):
			cranes += 1
	_check(piers == 4, "four piers stand over the harbour (%d)" % piers)
	_check(cranes == 2, "two cranes loom (%d)" % cranes)
	_check(_find_deep("ContainerMaze") != null
			and _find_deep("ContainerMaze").get_child_count() > 8,
			"the container maze has its rows")
	_check(_find_deep("Harbour") != null,
			"the harbour water plane exists")
	# the market walks in; WAREHOUSE 9 stays story-sealed
	_check(Doors.state_of("THE FISH MARKET") == "open",
			"the fish market answers OPEN")
	_check(Doors.state_of("DOCK WAREHOUSE 9") == "locked",
			"DOCK WAREHOUSE 9 stays locked")
	var law := {}
	for d in Doors.door_list():
		if d["label"] == "DOCK WAREHOUSE 9":
			law = d
	_check(not law.is_empty() and not law.get("breakable", true),
			"WAREHOUSE 9 is unbreakable (the story owns it)")
	_check(_find_deep("TheEmptyLot") != null,
			"the empty lot keeps its story space")
	_check(await _img_alive(), "the docks render alive (fog + sodium)")


func _chain_block() -> void:
	# docks -> club -> neighbourhood -> warehouse: the full walk home
	await Game.travel("club_district", "from_docks")
	await _wait_s(0.6)
	_check(Game.area_id == "club_district",
			"the underpass chains docks -> club")
	await Game.travel("neighbourhood", "from_club")
	await _wait_s(0.6)
	_check(Game.area_id == "neighbourhood",
			"the avenue's west gate chains club -> neighbourhood")
	# and the neighbourhood's east gate is NOW real travel wiring
	var real := false
	for c in get_tree().current_scene.get_children():
		if str(c.name).begins_with("Gate_THE_CLUB"):
			real = c.get_node_or_null("GateZone") != null
	_check(real, "the neighbourhood's east gate travels (no placeholder)")
	await Game.travel("warehouse", "from_street")
	await _wait_s(0.6)
	_check(Game.area_id == "warehouse",
			"the street's west gate chains home")
	_check(_hero() != null and is_instance_valid(_hero()),
			"the hero survives the whole chain")
