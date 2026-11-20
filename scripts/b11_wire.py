#!/usr/bin/env python3
"""B11 wiring: the kidnap arc goes live.

trust.gd      locked (Close forever, cannot decay) and gone (dead,
              calls stop) friend states - the arc's two endings
heat.gd       a permanent enemy keeps a heat floor under you
phone.gd      the UNKNOWN NUMBER: cold + payoff calls, choices wired
              to the arc; a sender entry for the banner
phone_ui.gd   the ring/call screens name non-friend callers too
world_sim.gd  the day roll drives the arc clock + morning lines
tuning.gd     the arc's numbers
project.godot the Kidnap autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# 1. trust: the two permanent states
patch("scripts/trust.gd", [(
    """func tier(friend: String) -> String:""",
    """## Locked (bible 4H): saved from the kidnappers - the bond is Close
## forever and cannot decay. Gone: taken for good (paid them off, or
## the clock ran out) - the calls stop, the number goes dead.
var locked := {}
var gone := {}


func lock(friend: String) -> void:
	locked[friend] = true
	if trust.get(friend, 0.0) < 60.0:
		trust[friend] = 60.0  # Close floor
	changed.emit(friend)


func lose(friend: String) -> void:
	gone[friend] = true
	changed.emit(friend)


func is_gone(friend: String) -> bool:
	return gone.get(friend, false)


func tier(friend: String) -> String:
	if gone.get(friend, false):
		return "gone\"""",
), (
    """func add(friend: String, delta: float, why: String) -> void:""",
    """func add(friend: String, delta: float, why: String) -> void:
	if gone.get(friend, false):
		return  # the dead do not drift
	if locked.get(friend, false) and trust.get(friend, 100.0) + delta < 60.0:
		delta = 60.0 - trust.get(friend, 100.0)  # the Close floor holds""",
)])

# 2. trust persistence carries the new sets
patch("scripts/trust.gd", [(
    """func to_dict() -> Dictionary:""",
    """func to_dict() -> Dictionary:""",
)])
s = open(P + "scripts/trust.gd").read()
import re
m = re.search(r"func to_dict\(\) -> Dictionary:\n(.*?)\n\n\n", s, re.S)
assert m, "trust to_dict body not found"
print("trust to_dict body:", m.group(1).replace("\n", " | "))

# 3. heat: the permanent enemy's floor
patch("scripts/heat.gd", [(
    """func add(amount: float) -> void:""",
    """## The kidnap arc's permanent enemy (bible 4H): the heat never fully
## cools while they own the streets' fear.
func _enemy_floor() -> void:
	if Kidnap.permanent_enemy and heat < float(Tuning.v("kidnap_enemy_floor")):
		heat = float(Tuning.v("kidnap_enemy_floor"))


func add(amount: float) -> void:""",
)])

# 4. phone: the UNKNOWN NUMBER + the arc's choices
patch("scripts/phone.gd", [(
    """const LEDGER_SENDERS := {
	"family": {"name": "The Family", "color": Color(0.85, 0.35, 0.25)},
	"corp": {"name": "The Corporation", "color": Color(0.4, 0.75, 1.0)},
	"crew": {"name": "The Crew", "color": Color(0.9, 0.8, 0.35)},
}""",
    """const LEDGER_SENDERS := {
	"family": {"name": "The Family", "color": Color(0.85, 0.35, 0.25)},
	"corp": {"name": "The Corporation", "color": Color(0.4, 0.75, 1.0)},
	"crew": {"name": "The Crew", "color": Color(0.9, 0.8, 0.35)},
	"kidnapper": {"name": "UNKNOWN NUMBER", "color": Color(0.8, 0.55, 0.3)},
}""",
), (
    '''	"brother": {
		"demand": {''',
    '''	"kidnapper": {
		"cold": {
			"lines": [
				"UNKNOWN NUMBER: \\"We have the one you call by name.\\"",
				"UNKNOWN NUMBER: \\"No cops. Twelve hundred by Friday, or we stop feeding them.\\"",
				"UNKNOWN NUMBER: \\"You have three days. Decide.\\"",
			],
			"choice": {"pay_ransom": "PAY $1200", "trace": "NO COPS - I'LL FIND THEM"},
		},
		"payoff": {
			"lines": [
				"UNKNOWN NUMBER: \\"The boss liked your work. Shame about the rest.\\"",
				"UNKNOWN NUMBER: \\"Walk away. Three thousand, and we keep them. Nobody's enemy.\\"",
				"UNKNOWN NUMBER: \\"Last decision. Make it.\\"",
			],
			"choice": {"save": "CUT THEM DOWN", "take": "TAKE THE MONEY"},
		},
	},
	"brother": {
		"demand": {''',
), (
    """	hang_up()


func hang_up() -> void:""",
    """	# the kidnap arc's choices (bible 4H): the arc owns the outcomes
	if caller_id() == "kidnapper":
		Kidnap.on_call_choice(call_kind(), option)
		_log_entry({"caller": "kidnapper", "kind": call_kind(),
			"outcome": option})
	hang_up()


func hang_up() -> void:""",
)])

# 5. phone_ui: non-friend callers get their sender name on both screens
patch("scripts/phone_ui.gd", [(
    """		var who: Dictionary = Trust.FRIENDS.get(Phone.caller_id(), {})
		_banner_name.text = who.get("name", "?")""",
    """		var who: Dictionary = Phone.sender(Phone.caller_id())
		_banner_name.text = who.get("name", "?")""",
), (
    """	var who: Dictionary = Trust.FRIENDS.get(Phone.caller_id(), {})
	_call_name.text = who.get("name", "?")""",
    """	var who: Dictionary = Phone.sender(Phone.caller_id())
	_call_name.text = who.get("name", "?")""",
)])

# 6. world_sim: the arc clock + the morning lines
patch("scripts/world_sim.gd", [(
    """	var pruned := City.age_rumors(new_day)""",
    """	for line in Kidnap.morning_lines():
		lines.append(line)
	var pruned := City.age_rumors(new_day)""",
), (
    """	Jobs.on_day_rolled(new_day)""",
    """	Jobs.on_day_rolled(new_day)
	Kidnap.on_day_rolled(new_day)""",
)])

# 7. tuning: the arc's numbers
patch("scripts/tuning.gd", [(
    '''	"job_overuse_at": 3,  # setups through one friend before their business eats it''',
    '''	"job_overuse_at": 3,  # setups through one friend before their business eats it
	"kidnap_min_day": 3,  # the arc waits until the loop has teeth
	"kidnap_min_trust": 40,  # someone must matter enough to take
	"kidnap_days": 3,  # days before they stop feeding them
	"kidnap_ransom": 1200,  # the cold call's price
	"kidnap_payoff": 3000,  # the devil's offer
	"kidnap_enemy_floor": 1.5,  # permanent enemy: heat never cools below''',
)])

# 8. the autoload
patch("project.godot", [(
    '''Jobs="*res://scripts/jobs.gd"''',
    '''Jobs="*res://scripts/jobs.gd"
Kidnap="*res://scripts/kidnap.gd"''',
)])

# trust to_dict/from_dict carry the new sets
s = open(P + "scripts/trust.gd").read()
i = s.index("func to_dict() -> Dictionary:")
j = s.index("func from_dict", i)
old = s[i:j]
assert '"trust": trust.duplicate()' in old, old
new = old.replace('"trust": trust.duplicate()',
                  '"trust": trust.duplicate(), "locked": locked.duplicate(),\n\t\t"gone": gone.duplicate()')
s = s[:i] + new + s[j:]
i = s.index("func from_dict")
seg = s[i:]
old2 = seg[:seg.index("\n\n\n")]
assert "trust" in old2, old2
print("trust from_dict body:", old2.replace("\n", " | "))
new2 = old2 + '''

	locked = d.get("locked", {}).duplicate()
	gone = d.get("gone", {}).duplicate()'''
s = s[:i] + new2 + seg[seg.index("\n\n\n"):len(seg)+(len(new2)-len(old2)):]
open(P + "scripts/trust.gd", "w").write(s)
print("trust persistence carries locked/gone")

print("B11 wiring complete")
