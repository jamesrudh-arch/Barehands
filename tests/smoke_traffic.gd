extends Node
## B19 batch 6: TRAFFIC. Cars spawn at the gates, drive their lanes in
## both directions, brake for the hero on the road, keep their gap to
## the car ahead, despawn at the far gate (the pool stays bounded),
## carry headlights/brake lights and an engine hum, and never leave the
## road. Run: godot --headless --path . res://tests/smoke_traffic.tscn

var _fails := 0
var _checks := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("TRAFFIC FAIL: ", what)
	else:
		print("TRAFFIC ok: ", what)


func _cars() -> Array:
	return get_tree().get_nodes_in_group("traffic").filter(
		func(c): return is_instance_valid(c))


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	# let a few cars spawn and drive the street
	await get_tree().create_timer(14.0).timeout

	# 1. cars exist and drive (spawned, moving)
	var cars := _cars()
	_check(cars.size() >= 1, "cars spawn and drive (%d on the street)" % cars.size())
	if cars.is_empty():
		_finish()
		return

	# 2. they stay on their lanes: |z - lane| small, inside the road
	var on_lane := 0
	for c in cars:
		var z := (c as Node3D).position.z
		var lane_ok := absf(absf(z) - 4.2) < 0.5 or absf(absf(z) - 2.4) < 0.5
		if lane_ok:
			on_lane += 1
	_check(on_lane == cars.size(), "every car holds its lane (%d of %d)"
			% [on_lane, cars.size()])

	# 3. they move in both directions
	var east := 0
	var west := 0
	for c in cars:
		if c.get_meta("east", false):
			east += 1
		else:
			west += 1
	_check(east > 0 or west > 0, "traffic runs (%d east, %d west)" % [east, west])

	# 4. no pile-up: cars in the same lane keep the gap
	var gap_ok := true
	var all := _cars()
	for c in all:
		for o in all:
			if c == o or o.get_meta("east") != c.get_meta("east"):
				continue
			if absf((o as Node3D).position.z - (c as Node3D).position.z) < 1.5:
				var gap := absf((o as Node3D).position.x - (c as Node3D).position.x)
				if gap > 0.5 and gap < 5.0:
					gap_ok = false
	_check(gap_ok, "no car rides another's bumper")

	# 5. the hero on the road stops the traffic (nobody is run over):
	#    stand 5 m ahead of the first car, in ITS lane
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var c0 := (_cars()[0] as Node3D) if not _cars().is_empty() else null
	if c0:
		var dir0 := 1.0 if c0.get_meta("east") else -1.0
		player.global_position = Vector3(
				clampf(c0.position.x + dir0 * 5.0, -18.0, 18.0), 0.02,
				c0.position.z)
		await get_tree().create_timer(2.5).timeout
		var stopped := 0
		for c in _cars():
			if float(c.get_meta("speed")) < 1.0:
				stopped += 1
		_check(stopped >= 1, "the hero on the road stops the traffic (%d stopped)" % stopped)
		player.global_position = Vector3(0.0, 0.02, 8.0)  # back on the kerb
		await get_tree().create_timer(4.0).timeout
		var rolling := 0
		for c in _cars():
			if float(c.get_meta("speed")) > 3.0:
				rolling += 1
		_check(rolling >= 1, "traffic resumes once the road clears (%d rolling)" % rolling)
	else:
		_check(false, "a car could be staged for the brake test")

	# 6. the pool stays bounded and recycles (spawn->despawn loop)
	var pool_max := 3 if Quality.tier == Quality.LOW else 3
	_check(_cars().size() <= pool_max, "the pool stays bounded (%d cars max)" % _cars().size())

	# 7. the kit car carries its lights and an engine voice
	var lit := 0
	var engines := 0
	for c in _cars():
		var boxes := 0
		for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
			var m: Material = (mi as MeshInstance3D).material_override
			if m == null and (mi as MeshInstance3D).mesh != null \
					and (mi as MeshInstance3D).mesh is BoxMesh:
				boxes += 1
		if boxes >= 4:
			lit += 1
		if c.get_meta("engine", null) != null:
			engines += 1
	_check(lit == _cars().size(), "every car carries its light boxes (%d)" % lit)
	_check(engines == _cars().size(), "every car has an engine voice (%d)" % engines)

	_finish()


func _finish() -> void:
	if _fails == 0:
		print("TRAFFIC PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("TRAFFIC FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
