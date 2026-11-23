extends Node

## USER OVERRIDES R11 / V3 PART D: DOORS THAT TALK, TRY, WARN AND BREAK.
## Every door in the world answers a TRY. OPEN doors let you walk in
## (the five interiors, the venues, the kiosks, the warehouse - their
## proven flows unchanged). The street's shut fronts are LOCKED, and a
## locked door SAYS WHY - one line, at the door, in plain words, with
## a rattle, a shake and a haptic tick. Breakable doors break: B
## presses are shoulder hits, A kicks land on the frame, each hit
## thuds, shakes the camera and raises Heat, the last one splinters
## the door, drops the stash and wakes whoever is inside (breaking in
## is LOUD and it starts a fight). Steel doors refuse and say so.
## A broken door STAYS broken: the registry remembers by label, so a
## street reload re-breaks the frame instead of raising a new door.

const CLS_Pickup := preload("res://scripts/pickup.gd")

## The law table, keyed by the front's label (block_builder names the
## node Front_<LABEL>). Reasons are the street's own words.
const TABLE := {
	"NEON 9": {"state": "locked", "breakable": true, "hits": 3,
		"stash": 80, "ambush": [3, 1],
		"reason": "MEMBERS ONLY - the list closes at midnight"},
	"PALACE": {"state": "locked", "breakable": true, "hits": 2,
		"stash": 30, "ambush": [1],
		"reason": "SHUT - the licence died last spring"},
	"MECHANIC": {"state": "locked", "breakable": false, "hits": 0,
		"stash": 0, "ambush": [],
		"reason": "STEEL SHUTTER - the lift's been dead a month"},
	"IRON PALM GYM": {"state": "open"},
	"THE RAIN GLASS": {"state": "open"},
	"THE VELVET ROOM": {"state": "open"},
}

## The open doors of the world, for the record (their entry flows are
## their own - the walk-in zones, the venue doors, the warehouse gate).
const OPEN_DOORS := ["MAMA SUN'S NOODLES", "YOUR ROOM", "THE KNUCKLE ROOM",
	"THE WAREHOUSE", "THE TAILOR", "THE GEAR COUNTER", "THE PAWN DESK"]

const APPROACH_R := 2.5  # the prompt ring (V3 PART D: about 2 m)
const ACT_R := 2.8       # a try reaches this far

## node path -> the live door record.
var _doors: Dictionary = {}
## label -> true once broken: survives street reloads (the city remembers).
var _broken: Dictionary = {}
## node path -> msec until a spoken line hands the label back to the verb.
var _say_until: Dictionary = {}
var _tick := 0


func _ready() -> void:
	_process_poll()


func _process_poll() -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		_sweep()


## Fronts rise with their block (lazy) - the registry sweeps for them.
func _sweep() -> void:
	for front in get_tree().get_nodes_in_group("shopfront"):
		if _doors.has(front.get_path()):
			continue
		_register(front)


func _register(front: Node3D) -> void:
	var label: String = str(front.name).trim_prefix("Front_")
	var law: Dictionary = TABLE.get(label,
			{"state": "locked", "breakable": false, "hits": 0, "stash": 0,
			"ambush": [], "reason": "NO ANSWER - the bell's dead"})
	var rec := {
		"node": front, "label": label, "state": law["state"],
		"reason": law.get("reason", ""),
		"breakable": bool(law.get("breakable", false)),
		"hits_left": int(law.get("hits", 0)),
		"stash": int(law.get("stash", 0)),
		"ambush": law.get("ambush", []),
		"tried": false, "door_mesh": null, "prompt": null,
	}
	_doors[front.get_path()] = rec
	if rec["state"] == "locked" or _broken.has(label):
		_build_door(front, rec)
		if _broken.has(label):
			# the city remembers: this frame already met the shoulder
			rec["state"] = "broken"
			rec["hits_left"] = 0
			_swing_open(rec, true)
	Log.info("Doors: registered %s (%s)" % [label, rec["state"]])


## The plank door on a shut front: the thing your shoulder meets, and
## the line that talks (approach verb, LOCKED reason, break progress).
func _build_door(front: Node3D, rec: Dictionary) -> void:
	var side := -signf(front.global_position.z)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.15, 2.2, 0.1)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.28, 0.19, 0.12) \
			if rec["breakable"] else Color(0.34, 0.36, 0.4)
	dmat.metallic = 0.0 if rec["breakable"] else 0.6
	dm.material = dmat
	door.mesh = dm
	door.position = Vector3(0, 1.1, side * 0.62)
	front.add_child(door)
	rec["door_mesh"] = door
	var prompt := Label3D.new()
	prompt.text = ""
	prompt.modulate = Color(1.0, 0.85, 0.55)
	prompt.font_size = 30
	prompt.outline_size = 8
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.position = Vector3(0, 2.7, side * 0.7)
	front.add_child(prompt)
	rec["prompt"] = prompt


func _process(_delta: float) -> void:
	# 10 Hz: the approach verb on the nearest door (V3 PART D #1)
	_tick += 1
	if _tick % 6 != 0:
		return
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		return
	for rec in _doors.values():
		var n: Node3D = rec["node"]
		if n == null or not is_instance_valid(n):
			continue
		var prompt: Label3D = rec["prompt"]
		if prompt == null or not is_instance_valid(prompt):
			continue
		var near: bool = n.global_position.distance_to(
				hero.global_position) < APPROACH_R
		var saying: bool = Time.get_ticks_msec() < int(
				_say_until.get(n.get_path(), 0))
		if near and not saying:
			prompt.text = "B: %s" % context_verb(hero.global_position)
			prompt.visible = true
		elif not saying and prompt.visible \
				and prompt.text.begins_with("B: "):
			prompt.visible = false


## The context verb for the B button near a door.
func context_verb(hero_pos: Vector3) -> String:
	var rec := _nearest(hero_pos, ACT_R)
	if rec.is_empty():
		return ""
	match rec["state"]:
		"open":
			return "OPEN"
		"broken":
			return "LOOK"
	var tried: bool = rec["tried"]
	if tried and rec["breakable"]:
		return "BREAK"
	return "TRY"


## One B press at a door: try it, read the reason, or break it down.
## Returns true when a door answered (the hero's grab chain stops).
func try_nearest(hero: Node3D) -> bool:
	var rec := _nearest(hero.global_position, ACT_R)
	if rec.is_empty():
		return false
	match rec["state"]:
		"open":
			_say(rec, "OPEN - walk in")
			return true
		"broken":
			_say(rec, "the frame's splintered - it's yours")
			return true
	# locked: the first try is a hand on the handle - rattle and shake
	if not rec["tried"]:
		rec["tried"] = true
		_rattle(rec)
		if rec["breakable"]:
			_say(rec, "LOCKED - %s (B: shoulder it, A: kick it)" % rec["reason"])
		else:
			_say(rec, "LOCKED - %s" % rec["reason"])
		Log.info("Doors: tried %s - %s" % [rec["label"], rec["reason"]])
		return true
	# tried before: breakable fronts take the shoulder hit, steel refuses
	if rec["breakable"]:
		_break_hit(rec)
	else:
		_rattle(rec)
		_say(rec, "it won't move - %s" % rec["reason"])
	return true


## The A kick near a breakable locked door lands on the frame (the
## kick swing still plays, so it reads as a kick at the door). The
## first kick tries the handle instead - you feel why it will not open.
func kick_door(hero: Node3D) -> void:
	var rec := _nearest(hero.global_position, 2.2)
	if rec.is_empty() or rec["state"] != "locked" or not rec["breakable"]:
		return
	if not rec["tried"]:
		try_nearest(hero)
		return
	_break_hit(rec)


## The handle try: the frame rattles, the hand feels it.
func _rattle(rec: Dictionary) -> void:
	Sound.play("door_close_0", -10.0, 1.7, 0.08)
	Sound.play("creak_0", -12.0, 1.3)
	Haptics.fire("light")
	var mesh: MeshInstance3D = rec["door_mesh"]
	if mesh:
		var base: Vector3 = mesh.position
		mesh.position = base + Vector3(0.05, 0, 0)
		var tw := create_tween()
		tw.tween_property(mesh, "position", base, 0.13)


## One shoulder hit or kick on the frame: it thuds, the camera kicks,
## the street hears it, splinters fly.
func _break_hit(rec: Dictionary) -> void:
	var mesh: MeshInstance3D = rec["door_mesh"]
	var pos: Vector3 = (rec["node"] as Node3D).global_position + Vector3.UP
	if mesh:
		var base: Vector3 = mesh.position
		mesh.position = base + Vector3(0.09, 0, 0)
		var tw := create_tween()
		tw.tween_property(mesh, "position", base, 0.16)
	Sound.play("wood_heavy_0", -2.0, 0.9)
	Sound.play("sub_hit_0", -7.0, 0.8)
	Haptics.fire("heavy")
	Fx.emit_hit("kick", pos)
	var cam := get_tree().get_first_node_in_group("camera") as Node
	if cam and cam.has_method("shake"):
		cam.call("shake", 0.5)
	Heat.add(0.6)
	rec["hits_left"] -= 1
	if rec["hits_left"] > 0:
		_say(rec, "the frame cracks - %d more" % rec["hits_left"])
		Log.info("Doors: hit %s (%d left)" % [rec["label"], rec["hits_left"]])
		return
	_break_open(rec)


## The last hit: the door bursts off its hinge, the stash drops, and
## whoever was inside comes out swinging (breaking in starts a fight).
func _break_open(rec: Dictionary) -> void:
	rec["state"] = "broken"
	rec["hits_left"] = 0
	_broken[rec["label"]] = true
	_swing_open(rec)
	Sound.play("door_close_0", -4.0, 0.6)
	Sound.play("glass_med_0", -10.0, 0.9)
	Haptics.fire("super")
	var cam := get_tree().get_first_node_in_group("camera") as Node
	if cam and cam.has_method("shake"):
		cam.call("shake", 0.9)
	Heat.add(1.5)
	Fx.emit_hit("finisher", (rec["node"] as Node3D).global_position
			+ Vector3.UP * 1.2)
	if int(rec["stash"]) > 0:
		var stash := CLS_Pickup.new()
		stash.setup("cash", int(rec["stash"]))
		stash.position = (rec["node"] as Node3D).global_position \
				+ Vector3(0, 0.4, -signf(
				(rec["node"] as Node3D).global_position.z) * 1.1)
		var root := get_tree().current_scene
		(root if root else self).add_child(stash)
	for kind in rec["ambush"]:
		var e := load("res://scenes/enemy.tscn").instantiate() \
				as CharacterBody3D
		var root2 := get_tree().current_scene
		(root2 if root2 else self).add_child(e)
		e.set("kind", int(kind))
		e.global_position = (rec["node"] as Node3D).global_position \
				+ Vector3(randf_range(-1.6, 1.6), 0.02,
				-signf((rec["node"] as Node3D).global_position.z)
				* randf_range(0.8, 1.8))
	_say(rec, "the door gives - take what's behind it")
	Log.info("Doors: %s broken open (stash %d, ambush %d)" % [
			rec["label"], rec["stash"], (rec["ambush"] as Array).size()])


## The burst-open swing: the leaf tears off its hinge toward the floor.
## A remembered break (scene reload) settles instantly, no ceremony.
func _swing_open(rec: Dictionary, instant := false) -> void:
	var mesh: MeshInstance3D = rec["door_mesh"]
	if mesh == null:
		return
	if instant:
		mesh.rotation.y = 1.25
		mesh.position.y = 0.35
		mesh.position.z *= 0.4
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "rotation:y", 1.25, 0.3)
	tw.tween_property(mesh, "position:y", 0.35, 0.3)
	tw.tween_property(mesh, "position:z", mesh.position.z * 0.4, 0.3)


## The reason line at the door: three seconds, then the approach verb
## takes the label back.
func _say(rec: Dictionary, text: String) -> void:
	var prompt: Label3D = rec["prompt"]
	if prompt == null:
		return
	prompt.text = text
	prompt.visible = true
	_say_until[(rec["node"] as Node).get_path()] = \
			Time.get_ticks_msec() + 3000


func _nearest(hero_pos: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for rec in _doors.values():
		var n: Node3D = rec["node"]
		if n == null or not is_instance_valid(n):
			continue
		var d: float = n.global_position.distance_to(hero_pos)
		if d < best_d:
			best_d = d
			best = rec
	return best


## The registry, for the suite and the record.
func door_list() -> Array:
	var out := []
	for rec in _doors.values():
		out.append(rec)
	return out


func state_of(label: String) -> String:
	for rec in _doors.values():
		if rec["label"] == label:
			return rec["state"]
	return ""


func is_broken(label: String) -> bool:
	return _broken.has(label)
