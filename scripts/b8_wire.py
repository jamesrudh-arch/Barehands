#!/usr/bin/env python3
"""B8 wiring: the city answers the LOADED block; the map grows layers;
deaths and damage scar the blocks and persist.

city.gd         BLOCK_INFO (names/blurbs), set_current_district(),
                district_at() -> current block, damage/death points +
                persistence, rumor() pools, on_violence scars
retry_offer.gd  a lapsed offer means a death: the spot is remembered
phone_ui.gd     map cards: name/blurb + MOOD/HEAT/FRIENDS/DAMAGE chips,
                unvisited blocks stay "???"
trainer.gd      the placeholder points at the Block 2 gym (bible 6)
project.godot   the Blocks autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:80])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


patch("scripts/city.gd", [
    # block identities + the current-block model
    (
        '''const DISTRICTS := ["riverside", "market", "foundry"]''',
        '''const DISTRICTS := ["riverside", "market", "foundry"]

## What each block IS (bible 6), for the map and the rumors.
const BLOCK_INFO := {
	"riverside": {"name": "RIVERSIDE ROW",
		"blurb": "your block - the alley, the noodle shop, the bar"},
	"market": {"name": "THE CLUB QUARTER",
		"blurb": "main street, the gym, the Mechanic's garage"},
	"foundry": {"name": "THE DOCKS",
		"blurb": "the warehouse, the water, the shut door"},
}''',
    ),
    # the current district: set by the Blocks walk, not by x bands
    (
        '''func district_at(pos: Vector3) -> String:
	if pos.x < -6.0:
		return "riverside"
	if pos.x > 6.0:
		return "foundry"
	return "market"''',
        '''func district_at(pos: Vector3) -> String:
	# batch 8: one block = one district; the loaded block answers
	return Blocks.current()


## The walk between blocks lands here (fog, music and moods ride the
## signal). Guarded so nothing re-broadcasts the same block.
func set_current_district(d: String) -> void:
	if d == _district_now:
		return
	_district_now = d
	entered_district.emit(d, mood_of(d))
	changed.emit()


## The scars a block carries (bible 6 damage layer): where bodies
## dropped, and where the hero died. LOCAL to each block.
var _damage: Dictionary = {}   # block -> [{pos: Vector3}]
var _deaths: Dictionary = {}   # block -> [{pos: Vector3}]
const DAMAGE_CAP := 12


func note_damage(pos: Vector3, kind: String) -> void:
	var d := district_at(pos)
	var local := Vector3(pos.x - Blocks.BLOCK_X[d], pos.y, pos.z)
	var list: Array = _damage.get(d, [])
	list.append({"pos": local, "kind": kind})
	while list.size() > DAMAGE_CAP:
		list.pop_front()
	_damage[d] = list
	changed.emit()


func note_death(pos: Vector3) -> void:
	var d := district_at(pos)
	var local := Vector3(pos.x - Blocks.BLOCK_X[d], pos.y, pos.z)
	var list: Array = _deaths.get(d, [])
	list.append({"pos": local})
	while list.size() > 6:
		list.pop_front()
	_deaths[d] = list
	Log.info("City: someone died in the %s - the block remembers" % d)


func damage_points(d: String) -> Array:
	var pts: Array = []
	for e in _damage.get(d, []):
		pts.append(e["pos"])
	return pts


func death_points(d: String) -> Array:
	var pts: Array = []
	for e in _deaths.get(d, []):
		pts.append(e["pos"])
	return pts''',
    ),
    # violence leaves a scar where it happens
    (
        '''		"knockdown":
			add_rep(d, -8.0, "a body dropped in the " + d)''',
        '''		"knockdown":
			add_rep(d, -8.0, "a body dropped in the " + d)
			note_damage(pos, "scorch")''',
    ),
    (
        '''		"shot":
			add_rep(d, -4.0, "a gunshot in the " + d)''',
        '''		"shot":
			add_rep(d, -4.0, "a gunshot in the " + d)
			note_damage(pos, "scorch")''',
    ),
    # rumor pools for the wanderers and the shop owner
    (
        '''func to_dict() -> Dictionary:''',
        '''## What the street whispers on a given block: the mood, the last
## thing anyone saw, and the block's own weather.
func rumor(d: String) -> Array:
	var pool: Array = []
	match mood_of(d):
		"your street":
			pool.append("this block still says your name right")
			pool.append("nobody starts anything on this street")
		"friendly":
			pool.append("good night for it, they say")
			pool.append("the %s's been quiet since you cleaned it up" % d)
		"wary":
			pool.append("people cross the road when you pass lately")
		"turning hostile":
			pool.append("stay off this block a while. just a while")
		"hostile":
			pool.append("you shouldn't be walking here")
	var heard := last_heard(d)
	if not heard.is_empty():
		pool.append("they're saying: " + heard)
	return pool if not pool.is_empty() else ["quiet night"]


## One line, for the wanderers' bubbles.
func rumor_line(d: String) -> String:
	var pool := rumor(d)
	return pool[randi() % pool.size()]


func to_dict() -> Dictionary:''',
    ),
])

# persistence: damage + deaths ride the city dict
s = open(P + "scripts/city.gd").read()
old = '''	"hostile": hostile.duplicate(true),'''
assert s.count(old) == 1
s = s.replace(old, '''	"hostile": hostile.duplicate(true),
	"damage": _damage.duplicate(true),
	"deaths": _deaths.duplicate(true),''')
old2 = '''	for dd in DISTRICTS:'''
# from_dict re-inits per district; append the scar restore after the loop
i = s.index("func from_dict")
j = s.index("\n\n", i)
block = s[i:j]
assert '"damage"' not in block
new_block = block.replace('''func from_dict(d: Dictionary) -> void:''',
'''func from_dict(d: Dictionary) -> void:
	_damage = d.get("damage", {}).duplicate(true)
	_deaths = d.get("deaths", {}).duplicate(true)''', 1)
s = s[:i] + new_block + s[j:]
open(P + "scripts/city.gd", "w").write(s)
print("patched scripts/city.gd (persist)")

patch("scripts/phone.gd", [
    (
        """func _ready() -> void:
	City.entered_district.connect(_on_district)""",
        """func _ready() -> void:
	# your home block is never fogged (bible 6 fog of war)
	_visited["riverside"] = true
	City.entered_district.connect(_on_district)""",
    ),
])

patch("scripts/retry_offer.gd", [
    (
        '''		Ledger.death_debt()''',
        '''		Ledger.death_debt()
		# the block remembers where it happened (bible 6 memorials)
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			City.note_death(p.global_position)''',
    ),
])

patch("scripts/phone_ui.gd", [
    # map cards grow the bible's layers (jobs wait for the jobs batch)
    (
        '''	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)''',
        '''	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	# batch 8: the block's name + blurb, or the fog
	if Phone.has_visited(district):
		col.add_child(_label(City.BLOCK_INFO[district]["name"], 13,
				Color(0.85, 0.88, 0.9)))
		col.add_child(_label(City.BLOCK_INFO[district]["blurb"], 10,
				Color(0.55, 0.58, 0.62)))
		col.add_child(_map_layers(district, is_now))
	else:
		col.add_child(_label("???", 13, Color(0.4, 0.4, 0.45)))
		col.add_child(_label("not walked yet", 10,
				Color(0.35, 0.35, 0.4)))''',
    ),
])

# the layers row itself appends after _map_card
s = open(P + "scripts/phone_ui.gd").read()
anchor = '''func _map_card(district: String, is_now: bool) -> PanelContainer:'''
assert s.count(anchor) == 1
layers_fn = '''## The bible's map layers, minus jobs (they have no source until the
## jobs batch - no dead chips): mood, heat, friends, damage.
func _map_layers(district: String, is_now: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var who: Array = []
	for fid in Trust.FRIENDS:
		if Blocks.FRIEND_HOMES.get(fid, "") == district:
			who.append(Trust.FRIENDS[fid]["name"])
	var chips := [
		["MOOD " + City.mood_of(district), Color(0.6, 0.8, 0.65)],
		["HEAT " + "*".repeat(roundi(clampf(Heat.heat, 0.0, 5.0))),
				Color(0.95, 0.55, 0.3)],
		["FRIENDS " + ("+".join(who) if not who.is_empty() else "-"),
				Color(0.55, 0.75, 0.9)],
		["DAMAGE %d" % City.damage_points(district).size(),
				Color(0.85, 0.5, 0.5)],
	]
	for c in chips:
		var chip := _label(c[0], 9, c[1] if is_now else c[1].darkened(0.35))
		row.add_child(chip)
	return row


'''
s = s.replace(anchor, layers_fn + anchor, 1)
open(P + "scripts/phone_ui.gd", "w").write(s)
print("patched scripts/phone_ui.gd (layers)")

patch("scripts/trainer.gd", [
    (
        '''## the hero's GRAB near the trainer opens
## the MOVES screen to teach and practise. The gym/tournament batch wires
## the real dialogue through cast.gd and replaces this silhouette.''',
        '''## the hero's GRAB near the trainer opens
## the MOVES screen to teach and practise. The real gym is in the club
## quarter (walk east through the gate; bible 6 places the fight club
## there with the underground tournaments) - the tournament batch wires
## its door and replaces this silhouette.''',
    ),
])

patch("project.godot", [(
    '''FriendHelp="*res://scripts/friend_help.gd"''',
    '''FriendHelp="*res://scripts/friend_help.gd"
Blocks="*res://scripts/blocks.gd"''',
)])

print("B8 wiring complete")
