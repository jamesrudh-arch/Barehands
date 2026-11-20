extends Node
## Batch 8 suite: the district made real (bible 6). Three blocks walked
## through gates with fades - no fast travel anywhere; fog lifts only
## where your feet have been; blocks 2 and 3 build themselves with
## their landmarks (the gym, the garage, the warehouse, the water, the
## underpass); crowds thin with the mood; violence scars the block and
## deaths leave memorials, both persisted; the noodle shop is a room
## behind a fade; the phone's map reads names, layers, and fog.

var _fails := 0
var _checks := 0
var _player: CharacterBody3D
var _ui: CanvasLayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("DISTRICT FAIL: ", what)
	else:
		print("DISTRICT ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.0)  # Blocks wires the gates + interior
	_player = main.get_node("Player") as CharacterBody3D
	_ui = get_node("/root/Phone/PhoneUI") as CanvasLayer

	await _test_boot_fog()
	await _test_walk_the_blocks()
	await _test_interior()
	await _test_scars_and_deaths()
	await _test_map()
	await _test_planks()

	if _fails == 0:
		print("DISTRICT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("DISTRICT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _calm() -> void:
	Phone.close()
	await _wait_s(0.4)
	InputBus.clear_queues()


# --- A. the home block + the fog ------------------------------------------------


func _test_boot_fog() -> void:
	await _wait_s(0.3)
	_check(Blocks.current() == "riverside", "the home block loads first")
	_check(City.district_now() == "riverside", "the city agrees")
	_check(Phone.has_visited("riverside"), "your home block is never fogged")
	_check(not Phone.has_visited("market") and not Phone.has_visited("foundry"),
			"the other blocks start fogged")
	_check(Interior != null and get_tree().get_nodes_in_group("shop_owner").size() == 1,
			"the noodle shop owner exists")


# --- B. the walk: gates, fades, fog, landmarks -----------------------------------


func _walk_to(x: float, z := 0.0, expect := "") -> void:
	var was := Blocks.current()
	_player.global_position = Vector3(x, 0.02, z)
	_player.velocity = Vector3.ZERO
	# the gate fires and both fades run - poll for the arrival so a
	# slow world (a phone just closed) never races the check
	for i in 30:
		await _wait_s(0.3)
		if expect != "" and Blocks.current() == expect:
			break
		if expect == "" and Blocks.current() != was:
			break
	await _wait_s(0.3)


func _test_walk_the_blocks() -> void:
	await _walk_to(18.6, 0.0, "market")  # the east gate of the home block
	_check(Blocks.current() == "market", "the east gate walks into the club quarter")
	_check(Phone.has_visited("market"), "walking lifts the fog")
	_check(absf(_player.global_position.x - (240.0 - 16.4)) < 2.0,
			"you arrive at the quarter's west end (%.1f)" % _player.global_position.x)
	var market := Blocks.block_node("market")
	_check(market != null, "the club quarter built itself")
	_check(_has_label(market, "IRON PALM GYM"), "the gym is here (bible 6)")
	_check(_has_label(market, "MECHANIC"), "the Mechanic's garage is here")
	_check(not get_tree().get_nodes_in_group("underpass").is_empty(),
			"the underpass dresses the 2-3 ends")
	var crowd := market.get_node_or_null("Crowd") as Node
	_check(crowd != null and crowd.get_child_count() == 2,
			"an indifferent block keeps 2 walkers (%d)" % (crowd.get_child_count() if crowd else -1))
	# east again: the docks
	await _walk_to(258.6, 0.0, "foundry")
	_check(Blocks.current() == "foundry", "the underpass end walks into the docks")
	_check(Phone.has_visited("foundry"), "the docks unfog")
	var docks := Blocks.block_node("foundry")
	_check(docks != null and not get_tree().get_nodes_in_group("warehouse_door").is_empty(),
			"the warehouse and its shut door are here")
	_check(docks != null and docks.get_node_or_null("Water") != null,
			"the water is here")
	# and back west, the long way home
	await _walk_to(461.4, 0.0, "market")
	_check(Blocks.current() == "market", "walking back west returns to the quarter")
	await _walk_to(221.4, 0.0, "riverside")
	_check(Blocks.current() == "riverside", "the west gate walks home")
	_check(absf(_player.global_position.x - 16.4) < 2.0,
			"home again at the east end (%.1f)" % _player.global_position.x)


# --- C. the noodle shop: a room behind a fade --------------------------------------


func _test_interior() -> void:
	var shop := _find_interior()
	_check(shop != null, "the noodle shop exists")
	_player.global_position = Vector3(-4.0, 0.02, 6.4)
	_player.velocity = Vector3.ZERO
	await _wait_s(0.4)
	_check(shop.try_use(_player), "GRAB at the door steps through")
	await _wait_s(1.2)
	_check(Interior.is_inside_interior(_player),
			"the door fades you into the shop (x %.1f)" % _player.global_position.x)
	_check(not get_tree().get_nodes_in_group("shop_owner").is_empty(),
			"the owner is behind the counter")
	# the exit door fades you back onto the street
	_player.global_position = Vector3(720.0, 0.02, 3.6)
	_player.velocity = Vector3.ZERO
	await _wait_s(1.6)
	_check(not Interior.is_inside_interior(_player),
			"the exit fades you back out (x %.1f)" % _player.global_position.x)
	_check(absf(_player.global_position.x - (-4.0)) < 2.0,
			"back at the shop front (%.1f)" % _player.global_position.x)


# --- D. the scars: damage decals, memorials, persistence ----------------------------


func _test_scars_and_deaths() -> void:
	City.note_damage(Vector3(2.0, 0.0, 1.0), "scorch")
	City.note_death(Vector3(-2.0, 0.0, 1.0))
	_check(City.damage_points("riverside").size() == 1, "the damage is remembered")
	_check(City.death_points("riverside").size() == 1, "the death is remembered")
	# the decals spawn when the block is next dressed - walk out and back
	await _walk_to(18.6)
	await _walk_to(221.4, 0.0, "riverside")
	_check(get_tree().get_nodes_in_group("decal").size() >= 1,
			"the scorch is on the street")
	_check(get_tree().get_nodes_in_group("memorial").size() >= 1,
			"the memorial stands where someone died")
	# violence feeds the damage layer too
	var before := City.damage_points("riverside").size()
	City.on_violence("knockdown", _player.global_position)
	_check(City.damage_points("riverside").size() == before + 1,
			"a knockdown scars the block")
	# and it all rides the save
	var d := City.to_dict()
	City.from_dict({"rep": {}, "hostile": {}, "witnessed": {},
			"nickname": "x", "damage": {}, "deaths": {}})
	_check(City.damage_points("riverside").is_empty(),
			"an empty restore clears the scars")
	City.from_dict(d)
	_check(City.damage_points("riverside").size() >= 2
			and City.death_points("riverside").size() == 1,
			"the full restore brings them back")


# --- E. the map: names, layers, fog, no fast travel ----------------------------------


func _test_map() -> void:
	Phone.open()
	await _wait_s(0.3)
	(_ui.get_node("Screen/Apps/MapBtn") as Button).pressed.emit()
	await _wait_s(0.3)
	var body := _ui.get_node("Screen/AppBody")
	_check(_find_text(body, "RIVERSIDE ROW"), "the home card carries its name")
	_check(_find_text(body, "THE CLUB QUARTER"), "the quarter card carries its name")
	_check(_find_text(body, "THE DOCKS"), "the docks card carries its name")
	_check(_find_text(body, "MOOD "), "the mood layer reads")
	_check(_find_text(body, "HEAT "), "the heat layer reads")
	_check(_find_text(body, "FRIENDS "), "the friends layer reads")
	_check(_find_text(body, "DAMAGE "), "the damage layer reads")
	_check(_find_text(body, "no fast travel"), "the map says what it is")
	# no fast travel: only the BACK button and the board's TAKE buttons
	var travel := 0
	for b in _find_buttons(body, ""):
		if not (b as Button).text.begins_with("TAKE - ") and b.text != "BACK":
			travel += 1
	_check(travel == 0, "no travel buttons - only BACK and TAKE (%d others)" % travel)
	Phone.close()
	await _wait_s(0.2)


# --- F. a hot street boards up --------------------------------------------------------


func _test_planks() -> void:
	City.turn_hostile("market")
	await _walk_to(18.6)
	_check(not get_tree().get_nodes_in_group("plank").is_empty(),
			"a hostile block boards its fronts")
	var crowd := (Blocks.block_node("market").get_node_or_null("Crowd") as Node)
	_check(crowd == null or crowd.get_child_count() == 0,
			"nobody walks a hot street")


func _find_interior() -> Interior:
	for n in get_tree().get_nodes_in_group("interior"):
		if n is Interior:
			return n
	return null


func _has_label(root: Node, text: String) -> bool:
	if root == null:
		return false
	if root is Label3D and (root as Label3D).text.contains(text):
		return true
	for c in root.get_children():
		if _has_label(c, text):
			return true
	return false


func _find_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for c in node.get_children():
		if _find_text(c, text):
			return true
	return false


func _find_buttons(node: Node, prefix: String) -> Array:
	var hits: Array = []
	if node is Button and (node as Button).text.begins_with(prefix):
		hits.append(node)
	for c in node.get_children():
		hits.append_array(_find_buttons(c, prefix))
	return hits
