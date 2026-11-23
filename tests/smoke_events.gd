extends Node
const CLS_Wanderer := preload("res://scripts/wanderer.gd")
## B27: THE STREET HAPPENS TO ITSELF. The umbrella law (heavy rain
## puts canopies over the street, dry air folds them), the dispute
## (two citizens square up in ANGRY faces the player can read, the
## pavement collects, the city remembers), the gossip chain (a told
## story is retold as you pass), the fender-bender (both cars stand
## with hazards pulsing, the lane waits, then they drive on), the
## police sweep (a cruiser rolls with beacons, the road empties
## around it) - and every event lands in the ONE memory the radio,
## the gossip and the smalltalk all read.
## Run: godot --headless --path . res://tests/smoke_events.tscn

var _fails := 0
var _checks := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("EVENTS FAIL: ", what)
	else:
		print("EVENTS ok: ", what)


func _physics_seconds(t: float) -> void:
	var frames := int(round(t * 60.0))
	for i in frames:
		await get_tree().physics_frame


func _wanderers() -> Array:
	var out: Array = []
	for w in get_tree().get_nodes_in_group("wanderer"):
		if is_instance_valid(w):
			out.append(w)
	return out


func _mouth_of(w: Node) -> MeshInstance3D:
	var m := (w as Node3D).find_children("Mouth", "MeshInstance3D", true, false)
	return m[0] if m.size() > 0 else null


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.5).timeout

	# 1. the director exists and starts quiet
	_check(Events != null and Events.active() == "",
			"the Events director exists and the street starts quiet")
	if Events == null:
		_finish()
		return

	# 2. THE UMBRELLA LAW: heavy rain canopies the street
	Weather.set_state("heavy")
	Weather.intensity = 0.92
	await _physics_seconds(1.5)
	var canopies := get_tree().get_nodes_in_group("umbrella").size()
	_check(canopies >= 3,
			"heavy rain snaps umbrellas open (%d on the street)" % canopies)
	Weather.set_state("normal")
	Weather.intensity = 0.65
	await _physics_seconds(1.5)
	var folded := get_tree().get_nodes_in_group("umbrella").size()
	_check(folded == 0, "dry air folds every umbrella (%d left)" % folded)

	# 3. THE DISPUTE: two citizens square up, angry faces the player
	# can READ, the pavement collects, the city remembers
	var calm := _wanderers()
	if calm.size() >= 5:
		var a: Node3D = calm[0]
		var b: Node3D = calm[1]
		var mid := Vector3(-6.0, 0.0, 8.0)
		# exile everyone else down the kerb so the planted pair is
		# unambiguously the closest calm couple on the block
		var ex := 6.0
		for i in range(2, calm.size()):
			(calm[i] as Node3D).global_position = Vector3(ex, 0.0, 8.0)
			(calm[i] as Node3D).set("_state", CLS_Wanderer.State.WALK)
			ex += 4.0
		a.global_position = mid + Vector3(-0.8, 0.0, 0.0)
		b.global_position = mid + Vector3(0.8, 0.0, 0.0)
		var watchers: Array = []
		for i in mini(3, calm.size() - 2):
			var w: Node3D = calm[2 + i]
			w.global_position = mid + Vector3(0.0, 0.0, -1.8 - i * 0.9)
			w.set("_state", CLS_Wanderer.State.WALK)
			watchers.append(w)
		await get_tree().physics_frame
		var fired: bool = Events.force("dispute")
		_check(fired and Events.active() == "dispute",
				"a dispute flares (two neighbours, one kerb)")
		await _physics_seconds(1.2)
		_check(int(a.get("_state")) == CLS_Wanderer.State.ARGUE
				and int(b.get("_state")) == CLS_Wanderer.State.ARGUE,
				"both arguers are in the ARGUE state")
		_check(a.get("_dispute_with") == b and b.get("_dispute_with") == a,
				"the pair is cross-linked at each other")
		var ma := _mouth_of(a)
		_check(ma != null and ma.scale.y < 0.8,
				"the anger is OBSERVABLE - the mouth goes tight (%.2f)"
				% (ma.scale.y if ma else -1.0))
		var watching := 0
		for w in watchers:
			if int((w as Node).get("_state")) == CLS_Wanderer.State.WATCH:
				watching += 1
		_check(watching == watchers.size(),
				"the pavement collects - every planted passerby turns to watch (%d/%d)"
				% [watching, watchers.size()])
		var heard := City.last_heard("riverside")
		_check(heard.contains("squared up"),
				"the city remembers the dispute the radio will quote ('%s')" % heard)
		Events.end_now()
		await _physics_seconds(0.5)
		_check(int(a.get("_state")) != CLS_Wanderer.State.ARGUE
				and int(b.get("_state")) != CLS_Wanderer.State.ARGUE,
				"the argument resolves - both walk on")

	# 4. THE GOSSIP CHAIN: a told story is retold as you pass
	var walkers := _wanderers()
	if walkers.size() >= 2:
		var hero := get_tree().get_first_node_in_group("player") as Node3D
		var g: Node3D = walkers[0]
		g.global_position = Vector3(-4.0, 0.0, 8.0)
		g.set("_state", CLS_Wanderer.State.WALK)
		hero.global_position = g.global_position + Vector3(0.8, 0.02, 0.8)
		g.call("hear_gossip", "the docks burned", Vector3.ZERO)
		await _physics_seconds(0.6)
		var said := str(g.get("_said"))
		_check(said.contains("the docks burned"),
				"a told story is retold as you pass ('%s')" % said)

	# 5. THE FENDER-BENDER: two cars kiss, both stand, hazards pulse,
	# the lane waits, then they drive on
	var lane := -4.2
	var c1 := _spawn_traffic_at(Vector3(8.0, 0.02, lane))
	var c2 := _spawn_traffic_at(Vector3(3.4, 0.02, lane))
	if c1 == null or c2 == null:
		_check(false, "the bender pair spawned (traffic available)")
	elif Events.force("bender"):
		# the director picks its own pair from the pool (ambient cars
		# can match first) - assert on the pair IT chose
		var ba: Node3D = Events.get("_bend_a")
		var bb: Node3D = Events.get("_bend_b")
		_check(Events.active() == "bender",
				"a fender-bender holds the lane")
		await _physics_seconds(0.8)
		_check(ba != null and bb != null and bool(ba.get_meta("bender", false))
				and bool(bb.get_meta("bender", false)),
				"both chosen cars carry the bender mark")
		_check(float(ba.get_meta("speed")) == 0.0
				and float(bb.get_meta("speed")) == 0.0,
				"the pair stands still")
		var m1: StandardMaterial3D = ba.get_meta("tail_mat")
		var lo := 99.0
		var hi := -99.0
		for i in 18:
			await _physics_seconds(0.05)
			if m1:
				lo = minf(lo, m1.emission_energy_multiplier)
				hi = maxf(hi, m1.emission_energy_multiplier)
		_check(hi - lo > 0.6,
				"the hazard lamps PULSE while the pair stands (%.2f..%.2f)" % [lo, hi])
		Events.end_now()
		await _physics_seconds(1.2)
		_check(not ba.has_meta("bender") and not bb.has_meta("bender"),
				"the bender clears - the marks lift")
		_check(float(bb.get_meta("speed")) > 0.0,
				"the lane drives on again (speed %.1f)" % float(bb.get_meta("speed")))

	# 6. THE POLICE SWEEP: a cruiser rolls with beacons, the road
	# empties around it - a pedestrian mid-crossing clears the zebra as
	# it nears (the road clamp keeps WALKERS on the kerb by design;
	# the only legal road state is CROSSING)
	var road_folk: Node3D = null
	var wk := _wanderers()
	if wk.size() > 0:
		road_folk = wk[wk.size() - 1]
		road_folk.global_position = Vector3(0.0, 0.0, 1.5)  # ON the zebra
		road_folk.set("_state", CLS_Wanderer.State.CROSSING)
	var fired3: bool = Events.force("sweep")
	_check(fired3 and Events.active() == "sweep",
			"the sweep cruiser rolls (heat drew it)")
	var cruiser: Node3D = null
	for c in get_tree().get_nodes_in_group("traffic"):
		if (c as Node).name == "SweepCar":
			cruiser = c as Node3D
	_check(cruiser != null, "the SweepCar is on the street")
	if cruiser and road_folk:
		# HOLD the crosser mid-zebra until the cruiser is inside the
		# 8 m shoo radius (poll the cruiser - no clock math), then
		# release: the next tick (<= 0.8 s) shoos them and the FLEE
		# runs ~1.9 s to the kerb. A pin running past the release would
		# stamp the FLEE back to CROSSING - the release IS the test.
		while cruiser.global_position.x < -5.0:
			await get_tree().physics_frame
			road_folk.global_position = Vector3(0.0, 0.0, 1.2)
			road_folk.set("_state", CLS_Wanderer.State.CROSSING)
		await _physics_seconds(0.9)
		_check(int(road_folk.get("_state")) == CLS_Wanderer.State.FLEE,
				"the crosser is FLEEING the cruiser (state %d, z %.1f)"
				% [int(road_folk.get("_state")), road_folk.global_position.z])
	Events.end_now()
	await _physics_seconds(0.3)
	var still := false
	for c in get_tree().get_nodes_in_group("traffic"):
		if (c as Node).name == "SweepCar":
			still = true
	_check(not still, "the cruiser drives on (recycled)")

	# 7. the whole event trail lives in the ONE memory the radio reads
	var trail := 0
	for e in City.witnessed.get("riverside", []):
		var ev := str(e.get("event", ""))
		if ev.contains("squared up") or ev.contains("kissed") or ev.contains("cruiser"):
			trail += 1
	_check(trail >= 2, "the street's memory carries the event trail (%d entries)" % trail)

	_finish()


## Spawn a traffic car, then park it exactly where the event needs it.
func _spawn_traffic_at(pos: Vector3) -> Node3D:
	var before := get_tree().get_nodes_in_group("traffic").size()
	Traffic.call("_spawn", "riverside")
	var new_count := get_tree().get_nodes_in_group("traffic").size()
	if new_count <= before:
		return null
	var car: Node3D = null
	for c in get_tree().get_nodes_in_group("traffic"):
		var cn := c as Node3D
		if cn.get_meta("block", "") == "riverside" and cn not in _used:
			car = cn
	if car == null:
		return null
	_used.append(car)
	car.set_meta("east", true)
	car.set_meta("speed", 2.0)
	car.position = pos
	return car


var _used: Array = []


func _finish() -> void:
	await get_tree().create_timer(0.5).timeout
	print("EVENTS RESULT: %d checks, %d fails" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
