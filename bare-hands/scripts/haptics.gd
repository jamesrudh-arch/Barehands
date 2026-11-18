extends Node
## Haptics (Stage A3), autoloaded as "Haptics". Every pattern is short and
## distinct so a player can FEEL which action landed: light for a punch,
## heavy for a heavy hit, a long rumble for a super strike. Honors the
## master switch and strength slider in Settings.
##
## Android: Input.vibrate_handheld works out of the box.
## iOS: Godot has no built-in vibration - a plugin is needed. The hooks all
## route through here, so wiring one in later touches only this file.

const PATTERNS := {
	"light": [18],          # a jab: a tick
	"heavy": [40],          # a heavy hit: a firm push
	"parry": [12, 60, 22],  # the freeze window: tick-pause-tick
	"super": [30, 70, 120], # the super strike: building rumble
	"ui": [10],             # a button press
	"down": [70],           # the hero is knocked down
}

var _queue: Array = []  # [msec_to_wait, duration] steps


func fire(pattern: String) -> void:
	if not bool(Settings.value("haptics_on")):
		return
	var steps: Array = PATTERNS.get(pattern, PATTERNS["ui"])
	var strength: float = float(Settings.value("haptic_str"))
	if strength <= 0.01:
		return
	# strength scales the durations (a weaker motor still gets the rhythm)
	var wait := 0
	for i in steps.size():
		var dur := int(round(float(steps[i]) * (0.4 + 0.6 * strength)))
		_queue.append([float(wait), dur])
		wait = 0
		if i < steps.size() - 1:
			_queue.append([55.0, 0])  # gap between pulses
	_pump()


## Fire one raw pulse (used by Fx for combat hits).
func pulse(duration_ms: int) -> void:
	if not bool(Settings.value("haptics_on")):
		return
	var strength: float = float(Settings.value("haptic_str"))
	if strength <= 0.01:
		return
	Input.vibrate_handheld(int(round(duration_ms * (0.4 + 0.6 * strength))))


var _pumping := false


func _pump() -> void:
	if _pumping or _queue.is_empty():
		return
	_pumping = true
	while not _queue.is_empty():
		var step: Array = _queue.pop_front()
		var wait_ms: float = step[0]
		var dur: int = step[1]
		if wait_ms > 0.0:
			await _sleep_msec(wait_ms)
		if dur > 0:
			Input.vibrate_handheld(dur)
			await _sleep_msec(dur + 8.0)
	_pumping = false


func _sleep_msec(ms: float) -> void:
	var timer := get_tree().create_timer(ms / 1000.0)
	await timer.timeout
