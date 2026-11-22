extends Node3D

## Rain that follows the camera (world-aligned streaks, not glued to it) plus
## ground splash sparks that follow the hero. Density answers to the Quality
## tier; splashes only exist on High.
## B19 batch 7: the rain obeys the WEATHER autoload - four intensities
## with slow transitions, a wind vector that tilts the fall, splash
## strength that follows the downpour, and ripple rings on every
## puddle the street carries.

var _rain: CPUParticles3D
var _splash: CPUParticles3D
var _ripple_pool: Array[CPUParticles3D] = []
var _cam: Camera3D
var _player: CharacterBody3D


func _ready() -> void:
	_build_rain()
	_build_splash()
	Quality.tier_changed.connect(_apply_tier)
	_apply_tier(Quality.tier)
	# boot into whatever profile is live (XOGOT SAFE on mobile):
	# the rain layer builds after the Visual autoload, so it pulls
	visual_apply(Visual.rain_on, Visual.rain_streak_width, Visual.splash_on)


func _process(_delta: float) -> void:
	if _cam:
		global_position = Vector3(_cam.global_position.x, 0.0, _cam.global_position.z)
	if _splash and _player:
		_splash.position = Vector3(0.0, 0.02, 0.0) + _player.global_position - global_position
	_follow_weather()


## B19: the sky drives the fall - amount, wind tilt, splash strength -
## and the puddles carry ripple rings that answer the downpour.
func _follow_weather() -> void:
	if Weather == null:
		return
	var k: float = Weather.intensity
	# amount and streak read by intensity (Quality tier stays the other
	# half of the budget)
	var base := 700.0 if Quality.tier == Quality.HIGH else 350.0
	_rain.amount = int(base * (0.45 + 0.55 * k))
	if _rain.mesh is QuadMesh:
		var wm: StandardMaterial3D = (_rain.mesh as QuadMesh).material
		wm.albedo_color = Color(0.62, 0.72, 0.9, 0.24 + 0.2 * k)
	# the wind tilts the fall
	var w: Vector3 = Weather.wind
	_rain.direction = Vector3(w.x * 0.35, -1.0, w.z * 0.35).normalized()
	# splashes and puddle ripples breathe with the downpour
	if _splash:
		_splash.amount = int(40 + 70 * k)
		_splash.emitting = splash_allowed and Quality.tier == Quality.HIGH \
				and k > 0.3
	_ripples(k)


## Ripple rings on the street's puddles: small expanding rings whose
## emission rate follows the rain (a calm drizzle patters, a storm
## drums). One emitter per puddle, pooled and capped.
func _ripples(k: float) -> void:
	# ripples breathe from a proper rain upward (light drizzle patters
	# quietly, no rings); both tiers carry them - the pool is tiny
	if k < 0.5:
		for r in _ripple_pool:
			(r as CPUParticles3D).emitting = false
		return
	var puddles := get_tree().get_nodes_in_group("puddle")
	# build the pool once, then re-parent lazily as the street changes
	while _ripple_pool.size() < mini(puddles.size(), 4):
		var r := _build_ripple()
		add_child(r)
		_ripple_pool.append(r)
	for i in _ripple_pool.size():
		var r := _ripple_pool[i] as CPUParticles3D
		if i < puddles.size():
			var p := puddles[i] as Node3D
			r.position = p.global_position - global_position + Vector3.UP * 0.02
			r.emitting = true
			var cap := 12 if Quality.tier == Quality.HIGH else 6
			r.amount = int(3 + 9.0 * k) if Quality.tier == Quality.HIGH \
					else mini(int(2 + 5.0 * k), cap)
		else:
			r.emitting = false


func _build_ripple() -> CPUParticles3D:
	var r := CPUParticles3D.new()
	r.name = "Ripples"
	r.emitting = false
	r.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	r.emission_box_extents = Vector3(0.5, 0.01, 0.35)
	r.amount = 8
	r.lifetime = 0.7
	r.direction = Vector3.UP
	r.spread = 0.0
	r.initial_velocity_min = 0.0
	r.initial_velocity_max = 0.05
	r.gravity = Vector3.ZERO
	r.scale_amount_min = 0.4
	r.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(1.0, 1.0))
	r.scale_amount_curve = curve
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _ring_texture()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.3)
	qm.material = mat
	r.mesh = qm
	return r


## A soft ring, code-drawn (the ripple's own shape).
func _ring_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var d := Vector2(float(x) - 15.5, float(y) - 15.5).length()
			var ring := 1.0 - absf(d - 11.0) / 4.0
			var a := clampf(ring, 0.0, 1.0) * 0.8
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## A 4x32 soft vertical streak, code-generated (no import).
func _streak_texture() -> ImageTexture:
	var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		var t := absf(float(y) - 15.5) / 15.5
		var a := clampf(1.0 - t * t, 0.0, 1.0) * 0.85
		for x in range(4):
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## A 16x16 soft radial dot for splashes.
func _dot_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 7.5
			var a := clampf(1.0 - d * d, 0.0, 1.0) * 0.8
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


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
	_rain.scale_amount_min = 0.6
	_rain.scale_amount_max = 1.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# without this the quads do not face the camera on Mobile and
	# read as raw squares (the pale-block bug)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# B17: a code-generated streak texture. An UNTEXTURED quad is a
	# pale square when it catches the eye broadside; a soft-edged
	# streak texture is a raindrop at every angle (and needs no
	# imported file, so a fresh import cannot lose it).
	mat.albedo_texture = _streak_texture()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.008, 0.30)
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
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _dot_texture()  # B17: soft dot, not a square
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	qm.material = mat
	_splash.mesh = qm
	add_child(_splash)


func _apply_tier(tier: String) -> void:
	if tier == Quality.HIGH:
		_rain.amount = 700
		_splash.emitting = splash_allowed
	else:
		_rain.amount = 350
		_splash.emitting = false


## The Visual profile drives this (the VISUAL DEBUG panel): rain on
## or off, streak width in metres, splashes on or off.
var rain_on := true
var streak_width := 0.008
var splash_allowed := true


func visual_apply(want_rain: bool, width: float, want_splash: bool) -> void:
	rain_on = want_rain
	splash_allowed = want_splash
	streak_width = width
	_rain.emitting = want_rain
	_rain.visible = want_rain
	if _rain.mesh is QuadMesh:
		(_rain.mesh as QuadMesh).size = Vector2(width, 0.30)
	_apply_tier(Quality.tier)
