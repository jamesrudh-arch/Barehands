extends Node
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
const JOINTS := {  # label -> bone-name patterns (first match wins)
	"shoulder": ["upperarm_l", "upperarm_r"],
	"elbow": ["lowerarm_l", "lowerarm_r"],
	"hip": ["pelvis", "hips"],
	"knee": ["calf_l", "thigh_l", "lowerleg_l", "upperleg_l"],
}
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
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
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
	thug.state = Enemy.State.IDLE
	thug.global_position = Vector3(0.0, 0.02, 0.5)
	for clip in CLIPS:
		await _direct_clip("enemy", thug, clip, null)

	# cast NPCs: play through the NpcRig fan-out
	var cast_node := _main.get_node("Cast") as Cast
	for n in cast_node.npcs:
		var rig: NpcRig = (n.node as Node3D).get_node("Rig")
		for clip in CLIPS:
			await _direct_clip(n.name, n.node, clip, rig)

	var lib := UalBind.library()
	for clip in CLIPS:
		var a := lib.get_animation(clip)
		print("POSE   clip %-10s length=%.2fs loop_mode=%d" % [clip, a.length, a.loop_mode])
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
	var rig: HeroRig = _player.get_node("Body/Hero")
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


## NPCs and the enemy: play the clip directly on the rig / player.
func _direct_clip(char_name: String, root: Node3D, clip: String, rig: Node) -> void:
	_current_clip = clip
	if rig:
		rig.play(clip)
	else:
		var ap := _find_ap(root)
		ap.stop()
		ap.play(clip, 0.0)
	await _sample(char_name, root, rig)


func _rig_current(rig: HeroRig) -> String:
	var p := rig.main_player()
	return p.current_animation if p else "?"


## Sample every skeleton in the character over 60 frames.
func _sample(char_name: String, root: Node3D, rig: Node) -> void:
	var skels: Array = root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		_check(false, "%s: no skeletons" % char_name)
		return
	for skel in skels:
		var piece_name := (skel as Node3D).get_parent().name
		var joint_ids := {}
		for label in JOINTS:
			for pattern in JOINTS[label]:
				var id := (skel as Skeleton3D).find_bone(pattern)
				if id >= 0:
					joint_ids[label] = id
					break
		if joint_ids.size() < 3:
			continue  # a skeleton without these bones (none expected)
		# stop the players so a short non-looping clip restarts for THIS
		# skeleton's window (play() on a finished clip would be a no-op)
		for ap in root.find_children("Clips", "AnimationPlayer", true, false):
			ap.stop()
		if rig:
			rig.play(_current_clip)
		# rest pose first, so a frozen T-pose measures ~0
		for label in joint_ids:
			(skel as Skeleton3D).reset_bone_pose(joint_ids[label])
		var rest := {}
		for label in joint_ids:
			rest[label] = (skel as Skeleton3D).get_bone_global_pose(joint_ids[label]).origin
		var max_move := {}
		for label in joint_ids:
			max_move[label] = 0.0
		for f in 60:
			await get_tree().physics_frame
			for label in joint_ids:
				var now := (skel as Skeleton3D).get_bone_global_pose(joint_ids[label]).origin
				max_move[label] = maxf(max_move[label], rest[label].distance_to(now))
		var moved := 0
		for label in joint_ids:
			if max_move[label] >= PASS_MOVE:
				moved += 1
		var line := "%-12s %-10s %-26s" % [char_name, _current_clip, piece_name]
		for label in ["shoulder", "elbow", "hip", "knee"]:
			if max_move.has(label):
				line += " %s=%.3f" % [label, max_move[label]]
		print("POSE   ", line)
		_check(moved >= 3, "%s %s [%s] moves at least 3 joints (moved %d)" % [
				char_name, _current_clip, piece_name, moved])


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null
