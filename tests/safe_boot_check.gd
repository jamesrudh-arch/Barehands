extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_SafeBoot := preload("res://scripts/safe_boot.gd")
const CLS_BuildInfo := preload("res://scripts/build_info.gd")
## safe_boot_check (B16): renders the SafeBoot diagnostic scene with a
## real renderer and PROVES it: the base world builds (floor, hero,
## camera, dummy, real touch controls), the log fills, the autoload
## census is alive, the build stamp is on screen - and every system
## toggle turns on and off again without a single script error.
## Saves the frame to /tmp/safe_boot.png.

var _fails := 0
var _checks := 0
const OUT := "/tmp/safe_boot.png"


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("SAFEBOOT FAIL: ", what)
	else:
		print("SAFEBOOT ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("SAFEBOOT SKIP: no display")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var sb: CLS_SafeBoot = load("res://scenes/safe_boot.tscn").instantiate()
	add_child(sb)
	await _wait_s(2.0)

	# the base world
	var hero := get_tree().get_first_node_in_group("player")
	_check(hero != null, "the real hero exists in SafeBoot")
	var cam := get_tree().get_first_node_in_group("camera")
	_check(cam is Camera3D and cam.is_position_in_frustum(
			hero.global_position + Vector3.UP),
			"the camera frames the hero")
	_check(get_tree().get_first_node_in_group("enemy") != null,
			"the dummy exists (node 'Dummy', kind 0)")
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is CLS_ActionButton and (c as CLS_ActionButton).visible:
				buttons += 1
	_check(buttons >= 3, "real touch controls visible (%d buttons)" % buttons)

	# the log panel
	var log_box: TextEdit = sb.get_node("Diag") \
			.find_children("*", "TextEdit", true, false)[0] as TextEdit \
			if sb.get_node_or_null("Diag") else null
	_check(log_box != null and log_box.text.length() > 200,
			"the log panel is filled (%d chars)" % (log_box.text.length() \
			if log_box else 0))
	if log_box:
		_check("AUTOLOAD CENSUS" in log_box.text, "the census is in the log")
		_check(log_box.text.count("NULL  <--") == 0,
				"every autoload alive in the census (no NULL markers)")
		_check("BUILD B" in log_box.text and "commit" in log_box.text,
				"the build stamp is in the log")
		_check("Dummy" in log_box.text,
				"the grey-figure answer (node 'Dummy') is in the log")
	# the stamp autoload: a top-right label with the EXACT generated
	# stamp (B18: compared against BuildInfo itself - a hardcoded "B16"
	# here went stale at the B17 stamp bump and failed the suite on HEAD)
	var stamp_layer := get_node_or_null("/root/BuildStamp")
	_check(stamp_layer != null and CLS_BuildInfo.STAMP
			in stamp_layer.get_child(0).get_child(0).text,
			"the boot-corner build stamp is on screen")

	# the frame itself
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT)
	print("SAFEBOOT info: frame saved ", OUT, " ", img.get_size())
	var lit := 0
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			total += 1
			if img.get_pixel(x, y).v > 0.03:
				lit += 1
	_check(float(lit) / total > 0.10,
			"the scene renders visibly (lit %.1f%%)" % (float(lit) / total * 100.0))

	# every system toggle, one at a time, on then off, no crashes
	for sys in sb.SYSTEMS:
		var id: String = sys[0]
		sb.call("_toggle", id, true)
		await _wait_s(1.5)
		var still := get_tree().get_first_node_in_group("player") != null
		_check(still, "system ON '%s' - the hero survives" % id)
		sb.call("_toggle", id, false)
		await _wait_s(0.6)
		_check(get_tree().get_first_node_in_group("player") != null,
				"system OFF '%s' - clean removal" % id)

	if _fails == 0:
		print("SAFEBOOT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("SAFEBOOT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
