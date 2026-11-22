extends Node
const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_BlockBuilder := preload("res://scripts/block_builder.gd")
## B18.4: the CC0 kit integration contract. The Kenney City Kit / Car
## Kit models replace the placeholder boxes (licences in CREDITS.md and
## assets/kits/LICENSE-Kenney-CC0.txt); every check here pins one piece
## of that takeover so a regression is a named line, not a look.
## Run:  godot --headless --path . res://tests/smoke_kits.tscn

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("KITS FAIL: ", what)
	else:
		print("KITS ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(1.0).timeout  # deferred kit adds land

	# 1. the kit files import at all
	for rel in ["kenney_commercial/building-f.glb",
			"kenney_commercial/building-g.glb", "kenney_commercial/building-b.glb",
			"kenney_commercial/building-d.glb", "kenney_city/building-small-d.glb",
			"kenney_city/pavement.glb", "kenney_roads/road-straight.glb",
			"kenney_roads/light-curved-double.glb",
			"kenney_roads/construction-barrier.glb", "kenney_cars/sedan.glb",
			# B19 kits: the docks, the traffic pool, the homes, the rooms
			"kenney_industrial/building-l.glb", "kenney_industrial/chimney-medium.glb",
			"kenney_industrial/detail-tank.glb", "kenney_traffic/truck.glb",
			"kenney_traffic/box.glb", "kenney_traffic/police.glb",
			"kenney_traffic/suv.glb", "kenney_traffic/van.glb",
			"kenney_suburban/building-type-a.glb", "kenney_suburban/building-type-c.glb",
			"kenney_furniture/bedSingle.glb", "kenney_furniture/loungeSofa.glb",
			"kenney_furniture/stoolBar.glb", "kenney_food/skewer.glb"]:
		_check(CLS_Kit.available(rel), "kit imports: %s" % rel)

	# 2. the main street's six placeholder box plots wear kit buildings,
	#    and the box meshes behind them hide
	var dressed := 0
	var hidden := 0
	for name_b in ["BuildingA", "BuildingB", "BuildingC",
			"BuildingD", "BuildingE", "BuildingF"]:
		var b: Node3D = main.find_child(name_b, true, false)
		if b == null:
			continue
		var mesh_mi: MeshInstance3D = b.get_node_or_null("Mesh")
		for c in main.get_children():
			if c.name.begins_with("Kit_building") and c is Node3D \
					and absf((c as Node3D).position.x - b.position.x) < 5.0:
				dressed += 1
				break
		if mesh_mi and not mesh_mi.visible:
			hidden += 1
	_check(dressed == 6, "all six building plots wear kit buildings (%d)" % dressed)
	_check(hidden == 6, "all six placeholder box meshes hide (%d)" % hidden)

	# 3. the kit buildings kept their colormap (not blank slabs)
	var textured := 0
	for c in main.get_children():
		if c.name.begins_with("Kit_building"):
			for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				if mesh == null:
					continue
				for i in mesh.get_surface_count():
					var m: Material = mesh.surface_get_material(i)
					if m is StandardMaterial3D \
							and (m as StandardMaterial3D).albedo_texture != null:
						textured += 1
	_check(textured >= 6, "kit buildings carry their colormap texture (%d surfaces)" % textured)

	# 4. the pavements: kit tiles in, slab boxes out
	var pavements := 0
	for c in main.get_children():
		if c.name.begins_with("Kit_pavement"):
			pavements += 1
	var slabs_hidden := 0
	for sw_name in ["SidewalkN", "SidewalkS"]:
		var sw: MeshInstance3D = main.find_child(sw_name, true, false)
		if sw and not sw.visible:
			slabs_hidden += 1
	_check(pavements == 2, "both sidewalks wear kit pavement (%d)" % pavements)
	_check(slabs_hidden == 2, "both sidewalk slab boxes hide (%d)" % slabs_hidden)

	# 5. the lamps: B23 code-built posts (dark poles, warm sodium
	# lights the moths can adopt) - the glb lamps retired with the
	# white-arm obstruction they rendered on device
	var lamps := 0
	for c in main.find_children("StreetLamp*", "Node3D", true, false):
		lamps += 1
	_check(lamps == 6, "six lamp posts at the curb (%d)" % lamps)
	var lamp_lights := 0
	for l in get_tree().get_nodes_in_group("street_lights"):
		if l is OmniLight3D and l.get_parent() != null \
				and (l.get_parent() as Node).name.begins_with("StreetLamp"):
			lamp_lights += 1
	_check(lamp_lights == 6, "every lamp post carries a warm light (%d)" % lamp_lights)

	# 6. the parked car: the CC0 sedan body, the noir lights on top, the
	#    takedown collision untouched
	var car: Node = main.find_child("ParkedCar", true, false)
	_check(car != null, "the ParkedCar stands")
	var car_kit := false
	for c in car.get_children():
		if c.name.begins_with("Kit_sedan"):
			car_kit = true
	var boxes := 0  # visible BoxMesh children: the noir light boxes only
	for c in car.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh \
				and (c as MeshInstance3D).visible:
			boxes += 1
	_check(car_kit, "the Kenney sedan took the body")
	_check(boxes == 6, "only the six noir light boxes stay visible (%d)" % boxes)
	_check(car.has_meta("slam_surface") and str(car.get_meta("slam_surface")) == "car",
			"the slam surface meta survives")

	# 7. every kit material respects the 1.1 emission cap (ART_BIBLE)
	var cap_ok := true
	for k in get_tree().get_nodes_in_group("cc0_kit"):
		var mesh: Mesh = null
		if k is MultiMeshInstance3D:
			mesh = (k as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if m is StandardMaterial3D \
					and (m as StandardMaterial3D).emission_enabled \
					and (m as StandardMaterial3D).emission_energy_multiplier > 1.1:
				cap_ok = false
	_check(cap_ok, "kit emissions capped at 1.1 (the Mobile buffer)")

	# 8. the enemies wear the CC0 characters (the dummy keeps its
	#    mannequin - kind 0 is gear, not a person)
	if OS.get_environment("KITS_DEBUG") == "1":
		for k in get_tree().get_nodes_in_group("cc0_kit"):
			print("KITS DEBUG: %s at %s" % [str(k.get_path()),
					str((k as Node3D).global_position) if k is Node3D else "-"])
	await _check_enemy_kinds()

	# 9. blocks 2 and 3 dress from the same kits
	await _check_blocks()

	# 10. B19: the alley and the back row - annexes, garages, suburban
	#     depth behind the north shopfronts
	var alley_kits := 0
	var alley_hidden := 0
	for p in ["Parkour/Annex1", "Parkour/Annex2", "Parkour/Garage1", "Parkour/Garage2"]:
		var b: Node3D = main.get_node_or_null(p)
		if b == null:
			continue
		for c in b.get_children():
			if c is MeshInstance3D and not (c as MeshInstance3D).visible:
				alley_hidden += 1
				break
	for c in main.get_children():
		if c.name.begins_with("Kit_building_type") or c.name.begins_with("Kit_building_garage"):
			alley_kits += 1
	_check(alley_kits == 7, "alley outbuildings + suburban back row (%d kits)" % alley_kits)
	_check(alley_hidden == 4, "the four alley box meshes hide (%d)" % alley_hidden)

	# 11. B19: the hero wears real textures - natively resolved by the
	#     import, or rebound per mesh (both count; flat is the failure)
	# B23: the hero is the code-built humanoid - no gltf textures by
	# DESIGN; the check is the body is REAL: many meshes, every mesh
	# dressed with its own material, the joint tree complete
	var hero: Node3D = main.find_child("Hero", true, false)
	var hero_meshes := 0
	var hero_dressed := 0
	var hero_joints := 0
	if hero:
		for mi in hero.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh == null:
				continue
			hero_meshes += 1
			if (mi as MeshInstance3D).material_override is StandardMaterial3D:
				hero_dressed += 1
		for jn in ["shoulder_l", "elbow_l", "hip_l", "knee_l", "head"]:
			if hero.find_child(jn, true, false):
				hero_joints += 1
	_check(hero != null and hero_meshes >= 20 and hero_dressed >= 18
			and hero_joints == 5,
			"the hero is a full code-built body (%d meshes, %d dressed, %d/5 joints)" % [
					hero_meshes, hero_dressed, hero_joints])

	# 12. B19: the trainer is a real character, the fx sprites load
	var trainer := get_tree().get_first_node_in_group("trainer")
	var trainer_rig := false
	if trainer:
		for c in trainer.get_children():
			if c.get_script() != null and "npc_rig" in str(c.get_script().resource_path):
				trainer_rig = true
	_check(trainer != null and trainer_rig,
			"the trainer is a real UBC character (no capsule)")
	for fx in ["smoke_1.png", "fire_1.png", "fire_core_1.png", "spark_burst.png"]:
		_check(ResourceLoader.exists("res://assets/fx/" + fx),
				"fx sprite ships: %s" % fx)

	if _fails == 0:
		print("KITS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("KITS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _check_enemy_kinds() -> void:
	for kind in [1, 2, 3, 4]:
		var e: CharacterBody3D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
		e.set("kind", kind)
		add_child(e)
		await get_tree().process_frame
		var person: Node = e.get("_humanoid")
		var mats: Array = e.get("_mats")
		var mi: MeshInstance3D = e.get_node_or_null("Body/Mannequin/Armature/Skeleton3D/Mannequin")
		_check(person != null and is_instance_valid(person),
				"kind %d wears its humanoid body" % kind)
		_check(mats.size() > 0, "kind %d owns tinted materials (%d)" % [kind, mats.size()])
		_check(mi == null or not mi.visible, "kind %d hides the plain mannequin" % kind)
		e.queue_free()
	var dummy: CharacterBody3D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	dummy.set("kind", 0)
	add_child(dummy)
	await get_tree().process_frame
	_check((dummy.get("_char_pieces") as Array).is_empty(),
			"the training dummy keeps its mannequin")
	dummy.queue_free()


func _check_blocks() -> void:
	for block_id in ["market", "foundry"]:
		var b: Node3D = CLS_BlockBuilder.new()
		b.block_id = block_id
		add_child(b)
		b.build_block()
		await get_tree().process_frame
		await get_tree().process_frame  # deferred kit adds land
		var kits := 0
		var buildings := 0
		var road_rows := 0
		var construction := 0
		var crates := 0
		var dock := 0
		for c in b.get_children():
			if c is Node3D and c.name.begins_with("Kit_"):
				kits += 1
				# the market's fog skyscraper is a silhouette, not a plot
				if c.name.begins_with("Kit_building") \
						and not c.name.begins_with("Kit_building_skyscraper"):
					buildings += 1
				if c.name.begins_with("Kit_construction"):
					construction += 1
				if c.name.begins_with("Kit_box"):
					crates += 1
				if c.name.begins_with("Kit_truck") \
						or c.name.begins_with("Kit_chimney") \
						or c.name.begins_with("Kit_detail_tank"):
					dock += 1
			if c.name.begins_with("KitRow_"):
				kits += 1
				road_rows += 1
		var want_construction := 4
		# B23: the kit glb buildings retired from street plots (device
		# ghosts); the code facades carry them - window panes + roofs
		var windows := 0
		for w in get_tree().get_nodes_in_group("facade_window"):
			windows += 1
		var want_panes := 12 if block_id == "foundry" else 30
		_check(windows >= want_panes,
				"%s: code facades with window grids (%d panes)" % [block_id, windows])
		_check(road_rows == 1, "%s: the marked road lane tiles (%d rows)" % [block_id, road_rows])
		_check(construction == want_construction,
				"%s: the roadworks patch stands (%d props)" % [block_id, construction])
		var want_kits2 := 10 if block_id == "market" else (
				20 if block_id == "foundry" else 22)
		_check(kits >= want_kits2,
				"%s: the street dresses from the kits (%d models)" % [block_id, kits])
		if block_id == "market":
			var awnings := 0
			for c in b.get_children():
				if c.name.begins_with("Kit_detail_awning"):
					awnings += 1
			_check(awnings == 2, "market: awnings over the club fronts (%d)" % awnings)
		else:
			# the foundry: the warehouse sheds carry the old box volume,
			# the containers wear textured crates, the dock works
			_check(crates >= 8, "foundry: textured cargo crates (%d)" % crates)
			_check(dock == 3, "foundry: the dock works - truck, chimney, tank (%d)" % dock)
			var wh_box_hidden := false
			for c in b.get_children():
				if c is StaticBody3D:
					for mc in (c as Node).get_children():
						var wmesh := mc as MeshInstance3D
						if wmesh and not wmesh.visible and wmesh.mesh is BoxMesh \
								and (wmesh.mesh as BoxMesh).size.x > 20.0:
							wh_box_hidden = true
			_check(wh_box_hidden, "foundry: the warehouse placeholder box hides")
			_check(b.find_child("warehouse_door", true, false) != null
					or b.get_tree().get_nodes_in_group("warehouse_door").size() > 0,
					"foundry: the MERIDIAN door group survives")
		b.queue_free()
