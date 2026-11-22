extends Node
## B25: THE DRIVER. The parked noir sedan is a real drivable vehicle:
## context ENTER boards it, the stick steers and throttles, the
## handbrake bites, the horn sounds, traffic yields to the occupied
## car, X exits at the kerb, and the car persists through a save/load
## round trip. Run: godot --headless --path . res://tests/smoke_drive.tscn

var _fails := 0
var _checks := 0
var _main: Node
var _hero: CharacterBody3D
var _car: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("DRIVE FAIL: ", what)
	else:
		print("DRIVE ok: ", what)


func _stick(v: Vector2) -> void:
	# the stick node owns InputBus.move (its _process rewrites it every
	# frame from its own target) - the suite drives the stick, exactly
	# like every walking suite does
	var s := get_tree().get_first_node_in_group("stick")
	if s:
		s.call("debug_set_move", v)


func _reset_car() -> void:
	# each driving leg starts fresh: back on the runway, straight,
	# stopped - a curved leg must not bleed its geometry into the next
	_car.global_position = Vector3(18.0, 0.0, -2.4)
	_car.rotation.y = PI - 0.12
	_car.set("speed", 0.0)
	await get_tree().physics_frame


func _physics_seconds(t: float) -> void:
	# fixed 60 Hz frame counts: get_physics_process_delta_time() reads 0
	# in a headless run and every timed wait would collapse
	var frames := int(round(t * 60.0))
	for i in frames:
		await get_tree().physics_frame


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout
	_hero = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_car = get_tree().get_first_node_in_group("vehicle") as CharacterBody3D

	# 1. the sedan became a drivable vehicle
	_check(_car != null and _car is CharacterBody3D,
			"the parked sedan is a vehicle body (drivable)")
	if _car == null or _hero == null:
		_finish()
		return

	# 2. the context verb wins beside the car
	_hero.global_position = _car.global_position + Vector3(0, 0.1, 2.2)
	_check(_hero.context_action() == "ENTER",
			"beside the car the context verb is ENTER")

	# 3. boarding: occupied, hero hidden, driving, camera retargeted
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	_hero._try_grab_action()
	_check(bool(_car.get("occupied")), "boarding occupies the car")
	_check(not _hero.visible, "the hero is seated (hidden) while driving")
	_check(bool(_hero.get("driving")), "the hero reports driving state")
	if cam and cam.has_method("retarget"):
		_check(cam.get("_target") == _car,
				"the camera follows the car while driving")

	# 4. no accidental interactions from the driver's seat
	_check(_hero.context_action() == "",
			"no door or shop verbs leak through while driving")

	# 4b. roll the car onto the open street for the driving legs (the
	# parked bay is 2m from a building wall - the physics is proven,
	# the runway just needs room)
	_car.global_position = Vector3(18.0, 0.0, -2.4)
	_car.rotation.y = PI - 0.12
	await get_tree().physics_frame

	# 5. throttle: the stick's up is the pedal
	var start := _car.global_position
	_stick(Vector2.UP)
	await _physics_seconds(1.2)
	var fwd := _car.global_position - start
	_check(float(_car.get("speed")) > 3.0,
			"stick up accelerates (speed %.1f m/s)" % float(_car.get("speed")))
	_check(fwd.length() > 3.0, "the car covers ground (%.1f m)"
			% fwd.length())

	# 6. steering: authority at speed, nose follows the stick
	await _reset_car()
	var yaw0 := _car.rotation.y
	_stick(Vector2(0.6, 0.8).normalized())
	await _physics_seconds(0.6)
	var d_yaw := absf(_car.rotation.y - yaw0)
	_check(d_yaw > 0.05, "the steering turns the car (yaw %.2f)" % d_yaw)

	# 7. brake to a stop, then reverse (down becomes reverse below 0)
	await _reset_car()
	# reverse east down the open west street (from the east end the
	# nose-west car would reverse straight into BuildingF's face)
	_car.global_position = Vector3(-8.0, 0.0, -2.4)
	await get_tree().physics_frame
	_stick(Vector2.DOWN)
	await _physics_seconds(1.2)
	_check(float(_car.get("speed")) < -1.0,
			"stick down brakes then reverses (speed %.1f)" % float(_car.get("speed")))

	# 8. handbrake bites hard
	await _reset_car()
	_stick(Vector2.UP)
	await _physics_seconds(1.2)
	var sp := float(_car.get("speed"))
	_car.call("handbrake", true)
	await _physics_seconds(0.7)
	_check(float(_car.get("speed")) < sp * 0.4,
			"the handbrake sheds speed fast (%.1f -> %.1f)"
			% [sp, float(_car.get("speed"))])
	_car.call("handbrake", false)

	# 9. the horn
	_car.call("honk")
	_check(bool(_car.call("horn_active")), "the horn sounds")

	_stick(Vector2.ZERO)
	await _physics_seconds(1.0)

	# 10. traffic yields to the OCCUPIED car on the road (probe a
	# traffic car's hazard scan from behind, on its lane)
	var lane_z := -4.2
	_car.global_position = Vector3(14.0, 0.0, lane_z)
	var probe := Node3D.new()
	probe.position = Vector3(8.0, 0.0, lane_z)
	add_child(probe)
	# the traffic manager is the Traffic autoload; group "traffic"
	# holds the CARS. Probes are isolated from the seated player.
	var yields_occupied := false
	var yields_free := true
	if Traffic.has_method("_hazard_ahead"):
		yields_occupied = Traffic.call("_hazard_ahead", probe, true,
				lane_z, null)
		_car.call("request_exit")
		await get_tree().create_timer(0.3).timeout
		yields_free = Traffic.call("_hazard_ahead", probe, true,
				lane_z, null)
	_check(yields_occupied, "traffic brakes behind the occupied car")
	_check(not yields_free,
			"an exited kerb-parked car does NOT freeze the lane")

	# 11. exit: hero visible again at the kerb, beside the car
	_check(not bool(_car.get("occupied")), "X exits the car")
	_check(_hero.visible, "the hero is visible again after exiting")
	_check(bool(_hero.get("driving")) == false, "driving state clears")
	_check(_hero.global_position.distance_to(_car.global_position) < 4.0,
			"the hero steps out beside the car")

	# 12. the car persists through a save/load round trip
	_car.global_position = Vector3(-30.0, 0.0, -2.4)
	var saved := SaveGame.save_all()
	_check(saved, "the game saves with the car moved")
	_car.global_position = Vector3(9.0, 0.0, -2.4)
	SaveGame.load_all()
	await get_tree().create_timer(0.5).timeout
	_check(absf(_car.global_position.x - (-30.0)) < 0.5,
			"after load the car is where it was left (%.1f, %.1f)"
			% [_car.global_position.x, _car.global_position.z])

	_finish()


func _finish() -> void:
	await get_tree().create_timer(0.5).timeout
	print("DRIVE RESULT: %d checks, %d fails" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
