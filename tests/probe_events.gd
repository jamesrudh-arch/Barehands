extends Node
## B27 probe: does Events._process actually tick? Prints the
## director's clock after a forced sweep - the honest answer.

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout
	print("PROBE t0: _t=%.2f _shoo=%.2f active=%s" % [float(Events.get("_t")),
			float(Events.get("_shoo_t")), Events.active()])
	var ok: bool = Events.force("sweep")
	print("PROBE force sweep: %s" % str(ok))
	var road_folk: Node3D = null
	for w in get_tree().get_nodes_in_group("wanderer"):
		var wn := w as Node3D
		if wn and is_instance_valid(wn) and not bool(wn.get("_entered")):
			road_folk = wn
			break
	road_folk.global_position = Vector3(0.0, 0.0, 1.8)
	road_folk.set("_state", 0)  # WALK
	print("PROBE folk before: state=%d entered=%s z=%.1f" % [
			int(road_folk.get("_state")), str(road_folk.get("_entered")),
			road_folk.global_position.z])
	await get_tree().create_timer(1.0).timeout
	var cruiser: Node3D = null
	for c in get_tree().get_nodes_in_group("traffic"):
		if (c as Node).name == "SweepCar":
			cruiser = c as Node3D
	print("PROBE cruiser at %s" % str(cruiser.global_position if cruiser else "null"))
	# direct call: does the API itself work?
	road_folk.set("_state", 2)
	road_folk.call("shoo", cruiser.global_position)
	print("PROBE direct shoo: state=%d z=%.1f" % [int(road_folk.get("_state")),
			road_folk.global_position.z])
	road_folk.set("_state", 0)
	# now let the events tick reach it, pinned in place
	var pin := 0.0
	while pin < 3.0:
		await get_tree().create_timer(0.5).timeout
		pin += 0.5
		road_folk.global_position = Vector3(0.0, 0.0, 1.8)
		road_folk.set("_state", 0)
	print("PROBE after ticks: state=%d z=%.1f _shoo=%.2f _t=%.1f active=%s" % [
			int(road_folk.get("_state")), road_folk.global_position.z,
			float(Events.get("_shoo_t")), float(Events.get("_t")), Events.active()])
	Events.end_now()
	await get_tree().create_timer(0.3).timeout
	print("PROBE t3: active=%s next_at=%.1f" % [Events.active(),
			float(Events.get("_next_at"))])
	get_tree().quit(0)
