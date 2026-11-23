extends Node

## THE DOOR LAW (rebuild step 6, scripts/world/doors.gd): every door
## in the world answers a TRY. OPEN doors let you walk in (their
## interiors are their own). LOCKED doors SAY WHY - one line, at the
## door, plain words, with a rattle, a shake and a haptic tick.
## Breakable doors break: B presses shoulder them, A kicks land on
## the frame, the last hit bursts the leaf, drops the stash and wakes
## whoever is inside. A broken door STAYS broken - WorldState carries
## the flag, so a reload re-breaks the frame instead of raising a new
## door. The B button is the try (context verb OPEN/TRY/BREAK/LOOK);
## mid-fight a kick never lands on a door.

const CLS_STASH := preload("res://scripts/world/stash.gd")

const APPROACH_R := 2.5
const ACT_R := 2.8
const SAY_S := 3.0

## label -> law, by the area's registration
## law = {node, state: "open"|"locked"|"broken", reason, breakable,
##        hits, stash, ambush: [kinds]}
var _doors: Dictionary = {}
var _say_until: Dictionary = {}
var _tick := 0


func _ready() -> void:
	set_process(true)


## The area registers its fronts as they build. Broken flags from a
## previous session re-apply instantly (the city remembers).
func register(front: Node3D, label: String, law: Dictionary) -> void:
	law["node"] = front
	law["label"] = label
	if WorldState.flag("door_broken:" + label):
		law["state"] = "broken"
		law["hits_left"] = 0
	# the paid book opens the grille (M4's third answer)
	if law["state"] == "locked" 			and WorldState.flag("door_open:" + label):
		law["state"] = "open"
	if law["state"] == "locked":
		_build_leaf(front, law)
	if law.get("state", "") == "broken":
		_leaf_set_open(law, false)
	_doors[label] = law
	Log.info("Doors: %s registered (%s)" % [label, law["state"]])


## The plank leaf on a shut front + the line that talks.
## a gratitude open at runtime (the current scene's leaf swings)
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


func _build_leaf(front: Node3D, law: Dictionary) -> void:
	var side := -signf(front.global_position.z) \
			if absf(front.global_position.z) > 1.0 else 1.0
	var leaf := MeshInstance3D.new()
	leaf.name = "DoorLeaf"
	var m := BoxMesh.new()
	m.size = Vector3(1.15, 2.2, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.19, 0.12) \
			if law.get("breakable", false) else Color(0.34, 0.36, 0.4)
	mat.metallic = 0.0 if law.get("breakable", false) else 0.6
	m.material = mat
	leaf.mesh = m
	leaf.position = Vector3(0, 1.1, side * 0.62)
	front.add_child(leaf)
	law["leaf"] = leaf
	var prompt := Label3D.new()
	prompt.name = "DoorPrompt"
	prompt.modulate = Color(1.0, 0.85, 0.55)
	prompt.font_size = 30
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0.01, 0.015, 0.04)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, 2.75, side * 0.7)
	prompt.visible = false
	front.add_child(prompt)
	law["prompt"] = prompt


func _process(_delta: float) -> void:
	# 10 Hz: the approach verb on the nearest door
	_tick += 1
	if _tick % 6 != 0:
		return
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null or not is_instance_valid(hero):
		return
	# lazy purge: laws whose fronts died with a left scene (the area
	# re-registers on its next load; broken state lives in WorldState)
	var stale: Array = []
	for law in _doors.values():
		# read UNTYPED first: assigning a freed instance to a typed
		# var is itself the error (is_instance_valid never runs)
		var n = law["node"]
		if n == null or not (n is Node3D) or not is_instance_valid(n):
			stale.append(law["label"])
	for label in stale:
		_doors.erase(label)
	for law in _doors.values():
		var n = law["node"]
		if n == null or not is_instance_valid(n):
			continue
		var prompt = law.get("prompt")
		if prompt == null or not is_instance_valid(prompt):
			continue
		var near: bool = (n as Node3D).global_position.distance_to(
				hero.global_position) < APPROACH_R
		var saying := Time.get_ticks_msec() < int(_say_until.get(
				law["label"], 0))
		if near and not saying:
			prompt.text = "B: %s" % context_verb(hero.global_position)
			prompt.visible = true
		elif not saying and prompt.visible \
				and prompt.text.begins_with("B: "):
			prompt.visible = false


## The context verb for the B button near a door.
func context_verb(hero_pos: Vector3) -> String:
	var law := _nearest(hero_pos, ACT_R)
	if law.is_empty():
		return ""
	match law["state"]:
		"open":
			return "OPEN"
		"broken":
			return "LOOK"
	if law.get("tried", false) and law.get("breakable", false):
		return "BREAK"
	return "TRY"


## One B press at a door: try it, read the reason, or shoulder it.
## Returns true when a door answered (the hero's action chain stops).
func try_nearest(hero: Node3D) -> bool:
	var law := _nearest(hero.global_position, ACT_R)
	if law.is_empty():
		return false
	match law["state"]:
		"open":
			_say(law, "OPEN - walk in")
			return true
		"broken":
			_say(law, "the frame's splintered - it's yours")
			return true
	if not law.get("tried", false):
		law["tried"] = true
		_rattle(law)
		if law.get("breakable", false):
			_say(law, "LOCKED - %s (B: shoulder it, A: kick it)"
					% law["reason"])
		else:
			_say(law, "LOCKED - %s" % law["reason"])
		WorldState.push_event("door_tried", {"door": law["label"]})
		return true
	if law.get("breakable", false):
		_break_hit(law)
	else:
		_rattle(law)
		_say(law, "it won't move - %s" % law["reason"])
	return true


## The A kick near a tried, breakable locked door lands on the frame.
func kick_door(hero: Node3D) -> void:
	var law := _nearest(hero.global_position, 2.2)
	if law.is_empty() or law["state"] != "locked" \
			or not law.get("breakable", false):
		return
	if not law.get("tried", false):
		try_nearest(hero)
		return
	_break_hit(law)


func _rattle(law: Dictionary) -> void:
	Sound.play("door_close_0", -10.0, 1.7, 0.08)
	Sound.play("creak_0", -12.0, 1.3)
	Haptics.fire("light")
	var leaf: MeshInstance3D = law.get("leaf")
	if leaf:
		var base: Vector3 = leaf.position
		leaf.position = base + Vector3(0.05, 0, 0)
		var tw := create_tween()
		tw.tween_property(leaf, "position", base, 0.13)


func _break_hit(law: Dictionary) -> void:
	var leaf: MeshInstance3D = law.get("leaf")
	if leaf:
		var base: Vector3 = leaf.position
		leaf.position = base + Vector3(0.09, 0, 0)
		var tw := create_tween()
		tw.tween_property(leaf, "position", base, 0.16)
	Sound.play("wood_heavy_0", -2.0, 0.9)
	Sound.play("sub_hit_0", -7.0, 0.8)
	Haptics.fire("heavy")
	Fx.emit_hit("kick", (law["node"] as Node3D).global_position
			+ Vector3.UP)
	WorldState.bump("noise", 0.6)
	law["hits_left"] = int(law.get("hits_left", 1)) - 1
	if int(law["hits_left"]) > 0:
		_say(law, "the frame cracks - %d more" % law["hits_left"])
		return
	_break_open(law)


func _break_open(law: Dictionary) -> void:
	law["state"] = "broken"
	law["hits_left"] = 0
	WorldState.set_flag("door_broken:" + str(law["label"]))
	var leaf: MeshInstance3D = law.get("leaf")
	if leaf:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(leaf, "rotation:y", 1.25, 0.3)
		tw.tween_property(leaf, "position:y", 0.35, 0.3)
		tw.tween_property(leaf, "position:z", leaf.position.z * 0.4, 0.3)
	Sound.play("door_close_0", -4.0, 0.6)
	Sound.play("glass_med_0", -10.0, 0.9)
	Haptics.fire("super")
	Fx.emit_hit("finisher", (law["node"] as Node3D).global_position
			+ Vector3.UP * 1.2)
	WorldState.bump("noise", 1.5)
	WorldState.push_event("door_broken", {"door": law["label"]})
	if int(law.get("stash", 0)) > 0:
		var stash := CLS_STASH.new()
		stash.amount = int(law["stash"])
		stash.label = str(law["label"])
		var n: Node3D = law["node"]
		# BESIDE the doorway (lateral + a step out): dead-centre behind
		# the burst leaf is under the breaker's feet (0.1 m - the
		# suite caught both stashes auto-collecting), and deep behind
		# is inside the building's collider. Lateral reads, is
		# reachable, and never auto-collects (1.3 m from the breaker).
		var side := signf(n.global_position.z) \
				if absf(n.global_position.z) > 1.0 else -1.0
		stash.global_position = n.global_position \
				+ Vector3(0.9, 0.4, -side * 0.9)
		var root := get_tree().current_scene
		(root if root else self).add_child(stash)
	for kind in law.get("ambush", []):
		# the ambush wakes whoever was inside (enemies arrive with the
		# NPC step; the wake is recorded in the world state now)
		WorldState.push_event("ambush_woke", {
				"door": law["label"], "kind": int(kind)})
	_say(law, "the door gives - take what's behind it")


func _leaf_set_open(law: Dictionary, _animate: bool) -> void:
	var leaf: MeshInstance3D = law.get("leaf")
	if leaf:
		leaf.rotation.y = 1.25
		leaf.position.y = 0.35
		leaf.position.z *= 0.4


func _say(law: Dictionary, text: String) -> void:
	var prompt = law.get("prompt")
	if prompt == null or not is_instance_valid(prompt):
		return
	prompt.text = text
	prompt.visible = true
	_say_until[law["label"]] = Time.get_ticks_msec() + int(SAY_S * 1000.0)


func _nearest(hero_pos: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for law in _doors.values():
		var n = law["node"]  # untyped: freed instances fail typed assignment
		if n == null or not is_instance_valid(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(hero_pos)
		if d < best_d:
			best_d = d
			best = law
	return best


func state_of(label: String) -> String:
	return str(_doors.get(label, {}).get("state", ""))


func door_list() -> Array:
	return _doors.values()
