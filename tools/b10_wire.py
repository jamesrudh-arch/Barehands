#!/usr/bin/env python3
"""B10 wiring: the jobs go live.

jobs.gd        real districts only, Enemy.State.DOWN, save-safe to_dict
city.gd        note_damage_in(district, ...) - a mark on a block you're
               not standing in
tuning.gd      job_overuse_at
project.godot  the Jobs autoload
world_sim.gd   day roll -> jobs go cold + the board refreshes; the
               fight-toast hint finds the right group (hud_buttons)
phone_ui.gd    THE BOARD on the map app + the JOBS chip per district
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# 1. the ten jobs, real districts (riverside 2 / market 4 / foundry 4)
patch("scripts/jobs.gd", [(
    """const JOBS := [
	{"id": "courier_neon", "title": "the neon courier", "template": "delivery",
		"district": "neon_district", "friend": "club_owner", "pay": 500,
		"hard": false,
		"blurb": "a case walks from the club to a corner in the neon block. nobody opens it."},
	{"id": "courier_foundry", "title": "the foundry run", "template": "delivery",
		"district": "foundry", "friend": "mechanic", "pay": 750,
		"hard": true,
		"blurb": "machine parts, no papers, no questions. the drop point bites."},
	{"id": "free_brothers_man", "title": "the brother's man", "template": "rescue",
		"district": "market", "friend": "brother", "pay": 900,
		"hard": false,
		"blurb": "the Family borrowed one of the brother's people. give them back."},
	{"id": "free_foundry_hand", "title": "the foundry hand", "template": "rescue",
		"district": "foundry", "friend": "mechanic", "pay": 1100,
		"hard": true,
		"blurb": "a debt-slaved hand on the foundry floor. two guards this time."},
	{"id": "lean_shark", "title": "the market shark", "template": "coerced",
		"district": "market", "friend": "club_owner", "pay": 400,
		"hard": false,
		"blurb": "a shop collects for the wrong people. explain the error, quietly."},
	{"id": "lean_fenced", "title": "the fenced goods", "template": "coerced",
		"district": "neon_district", "friend": "club_owner", "pay": 600,
		"hard": false,
		"blurb": "stolen stock moves through a neon stall. persuade the fence."},
	{"id": "cut_enforcer", "title": "the collector", "template": "hit",
		"district": "market", "friend": "brother", "pay": 1200,
		"hard": false,
		"blurb": "a collector who works children's shops. the Family won't miss him."},
	{"id": "cut_snitch", "title": "the snitch", "template": "hit",
		"district": "foundry", "friend": "mechanic", "pay": 1500,
		"hard": true,
		"blurb": "someone sold the garage's route to the Corporation. knife trained."},
	{"id": "hold_riverside", "title": "the riverside corner", "template": "turf",
		"district": "riverside", "friend": "drunk", "pay": 800,
		"hard": false,
		"blurb": "three waves want the corner by the noodle front. keep it."},
	{"id": "hold_market", "title": "the market floor", "template": "turf",
		"district": "market", "friend": "club_owner", "pay": 1000,
		"hard": true,
		"blurb": "the club's floor tax is due. collect it off their heads."},
]""",
    """const JOBS := [
	{"id": "courier_market", "title": "the market courier", "template": "delivery",
		"district": "market", "friend": "club_owner", "pay": 500,
		"hard": false,
		"blurb": "a case walks from the club to a corner of the market. nobody opens it."},
	{"id": "courier_foundry", "title": "the foundry run", "template": "delivery",
		"district": "foundry", "friend": "mechanic", "pay": 750,
		"hard": true,
		"blurb": "machine parts, no papers, no questions. the drop point bites."},
	{"id": "free_brothers_man", "title": "the brother's man", "template": "rescue",
		"district": "market", "friend": "brother", "pay": 900,
		"hard": false,
		"blurb": "the Family borrowed one of the brother's people. give them back."},
	{"id": "free_foundry_hand", "title": "the foundry hand", "template": "rescue",
		"district": "foundry", "friend": "mechanic", "pay": 1100,
		"hard": true,
		"blurb": "a debt-slaved hand on the foundry floor. two guards this time."},
	{"id": "lean_riverside", "title": "the riverside shark", "template": "coerced",
		"district": "riverside", "friend": "brother", "pay": 400,
		"hard": false,
		"blurb": "a stall by the water collects for the wrong people. explain the error."},
	{"id": "lean_fenced", "title": "the fenced goods", "template": "coerced",
		"district": "foundry", "friend": "club_owner", "pay": 600,
		"hard": false,
		"blurb": "stolen stock moves through a foundry stall. persuade the fence."},
	{"id": "cut_enforcer", "title": "the collector", "template": "hit",
		"district": "market", "friend": "brother", "pay": 1200,
		"hard": false,
		"blurb": "a collector who works children's shops. the Family won't miss him."},
	{"id": "cut_snitch", "title": "the snitch", "template": "hit",
		"district": "foundry", "friend": "mechanic", "pay": 1500,
		"hard": true,
		"blurb": "someone sold the garage's route to the Corporation. knife trained."},
	{"id": "hold_riverside", "title": "the riverside corner", "template": "turf",
		"district": "riverside", "friend": "drunk", "pay": 800,
		"hard": false,
		"blurb": "three waves want the corner by the noodle front. keep it."},
	{"id": "hold_market", "title": "the market floor", "template": "turf",
		"district": "market", "friend": "club_owner", "pay": 1000,
		"hard": true,
		"blurb": "the club's floor tax is due. collect it off their heads."},
]""",
)])

# 2. spot map: real districts only
patch("scripts/jobs.gd", [(
    """	var base := {"riverside": Vector3(5.0, 0.02, 5.0),
		"market": Vector3(245.0, 0.02, 6.0),
		"foundry": Vector3(484.0, 0.02, -5.0),
		"neon_district": Vector3(-8.0, 0.02, 6.0)}[j["district"]]""",
    """	var base := {"riverside": Vector3(5.0, 0.02, 5.0),
		"market": Vector3(245.0, 0.02, 6.0),
		"foundry": Vector3(484.0, 0.02, -5.0)}[j["district"]]""",
)])

# 3. DOWN by enum, not by ordinal; gone enemies count as handled
patch("scripts/jobs.gd", [(
    """		elif (e as Node).get("state") == 5:  # Enemy.State.DOWN
			if not active.get("_counted", []).has(e):
				active["_counted"].append(e)
				active["downed"] += 1
			# a downed enemy stays counted even once freed
		else:
			alive += 1""",
    """		elif (e as Enemy).state == Enemy.State.DOWN:
			if not active.get("_counted", []).has(e):
				active["_counted"].append(e)
				active["downed"] += 1
			# a downed enemy stays counted even once freed
		else:
			alive += 1""",
), (
    """			var guard_up := false
			for e in _spawned:
				if is_instance_valid(e) and (e as Node).get("state") != 5:
					guard_up = true""",
    """			var guard_up := false
			for e in _spawned:
				if is_instance_valid(e) and (e as Enemy).state != Enemy.State.DOWN:
					guard_up = true""",
)])

# 4. save-safe to_dict (never serialize node refs)
patch("scripts/jobs.gd", [(
    """func to_dict() -> Dictionary:
	return {"offers": offers.duplicate(), "done": done.duplicate(),
		"setups": setups.duplicate(),
		"active": active.duplicate()}""",
    """func to_dict() -> Dictionary:
	var a := active.duplicate()
	a.erase("_counted")  # node refs never go into the save
	return {"offers": offers.duplicate(), "done": done.duplicate(),
		"setups": setups.duplicate(), "active": a}""",
)])

# 5. the overuse mark lands on the FRIEND's block, wherever you stand
patch("scripts/jobs.gd", [(
    """	City.note_damage(Vector3(hx + 2.0, 0.0, 4.0), "scorch")""",
    """	City.note_damage_in(home, Vector3(hx + 2.0, 0.0, 4.0), "scorch")""",
)])

patch("scripts/city.gd", [(
    """func note_damage(pos: Vector3, kind: String) -> void:
	var d := district_at(pos)""",
    """func note_damage(pos: Vector3, kind: String) -> void:
	note_damage_in(district_at(pos), pos, kind)


## A mark on a block you are NOT standing in (a friend's business
## eating your overuse, world events elsewhere).
func note_damage_in(d: String, pos: Vector3, kind: String) -> void:""",
)])

patch("scripts/tuning.gd", [(
    '''	"rumor_age_days": 2,  # days a street rumor stays in retelling''',
    '''	"rumor_age_days": 2,  # days a street rumor stays in retelling
	"job_overuse_at": 3,  # setups through one friend before their business eats it''',
)])

patch("project.godot", [(
    '''WorldSim="*res://scripts/world_sim.gd"''',
    '''WorldSim="*res://scripts/world_sim.gd"
Jobs="*res://scripts/jobs.gd"''',
)])

patch("scripts/world_sim.gd", [(
    """	var pruned := City.age_rumors(new_day)
	if pruned > 0:
		lines.append("the street let %d old rumor(s) go" % pruned)""",
    """	var pruned := City.age_rumors(new_day)
	if pruned > 0:
		lines.append("the street let %d old rumor(s) go" % pruned)
	# a live job goes cold on the friend who set it up
	var cold: String = ""
	if not Jobs.active.is_empty() and Jobs.active.get("phase", "") in \\
			["TAKEN", "RECON", "READY"]:
		var j := Jobs.job_by_id(Jobs.active["id"])
		cold = j.get("title", "")
	if not cold.is_empty():
		lines.append("\\"%s\\" went cold - that was someone's name on it" % cold)
	Jobs.on_day_rolled(new_day)""",
), (
    """		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("DAY %d - the books closed" % new_day, 3.0)""",
    """		var hud := get_tree().get_first_node_in_group("hud_buttons")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("DAY %d - the books closed" % new_day, 3.0)""",
)])

# 6. the map app: THE BOARD above the cards
patch("scripts/phone_ui.gd", [(
    """	var now := City.district_now()
	for d in City.DISTRICTS:
		row.add_child(_map_card(d, d == now))
	var note := _label("no fast travel - the streets are the travel", 12,""",
    """	var now := City.district_now()
	for d in City.DISTRICTS:
		row.add_child(_map_card(d, d == now))
	_app_body.add_child(_jobs_board())
	var note := _label("no fast travel - the streets are the travel", 12,""",
), (
    """## The bible's map layers, minus jobs (no source until the jobs batch -
## no dead chips): mood, heat, friends, damage.""",
    """## THE BOARD (jobs): today's offers, the live job, one beat each.
func _jobs_board() -> VBoxContainer:
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 4)
	var head := _label("THE BOARD - one beat a job, the day is the deadline",
			12, Color(0.85, 0.75, 0.4))
	board.add_child(head)
	var any := false
	if not Jobs.active.is_empty() and Jobs.active.get("phase", "") in \\
			["TAKEN", "RECON", "READY"]:
		var j := Jobs.job_by_id(Jobs.active["id"])
		var live := _label("LIVE - %s (%s)" % [j["title"], Jobs.active["phase"]],
				13, Color(0.95, 0.85, 0.5))
		board.add_child(live)
		any = true
	for id in Jobs.offers:
		var oj := Jobs.job_by_id(id)
		if oj.is_empty():
			continue
		any = true
		var text := "TAKE - %s  ($%d dirty - %s - %s)" % [oj["title"], oj["pay"],
				Jobs.TEMPLATES[oj["template"]]["name"],
				oj["district"].to_upper()]
		board.add_child(_btn(text, Color(0.7, 0.65, 0.45),
				func(): _take_job(id)))
	if not any:
		board.add_child(_label("nothing on the board today - sleep on it",
				12, Color(0.55, 0.57, 0.6)))
	return board


func _take_job(id: String) -> void:
	if Jobs.take(id):
		_open_map()  # the board redraws: the job goes LIVE
	else:
		_show_app_note("MAP", "the fixer's line is busy - try again")


## The bible's map layers, plus jobs now that the board has a source:
## mood, heat, friends, damage.""",
), (
    """	var chips := [
		["MOOD " + City.mood_of(district), Color(0.6, 0.8, 0.65)],""",
    """	var job_n := 0
	for id in Jobs.offers:
		var oj := Jobs.job_by_id(id)
		if oj.get("district", "") == district:
			job_n += 1
	var chips := [
		["MOOD " + City.mood_of(district), Color(0.6, 0.8, 0.65)],
		["JOBS %d" % job_n, Color(0.85, 0.75, 0.4)],""",
)])

print("B10 wiring complete")
