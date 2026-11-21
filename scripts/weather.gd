extends Node

## B19 batch 7: WEATHER (directive part 13). The city keeps its rainy
## identity, but the rain now has a LIFE: four intensities (light,
## normal, heavy, wind-driven storm) that drift into each other over
## minutes, a wind vector the whole street obeys (rain angle, smoke
## drift, the storm walk), puddle ripples that answer the downpour,
## and a rain bed whose volume follows the sky. Nothing here can dry
## the city out - the neon-noir bible is the law.

signal changed(state_name: String, intensity: float)

const STATES := {
	"light": 0.35,
	"normal": 0.65,
	"heavy": 0.9,
	"storm": 1.0,
}
const CYCLE_MIN := 90.0
const CYCLE_MAX := 180.0
const DRIFT := 0.05  # intensity units per second while transitioning

var state := "normal"
var intensity := 0.65
var wind := Vector3(0.22, 0.0, 0.1)

var _target := 0.65
var _next_change := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next_change = _clock() + randf_range(CYCLE_MIN, CYCLE_MAX)


func _process(delta: float) -> void:
	# the sky drifts toward its target, then picks a new mood
	if absf(intensity - _target) > 0.01:
		intensity = move_toward(intensity, _target, DRIFT * delta)
		_apply(intensity)
	elif _clock() > _next_change:
		var keys := STATES.keys()
		var pick: String = keys[randi() % keys.size()]
		set_state(pick)


## Public: the story or a test can pin the sky (save-scenes, the
## storm over the final choice, the calm after it). Pinning is
## IMMEDIATE - the slow drift belongs to the natural cycle only.
func set_state(s: String) -> void:
	if not STATES.has(s):
		return
	state = s
	_target = STATES[s]
	intensity = _target
	_next_change = _clock() + randf_range(CYCLE_MIN, CYCLE_MAX)
	# the storm carries its own wind; the calmer states drift less
	var wind_power: float = 0.12 + float(STATES[s]) * 0.35
	wind = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() \
			* wind_power
	_apply(intensity)
	changed.emit(s, intensity)
	Log.info("Weather: %s (intensity %.2f, wind %s)" % [s, intensity,
			str(wind.round())])


func _apply(to: float) -> void:
	# the rain bed follows the sky (the ambience loop Sound owns)
	if Sound != null:
		Sound.set_amb_vol("rain_asphalt", linear_to_db(
				clampf(0.35 + to * 0.65, 0.1, 1.0)) - 8.0)
		Sound.set_amb_vol("rain_metal", linear_to_db(
				clampf(to * 0.5, 0.05, 0.6)) - 10.0)


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0
