extends CharacterBody3D
## Batch-2 hero: the Universal Animation Library mannequin. The stick sets
## walking/running speed analogously; the model turns to face its travel.
## JUMP/SPRINT come in through InputBus (touch buttons). Ledge climbing is
## faked with code: jump into a climbable edge to grab it and pull up.

const WALK_SPEED := 1.8  # m/s at a gentle push of the stick
const RUN_SPEED := 5.2  # m/s with the stick fully out
const SPRINT_MULT := 1.35  # on top of a full push while SPRINT is held
const ACCEL := 11.0
const BRAKE := 15.0
const AIR_ACCEL := 6.0
const GRAVITY := 22.0
const JUMP_SPEED := 7.6  # ~1.25 m apex
const COYOTE := 0.12  # grace to still jump after walking off an edge
const TURN_SPEED := 12.0
const DEADZONE := 0.15
const BOUND := 18.5  # keeps the hero on the street block

const GRAB_MIN := 0.55  # reachable ledge window above the feet
const GRAB_MAX := 2.4
const PULL_TIME := 0.55  # seconds from hang to standing on the roof

enum { GROUND, AIR, CLIMB }

var state := GROUND
var _yaw := 0.0
var _since_floor := 0.0
var _air_time := 0.0
var _land_until := 0.0
var _climb_t := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO

@onready var _body: Node3D = $Body
@onready var _anim: AnimationPlayer = $Body/Mannequin/AnimationPlayer


func _physics_process(delta: float) -> void:
	match state:
		CLIMB:
			_climb_step(delta)
		_:
			_move_step(delta)


func _move_step(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):  # desktop fallback: Space
		InputBus.queue_jump()
	var sprint := InputBus.sprint or Input.is_key_pressed(KEY_SHIFT)

	var stick := _stick()
	var push := stick.length()
	var wish := Vector3.ZERO
	if push > 0.0:
		var fwd := Vector3(-sin(InputBus.camera_yaw), 0.0, -cos(InputBus.camera_yaw))
		var right := Vector3(cos(InputBus.camera_yaw), 0.0, -sin(InputBus.camera_yaw))
		wish = (right * stick.x + fwd * -stick.y).normalized()

	var goal := wish * lerpf(WALK_SPEED, RUN_SPEED, push) * (SPRINT_MULT if sprint else 1.0)
	var rate := ACCEL if push > 0.01 else BRAKE
	if not is_on_floor():
		rate = AIR_ACCEL
	velocity.x = move_toward(velocity.x, goal.x, rate * delta)
	velocity.z = move_toward(velocity.z, goal.z, rate * delta)

	if is_on_floor():
		_since_floor = 0.0
	else:
		_since_floor += delta
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	if InputBus.take_jump() and _since_floor <= COYOTE:
		velocity.y = JUMP_SPEED
		_since_floor = COYOTE + 1.0  # spend the coyote window
		_play("Jump_Start", 0.08)

	var was_air := not is_on_floor()
	move_and_slide()
	_face_travel(delta)
	global_position.x = clampf(global_position.x, -BOUND, BOUND)
	global_position.z = clampf(global_position.z, -BOUND, BOUND)

	if is_on_floor():
		if was_air and _air_time > 0.08:
			_play("Jump_Land", 0.06)
			_anim.speed_scale = 1.8
			_land_until = _now() + 0.45
		_air_time = 0.0
		state = GROUND
	else:
		_air_time += delta
		state = AIR
		if _air_time > 0.06:
			_try_grab()
	_drive_anim()


## The raw stick plus keyboard fallback, with the dead zone remapped to 0..1.
func _stick() -> Vector2:
	var v := InputBus.move
	if v == Vector2.ZERO:
		v = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var m := v.length()
	if m <= DEADZONE:
		return Vector2.ZERO
	return v / m * clampf(remap(m, DEADZONE, 1.0, 0.0, 1.0), 0.0, 1.0)


func _face_travel(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length_squared() > 0.3:
		_yaw = rotate_toward(_yaw, atan2(-flat.x, -flat.y), TURN_SPEED * delta)
		_body.rotation.y = _yaw


## While airborne and moving into a wall, look for a flat top edge in reach.
## The pack has no climb clip, so the grab and pull-up are faked with code.
func _try_grab() -> void:
	var fwd := -_body.global_transform.basis.z
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() < 1.0:
		return
	if Vector2(fwd.x, fwd.z).dot(flat.normalized()) < 0.5:
		return
	var space := get_world_3d().direct_space_state
	var exclude := [get_rid()]
	for h: float in [0.45, 1.15]:  # knee and chest probes above the feet
		var origin: Vector3 = global_position + Vector3.UP * h + fwd * 0.28
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				origin, origin + fwd * 0.55, 1, exclude))
		if wall.is_empty():
			continue
		var n: Vector3 = wall.normal
		if n.y > 0.6 or n.dot(fwd) > -0.5:  # a ramp, or not facing it
			continue
		var wall_pos: Vector3 = wall.position
		var top: Vector3 = wall_pos - n * 0.35 + Vector3.UP * (GRAB_MAX + 0.15)
		var ledge := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				top, top + Vector3.DOWN * (GRAB_MAX + 0.9), 1, exclude))
		if ledge.is_empty() or ledge.normal.y < 0.65:
			continue
		var ledge_y: float = ledge.position.y
		var rel: float = ledge_y - global_position.y
		if rel < GRAB_MIN or rel > GRAB_MAX:
			continue
		var head := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				ledge.position + Vector3.UP * 0.15,
				ledge.position + Vector3.UP * 1.9, 1, exclude))
		if not head.is_empty():  # no room to stand up there
			continue
		_start_climb(wall_pos, n, ledge_y)
		return


func _start_climb(wall_pos: Vector3, n: Vector3, ledge_y: float) -> void:
	state = CLIMB
	velocity = Vector3.ZERO
	_air_time = 0.0
	_climb_t = 0.0
	_climb_from = Vector3(wall_pos.x + n.x * 0.42, ledge_y - 1.25, wall_pos.z + n.z * 0.42)
	var into := Vector3(-n.x, 0.0, -n.z).normalized()
	_climb_to = Vector3(wall_pos.x + into.x * 0.75, ledge_y + 0.02, wall_pos.z + into.z * 0.75)
	_yaw = atan2(-into.x, -into.z)  # face the wall while climbing
	_body.rotation.y = _yaw
	_play("Jump", 0.12)  # tucked pose reads as reaching for the edge


func _climb_step(delta: float) -> void:
	_climb_t += delta / PULL_TIME
	var t := clampf(_climb_t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)  # smoothstep ease
	global_position = _climb_from.lerp(_climb_to, e)
	if _climb_t >= 1.0:
		state = GROUND
		velocity = -_body.global_transform.basis.z * 1.8
		_play("Jump_Land", 0.06)
		_anim.speed_scale = 1.8
		_land_until = _now() + 0.45


func _drive_anim() -> void:
	if state == CLIMB:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		if _anim.current_animation == "Jump_Start" and _anim.is_playing():
			return  # let the launch pose play out first
		_play("Jump", 0.25)
	elif _now() < _land_until:
		return  # brief landing recovery
	elif speed < 0.35:
		_play("Idle", 0.25)
	elif speed < 3.3:
		_play("Walk", 0.25)
		_anim.speed_scale = clampf(speed / 2.2, 0.7, 1.7)
	else:
		_play("Sprint", 0.25)
		_anim.speed_scale = clampf(speed / 5.6, 0.75, 1.5)


func _play(anim_name: String, blend: float = 0.25) -> void:
	if _anim.current_animation != anim_name:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, blend)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
