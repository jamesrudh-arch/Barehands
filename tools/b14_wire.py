#!/usr/bin/env python3
"""B14 wiring: the difficulty knobs (bible 5 polish pass).

Three streets to walk, one Setting. STREET is the night as written
(bible 14 defaults, untouched - every old suite stays green). HARD
and BRUTAL turn three screws the player can feel: enemies take more
sticks to drop, their tells come faster (the read tightens), and
hits drain more Composure (mistakes cost more). All numbers live in
tuning.gd as flat keys so run_tests' all-values->-0 sanity rule
holds.

settings.gd    the "difficulty" key (street/hard/brutal) + a
               diff_mult() helper that maps a lever name to the
               active tier's multiplier
tuning.gd      hard_* / brutal_* multipliers (hp, telegraph,
               composure)
enemy.gd       max_hp scales at spawn (after the kind floors);
               telegraph scales (the read tightens)
composure.gd   drain scales (hits cost more)
settings_ui.gd a THE FIGHT picker: three buttons, the active one
               highlighted, noir one-liners as tooltips
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        if old not in s:
            assert new in s, "%s: not found: %r" % (path, old[:70])
            continue  # already applied (idempotent)
        assert s.count(old) == 1, "%s: not unique: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# 1. settings: the difficulty key + the multiplier helper
patch("scripts/settings.gd", [
    (
        '''	"shake_scale": 1.0,''',
        '''	"shake_scale": 1.0,
	"difficulty": "street",  # street as written / hard / brutal''',
    ),
    (
        '''func layout_for(button: String) -> Dictionary:''',
        '''## The difficulty levers (bible 14 defaults are STREET, untouched).
## name -> the active tier's multiplier; every lever defaults 1.0.
func diff_mult(lever: String) -> float:
	var d := str(value("difficulty"))
	if d == "hard":
		return float(Tuning.v("hard_" + lever))
	if d == "brutal":
		return float(Tuning.v("brutal_" + lever))
	return 1.0


func layout_for(button: String) -> Dictionary:''',
    ),
])

# 2. tuning: the two harder streets' screws
patch("scripts/tuning.gd", [
    (
        '''	"dirty_burn_heat": 0.3,  # ...and this hot by morning''',
        '''	"dirty_burn_heat": 0.3,  # ...and this hot by morning
	# the difficulty tiers (STREET is the 1.0 baseline above):
	"hard_hp": 1.5,  # sticks to drop a man
	"hard_telegraph": 0.85,  # faster tells - the read tightens
	"hard_composure": 1.25,  # hits drain more nerve
	"brutal_hp": 2.0,
	"brutal_telegraph": 0.7,
	"brutal_composure": 1.5,''',
    ),
])

# 3. enemy: hp and tells scale with the street
patch("scripts/enemy.gd", [
    (
        '''	if kind == 4:
		_body.scale = Vector3(1.28, 1.28, 1.28)
		max_hp = maxf(max_hp, 30)
		hp = max_hp
	elif kind == 2:
		_body.scale = Vector3(1.18, 1.18, 1.18)
		max_hp = maxf(max_hp, 12)
		hp = max_hp''',
        '''	if kind == 4:
		_body.scale = Vector3(1.28, 1.28, 1.28)
		max_hp = maxf(max_hp, 30)
	elif kind == 2:
		_body.scale = Vector3(1.18, 1.18, 1.18)
		max_hp = maxf(max_hp, 12)
	# the difficulty screws (STREET = the bible's night, untouched)
	max_hp = maxi(1, int(round(max_hp * Settings.diff_mult("hp"))))
	hp = max_hp''',
    ),
    (
        '''	if Tactics.player_spams("punch_light"):
		return TUNING[kind][2] * 0.75
	return TUNING[kind][2]''',
        '''	var t := TUNING[kind][2]
	if Tactics.player_spams("punch_light"):
		t *= 0.75
	# harder streets: the tells come faster and the read tightens
	return t * Settings.diff_mult("telegraph")''',
    ),
])

# 4. composure: harder streets drain more nerve per mistake
patch("scripts/composure.gd", [
    (
        '''func drain(amount: float, _why: String = "") -> void:''',
        '''func drain(amount: float, _why: String = "") -> void:
	# the difficulty screw: on harder streets mistakes cost more
	amount *= Settings.diff_mult("composure")''',
    ),
])

# 5. settings UI: the THE FIGHT picker
patch("scripts/settings_ui.gd", [
    (
        '''	_slider(col, "Button size", "button_scale", 0.7, 1.5, 0.05)''',
        '''	_difficulty_picker(col)
	_slider(col, "Button size", "button_scale", 0.7, 1.5, 0.05)''',
    ),
    (
        '''func _refresh() -> void:
	for b in _scroll.find_children("Scheme_*", "Button", true, false):''',
        '''## The difficulty tiers (bible 14 defaults are STREET). Three
## streets to walk; the active one glows. Tooltips carry the noir.
func _difficulty_picker(col: BoxContainer) -> void:
	_title(col, "THE FIGHT")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	var specs := {
		"street": ["STREET", "the night as written"],
		"hard": ["HARD", "they read faster, they drop slower"],
		"brutal": ["BRUTAL", "no mercy anywhere in the city"],
	}
	for id in ["street", "hard", "brutal"]:
		var b := Button.new()
		b.text = specs[id][0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 56)
		b.tooltip_text = specs[id][1]
		b.add_theme_font_size_override("font_size", 15)
		_style(b)
		b.pressed.connect(func() -> void:
			Settings.set_value("difficulty", id)
			_refresh())
		b.name = "Difficulty_" + id
		grid.add_child(b)
	_refresh()


func _refresh() -> void:
	for b in _scroll.find_children("Scheme_*", "Button", true, false):''',
    ),
    (
        '''		(b as Button).modulate = Color(1.4, 1.15, 0.8) if on else Color.WHITE''',
        '''		(b as Button).modulate = Color(1.4, 1.15, 0.8) if on else Color.WHITE
	for b in _scroll.find_children("Difficulty_*", "Button", true, false):
		var on: bool = str(Settings.value("difficulty")) \\
				== (b as Button).name.trim_prefix("Difficulty_")
		(b as Button).modulate = Color(1.4, 1.15, 0.8) if on else Color.WHITE''',
    ),
])

print("B14 wiring complete")
