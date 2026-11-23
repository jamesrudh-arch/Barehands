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
	var dog := get_tree().create_timer(90.0)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	await _wait_s(2.0)
	# the walkers
	var walkers: Array = []
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if not p.is_in_group("local") and is_instance_valid(p):
			walkers.append(p)
	_check(walkers.size() >= 4,
			"the street has walkers (%d)" % walkers.size())
	var with_clips := 0
	var with_rigs := 0
	for p in walkers:
		if p.get_node_or_null("Rig") != null:
			with_rigs += 1
		if p._anim != null and p._anim.has_animation("ambient/walking_a") \
				and p._anim.has_animation("ambient/Idle_A"):
			with_clips += 1
	_check(with_rigs == walkers.size(),
			"every walker mounts a cast rig (%d/%d)" % [with_rigs,
					walkers.size()])
	_check(with_clips == walkers.size(),
			"every walker has the alias clips (%d/%d)" % [with_clips,
					walkers.size()])
	# the walkers MOVE (positions change over 3s)
	var before := {}
	for p in walkers:
		before[p] = (p as Node3D).global_position.x
	await _wait_s(3.0)
	var moved := 0
	for p in walkers:
		if is_instance_valid(p) and absf(
				(p as Node3D).global_position.x - before[p]) > 0.3:
			moved += 1
	_check(moved >= 2, "the walkers walk (%d of %d moved)" % [moved,
			walkers.size()])
	# the locals at the venues
	var locals_: Array = get_tree().get_nodes_in_group("local")
	_check(locals_.size() >= 2,
			"the named locals stand at their venues (%d)" % [
					locals_.size()])
	var labeled := 0
	for l in locals_:
		var has_label := false
		for c in (l as Node).get_children():
			if c is Label3D:
				has_label = true
		if has_label:
			labeled += 1
	_check(labeled >= 2, "the locals carry their names (%d)" % labeled)
	# the traffic moves along the lanes
	var cars := get_tree().current_scene.find_children("Traffic*",
			"Node", false, false)
	_check(cars.size() >= 2, "the lanes have cars (%d)" % cars.size())
	var cx := {}
	for c in cars:
		cx[c] = (c.body as Node3D).global_position.x
	await _wait_s(2.5)
	var drove := 0
	for c in cars:
		if absf((c.body as Node3D).global_position.x - cx[c]) > 1.0:
			drove += 1
	_check(drove >= 2, "the cars drive the lanes (%d)" % drove)
	# the hero spawns on the lit street (not the alley mouth)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	_check(hero != null and absf(hero.global_position.x - -16.0) < 1.0
			and hero.global_position.z > -3.5,
			"the 'start' spawn lands on the street (%s)" % str(
					hero.global_position if hero else Vector3.ZERO))
	_finish()

func _finish() -> void:
	print("LIFE RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
