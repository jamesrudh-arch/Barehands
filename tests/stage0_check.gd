extends Node
## stage0_check (B17/B18): proves the zero-dependency boot scene. Runs
## on a real renderer: Stage0 must draw (magenta, not Godot's grey),
## fill the info line, run every boot stage, write user://boot_log.txt,
## and hold all four buttons - with the class cache DELETED (the
## fresh-import condition) and with it present. B18 adds the truthful
## banner: green "tap LAUNCH FULL GAME" only when everything passed
## WITHOUT the cache (the phone's permanent state), retry guidance
## only on real failures, silence when the cache exists - and
## LAUNCH FULL GAME must be the first button.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("STAGE0 FAIL: ", what)
	else:
		print("STAGE0 ok: ", what)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("STAGE0 SKIP: no display")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var s0: Node = load("res://scenes/stage0.tscn").instantiate()
	add_child(s0)
	await get_tree().create_timer(2.5).timeout

	# the info line + the stamp on it
	var labels: Array = []
	for c in _walk(s0):
		if c is Label and (c as Label).text.length() > 40:
			labels.append(c)
	_check(labels.size() >= 1, "the info line is filled (%d long labels)" % labels.size())
	var stamp_seen := false
	for l in labels:
		if "BUILD: " in (l as Label).text:
			var t: String = (l as Label).text
			stamp_seen = ("unknown" not in t) and ("missing" not in t.split("\n")[0])
	_check(stamp_seen, "the build stamp is on the info line")

	# the log box + the stages ran
	var boxes: Array = []
	for c in _walk(s0):
		if c is TextEdit:
			boxes.append(c)
	_check(boxes.size() >= 1, "the log panel exists")
	if boxes:
		var txt: String = (boxes[0] as TextEdit).text
		_check(txt.length() > 300, "the boot stages ran (%d chars)" % txt.length())
		_check("PASS  autoload" in txt, "at least one autoload PASS line")
		_check("PASS  SafeBoot: loads and builds" in txt,
				"the SafeBoot stage passed its load check")
		_check("PASS  FULL GAME: loads and builds" in txt,
				"the full-game stage passed its load check")

	# boot_log.txt on disk
	var f := FileAccess.open("user://boot_log.txt", FileAccess.READ)
	_check(f != null and f.get_as_text().length() > 300,
			"user://boot_log.txt written")
	if f:
		f.close()

	# the four buttons
	var names := {}
	for c in _walk(s0):
		if c is Button:
			names[(c as Button).text] = true
	for want in ["LAUNCH SAFEBOOT", "LAUNCH FULL GAME", "COPY LOG", "RETRY"]:
		_check(names.has(want), "button '%s' exists" % want)

	# B18: LAUNCH FULL GAME is the FIRST button (the one you want)
	var btns: Array = []
	for c in _walk(s0):
		if c is Button:
			btns.append(c)
	_check(btns.size() >= 4 and (btns[0] as Button).text == "LAUNCH FULL GAME",
			"LAUNCH FULL GAME is the first button (of %d)" % btns.size())

	# B18: the truthful banner - the only autowrap Label on the screen
	var cache_ok := FileAccess.file_exists(
			"res://.godot/global_script_class_cache.cfg")
	var banner: Label = null
	for c in _walk(s0):
		if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			banner = c
	_check(banner != null, "the banner label exists")
	var log_txt: String = (boxes[0] as TextEdit).text if boxes.size() > 0 else ""
	var has_fail := log_txt.find("FAIL") != -1
	if banner:
		if has_fail:
			_check("BOOT FAILURES" in banner.text and "RETRY" in banner.text,
					"failure banner points at RETRY")
			_check(not ("ALL STAGES GREEN" in banner.text),
					"failure banner never claims all-clear")
		elif not cache_ok:
			_check("ALL STAGES GREEN" in banner.text
					and "LAUNCH FULL GAME" in banner.text
					and "nothing to wait for" in banner.text,
					"no-cache all-clear banner names LAUNCH FULL GAME")
			var bc: Color = banner.get_theme_color("font_color")
			_check(bc.g > bc.r, "the all-clear banner reads green (g %.2f > r %.2f)"
					% [bc.g, bc.r])
		else:
			_check(banner.text == "", "cache-present all-green run shows no banner")

	# the frame: magenta, visibly drawn, NOT Godot's default grey
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/stage0.png")
	var c := img.get_pixel(img.get_width() / 2, 8)
	_check(c.r > 0.10 and c.b > 0.06 and c.g < 0.08,
			"the clear colour is the dark magenta (%.2f,%.2f,%.2f)" % [c.r, c.g, c.b])
	_check(not (absf(c.r - 0.3) < 0.02 and absf(c.g - 0.3) < 0.02
			and absf(c.b - 0.3) < 0.02), "not Godot's default grey")

	print("STAGE0 %s (%d checks)" % ["PASS" if _fails == 0 else "FAIL", _checks])
	get_tree().quit(0 if _fails == 0 else 1)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
