extends Node3D

## THE CAMERA RIG (rebuild step 3): a spring-arm third-person camera
## with collision, fed by the `look` action (keyboard/controller) and
## by the touch LOOK stick (add_look). Never auto-rotates behind the
## hero; a soft yaw-assist can come later as a Settings toggle.

const ARM_LEN := 3.4
const PITCH_MIN := -0.55
const PITCH_MAX := 0.95
const SENS := 0.0026

var yaw := 0.0
var pitch := 0.2

var _arm: SpringArm3D
var _cam: Camera3D
var _light: OmniLight3D  # the face light (the architecture's rule)


func _ready() -> void:
	name = "CameraRig"
	add_to_group("camera_rig")
	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	_arm.spring_length = ARM_LEN
	_arm.collision_mask = 1  # the world layer
	_arm.margin = 0.3
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = 68.0
	_cam.near = 0.08
	_arm.add_child(_cam)
	# the face light rides with the camera so the hero's face always
	# reads - warm, low energy, no shadow (mobile budget)
	_light = OmniLight3D.new()
	_light.name = "FaceLight"
	_light.light_color = Color(1.0, 0.85, 0.68)
	_light.light_energy = 0.55
	_light.omni_range = 4.2
	_light.position = Vector3(0, 0.2, 0.4)
	_arm.add_child(_light)
	_apply()


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right",
			"look_up", "look_down")
	if look.length() > 0.01:
		add_look(look.x * 1400.0 * delta, look.y * 1400.0 * delta)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero:
		global_position = global_position.lerp(
				hero.global_position + Vector3(0, 1.45, 0),
				clampf(delta * 18.0, 0.0, 1.0))
	_apply()


## The touch-stick feed (analog, in screen-space deltas).
func add_look(dx: float, dy: float) -> void:
	var invert: bool = Settings.value("invert_look") == true
	yaw -= dx * SENS
	pitch += (dy * SENS) * (-1.0 if invert else 1.0)
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


func _apply() -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	_cam.make_current()
