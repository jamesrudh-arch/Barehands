extends Node
## B23 live_boot: the REAL launch path, played live on the software GL
## renderer. Nothing is pre-set (no first_run_done shortcut): main.tscn
## boots (the game IS the main scene now - Stage 0 is a diagnostic, not
## a gate), the first-run picker offers the control scheme, confirming
## it wakes the dormant start sequence (studio card -> title -> menu),
## PLAY is really pressed, the opening shot is really skipped, and the
## hero lands in the apartment. Then the playable basics run through
## the REAL pipelines: stick walk, sprint, the JUMP button, camera
## follow, a save/load roundtrip, the left-handed layout REALLY moving
## buttons, and a gate walk into the next block.
## HONESTY: Linux + llvmpipe at 640x360, NOT an iPhone.
var _fails := 0
var _checks := 0
var _player: Node3D
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("BOOT FAIL: ", what)
	else:
		print("BOOT ok: ", what)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/lp_shots")
	# B27: the events director stands down for the boot battery (this
	# suite asserts walker/watcher counts; smoke_events runs live)
	Settings.set_value("dynamic_events", false)
	# a FRESH user dir is provided by the battery (HOME isolation); the
	# settings file inside it starts empty, so the picker must show
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().create_timer(3.0).timeout
	Visual.apply_profile(Visual.PROFILE_XOGOT_SAFE)

	# --- PHASE 1: the first-run picker and the one-time title ----------
	var picker: Node = null
	for n in _main.get_children():
		if n.has_method("_pick"):
			picker = n
			break
	_check(picker != null and picker.visible,
			"fresh boot shows the control-scheme picker")
	if picker:
		picker.call("_pick", "fight")  # the confirm path a finger takes
	await get_tree().create_timer(2.0).timeout
	# the dormant sequence must have woken: studio card -> title ->
	# loading -> menu. Poll for the menu's PLAY button (up to 30 s).
	var play_btn: Button = null
	var seq: Node = null
	for i in 150:
		for n in _main.get_children():
			if n.has_method("_play"):
				seq = n
		if seq:
			for b in seq.find_children("*", "Button", true, false):
				if (b as Button).text == "PLAY" and b.visible:
					play_btn = b
					break
		if play_btn:
			break
		await get_tree().create_timer(0.2).timeout
	_check(play_btn != null, "the title sequence reached the MAIN MENU")
	if play_btn == null:
		_finish()
		return
	await _shot("01_title_menu")
	_check(_lum_ok("/tmp/lp_shots/01_title_menu.png"),
			"the main menu renders (not a black frame)")
	play_btn.pressed.emit()  # the real button activation
	await get_tree().create_timer(2.0).timeout

	# --- PHASE 2: the opening shot, really skipped ---------------------
	var opening := get_tree().get_first_node_in_group("opening")
	if opening and not bool(opening.get("ever_finished")):
		opening.call("skip")
	await get_tree().create_timer(2.0).timeout
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_check(_player != null, "the hero exists after the real boot path")
	if _player == null:
		_finish()
		return
	await _shot("02_boot_apartment")
	_check(_lum_ok("/tmp/lp_shots/02_boot_apartment.png"),
			"the apartment renders after boot (not a black void)")
	_check(not InputBus.locked, "input is unlocked (no stuck lock)")

	# --- PHASE 3: movement through the REAL stick pipeline --------------
	# movement tests need open floor with NO doors (the apartment door
	# fade warps distance readings): the street landing is known-clear
	_player.global_position = Vector3(-2.0, 0.02, 8.0)
	_player.look_at(Vector3(-2.0, 0.02, -8.0), Vector3.UP)
	Blocks.snap_camera_to(_player)
	await get_tree().create_timer(0.6).timeout
	var stick := get_tree().get_first_node_in_group("stick")
	var start_pos: Vector3 = _player.global_position
	for i in 20:
		if stick:
			stick.set("_target", Vector2(1.0, 0.0))
			stick.set("_active", true)
		await get_tree().create_timer(0.1).timeout
	if stick:
		stick.set("_target", Vector2.ZERO)
		stick.set("_active", false)
	_check(_player.global_position.distance_to(start_pos) > 1.2,
			"walk: the stick moves the hero (%.1f m)" % [
					_player.global_position.distance_to(start_pos)])

	# sprint: holding the REAL SprintBtn while walking
	var walk_spd := await _watch_speed(0.8, 1.2, null)
	var sprint_btn := _find_button("SprintBtn")
	var sprint_spd := await _watch_speed(0.8, 1.2, sprint_btn)
	_check(sprint_btn != null and sprint_spd > walk_spd * 1.15,
			"sprint (held SprintBtn) is faster than walk (%.1f vs %.1f m/s)" % [
					sprint_spd, walk_spd])

	# jump: the REAL JumpBtn pressed
	var jump := _find_button("JumpBtn")
	_check(jump != null, "the JUMP button exists in the layout")
	var max_vy := 0.0
	var ground_y := _player.global_position.y
	if jump:
		# probe: the state the jump gate actually checks
		print("BOOT probe: pre-jump stunned=%s floor=%s since_floor=%.2f" % [
				str(_player.get("stunned")), str(_player.is_on_floor()),
				float(_player.get("_since_floor"))])
		jump.emit_signal("down")
		for i in 8:
			await get_tree().create_timer(0.1).timeout
			max_vy = maxf(max_vy, _player.global_position.y - ground_y)
		print("BOOT probe: post-jump vy=%.2f peak=+%.2f" % [
				(_player as CharacterBody3D).velocity.y, max_vy])
	_check(max_vy > 0.05, "jump lifts the hero (peak +%.2f m)" % max_vy)

	# camera follow: after walking, the camera settles back to its
	# designed band (distance 6.0 + height, lerped - camera_follow.gd)
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	for i in 12:
		if stick:
			stick.set("_target", Vector2(0, -0.8))
			stick.set("_active", true)
		await get_tree().create_timer(0.1).timeout
	if stick:
		stick.set("_target", Vector2.ZERO)
		stick.set("_active", false)
	await get_tree().create_timer(1.5).timeout  # let it settle
	var d1 := cam.global_position.distance_to(_player.global_position)
	_check(d1 > 3.0 and d1 < 10.0,
			"the camera follows and settles into its band (%.1f m)" % d1)

	# --- PHASE 4: save / load roundtrip --------------------------------
	# save/load AWAY from doors (a door fade would race the restore)
	_player.global_position = Vector3(-2.0, 0.02, 8.0)
	await get_tree().create_timer(0.4).timeout
	var saved_ok: bool = SaveGame.save_all()
	var cash0: int = Wallet.cash
	var pos0: Vector3 = _player.global_position
	Wallet.spend(10, "boot-test spend")  # the real purchase path
	var spent: int = Wallet.cash
	_player.global_position += Vector3(1.5, 0, 0)
	var loaded_ok: bool = SaveGame.load_all()
	await get_tree().create_timer(0.5).timeout
	_check(saved_ok and loaded_ok and spent == cash0 - 10
			and Wallet.cash == cash0
			and _player.global_position.distance_to(pos0) < 1.0,
			"save/load restores cash AND position ($%d -> $%d -> $%d, %.1f m)" % [
					cash0, spent, Wallet.cash,
					_player.global_position.distance_to(pos0)])

	# --- PHASE 5: the layout REALLY rearranges --------------------------
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	var punch := _find_button("FightX")
	if punch and hud and hud.has_method("apply_preset"):
		var x0: float = (punch as Control).global_position.x
		hud.call("apply_preset", "left")  # the REAL picker path
		await get_tree().create_timer(0.5).timeout
		var x1: float = (punch as Control).global_position.x
		var flag: bool = bool(Settings.value("left_handed"))
		hud.call("apply_preset", "classic")
		await get_tree().create_timer(0.5).timeout
		var x2: float = (punch as Control).global_position.x
		_check(flag and absf(x1 - x0) > 80.0 and absf(x2 - x1) > 80.0,
				"the layout picker REALLY mirrors and restores (L %.0f px, back %.0f px)" % [
						x1 - x0, x2 - x1])
	else:
		_check(false, "the punch button + picker exist for the layout check")

	# --- PHASE 6: the city connects - a gate walk into the next block ---
	# riverside's east gate sits at x = +19: step into its zone and let
	# the fade + travel land (the travel can fire on the settle frame,
	# so the block id is captured BEFORE the teleport)
	var block0 := Blocks.current()
	_player.global_position = Vector3(19.0, 0.02, 0.0)
	await get_tree().create_timer(2.0).timeout
	var moved_block := Blocks.current() != block0
	for i in 30:
		if Blocks.current() != block0:
			break
		if stick:
			stick.set("_target", Vector2(1.0, 0.0))
			stick.set("_active", true)
		await get_tree().create_timer(0.1).timeout
	if stick:
		stick.set("_target", Vector2.ZERO)
		stick.set("_active", false)
	await get_tree().create_timer(1.5).timeout
	print("BOOT probe: hero at %s, block %s" % [
			str(_player.global_position.round()), Blocks.current()])
	_check(moved_block or Blocks.current() != block0,
			"the gate moved the hero into the next block (%s -> %s)" % [
					block0, Blocks.current()])
	await _shot("03_next_block")
	_check(_lum_ok("/tmp/lp_shots/03_next_block.png"),
			"the next block renders (not a black void)")
	_finish()


func _watch_speed(mag: float, secs: float, hold: Control) -> float:
	# average ground speed over a window of REAL stick driving, with an
	# optional held action button (sprint) driven through its real signal.
	# B26 (the B24 llvmpipe lesson, applied): the window counts PHYSICS
	# frames, not wall time - under the software renderer the idle loop
	# stalls for whole seconds and the physics catch-up cap freezes the
	# sim mid-window, so wall-clock speeds read as fractions of the
	# truth (walk 0.5, sprint 0.1 m/s on the same legs that walk 5.6 m).
	# The sim's own frame count cannot lie about the sim.
	var frames := int(round(secs * 60.0))
	var stick := get_tree().get_first_node_in_group("stick")
	var p0 := _player.global_position
	var moved := 0.0
	if hold:
		hold.emit_signal("down")
	var f := 0
	while f < frames:
		if stick:
			stick.set("_target", Vector2(0, -mag))
			stick.set("_active", true)
		await get_tree().physics_frame
		f += 1
		moved = _player.global_position.distance_to(p0)
	if hold:
		hold.emit_signal("up")
	if stick:
		stick.set("_target", Vector2.ZERO)
		stick.set("_active", false)
	return moved / secs


func _find_button(btn_name: String) -> Control:
	# ActionButton extends Control with custom down/up signals (NOT a
	# Button) - find by name and drive its real signals
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud == null:
		return null
	for c in hud.get_children():
		if c.name == btn_name:
			return c as Control
	return null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/lp_shots/%s.png" % name)
	print("BOOT shot: /tmp/lp_shots/%s.png" % name)


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
	print("BOOT lum %s avg %.3f" % [path.get_file(), avg])
	return avg > 0.03


func _finish() -> void:
	if _fails == 0:
		print("BOOT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("BOOT FAIL (%d of %d)" % [_fails, _checks])
		get_tree().quit(1)
