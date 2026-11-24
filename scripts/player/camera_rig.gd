extends Node3D

## THE CAMERA RIG (rebuild step 3): a spring-arm third-person camera
## with collision, fed by the `look` action (keyboard/controller) and
## by the touch LOOK stick (add_look). Never auto-rotates behind the
## hero; a soft yaw-assist can come later as a Settings toggle.

const ARM_LEN := 3.4
const PITCH_MIN := -0.55
const PITCH_MAX := 0.95
const SENS := 0.0026

# S5.17 THE FEEL PASS: the camera SPEAKS. Trauma-shake (impulse
# in, quadratic falloff out - the Squirrel Eiserloh model), a
# sprint FOV kick, and a handheld drift when the hero stands.
# A silent camera reads as a dev viewport; a talking one reads
# as a game.
const FOV_BASE := 68.0
const FOV_SPRINT := 74.0
const SHAKE_DECAY := 3.4   # trauma units per second
const DRIFT_FREQ := 0.55   # the handheld sway (rad/s, slow)

var yaw := 0.0
var pitch := 0.2

var _arm: SpringArm3D
var _cam: Camera3D
var _light: OmniLight3D  # the face light (the architecture's rule)
var _trauma := 0.0       # 0..1, squared for the shake amount
var _t_sway := 0.0

## Impulse-based shake: 0.3 = a jab landed, 1.0 = a super. Sums
## while hot (two hits in a row stack), decays in ~0.3 s.
func add_impulse(strength: float) -> void:
	_trauma = minf(_trauma + clampf(strength, 0.0, 1.0), 1.0)


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
	# the noir lens rides above the world, under the HUD (the S5.17
	# feel pass) - toggle-offable for battery/mobile honesty
	if bool(Settings.value("noir_screen")):
		var lens := preload("res://scripts/world/noir_screen.gd").new()
		add_child(lens)
	_apply()


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right",
			"look_up", "look_down")
	if look.length() > 0.01:
		add_look(look.x * 1400.0 * delta, look.y * 1400.0 * delta)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var hero_speed := 0.0
	if hero:
		global_position = global_position.lerp(
				hero.global_position + Vector3(0, 1.45, 0),
				clampf(delta * 18.0, 0.0, 1.0))
		var body := hero as CharacterBody3D
		if body:
			hero_speed = Vector2(body.velocity.x,
					body.velocity.z).length()
	# THE KICK: near run speed widens the lens (68 -> 74) and eases
	# back at walk - speed gets a FOCAL weight, not just a volume
	var kick_t: float = clampf((hero_speed - 3.2) / 2.4, 0.0, 1.0)
	_cam.fov = lerpf(_cam.fov, FOV_BASE + (FOV_SPRINT - FOV_BASE)
			* kick_t, clampf(delta * 6.0, 0.0, 1.0))
	# THE SHAKE: trauma^2 so small hits whisper and big ones slam;
	# three detuned trig channels (x/y pos + roll), never pitch -
	# pitch shake fights the player's look stick
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	_t_sway += delta
	var sx := sin(_t_sway * 37.0) * 0.5 + sin(_t_sway * 61.0) * 0.5
	var sy := sin(_t_sway * 43.0) * 0.5 + sin(_t_sway * 71.0) * 0.5
	_cam.position = Vector3(
			sx * shake * 0.14,
			sy * shake * 0.11,
			-shake * 0.06)
	_cam.rotation.z = sx * shake * 0.035
	# THE DRIFT: a handheld camera breathes when the hero stands -
	# a locked frame reads as a surveillance feed
	var calm := 1.0 - clampf(hero_speed / 1.0, 0.0, 1.0)
	if calm > 0.0:
		_cam.position += Vector3(
				sin(_t_sway * DRIFT_FREQ) * 0.012,
				sin(_t_sway * DRIFT_FREQ * 1.37) * 0.018, 0.0) * calm
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
