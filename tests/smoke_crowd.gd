extends Node
const CLS_Wanderer := preload("res://scripts/wanderer.gd")
const CLS_BlockBuilder := preload("res://scripts/block_builder.gd")
## B19 batch 5: the living city. Pedestrians walk the pavement graph
## (never the road outside the crossing), live small lives (browse,
## phone, pairs, the club queue), react to fights (watch / record /
## flee), keep district densities, and no two are identical clones.
## Run:  godot --headless --path . res://tests/smoke_crowd.tscn

var _fails := 0
var _checks := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("CROWD FAIL: ", what)
	else:
		print("CROWD ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	# B27: this suite asserts quiet-street behaviours - the director
	# stands down (smoke_events runs the live street)
	Settings.set_value("dynamic_events", false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(3.0).timeout  # the street settles

	# 1. the riverside has its people (base 6, mood +-2, no queue here)
	var crowd := _main.get_node_or_null("Crowd")
	print("CROWD diag: crowd=", crowd, " children=",
			crowd.get_child_count() if crowd else -1)
	var peds := _living(crowd)
	_check(peds.size() >= 4 and peds.size() <= 9,
			"riverside density (%d walkers)" % peds.size())

	# 2. pavement discipline: nobody stands in the road except at the
	#    crossing line
	var on_road_bad := 0
	var crossing := 0
	for w in peds:
		var wp := (w as Node3D).global_position
		if absf(wp.z) < 6.0:
			if absf(wp.x) < 2.0:
				crossing += 1
			else:
				on_road_bad += 1
	_check(on_road_bad == 0, "nobody walks the road outside the crossing (%d bad)" % on_road_bad)
	_check(crossing <= peds.size(), "crossing use recorded (%d)" % crossing)

	# 3. the street moves: most walkers changed position over a second
	var before := {}
	for w in peds:
		before[w] = (w as Node3D).global_position
	await get_tree().create_timer(1.5).timeout
	var moved := 0
	for w in peds:
		if before.has(w) and is_instance_valid(w) \
				and (w as Node3D).global_position.distance_to(before[w]) > 0.3:
			moved += 1
	_check(moved >= peds.size() / 2,
			"the street moves (%d of %d walked)" % [moved, peds.size()])

	# 4. variety: bodies and tints differ - no cloned crowd
	# B23: bodies are code-built humanoids - variety reads from the
	# rig's spec (build, height bucket, hair, skirt), not gltf names
	var bodies := {}
	for w in peds:
		var rig: Node = null
		for c in (w as Node).get_children():
			if c.get_script() != null and "npc_rig" in str(c.get_script().resource_path):
				rig = c
		var look := "nobody"
		if rig and not (rig.get("spec") as Dictionary).is_empty():
			var sp: Dictionary = rig.get("spec")
			look = "%d-%.2f-%d-%s" % [sp.get("build", 1),
					sp.get("height", 1.7), sp.get("hair_style", 0),
					str(sp.get("skirt", false))]
		bodies[look] = true
	_check(bodies.size() >= 2, "at least two body models on the street (%d)" % bodies.size())

	# 5. a fight splits the street: reactions happen, then the street
	#    settles back on its own
	var reacted := 0
	Fx.hit_landed.emit("jab", Vector3(0, 1, 8))
	await get_tree().create_timer(1.0).timeout
	for w in _living(crowd):
		var st: int = (w as Node).get("_state")
		if st == CLS_Wanderer.State.WATCH or st == CLS_Wanderer.State.PHONE \
				or st == CLS_Wanderer.State.FLEE:
			reacted += 1
	_check(reacted >= 2, "a public fight draws reactions (%d of %d)"
			% [reacted, _living(crowd).size()])
	await get_tree().create_timer(8.0).timeout  # calm + settle
	var still_scared := 0
	for w in _living(crowd):
		var st2: int = (w as Node).get("_state")
		if st2 == CLS_Wanderer.State.WATCH or st2 == CLS_Wanderer.State.FLEE:
			still_scared += 1
	_check(still_scared == 0, "the street calms back down (%d still scared)" % still_scared)

	# 6. the crossing waits for traffic: a staged walker at the crossing
	#    holds while a car is within 12 m, crosses when it clears (real
	#    traffic included - the street runs during this suite)
	var agent := _stage_crosser(crowd)
	if agent:
		var car := Node3D.new()
		car.add_to_group("traffic")
		car.position = Vector3(4.0, 0, 0)
		_main.add_child(car)
		await get_tree().create_timer(1.0).timeout
		_check((agent.get("_state") as int) == CLS_Wanderer.State.CROSS_WAIT,
				"a walker holds at the crossing while a car passes")
		car.position = Vector3(60.0, 0, 0)  # gone
		# real traffic keeps running: it either passes or STOPS to yield
		# (courtesy both ways) - either way the walker gets to cross
		var crossed := false
		for i in 24:
			await get_tree().create_timer(0.5).timeout
			if (agent.get("_state") as int) != CLS_Wanderer.State.CROSS_WAIT:
				crossed = true
				break
		_check(crossed,
				"the walker crosses once the road clears (real traffic yields or passes)")
		car.queue_free()
	else:
		_check(false, "a crossing-bound walker could be staged")

	# 7. the market: busier, with the club queue at the VELVET ROOM
	#    (the crowd is Blocks' to staff, so the block is built the way
	#    the game builds it)
	Blocks.call("_ensure", "market")
	Blocks.call("_wanderers", "market")
	await get_tree().create_timer(1.5).timeout
	var market := Blocks.block_node("market")
	var mcrowd: Node = market.get_node_or_null("Crowd") if market else null
	var mpeds := _living(mcrowd)
	var want_market := 5 if Quality.tier == Quality.LOW else 8
	_check(mpeds.size() >= want_market,
			"the market street is the busy one (%d walkers)" % mpeds.size())
	var queued := 0
	for w in mcrowd.get_children():
		if _in_queue(w) and not (w as Node).is_queued_for_deletion():
			queued += 1
	_check(queued == 3, "the club queue holds its line (%d)" % queued)

	# 8. the foundry: workers, fewer
	Blocks.call("_ensure", "foundry")
	Blocks.call("_wanderers", "foundry")
	await get_tree().create_timer(1.5).timeout
	var fpeds := _living(Blocks.block_node("foundry").get_node_or_null("Crowd"))
	var want_foundry := 2 if Quality.tier == Quality.LOW else 4
	_check(fpeds.size() >= want_foundry and fpeds.size() <= want_foundry + 2,
			"the docks keep a working crowd (%d)" % fpeds.size())

	if _fails == 0:
		print("CROWD PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("CROWD FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _living(crowd: Node) -> Array:
	var out: Array = []
	if crowd == null:
		return out
	for c in crowd.get_children():
		if not c.is_queued_for_deletion() and not _in_queue(c):
			out.append(c)
	return out


## queue members carry a real slot (not the Vector3.ZERO default)
func _in_queue(c: Node) -> bool:
	var slot = c.get("queue_slot")
	return slot != null and slot != Vector3.ZERO


## Stage one walker AT the crossing, waiting to cross: the
## deterministic setup for the traffic-yield check.
func _stage_crosser(crowd: Node) -> Node:
	if crowd == null:
		return null
	var w := CLS_Wanderer.new()
	w.block = "riverside"
	w.home = Vector3(0.5, 0.0, 8.0)
	crowd.add_child(w)
	w.spawn()
	w.set("_state", CLS_Wanderer.State.CROSS_WAIT)
	w.set("_target_side", -1.0)
	return w
