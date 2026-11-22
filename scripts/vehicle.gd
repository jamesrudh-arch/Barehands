class_name Vehicle
extends CharacterBody3D
## B25 THE DRIVER: the drivable car (the master directive Section 5 -
## "vehicles must be actual usable game objects, not decorative
## models"). Arcade handling tuned for touch: the stick steers and
## throttles (up = drive, down = brake/reverse, exactly the walking
## metaphor), the drive HUD gives B HANDBRAKE / A HORN / X EXIT.
## The car's long axis is +x (the nose), matching the parked sedan's
## built shape; traffic yields to it while it is occupied, exactly as
## it yields to a person on the road.

signal horn(on: bool)

const MAX_F := 17.0      # cruise ~61 km/h
const MAX_R := -5.5
const ACC := 9.0
const BRAKE := 15.0
const DRAG := 3.4
const HAND := 22.0      # handbrake decel
const TURN := 1.85       # steering authority, rad/s at full effect

var speed := 0.0
var occupied := false
var _hero: CharacterBody3D = null
var _hb := false
var _steer := 0.0
var _horn_on := false
var _exit_want := false
var _wheels: Array[Node3D] = []
var _brake_lights: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("vehicle")
	for c in find_children("*", "MeshInstance3D", true, false):
		if "wheel" in (c as Node).name.to_lower():
			_wheels.append(c as Node3D)
		elif "tail" in (c as Node).name.to_lower():
			_brake_lights.append(c as MeshInstance3D)
	# a stopped car is still a solid body: CharacterBody3D bodies do
	# not push each other, so the sedan never gets shoved around


## The hero boards. Answers false when already occupied.
func try_enter(hero: CharacterBody3D) -> bool:
	if occupied or hero == null:
		return false
	occupied = true
	_hero = hero
	speed = 0.0
	if hero.has_method("set_driving"):
		hero.call("set_driving", true)
	# park the hero's body inside the cabin: hidden, collision off,
	# parked - the car IS the hero's collider while driving
	hero.global_position = global_position + transform.basis.x * -0.25 \
			+ Vector3.UP * 0.55
	hero.visible = false
	if hero is CollisionObject3D:
		(hero as CollisionObject3D).set_deferred(
				"collision_layer", 0)
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", self)
	Log.info("Vehicle: the hero takes the wheel (speed 0)")
	return true


## The hero steps out at the kerb side; the car stays where it is
## parked and becomes part of the world again (traffic yields to it
## only while occupied - a kerb-parked car must not freeze the lane).
func try_exit() -> void:
	if not occupied or _hero == null:
		return
	occupied = false
	var side := transform.basis.z
	var try_pos := global_position + side * 1.7 + Vector3.UP * 0.55
	_hero.global_position = try_pos
	_hero.visible = true
	if _hero is CollisionObject3D:
		(_hero as CollisionObject3D).set_deferred(
				"collision_layer", 1)
	if _hero.has_method("set_driving"):
		_hero.call("set_driving", false)
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", _hero)
	speed = 0.0
	Log.info("Vehicle: the hero steps out (the car stays parked)")
	_hero = null


func handbrake(down: bool) -> void:
	_hb = down


func honk() -> void:
	# a horn is a legal requirement and a warning: two short bursts,
	# routed through the same audio hook the city sounds use
	_horn_on = true
	emit_signal("horn", true)
	Log.info("Vehicle: HONK")


func horn_active() -> bool:
	return _horn_on


func request_exit() -> void:
	_exit_want = true


func _physics_process(delta: float) -> void:
	if not occupied:
		speed = 0.0
		_set_brake_lights(true)
		return
	if _exit_want:
		_exit_want = false
		try_exit()
		return
	# the stick: up = drive, down = brake then reverse - the same
	# mental model as walking, so the thumb never relearns
	var stick := InputBus.move
	if stick == Vector2.ZERO:
		stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var throttle := -stick.y
	if throttle > 0.08:
		speed = move_toward(speed, MAX_F * clampf(throttle, 0.0, 1.0), ACC * delta)
	elif throttle < -0.08:
		var decel := BRAKE if speed > 0.05 else ACC * 0.7
		speed = move_toward(speed, MAX_R, decel * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	if _hb:
		speed = move_toward(speed, 0.0, HAND * delta)
	# steering: authority ramps with speed (no turning a parked car,
	# no twitch at full tilt) and flips in reverse like a real car
	var authority := clampf(absf(speed) / 6.0, 0.0, 1.0) * TURN
	_steer = stick.x
	rotate_y(-_steer * authority * delta * sign(speed))
	velocity = transform.basis.x * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var braking := speed > 0.05 and (throttle < -0.08 or _hb)
	_set_brake_lights(braking or speed == 0.0)
	move_and_slide()
	# walls are solid at speed: bleed it, but never full-stop on a
	# scrape (the hero keeps the fun, the city keeps its walls).
	# The FLOOR is not a wall - resting contact must not bleed speed.
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.5:
			speed *= 0.55
			break
	# rolling wheels + the engine hum follow the actual speed
	for w in _wheels:
		w.rotate_x((speed / 0.32) * delta)
	if _horn_on and speed > 0.5:
		_horn_on = false
		emit_signal("horn", false)


func _set_brake_lights(on: bool) -> void:
	for m in _brake_lights:
		var mat := m.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.08, 0.08) * (1.6 if on else 0.35)
