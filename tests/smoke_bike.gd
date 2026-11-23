extends Node
## B26 WHEELS EVERYWHERE: the bicycle is a real ride - context ENTER
## mounts it, the hero rides IN SIGHT seated in the open (no cabin),
## the stick pedals and steers, B brakes, the BELL sounds, traffic
## yields to the occupied bike, X steps off at the kerb. And the
## street owns several vehicles now: the second sedan, the bicycle,
## and one drivable car per far block - every one persisted by name
## through a save/load round trip.
## Run: godot --headless --path . res://tests/smoke_bike.tscn

var _fails := 0
var _checks := 0
var _main: Node
var _hero: CharacterBody3D
var _bike: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("BIKE FAIL: ", what)
	else:
		print("BIKE ok: ", what)


func _stick(v: Vector2) -> void:
	var s := get_tree().get_first_node_in_group("stick")
	if s:
		s.call("debug_set_move", v)


func _physics_seconds(t: float) -> void:
	var frames := int(round(t * 60.0))
	for i in frames:
		await get_tree().physics_frame


func _vehicle_named(n: String) -> Node3D:
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v is Node3D and (v as Node).name == n:
			return v as Node3D
	return null


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout
	_hero = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_bike = _vehicle_named("Bicycle")

	# 1. the bicycle is a real drivable vehicle
	_check(_bike != null and _bike is CharacterBody3D,
			"the bicycle exists as a vehicle body (drivable)")
	if _bike == null or _hero == null:
		_finish()
		return

	# 2. cars everywhere: the kerb parks a second sedan too
	var car_b := _vehicle_named("ParkedCarB")
	_check(car_b != null, "the second parked sedan (ParkedCarB) stands")
	_check(get_tree().get_nodes_in_group("vehicle").size() >= 3,
			"the riverside block parks 3+ real vehicles (sedan, sedan B, bicycle)")

	# 3. the context verb beside the bike
	_hero.global_position = _bike.global_position + Vector3(0, 0.1, -1.4)
	_check(_hero.context_action() == "ENTER",
			"beside the bicycle the context verb is ENTER")

	# 4. mounting: occupied, hero IN SIGHT (the whole difference from
	# the car), driving, camera retargeted, seated pose
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	_hero._try_grab_action()
	await get_tree().physics_frame
	_check(bool(_bike.get("occupied")), "mounting occupies the bike")
	_check(_hero.visible, "the hero rides IN PLAIN SIGHT on the bike")
	_check(bool(_hero.get("driving")), "the hero reports driving state")
	if cam and cam.has_method("retarget"):
		_check(cam.get("_target") == _bike,
				"the camera follows the bike while riding")
	var rig := _hero.get_node_or_null("Body/Hero")
	_check(rig != null and str(rig.call("current")) == "Sit",
			"the rider sits (rig on the seated pose)")

	# 5. THE WHEEL-AXIS LAW (the B26 probe): the wheels ROLL about the
	# axle - the cylinder axis never leaves the lateral line (the
	# B19 rotate_x bug flopped every wheel on the street)
	var wheel := _bike.find_children("wheel_*", "Node3D", true, false)
	var wf: Node3D = wheel[0] if wheel.size() > 0 else null
	var axis0 := Vector3.ZERO
	if wf:
		axis0 = (wf as Node3D).basis * Vector3.UP
	var q0 := wf.quaternion if wf else Quaternion.IDENTITY
	_stick(Vector2.UP)
	await _physics_seconds(1.2)
	var sp := float(_bike.get("speed"))
	_check(sp > 2.0, "pedalling accelerates (speed %.1f m/s)" % sp)
	if wf:
		var axis1: Vector3 = (wf as Node3D).basis * Vector3.UP
		_check(absf(axis1.normalized().y) < 0.02
				and absf(axis1.normalized().z) < 0.02,
				"the front wheel ROLLS - its axle stays on the lateral line")
		_check(not wf.quaternion.is_equal_approx(q0),
				"the front wheel actually spins while riding")

	# 6. the rider is carried: hero and bike moved together
	var d := _hero.global_position.distance_to(_bike.global_position)
	_check(d < 1.7, "the hero stays attached to the saddle (%.2f m)" % d)
	_check(absf(_hero.global_position.z - _bike.global_position.z) < 1.0,
			"the rider sits ON the bike's line, not dragged behind")

	# 7. steering turns the bars
	var yaw0 := _bike.rotation.y
	_stick(Vector2(0.7, 0.7).normalized())
	await _physics_seconds(0.6)
	_check(absf(_bike.rotation.y - yaw0) > 0.05,
			"the steering turns the bike (yaw %.2f)"
			% absf(_bike.rotation.y - yaw0))

	# 8. the brake (B) sheds speed hard
	_bike.call("handbrake", true)
	await _physics_seconds(0.5)
	var sp2 := float(_bike.get("speed"))
	_check(sp2 < sp * 0.5, "the B brake sheds speed (%.1f -> %.1f)" % [sp, sp2])
	_bike.call("handbrake", false)

	# 9. the BELL sounds (A on the drive cluster)
	_bike.call("honk")
	_check(bool(_bike.call("horn_active")), "the bell rings (A BELL)")

	_stick(Vector2.ZERO)
	await _physics_seconds(0.8)

	# 10. traffic yields to the OCCUPIED bike on its lane
	var lane_z := -4.2
	_bike.global_position = Vector3(12.0, 0.0, lane_z)
	var probe := Node3D.new()
	probe.position = Vector3(6.0, 0.0, lane_z)
	add_child(probe)
	var yields_occupied := false
	var yields_free := true
	if Traffic.has_method("_hazard_ahead"):
		yields_occupied = Traffic.call("_hazard_ahead", probe, true,
				lane_z, null)
		_bike.call("request_exit")
		await get_tree().create_timer(0.3).timeout
		yields_free = Traffic.call("_hazard_ahead", probe, true,
				lane_z, null)
	_check(yields_occupied, "traffic brakes behind the occupied bike")
	_check(not yields_free, "a dismounted bike does NOT freeze the lane")

	# 11. dismount: hero beside, in sight, controllers resumed
	_check(not bool(_bike.get("occupied")), "X steps off the bike")
	_check(_hero.visible, "the hero stands beside the bike again")
	_check(not bool(_hero.get("driving")), "driving state clears")
	_check(_hero.global_position.distance_to(_bike.global_position) < 3.0,
			"the hero steps off beside the bike")
	_stick(Vector2.UP)
	await _physics_seconds(0.4)
	var cur := str(rig.call("current")) if rig else ""
	_check(cur != "Sit", "the walk cycle resumes after dismount (%s)" % cur)
	_stick(Vector2.ZERO)

	# 12. the second sedan is genuinely drivable too (cars everywhere)
	if car_b != null:
		_hero.global_position = car_b.global_position + Vector3(0, 0.1, 2.2)
		_check(_hero.context_action() == "ENTER",
				"beside ParkedCarB the context verb is ENTER")
		_hero._try_grab_action()
		await get_tree().physics_frame
		_check(bool(car_b.get("occupied")),
				"ParkedCarB boards - the whole kerb is real metal")
		car_b.call("request_exit")
		await get_tree().physics_frame

	# 13. the far blocks park their own car (market): walk there
	await Blocks.travel("market", "east")
	var car_m := _vehicle_named("CarMarket")
	_check(car_m != null, "the market block parks a drivable CarMarket")
	if car_m != null:
		_hero.global_position = car_m.global_position + Vector3(0, 0.1, 2.0)
		_check(_hero.context_action() == "ENTER",
				"beside CarMarket the context verb is ENTER (walked there, not teleported)")
	await Blocks.travel("riverside", "west")

	# 14. multi-vehicle persistence: bike + sedan BOTH restore by name
	_bike.global_position = Vector3(-20.0, 0.0, -2.3)
	var sedan := _vehicle_named("ParkedCar")
	sedan.global_position = Vector3(-24.0, 0.0, -2.4)
	var saved := SaveGame.save_all()
	_check(saved, "the game saves with several vehicles moved")
	_bike.global_position = Vector3(9.0, 0.0, -2.3)
	sedan.global_position = Vector3(9.0, 0.0, -2.4)
	SaveGame.load_all()
	await get_tree().create_timer(0.5).timeout
	_check(absf(_bike.global_position.x - (-20.0)) < 0.5,
			"the bike is where it was left (x %.1f)" % _bike.global_position.x)
	_check(absf(sedan.global_position.x - (-24.0)) < 0.5,
			"the sedan is where it was left (x %.1f)" % sedan.global_position.x)

	_finish()


func _finish() -> void:
	await get_tree().create_timer(0.5).timeout
	print("BIKE RESULT: %d checks, %d fails" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
