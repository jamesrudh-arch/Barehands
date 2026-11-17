extends CharacterBody3D
## Batch-1 placeholder hero: a capsule that walks around the street block.
## The on-screen stick writes InputBus.move; WASD/arrows work as a desktop fallback.

const SPEED := 4.5
const ACCEL := 12.0
const GRAVITY := 9.8
const BOUND := 18.5  # keeps the hero on the asphalt until the city grows

var _yaw := 0.0

@onready var _body: Node3D = $Body


func _physics_process(delta: float) -> void:
	var dir := InputBus.move
	if dir == Vector2.ZERO:  # desktop fallback for quick tests, ignored on phones
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var goal := Vector3(dir.x, 0.0, dir.y) * SPEED
	velocity.x = move_toward(velocity.x, goal.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, goal.z, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -BOUND, BOUND)
	global_position.z = clampf(global_position.z, -BOUND, BOUND)
	_face_travel(delta)


func _face_travel(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length_squared() > 0.05:
		_yaw = rotate_toward(_yaw, atan2(-flat.x, -flat.y), 10.0 * delta)
		_body.rotation.y = _yaw
