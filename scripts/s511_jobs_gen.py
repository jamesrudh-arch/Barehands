#!/usr/bin/env python3
## S5.11 THE TEN CORE JOBS + THE KIDNAP ARC: fourteen .tres files
## on the existing condition vocabulary (five templates reskinned:
## Delivery, Rescue, Coerced, Hit, Turf) + the engine's two new
## stage keys (unlock_door, ring-with-zero) + m6 chains into j1.
import sys

def tres(path, body):
    open(path, 'w').write(
        '[gd_resource type="Resource" script_class="MissionData" '
        'load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" '
        'path="res://scripts/data/mission_data.gd" id="1"]\n\n'
        '[resource]\nscript = ExtResource("1")\n' + body)

def mission(mid, title, blurb, stages, cash, clean, xp, nxt):
    s = 'id = "%s"\ntitle = "%s"\nblurb = "%s"\nstages = [' % (
        mid, title, blurb)
    for st in stages:
        s += '{\n'
        for k, v in st.items():
            # raw passthrough for geometry/collections, quotes for
            # plain strings (a quoted "Vector3(...)" is a String -
            # _place_marker assigned it to position and died)
            if isinstance(v, str) and (v.startswith("Vector3(")
                    or v.startswith("[") or v.startswith("{")):
                s += '"%s": %s,\n' % (k, v)
            elif isinstance(v, str):
                s += '"%s": "%s",\n' % (k, v)
            else:
                s += '"%s": %s,\n' % (k, v)
        s += '}, '
    s += ']\nreward_cash = %d\nreward_clean = %d\nreward_xp = %.1f\nnext = "%s"\n' % (
        cash, clean, xp, nxt)
    return s

def spawn(*specs):
    inner = ', '.join('{"pos": %s%s}' % (
        p, (', "hp": %.1f' % hp) if hp else '') for p, hp in specs)
    return '[' + inner + ']'

R = 'Vector3'
JOBS = []

# --- the five templates, reskinned ten ways --------------------------
JOBS.append(('j1', mission('j1', 'THE DROP',
	"Sal's fish market needs a package that never touched the alley.",
	[{"area": "warehouse", "check": "package_taken",
		"marker": "Vector3(-6.5, 1.05, 4.8)",
		"objective": "Take the package from your workbench"},
	 {"area": "docks", "check": "delivered",
		"marker": "Vector3(30.0, 1.2, -1.6)",
		"objective": "Walk it to SAL at the fish market"}],
	250, 0, 30.0, 'j2')))

JOBS.append(('j2', mission('j2', 'ROOM SERVICE',
	"Hotel Aurora's guests are loud and the management is worse.",
	[{"area": "club_district", "check": "reach",
		"marker": "Vector3(-22.0, 1.2, 7.2)",
		"objective": "Reach HOTEL AURORA's door"},
	 {"area": "club_district", "check": "defeat", "need": 2,
		"spawn": spawn(("Vector3(-24.0, 0.05, 9.0)", 0),
				("Vector3(-20.0, 0.05, 9.0)", 0)),
		"marker": "Vector3(-22.0, 1.2, 7.2)",
		"objective": "The guests object - settle it"}],
	200, 0, 35.0, 'j3')))

JOBS.append(('j3', mission('j3', "THE COPY'S DEBT",
	"The man who studied your tape wants a word. He sends friends.",
	[{"area": "docks", "check": "at_area",
		"marker": "Vector3(10.0, 1.2, 0.0)",
		"objective": "They wait at the docks yard"},
	 {"area": "docks", "check": "defeat", "need": 1,
		"spawn": spawn(("Vector3(10.0, 0.05, 0.0)", 90.0)),
		"marker": "Vector3(10.0, 1.2, 0.0)",
		"objective": "THE STUDENT: put him down"},
	 {"area": "docks", "check": "area_clear",
		"marker": "Vector3(10.0, 1.2, 0.0)",
		"objective": "Let the yard go quiet"}],
	300, 0, 40.0, 'j4')))

JOBS.append(('j4', mission('j4', "VESPER'S FAVOR",
	"The club owner counts on you. That is a compliment and a bill.",
	[{"area": "club_district", "check": "any_flag",
		"flags": '["j4_ok"]', "grab_flag": "j4_ok",
		"marker": "Vector3(-41.5, 1.2, -5.0)",
		"objective": "Hear Vesper out at the Velvet Room's back curb (GRAB)"},
	 {"area": "club_district", "check": "reach",
		"marker": "Vector3(-41.5, 1.2, 3.0)",
		"objective": "Take his corner out front"}],
	180, 0, 25.0, 'j5')))

JOBS.append(('j5', mission('j5', 'THE WATCH',
	"The Velvet Room's curb is contested ground tonight.",
	[{"area": "club_district", "check": "reach",
		"marker": "Vector3(-41.5, 1.2, 3.0)",
		"objective": "Stand the Velvet Room's curb"},
	 {"area": "club_district", "check": "defeat", "need": 2,
		"spawn": spawn(("Vector3(-38.5, 0.05, 3.0)", 0),
				("Vector3(-44.5, 0.05, 3.0)", 0)),
		"marker": "Vector3(-41.5, 1.2, 3.0)",
		"objective": "The first pair"},
	 {"area": "club_district", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(-38.5, 0.05, 3.0)", 0),
				("Vector3(-44.5, 0.05, 3.0)", 0),
				("Vector3(-41.5, 0.05, 0.0)", 60.0)),
		"marker": "Vector3(-41.5, 1.2, 3.0)",
		"objective": "Three more - hold the curb"},
	 {"area": "club_district", "check": "area_clear",
		"marker": "Vector3(-41.5, 1.2, 3.0)",
		"objective": "The strip breathes again"}],
	320, 0, 55.0, 'j6')))

JOBS.append(('j6', mission('j6', "DEE'S SUPPLIES",
	"Old Dee fed you for years. His supplier didn't show.",
	[{"area": "neighbourhood", "check": "package_taken",
		"marker": "Vector3(6.0, 1.0, 5.4)",
		"objective": "Collect the crate at THE CORNER STORE"},
	 {"area": "neighbourhood", "check": "delivered",
		"marker": "Vector3(-40.4, 1.2, 5.4)",
		"objective": "Carry it to Dee's counter at MAMA SUN'S"}],
	120, 80, 20.0, 'j7')))

JOBS.append(('j7', mission('j7', "THE MECHANIC'S PROBLEM",
	"The garage's shutter is steel, but the street talks.",
	[{"area": "club_district", "check": "reach",
		"marker": "Vector3(36.0, 1.2, 7.2)",
		"objective": "THE MECHANIC's shutter, the club strip's end"},
	 {"area": "club_district", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(33.0, 0.05, 9.0)", 0),
				("Vector3(39.0, 0.05, 9.0)", 0),
				("Vector3(36.0, 0.05, 11.0)", 60.0)),
		"marker": "Vector3(36.0, 1.2, 7.2)",
		"objective": "The problem has hands - three of them"}],
	350, 0, 50.0, 'j8')))

JOBS.append(('j8', mission('j8', 'WALK HIS ROUTE',
	"You cannot follow a man forever. You can learn where he goes.",
	[{"area": "docks", "check": "reach",
		"marker": "Vector3(10.0, 1.2, 8.0)",
		"objective": "The route starts at the harbour mouth"},
	 {"area": "docks", "check": "reach",
		"marker": "Vector3(-10.0, 1.2, -2.0)",
		"objective": "Second stop: the container gap"},
	 {"area": "docks", "check": "reach",
		"marker": "Vector3(-30.0, 1.2, -8.0)",
		"objective": "Last stop - memorize the way to Warehouse 9"}],
	220, 0, 30.0, 'j9')))

JOBS.append(('j9', mission('j9', 'THE QUIET WARNING',
	"The Corporation calls again. They are polite. That is worse.",
	[{"area": "neighbourhood", "check": "any_flag",
		"flags": '["j9_visit", "j9_stay"]',
		"ring": ('{"from": "THE CORPORATION", "duration": 14.0, '
			'"lines": ["\'A courtesy call. There is a matter at the container maze.\'", '
			'"\'Come see it yourself, or stay home and let it come to you.\'"], '
			'"choices": [{"label": "PAY A VISIT\\nthe container maze, tonight", '
			'"flag": "j9_visit"}, '
			'{"label": "STAY AWAY\\nthey come either way (+heat)", '
			'"flag": "j9_stay", "heat": 3.0}], '
			'"decline": {"flag": "j9_stay", "heat": 3.0}}'),
		"marker": "Vector3(-42.0, 1.2, 7.2)",
		"objective": "THE CORPORATION is calling - answer"},
	 {"area": "docks", "check": "defeat", "need": 2,
		"spawn": spawn(("Vector3(20.0, 0.05, -8.0)", 0),
				("Vector3(24.0, 0.05, -12.0)", 0)),
		"marker": "Vector3(22.0, 1.2, -10.0)",
		"objective": "They came anyway - the container maze"}],
	280, 0, 40.0, 'j10')))

JOBS.append(('j10', mission('j10', 'THE BIG MOVE',
	"Whatever they are moving through the docks, it moves tonight.",
	[{"area": "docks", "check": "at_area",
		"marker": "Vector3(20.0, 1.2, 0.0)",
		"objective": "The docks, after dark"},
	 {"area": "docks", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(18.0, 0.05, 2.0)", 0),
				("Vector3(24.0, 0.05, 2.0)", 0),
				("Vector3(21.0, 0.05, -3.0)", 0)),
		"marker": "Vector3(20.0, 1.2, 0.0)",
		"objective": "The movers - three of them"},
	 {"area": "docks", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(18.0, 0.05, 2.0)", 120.0),
				("Vector3(24.0, 0.05, 2.0)", 120.0),
				("Vector3(21.0, 0.05, -3.0)", 90.0)),
		"marker": "Vector3(20.0, 1.2, 0.0)",
		"objective": "The escort - harder men"},
	 {"area": "docks", "check": "area_clear",
		"marker": "Vector3(20.0, 1.2, 0.0)",
		"objective": "The yard must go quiet"}],
	500, 0, 70.0, 'k1')))

# --- the kidnap arc ---------------------------------------------------
JOBS.append(('k1', mission('k1', 'COLD CALL',
	"The voice on the phone is your brother's, and it is shaking.",
	[{"area": "neighbourhood", "check": "any_flag",
		"flags": '["k1_heard"]',
		"ring": ('{"from": "THE BROTHER", "duration": 16.0, '
			'"lines": ["\'They took him. The one of us with the softest hands.\'", '
			'"\'I traced the call - the docks. Warehouse 9. The tape is theirs.\'", '
			'"\'Come home first. We plan this right.\'"], '
			'"choices": [{"label": "ON MY WAY", "flag": "k1_heard"}], '
			'"decline": {"flag": "k1_heard"}}'),
		"marker": "Vector3(-42.0, 1.2, 7.2)",
		"objective": "THE BROTHER is calling - answer him"},
	 {"area": "warehouse", "check": "reach",
		"marker": "Vector3(-6.5, 1.2, 4.8)",
		"objective": "Come home - the workbench, like the old days"}],
	0, 0, 40.0, 'k2')))

JOBS.append(('k2', mission('k2', 'THE INVESTIGATION',
	"No fists yet. Walk the city the way they walked it.",
	[{"area": "neighbourhood", "check": "reach",
		"marker": "Vector3(-20.0, 1.2, 3.4)",
		"objective": "The alley mouth - where they waited"},
	 {"area": "club_district", "check": "reach",
		"marker": "Vector3(-41.5, 1.2, -5.0)",
		"objective": "The Velvet Room's back curb - where they paid"},
	 {"area": "docks", "check": "any_flag",
		"flags": '["k_clue"]', "grab_flag": "k_clue",
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "The tape on WAREHOUSE 9's doors - search it (GRAB)"}],
	150, 0, 45.0, 'k3')))

JOBS.append(('k3', mission('k3', 'THE ASSAULT',
	"The tape comes off. What is behind it has been waiting.",
	[{"area": "docks", "check": "at_area",
		"unlock_door": "DOCK WAREHOUSE 9",
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "DOCK WAREHOUSE 9 - the tape is coming off"},
	 {"area": "docks", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(-32.0, 0.05, -8.0)", 0),
				("Vector3(-40.0, 0.05, -8.0)", 0),
				("Vector3(-36.0, 0.05, -16.0)", 0)),
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "The guards at the doors"},
	 {"area": "docks", "check": "defeat", "need": 3,
		"spawn": spawn(("Vector3(-33.0, 0.05, -10.0)", 120.0),
				("Vector3(-39.0, 0.05, -10.0)", 120.0),
				("Vector3(-36.0, 0.05, -12.0)", 200.0)),
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "THE LIEUTENANT and his two - the last door"},
	 {"area": "docks", "check": "area_clear",
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "The yard goes quiet. Go in."}],
	400, 0, 80.0, 'k4')))

JOBS.append(('k4', mission('k4', 'THE CHOICE',
	"Inside: your friend, the money, and a phone that already knows you're here.",
	[{"area": "docks", "check": "any_flag",
		"flags": '["k_saved", "k_paid"]',
		"ring": ('{"from": "THE CORPORATION", "duration": 20.0, '
			'"lines": ["\'You are standing in our building with our property.\'", '
			'"\'The man is nothing. The case beside him is two thousand, clean.\'", '
			'"\'Choose. The phone only rings once.\'"], '
			'"choices": [{"label": "SAVE THEM\\nthe money burns, the Corporation remembers", '
			'"flag": "k_saved", "also_flag": "corp_enemy", "zero": ["stash_cash", "clean_cash"]}, '
			'{"label": "TAKE THE PAYOFF\\n+$2000 clean, the friend is theirs", '
			'"flag": "k_paid", "clean_cash": 2000.0}], '
			'"decline": {"flag": "k_saved", "also_flag": "corp_enemy", "zero": ["stash_cash", "clean_cash"]}}'),
		"marker": "Vector3(-36.0, 1.2, -6.0)",
		"objective": "THE CORPORATION is calling - this is the choice"}],
	0, 0, 100.0, '')))

for name, body in JOBS:
    tres('data/missions/%s.tres' % name, body)
    print("wrote %s" % name)

# m6 chains into the jobs
s = open('data/missions/m6.tres').read()
if 'next = ""' in s:
    s = s.replace('next = ""', 'next = "j1"', 1)
    open('data/missions/m6.tres', 'w').write(s)
    print("m6 -> j1")

# --- the engine hooks -------------------------------------------------
def patch(path, pairs):
    s = open(path).read()
    n = 0
    for old, new in pairs:
        if old in s:
            s = s.replace(old, new, 1)
            n += 1
        elif new in s:
            n += 1  # already applied
        else:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, n))

patch('scripts/missions/missions.gd', [
(
"""	_defeat_count = 0
	_pending_spawn = stage.get("spawn", [])""",
"""	_defeat_count = 0
	_pending_spawn = stage.get("spawn", [])
	# the story door: a stage can unseal one (k3's tape)
	if stage.has("unlock_door"):
		var ulabel := str(stage["unlock_door"])
		WorldState.set_flag("door_open:" + ulabel)
		Doors.open_door(ulabel)"""
),
])

patch('scripts/ui/phone.gd', [
(
"""	if eff.has("flag"):
		WorldState.set_flag(str(eff["flag"]))""",
"""	if eff.has("flag"):
		WorldState.set_flag(str(eff["flag"]))
	if eff.has("also_flag"):
		WorldState.set_flag(str(eff["also_flag"]))
	# THE CHOICE's teeth: some prices zero a pool outright
	for k in eff.get("zero", []):
		WorldState.set_value(str(k), 0.0)"""
),
])

# saving them makes a permanent enemy: the spawner escalates
patch('scripts/missions/missions.gd', [
(
"""	var escalate := 1.0
	if WorldState.flag("m6_declined"):
		escalate = Tuning.v("escalate_hp_mult")""",
"""	var escalate := 1.0
	if WorldState.flag("m6_declined") \\
			or WorldState.flag("corp_enemy"):
		escalate = Tuning.v("escalate_hp_mult")"""
),
])
print("JOBS + ARC WIRED")
