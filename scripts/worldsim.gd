extends Node

## THE WORLD SIM (S5.7): the beat clock + weather. Three beats a
## day - DUSK, MIDNIGHT, 3 AM (the bible's Ledger puzzle) - each
## beat re-lights the current area's authored NightAir, rolls the
## weather (rain frequent, the signature), and distills the radio
## recap. The economy's windows, the schedules and the gossip all
## hang off beat_advanced.

signal beat_advanced(beat: int, beat_name: String)

const BEATS := ["DUSK", "MIDNIGHT", "3 AM"]

var _t := 0.0
var _scene_path := ""
var _scene_inst: Node = null
var _authored := {}      # scene -> {bg, amb_e, fog} (the base look)
var _crimes_this_beat := 0
var _rain: CPUParticles3D = null
var _splash_pool: Array = []
var _splash_next := 0.0
var _ring_mat_cache: StandardMaterial3D
var _rain_mat: ParticleProcessMaterial


func _ready() -> void:
	name = "WorldSim"
	add_to_group("worldsim")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not WorldState.has("beat"):
		WorldState.set_value("beat", 0)
	if not WorldState.has("day"):
		WorldState.set_value("day", 1)
	if not WorldState.has("weather"):
		WorldState.set_value("weather", "clear")
	WorldState.event_fired.connect(_on_event)


func beat() -> int:
	return int(WorldState.get_value("beat", 0))


func beat_name() -> String:
	return BEATS[beat() % BEATS.size()]


func day() -> int:
	return int(WorldState.get_value("day", 1))


func raining() -> bool:
	return str(WorldState.get_value("weather", "clear")) == "rain"


## tests + missions can force the sky
func set_weather(w: String) -> void:
	WorldState.set_value("weather", w)
	_apply_phase()
	_apply_weather()
	Log.info("Weather: %s (beat %d, %s, day %d)" % [w, beat(),
			beat_name(), day()])


func _on_event(kind: String, _data: Dictionary) -> void:
	if str(kind) == "crime":
		_crimes_this_beat += 1


func _process(delta: float) -> void:
	_t += delta
	if _t >= Tuning.v("beat_real_seconds"):
		_t = 0.0
		advance_beat()
	# the splash rings tick while it rains (S5.16)
	if raining() and _splash_pool.size() > 0:
		_splash_next -= delta
		if _splash_next <= 0.0:
			_splash_next = 0.12
			_fire_splash()
	# a travel builds a fresh NightAir + frees the old rain column:
	# re-apply when the current scene's file changes
	var scene := get_tree().current_scene
	if scene == null:
		return
	var sp := str(scene.scene_file_path)
	# track the INSTANCE, not the path - a same-area reload builds
	# a fresh scene + fresh environment under the same file name
	if (scene != _scene_inst or sp != _scene_path) and sp != "":
		_scene_inst = scene
		_scene_path = sp
		_apply_phase()
		_apply_weather()
	# the rain column rides the hero
	if _rain and is_instance_valid(_rain):
		var hero := get_tree().get_first_node_in_group("player") \
				as Node3D
		if hero and is_instance_valid(hero):
			_rain.global_position = hero.global_position \
					+ Vector3(0, 9.0, 0)


func advance_beat() -> void:
	var b := beat() + 1
	WorldState.set_value("beat", b)
	if b % BEATS.size() == 0:
		WorldState.set_value("day", day() + 1)
	# the sky rolls: rain is frequent, it does let up
	var w := str(WorldState.get_value("weather", "clear"))
	if w == "rain":
		if randf() < Tuning.v("weather_rain_stop"):
			w = "clear"
	else:
		if randf() < Tuning.v("weather_rain_chance"):
			w = "rain"
	WorldState.set_value("weather", w)
	_apply_phase()
	_apply_weather()
	_radio_recap()
	beat_advanced.emit(b, beat_name())
	Log.info("Beat: %d (%s, day %d, %s) - %d crime(s) on the scanner"
			% [b, beat_name(), day(), w, _crimes_this_beat])
	_crimes_this_beat = 0


## the phase curves - each area is AUTHORED at Midnight; Dusk is
## warmer + lighter, 3 AM is the deepest dark. Rain thickens fog.
func _apply_phase() -> void:
	var env := _env()
	if env == null:
		return
	var a := _authored_for(env)
	var ph := beat() % BEATS.size()
	var bg: Color = a.bg
	var amb: float = a.amb_e
	var fog: float = a.fog
	match ph:
		0:  # DUSK - the evening is warmer, the air lighter
			bg = bg.lightened(0.10)
			amb *= 1.2
			fog *= 0.8
		2:  # 3 AM - the deepest hour
			bg = bg.darkened(0.3)
			amb *= 0.85
			fog *= 1.15
	if raining():
		fog *= 2.6
		bg = bg.darkened(0.25)
		# the teal noir fill: rain-night shadows carry cold air
		env.ambient_light_color = Color(0.62, 0.78, 0.85, 1.0)
	else:
		# the AUTHORED tint returns (the second city breathes
		# amber - a white reset drowned it; the city suite caught
		# the regression)
		env.ambient_light_color = a.amb_c
	env.background_color = bg
	env.ambient_light_energy = amb
	env.fog_density = fog


func _apply_weather() -> void:
	# the ambience bed: the city always hums; rain comes FORWARD
	if raining():
		Sound.set_amb_vol("rain_asphalt", -3.0)
		Sound.set_amb_vol("rain_metal", -14.0)
		_ensure_rain()
		if _rain:
			_rain.emitting = true
	else:
		Sound.set_amb_vol("rain_asphalt", -26.0)
		Sound.set_amb_vol("rain_metal", -34.0)
		if _rain:
			_rain.emitting = false


## one ring: a random spot in the column's footprint, expands
## and fades over ~0.4 s - the ground answering the rain
func _fire_splash() -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		return
	for ring in _splash_pool:
		if (ring as MeshInstance3D).visible:
			continue
		var r: MeshInstance3D = ring
		r.visible = true
		r.global_position = hero.global_position + Vector3(
				randf_range(-7.0, 7.0), 0.03,
				randf_range(-7.0, 7.0))
		r.scale = Vector3.ONE * 0.5
		var tw := r.create_tween()
		tw.tween_property(r, "scale", Vector3.ONE * 2.6, 0.42)
		tw.tween_property(r, "visible", false, 0.0)
		break


## the splash ring material: additive, fading
func _ring_mat() -> StandardMaterial3D:
	if _ring_mat_cache == null:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d: float = Vector2(x - 15.5, y - 15.5).length()
				var a: float = 0.0
				if d > 9.0 and d < 15.0:
					a = 1.0 - absf(d - 12.0) / 3.0
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.5))
		m.albedo_texture = ImageTexture.create_from_image(img)
		_ring_mat_cache = m
	return _ring_mat_cache


## the rain column: streaks in a 16 m box over the hero.
## CPUParticles3D (S5.15 law: GPUParticles drew NOTHING on the
## compatibility path - the diff probe proved 0.05% pixel change
## with emitting=true; CPU particles render on every renderer).
## Streaks sized for the READABILITY law: a 1.4 cm sliver is
## sub-pixel at street distance - these read as rain.
func _ensure_rain() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _rain and is_instance_valid(_rain) \
			and _rain.get_parent() == scene:
		return
	if _rain and is_instance_valid(_rain):
		_rain.queue_free()
	_rain = CPUParticles3D.new()
	_rain.name = "RainColumn"
	_rain.amount = int(Tuning.v("rain_particles"))
	# LIFETIME = COLUMN HEIGHT: 0.7 s of fall spread the streaks
	# over 28 vertical metres - the camera band saw ~14 of 700.
	# A 0.35 s fall is a compact 15 m downpour: same particles,
	# ~3x the visible density.
	_rain.lifetime = 0.35
	_rain.explosiveness = 0.0
	# THE FALL VOLUME (S5.16 law): streaks fall ~28 m per lifetime
	# (velocity 30 + gravity 30 x 0.7 s) - an aabb that ends 10 m
	# under the node CULLED most of the fall (the isolate probe:
	# 700 emitting, 0.15% of pixels changed). Cover the whole fall.
	_rain.visibility_aabb = AABB(Vector3(-17, -13, -17),
			Vector3(34, 18, 34))
	_rain.direction = Vector3(0.3, -1, 0.06)  # the street's wind
	_rain.spread = 12.0
	_rain.gravity = Vector3(0, -30, 0)
	_rain.initial_velocity_min = 26.0
	_rain.initial_velocity_max = 34.0
	_rain.scale_amount_min = 0.5
	_rain.scale_amount_max = 2.2
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# THE VIEW-SCALE BOX: the frustum sees 10-30 m of street; a
	# hero-centred +-8 m column put ~15 streaks in frame. +-16 m
	# with 3x the particles keeps the same per-m3 density over the
	# whole visible street.
	_rain.emission_box_extents = Vector3(16.0, 0.2, 16.0)
	# THE SPLASH RINGS (S5.16): the ground answers the rain - a
	# pooled set of expanding rings under the column, the "no
	# splash" gate finding
	_splash_pool = []
	_splash_next = 0.0
	for i in 10:
		var ring := MeshInstance3D.new()
		var rm := QuadMesh.new()
		rm.size = Vector2(0.2, 0.2)
		rm.material = _ring_mat()
		ring.mesh = rm
		ring.rotation.x = -PI / 2.0
		ring.visible = false
		scene.add_child(ring)
		_splash_pool.append(ring)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.022, 1.15, 0.022)
	var sm := StandardMaterial3D.new()
	# BRIGHT against the night (S5.16 law): the frame is dark now
	# (sky 14 / mid 39 / street 92) - rain catches city light and
	# must CONTRAST, not whisper. Dim streaks on a dark frame read
	# as mush (the 94.8%-diff / VLM-"no rain" contradiction).
	sm.albedo_color = Color(0.62, 0.72, 0.9, 0.65)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = sm
	_rain.mesh = streak
	# LAW (isolate-probe-proven): a rotated CPUParticles3D node
	# renders NOTHING on this path (0.00% tilted vs 5.96% upright).
	# The wind lives in the velocity vector, never the transform.
	scene.add_child(_rain)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero and is_instance_valid(hero):
		_rain.global_position = hero.global_position + Vector3(0, 7, 0)


## the radio recap: the scanner distills the beat
func _radio_recap() -> void:
	var heat := int(float(WorldState.get_value("heat", 0.0)))
	var line := "day %d, %s - " % [day(), beat_name().to_lower()]
	if _crimes_this_beat <= 0 and heat < 3:
		line += "a quiet scanner. the city breathes."
	elif _crimes_this_beat >= 3 or heat >= 8:
		line += "all units: the block is hot. %d incident(s)." \
				% maxi(1, _crimes_this_beat)
	else:
		line += "%d incident(s) logged, nothing the rain can't wash." \
				% _crimes_this_beat
	WorldState.push_event("radio", {"line": line, "beat": beat()})
	# the street's version: the count drifts with every retelling
	if _crimes_this_beat > 0:
		var drift: int = _crimes_this_beat + randi_range(0, 2)
		WorldState.push_event("gossip", {"line":
				"the street says it was %d men, and nobody saw a thing"
				% drift, "beat": beat()})


# --- the env plumbing -------------------------------------------------------

func _env() -> Environment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	# every area builds its own (name varies) - take the first
	for c in scene.get_children():
		if c is WorldEnvironment:
			return (c as WorldEnvironment).environment
	return null


## remember each area's AUTHORED values once, then modulate - the
## areas rebuild their environment on every travel
func _authored_for(e: Environment) -> Dictionary:
	var scene := get_tree().current_scene
	var key := str(scene.scene_file_path) if scene != null else "?"
	if _authored.has(key):
		return _authored[key]
	var a := {"bg": e.background_color, "amb_c": e.ambient_light_color,
			"amb_e":
			e.ambient_light_energy, "fog": e.fog_density}
	_authored[key] = a
	return a
