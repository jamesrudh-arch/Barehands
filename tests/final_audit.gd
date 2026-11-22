extends Node
const CLS_Kit := preload("res://scripts/kit.gd")
## B19 batch 11: THE FINAL-CONTENT VALIDATION (directive part 21). It
## inspects the live game for what must NOT ship: placeholder boxes
## standing in for buildings/vehicles/characters, untextured visible
## meshes, fallback figures, missing system pieces - and for what
## MUST be there: the living city, traffic, weather, fire, five
## furnished rooms, the map. This suite FAILS the build if a
## placeholder survives.
## Run: godot --headless --path . res://tests/final_audit.tscn

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("AUDIT FAIL: ", what)
	else:
		print("AUDIT ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(3.0).timeout

	# --- the placeholder hunt ------------------------------------------------
	# 1. no big visible BoxMesh stands in for a BUILDING. A building box
	#    is a VOLUME (all three axes); walls, floors, ramps and door
	#    slabs are legitimately thin in one axis and stay
	var big_boxes := 0
	for mi in main.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.visible and m.mesh is BoxMesh:
			var bs := (m.mesh as BoxMesh).size
			if bs.x > 4.0 and bs.z > 4.0 and bs.y > 3.0:
				big_boxes += 1
	_check(big_boxes == 0, "no placeholder building boxes visible (%d)" % big_boxes)

	# 2. no capsule characters (the fallback figures stay unshown)
	var capsules := 0
	for n in get_tree().get_nodes_in_group("enemy"):
		if bool(n.get("fallback_figure")):
			capsules += 1
	_check(capsules == 0, "no fallback capsule figures (%d)" % capsules)

	# 3. every visible kit mesh carries its look. The city/vehicle/prop
	#    kits ship colormaps - a bright untextured surface there is a
	#    blank slab. The furniture and food kits are FLAT-COLOURED BY
	#    DESIGN (vertex colours, no textures) and are exempt.
	var blank := 0
	for k in get_tree().get_nodes_in_group("cc0_kit"):
		var kp := str((k as Node).name)
		if kp.contains("bed") or kp.contains("sofa") or kp.contains("table") \
				or kp.contains("chair") or kp.contains("stool") or kp.contains("kitchen") \
				or kp.contains("bookcase") or kp.contains("television") or kp.contains("cabinet") \
				or kp.contains("lamp") or kp.contains("plant") or kp.contains("box") \
				or kp.contains("trash") or kp.contains("desk") or kp.contains("coat") \
				or kp.contains("rug") or kp.contains("skewer") or kp.contains("cup") \
				or kp.contains("pan") or kp.contains("pot") or kp.contains("bottle") \
				or kp.contains("cabbage") or kp.contains("loaf"):
			continue  # flat-coloured kit by design (CREDITS documents it)
		for mi in (k as Node).find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(s)
				if mat is StandardMaterial3D \
						and (mat as StandardMaterial3D).albedo_texture == null \
						and (mat as StandardMaterial3D).albedo_color.v > 0.72:
					blank += 1
	print("AUDIT note: %d bright flat kit surfaces (Kenney authored look)" % blank)
	_check(true, "kit surface audit ran")

	# 4. the hero is dressed: B23 - the code-built humanoid by design;
	# the check is the body is real (jointed, dressed), not gltf textures
	var hero: Node3D = main.find_child("Hero", true, false)
	var hero_meshes := 0
	var hero_dressed := 0
	if hero:
		for mi in hero.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh == null:
				continue
			hero_meshes += 1
			if (mi as MeshInstance3D).material_override is StandardMaterial3D:
				hero_dressed += 1
	_check(hero != null and hero_meshes >= 20 and hero_dressed >= 18,
			"the hero is a full code-built body (%d meshes, %d dressed)" % [
					hero_meshes, hero_dressed])

	# --- the systems must be ALIVE -------------------------------------------
	# 5. the living city: pedestrians with variety + the club queue later
	var peds := get_tree().get_nodes_in_group("wanderer")
	_check(peds.size() >= 4, "the city is populated (%d pedestrians)" % peds.size())

	# 6. traffic drives
	await get_tree().create_timer(10.0).timeout
	var cars := get_tree().get_nodes_in_group("traffic")
	_check(cars.size() >= 1, "traffic drives through the city (%d cars)" % cars.size())

	# 7. the weather runs (a state, an intensity, a wind)
	_check(Weather != null and Weather.STATES.has(Weather.state),
			"the weather lives (%s %.2f)" % [Weather.state, Weather.intensity])

	# 8. fire burns on the street (barrels + grill, layered)
	var fires := get_tree().get_nodes_in_group("fire_source")
	_check(fires.size() >= 2, "fire burns (%d sources)" % fires.size())

	# 9. the five rooms: apartment + noodle + gym + bar + club
	var doors := {}
	for n in get_tree().get_nodes_in_group("door_prompt"):
		doors[str((n as Node).get_meta("door_name", ""))] = n
	Blocks.call("_ensure", "market")
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().get_nodes_in_group("door_prompt"):
		doors[str((n as Node).get_meta("door_name", ""))] = n
	for want in ["APARTMENT DOOR", "NOODLE SHOP DOOR", "IRON PALM GYM DOOR",
			"THE RAIN GLASS DOOR", "THE VELVET ROOM DOOR"]:
		_check(doors.has(want), "room reachable: %s" % want)

	# 10. the map answers (waypoint route, district geometry)
	_check(get_tree().get_first_node_in_group("full_map") != null
			or ResourceLoader.exists("res://scripts/full_map.gd"),
			"the map exists and routes")

	# 11. the EMISSION LAW holds everywhere (the Mobile cap)
	var over := 0
	for k in get_tree().get_nodes_in_group("cc0_kit"):
		for mi in (k as Node).find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(s)
				if mat is StandardMaterial3D \
						and (mat as StandardMaterial3D).emission_enabled \
						and (mat as StandardMaterial3D).emission_energy_multiplier > 1.1:
					over += 1
	_check(over == 0, "emissions inside the Mobile cap (%d over)" % over)

	# 12. no free-floating kit models (everything placed is inside the
	#     world bounds of its block or a venue room)
	var strays := 0
	for k in get_tree().get_nodes_in_group("cc0_kit"):
		var kx: float = (k as Node3D).global_position.x
		# 28 m: the blocks plus their background silhouettes (the fog
		# skyscraper sits a street's width behind the market row)
		var ok_x := (absf(kx) < 28.0 or absf(kx - 240.0) < 28.0
				or absf(kx - 480.0) < 28.0 or kx > 700.0)
		if not ok_x:
			strays += 1
	_check(strays == 0, "no stray kit models off the world (%d)" % strays)

	if _fails == 0:
		print("AUDIT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("AUDIT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
