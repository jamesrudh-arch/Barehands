extends Node
## S5.7 WORLD SIM: the beat clock, the phase curves, the rain
## machine, the radio recap.
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("WORLD PASS %s" % what)
	else:
		_fail += 1
		print("WORLD FAIL %s" % what)

func _ws() -> Node:
	return get_tree().get_first_node_in_group("worldsim")

func _env() -> Environment:
	for c in get_tree().current_scene.get_children():
		if c is WorldEnvironment:
			return (c as WorldEnvironment).environment
	return null

func _ready() -> void:
	var dog := get_tree().create_timer(200.0, true, false, true)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.6)
	var ws := _ws()
	_check(ws != null, "the worldsim rides Game")
	if ws == null:
		_finish()
		return
	_check(ws.beat() == 0 and ws.beat_name() == "DUSK"
			and ws.day() == 1, "day 1 opens at DUSK (beat 0)")
	# --- the phase curves (authored = MIDNIGHT, the base look)
	# the warehouse home has no NightAir - read the curves on the
	# open street
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	ws.set_weather("clear")
	await _wait_s(0.3)
	var e := _env()
	var dusk_amb: float = e.ambient_light_energy
	var dusk_fog: float = e.fog_density
	ws.advance_beat()
	await _wait_s(0.3)
	_check(ws.beat() == 1 and ws.beat_name() == "MIDNIGHT",
			"beat 1 is MIDNIGHT")
	_check(is_equal_approx(e.ambient_light_energy,
			dusk_amb / 1.2),
			"MIDNIGHT is the authored look (ambient back to base)")
	ws.advance_beat()
	await _wait_s(0.3)
	_check(ws.beat_name() == "3 AM", "beat 2 is 3 AM")
	_check(e.ambient_light_energy < dusk_amb / 1.2
			and e.fog_density > dusk_fog,
			"3 AM is the deepest hour (ambient down, fog up)")
	ws.advance_beat()
	await _wait_s(0.3)
	_check(ws.beat() == 3 and ws.beat_name() == "DUSK"
			and ws.day() == 2, "the day rolls: day 2 DUSK")
	# --- the rain machine
	ws.set_weather("rain")
	await _wait_s(0.4)
	var rain := get_tree().current_scene.get_node_or_null(
			"RainColumn") as GPUParticles3D
	_check(rain != null and rain.emitting,
			"the rain column falls (particles emitting)")
	_check(Sound.amb_player("rain_asphalt") != null
			and is_equal_approx(
			Sound.amb_player("rain_asphalt").volume_db, -3.0),
			"the rain bed comes FORWARD (-3 dB)")
	var clear_fog: float = _env().fog_density
	ws.set_weather("clear")
	await _wait_s(0.4)
	_check(not rain.emitting, "clear sky: the column stops")
	_check(Sound.amb_player("rain_asphalt").volume_db < -20.0,
			"clear sky: the bed ducks away")
	_check(_env().fog_density < clear_fog,
			"rain thickens the fog (clear is thinner)")
	# --- the radio recap
	var log_size := WorldState.event_log().size()
	WorldState.push_event("crime", {"pos": Vector3.ZERO})
	WorldState.push_event("crime", {"pos": Vector3.ZERO})
	ws.advance_beat()
	await _wait_s(0.3)
	var got_radio := false
	for ev in WorldState.event_log().slice(maxi(0,
			WorldState.event_log().size() - 4),
			WorldState.event_log().size()):
		if str(ev.get("kind", "")) == "radio":
			got_radio = true
	_check(got_radio, "the radio distills the scanner each beat")
	# --- travel re-applies (a fresh NightAir, the rain follows)
	ws.set_weather("rain")
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	var rain2 := get_tree().current_scene.get_node_or_null(
			"RainColumn") as GPUParticles3D
	_check(rain2 != null and rain2.emitting,
			"the rain follows the travel")
	# --- the save carries the clock
	var sv: Dictionary = WorldState.to_save()
	_check(str(sv).contains("beat") and str(sv).contains("weather"),
			"the save carries beat + weather")
	_finish()

func _finish() -> void:
	print("WORLD RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
