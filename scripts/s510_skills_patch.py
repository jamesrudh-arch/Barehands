#!/usr/bin/env python3
## S5.10 THE SKILLS PASS: the five disciplines become LEARNED, not
## given - M2 teaches Kickboxing at Tony's counter, M3's Old Dee
## teaches the Drunken hint; M4's third answer (clear the owner's
## book, $300 clean) opens THE PAWN DESK; the clothing stall sells
## outfits (the jacket's real material tint).
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ------------------------------------------------------------- tuning keys
patch('scripts/tuning.gd', [
(
"""	"taxi_fare": 25.0,  # the cab rides clean, any corner of the city""",
"""	"taxi_fare": 25.0,  # the cab rides clean, any corner of the city
	"pawn_book_cost": 300.0,  # M4's third answer clears his book
	"outfit_price": 40.0,  # the stall's jackets"""
),
])

# ------------------------------------------------------------ game defaults
patch('scripts/core/game.gd', [
(
"""	WorldState.set_value("debt_corp", Tuning.v("debt_start_corp"))
	await travel("warehouse", "start")""",
"""	WorldState.set_value("debt_corp", Tuning.v("debt_start_corp"))
	# the disciplines are LEARNED from people: you start with your
	# fists (and the pistol you already carry); the teachers hand
	# over the rest (M2 Kickboxing, M3 Drunken, the Collector later)
	WorldState.set_value("unlocked_styles", ["brawler", "weapon"])
	await travel("warehouse", "start")"""
),
])

# ------------------------------------------------------------ combat gate
patch('scripts/player/combat.gd', [
(
"""func set_style(id: String) -> void:
	if not STYLES.has(id):
		return""",
"""func set_style(id: String) -> void:
	if not STYLES.has(id):
		return
	# learned, never given (S5.10): a locked discipline is a
	# teacher you haven't met
	if not _style_unlocked(id):
		return


func _style_unlocked(id: String) -> bool:
	var unlocked: Array = WorldState.get_value("unlocked_styles",
			["brawler"])
	return unlocked.has(id)


func unlock_style(id: String) -> bool:
	if not STYLES.has(id) or _style_unlocked(id):
		return false
	var unlocked: Array = WorldState.get_value("unlocked_styles",
			["brawler"])
	unlocked.append(id)
	WorldState.set_value("unlocked_styles", unlocked)
	style_changed.emit(id)
	Log.info("Combat: LEARNED %s (the stance is yours)" % id)
	return true"""
),
])

# ------------------------------------------------------------- hero surface
patch('scripts/player/hero.gd', [
(
"""## The style cycle (the hold-flick wheel lands with the HUD step;
## until then the STYLE action walks the five in order).
func _cycle_style() -> void:
	var order := ["brawler", "kickboxing", "grappling", "drunken", "weapon"]
	var i := order.find(_combat.style_id)
	_combat.set_style(order[(i + 1) % order.size()])
	Log.info("Hero: style -> %s" % _combat.style_id)""",
"""## The style cycle (the hold-flick wheel lands with the HUD step;
## until then the STYLE action walks the LEARNED ones in order).
func _cycle_style() -> void:
	var order: Array = WorldState.get_value("unlocked_styles",
			["brawler"])
	if order.size() < 2:
		return  # one stance is not a cycle
	var i: int = order.find(_combat.style_id)
	if i < 0:
		i = 0
	_combat.set_style(order[(i + 1) % order.size()])
	Log.info("Hero: style -> %s" % _combat.style_id)


## a teacher hands over a discipline (missions call this at the
## teach spot); it lands already worn
func unlock_style(id: String) -> bool:
	if _combat == null or not is_instance_valid(_combat):
		return false
	var got := _combat.unlock_style(id)
	if got:
		_combat.set_style(id)
	return got


## THE OUTFIT (the stall's jackets): the real jacket material tint
const OUTFITS := [["THE WORK JACKET", Color(1.0, 1.0, 1.0)],
	["THE CRIMSON", Color(1.0, 0.32, 0.3)],
	["THE SLATE", Color(0.42, 0.48, 0.62)],
	["THE GOLD", Color(0.95, 0.78, 0.3)]]

func set_outfit(idx: int) -> String:
	var mesh := _find_mesh("Wolf3D_Outfit_Top")
	if mesh == null:
		return ""
	var mat := (mesh as MeshInstance3D).get_active_material(0)
	if mat == null:
		return ""
	var pick := OUTFITS[idx % OUTFITS.size()]
	mat.albedo_color = pick[1]
	WorldState.set_value("outfit", idx)
	Log.info("Hero: outfit -> %s" % pick[0])
	return pick[0]


func _find_mesh(nm: String) -> Node:
	for c in find_children("*", "MeshInstance3D", true, false):
		if str((c as Node).name).contains(nm):
			return c
	return null


func outfit_name() -> String:
	var idx := int(float(WorldState.get_value("outfit", 0)))
	return OUTFITS[idx % OUTFITS.size()][0]"""
),
])

# --------------------------------------------------- the missions teach spots
patch('scripts/missions/missions.gd', [
(
"""	WorldState.set_flag(str(st["grab_flag"]))
	WorldState.push_event("choice", {"what": str(st["grab_flag"])})
	Log.info("Mission: the grab answers (%s)" % st["grab_flag"])
	return true""",
"""	WorldState.set_flag(str(st["grab_flag"]))
	WorldState.push_event("choice", {"what": str(st["grab_flag"])})
	# a teach stage hands over the discipline, already worn
	if st.has("teach"):
		hero.unlock_style(str(st["teach"]))
	Log.info("Mission: the grab answers (%s)" % st["grab_flag"])
	return true"""
),
])

# m2 + m3 gain their teach stages (python rewrites the tres chains)
for path, stage, nextid in [
    ('data/missions/m2.tres', None, None),
    ('data/missions/m3.tres', None, None),
]:
    pass  # (handled below with dedicated inserts)

def tres_patch(path, old, new):
    s = open(path).read()
    if old not in s:
        print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
    open(path, 'w').write(s.replace(old, new, 1))

# m2: the gym fight ends with Tony's counter lesson
tres_patch('data/missions/m2.tres',
'''"marker": Vector3(-35.5, 1.2, 8.4),
"objective": "Tony's way: put his two muscle men down"
}]''',
'''"marker": Vector3(-35.5, 1.2, 8.4),
"objective": "Tony's way: put his two muscle men down"
}, {
"area": "club_district",
"check": "any_flag",
"flags": ["skill_kickboxing"],
"grab_flag": "skill_kickboxing",
"teach": "kickboxing",
"marker": Vector3(-35.5, 1.2, 5.0),
"objective": "Tony pays in lessons - take the KICKBOXING stance (GRAB at the counter)"
}]''')

# m3: the bottle ends in Dee's Drunken hint
tres_patch('data/missions/m3.tres',
'''"marker": Vector3(-4.6, 1.2, 5.4),
"objective": "Bring the bottle back to Marla"
}]''',
'''"marker": Vector3(-4.6, 1.2, 5.4),
"objective": "Bring the bottle back to Marla"
}, {
"area": "neighbourhood",
"check": "any_flag",
"flags": ["skill_drunken"],
"grab_flag": "skill_drunken",
"teach": "drunken",
"marker": Vector3(-40.4, 1.2, 5.4),
"objective": "Old Dee's payment is a secret - the DRUNKEN hint (GRAB at his counter)"
}]''')

# --------------------------------------------------------- market vendors
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
