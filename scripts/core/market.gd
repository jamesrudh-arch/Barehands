extends Node

## THE MARKET (S5.5): the economy's vendor layer - the design's
## dirty/clean split on the cast that already stands at its doors.
## Crime pays DIRTY (stash drops, mission rewards, the fence deals
## in it); laundering at Vesper's club converts it CLEAN at his
## cut, capped by trust ("drifting" for now - the trust system is
## not built); LEGIT shops take clean at par and dirty at the
## surcharge; THE DEBT only eats clean (that is the loop's teeth:
## you cannot hand the Corporation a wad of alley money). The
## overnight pressure runs on a timer until the day/night cycle
## exists: interest ticks, and a pocket too full of dirty cash
## gets noticed.

const VENDOR_R := 3.2

## area -> who stands where (the cast is placed by the areas)
const VENDORS := {
	"noodles": {"area": "neighbourhood",
			"pos": Vector3(-40.4, 0.05, 5.4), "who": "OLD DEE"},
	"ammo": {"area": "club_district",
			"pos": Vector3(-35.5, 0.05, 5.0), "who": "TONY"},
	"laundry": {"area": "club_district",
			"pos": Vector3(-41.5, 0.05, -5.0), "who": "VESPER"},
	"pawn_book": {"area": "neighbourhood",
			"pos": Vector3(-18.0, 0.05, 5.4), "who": "THE OWNER"},
	"stall": {"area": "neighbourhood",
			"pos": Vector3(6.0, 0.05, 5.4), "who": "THE STALL"},
}

var _beat_wired := false


func _ready() -> void:
	add_to_group("market")


func _process(_delta: float) -> void:
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
			% int(float(WorldState.get_value("launder_cap", base))))


# --- the pools ---------------------------------------------------------------

func _pool(key: String) -> float:
	return float(WorldState.get_value(key, 0.0))


## THE PRICE OF MONEY: clean spends at par; a shop that has to
## look away charges the surcharge on the dirty part it takes.
## Returns null-shape {ok: false} when the pockets cannot cover it.
func pay(price: float, who := "") -> Dictionary:
	# after MIDNIGHT the city charges for the hour (S5.8)
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws and int(ws.beat()) % 3 == 1:
		price *= 1.0 + Tuning.v("night_premium")
	# and a hot block taxes everything (S5.12 - the street prices
	# risk into every sale)
	if float(WorldState.get_value("heat", 0.0)) >= 8.0:
		price *= 1.1
	var clean := _pool("clean_cash")
	var dirty := _pool("stash_cash")
	var clean_part := minf(clean, price)
	var dirty_need := price - clean_part
	var dirty_part := 0.0
	if dirty_need > 0.0:
		dirty_part = dirty_need * (1.0
				+ Tuning.v("dirty_spend_surcharge"))
		if dirty < dirty_part:
			return {"ok": false, "need": price - clean - dirty}
	if clean_part > 0.0:
		WorldState.set_value("clean_cash", clean - clean_part)
	if dirty_part > 0.0:
		WorldState.set_value("stash_cash", dirty - dirty_part)
	return {"ok": true, "clean": clean_part, "dirty": dirty_part}


# --- the vendors (GRAB at the body) ------------------------------------------

## GRAB at a vendor's spot. Returns true when the verb is consumed
## (the street answered, even if the answer was no).
func try_grab(hero: Node3D) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	for id in VENDORS:
		var v: Dictionary = VENDORS[id]
		if Game.area_id != str(v["area"]):
			continue
		if hero.global_position.distance_to(v["pos"]) > VENDOR_R:
			continue
		match id:
			"noodles":
				return _noodles(hero)
			"ammo":
				return _ammo(hero)
			"laundry":
				return _laundry()
			"pawn_book":
				return _pawn_book()
			"stall":
				return _stall(hero)
	return false


func _noodles(hero: Node3D) -> bool:
	var max_hp := float(hero.get("MAX_HP"))
	if float(hero.get("hp")) >= max_hp:
		WorldState.push_event("vendor_no", {"who": "OLD DEE",
				"msg": "You're full, kid. Sit anyway if you like."})
		return true
	var res := pay(Tuning.v("noodles_price"))
	if not res["ok"]:
		WorldState.push_event("vendor_no", {"who": "OLD DEE",
				"msg": "No money, no bowl."})
		return true
	hero.set("hp", max_hp)
	WorldState.push_event("vendor_yes", {"who": "OLD DEE",
			"msg": "One bowl. It helps."})
	Log.info("Market: noodles heal (%s)" % _paid_str(res))
	return true


func _ammo(hero: Node3D) -> bool:
	var gun := hero.get_node_or_null("Gun")
	if gun == null:
		return false  # no pistol in hand: not Tony's counter
	var rounds := int(Tuning.v("ammo_box_rounds"))
	if int(gun.get("reserve")) >= 72:
		WorldState.push_event("vendor_no", {"who": "TONY",
				"msg": "You're carrying all I'd sell you."})
		return true
	var price := Tuning.v("ammo_box_price")
	# the Corporation's line: their man pays half (M6's offer)
	if WorldState.flag("m6_accepted"):
		price *= Tuning.v("corp_ammo_mult")
	var res := pay(price)
	if not res["ok"]:
		WorldState.push_event("vendor_no", {"who": "TONY",
				"msg": "Cash first. Gym rule."})
		return true
	gun.call("add_reserve", rounds)
	WorldState.push_event("vendor_yes", {"who": "TONY",
			"msg": "A box of twelve. Don't wave it in here."})
	Log.info("Market: ammo +%d (%s)" % [rounds, _paid_str(res)])
	return true


## LAUNDERING: Vesper moves dirty to clean at his cut, capped by
## trust per window (the "day" is a timer stand-in until the
## day/night cycle lands).
func _laundry() -> bool:
	# the window opens on each BEAT (S5.8) with a drifted cap
	var cap := float(WorldState.get_value("launder_cap",
			Tuning.v("launder_daily_drifting")))
	var moved := float(WorldState.get_value("laundered_window", 0.0))
	var room := cap - moved
	if room <= 0.0:
		WorldState.push_event("vendor_no", {"who": "VESPER",
				"msg": "That's all I can move for you tonight."})
		return true
	var stash := _pool("stash_cash")
	if stash <= 0.0:
		WorldState.push_event("vendor_no", {"who": "VESPER",
				"msg": "Come back with something to move."})
		return true
	var amount := minf(stash, room)
	var clean := amount * (1.0 - Tuning.v("launder_cut"))
	WorldState.set_value("stash_cash", stash - amount)
	WorldState.set_value("clean_cash", _pool("clean_cash") + clean)
	WorldState.set_value("laundered_window", moved + amount)
	WorldState.push_event("vendor_yes", {"who": "VESPER",
			"msg": "Moved $%d. Your cut: $%d." % [int(amount),
					int(clean)]})
	Log.info("Market: launder $%d -> $%d clean" % [int(amount),
			int(clean)])
	return true


## THE DEBT EATS CLEAN ONLY (the Ledger's quick-pay chip).
func pay_debt(amount: float) -> bool:
	var clean := _pool("clean_cash")
	amount = minf(amount, clean)
	var debt := _pool("debt")
	amount = minf(amount, debt)
	if amount <= 0.0:
		return false
	WorldState.set_value("clean_cash", clean - amount)
	WorldState.set_value("debt", debt - amount)
	WorldState.push_event("debt_paid", {"amount": amount,
			"left": debt - amount})
	Log.info("Market: debt paid $%d, $%d stands" % [int(amount),
			int(debt - amount)])
	return true


## M4'S THIRD ANSWER: clear the owner's book with them, clean
## only (the Corporation doesn't take alley money) - and the
## grille opens for good.
func _pawn_book() -> bool:
	if WorldState.flag("pawn_paid"):
		WorldState.push_event("vendor_no", {"who": "THE OWNER",
				"msg": "My book's clear. You did that."})
		return true
	if float(WorldState.get_value("clean_cash", 0.0)) 			< Tuning.v("pawn_book_cost"):
		WorldState.push_event("vendor_no", {"who": "THE OWNER",
				"msg": "Three hundred, clean. Their rules."})
		return true
	WorldState.set_value("clean_cash",
			float(WorldState.get_value("clean_cash", 0.0))
			- Tuning.v("pawn_book_cost"))
	WorldState.set_flag("pawn_paid")
	WorldState.set_flag("door_open:THE PAWN DESK")
	Doors.open_door("THE PAWN DESK")
	WorldState.push_event("vendor_yes", {"who": "THE OWNER",
			"msg": "Cleared. The grille's open - tell the street."})
	Log.info("Market: the pawn book cleared ($300 clean)")
	return true


## THE STALL: jackets, cycled one GRAB at a time
func _stall(hero: Node3D) -> bool:
	var res := pay(Tuning.v("outfit_price"))
	if not res["ok"]:
		WorldState.push_event("vendor_no", {"who": "THE STALL",
				"msg": "Forty, or walk in what you wore."})
		return true
	var idx := (int(float(WorldState.get_value("outfit", 0))) + 1) 			% 4
	var nm: String = hero.set_outfit(idx)
	WorldState.push_event("vendor_yes", {"who": "THE STALL",
			"msg": "%s. It's you." % nm})
	return true


# --- the overnight pressure (timer stand-in) ---------------------------------

func _overnight_pressure() -> void:
	var debt := _pool("debt")
	if debt > 0.0:
		var interest := debt * Tuning.v("debt_interest_tick")
		WorldState.set_value("debt", debt + interest)
	var stash := _pool("stash_cash")
	if stash >= Tuning.v("dirty_burn_min"):
		WorldState.bump("heat", Tuning.v("dirty_burn_heat"))
		WorldState.push_event("burn_notice", {
				"msg": "That pocket is too full. Someone noticed."})
		Log.info("Market: the dirty pocket gets noticed "
				+ "(+%.1f heat)" % Tuning.v("dirty_burn_heat"))


func _paid_str(res: Dictionary) -> String:
	return "$%d clean + $%d dirty" % [int(res["clean"]),
			int(res["dirty"])]
