extends Node3D

## LEVERAGE B18 (Part 1.3): the hero locator. A bright marker ring on the
## ground under the hero plus a rim light that always comes from BEHIND
## relative to the camera, so the hero's silhouette pops against the
## dark street no matter how the phone renders the character's own
## materials (the grey-figure lesson: readability must not depend on a
## GLB import). Permanent and tunable: Settings keys hero_locator (on)
## and hero_rim (0..3); the VISUAL DEBUG panel can drive both live.

var _ring: MeshInstance3D
var _rim: SpotLight3D
var _t := 0.0


func _ready() -> void:
	add_to_group("hero_locator")
	_ring = MeshInstance3D.new()
	_ring.name = "LocatorRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.56
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.35, 1.0, 0.9, 0.95)
	rm.emission_enabled = true
	rm.emission = Color(0.3, 1.0, 0.9)
	rm.emission_energy_multiplier = 1.1  # bright, still Mobile-safe
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.no_depth_test = true  # visible through legs and clutter
	torus.material = rm
	_ring.mesh = torus
	_ring.position = Vector3(0, 0.05, 0)
	add_child(_ring)

	_rim = SpotLight3D.new()
	_rim.name = "RimLight"
	_rim.spot_range = 7.0
	_rim.spot_angle = 55.0
	_rim.light_color = Color(0.7, 0.95, 1.0)
	_rim.light_energy = 1.8
	_rim.shadow_enabled = false
	add_child(_rim)
	_apply_settings()
	Settings.changed.connect(_on_setting)


func _on_setting(_key: String) -> void:
	_apply_settings()


func _apply_settings() -> void:
	var on := bool(Settings.value("hero_locator"))
	visible = on
	if on:
		_rim.light_energy = clampf(float(Settings.value("hero_rim")), 0.0, 3.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# the ring breathes gently so a still hero still reads as alive
	_ring.scale = Vector3.ONE * (1.0 + 0.05 * sin(_t * 2.0))
	# the rim always comes from behind, relative to the camera: the
	# silhouette edge lights up against the dark street
	var yaw: float = InputBus.camera_yaw
	_rim.position = Vector3(sin(yaw) * 1.8, 2.4, cos(yaw) * 1.8)
	_rim.rotation.y = yaw  # -Z (the cone axis) now points at the hero
