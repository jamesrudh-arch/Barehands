#!/usr/bin/env python3
## S5.6 THE STORY SPINE wiring: missions engine (at_area/reach/
## defeat/area_clear/any_flag checks, thug spawning, GRAB choice
## spots, punch-at-the-door), phone 2.0 CALLS (ring + countdown +
## answer/decline + choices + missed cost), reward_clean, the M6
## consequences (escalation hp, corp ammo line).
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ------------------------------------------------------- mission_data.gd
patch('scripts/data/mission_data.gd', [
(
"""@export var reward_cash := 0
@export var reward_xp := 0.0""",
"""@export var reward_cash := 0
## clean money (a grateful shopkeeper pays from the till)
@export var reward_clean := 0
@export var reward_xp := 0.0"""
),
])

# -------------------------------------------------------------- enemy.gd
patch('scripts/npc/enemy.gd', [
(
"""		WorldState.push_event("crime", {"pos": global_position,
				"base": 4.0, "who": name})""",
"""		WorldState.push_event("crime", {"pos": global_position,
				"base": 4.0, "who": name})
		# the story counts its own (M2/M5): a body is a body
		WorldState.push_event("enemy_down", {"who": name})"""
),
])

# -------------------------------------------------------------- tuning.gd
patch('scripts/tuning.gd', [
(
"""	"debt_interest_tick": 0.005,  # ...what the debt grows per tick""",
"""	"debt_interest_tick": 0.005,  # ...what the debt grows per tick
	"escalate_hp_mult": 1.25,  # refused the Corporation: harder men
	"corp_ammo_mult": 0.5,  # accepted: their ammunition line, half"""
),
])

# --------------------------------------------------------------- market.gd
patch('scripts/core/market.gd', [
(
"""	var res := pay(Tuning.v("ammo_box_price"))""",
"""	var price := Tuning.v("ammo_box_price")
	# the Corporation's line: their man pays half (M6's offer)
	if WorldState.flag("m6_accepted"):
		price *= Tuning.v("corp_ammo_mult")
	var res := pay(price)"""
),
])

# ------------------------------------------------------------ missions.gd
patch('scripts/missions/missions.gd', [
# state
(
"""var _has_package := false
var _last_area := \"\"""",
"""var _has_package := false
var _last_area := ""
var _defeat_count := 0
var _pending_spawn: Array = []
var _punch_wired := false"""
),
# stage enter: reset counters, stage spawn + ring
(
"""	_capture_condition_state(stage.get("check", ""))
	_place_marker(stage)
	_stage_t = 0.0""",
"""	_capture_condition_state(stage.get("check", ""))
	_place_marker(stage)
	_defeat_count = 0
	_pending_spawn = stage.get("spawn", [])
	# THE CALL (M6): the stage's phone rings the moment it lands
	if stage.has("ring"):
		var ph := get_tree().get_first_node_in_group("phone")
		if ph and is_instance_valid(ph):
			ph.ring(stage.get("ring", {}))
	_stage_t = 0.0"""
),
# landed branch: spawn the stage's muscle + generalized package
(
"""			if active != null and stage_index < active.stages.size():
				var st: Dictionary = active.stages[stage_index]
				_place_marker(st)
				if st.get("check", "") == "package_taken" \\
						and not _has_package:
					_spawn_package()""",
"""			if active != null and stage_index < active.stages.size():
				var st: Dictionary = active.stages[stage_index]
				_place_marker(st)
				if st.get("check", "") == "package_taken" \\
						and not _has_package:
					_spawn_package(st)
				if not _pending_spawn.is_empty():
					_spawn_muscle()"""
),
# the punch watcher (M4's fist through the grille)
(
"""	if _marker and is_instance_valid(_marker):
		var ring := _marker.get_node_or_null("Ring") as MeshInstance3D
		if ring:
			ring.scale = Vector3.ONE * (1.0 + 0.12
					* sin(_stage_t * 3.0))""",
"""	if _marker and is_instance_valid(_marker):
		var ring := _marker.get_node_or_null("Ring") as MeshInstance3D
		if ring:
			ring.scale = Vector3.ONE * (1.0 + 0.12
					* sin(_stage_t * 3.0))
	# M4's other answer: a fist near the stage's door. The hero
	# instance dies on travel - rewire when the stage wants it.
	var hero_w := get_tree().get_first_node_in_group("player") as Node3D
	if hero_w == null or not is_instance_valid(hero_w):
		_punch_wired = false
	elif not _punch_wired:
		if not hero_w.face_action.is_connected(_on_hero_action):
			hero_w.face_action.connect(_on_hero_action)
		_punch_wired = true"""
),
# the new conditions
(
"""		"street_reached":
			return Game.area_id == "neighbourhood"
		"package_taken":
			return _has_package""",
"""		"street_reached":
			return Game.area_id == "neighbourhood"
		"at_area":
			var st_a: Dictionary = active.stages[stage_index]
			return Game.area_id == str(st_a.get("area", ""))
		"reach":
			# stand at the marker (M5's corner, the boss's curb)
			var st_r: Dictionary = active.stages[stage_index]
			return hero != null and is_instance_valid(hero) \\
					and Game.area_id == str(st_r.get("area", "")) \\
					and hero.global_position.distance_to(
					st_r.get("marker", Vector3.ZERO)) < 2.6
		"package_taken":
			return _has_package
		"defeat":
			# real bodies, counted by the enemy_down event
			var st_d: Dictionary = active.stages[stage_index]
			return _defeat_count >= int(st_d.get("need", 1))
		"area_clear":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) \\
						and float(e.get("hp")) > 0.0:
					return false
			return true
		"any_flag":
			# the choice stages (M4's talk-or-break, M6's answer)
			var st_f: Dictionary = active.stages[stage_index]
			for f in st_f.get("flags", []):
				if WorldState.flag(str(f)):
					return true
			return false"""
),
# grab choice spots + the punch handler + muscle spawn (before _advance)
(
"""func _advance() -> void:""",
"""## GRAB at a choice spot (M4's grille, M3's ask): the street's
## other verb. Runs after police + market in the hero's chain.
func try_grab(hero: Node3D) -> bool:
	if active == null or hero == null or not is_instance_valid(hero):
		return false
	if stage_index >= active.stages.size():
		return false
	var st: Dictionary = active.stages[stage_index]
	if not st.has("grab_flag") or Game.area_id != str(st.get("area", "")):
		return false
	if hero.global_position.distance_to(
			st.get("marker", Vector3.ZERO)) > 3.4:
		return false
	WorldState.set_flag(str(st["grab_flag"]))
	WorldState.push_event("choice", {"what": str(st["grab_flag"])})
	Log.info("Mission: the grab answers (%s)" % st["grab_flag"])
	return true


## a fist near the stage's marker (M4: the grille gives way)
func _on_hero_action(action: String) -> void:
	if active == null or stage_index >= active.stages.size():
		return
	var st: Dictionary = active.stages[stage_index]
	if action != "punch" or not st.has("punch_flag"):
		return
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null or not is_instance_valid(hero):
		return
	if hero.global_position.distance_to(
			st.get("marker", Vector3.ZERO)) > 3.4:
		return
	WorldState.set_flag(str(st["punch_flag"]))
	WorldState.bump("heat", 2.0)  # the street heard the steel
	WorldState.set_flag("door_broken:" + str(st.get("door", "")))
	WorldState.push_event("choice", {"what": str(st["punch_flag"])})
	Log.info("Mission: the fist answers (%s)" % st["punch_flag"])


## the stage's muscle (M2's gym, M5's collectors), spawned when
## the area has landed. Refusing the Corporation sends harder men.
func _spawn_muscle() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var escalate := 1.0
	if WorldState.flag("m6_declined"):
		escalate = Tuning.v("escalate_hp_mult")
	var script := load("res://scripts/npc/enemy.gd") as GDScript
	for spec in _pending_spawn:
		var e: CharacterBody3D = script.new()
		e.position = spec.get("pos", Vector3.ZERO)
		e.rotation.y = float(spec.get("rot", 0.0))
		if spec.has("hp"):
			e.set("hp", float(spec["hp"]) * escalate)
		else:
			e.set("hp", float(e.get("hp")) * escalate)
		e.add_to_group("mission_spawn")
		scene.add_child(e)
		Log.info("Mission: muscle at %s (hp %.0f)" % [
				str(spec.get("pos", Vector3.ZERO)),
				float(e.get("hp"))])
	_pending_spawn = []


func _drop_spawned() -> void:
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.queue_free()


func _advance() -> void:
	_drop_spawned()"""
),
# count the bodies
(
"""	WorldState.event_fired.connect(_on_event)""",
"""	WorldState.event_fired.connect(_on_event)"""
),
# clean reward
(
"""	if m.reward_cash > 0:
		WorldState.bump("stash_cash", float(m.reward_cash))""",
"""	if m.reward_cash > 0:
		WorldState.bump("stash_cash", float(m.reward_cash))
	if m.reward_clean > 0:
		WorldState.bump("clean_cash", float(m.reward_clean))
		WorldState.push_event("paid_clean", {"amount":
				m.reward_clean})"""
),
])

# _on_event: find it and add the defeat count
s = open('scripts/missions/missions.gd').read()
import re
m = re.search(r'func _on_event\([^)]*\) -> void:\n', s)
if not m:
    print("MISS _on_event"); sys.exit(1)
ins = m.end()
s = s[:ins] + """	if str(kind) == "enemy_down":
		_defeat_count += 1
		return
""" + s[ins:]
open('scripts/missions/missions.gd','w').write(s)
print("missions _on_event counts the bodies")

# generalize the package to the stage's marker/area
patch('scripts/missions/missions.gd', [
(
"""func _spawn_package() -> void:
	_drop_package()
	var scene := get_tree().current_scene
	if scene == null or Game.area_id != "warehouse":
		return
	_package = Node3D.new()
	_package.name = "ThePackage"
	_package.position = Vector3(-6.5, 1.05, 4.8)""",
"""func _spawn_package(st: Dictionary = {}) -> void:
	_drop_package()
	var scene := get_tree().current_scene
	if scene == null:
		return
	# M1's workbench box; any later stage names its own counter
	var at := Vector3(-6.5, 1.05, 4.8)
	var want_area := "warehouse"
	if not st.is_empty():
		at = st.get("marker", at)
		want_area = str(st.get("area", want_area))
	if Game.area_id != want_area:
		return
	_package = Node3D.new()
	_package.name = "ThePackage"
	_package.position = at"""
),
])
print("ALL WIRED")
