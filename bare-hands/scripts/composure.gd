extends Node
## Player Composure (Batch 2, bible 4A: 'Posture break on enemies mirrors
## Composure on the player'; balance defaults: Composure 100). The hero's
## defensive economy: hits drain it hard, blocked strikes chip it, parries
## cost nothing (skill is free - defensive play stays rewarding). At zero
## the GUARD BREAKS: blocking is dead for a beat, the strike goes through.
## Calm regenerates it. The ComposureBar (main UI) listens to `changed`.

signal changed(value: float)
signal guard_broke

var value := 100.0:
	set(v):
		value = clampf(v, 0.0, Tuning.v("composure_max"))
		changed.emit(value)

var _broken_until_msec := 0
var _last_drain_msec := 0


func _ready() -> void:
	# survive the stress run: start whole, no save scumming
	value = Tuning.v("composure_max")


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	# the break heals on its own timer, independent of the bar refilling
	if _broken_until_msec > 0 and now >= _broken_until_msec:
		_broken_until_msec = 0
		changed.emit(value)
	# calm regen: nothing has bitten the hero for a beat
	if now - _last_drain_msec > int(Tuning.v("composure_regen_delay_s") * 1000.0):
		if value < Tuning.v("composure_max"):
			value = minf(value + Tuning.v("composure_regen_per_s") * delta,
					Tuning.v("composure_max"))


## A hit landed (hard drain) or a strike was blocked (a chip). Parries
## never drain - the parry is the skill expression, and skill is free.
func drain(amount: float, _why: String = "") -> void:
	if amount <= 0.0:
		return
	_last_drain_msec = Time.get_ticks_msec()
	var was_broken := guard_broken()
	value -= amount
	if value <= 0.0 and not was_broken:
		_broken_until_msec = Time.get_ticks_msec() + \
				int(Tuning.v("guard_break_seconds") * 1000.0)
		guard_broke.emit()
		Log.info("Composure: GUARD BROKEN (%s)" % _why)
		Fx.shake(0.6)
		Fx.haptic(120)
		Sound.play("latch_0", -6.0, 0.8)


func guard_broken() -> bool:
	return _broken_until_msec > Time.get_ticks_msec()


## Tests and the instant retry reset the hero whole.
func reset() -> void:
	_broken_until_msec = 0
	_last_drain_msec = 0
	value = Tuning.v("composure_max")
