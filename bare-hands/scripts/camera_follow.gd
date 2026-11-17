class_name FollowCamera
extends Camera3D
## Cinematic third-person camera. Slight over-the-shoulder offset, laggy
## vertical follow (fast horizontal), a field-of-view kick while sprinting,
## a gentle push-in when enemies are close, an optional lock-on that frames
## the hero and their target together, and a ray that keeps it out of walls.

@export var target_path: NodePath = ^"../Player"
@export var distance := 6.0
@export var height := 2.8
@export var shoulder := 0.45
@export var look_height := 1.5
@export var base_fov := 70.0
@export var sprint_fov := 77.0
@export var combat_distance := 4.6
@export var combat_height := 2.2

var _yaw := 0.0
var _shake := 0.0  # impact shake, kept very subtle (a few centimetres)
var _lock_target: CharacterBody3D = null
var _fov_now := 70.0
var _dist_now := 6.0
var _height_now := 2.8
var _combat := 0.0  # 0..1 blend into the close combat framing
var _frozen := false  # the opening shot drives the camera while true
var _fov_punch := 0.0  # impact FOV kick, decays fast (negative = zoom in)

@onready var _target: CharacterBody3D = get_node(target_path) as CharacterBody3D


func _ready() -> void:
	add_to_group("camera")
	_fov_now = base_fov
	_dist_now = distance
	_height_now = height
	var pivot := _pivot()
	global_position = pivot + Vector3(0.0, height, distance)
	look_at(pivot)


## Impact shake: 0.2 jab, 0.35 cross, 0.9 slam.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Impact FOV punch in degrees; negative zooms in (parry).
func fov_punch(amount: float) -> void:
	_fov_punch = maxf(absf(_fov_punch) * signf(_fov_punch), 0.0)
	if signf(amount) == signf(_fov_punch) or _fov_punch == 0.0:
		_fov_punch = amount if absf(amount) > absf(_fov_punch) else _fov_punch


## Toggle lock-on to the nearest standing enemy in front of the hero.
func toggle_lock() -> void:
	if _lock_target:
		_lock_target = null
		return
	var best: CharacterBody3D = null
	var best_d := 14.0
	var fwd: Vector3 = -_target.get_node("Body").global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state == Enemy.State.DOWN:
			continue
		var to: Vector3 = e.global_position - _target.global_position
		to.y = 0.0
		if to.length() < best_d and Vector2(fwd.x, fwd.z).dot(
				Vector2(to.x, to.z).normalized()) > -0.2:
			best = e
			best_d = to.length()
	_lock_target = best


func lock_target() -> CharacterBody3D:
	return _lock_target


## The opening shot freezes the follow logic while it flies the camera.
func set_frozen(frozen: bool) -> void:
	_frozen = frozen


func _physics_process(delta: float) -> void:
	if _frozen:
		return
	if InputMap.has_action("lock") and Input.is_action_just_pressed("lock"):
		toggle_lock()
	_retarget_lock()
	var flat := Vector2(_target.velocity.x, _target.velocity.z)
	var facing := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	# Re-center only while the hero travels away from the camera. Running at
	# the camera keeps the view steady instead of spiraling behind them.
	if flat.length() > 1.2 and flat.x * facing.x + flat.y * facing.z > 0.0:
		var turn := 2.8
		if _lock_target:
			turn = 4.5  # lock-on turns to keep the target in frame
		_yaw = rotate_toward(_yaw, atan2(-flat.x, -flat.y), turn * delta)
	InputBus.camera_yaw = _yaw

	# Combat push-in: blend closer while any enemy is near the hero.
	var want_combat := 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state != Enemy.State.DOWN and \
				e.global_position.distance_to(_target.global_position) < 3.5:
			want_combat = 1.0
			break
	_combat = move_toward(_combat, want_combat, delta * 2.2)

	# FOV kick above sprint speed.
	var speed := flat.length()
	var want_fov := lerpf(base_fov, sprint_fov, clampf((speed - 5.4) / 2.0, 0.0, 1.0))
	_fov_now = lerpf(_fov_now, want_fov, 1.0 - exp(-4.0 * delta))
	_fov_punch = move_toward(_fov_punch, 0.0, 90.0 * delta)
	fov = _fov_now + _fov_punch

	_dist_now = lerpf(_dist_now, lerpf(distance, combat_distance, _combat), 1.0 - exp(-3.0 * delta))
	_height_now = lerpf(_height_now, lerpf(height, combat_height, _combat), 1.0 - exp(-3.0 * delta))

	var pivot := _aim_point()
	var look := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	# Over-the-shoulder: offset the aim point sideways, push the camera the
	# same way so the hero sits left-of-center looking down their line.
	var side := right * shoulder
	var goal := pivot - look * _dist_now + Vector3.UP * _height_now + side
	goal = _pull_in(pivot + side, goal)

	# Fast horizontal catch-up, softer vertical: reads as a laggy crane.
	var k := 1.0 - exp(-6.5 * delta)
	var goal_h := Vector3(goal.x, global_position.y, goal.z)
	global_position = global_position.lerp(goal_h, k)
	global_position.y = lerpf(global_position.y, goal.y, 1.0 - exp(-4.0 * delta))
	if _shake > 0.005:
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)) * 0.12 * _shake
		_shake = maxf(_shake - 3.0 * delta, 0.0)
	look_at(pivot + side * 0.5)


func _aim_point() -> Vector3:
	var p := _target.global_position + Vector3.UP * look_height
	if _lock_target:
		# Frame hero and target together: aim between them, biased to the hero.
		var t: Vector3 = _lock_target.global_position + Vector3.UP * 1.2
		return p.lerp(t, 0.35)
	return p


func _retarget_lock() -> void:
	if _lock_target == null:
		return
	if _lock_target.state == Enemy.State.DOWN or \
			_lock_target.global_position.distance_to(_target.global_position) > 14.0:
		_lock_target = null


func _pivot() -> Vector3:
	return _target.global_position + Vector3.UP * look_height


## Shorten the boom if something solid sits between the hero and the camera.
func _pull_in(pivot: Vector3, goal: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			pivot, goal, 1, [_target.get_rid()]))
	if hit.is_empty():
		return goal
	var dir := (goal - pivot).normalized()
	return pivot + dir * maxf(pivot.distance_to(hit.position) - 0.35, 0.8)
