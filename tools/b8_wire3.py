#!/usr/bin/env python3
"""B8 wiring part 3: map card name/blurb/layers, trainer pointer, the
Blocks autoload (parts 1-2 already applied)."""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:80])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


patch("scripts/phone_ui.gd", [
    (
        '''	if Phone.has_visited(district):
		col.add_child(_label(district.to_upper(), 16,
				Color(0.92, 0.95, 0.98)))
		col.add_child(_label("here" if is_now else " ", 12, CYAN if is_now else Color(0.4, 0.4, 0.45)))
	else:
		col.add_child(_label("???", 16, Color(0.3, 0.3, 0.35)))
		col.add_child(_label("not yet walked", 12, Color(0.3, 0.3, 0.35)))
	return card''',
        '''	if Phone.has_visited(district):
		col.add_child(_label(City.BLOCK_INFO[district]["name"], 15,
				Color(0.92, 0.95, 0.98)))
		col.add_child(_label(City.BLOCK_INFO[district]["blurb"], 10,
				Color(0.55, 0.58, 0.62)))
		col.add_child(_map_layers(district, is_now))
		col.add_child(_label("here" if is_now else " ", 11,
				CYAN if is_now else Color(0.4, 0.4, 0.45)))
	else:
		col.add_child(_label("???", 16, Color(0.3, 0.3, 0.35)))
		col.add_child(_label("not yet walked", 12, Color(0.3, 0.3, 0.35)))
	return card''',
    ),
])

# the layers row, before _map_card
s = open(P + "scripts/phone_ui.gd").read()
anchor = '''func _map_card(district: String, is_now: bool) -> PanelContainer:'''
assert s.count(anchor) == 1
layers_fn = '''## The bible's map layers, minus jobs (no source until the jobs batch -
## no dead chips): mood, heat, friends, damage.
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
        '''## the MOVES screen to teach and practise. The gym/tournament batch wires
## the real dialogue through cast.gd and replaces this silhouette.''',
        '''## the MOVES screen to teach and practise. The real gym is in the club
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

print("B8 wiring part 3 complete")
