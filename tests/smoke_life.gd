extends Node
## S5.3 LIVING WORLD SUITE: the street breathes - deterministic
## checks (the VLM gates proved the reads; this pins the systems).
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("LIFE PASS %s" % what)
	else:
		_fail += 1
		print("LIFE FAIL %s" % what)

func _ready() -> void:
	var dog := get_tree().create_timer(150.0)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	# per-area expectations: walkers, locals, cars (the districts
	# share the life systems; the counts pin that each really
	# spawns them)
	for spec in [["neighbourhood", 4, 2, 2], ["club_district", 4, 2, 2],
			["docks", 3, 1, 0]]:
		var area: String = spec[0]
		var want_peds: int = spec[1]
		var want_locals: int = spec[2]
		var want_cars: int = spec[3]
		await Game.travel(area, "start")
		await _wait_s(2.0)
		var walkers: Array = []
		for p in get_tree().get_nodes_in_group("pedestrian"):
			if not p.is_in_group("local") and is_instance_valid(p):
				walkers.append(p)
		_check(walkers.size() >= want_peds,
				"%s: walkers on the ground (%d>=%d)" % [area,
						walkers.size(), want_peds])
		var with_clips := 0
		for p in walkers:
			if p.get_node_or_null("Rig") != null and p._anim != null \
					and p._anim.has_animation("ambient/walking_a"):
				with_clips += 1
		_check(with_clips >= want_peds,
				"%s: rigs + clips mounted (%d)" % [area, with_clips])
		var before := {}
		for p in walkers:
			before[p] = (p as Node3D).global_position.x
		await _wait_s(3.0)
		var moved := 0
		for p in walkers:
			if is_instance_valid(p) and absf(
					(p as Node3D).global_position.x - before[p]) > 0.3:
				moved += 1
		_check(moved >= 2, "%s: the walkers walk (%d moved)" % [area,
				moved])
		var locals_: Array = get_tree().get_nodes_in_group("local")
		_check(locals_.size() >= want_locals,
				"%s: named locals at venues (%d>=%d)" % [area,
						locals_.size(), want_locals])
		if want_cars > 0:
			var cars := get_tree().current_scene.find_children(
					"Traffic*", "Node", false, false)
			_check(cars.size() >= want_cars,
					"%s: the lanes have cars (%d)" % [area, cars.size()])
			var cx := {}
			for c in cars:
				cx[c] = (c.body as Node3D).global_position.x
			await _wait_s(2.5)
			var drove := 0
			for c in cars:
				if absf((c.body as Node3D).global_position.x - cx[c]) > 1.0:
					drove += 1
			_check(drove >= want_cars, "%s: the cars drive (%d)" % [
					area, drove])
		# the 'start' spawn lands somewhere sane (not the raw origin)
		var hero := get_tree().get_first_node_in_group("player") as Node3D
		_check(hero != null and hero.global_position.length() > 1.0,
				"%s: the start spawn is placed (%s)" % [area, str(
						hero.global_position if hero else Vector3.ZERO)])
	_finish()

func _finish() -> void:
	print("LIFE RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
