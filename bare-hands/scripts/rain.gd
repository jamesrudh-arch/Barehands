class_name RainLayer
extends Node3D
## Rain that follows the camera (world-aligned streaks, not glued to it) plus
## ground splash sparks that follow the hero. Density answers to the Quality
## tier; splashes only exist on High.

var _rain: CPUParticles3D
var _splash: CPUParticles3D
var _cam: Camera3D
var _player: CharacterBody3D


func _ready() -> void:
	_build_rain()
	_build_splash()
	Quality.tier_changed.connect(_apply_tier)
	_apply_tier(Quality.tier)


func _process(_delta: float) -> void:
	if _cam:
		global_position = Vector3(_cam.global_position.x, 0.0, _cam.global_position.z)
	if _splash and _player:
		_splash.position = Vector3(0.0, 0.02, 0.0) + _player.global_position - global_position


func _build_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(7.0, 5.0, 7.0)
	_rain.position = Vector3.UP * 6.5
	_rain.amount = 700
	_rain.lifetime = 0.9
	_rain.direction = Vector3(0.06, -1.0, 0.03)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 11.0
	_rain.initial_velocity_max = 14.0
	_rain.gravity = Vector3(0, -6.0, 0)
	_rain.scale_amount_min = 0.7
	_rain.scale_amount_max = 1.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.34)
	qm.material = mat
	_rain.mesh = qm
	add_child(_rain)
	add_to_group("rain_layer")
	# wait a frame for the scene, then grab the camera
	call_deferred("_grab_refs")


func _grab_refs() -> void:
	_cam = get_tree().get_first_node_in_group("camera") as Camera3D
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _build_splash() -> void:
	_splash = CPUParticles3D.new()
	_splash.name = "Splashes"
	_splash.emitting = false  # enabled by tier
	_splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_splash.emission_box_extents = Vector3(2.2, 0.02, 2.2)
	_splash.amount = 90
	_splash.lifetime = 0.22
	_splash.direction = Vector3.UP
	_splash.spread = 40.0
	_splash.initial_velocity_min = 0.7
	_splash.initial_velocity_max = 1.3
	_splash.gravity = Vector3(0, -9.0, 0)
	_splash.scale_amount_min = 0.5
	_splash.scale_amount_max = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 0.95, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.65, 0.85)
	mat.emission_energy_multiplier = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.045, 0.045)
	qm.material = mat
	_splash.mesh = qm
	add_child(_splash)


func _apply_tier(tier: String) -> void:
	if tier == Quality.HIGH:
		_rain.amount = 700
		_splash.emitting = true
	else:
		_rain.amount = 350
		_splash.emitting = false
