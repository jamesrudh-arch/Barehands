extends Node
const CLS_Cast := preload("res://scripts/cast.gd")
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_HeroRig := preload("res://scripts/hero_rig.gd")
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_UalBind := preload("res://scripts/ual_bind.gd")
## The REAL pose test (Series 2 fix session): animations must actually drive
## bones, not merely report "playing". Every character - hero, the enemy
## mannequin, all four cast NPCs - plays each clip in [Idle, Walk, Sprint,
## Jump, Punch_Jab] for 60 frames while we sample the global poses of
## shoulder, elbow, hip and knee joints on EVERY skeleton the character is
## made of (base body AND outfit pieces - a frozen outfit is exactly the
## T-pose the phone showed). The hero is driven through its real controls
## (velocity, jump, punch) so its own animation driver is part of the test.
## A clip fails if the joints barely leave the rest pose. Numbers printed.

const CLIPS := ["Idle", "Walk", "Sprint", "Jump", "Punch_Jab"]
# B23: the humanoid's joint NODES replace bone sampling - same intent:
# a clip that does not move the limbs is the T-pose regression. Watch
# the TRANSLATING nodes (limb tips ride their parents' rotations; the
# pivot joints themselves only rotate in place)
const JOINTS := ["hand_l", "hand_r", "elbow_l", "elbow_r", "knee_l", "knee_r",
	"foot_l", "foot_r"]
const PASS_MOVE := 0.004  # metres: below this across all joints = frozen

var _main: Node3D
var _player: CharacterBody3D
var _current_clip := "Idle"
var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("POSE FAIL: ", what)
	else:
		print("POSE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # the picker would lock input
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	# hero, driven through its real control path
	for clip in CLIPS:
		await _hero_clip(clip)

	# enemy: AI off (dummy mode), its own player driven directly
	var thug: CharacterBody3D = _main.get_node("Thug")
	thug.set("kind", 0)
	thug.state = CLS_Enemy.State.IDLE
	thug.global_position = Vector3(0.0, 0.02, 0.5)
	for clip in CLIPS:
		await _direct_clip("enemy", thug, clip, null)

	# cast NPCs: play through the NpcRig fan-out
	var cast_node := _main.get_node("Cast") as CLS_Cast
	for n in cast_node.npcs:
		var rig: CLS_NpcRig = (n.node as Node3D).get_node("Rig")
		for clip in CLIPS:
			await _direct_clip(n.name, n.node, clip, rig)

	if _fails == 0:
		print("POSE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("POSE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


## Drive the hero the way the game does: velocity for locomotion, queued
## jump/punch for the rest. Its own _drive_anim picks the clips.
func _hero_clip(clip: String) -> void:
	_current_clip = clip
	_player.velocity = Vector3.ZERO
	InputBus.clear_queues()
	var want_speed := 0.0
	match clip:
		"Walk":
			want_speed = 2.4
		"Sprint":
			want_speed = 5.6
	var rig: CLS_HeroRig = _player.get_node("Body/Hero")
	var got := false
	for i in 40:
		_player.velocity.x = 0.0
		_player.velocity.z = -want_speed  # north, along the street
		if i == 5 and clip == "Jump":
			InputBus.queue_jump()
		if i == 5 and clip == "Punch_Jab":
			InputBus.queue_punch()
		await get_tree().physics_frame
		var cur := _rig_current(rig)
		if clip == "Jump" and cur.begins_with("Jump"):
			got = true
			break
		if cur == clip:
			got = true
			break
	_check(got, "hero driver reaches %s (at %s)" % [clip, _rig_current(rig)])
	await _sample("hero", _player, rig)


## NPCs and the enemy: play the clip directly on the rig.
func _direct_clip(char_name: String, root: Node3D, clip: String, rig: Node) -> void:
	_current_clip = clip
	if rig:
		rig.play(clip)
	await _sample(char_name, root, rig)


func _rig_current(rig: CLS_HeroRig) -> String:
	var p := rig.main_player()
	return p.current_animation if p else "?"


## Sample the humanoid's joints over 60 frames: a clip that leaves
## them at rest is the frozen-figure regression, whatever drives it.
func _sample(char_name: String, root: Node3D, rig: Node) -> void:
	var hums: Array = []
	for n in root.find_children("*", "Node", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).contains("humanoid.gd"):
			hums.append(n)
	if hums.is_empty():
		_check(false, "%s: no humanoid body" % char_name)
		return
	for hum in hums:
		var joints: Dictionary = (hum as Node).get("_joints")
		var watch: Array = []
		for jn in JOINTS:
			if joints.has(jn) and is_instance_valid(joints[jn]):
				watch.append(joints[jn])
		if watch.size() < 4:
			_check(false, "%s: humanoid joints missing" % char_name)
			continue
		if rig:
			rig.play(_current_clip)
		else:
			(hum as Node).call("play", _current_clip)
		var rest := {}
		var max_move := {}
		for jn in watch:
			rest[jn] = (jn as Node3D).global_position
			max_move[jn] = 0.0
		for f in 60:
			await get_tree().physics_frame
			for jn in watch:
				max_move[jn] = maxf(max_move[jn],
						rest[jn].distance_to((jn as Node3D).global_position))
		var moved := 0
		var line := "%-12s %-10s" % [char_name, _current_clip]
		for jn in watch:
			if max_move[jn] >= PASS_MOVE:
				moved += 1
			line += " %s=%.3f" % [(jn as Node3D).name, max_move[jn]]
		print("POSE   ", line)
		_check(moved >= 4, "%s %s moves at least 4 joints (moved %d)" % [
				char_name, _current_clip, moved])


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null
