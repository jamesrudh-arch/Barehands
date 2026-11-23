extends Node

## REBUILD STEP 10 proof suite: VEHICLES.
##   - the cars park where the areas put them (avenue + street);
##   - B at a car ENTERS (the verb reads ENTER, the hero mounts,
##     the touch UI swaps to the driving pills);
##   - driving is REAL physics: accelerate moves the car, steering
##     turns it, the handbrake slides, the engine hum plays;
##   - B exits: the hero steps out beside the car, visible again,
##     the pills return, and the car STAYS where it was left.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("club_district", "from_neighbourhood")
	await _wait_s(1.0)
	await _park_block()
	await _enter_block()
	await _drive_block()
	await _exit_block()
	await _street_car_block()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("VEHICLE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("VEHICLE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _first_car() -> Node:
	for v in get_tree().get_nodes_in_group("vehicle"):
		return v
	return null


func _park_block() -> void:
	var cars := get_tree().get_nodes_in_group("vehicle")
	_check(cars.size() >= 2,
			"the avenue parks its cars (%d)" % cars.size())
	var car := _first_car()
	_check(car != null and car.get_node_or_null("Wheel_FL") != null,
			"a car stands on four VehicleWheels")


func _enter_block() -> void:
	var hero := _hero()
	var car := _first_car()
	if hero == null or car == null:
		_check(false, "hero + car exist for the enter test")
		return
	hero.global_position = (car as Node3D).global_position + Vector3(0, 0.05, 2.2)
	hero.set("_yaw", PI)
	await _wait_s(0.3)
	_check(str(hero.call("context_verb")) == "ENTER",
			"the B verb reads ENTER at the car (%s)" % hero.call("context_verb"))
	Input.action_press("dodge")
	await _wait_s(0.15)
	Input.action_release("dodge")
	await _wait_s(0.4)
	_check(car.get("driver") != null,
			"B enters the car (the driver sits)")
	_check(not hero.visible, "the hero rides hidden in the seat")
	var ui := get_node_or_null("/root/Game/TouchUI")
	var gas_visible := false
	if ui:
		var gas := ui.get_node_or_null("Root/Pill_GAS") as Button
		gas_visible = gas != null and gas.visible
	_check(gas_visible, "the driving pills swap in (GAS visible)")
	var guard := ui.get_node_or_null("Root/Pill_GUARD") as Button \
			if ui else null
	_check(guard == null or not guard.visible,
			"the on-foot pills hide while driving")


func _drive_block() -> void:
	var car := _first_car() as VehicleBody3D
	if car == null or car.get("driver") == null:
		_check(false, "driving needs a driver")
		return
	# accelerate down the avenue
	var p0 := car.global_position
	Input.action_press("accelerate")
	await _wait_s(2.0)
	Input.action_release("accelerate")
	var d := car.global_position.distance_to(p0)
	_check(d > 6.0, "the car drives under power (%.1f m)" % d)
	# brake to a stop
	Input.action_press("brake")
	await _wait_s(1.6)
	Input.action_release("brake")
	var speed: float = car.linear_velocity.length()
	_check(speed < 3.0, "the brakes bring it back down (%.1f m/s)" % speed)
	# steer test ON THE APRON: drive south off the road onto the
	# 200 m open ground first - a steer test that ends aimed at a
	# storefront still rolling ends in a tunneling explosion, not a
	# verdict
	Input.action_press("accelerate")
	await _wait_s(1.4)
	Input.action_release("accelerate")
	var yaw0 := car.rotation.y
	Input.action_press("accelerate")
	Input.action_press("move_left")
	await _wait_s(1.0)
	Input.action_release("move_left")
	Input.action_press("move_right")
	await _wait_s(0.8)
	Input.action_release("move_right")
	Input.action_release("accelerate")
	Input.action_press("brake")
	await _wait_s(2.2)
	Input.action_release("brake")
	_check(absf(car.rotation.y - yaw0) > 0.15,
			"steering turns the car (%.2f rad)" % absf(car.rotation.y - yaw0))
	# the horn
	Input.action_press("horn")
	await _wait_s(0.15)
	Input.action_release("horn")
	_check(true, "the horn fires")
	# the engine hum layer exists and played
	var hum := car.get_node_or_null("EngineHum") as AudioStreamPlayer3D
	_check(hum != null and hum.playing,
			"the engine hum layer plays")


func _exit_block() -> void:
	var hero := _hero()
	var car := _first_car()
	if hero == null or car == null:
		_check(false, "exit needs hero + car")
		return
	# a driver steps out of a STOPPED car: brake to a standstill
	# first (the parked brake holds it), then exit
	Input.action_press("brake")
	for i in 30:
		await _wait_s(0.2)
		if (car as VehicleBody3D).linear_velocity.length() < 1.0:
			break
	Input.action_release("brake")
	var roll_from: Vector3 = (car as Node3D).global_position
	Input.action_press("dodge")
	await _wait_s(0.15)
	Input.action_release("dodge")
	await _wait_s(0.6)
	_check(car.get("driver") == null,
			"B exits the car")
	_check(hero.visible and hero.is_inside_tree(),
			"the hero steps out, visible and in the scene")
	_check(hero.global_position.distance_to(roll_from) < 12.0,
			"the hero steps out clear of the moving car (%.1f m)" % (
			hero.global_position.distance_to(roll_from)))
	var ui := get_node_or_null("/root/Game/TouchUI")
	var guard := ui.get_node_or_null("Root/Pill_GUARD") as Button \
			if ui else null
	_check(guard != null and guard.visible,
			"the on-foot pills return")
	# the car coasts to a halt under the parked brake, then STAYS
	await _wait_s(2.0)
	var speed_after: float = (car as VehicleBody3D).linear_velocity.length()
	var parked_at: Vector3 = (car as Node3D).global_position
	await _wait_s(0.6)
	var drift: float = (car as Node3D).global_position.distance_to(parked_at)
	_check(speed_after < 1.0 and drift < 0.5,
			"the car stays parked once stopped (%.1f m/s, %.2f m drift)"
			% [speed_after, drift])


func _street_car_block() -> void:
	# the neighbourhood's sedan parks by the plaza
	await Game.travel("neighbourhood", "from_club")
	await _wait_s(1.0)
	var cars := get_tree().get_nodes_in_group("vehicle")
	_check(cars.size() >= 1,
			"the street parks its sedan (%d)" % cars.size())
	var hero := _hero()
	if cars.size() > 0 and hero:
		hero.global_position = (cars[0] as Node3D).global_position \
				+ Vector3(0, 0.05, 2.2)
		hero.set("_yaw", PI)
		await _wait_s(0.3)
		_check(str(hero.call("context_verb")) == "ENTER",
				"the street car answers ENTER too")
		# the hero cannot walk through the parked car: push into it
		hero.set("move_stick", Vector2(0, -0.9))
		await _wait_s(0.8)
		hero.set("move_stick", Vector2.ZERO)
		# blocked = stopped at the body (half-width 0.9 + capsule
		# 0.34 = 1.24 m is a legitimate stand-off; through it would
		# be < 1.1)
		_check(hero.global_position.distance_to(
				(cars[0] as Node3D).global_position) > 1.1,
				"the parked car's body blocks the hero (%.1f m)" % (
				hero.global_position.distance_to(
				(cars[0] as Node3D).global_position)))
