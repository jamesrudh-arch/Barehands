class_name Bike
extends Vehicle
## B26 WHEELS EVERYWHERE: the bicycle - the master directive's last
## vehicle class. Lighter, slower, quicker to turn than the sedan, and
## the hero rides it IN PLAIN SIGHT: no cabin to hide him, he sits the
## saddle and the pose IS the vehicle. A BELL replaces the horn (a
## bicycle's legal warning), B is the brake, and traffic yields to the
## occupied bike exactly as it yields to a person on the road.

const PEDAL_MAX := 10.2   # a city pedal ~37 km/h
const PEDAL_BACK := -2.5  # walking the bike backwards
const PEDAL_ACC := 6.5
const PEDAL_DRAG := 4.2   # bikes coast
const PEDAL_BRAKE := 12.0
const PEDAL_HAND := 13.0  # both levers, the B button
const BARS_TURN := 2.6    # nimble at the bars
const WHEEL_R := 0.34

var _model: Node3D = null
var _bell_player: AudioStreamPlayer3D = null

const BELL := preload("res://assets/audio/bell_heavy_0.ogg")


func _ready() -> void:
	# Vehicle._ready owns the group registration, the wheel scan and
	# the horn player contract; the bike hangs its own bell beside it
	super()
	# the drive cluster's A/B say BELL / BRAKE on a bicycle (the base
	# vars live on Vehicle - one cluster, every vehicle's own voice)
	hud_a = "BELL"
	hud_b = "BRAKE"
	_model = get_node_or_null("Model")
	_bell_player = AudioStreamPlayer3D.new()
	_bell_player.stream = BELL
	_bell_player.bus = "SFX"
	_bell_player.unit_size = 8.0
	_bell_player.volume_db = -6.0
	add_child(_bell_player)


## The hero mounts and stays VISIBLE - the whole difference from the
## car: the bicycle has no cabin, so the rider's pose is the vehicle's
## body. Collision still stands down; the bike is his collider.
func try_enter(hero: CharacterBody3D) -> bool:
	if occupied or hero == null:
		return false
	occupied = true
	_hero = hero
	speed = 0.0
	if hero.has_method("set_driving"):
		hero.call("set_driving", true)
	if hero is CollisionObject3D:
		(hero as CollisionObject3D).set_deferred("collision_layer", 0)
	_attach_hero()
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", self)
	Log.info("Bike: the hero mounts (in plain sight, speed 0)")
	return true


## Step off at the kerb side; the bike stays upright where it stopped.
func try_exit() -> void:
	if not occupied or _hero == null:
		return
	occupied = false
	var side := transform.basis.z
	_hero.global_position = global_position + side * 1.1 + Vector3.UP * 0.55
	if _hero is CollisionObject3D:
		(_hero as CollisionObject3D).set_deferred("collision_layer", 1)
	if _hero.has_method("set_driving"):
		_hero.call("set_driving", false)
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", _hero)
	speed = 0.0
	Log.info("Bike: the hero steps off (the bike stays put)")
	_hero = null


## A BELL is the bicycle's legal warning - no horn wire on a frame.
## Rings twice, the way a bell actually answers.
func honk() -> void:
	if _horn_on:
		return
	_horn_on = true
	emit_signal("horn", true)
	if _bell_player:
		_bell_player.play()
		_ring_again()
	Log.info("Bike: BELL")


func _ring_again() -> void:
	await get_tree().create_timer(0.3).timeout
	if _bell_player and occupied:
		_bell_player.play()


func _physics_process(delta: float) -> void:
	_ensure_scan()
	if not occupied:
		speed = 0.0
		return
	if _exit_want:
		_exit_want = false
		try_exit()
		return
	# the stick stays the walking metaphor: up = pedal, down = brake
	# then walk it back
	var stick := InputBus.move
	if stick == Vector2.ZERO:
		stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var throttle := -stick.y
	if throttle > 0.08:
		speed = move_toward(speed, PEDAL_MAX * clampf(throttle, 0.0, 1.0),
				PEDAL_ACC * delta)
	elif throttle < -0.08:
		var decel := PEDAL_BRAKE if speed > 0.05 else PEDAL_ACC * 0.5
		speed = move_toward(speed, PEDAL_BACK, decel * delta)
	else:
		speed = move_toward(speed, 0.0, PEDAL_DRAG * delta)
	if _hb:
		speed = move_toward(speed, 0.0, PEDAL_HAND * delta)
	# a bicycle turns with far less speed than a car needs
	var authority := clampf(absf(speed) / 4.0, 0.0, 1.0) * BARS_TURN
	_steer = stick.x
	rotate_y(-_steer * authority * delta * sign(speed))
	velocity = transform.basis.x * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	# walls bleed speed, the floor never does - same law as the car
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.5:
			speed *= 0.55
			break
	# B26 (the wheel-axis probe): the spin rides the PARENT X - the
	# true axle - so the wheels visibly roll under the rider
	for w in _wheels:
		w.rotate(Vector3(1, 0, 0), (speed / WHEEL_R) * delta)
	_attach_hero()
	_lean(delta)
	if _horn_on and absf(speed) > 0.5:
		_horn_on = false
		emit_signal("horn", false)


## The rider rides: seated on the saddle, face down the street, body
## carried by the bike every frame (his own controller stands down).
func _attach_hero() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	_hero.global_position = global_position + transform.basis.x * -0.06 \
			+ Vector3.UP * 0.56
	if _hero.has_method("set_body_yaw"):
		_hero.call("set_body_yaw", rotation.y - PI / 2.0)
	_hero.velocity = Vector3.ZERO


## The frame leans into the turn - the bike's whole body language.
func _lean(delta: float) -> void:
	if _model == null:
		return
	var target := _steer * clampf(absf(speed) / PEDAL_MAX, 0.0, 1.0) * 0.24
	_model.rotation.z = lerpf(_model.rotation.z, target,
			clampf(delta * 8.0, 0.0, 1.0))
