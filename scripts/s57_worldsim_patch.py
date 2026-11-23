#!/usr/bin/env python3
## S5.7 THE WORLD SIM: the beat clock (Dusk/Midnight/3 AM), the
## day/night phase curves over each area's authored NightAir, the
## RAIN machine (particles + ambience retune + fog), and the radio
## recap that distills the scanner each beat.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ------------------------------------------------------------ tuning keys
patch('scripts/tuning.gd', [
(
"""	"beat_real_seconds": 360.0,""",
"""	"beat_real_seconds": 360.0,
	"weather_rain_chance": 0.6,  # rain frequent - the signature
	"weather_rain_stop": 0.35,  # it does eventually let up
	"rain_particles": 340.0,  # the column density (mobile-honest)"""
),
])

# ------------------------------------------------------------- game wiring
patch('scripts/core/game.gd', [
(
"""	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)""",
"""	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)
	if _worldsim == null or not is_instance_valid(_worldsim):
		_worldsim = load("res://scripts/worldsim.gd").new()
		add_child(_worldsim)"""
),
])

# the member var (beside _police/_market)
s = open('scripts/core/game.gd').read()
anchor = "var _police: Node = null"
if anchor not in s:
    anchor = "var _police"
assert anchor in s
s = s.replace(anchor, anchor + "\nvar _worldsim: Node = null", 1)
open('scripts/core/game.gd','w').write(s)
print("game rides the worldsim")
