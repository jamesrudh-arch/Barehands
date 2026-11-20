#!/usr/bin/env python3
"""B12 wiring: the reactive city goes live.

heat.gd       tier names + the witness/alley multiplier on add()
city.gd       hollow markups in price_mult + hollow greetings;
              last_heard escalates with a rumor's tells
blocks.gd     wary blocks board up too (doors close as blocks hollow)
wanderer.gd   wanderers join a group so crowds can be counted
cash_hud.gd   the panel shows the heat tier's name
ledger.gd     a spent beat retells a rumor
world_sim.gd  the day roll resets the fixer + feeds the radio recap
phone.gd      THE FIXER as a sender
tuning.gd     the numbers
project.godot the Reactive autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        if old not in s:
            # idempotent: a pair already applied (a previous run half-finished)
            assert new in s, "%s: not found: %r" % (path, old[:70])
            continue
        assert s.count(old) == 1, "%s: not unique: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# 1. heat: the tiers get names, the crowd decides the price
patch("scripts/heat.gd", [(
    """func add(amount: float) -> void:
	var was := heat""",
    """## The named ladder (bible 4I): the HUD and the radio read it.
func tier_name() -> String:
	if heat >= Tuning.v("copy_at"):
		return "the war"
	if heat >= 4.0:
		return "hunted"
	if heat >= 2.0:
		return "marked"
	if heat >= 1.0:
		return "talked about"
	return "quiet"


func add(amount: float) -> void:
	var was := heat""",
), (
    """	heat = clampf(heat + amount, 0.0, MAX)""",
    """	# crowds are witnesses, alleys are not (bible 4I): a street with
	# eyes pays you back, an empty one lets it slide
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and amount > 0.0:
		var eyes := 0
		for w in get_tree().get_nodes_in_group("wanderer"):
			if (w as Node3D).global_position.distance_to(
					p.global_position) < 10.0:
				eyes += 1
		if eyes >= 2:
			amount *= float(Tuning.v("witness_mult"))
		elif eyes == 0:
			amount *= float(Tuning.v("alley_mult"))
	heat = clampf(heat + amount, 0.0, MAX_HEAT)""",
)])

# 2. city: hollow prices, hollow greetings, distorting rumors
patch("scripts/city.gd", [(
    """	if hostile.get(d, false):
		m += 0.15
	if Heat.heat >= 4.0:
		m += 0.10
	return clampf(m, 0.8, 1.4)""",
    """	if hostile.get(d, false):
		m += 0.15
	if Heat.heat >= 4.0:
		m += 0.10
	# a hollow block is an expensive block (bible 4I: prices rise,
	# doors close): wary shelves are thin, turning hostile they're empty
	var mood := mood_of(d)
	if mood == "wary":
		m += float(Tuning.v("hollow_wary_markup"))
	elif mood == "turning hostile":
		m += float(Tuning.v("hollow_turning_markup"))
	return clampf(m, 0.8, 1.5)""",
), (
    """	elif r <= -25.0:
		line = "You're trouble. Trouble pays full price."
	else:
		line = "New face. Standard prices."
	var heard := last_heard(d)""",
    """	elif r <= -25.0:
		line = "You're trouble. Trouble pays full price."
	else:
		line = "New face. Standard prices."
	var mood := mood_of(d)
	if mood == "wary" and not hostile.get(d, false):
		line = "Shelves are thinning. The prices aren't mine anymore."
	elif mood == "turning hostile":
		line = "We close early now. You know why."
	var heard := last_heard(d)""",
), (
    '''	return "They say " + witnessed[d][-1].event + "."
''',
    '''	# rumors distort over retellings (bible 4I): the street grows the
	# story every time a beat is spent on it
	var e: Dictionary = witnessed[d][-1]
	var tells := int(e.get("tells", 0))
	if tells >= 3:
		return "They SWEAR " + str(e.event) + " - and the number is bigger now."
	if tells >= 1:
		return "They say " + str(e.event) + ". It grows every telling."
	return "They say " + str(e.event) + "."
''',
)])

# 3. blocks: wary boards up too - doors close as blocks hollow
patch("scripts/blocks.gd", [(
    """## A hostile block boards its shop fronts (bible 6: damage layer).
func _planks_if_hostile(id: String) -> void:
	var root: Node = _main if id == "riverside" else _built.get(id)
	if not root or _planked.get(id, false):
		return
	var mood := City.mood_of(id)
	if mood != "hostile" and mood != "turning hostile":
		return""",
    """## A hostile block boards its shop fronts (bible 6: damage layer);
## a hollow one closes its doors too (bible 4I: doors close).
func _planks_if_hostile(id: String) -> void:
	var root: Node = _main if id == "riverside" else _built.get(id)
	if not root or _planked.get(id, false):
		return
	var mood := City.mood_of(id)
	if not ["hostile", "turning hostile", "wary"].has(mood):
		return""",
)])

# 4. wanderers join a group (the crowd is countable)
patch("scripts/wanderer.gd", [(
    """func spawn() -> void:""",
    """func spawn() -> void:
	add_to_group("wanderer")""",
)])

# 5. cash_hud: the panel names the heat
patch("scripts/cash_hud.gd", [(
    """	var price := Label.new()
	price.text = "BULLET ........ $%d" % Wallet.bullet_cost()""",
    """	var heat_line := Label.new()
	heat_line.text = "HEAT .......... %s (%.1f)" % [Heat.tier_name(), Heat.heat]
	heat_line.add_theme_font_size_override("font_size", 17)
	heat_line.add_theme_color_override("font_color", Color(1.0, 0.65, 0.45))
	col.add_child(heat_line)

	var price := Label.new()
	price.text = "BULLET ........ $%d" % Wallet.bullet_cost()""",
)])

# 6. ledger: a spent beat retells a rumor
patch("scripts/ledger.gd", [(
    """	beats_left -= 1
	Log.info("Ledger: beat spent on %s (%d left)" % [what, beats_left])""",
    """	beats_left -= 1
	Reactive.on_beat_spent()  # retellings distort rumors (bible 4I)
	Log.info("Ledger: beat spent on %s (%d left)" % [what, beats_left])""",
)])

# 7. world_sim: the day roll resets the fixer + the radio recaps
patch("scripts/world_sim.gd", [(
    """	Jobs.on_day_rolled(new_day)
	Kidnap.on_day_rolled(new_day)""",
    """	Jobs.on_day_rolled(new_day)
	Kidnap.on_day_rolled(new_day)
	Reactive.on_day_rolled(new_day)""",
), (
    """	for line in Kidnap.morning_lines():
		lines.append(line)""",
    """	for line in Kidnap.morning_lines():
		lines.append(line)
	for line in Reactive.radio_lines():
		lines.append(line)""",
)])

# 8. phone: THE FIXER sends
patch("scripts/phone.gd", [(
    """	"kidnapper": {"name": "UNKNOWN NUMBER", "color": Color(0.8, 0.55, 0.3)},""",
    """	"kidnapper": {"name": "UNKNOWN NUMBER", "color": Color(0.8, 0.55, 0.3)},
	"fixer": {"name": "THE FIXER", "color": Color(0.35, 0.85, 0.5)},""",
)])

# 9. tuning: the numbers
patch("scripts/tuning.gd", [(
    '''	"kidnap_enemy_floor": 1.5,  # permanent enemy: heat never cools below''',
    '''	"kidnap_enemy_floor": 1.5,  # permanent enemy: heat never cools below
	"fixer_at": 2.2,  # heat where the fixer texts (once a day)
	"fixer_base": 150,  # his opening price
	"fixer_per_heat": 100,  # ...plus this per point of heat
	"copy_at": 4.5,  # "the war": someone studied your tape
	"copy_cooldown_msec": 90000,  # the next tape-student waits
	"copy_hp_base": 6,  # the copy starts here ...
	"witness_mult": 1.5,  # 2+ wanderers watching: violence costs more
	"alley_mult": 0.6,  # nobody watching: it slides
	"hollow_wary_markup": 0.08,  # wary shelves are thin
	"hollow_turning_markup": 0.12,  # turning hostile: they're empty''',
)])

# 10. the autoload
patch("project.godot", [(
    '''Kidnap="*res://scripts/kidnap.gd"''',
    '''Kidnap="*res://scripts/kidnap.gd"
Reactive="*res://scripts/reactive.gd"''',
)])

print("B12 wiring complete")
