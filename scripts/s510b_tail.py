#!/usr/bin/env python3
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))
patch('scripts/core/market.gd', [
# the pawn book + the stall join the vendor table
(
"""	"laundry": {"area": "club_district",
			"pos": Vector3(-41.5, 0.05, -5.0), "who": "VESPER"},
}""",
"""	"laundry": {"area": "club_district",
			"pos": Vector3(-41.5, 0.05, -5.0), "who": "VESPER"},
	"pawn_book": {"area": "neighbourhood",
			"pos": Vector3(-18.0, 0.05, 5.4), "who": "THE OWNER"},
	"stall": {"area": "neighbourhood",
			"pos": Vector3(6.0, 0.05, 5.4), "who": "THE STALL"},
}"""
),
# the dispatch gains the two verbs
(
"""		match id:
			"noodles":
				return _noodles(hero)
			"ammo":
				return _ammo(hero)
			"laundry":
				return _laundry()
	return false""",
"""		match id:
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
	return false"""
),
# the two behaviors, beside the laundry
(
"""# --- the overnight pressure (timer stand-in) ---------------------------------""",
"""## M4'S THIRD ANSWER: clear the owner's book with them, clean
## only (the Corporation doesn't take alley money) - and the
## grille opens for good.
func _pawn_book() -> bool:
	if WorldState.flag("pawn_paid"):
		WorldState.push_event("vendor_no", {"who": "THE OWNER",
				"msg": "My book's clear. You did that."})
		return true
	if float(WorldState.get_value("clean_cash", 0.0)) \
			< Tuning.v("pawn_book_cost"):
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
	var idx := (int(float(WorldState.get_value("outfit", 0))) + 1) \
			% 4
	var nm: String = hero.set_outfit(idx)
	WorldState.push_event("vendor_yes", {"who": "THE STALL",
			"msg": "%s. It's you." % nm})
	return true


# --- the overnight pressure (timer stand-in) ---------------------------------"""
),
])

# the doors: the open flag re-applies at build + a runtime opener
patch('scripts/world/doors.gd', [
(
"""	if WorldState.flag("door_broken:" + label):
		law["state"] = "broken"
		law["hits_left"] = 0
	if law["state"] == "locked":
		_build_leaf(front, law)""",
"""	if WorldState.flag("door_broken:" + label):
		law["state"] = "broken"
		law["hits_left"] = 0
	# the paid book opens the grille (M4's third answer)
	if law["state"] == "locked" \
			and WorldState.flag("door_open:" + label):
		law["state"] = "open"
	if law["state"] == "locked":
		_build_leaf(front, law)"""
),
(
"""func _build_leaf(front: Node3D, law: Dictionary) -> void:""",
"""## a gratitude open at runtime (the current scene's leaf swings)
func open_door(label: String) -> void:
	if not _doors.has(label):
		return
	var law: Dictionary = _doors[label]
	if str(law.get("state", "")) != "locked":
		return
	law["state"] = "open"
	_leaf_set_open(law, false)
	_say(law, "OPEN - for you")
	Log.info("Doors: %s opens (the book was cleared)" % label)


func _build_leaf(front: Node3D, law: Dictionary) -> void:"""
),
])
print("SKILLS WIRED")

# the vendor dispatch: find it to add the two new behaviors
s = open('scripts/core/market.gd').read()
old = '''	_check(ms and false, "dispatch placeholder")'''
print("marker found" if old in s else "dispatch marker MISS - inspect below")
