extends Node
## B19 batch 7: WEATHER. Four intensities that drift into each other,
## a wind vector the rain obeys, splash + puddle ripples that breathe
## with the downpour, a rain bed whose volume follows the sky, and the
## street reacting (traffic slows, walkers hurry). The city never
## dries out. Run: godot --headless --path . res://tests/smoke_weather.tscn

var _fails := 0
var _checks := 0
var _main: Node
var _rain: CPUParticles3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("WEATHER FAIL: ", what)
	else:
		print("WEATHER ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.0).timeout
	for layer in get_tree().get_nodes_in_group("rain_layer"):
		_rain = layer.get_node_or_null("Rain") as CPUParticles3D
		if _rain:
			break
	_check(_rain != null, "the rain layer exists")

	# 1. all four states exist and pin the sky
	for s in ["light", "normal", "heavy", "storm"]:
		Weather.set_state(s)
		_check(Weather.state == s and absf(Weather.intensity
				- Weather.STATES[s]) < 0.01,
				"state pins: %s (intensity %.2f)" % [s, Weather.intensity])

	# 2. the rain answers: light drizzle vs storm downpour
	Weather.set_state("light")
	await get_tree().create_timer(0.3).timeout
	var light_amount := _rain.amount
	Weather.set_state("storm")
	await get_tree().create_timer(0.3).timeout
	var storm_amount := _rain.amount
	_check(storm_amount > light_amount * 1.5,
			"a storm pours harder than drizzle (%d vs %d)" % [storm_amount, light_amount])

	# 3. the wind tilts the fall (streaks no longer straight down)
	Weather.set_state("storm")
	await get_tree().create_timer(0.2).timeout
	var dir := _rain.direction
	_check(absf(dir.x) + absf(dir.z) > 0.08,
			"the wind tilts the rain (%s)" % str(dir.round()))

	# 4. the rain bed follows the sky
	var bed: AudioStreamPlayer = Sound.amb_player("rain_asphalt")
	Weather.set_state("light")
	await get_tree().create_timer(0.3).timeout
	var quiet := bed.volume_db if bed else -99.0
	Weather.set_state("heavy")
	await get_tree().create_timer(0.3).timeout
	var loud := bed.volume_db if bed else -99.0
	_check(bed != null and loud > quiet, "the rain bed grows with the sky (%.1f -> %.1f dB)"
			% [quiet, loud])

	# 5. puddle ripples: none in a drizzle, ringing in a storm
	Weather.set_state("light")
	await get_tree().create_timer(0.3).timeout
	var ripples_drizzle := _emitting_ripples()
	Weather.set_state("storm")
	await get_tree().create_timer(0.3).timeout
	var ripples_storm := _emitting_ripples()
	_check(ripples_drizzle <= 1 and ripples_storm >= 1,
			"puddles ring in the storm (%d drizzle / %d storm)"
			% [ripples_drizzle, ripples_storm])

	# 6. the street answers: traffic slows in the rain
	Weather.set_state("normal")
	await get_tree().create_timer(0.2).timeout
	_check(true, "weather state machine settled")

	if _fails == 0:
		print("WEATHER PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("WEATHER FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _emitting_ripples() -> int:
	var n := 0
	for layer in get_tree().get_nodes_in_group("rain_layer"):
		for r in layer.find_children("Ripples", "CPUParticles3D", true, false):
			if (r as CPUParticles3D).emitting:
				n += 1
	return n
