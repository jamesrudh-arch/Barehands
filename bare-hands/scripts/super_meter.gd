extends Node
## The SUPER meter (Stage A4), autoloaded as "SuperMeter". Fills from landed
## hits (+4), parries (+14) and takedowns (+10); a full meter lights the
## SUPER button. Spending it consumes the whole bar.

signal changed(value: float)
signal full

const MAX := 100.0
const GAIN_HIT := 4.0
const GAIN_PARRY := 14.0
const GAIN_TAKEDOWN := 10.0

var value := 0.0:
	set(v):
		var was_full := value >= MAX
		value = clampf(v, 0.0, MAX)
		changed.emit(value)
		if not was_full and value >= MAX:
			full.emit()
			Log.info("SuperMeter: FULL")


func _ready() -> void:
	# survive the 5-minute stress test: start empty, no save scumming
	value = 0.0


func gain(amount: float, _why: String = "") -> void:
	value += amount


## Try to spend the whole bar. False if it is not full.
func consume() -> bool:
	if value < MAX:
		return false
	value = 0.0
	return true


func is_full() -> bool:
	return value >= MAX


## Fraction 0..1 (for the button ring).
func frac() -> float:
	return value / MAX
