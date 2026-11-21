extends Node

## B19 batch 8: FIRE AND SMOKE (directive part 14). Real layered
## particle fires, not an orange sprite: a bright core, a taller
## outer flame, embers that ride up, smoke that grows and drifts with
## the wind, and steam when the rain works at it. A burning barrel is
## a takedown surface ("slam_fire" - the environmental combat the
## street already speaks). The Mobile budgets are the law: at most TWO
## flickering fire lights serve the nearest sources, every scorch is a
## recycled Decal from a pool of eight, and every emitter is a bounded
## CPUParticles3D that answers the Quality tier.

const FIRE_TEX := ["res://assets/fx/fire_1.png", "res://assets/fx/fire_2.png",
	"res://assets/fx/fire_3.png", "res://assets/fx/fire_4.png"]
const CORE_TEX := ["res://assets/fx/fire_core_1.png", "res://assets/fx/fire_core_2.png"]
const SMOKE_TEX := ["res://assets/fx/smoke_1.png", "res://assets/fx/smoke_2.png",
	"res://assets/fx/smoke_4.png"]
const SPARK_TEX := "res://assets/fx/spark_burst.png"

const LIGHT_BUDGET := 2
const SCORCH_POOL := 8  # the Mobile decal budget: 8 per mesh, hard law

var _sources: Array[Node3D] = []
var _scorch: Array[Decal] = []
var _scorch_i := 0
var _crackle: AudioStreamWAV = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crackle = _synth_crackle()


## A full fire source at `pos`: barrel body (shape-honest, like the
## street bins), flame layers, embers, smoke, steam layer, a scorch
## decal beneath, and - when `slam` - a takedown surface tag. The
## returned node joins the "fire_source" group.
func burning_barrel(parent: Node, pos: Vector3, slam := true) -> Node3D:
	var src := Node3D.new()
	src.name = "BurningBarrel"
	src.position = pos
	# deferred: street dressing runs while the scene is still setting
	# up children - a direct add on the busy parent is dropped silently
	parent.add_child.call_deferred(src)

	# the barrel: a steel drum with rim rings (cylinders - the same
	# honest shapes the street bins use; there is no barrel model in
	# the kits and a drum IS a cylinder)
	var body := StaticBody3D.new()
	if slam:
		body.set_meta("slam_surface", "fire")
	src.add_child(body)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.36
	cs.height = 0.95
	col.shape = cs
	col.position = Vector3.UP * 0.48
	body.add_child(col)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.1, 0.08)
	steel.roughness = 0.45
	steel.metallic = 0.7
	# [radius, height, y] - the drum wall plus two rim rings
	for spec in [[0.33, 0.9, 0.48], [0.36, 0.06, 0.08], [0.36, 0.06, 0.9]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = spec[0] * 0.95
		cm.bottom_radius = spec[0]
		cm.height = spec[1]
		cm.material = steel
		mi.mesh = cm
		mi.position = Vector3.UP * spec[2]
		body.add_child(mi)

	# the fire itself
	_flames(src, 1.0)
	_embers(src)
	_smoke(src, 1.0)
	_steam(src)

	# the scorch beneath (a recycled decal from the capped pool)
	scorch_at(pos + Vector3(0, 0.03, 0), 2.6)

	# the crackle bed (autoplay: the source enters the tree deferred)
	if _crackle != null:
		var a := AudioStreamPlayer3D.new()
		a.stream = _crackle
		a.bus = "Ambience"
		a.unit_size = 2.5
		a.volume_db = -6.0
		a.max_distance = 18.0
		a.autoplay = true
		src.add_child(a)

	src.add_to_group("fire_source")
	_sources.append(src)
	Log.info("Fire: a barrel burns at %s" % str(pos.round()))
	return src


## A small grill fire (no light, no slam - the noodle shop's wok).
func grill_fire(parent: Node, pos: Vector3) -> Node3D:
	var src := Node3D.new()
	src.name = "GrillFire"
	src.position = pos
	parent.add_child.call_deferred(src)  # the parent may be mid-setup
	_flames(src, 0.45)
	_smoke(src, 0.5)
	src.add_to_group("fire_source")
	_sources.append(src)
	return src


func _flames(src: Node3D, k: float) -> void:
	# the outer flame: tall, slow, translucent
	var outer := _sprite_emitter(FIRE_TEX, 0.55 * k,
			Color(1.0, 0.42, 0.12, 0.5), 26, 0.75,
			Vector2(0.5 * k, 0.6 * k))
	outer.position = Vector3.UP * 0.35 * k
	outer.initial_velocity_min = 1.4 * k
	outer.initial_velocity_max = 2.0 * k
	outer.angular_velocity_min = -70.0
	outer.angular_velocity_max = 70.0
	outer.scale_amount_min = 0.7
	outer.scale_amount_max = 1.3
	src.add_child(outer)
	src.set_meta("flame_outer", outer)
	# the core: small, bright, fast - the hot heart
	var core := _sprite_emitter(CORE_TEX, 0.3 * k,
			Color(1.0, 0.85, 0.4, 0.75), 16, 0.5,
			Vector2(0.3 * k, 0.34 * k))
	core.position = Vector3.UP * 0.3 * k
	core.initial_velocity_min = 1.1 * k
	core.initial_velocity_max = 1.6 * k
	core.scale_amount_min = 0.5
	core.scale_amount_max = 0.9
	src.add_child(core)
	src.set_meta("flame_core", core)


func _embers(src: Node3D) -> void:
	var e := CPUParticles3D.new()
	e.name = "Embers"
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.2
	e.amount = 18
	e.lifetime = 1.3
	e.direction = Vector3.UP
	e.spread = 22.0
	e.initial_velocity_min = 1.8
	e.initial_velocity_max = 3.0
	e.gravity = Vector3(0, 1.2, 0)
	e.scale_amount_min = 0.25
	e.scale_amount_max = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.62, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _tex(SPARK_TEX)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	qm.material = mat
	e.mesh = qm
	src.add_child(e)
	src.set_meta("embers", e)


func _smoke(src: Node3D, k: float) -> void:
	var s := _sprite_emitter(SMOKE_TEX, 1.6 * k,
			Color(0.16, 0.15, 0.16, 0.34), 22, 2.2,
			Vector2(0.8 * k, 0.8 * k))
	s.position = Vector3.UP * (1.1 * k)
	s.initial_velocity_min = 0.5
	s.initial_velocity_max = 0.9
	s.gravity = Vector3(0, 0.25, 0)
	# smoke grows and thins over its life
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.8))
	s.scale_amount_curve = curve
	src.add_child(s)
	src.set_meta("smoke", s)


func _steam(src: Node3D) -> void:
	# the rain's answer: thin white steam, idle until the sky pours
	var st := _sprite_emitter(SMOKE_TEX, 1.2,
			Color(0.75, 0.78, 0.82, 0.22), 14, 1.6,
			Vector2(0.6, 0.6))
	st.position = Vector3.UP * 0.8
	st.emitting = false
	st.initial_velocity_min = 0.7
	st.initial_velocity_max = 1.1
	src.add_child(st)
	src.set_meta("steam", st)


func _sprite_emitter(texs: Array, radius: float, color: Color,
		amount: int, lifetime: float, quad: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.amount = amount if Quality == null or Quality.tier != Quality.LOW \
			else maxi(4, amount / 2)
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _tex(str(texs[randi() % texs.size()]))
	var qm := QuadMesh.new()
	qm.size = quad
	qm.material = mat
	p.mesh = qm
	return p


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# the sprite set is CC0 but a fresh import can lag: a soft dot
	# keeps the fire honest (never a hard square)
	return _dot_texture()


func _dot_texture() -> ImageTexture:
	if _dot != null:
		return _dot
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 7.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot


var _dot: ImageTexture = null


# --- the running budget -----------------------------------------------------------------


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_flicker(delta, player)
	_weather_answer()


## At most LIGHT_BUDGET flickering OmniLights, serving the nearest
## sources; every other fire is emissive-only (Mobile law).
func _flicker(delta: float, player: Node3D) -> void:
	var near: Array = []
	for s in _sources:
		if not is_instance_valid(s):
			continue
		if player:
			s.set_meta("light_on", false)
			near.append([player.global_position.distance_to(
					(s as Node3D).global_position), s])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(near.size(), LIGHT_BUDGET):
		(near[i][1] as Node).set_meta("light_on", true)
	for s in _sources:
		if not is_instance_valid(s):
			continue
		var src := s as Node3D
		var light: OmniLight3D = src.get_node_or_null("FireLight")
		if bool(src.get_meta("light_on", false)) and light == null:
			light = OmniLight3D.new()
			light.name = "FireLight"
			light.light_color = Color(1.0, 0.55, 0.22)
			light.omni_range = 7.0
			light.position = Vector3.UP * 0.8
			src.add_child(light)
		if light:
			light.visible = bool(src.get_meta("light_on", false))
			if light.visible:
				light.light_energy = 0.9 + 0.4 * (0.5 + 0.5 * sin(
						Time.get_ticks_msec() * 0.013 * (1.0 + randf() * 0.2)))


## Rain works at every fire: the steam layer wakes, the flames damp,
## the smoke thins. Never a full extinguish - the noir holds a burn.
func _weather_answer() -> void:
	if Weather == null:
		return
	var wet: float = Weather.intensity
	for s in _sources:
		if not is_instance_valid(s):
			continue
		var src := s as Node3D
		# grills carry no steam layer - the defaults keep every getter
		# honest for both source kinds
		var steam: CPUParticles3D = src.get_meta("steam", null)
		if steam:
			steam.emitting = wet > 0.6
		var outer: CPUParticles3D = src.get_meta("flame_outer", null)
		if outer:
			outer.amount = int(26.0 * (1.0 - 0.3 * maxf(wet - 0.6, 0.0)))
		var smoke: CPUParticles3D = src.get_meta("smoke", null)
		if smoke:
			# the wind carries it
			smoke.gravity = Vector3(Weather.wind.x * 0.8, 0.25,
					Weather.wind.z * 0.8)


## Place a scorch mark: recycled from the capped Decal pool (oldest
## goes first). Code-drawn soft black splat - no asset dependency.
func scorch_at(pos: Vector3, size := 2.0) -> void:
	if _scorch.is_empty():
		for i in SCORCH_POOL:
			var d := Decal.new()
			d.texture_albedo = _scorch_texture()
			d.size = Vector3(size, 1.0, size)
			d.cull_mask = 1
			d.visible = false
			get_tree().current_scene.add_child.call_deferred(d)
			_scorch.append(d)
	var d := _scorch[_scorch_i % SCORCH_POOL]
	_scorch_i += 1
	d.global_position = pos
	d.size = Vector3(size, 1.0, size)
	d.visible = true


func _scorch_texture() -> ImageTexture:
	if _scorch_tex != null:
		return _scorch_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var d := Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.6) * 0.85
			img.set_pixel(x, y, Color(0.02, 0.02, 0.02, a))
	_scorch_tex = ImageTexture.create_from_image(img)
	return _scorch_tex


var _scorch_tex: ImageTexture = null


## Fire facts for the DEVICE REPORT and tests.
func facts() -> Dictionary:
	var live := 0
	for s in _sources:
		if is_instance_valid(s):
			live += 1
	return {"sources": live, "scorch_pool": SCORCH_POOL,
			"light_budget": LIGHT_BUDGET}


## 1 s of sparse low crackle: pops and hiss, looped (no asset).
func _synth_crackle() -> AudioStreamWAV:
	var rate := 11025
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pops := 0
	for i in n:
		var s := 0.0
		if rng.randf() < 0.0012:
			pops = 6
		if pops > 0:
			s = (rng.randf() - 0.5) * (float(pops) / 6.0)
			pops -= 1
		s += (rng.randf() - 0.5) * 0.06  # the constant hiss
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 12000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
