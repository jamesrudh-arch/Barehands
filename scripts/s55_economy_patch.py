#!/usr/bin/env python3
## S5.5 THE ECONOMY wiring: gun.add_reserve, hero grab chain,
## the tuned debt split, the fence's pool fix (stash_cash - dirty),
## the HUD DIRTY/CLEAN line, the phone LEDGER + PAY chip, the new
## tuning keys, and market._ammo's cap fix.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ------------------------------------------------------------- gun.gd
patch('scripts/player/gun.gd', [
(
"""signal ammo_changed(in_clip: int, reserve: int)""",
"""signal ammo_changed(in_clip: int, reserve: int)

## the market sells boxes; the HUD rides the signal
func add_reserve(n: int) -> void:
	reserve = mini(reserve + n, 72)  # three boxes: pocket limit
	ammo_changed.emit(ammo, reserve)"""
),
])

# ------------------------------------------------------------ hero.gd
patch('scripts/player/hero.gd', [
(
"""				var paid := false
				for p in get_tree().get_nodes_in_group("police"):
					if p.try_fence(self):
						paid = true
						break
				if not paid:
					face_action.emit(action)""",
"""				var paid := false
				for p in get_tree().get_nodes_in_group("police"):
					if p.try_fence(self):
						paid = true
						break
				if not paid:
					for m in get_tree().get_nodes_in_group("market"):
						if m.try_grab(self):
							paid = true
							break
				if not paid:
					face_action.emit(action)"""
),
])

# ------------------------------------------------------------ game.gd
patch('scripts/core/game.gd', [
(
"""	WorldState.set_value("debt", 2000.0)""",
"""	# the bible's five grand, split the way the story owes it
	WorldState.set_value("debt", Tuning.v("starting_debt"))
	WorldState.set_value("debt_family", Tuning.v("debt_start_family"))
	WorldState.set_value("debt_corp", Tuning.v("debt_start_corp"))"""
),
(
"""	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)""",
"""	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)
	if _market == null or not is_instance_valid(_market):
		_market = load("res://scripts/core/market.gd").new()
		add_child(_market)"""
),
(
"""var _police: Node = null""",
"""var _police: Node = null
var _market: Node = null"""
),
])

# ---------------------------------------------------------- police.gd
patch('scripts/core/police.gd', [
(
"""	var cash := float(WorldState.get_value("cash", 0.0))""",
"""	var cash := float(WorldState.get_value("stash_cash", 0.0))"""
),
(
"""	WorldState.set_value("cash", cash - price)""",
"""	WorldState.set_value("stash_cash", cash - price)"""
),
])

# ------------------------------------------------------------- hud.gd
patch('scripts/ui/hud.gd', [
(
"""	_cash.text = "$%d" % int(float(WorldState.get_value(
			"stash_cash", 0.0)))""",
"""	# the pools at a glance: dirty always, clean when it exists
	var clean := int(float(WorldState.get_value("clean_cash", 0.0)))
	_cash.text = "DIRTY $%d" % int(float(WorldState.get_value(
			"stash_cash", 0.0)))
	if clean > 0:
		_cash.text += "  ·  CLEAN $%d" % clean"""
),
])

# ----------------------------------------------------------- phone.gd
patch('scripts/ui/phone.gd', [
(
"""		"LEDGER":
			_line("CASH  $%d" % int(float(WorldState.get_value(
					"stash_cash", 0.0))), Color(0.5, 1.0, 0.7))
			_line("THE DEBT  $%d" % int(float(WorldState.get_value(
					"debt", 0.0))), Color(1.0, 0.55, 0.3))
			_line("HEAT  %d" % int(float(WorldState.get_value(
					"heat", 0.0))), Color(1.0, 0.45, 0.2))
			_line("every landing is a checkpoint - dying costs $50",
					Color(0.45, 0.47, 0.58), 13)""",
"""		"LEDGER":
			_line("DIRTY  $%d" % int(float(WorldState.get_value(
					"stash_cash", 0.0))), Color(0.5, 1.0, 0.7))
			_line("CLEAN  $%d" % int(float(WorldState.get_value(
					"clean_cash", 0.0))), Color(0.55, 0.9, 1.0))
			_line("THE DEBT  $%d" % int(float(WorldState.get_value(
					"debt", 0.0))), Color(1.0, 0.55, 0.3))
			_line("HEAT  %d" % int(float(WorldState.get_value(
					"heat", 0.0))), Color(1.0, 0.45, 0.2))
			# the quick-pay chip (bible: pay_chip on the Ledger)
			var chip := Button.new()
			chip.text = "PAY DEBT  $%d" % int(Tuning.v("pay_chip"))
			chip.custom_minimum_size = Vector2(0, 40)
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			var pay := func() -> void:
				var mkt: Node = null
				for m in get_tree().get_nodes_in_group("market"):
					mkt = m
				if mkt and mkt.pay_debt(Tuning.v("pay_chip")):
					_fill()
			chip.pressed.connect(pay)
			_col.add_child(chip)
			_line("the debt eats CLEAN only - launder at the club",
					Color(0.45, 0.47, 0.58), 13)"""
),
])

# --------------------------------------------------------- tuning.gd
patch('scripts/tuning.gd', [
(
"""	"launder_daily_drifting": 600,  # at trust "drifting" he moves this a day""",
"""	"launder_daily_drifting": 600,  # at trust "drifting" he moves this a day
	"launder_window_s": 300,  # the "day" stand-in until the cycle lands
	"noodles_price": 8,  # Old Dee's bowl (street price, dirty OK)
	"ammo_box_price": 25,  # Tony's box of twelve
	"ammo_box_rounds": 12,
	"economy_tick_s": 240,  # the overnight pressure's stand-in clock
	"debt_interest_tick": 0.005,  # ...what the debt grows per tick"""
),
])

# --------------------------------------------------------- market.gd
patch('scripts/core/market.gd', [
(
"""	var rounds := int(Tuning.v("ammo_box_rounds"))
	if int(gun.get("reserve")) >= int(gun.get("RESERVE_MAX")):""",
"""	var rounds := int(Tuning.v("ammo_box_rounds"))
	if int(gun.get("reserve")) >= 72:"""
),
(
"""	gun.set("reserve", int(gun.get("reserve")) + rounds)""",
"""	gun.call("add_reserve", rounds)"""
),
])
print("ALL WIRED")
