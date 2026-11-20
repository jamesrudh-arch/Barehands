extends Node
## Trust (bible 4D) - the phone's cost engine, autoloaded as "Trust".
## Friends 0-100, everyone starts at 70. Unanswered calls cost -6,
## and the later hangout/setup beats add their own. Tiers: Close >=60
## (helps in a fight once), Drifting 30-59 (hesitates), Estranged <30
## (stops calling). The batch-7 pass builds hangouts, setup payoffs and
## the kidnap-target pick on top of these numbers; the phone only needs
## the counters and the signal today.
##
## The Ledger always shows Trust so outcomes stay earned and visible
## (that surface lands with the Ledger batch).

signal changed(friend: String)

const FRIENDS := {
	"brother": {"name": "Brother", "color": Color(0.85, 0.55, 0.25),
		"who": "family, Brawler hands"},
	"mechanic": {"name": "The Mechanic", "color": Color(0.5, 0.8, 0.9),
		"who": "the garage, power-cut setups"},
	"club_owner": {"name": "The Club Owner", "color": Color(0.75, 0.5, 0.85),
		"who": "laundering, brawl-staging"},
	"drunk": {"name": "The Drunk", "color": Color(0.85, 0.75, 0.3),
		"who": "Drunken Boxing, lures cops"},
}

## bible 4D deltas: unanswered -6, hangout +15 (batch 7), clean setup
## +10, setup that hurts them -10.
const MISSED_CALL := -6.0
const DECLINED_CALL := -6.0
const REFUSED_DEMAND := -4.0

var _t: Dictionary = {}  # friend id -> 0..100
var _last_seen: Dictionary = {}  # friend id -> the day they last saw you


func _ready() -> void:
	for id in FRIENDS:
		_t[id] = 70.0
		_last_seen[id] = 1


## Any real contact - an answered call, a hangout - marks the friend
## as seen today, so days of silence are the only thing that drifts.
func note_interaction(friend: String) -> void:
	if FRIENDS.has(friend):
		_last_seen[friend] = Ledger.day


## The bible's 30-minute loop: skipping friends lowers trust. A friend
## you've not seen for two days drifts - Estranged friends don't
## bother anymore. Returns who drifted, for the morning report.
func day_rolled(new_day: int) -> Array:
	var drifted: Array = []
	for id in FRIENDS:
		if tier(id) == "Estranged":
			continue
		if int(_last_seen.get(id, 0)) < new_day - 1:
			add(id, -absf(float(Tuning.v("trust_skip_drift"))),
					"days without a word")
			drifted.append(FRIENDS[id]["name"])
	return drifted


func value(friend: String) -> float:
	return float(_t.get(friend, 70.0))


func add(friend: String, delta: float, why: String) -> void:
	if gone.get(friend, false):
		return  # the dead do not drift
	if locked.get(friend, false) and _t.get(friend, 100.0) + delta < 60.0:
		delta = maxf(delta, 60.0 - _t.get(friend, 100.0))  # the floor holds
	if not FRIENDS.has(friend):
		Log.warn("Trust: unknown friend '%s'" % friend)
		return
	var v := clampf(value(friend) + delta, 0.0, 100.0)
	if is_equal_approx(v, value(friend)):
		return
	_t[friend] = v
	changed.emit(friend)
	Log.info("Trust: %s %+.0f -> %.0f (%s)" % [FRIENDS[friend]["name"], delta, v, why])


## Close >=60 / Drifting 30-59 / Estranged <30 (bible 4D). The phone
## mutes rings from Estranged friends - they stop calling.
## Locked (bible 4H): saved from the kidnappers - the bond is Close
## forever and cannot decay. Gone: taken for good (paid them off, or
## the clock ran out) - the calls stop, the number goes dead.
var locked := {}
var gone := {}


func lock(friend: String) -> void:
	locked[friend] = true
	if _t.get(friend, 0.0) < 60.0:
		_t[friend] = 60.0  # Close floor
	changed.emit(friend)


func lose(friend: String) -> void:
	gone[friend] = true
	changed.emit(friend)


func is_gone(friend: String) -> bool:
	return gone.get(friend, false)


func tier(friend: String) -> String:
	if gone.get(friend, false):
		return "gone"
	var v := value(friend)
	if v >= 60.0:
		return "close"
	if v >= 30.0:
		return "drifting"
	return "estranged"


func callers() -> Array:
	## Who still calls: Close and Drifting friends.
	var out: Array = []
	for id in FRIENDS:
		if tier(id) != "estranged":
			out.append(id)
	return out


func to_dict() -> Dictionary:
	return {"values": _t.duplicate(), "last_seen": _last_seen.duplicate(),
		"locked": locked.duplicate(), "gone": gone.duplicate()}


func from_dict(d: Dictionary) -> void:
	var values: Dictionary = d.get("values", d)  # pre-B9 saves are flat
	for id in FRIENDS:
		if values.has(id):
			_t[id] = clampf(float(values[id]), 0.0, 100.0)
	var seen: Dictionary = d.get("last_seen", {})
	for id in FRIENDS:
		_last_seen[id] = int(seen.get(id, 1))
	locked = d.get("locked", {}).duplicate()
	gone = d.get("gone", {}).duplicate()


func reset_for_test() -> void:
	locked = {}
	gone = {}
	for id in FRIENDS:
		_t[id] = 70.0
		_last_seen[id] = 1
