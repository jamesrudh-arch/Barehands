class_name Player
extends CharacterBody3D
## Batch-3 hero: the Universal Animation Library mannequin. The stick sets
## walking/running speed analogously; the model turns to face its travel.
## Touch buttons drive JUMP/SPRINT/PUNCH/DODGE through InputBus. Ledge
## climbing is faked with code. Combat: jab->cross with input buffering,
## dodge with i-frames (a well-timed one parries), counter-hits and
## environmental slams. Gameplay timers run on a game-time clock so the
## slow-motion parry window stretches with Engine.time_scale.

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

const GRAB_MIN := 0.45  # reachable ledge window above the feet (forgiving)
const GRAB_MAX := 2.6
const PULL_TIME := 0.55  # seconds from hang to standing on the roof

const PUNCH_REACH := 1.45  # how far a fist connects
const JAB_TIME := 0.20  # fist lands this many seconds into the jab
const CROSS_TIME := 0.24
const JAB_LOCK := 0.42  # total jab commitment before the cross can chain
const CROSS_LOCK := 0.55
const BUFFER_TIME := 0.35  # a punch pressed during a punch chains the combo
const DODGE_SPEED := 6.5
const DODGE_TIME := 0.42

enum State { GROUND, AIR, CLIMB, PUNCH, DODGE }

var state: State = State.GROUND
var _yaw := 0.0
var _since_floor := 0.0
var _air_time := 0.0
var _t := 0.0  # game-time clock (stretched by slow-mo)
var _land_until := 0.0
var _climb_t := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _hint_done := false
var _punch_stage := 0  # 1 jab, 2 cross
var _punch_t := 0.0
var _punch_hit_done := false
var _punch_buffered_at := -99.0
var _dodge_t := 0.0
var _hitstun_until := 0.0
var _counter_until := 0.0

@onready var _body: Node3D = $Body
@onready var _rig: HeroRig = $Body/Hero


func _ready() -> void:
	add_to_group("player")
	_rig._velocity_fn = func() -> Vector3: return velocity  # drives the coat sway


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		State.CLIMB:
			_climb_step(delta)
			return
		State.PUNCH:
			_punch_step(delta)
		State.DODGE:
			_dodge_step(delta)
		_:
			_move_step(delta)
	_drive_anim()


func _move_step(delta: float) -> void:
	if InputBus.locked:  # opening shot: stand and breathe
		InputBus.move = Vector2.ZERO
		InputBus.clear_queues()
	_combat_input()
	if Input.is_action_just_pressed("ui_accept"):  # desktop fallback: Space
		InputBus.queue_jump()
	var sprint := InputBus.sprint or Input.is_key_pressed(KEY_SHIFT)
	var stunned := _t < _hitstun_until

	var stick := _stick()
	var push := stick.length()
	var wish := Vector3.ZERO
	if push > 0.0:
		var fwd := Vector3(-sin(InputBus.camera_yaw), 0.0, -cos(InputBus.camera_yaw))
		var right := Vector3(cos(InputBus.camera_yaw), 0.0, -sin(InputBus.camera_yaw))
		wish = (right * stick.x + fwd * -stick.y).normalized()

	var goal := wish * lerpf(WALK_SPEED, RUN_SPEED, push) * (SPRINT_MULT if sprint else 1.0)
	if stunned:
		goal = Vector3.ZERO
	var rate := BRAKE if (push <= 0.01 or stunned) else ACCEL
	if not is_on_floor():
		rate = AIR_ACCEL
	velocity.x = move_toward(velocity.x, goal.x, rate * delta)
	velocity.z = move_toward(velocity.z, goal.z, rate * delta)

	if is_on_floor():
		_since_floor = 0.0
	else:
		_since_floor += delta
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	if InputBus.take_jump() and _since_floor <= COYOTE and not stunned:
		velocity.y = JUMP_SPEED
		_since_floor = COYOTE + 1.0  # spend the coyote window
		_rig.play("Jump_Start", 0.08)

	var was_air := not is_on_floor()
	move_and_slide()
	_face_travel(delta)
	global_position.x = clampf(global_position.x, -BOUND, BOUND)
	global_position.z = clampf(global_position.z, -BOUND, BOUND)

	if is_on_floor():
		if was_air and _air_time > 0.08:
			_rig.play("Jump_Land", 0.06)
			_rig.set_speed(1.8)
			_land_until = _t + 0.45
		_air_time = 0.0
		if state == State.GROUND or state == State.AIR:  # combat input may have taken over
			state = State.GROUND
		if not _hint_done and state == State.GROUND:
			_check_climb_hint()
	else:
		_air_time += delta
		if state == State.GROUND or state == State.AIR:
			state = State.AIR
			if _air_time > 0.04:
				_try_grab()


func _combat_input() -> void:
	if InputMap.has_action("punch") and Input.is_action_just_pressed("punch"):
		InputBus.queue_punch()
	if InputMap.has_action("dodge") and Input.is_action_just_pressed("dodge"):
		InputBus.queue_dodge()
	if InputBus.take_dodge():
		_try_dodge()
	elif InputBus.take_punch():
		_try_punch()


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


# --- combat -----------------------------------------------------------------


func _try_punch() -> void:
	if state == State.PUNCH:
		_punch_buffered_at = _t  # buffered follow-up input
	elif state == State.DODGE:
		_punch_buffered_at = _t  # buffered: fires the moment the dodge ends
	elif state == State.GROUND and _t >= _hitstun_until:
		_start_punch(1)


func _start_punch(stage: int) -> void:
	state = State.PUNCH
	_punch_stage = stage
	_punch_t = 0.0
	_punch_hit_done = false
	_punch_buffered_at = -99.0
	# Soft-lock: snap to the nearest enemy roughly in front so a swing started
	# mid-turn still lands (touch movement is not pixel-precise).
	var target := _punch_target(-0.5, 0.25)
	var lunge := 3.2 if stage == 1 else 3.8
	if target:
		var to := target.global_position - global_position
		to.y = 0.0
		_yaw = atan2(-to.x, -to.z)
		_body.rotation.y = _yaw
		if to.length() < 0.85:
			lunge = 0.0  # point-blank: no lunge, just swing
	var fwd := -_body.global_transform.basis.z
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	_rig.play("Punch_Jab" if stage == 1 else "Punch_Cross", 0.06, 1.7)


func _punch_step(delta: float) -> void:
	if InputBus.take_dodge():
		_try_dodge()  # dodge cancels a punch
		return
	if InputBus.take_punch():
		_punch_buffered_at = _t
	_gravity(delta)
	_punch_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
	if not _punch_hit_done and _punch_t >= (JAB_TIME if _punch_stage == 1 else CROSS_TIME):
		_punch_hit_done = true
		_land_punch()
	move_and_slide()  # facing stays locked for the swing (soft-locked at start)
	if state != State.PUNCH:  # dodge-cancelled mid-step
		return
	if _punch_t >= (JAB_LOCK if _punch_stage == 1 else CROSS_LOCK):
		if _punch_stage == 1 and _t - _punch_buffered_at < BUFFER_TIME:
			_start_punch(2)  # the buffered press chains the cross
		else:
			state = State.GROUND


func _try_dodge() -> void:
	if state not in [State.GROUND, State.PUNCH] or _t < _hitstun_until:
		return
	var stick := _stick()
	var dir: Vector3
	if stick != Vector2.ZERO:
		var fwd := Vector3(-sin(InputBus.camera_yaw), 0.0, -cos(InputBus.camera_yaw))
		var right := Vector3(cos(InputBus.camera_yaw), 0.0, -sin(InputBus.camera_yaw))
		dir = (right * stick.x + fwd * -stick.y).normalized()
	else:
		dir = _body.global_transform.basis.z  # no stick: hop backward
	state = State.DODGE
	_dodge_t = 0.0
	velocity.x = dir.x * DODGE_SPEED
	velocity.z = dir.z * DODGE_SPEED
	velocity.y = 0.0
	if dir.dot(-_body.global_transform.basis.z) > 0.3:
		_rig.play("Roll", 0.06, 2.1)  # a roll roughly along the facing
	else:
		_rig.play("Jump", 0.06)  # side/back evade reads as a quick hop


func _dodge_step(delta: float) -> void:
	_gravity(delta)
	_dodge_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	move_and_slide()
	if _dodge_t >= DODGE_TIME:
		state = State.GROUND
		if _t - _punch_buffered_at < BUFFER_TIME:
			_start_punch(1)  # a punch buffered during the roll fires now


## How long ago the dodge started (99 = not dodging). The enemy reads this
## at its strike moment: young = parry, older = plain evade, none = hit.
func dodge_age() -> float:
	return _dodge_t if state == State.DODGE else 99.0


## Called by a parried enemy: the next punch inside the window counters.
func open_counter(seconds: float) -> void:
	_counter_until = _t + seconds


func take_hit(dir: Vector3) -> void:
	if state == State.CLIMB:
		return
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * 4.5
	velocity.z = dir.z * 4.5
	velocity.y = 1.5
	_hitstun_until = _t + 0.45
	state = State.GROUND
	_rig.play("Hit_Chest", 0.04, 1.6)
	Fx.shake(0.4)
	Fx.emit_hit("player_hit", global_position + Vector3.UP * 1.2)


func _land_punch() -> void:
	var target := _punch_target(0.35, 0.0)
	if target == null:
		return  # whiffed: no style points for spam
	var dir: Vector3 = target.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	var hit_pos := target.global_position + Vector3.UP * (1.2 if _punch_stage == 1 else 1.55)
	var heavy := _punch_stage == 2 or _t < _counter_until
	# Environmental takedown: a heavy hit with a crate or wall right behind
	# the enemy slams them into it.
	if heavy and _slam_behind(target, dir):
		Fx.hit_stop(0.13)  # layer 1: hit-stop first
		target.take_hit(dir, "slam")  # layer 2a: flash + knockdown
		Fx.burst(hit_pos, Color(1.0, 0.55, 0.2))  # layer 2b: particles
		Fx.shake(0.9)  # layer 3: subtle shake last
		Fx.emit_hit("slam", hit_pos)
		return
	var counter: bool = _t < _counter_until and target.state == Enemy.State.STAGGER
	var kind := "counter" if counter else ("jab" if _punch_stage == 1 else "cross")
	Fx.hit_stop(0.11 if counter or kind == "cross" else 0.07)
	target.take_hit(dir, kind)
	Fx.burst(hit_pos, Color(0.3, 0.95, 1.0) if counter else Color(1.0, 0.75, 0.3))
	Fx.shake(0.2 if kind == "jab" else 0.35)
	Fx.emit_hit(kind, hit_pos)
	if _style():
		_style().add(kind)


## Nearest standing enemy within reach (+slack) and the given forward arc.
func _punch_target(min_dot: float, reach_slack: float) -> CharacterBody3D:
	var fwd := -_body.global_transform.basis.z
	var target: CharacterBody3D = null
	var best_d := PUNCH_REACH + reach_slack
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state == Enemy.State.DOWN:  # no hitting bodies on the floor
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < best_d and Vector2(fwd.x, fwd.z).dot(
				Vector2(to.x, to.z).normalized()) > min_dot:
			target = e
			best_d = to.length()
	return target


func _slam_behind(target: CharacterBody3D, dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = target.global_position + Vector3.UP * 0.9
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			from, from + dir * 1.5, 1, [get_rid(), target.get_rid()]))
	return not hit.is_empty()


func _style() -> Node:
	return get_tree().get_first_node_in_group("style")


# --- climbing ---------------------------------------------------------------


## First time the player stands near a climbable edge, show the HUD hint once.
func _check_climb_hint() -> void:
	if not _near_climbable():
		return
	_hint_done = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("Jump while moving to climb")


## A wall within ~1.4 m ahead with a flat top a jump could reach (0.9-3.6 m up).
func _near_climbable() -> bool:
	var fwd := -_body.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var exclude := [get_rid()]
	var origin := global_position + Vector3.UP * 1.15 + fwd * 0.36
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			origin, origin + fwd * 1.0, 1, exclude))
	if wall.is_empty() or wall.normal.y > 0.6:
		return false
	var n: Vector3 = wall.normal
	var wall_pos: Vector3 = wall.position
	var top: Vector3 = wall_pos - n * 0.35 + Vector3.UP * 3.75
	var ledge := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			top, top + Vector3.DOWN * 3.8, 1, exclude))
	if ledge.is_empty() or ledge.normal.y < 0.65:
		return false
	var rel: float = ledge.position.y - global_position.y
	return rel > 0.9 and rel < 3.6


## While airborne and moving into a wall, look for a flat top edge in reach.
## The pack has no climb clip, so the grab and pull-up are faked with code.
func _try_grab() -> void:
	var fwd := -_body.global_transform.basis.z
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() < 0.75:
		return
	if Vector2(fwd.x, fwd.z).dot(flat.normalized()) < 0.35:
		return
	var space := get_world_3d().direct_space_state
	var exclude := [get_rid()]
	for h: float in [0.45, 1.15]:  # knee and chest probes above the feet
		var origin: Vector3 = global_position + Vector3.UP * h + fwd * 0.36
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				origin, origin + fwd * 0.70, 1, exclude))
		if wall.is_empty():
			continue
		var n: Vector3 = wall.normal
		if n.y > 0.6 or n.dot(fwd) > -0.35:  # a ramp, or not facing it
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
	state = State.CLIMB
	velocity = Vector3.ZERO
	_air_time = 0.0
	_climb_t = 0.0
	_climb_from = Vector3(wall_pos.x + n.x * 0.42, ledge_y - 1.25, wall_pos.z + n.z * 0.42)
	var into := Vector3(-n.x, 0.0, -n.z).normalized()
	_climb_to = Vector3(wall_pos.x + into.x * 0.75, ledge_y + 0.02, wall_pos.z + into.z * 0.75)
	_yaw = atan2(-into.x, -into.z)  # face the wall while climbing
	_body.rotation.y = _yaw
	_rig.play("Jump", 0.12)  # tucked pose reads as reaching for the edge


func _climb_step(delta: float) -> void:
	_climb_t += delta / PULL_TIME
	var t := clampf(_climb_t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)  # smoothstep ease
	global_position = _climb_from.lerp(_climb_to, e)
	if _climb_t >= 1.0:
		state = State.GROUND
		velocity = -_body.global_transform.basis.z * 1.8
		_rig.play("Jump_Land", 0.06)
		_rig.set_speed(1.8)
		_land_until = _t + 0.45


# --- helpers ----------------------------------------------------------------


func _gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)


func _drive_anim() -> void:
	if state == State.CLIMB or state == State.PUNCH or state == State.DODGE:
		return  # those states own their clips
	if _t < _hitstun_until:
		return  # hit reaction plays out
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		if _rig.current() == "Jump_Start" and _rig.is_playing():
			return  # let the launch pose play out first
		_rig.play("Jump", 0.25)
	elif _t < _land_until:
		return  # brief landing recovery
	elif speed < 0.35:
		_rig.play("Idle", 0.25)
	elif speed < 3.3:
		_rig.play("Walk", 0.25)
		_rig.set_speed(clampf(speed / 2.2, 0.7, 1.7))
	else:
		_rig.play("Sprint", 0.25)
		_rig.set_speed(clampf(speed / 5.6, 0.75, 1.5))

