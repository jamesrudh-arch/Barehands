#!/usr/bin/env python3
"""B9 wiring: the day rolls and the world answers.

ledger.gd     signal day_rolled(day, interest, missed) + end_day_early()
trust.gd      note_interaction + day_rolled skip-drift + persistence
city.gd       witnessed entries carry the day + age_rumors()
phone.gd      answering a friend call counts as seeing them
hangout.gd    a hangout counts as seeing them
safehouse.gd  the SLEEP button (end the day, save, wake to the report)
tuning.gd     overnight_heat_cool / trust_skip_drift / rumor_age_days
project.godot the WorldSim autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:80])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


patch("scripts/ledger.gd", [
    (
        "signal changed()",
        """signal changed()
## The day closed (beats out, or slept away): new day number, the
## interest that day cost, and whether the payment was missed. The
## world sim listens and turns the city over.
signal day_rolled(new_day: int, interest_charged: float, missed: bool)""",
    ),
    (
        """func _day_end() -> void:
	# interest already accrued continuously; the day just closes the books
	if _paid_today + 0.5 < _interest_today:
		_miss_payment()
	_interest_today = 0.0
	_paid_today = 0.0
	day += 1
	beats_left = 3  # the new day's three beats (Dusk, Midnight, 3 AM)
	Phone.push_text("family",
			"The Family: \\"Day %d closes. The numbers wait for no one.\\"" % day)
	Haptics.fire("tick")  # the faint debt-tick pulse (bible 7)
	_tick_count += 1
	changed.emit()""",
        """func _day_end() -> void:
	# interest already accrued continuously; the day just closes the books
	var charged := _interest_today
	var missed := false
	if _paid_today + 0.5 < _interest_today:
		_miss_payment()
		missed = true
	_interest_today = 0.0
	_paid_today = 0.0
	day += 1
	beats_left = 3  # the new day's three beats (Dusk, Midnight, 3 AM)
	Phone.push_text("family",
			"The Family: \\"Day %d closes. The numbers wait for no one.\\"" % day)
	Haptics.fire("tick")  # the faint debt-tick pulse (bible 7)
	_tick_count += 1
	day_rolled.emit(day, charged, missed)
	changed.emit()


## Sleep at the safehouse: close the day early. Leftover beats never
## carry over - the bible's budget has no banking.
func end_day_early() -> void:
	_day_end()""",
    ),
])

patch("scripts/trust.gd", [
    (
        "var _t: Dictionary = {}  # friend id -> 0..100",
        """var _t: Dictionary = {}  # friend id -> 0..100
var _last_seen: Dictionary = {}  # friend id -> the day they last saw you""",
    ),
    (
        """func _ready() -> void:
	for id in FRIENDS:
		_t[id] = 70.0""",
        """func _ready() -> void:
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
			add(id, float(Tuning.v("trust_skip_drift")), "days without a word")
			drifted.append(FRIENDS[id]["name"])
	return drifted""",
    ),
])

# persistence for _last_seen (clean patch on the real bodies)
patch("scripts/trust.gd", [
    (
        """func to_dict() -> Dictionary:
	return _t.duplicate()


func from_dict(d: Dictionary) -> void:
	for id in FRIENDS:
		if d.has(id):
			_t[id] = clampf(float(d[id]), 0.0, 100.0)


func reset_for_test() -> void:
	for id in FRIENDS:
		_t[id] = 70.0""",
        """func to_dict() -> Dictionary:
	return {"values": _t.duplicate(), "last_seen": _last_seen.duplicate()}


func from_dict(d: Dictionary) -> void:
	var values: Dictionary = d.get("values", d)  # pre-B9 saves are flat
	for id in FRIENDS:
		if values.has(id):
			_t[id] = clampf(float(values[id]), 0.0, 100.0)
	var seen: Dictionary = d.get("last_seen", {})
	for id in FRIENDS:
		_last_seen[id] = int(seen.get(id, 1))


func reset_for_test() -> void:
	for id in FRIENDS:
		_t[id] = 70.0
		_last_seen[id] = 1""",
    ),
])

patch("scripts/city.gd", [
    (
        """func remember(d: String, event: String) -> void:
	witnessed[d].append({"event": event, "time": Time.get_time_string_from_system()})""",
        """func remember(d: String, event: String) -> void:
	witnessed[d].append({"event": event,
			"time": Time.get_time_string_from_system(), "day": Ledger.day})""",
    ),
    (
        """# --- hostility -----------------------------------------------------------------------""",
        """## The street forgets slowly (world sim): rumors older than the
## tuning's days stop being retold. Returns how many were let go.
func age_rumors(new_day: int) -> int:
	var keep_days := int(Tuning.v("rumor_age_days"))
	var pruned := 0
	for d in DISTRICTS:
		var keep: Array = []
		for e in witnessed[d]:
			if int(e.get("day", 1)) >= new_day - keep_days:
				keep.append(e)
			else:
				pruned += 1
		witnessed[d] = keep
	return pruned


# --- hostility -----------------------------------------------------------------------""",
    ),
])

patch("scripts/phone.gd", [
    (
        """	_last_caller = _ring_caller
	_last_kind = _ring_kind
	_ring_caller = \"\"""",
        """	_last_caller = _ring_caller
	_last_kind = _ring_kind
	# an answered call is seeing them (world sim: days of silence drift)
	if Trust.FRIENDS.has(_last_caller):
		Trust.note_interaction(_last_caller)
	_ring_caller = \"\"""",
    ),
])

s = open(P + "scripts/hangout.gd").read()
old = '''	Trust.add(friend, trust_gain, "hangout: %s (%s)" % [_theme["game"], grade])'''
assert s.count(old) == 1
s = s.replace(old, '''	Trust.add(friend, trust_gain, "hangout: %s (%s)" % [_theme["game"], grade])
	Trust.note_interaction(friend)  # a hangout is seeing them''')
open(P + "scripts/hangout.gd", "w").write(s)
print("patched scripts/hangout.gd")

patch("scripts/safehouse.gd", [
    (
        '''	var choices: Array = [["SAVE", _save], ["LOAD", _load]]''',
        '''	var choices: Array = [["SAVE", _save], ["LOAD", _load],
			["SLEEP - end the day", _sleep]]''',
    ),
    (
        '''func _save() -> void:''',
        '''## Sleep: forfeit the day's leftover beats, close the books, save,
## and wake to the morning report (the world sim owns the night).
func _sleep() -> void:
	_close()
	WorldSim.sleep()


func _save() -> void:''',
    ),
])

patch("scripts/tuning.gd", [
    (
        '''	"beat_real_seconds": 360.0,''',
        '''	"beat_real_seconds": 360.0,
	"overnight_heat_cool": 1.0,  # stars the night takes off (world sim)
	"trust_skip_drift": -2.0,  # per day unseen, Warm+ friends (bible loop 2)
	"rumor_age_days": 2,  # days a street rumor stays in retelling''',
    ),
])

patch("project.godot", [(
    '''Blocks="*res://scripts/blocks.gd"''',
    '''Blocks="*res://scripts/blocks.gd"
WorldSim="*res://scripts/world_sim.gd"''',
)])

print("B9 wiring complete")
