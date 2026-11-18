class_name Player
extends CharacterBody3D
## The Series-2 hero. Movement and ledge-climbing as before; combat is now a
## small tree: tap PUNCH for the light chain (jab -> cross -> hook), HOLD
## PUNCH for a heavy swing - on a staggered enemy the heavy launches, on a
## nearly-done enemy it executes a cinematic finisher. Tap DODGE to evade,
## HOLD DODGE to block (a block in its first 0.15 s parries). GRAB seizes an
## enemy (PUNCH = knee, DODGE/GRAB = throw into whatever is behind them),
## or picks up the steel pipe, which has its own slower, heavier move set.
## Gameplay timers run on a game-time clock so slow motion stretches them.

const WALK_SPEED := 1.8
const RUN_SPEED := 5.2
const SPRINT_MULT := 1.35
const ACCEL := 11.0
const BRAKE := 15.0
const AIR_ACCEL := 6.0
const GRAVITY := 22.0
const JUMP_SPEED := 7.6
const COYOTE := 0.12
const TURN_SPEED := 12.0
const DEADZONE := 0.15
const BOUND := 18.5

const GRAB_MIN := 0.45
const GRAB_MAX := 2.6
const PULL_TIME := 0.55

const PUNCH_REACH := 1.45
const JAB_TIME := 0.20
const CROSS_TIME := 0.24
const HOOK_TIME := 0.24
const HEAVY_TIME := 0.34
const JAB_LOCK := 0.42
const CROSS_LOCK := 0.55
const HOOK_LOCK := 0.60
const HEAVY_LOCK := 0.75
const BUFFER_TIME := 0.35
const DODGE_SPEED := 6.5
const DODGE_TIME := 0.42
const BLOCK_PARRY_WINDOW := 0.15  # a block this young parries
const GRAB_TIME := 1.2  # how long a seize holds before auto-release

enum State { GROUND, AIR, CLIMB, PUNCH, DODGE, BLOCK, GRAB }

var state: State = State.GROUND
var has_pipe := false
var _yaw := 0.0
var _since_floor := 0.0
var _air_time := 0.0
var _t := 0.0  # game-time clock (stretched by slow-mo)
var _land_until := 0.0
var _climb_t := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _hint_done := false
var _punch_stage := 0  # 1 jab, 2 cross, 3 hook
var _punch_heavy := false
var _punch_t := 0.0
var _punch_hit_done := false
var _punch_buffered_at := -99.0
var _dodge_t := 0.0
var _block_t := 0.0  # age of the current block
var _hitstun_until := 0.0
var _counter_until := 0.0
var _step_acc := 0.0
var _grab_t := 0.0
var _grabbed_enemy: CharacterBody3D = null
var _pipe_prop: Node3D = null

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
		State.BLOCK:
			_block_step(delta)
		State.GRAB:
			_grab_step(delta)
		_:
			_move_step(delta)
	_drive_anim()


func _move_step(delta: float) -> void:
	if InputBus.locked:  # cutscene: stand and breathe
		InputBus.move = Vector2.ZERO
		InputBus.clear_queues()
	_combat_input()
	if Input.is_action_just_pressed("ui_accept"):  # desktop fallback: Space
		InputBus.queue_jump()
	if InputMap.has_action("punch") and Input.is_action_just_pressed("punch"):
		InputBus.punch_press()
	if InputMap.has_action("punch") and Input.is_action_just_released("punch"):
		InputBus.punch_release()
	if InputMap.has_action("dodge") and Input.is_action_just_pressed("dodge"):
		InputBus.dodge_press()
	if InputMap.has_action("dodge") and Input.is_action_just_released("dodge"):
		InputBus.dodge_release()
	if InputMap.has_action("grab") and Input.is_action_just_pressed("grab"):
		InputBus.queue_grab()
	var sprint := InputBus.sprint or Input.is_key_pressed(KEY_SHIFT)
	var stunned := _t < _hitstun_until

	var stick := _stick()
	var push := stick.length()
	var wish := Vector3.ZERO
	if push > 0.0:
		var fwd := Vector3(-sin(InputBus.camera_yaw), 0.0, -cos(InputBus.camera_yaw))
		var right := Vector3(cos(InputBus.camera_yaw), 0.0, -sin(InputBus.camera_yaw))
		wish = (right * stick.x + fwd * -stick.y).normalized()

	var weight := 0.92 if has_pipe else 1.0  # the pipe is heavy
	var goal := wish * lerpf(WALK_SPEED, RUN_SPEED, push) * (SPRINT_MULT if sprint else 1.0) * weight
	if stunned:
		goal = Vector3.ZERO
	var rate := BRAKE if (push <= 0.01 or stunned) else ACCEL
	if not is_on_floor():
		rate = AIR_ACCEL
	velocity.x = move_toward(velocity.x, goal.x, rate * delta)
	velocity.z = move_toward(velocity.z, goal.z, rate * delta)

	# footsteps: distance-driven, surface-aware (Sound picks the clip)
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.6:
		_step_acc += Vector2(velocity.x, velocity.z).length() * delta
		if _step_acc > 0.58:
			_step_acc = 0.0
			Sound.step(Sound.surface_at(global_position))

	if is_on_floor():
		_since_floor = 0.0
	else:
		_since_floor += delta
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	if InputBus.take_jump() and _since_floor <= COYOTE and not stunned:
		velocity.y = JUMP_SPEED
		_since_floor = COYOTE + 1.0
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
		if state == State.GROUND or state == State.AIR:
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
	# hold-PUNCH becomes a heavy after 0.30 s; the press is consumed so the
	# release never also fires a light
	if InputBus.punch_held and InputBus.punch_age() >= 0.30 and \
			state in [State.GROUND, State.PUNCH] and _t >= _hitstun_until:
		if state == State.PUNCH:
			_punch_buffered_at = _t
			_punch_heavy = true  # the buffered follow-up is a heavy
			InputBus.consume_punch_hold()
		else:
			InputBus.consume_punch_hold()
			_start_punch(3, true)
	# hold-DODGE becomes a block after 0.25 s
	if InputBus.dodge_held and InputBus.dodge_age() >= 0.25 and \
			state == State.GROUND and _t >= _hitstun_until:
		_enter_block()
	if InputBus.take_dodge():
		_try_dodge()
	elif InputBus.take_punch():
		_try_punch()
	elif InputBus.take_grab():
		_try_grab_action()


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


# --- the punch tree ------------------------------------------------------------


func _try_punch() -> void:
	if state == State.GRAB:  # a knee while holding someone
		_grab_knee()
	elif state == State.PUNCH:
		_punch_buffered_at = _t
	elif state == State.DODGE:
		_punch_buffered_at = _t
	elif state == State.BLOCK:
		pass  # guarding: no punches come out
	elif state == State.GROUND and _t >= _hitstun_until:
		_start_punch(1, false)


func _start_punch(stage: int, heavy: bool) -> void:
	if state == State.GRAB:
		_grab_knee()
		return
	state = State.PUNCH
	_punch_stage = stage
	_punch_heavy = heavy
	_punch_t = 0.0
	_punch_hit_done = false
	_punch_buffered_at = -99.0
	# a heavy always starts its own swing; a light chains from where it is
	if heavy:
		_punch_stage = 3 if not has_pipe else 3
	# Soft-lock: snap to the nearest enemy roughly in front.
	var target := _punch_target(-0.5, 0.25)
	var lunge := 3.2 if stage == 1 else 3.8
	if heavy:
		lunge = 4.2
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
	var speed := 1.7
	if has_pipe:
		speed = 0.85 if not heavy else 0.6  # the pipe swings slower
	elif heavy:
		speed = 0.75
	_rig.play("Punch_Jab" if stage == 1 else "Punch_Cross", 0.06, speed)


func _punch_step(delta: float) -> void:
	if InputBus.take_dodge():
		_try_dodge()  # dodge cancels a swing
		return
	if InputBus.take_punch():
		_punch_buffered_at = _t
	_gravity(delta)
	_punch_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
	if not _punch_hit_done and _punch_t >= _impact_time():
		_punch_hit_done = true
		_land_punch()
	move_and_slide()
	if state != State.PUNCH:
		return
	if _punch_t >= _lock_time():
		if not _punch_heavy and _punch_stage < 3 and _t - _punch_buffered_at < BUFFER_TIME:
			_start_punch(_punch_stage + 1, false)  # the light chain
		else:
			state = State.GROUND


func _impact_time() -> float:
	if _punch_heavy:
		return HEAVY_TIME * (1.25 if has_pipe else 1.0)
	match _punch_stage:
		1:
			return JAB_TIME
		2:
			return CROSS_TIME
		_:
			return HOOK_TIME


func _lock_time() -> float:
	if _punch_heavy:
		return HEAVY_LOCK * (1.2 if has_pipe else 1.0)
	match _punch_stage:
		1:
			return JAB_LOCK
		2:
			return CROSS_LOCK
		_:
			return HOOK_LOCK


func _land_punch() -> void:
	var target := _punch_target(0.35, 0.0)
	if target == null:
		return  # whiffed: no style for spam
	var dir: Vector3 = target.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	var counter: bool = _t < _counter_until and target.state == Enemy.State.STAGGER
	var kind := _swing_kind(target, counter)
	var hit_pos := target.global_position + Vector3.UP * (1.2 if _punch_stage == 1 else 1.55)

	# launcher: a heavy on a staggered enemy sends them up
	if kind == "launcher":
		Fx.hit_stop(0.12)
		target.take_hit(dir, kind)
		Fx.burst(hit_pos, Color(0.5, 0.85, 1.0))
		Fx.shake(0.5)
		Fx.camera_punch(5.0)
		Fx.haptic(80)
		Fx.emit_hit("launcher", hit_pos)
		_style_add("launcher")
		return
	# finisher: a heavy on a nearly-done enemy executes
	if kind == "finisher":
		Fx.slow_mo(0.5, 0.3)
		Fx.hit_stop(0.16)
		target.take_hit(dir, kind)
		Fx.burst(hit_pos + Vector3.UP * 0.3, Color(1.0, 0.3, 0.25))
		Fx.shake(0.8)
		Fx.camera_punch(-7.0)  # punch IN
		Fx.haptic(160)
		Fx.emit_hit("finisher", hit_pos)
		_style_add("finisher")
		return
	# environmental takedown: a heavy/cross with something solid behind them
	if kind == "cross" or kind == "counter" or kind == "heavy" or kind == "pipe_heavy":
		var surface := _surface_behind(target, dir)
		if surface != "":
			_env_takedown(target, dir, surface, hit_pos)
			return
	var dmg := _swing_damage(kind)
	Fx.hit_stop(0.11 if counter or kind in ["cross", "heavy", "pipe_heavy"] else 0.07)
	target.take_hit(dir, kind)
	Fx.burst(hit_pos, Color(0.3, 0.95, 1.0) if counter else
			(Color(0.75, 0.8, 0.9) if kind.begins_with("pipe") else Color(1.0, 0.75, 0.3)))
	Fx.shake(0.2 if kind == "jab" else 0.35)
	Fx.camera_punch(1.5 if kind == "jab" else (4.0 if counter else 3.0))
	if kind in ["heavy", "pipe_heavy"]:
		Fx.haptic(60)
		Fx.camera_punch(5.0)
	Fx.emit_hit(kind, hit_pos)
	_style_add(kind)


## What this swing is, given the target's condition.
func _swing_kind(target: CharacterBody3D, counter: bool) -> String:
	if counter:
		return "counter"
	if _punch_heavy:
		if has_pipe:
			return "pipe_heavy"
		if target.hp <= 2 and target.state != Enemy.State.DOWN:
			return "finisher"
		if target.state == Enemy.State.STAGGER or target.state == Enemy.State.FLINCH:
			return "launcher"
		return "heavy"
	if has_pipe:
		return "pipe"
	match _punch_stage:
		1:
			return "jab"
		2:
			return "cross"
		_:
			return "hook"


func _swing_damage(kind: String) -> int:
	return {"jab": 1, "cross": 2, "hook": 2, "heavy": 3, "counter": 99,
			"pipe": 2, "pipe_heavy": 4, "launcher": 1, "knee": 1}.get(kind, 1)


# --- environmental takedowns ----------------------------------------------------


## What slam-able thing is behind the target: a tagged prop (car, shutter,
## rail) or a plain wall.
func _surface_behind(target: CharacterBody3D, dir: Vector3) -> String:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = target.global_position + Vector3.UP * 0.9
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			from, from + dir * 1.6, 1, [get_rid(), target.get_rid()]))
	if hit.is_empty():
		return ""
	var col: Object = hit.collider
	if col is StaticBody3D and col.has_meta("slam_surface"):
		return col.get_meta("slam_surface")
	return "wall"


func _env_takedown(target: CharacterBody3D, dir: Vector3, surface: String, hit_pos: Vector3) -> void:
	var kind := "slam_" + surface
	Fx.hit_stop(0.14)
	target.take_hit(dir, kind)
	Fx.burst(hit_pos, Color(1.0, 0.55, 0.2))
	Fx.shake(0.9)
	Fx.camera_punch(6.0)
	Fx.haptic(120)
	Fx.emit_hit(kind, hit_pos)
	_style_add(kind)


# --- block and parry -------------------------------------------------------------


func _enter_block() -> void:
	if state != State.GROUND:
		return
	state = State.BLOCK
	_block_t = 0.0
	velocity.x *= 0.3
	velocity.z *= 0.3
	_rig.play("Hit_Chest", 0.12, 0.55)  # braced pose, slowed, reads as a guard


func _block_step(delta: float) -> void:
	if not InputBus.dodge_held:
		state = State.GROUND  # release the guard
		return
	_block_t += delta
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if InputBus.take_punch() or InputBus.take_grab():
		state = State.GROUND  # dropping the guard to act
		_try_punch()
	move_and_slide()


func block_age() -> float:
	return _block_t if state == State.BLOCK else 99.0


## An enemy strike connects. Returns what happened so the attacker can react:
## "hit", "blocked" or "parried" (a young block = perfect parry).
func take_hit(dir: Vector3, from: CharacterBody3D = null) -> String:
	if state == State.CLIMB or state == State.GRAB:
		return "hit"
	dir.y = 0.0
	dir = dir.normalized()
	if state == State.DODGE:
		return "hit"  # resolved by the enemy via dodge_age() before this
	if state == State.BLOCK:
		if _block_t <= BLOCK_PARRY_WINDOW:
			if from and from.has_method("parried"):
				from.parried()
			return "parried"
		# a solid block: pushed back, no stun, no damage feel
		velocity.x = dir.x * 2.0
		velocity.z = dir.z * 2.0
		Fx.burst(global_position + Vector3.UP * 1.2 + \
				-_body.global_transform.basis.z * 0.5, Color(0.6, 0.8, 1.0))
		Fx.haptic(30)
		Fx.emit_hit("block", global_position + Vector3.UP * 1.2)
		return "blocked"
	velocity.x = dir.x * 4.5
	velocity.z = dir.z * 4.5
	velocity.y = 1.5
	_hitstun_until = _t + 0.45
	state = State.GROUND
	_rig.play("Hit_Chest", 0.04, 1.6)
	Fx.shake(0.4)
	Fx.emit_hit("player_hit", global_position + Vector3.UP * 1.2)
	return "hit"


# --- dodge ------------------------------------------------------------------------


func _try_dodge() -> void:
	if state == State.GRAB:
		_grab_throw()
		return
	if state not in [State.GROUND, State.PUNCH, State.BLOCK] or _t < _hitstun_until:
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
		_rig.play("Roll", 0.06, 2.1)
	else:
		_rig.play("Jump", 0.06)


func _dodge_step(delta: float) -> void:
	_gravity(delta)
	_dodge_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	move_and_slide()
	if _dodge_t >= DODGE_TIME:
		state = State.GROUND
		if _t - _punch_buffered_at < BUFFER_TIME:
			_start_punch(1, false)


## How long ago the dodge started (99 = not dodging).
func dodge_age() -> float:
	return _dodge_t if state == State.DODGE else 99.0


## Called by a parried enemy: the next punch inside the window counters.
func open_counter(seconds: float) -> void:
	_counter_until = _t + seconds


# --- grab and throw -----------------------------------------------------------------


func _try_grab_action() -> void:
	if state == State.GRAB:
		_grab_throw()
		return
	if state != State.GROUND or _t < _hitstun_until:
		return
	# seize an enemy in reach
	var target := _punch_target(-0.6, 0.35)
	if target and target.state not in [Enemy.State.DOWN, Enemy.State.GRABBED,
			Enemy.State.LAUNCHED] and target.has_method("grabbed_by"):
		state = State.GRAB
		_grab_t = 0.0
		_grabbed_enemy = target
		target.grabbed_by(self)
		_rig.play("Push", 0.08, 0.8)
		return
	# no enemy: pick up the pipe if it is at our feet
	if not has_pipe:
		for pipe in get_tree().get_nodes_in_group("pipe_prop"):
			if pipe is Node3D and global_position.distance_to((pipe as Node3D).global_position) < 1.7:
				has_pipe = true
				_pipe_prop = pipe
				(pipe as Node3D).visible = false
				_rig.equip_pipe(true)
				Sound.play("latch_0", -4.0)
				Sound.play("metal_click_0", -8.0)
				Log.info("player picked up the pipe")
				return
		if has_pipe:  # nothing to seize, pipe in hand: the grab throws it
			throw_pipe()
			return


func _grab_step(delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		state = State.GROUND
		return
	# while holding someone: PUNCH knees, DODGE or GRAB throws
	if InputBus.take_punch():
		_grab_knee()
	elif InputBus.take_dodge() or InputBus.take_grab():
		_grab_throw()
		return
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	move_and_slide()
	# the seized enemy is held in front of the hero
	var fwd := -_body.global_transform.basis.z
	_grabbed_enemy.global_position = global_position + fwd * 0.95
	_grab_t += delta
	if _grab_t >= GRAB_TIME:
		_release_grab(Vector3.ZERO, 0.0)


func _grab_knee() -> void:
	if _grabbed_enemy == null:
		return
	var fwd := -_body.global_transform.basis.z
	var dir := (fwd + Vector3.UP * 0.2)
	dir.y = 0.0
	Fx.hit_stop(0.08)
	_grabbed_enemy.take_hit(dir.normalized(), "knee")
	Fx.burst(global_position + fwd * 1.0 + Vector3.UP * 1.2, Color(1.0, 0.85, 0.5))
	Fx.shake(0.25)
	Fx.emit_hit("knee", global_position + fwd * 1.0 + Vector3.UP * 1.2)
	_style_add("knee")


func _grab_throw() -> void:
	if _grabbed_enemy == null:
		return
	# throwing the pipe instead: it flies and drops
	if has_pipe and _grab_t < 0.0:
		pass  # (pipe throw is GRAB with pipe in hand; handled below)
	var stick := _stick()
	var dir: Vector3
	if stick != Vector2.ZERO:
		var fwd := Vector3(-sin(InputBus.camera_yaw), 0.0, -cos(InputBus.camera_yaw))
		var right := Vector3(cos(InputBus.camera_yaw), 0.0, -sin(InputBus.camera_yaw))
		dir = (right * stick.x + fwd * -stick.y).normalized()
	else:
		dir = -_body.global_transform.basis.z
	var enemy := _grabbed_enemy
	_release_grab(dir, 6.5)
	# environmental takedown if something solid catches them
	var surface := _surface_behind(enemy, dir)
	if surface != "":
		_env_takedown(enemy, dir, surface, enemy.global_position + Vector3.UP * 1.2)
	else:
		_style_add("throw")


func _release_grab(dir: Vector3, speed: float) -> void:
	if _grabbed_enemy and is_instance_valid(_grabbed_enemy):
		if speed > 0.0:
			_grabbed_enemy.release_grab(dir, speed)
		else:
			_grabbed_enemy.release_grab(Vector3.ZERO, 0.0)
	_grabbed_enemy = null
	state = State.GROUND
	_rig.play("Idle", 0.15)


## Throw the held pipe like a weapon (GRAB while the pipe is equipped).
func throw_pipe() -> void:
	if not has_pipe:
		return
	has_pipe = false
	_rig.equip_pipe(false)
	if _pipe_prop:
		_pipe_prop.visible = true
		_pipe_prop.global_position = global_position + \
				-_body.global_transform.basis.z * 0.8 + Vector3.UP * 1.2
	var dir := -_body.global_transform.basis.z
	# the pipe hits the first enemy along its arc
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state == Enemy.State.DOWN:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < 4.0 and Vector2(dir.x, dir.z).dot(
				Vector2(to.x, to.z).normalized()) > 0.85:
			e.take_hit(dir, "pipe_heavy")
			Fx.burst(e.global_position + Vector3.UP * 1.2, Color(0.75, 0.8, 0.9))
			Fx.haptic(80)
			Fx.emit_hit("pipe_heavy", e.global_position + Vector3.UP * 1.2)
			_style_add("pipe_throw")
			break
	Sound.play("metal_ring_0", -6.0)


# --- targets -----------------------------------------------------------------------


## Nearest standing enemy within reach (+slack) and the given forward arc.
func _punch_target(min_dot: float, reach_slack: float) -> CharacterBody3D:
	var fwd := -_body.global_transform.basis.z
	var target: CharacterBody3D = null
	var best_d := PUNCH_REACH + reach_slack
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state in [Enemy.State.DOWN, Enemy.State.GRABBED, Enemy.State.LAUNCHED]:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < best_d and Vector2(fwd.x, fwd.z).dot(
				Vector2(to.x, to.z).normalized()) > min_dot:
			target = e
			best_d = to.length()
	return target


func _style_add(kind: String) -> void:
	if _style():
		_style().add(kind)


func _style() -> Node:
	return get_tree().get_first_node_in_group("style")


# --- climbing ------------------------------------------------------------------------


func _check_climb_hint() -> void:
	if not _near_climbable():
		return
	_hint_done = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("Jump while moving to climb")


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


func _try_grab() -> void:
	var fwd := -_body.global_transform.basis.z
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() < 0.75:
		return
	if Vector2(fwd.x, fwd.z).dot(flat.normalized()) < 0.35:
		return
	var space := get_world_3d().direct_space_state
	var exclude := [get_rid()]
	for h: float in [0.45, 1.15]:
		var origin: Vector3 = global_position + Vector3.UP * h + fwd * 0.36
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				origin, origin + fwd * 0.70, 1, exclude))
		if wall.is_empty():
			continue
		var n: Vector3 = wall.normal
		if n.y > 0.6 or n.dot(fwd) > -0.35:
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
		if not head.is_empty():
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
	_yaw = atan2(-into.x, -into.z)
	_body.rotation.y = _yaw
	_rig.play("Jump", 0.12)


func _climb_step(delta: float) -> void:
	_climb_t += delta / PULL_TIME
	var t := clampf(_climb_t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	global_position = _climb_from.lerp(_climb_to, e)
	if _climb_t >= 1.0:
		state = State.GROUND
		velocity = -_body.global_transform.basis.z * 1.8
		_rig.play("Jump_Land", 0.06)
		_rig.set_speed(1.8)
		_land_until = _t + 0.45


# --- helpers -----------------------------------------------------------------------------


func _gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)


func _drive_anim() -> void:
	if state in [State.CLIMB, State.PUNCH, State.DODGE, State.BLOCK, State.GRAB]:
		return
	if _t < _hitstun_until:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		if _rig.current() == "Jump_Start" and _rig.is_playing():
			return
		_rig.play("Jump", 0.25)
	elif _t < _land_until:
		return
	elif speed < 0.35:
		_rig.play("Idle", 0.25)
	elif speed < 3.3:
		_rig.play("Walk", 0.25)
		_rig.set_speed(clampf(speed / 2.2, 0.7, 1.7))
	else:
		_rig.play("Sprint", 0.25)
		_rig.set_speed(clampf(speed / 5.6, 0.75, 1.5))
