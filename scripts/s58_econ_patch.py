#!/usr/bin/env python3
## S5.8 THE ECONOMY GOES REAL: the overnight pressure and the
## laundering window ride the BEAT clock (worldsim's signal), the
## drifting cap re-rolls each window, and after midnight the shops
## charge the night premium.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

patch('scripts/tuning.gd', [
(
"""	"rain_particles": 340.0,  # the column density (mobile-honest)""",
"""	"rain_particles": 340.0,  # the column density (mobile-honest)
	"night_premium": 0.10,  # after MIDNIGHT everything costs more
	"launder_cap_drift": 0.35,  # each window the cap drifts +/-35%"""
),
])

patch('scripts/core/market.gd', [
# the timer dies; the beat hook lives
(
"""var _tick_t := 0.0""",
"""var _beat_wired := false"""
),
(
"""func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t < Tuning.v("economy_tick_s"):
		return
	_tick_t = 0.0
	_overnight_pressure()""",
"""func _process(_delta: float) -> void:
	# the pressure rides the BEAT now (S5.8) - wire whenever the
	# worldsim shows up (it is created after the market's siblings)
	if _beat_wired:
		return
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws and not ws.beat_advanced.is_connected(_on_beat):
		ws.beat_advanced.connect(_on_beat)
		_beat_wired = true


## one BEAT of the city's pressure: interest, the noticed pocket,
## and a fresh laundering window with a re-rolled drifting cap.
func _on_beat(_beat: int, _name: String) -> void:
	_overnight_pressure()
	WorldState.set_value("laundered_window", 0.0)
	var base := Tuning.v("launder_daily_drifting")
	var drift := 1.0 + randf_range(-Tuning.v("launder_cap_drift"),
			Tuning.v("launder_cap_drift"))
	WorldState.set_value("launder_cap", roundf(base * drift))
	Log.info("Market: the window opens - Vesper can move ~$%d tonight"
			% int(float(WorldState.get_value("launder_cap", base))))"""
),
# the window reads the beat-driven cap (no clock math)
(
"""func _laundry() -> bool:
	var cap := Tuning.v("launder_daily_drifting")
	var now := Time.get_ticks_msec()
	var window_ms := int(Tuning.v("launder_window_s")) * 1000
	var last := int(float(WorldState.get_value("launder_last", 0.0)))
	if now - last >= window_ms:
		WorldState.set_value("laundered_window", 0.0)  # new window
	var moved := float(WorldState.get_value("laundered_window", 0.0))""",
"""func _laundry() -> bool:
	# the window opens on each BEAT (S5.8) with a drifted cap
	var cap := float(WorldState.get_value("launder_cap",
			Tuning.v("launder_daily_drifting")))
	var moved := float(WorldState.get_value("laundered_window", 0.0))"""
),
# drop the stale launder_last write
(
"""	WorldState.set_value("laundered_window", moved + amount)
	WorldState.set_value("launder_last", float(now))""",
"""	WorldState.set_value("laundered_window", moved + amount)"""
),
# the night premium: after MIDNIGHT every shop costs more
(
"""func pay(price: float, who := "") -> Dictionary:""",
"""func pay(price: float, who := "") -> Dictionary:
	# after MIDNIGHT the city charges for the hour (S5.8)
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws and int(ws.beat()) % 3 == 1:
		price *= 1.0 + Tuning.v("night_premium")"""
),
])
print("ECONOMY RIDES THE BEAT")
