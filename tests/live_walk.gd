extends Node
## PHASE SIXTEEN, part 1: the walk-out, proven live. This is the
## exact flow the LPD probe validated on the software renderer: boot,
## place the hero in the apartment like a save point, aim the camera,
## then drive the REAL stick pipeline (_target - the variable a finger
## drag produces) and walk out through the self-opening door.
## HONESTY: Linux + llvmpipe, NOT an iPhone. Run like live_play.
var _fails := 0
var _checks := 0
var _player: Node3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("WALK FAIL: ", what)
	else:
		print("WALK ok: ", what)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/lp_shots")
	Settings.set_value("first_run_done", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	Visual.apply_profile(Visual.PROFILE_XOGOT_SAFE)
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		print("WALK FAIL: no player")
		get_tree().quit(1)
		return
	_player.global_position = Vector3(780.0, 0.02, 1.8)
	_player.look_at(Vector3(780.0, 0.02, -3.2), Vector3.UP)
	var blocks := get_tree().root.get_node_or_null("/root/Blocks")
	if blocks:
		blocks.call("snap_camera_to", _player)
	var follow := get_tree().get_first_node_in_group("camera")
	if follow:
		follow.set("_yaw", 0.0)  # look at the door (-Z)
	var guide := get_tree().get_first_node_in_group("guide")
	guide.set("step", 1)  # STEP_OPEN: the door opens itself on approach
	await get_tree().create_timer(1.5).timeout
	await _shot("01_apartment_hero")
	_check(_lum_ok("/tmp/lp_shots/01_apartment_hero.png"),
			"the apartment renders (not a black void)")
	# walk to the door through the stick pipeline
	var stick := get_tree().get_first_node_in_group("stick")
	var opened := false
	for i in 120:  # up to 12 s
		if stick:
			stick.set("_target", Vector2(0, -0.85))
			stick.set("_active", true)
		await get_tree().create_timer(0.1).timeout
		var st := _door_state()
		if st != "closed" or _player.global_position.x < 700.0:
			opened = true
			break
	if stick:
		stick.set("_target", Vector2.ZERO)
		stick.set("_active", false)
	_check(opened, "the door opened on walk-in (%s)" % _door_state())
	await get_tree().create_timer(4.0).timeout  # the fade completes
	_check(_player.global_position.x < 700.0,
			"the hero walked OUT to the street (%s)" % str(_player.global_position.round()))
	await get_tree().create_timer(1.5).timeout
	await _shot("02_street_landing")
	_check(_lum_ok("/tmp/lp_shots/02_street_landing.png"),
			"the street renders (not a black void)")
	if _fails == 0:
		print("WALK PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("WALK FAIL (%d of %d)" % [_fails, _checks])
		get_tree().quit(1)


func _door_state() -> String:
	for n in get_tree().get_nodes_in_group("door_prompt"):
		if str(n.get_meta("door_name", "")).contains("APARTMENT"):
			return str(n.get_meta("door_state", "?"))
	return "none"


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/lp_shots/%s.png" % name)
	print("WALK shot: /tmp/lp_shots/%s.png" % name)


func _lum_ok(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null:
		return false
	img.convert(Image.FORMAT_L8)
	var lum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			lum += img.get_pixel(x, y).r
			n += 1
	var avg := lum / maxf(n, 1.0)
	print("WALK lum %s avg %.3f" % [path.get_file(), avg])
	# the rigorous luminance law lives in render_check; here 0.03 is
	# the live floor (a true black void is ~0.01)
	return avg > 0.03
