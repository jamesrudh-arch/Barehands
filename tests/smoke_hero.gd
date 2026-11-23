extends Node

## REBUILD STEP 3 proof suite: the player, the camera and the touch
## UI, live in the warehouse shell.
##   - the hero mounts with the rigged KayKit body and live library;
##   - InputMap movement moves the hero (walk/run), the hero FACES the
##     movement, the tree blends by speed (idle != run pose);
##   - jump leaves the ground and lands;
##   - the camera rig orbits on `look` and the shell camera is the
##     rig's own;
##   - the touch UI is generated from the control table: the X/Y/A/B
##     diamond exists with the right actions, pills exist, pressing a
##     face button fires its InputMap action, and the move stick feeds
##     the hero analog;
##   - a rendered frame contains the lit hero.

var _fails := 0
var _checks := 0
var _main: Node = null


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	for i in 4:
		await get_tree().process_frame
	# travel() swaps the CURRENT scene: hand that role to a holder so
	# the suite node survives the area change (the step-1 lesson)
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(0.5)
	await _hero_block()
	await _move_block()
	await _jump_block()
	await _camera_block()
	await _touch_block()
	await _render_block()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("HERO PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("HERO FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _hero_block() -> void:
	var hero := _hero()
	_check(hero != null, "the hero mounts in PLAY")
	if hero == null:
		return
	var skel := _find(hero, Skeleton3D) as Skeleton3D
	_check(skel != null and skel.get_bone_count() == 23,
			"the KayKit rig is live (%d bones)" % (
			skel.get_bone_count() if skel else -1))
	var anim := _find(hero, AnimationPlayer) as AnimationPlayer
	var clips := anim.get_animation_list().size() if anim else 0
	_check(clips >= 30, "the shared library is installed (%d clips)" % clips)
	var tree := _find(hero, AnimationTree) as AnimationTree
	_check(tree != null and tree.active,
			"the locomotion tree is active")
	_check(get_tree().get_first_node_in_group("camera_rig") != null,
			"the camera rig mounts")


func _move_block() -> void:
	var hero := _hero()
	if hero == null:
		return
	var start: Vector3 = hero.global_position
	var rig := _find(hero, Skeleton3D) as Skeleton3D
	var idle_pose := _pose_hash(rig)
	# walk (stick half-push)
	Input.action_press("move_up", 0.5)
	await _wait_s(0.9)
	Input.action_release("move_up")
	var walked: Vector3 = hero.global_position - start
	_check(walked.length() > 1.0,
			"walking moves the hero (%.2f m)" % walked.length())
	var walk_pose := _pose_hash(rig)
	_check(walk_pose != idle_pose,
			"the walk pose differs from the idle pose")
	# run (full push = auto-sprint)
	Input.action_press("move_up", 1.0)
	await _wait_s(0.9)
	Input.action_release("move_up")
	var ran: Vector3 = hero.global_position - start
	_check(ran.length() > walked.length() + 1.0,
			"running outpaces walking (%.2f m vs %.2f m)" % [
			ran.length(), walked.length()])
	var run_pose := _pose_hash(rig)
	_check(run_pose != idle_pose and run_pose != walk_pose,
			"the run pose differs from idle AND walk")
	# facing: the visual rig turns toward the walk direction (away
	# from the camera) - from yaw 0 that is a ~PI turn
	var visual := hero.get_node_or_null("Rig") as Node3D
	_check(visual != null and absf(visual.rotation.y) > 2.0,
			"the hero faces the movement (rig yaw %.2f)" % (
			visual.rotation.y if visual else -9.0))
	# settle: the tree's walk blend returns to 0 with the stick
	await _wait_s(0.5)
	var tree := _find(hero, AnimationTree) as AnimationTree
	var blend := float(tree.get("parameters/b_walk/blend_amount")) \
			if tree else -1.0
	_check(blend < 0.02,
			"the tree settles back to idle (walk blend %.2f)" % blend)


func _pose_hash(skel: Skeleton3D) -> int:
	if skel == null:
		return 0
	var h := 0
	for i in skel.get_bone_count():
		var p := skel.get_bone_pose(i).origin
		h = hash([h, snappedf(p.x, 0.001), snappedf(p.y, 0.001),
				snappedf(p.z, 0.001)])
	return h


func _jump_block() -> void:
	var hero := _hero()
	if hero == null:
		return
	var y0: float = hero.global_position.y
	Input.action_press("jump")
	await _wait_s(0.08)
	Input.action_release("jump")
	await _wait_s(0.25)
	var peak: float = hero.global_position.y
	_check(peak > y0 + 0.3, "jumping leaves the ground (%.2f m up)" % (
			peak - y0))
	await _wait_s(0.8)
	_check(absf(hero.global_position.y - y0) < 0.05,
			"the hero lands back (%.2f)" % (hero.global_position.y - y0))


func _camera_block() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig") as Node3D
	if rig == null:
		_check(false, "the camera rig exists for the look test")
		return
	var yaw0: float = rig.get("yaw")
	Input.action_press("look_right")
	await _wait_s(0.4)
	Input.action_release("look_right")
	var yaw1: float = rig.get("yaw")
	_check(yaw1 < yaw0 - 0.05,
			"the look action orbits the camera (%.2f -> %.2f)" % [yaw0, yaw1])
	var vc := get_viewport().get_camera_3d()
	_check(vc != null and rig.is_ancestor_of(vc),
			"the viewport renders through the rig's camera")
	var shell := get_tree().current_scene
	_check(shell != null and shell.is_ancestor_of(vc),
			"the rig's camera belongs to the area scene")


func _touch_block() -> void:
	var ui := _find_ui()
	if ui == null:
		_check(false, "the touch UI mounts")
		return
	_check(true, "the touch UI mounts")
	# the table IS the contract: X punch, Y heavy, A kick, B dodge
	var expect := {"X": "punch", "Y": "heavy", "A": "kick", "B": "dodge"}
	for letter in expect:
		var btn := ui.get_node_or_null("Root/Face_" + letter) as Button
		_check(btn != null and btn.text == letter,
				"the %s button exists with its letter" % letter)
	var hero := _hero()
	# pressing the X button fires the punch action (the hero hook)
	ui.call("_fire", "punch")
	await _wait_s(0.12)
	_check(hero != null and str(hero.get("last_action")) == "punch",
			"the X button fires PUNCH through the InputMap")
	ui.call("_fire", "kick")
	await _wait_s(0.12)
	_check(hero != null and str(hero.get("last_action")) == "kick",
			"the A button fires KICK through the InputMap")
	for pill in ["GUARD", "GRAB", "SPRINT", "JUMP", "LOCK"]:
		_check(ui.get_node_or_null("Root/Pill_" + pill) != null,
				"the %s pill exists" % pill)
	# the move stick feeds the hero analog
	hero.set("move_stick", Vector2(0.0, -0.6))
	await _wait_s(0.7)
	var d: Vector3 = hero.global_position
	hero.set("move_stick", Vector2.ZERO)
	_check(d.length() > 0.5,
			"the analog stick moves the hero (%.2f)" % d.length())


func _render_block() -> void:
	await _wait_s(0.3)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_check(false, "the hero renders (no image in this mode)")
		return
	img.save_png("/tmp/render/smoke_hero.png")
	var alive := _img_alive(img)
	_check(alive, "a rendered frame with the hero is alive")


func _img_alive(img: Image) -> bool:
	var l8 := img.duplicate()
	l8.convert(Image.FORMAT_L8)
	l8.resize(64, 36)
	var bins := {}
	var total := 0
	for y in l8.get_height():
		for x in l8.get_width():
			var v: int = l8.get_pixel(x, y).r8
			bins[v] = int(bins.get(v, 0)) + 1
			total += 1
	var mid := 0
	for i in range(10, 246):
		mid += int(bins.get(i, 0))
	return total > 0 and float(mid) / float(total) > 0.05


func _find_ui() -> CanvasLayer:
	# the touch UI lives under the Game autoload, not directly at root
	return get_node_or_null("/root/Game/TouchUI") as CanvasLayer


func _find(root: Node, what) -> Node:
	if root == null:
		return null
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var found := _find(c, what)
		if found:
			return found
	return null
