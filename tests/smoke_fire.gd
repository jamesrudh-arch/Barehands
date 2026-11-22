extends Node
## B19 batch 8: FIRE. Layered flames (core + outer + embers), smoke
## that grows and drifts with the wind, steam when the rain works at
## it, at most two flickering lights, a scorch decal pool capped at
## the Mobile budget, burn barrels as slam surfaces, and a crackle
## bed. Run: godot --headless --path . res://tests/smoke_fire.tscn

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FIRE FAIL: ", what)
	else:
		print("FIRE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.5).timeout

	# 1. the street burns: the alley barrel and the noodle grill
	var sources := get_tree().get_nodes_in_group("fire_source")
	_check(sources.size() >= 2, "fire sources live on the street (%d)" % sources.size())

	# 2. layered fire: every source carries core + outer + smoke (+steam
	#    on barrels), each a bounded CPUParticles3D with a sprite
	var layered := 0
	var sprites := 0
	for s in sources:
		var n := 0
		for key in ["flame_core", "flame_outer", "smoke"]:
			if (s as Node).get_meta(key, null) != null:
				n += 1
		if n >= 3:
			layered += 1
		for p in (s as Node).find_children("*", "CPUParticles3D", true, false):
			var mesh: QuadMesh = (p as CPUParticles3D).mesh
			if mesh and mesh.material is StandardMaterial3D \
					and (mesh.material as StandardMaterial3D).albedo_texture != null:
				sprites += 1
				break
	_check(layered == sources.size(), "every fire is layered (%d of %d)"
			% [layered, sources.size()])
	_check(sprites == sources.size(), "every fire uses real sprites (%d)" % sprites)

	# 3. the barrels are slam surfaces (environmental takedown into fire)
	var slam := 0
	for s in sources:
		for c in (s as Node).find_children("*", "StaticBody3D", true, false):
			if (c as StaticBody3D).has_meta("slam_surface") \
					and str((c as StaticBody3D).get_meta("slam_surface")) == "fire":
				slam += 1
	_check(slam >= 1, "a burn barrel is a fire slam surface (%d)" % slam)

	# 4. the light budget: at most 2 flickering fire lights, ever
	Weather.set_state("normal")
	await get_tree().create_timer(0.5).timeout
	var lights := 0
	for s in get_tree().get_nodes_in_group("fire_source"):
		for l in (s as Node).find_children("*", "OmniLight3D", true, false):
			if (l as OmniLight3D).visible:
				lights += 1
	_check(lights <= 2, "the fire light budget holds (%d lit)" % lights)

	# 5. the rain works at the fire: steam wakes, flames damp
	Weather.set_state("storm")
	await get_tree().create_timer(0.7).timeout
	var steaming := 0
	for s in get_tree().get_nodes_in_group("fire_source"):
		var steam: CPUParticles3D = null
		if (s as Node).has_meta("steam"):
			steam = (s as Node).get_meta("steam")
		if steam and steam.emitting:
			steaming += 1
	_check(steaming >= 1, "rain on fire makes steam (%d steaming)" % steaming)
	Weather.set_state("light")
	await get_tree().create_timer(0.7).timeout
	var steaming_after := 0
	for s in get_tree().get_nodes_in_group("fire_source"):
		var steam: CPUParticles3D = null
		if (s as Node).has_meta("steam"):
			steam = (s as Node).get_meta("steam")
		if steam and steam.emitting:
			steaming_after += 1
	_check(steaming_after == 0, "dry weather keeps the steam off (%d)" % steaming_after)

	# 6. scorch decals: capped pool, oldest recycled, never more than 8
	#    (they attach to the current scene root - wherever that is)
	for i in 20:
		Fire.scorch_at(Vector3(i * 0.5 - 5.0, 0.03, 6.0), 2.0)
	await get_tree().create_timer(0.3).timeout
	var decals := 0
	for d in get_tree().root.find_children("*", "Decal", true, false):
		if (d as Decal).visible:
			decals += 1
	_check(decals <= 8 and decals >= 1,
			"the scorch pool stays within the Mobile budget (%d visible)" % decals)

	# 7. no node growth: repeated scorches recycle the same decals
	# (settle first: the flicker lights are created lazily)
	await get_tree().create_timer(0.6).timeout
	var nodes_before := get_tree().get_node_count()
	for i in 10:
		Fire.scorch_at(Vector3(2.0, 0.03, 6.0), 2.0)
	await get_tree().create_timer(0.3).timeout
	_check(get_tree().get_node_count() == nodes_before,
			"scorches recycle, never accumulate (%d -> %d)"
			% [nodes_before, get_tree().get_node_count()])

	# 8. the crackle bed plays
	var crackling := 0
	for s in get_tree().get_nodes_in_group("fire_source"):
		for a in (s as Node).find_children("*", "AudioStreamPlayer3D", true, false):
			if (a as AudioStreamPlayer3D).playing:
				crackling += 1
	_check(crackling >= 1, "the fire crackles (%d beds)" % crackling)

	if _fails == 0:
		print("FIRE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("FIRE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
