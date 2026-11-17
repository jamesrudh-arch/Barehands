extends Camera3D
## Third-person follow camera for Batch 2. Swings behind the hero's heading,
## keeps them framed on slopes and rooftops, and pulls in with a ray when a
## wall would otherwise clip the view.

@export var target_path: NodePath = ^"../Player"
@export var distance := 6.5
@export var height := 3.0
@export var follow_speed := 6.0
@export var turn_speed := 2.8
@export var look_height := 1.5

var _yaw := 0.0

@onready var _target: CharacterBody3D = get_node(target_path) as CharacterBody3D


func _ready() -> void:
	var pivot := _pivot()
	global_position = pivot + Vector3(0.0, height, distance)
	look_at(pivot)


func _physics_process(delta: float) -> void:
	var flat := Vector2(_target.velocity.x, _target.velocity.z)
	var facing := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	# Re-center only while the hero travels away from the camera. Running at
	# the camera keeps the view steady instead of spiraling behind them.
	if flat.length() > 1.2 and flat.x * facing.x + flat.y * facing.z > 0.0:
		_yaw = rotate_toward(_yaw, atan2(-flat.x, -flat.y), turn_speed * delta)
	InputBus.camera_yaw = _yaw

	var pivot := _pivot()
	var look := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var goal := pivot - look * distance + Vector3.UP * height
	goal = _pull_in(pivot, goal)

	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	look_at(pivot)


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
