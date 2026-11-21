extends Control
## Stage0 (B17): the boot scene that CANNOT fail silently. ZERO game
## dependencies: no autoload identifiers, no class_name references, no
## custom resources, no preloads of game scripts - built-in nodes and
## engine singletons only. Even if every autoload and every game
## script fails to parse on a fresh import, this screen still draws
## (dark magenta + text), tells you which build is running, runs a
## numbered boot-stage census of every layer, and writes the log to
## user://boot_log.txt.
##
## The stamp comes from res://VERSION.txt (a plain text file at the
## repo root) read with FileAccess - no script involved.
##
## B18: the banner is set AFTER the census and tells the truth: green
## "all clear, tap LAUNCH FULL GAME" when every stage passed without
## the class cache (Xogot never writes it on device - the phone's
## PERMANENT state), retry guidance only when something actually
## FAILED. B17's banner claimed "FIRST-RUN IMPORT IN PROGRESS - wait,
## then tap RETRY" on that same healthy state, and the owner rightly
## read it as "the game cannot launch".

const MAGENTA := Color(0.16, 0.02, 0.12, 1.0)

var _info: Label
var _banner: Label
var _log_box: TextEdit
var _stage_lines: Array = []
var _stamp := "unknown stamp"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = MAGENTA
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18.0
	col.offset_right = -18.0
	col.offset_top = 12.0
	col.offset_bottom = -12.0
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(col)

	var title := Label.new()
	title.text = "LEVERAGE - STAGE 0 (boot diagnostic)"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95))
	col.add_child(title)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(0.92, 0.8, 0.92))
	col.add_child(_info)

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_banner)

	_log_box = TextEdit.new()
	_log_box.editable = false
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_font_size_override("font_size", 13)
	col.add_child(_log_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	col.add_child(actions)
	# B18: LAUNCH FULL GAME is the FIRST button - it is the one you
	# actually want; SafeBoot is the diagnostic drill-down. It also
	# arms the start sequence (studio card -> title -> menu): suites
	# and SafeBoot boots never set the flag, so they go straight in.
	_big_button(actions, "LAUNCH FULL GAME",
		func():
			Settings.set_value("play_start_sequence", true)
			get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_big_button(actions, "LAUNCH SAFEBOOT",
			func(): get_tree().change_scene_to_file("res://scenes/safe_boot.tscn"))
	_big_button(actions, "COPY LOG", _copy_log)
	_big_button(actions, "RETRY", func(): _run_stages())

	_fill_info()
	_run_stages()


func _big_button(row: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	row.add_child(b)


## The banner: green all-clear or yellow retry-guidance. Green means
## "the census is green, nothing is importing, go play".
func _set_banner(text: String, all_clear: bool) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color",
			Color(0.55, 1.0, 0.6) if all_clear else Color(1.0, 0.95, 0.4))


## Everything the info line shows. Engine singletons only.
func _fill_info() -> void:
	_stamp = _read_stamp()
	var cache_ok := FileAccess.file_exists(
			"res://.godot/global_script_class_cache.cfg")
	var ver: Dictionary = Engine.get_version_info()
	_info.text = "BUILD: %s\nGodot %s %s | renderer: %s | GPU: %s\nwindow: %s | orientation: %s | safe area: %s\ntime: %s | class cache: %s" % [
			_stamp,
			str(ver.get("string", "?")), str(OS.get_name()),
			str(ProjectSettings.get_setting(
					"rendering/renderer/rendering_method", "?")),
			RenderingServer.get_video_adapter_name(),
			str(get_window().size),
			str(DisplayServer.screen_get_orientation()),
			str(DisplayServer.get_display_safe_area()),
			Time.get_datetime_string_from_system(true),
			"EXISTS" if cache_ok else "MISSING",
	]
	# The banner is NOT set here: before the census has run, no honest
	# message exists. _run_stages sets it once the stages are done.
	_banner.text = ""


## The stamp from res://VERSION.txt - a text file, no scripts.
func _read_stamp() -> String:
	var f := FileAccess.open("res://VERSION.txt", FileAccess.READ)
	if f == null:
		return "VERSION.txt missing (is this the repo root import?)"
	var txt := f.get_as_text()
	f.close()
	for line in txt.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("stamp:"):
			return s.trim_prefix("stamp:").strip_edges()
	return "VERSION.txt has no stamp line"


# --- the numbered boot stages -------------------------------------------------


func _stage(num: int, text: String) -> void:
	var line := "%02d  %s" % [num, text]
	_stage_lines.append(line)
	print("[Stage0] ", line)


func _run_stages() -> void:
	_stage_lines = []
	_fill_info()
	_stage(1, "BUILD %s on %s" % [_stamp, OS.get_name()])
	_stage(2, "class cache: %s" % ("EXISTS" if FileAccess.file_exists(
			"res://.godot/global_script_class_cache.cfg") else "MISSING"))

	# 3..: every declared autoload, one guarded step each
	var num := 3
	var dead := 0
	for name in _declared_autoloads():
		var node := get_node_or_null("/root/" + name)
		if node == null:
			dead += 1
			_stage(num, "FAIL  autoload %-12s NULL - did not register" % name)
		elif node.get_script() == null:
			dead += 1
			_stage(num, "FAIL  autoload %-12s alive but its SCRIPT failed to parse" % name)
		else:
			_stage(num, "PASS  autoload %-12s (%s)" % [name, node.get_class()])
		num += 1
	_stage(num, "autoloads alive: %d dead: %d" % [
			_declared_autoloads().size() - dead, dead])
	num += 1

	# SafeBoot: a CODE-BUILT scene (the world assembles in _ready), so
	# the honest check is: the script parsed and carries its build
	# methods - the children only exist once it is in the tree
	num = _check_scene(num, "SafeBoot", "res://scenes/safe_boot.tscn",
			[], "_build_world", true)
	# the full game: a scene-file build (its root is a plain Node3D by
	# design) - the children exist right after instantiate, never
	# added to the tree
	num = _check_scene(num, "FULL GAME", "res://scenes/main.tscn",
			["Player", "Camera"], "", false)

	# The truthful banner (B18): failures get retry guidance; an
	# all-green census without the cache gets a green "go play" that
	# names the button. "FAIL" only ever appears in FAIL lines.
	var failed := false
	for line in _stage_lines:
		if (line as String).find("FAIL") != -1:
			failed = true
			break
	if failed:
		_set_banner("BOOT FAILURES ABOVE - if this is the first run, wait "
				+ "for Xogot's import to fully finish, then tap RETRY. If "
				+ "it stays red, tap COPY LOG and send the log.", false)
	elif not FileAccess.file_exists(
			"res://.godot/global_script_class_cache.cfg"):
		_set_banner("ALL STAGES GREEN - nothing is importing and there is "
				+ "nothing to wait for: Xogot never writes the class cache "
				+ "on device, and this build does not need it. Tap LAUNCH "
				+ "FULL GAME to play.", true)

	_stage(num, "boot stages complete - log written to user://boot_log.txt")
	_flush_log()


func _declared_autoloads() -> Array:
	var names: Array = []
	for prop in ProjectSettings.get_property_list():
		var key: String = str(prop.get("name", ""))
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	return names


## A guarded scene load: load, instantiate (NEVER added to the tree,
## so _ready never runs), check the expected children and their
## scripts, free. A parse failure anywhere shows as a named FAIL.
func _check_scene(num: int, label: String, path: String,
		want: Array, want_method: String, want_root_script: bool) -> int:
	var ps = load(path)
	if ps == null:
		_stage(num, "FAIL  %s: '%s' failed to LOAD" % [label, path])
		return num + 1
	var inst = ps.instantiate()
	if inst == null:
		_stage(num, "FAIL  %s: instantiate() returned null" % label)
		return num + 1
	var missing := []
	if want_root_script and inst.get_script() == null:
		missing.append("root script dead (parse failure)")
	for child_name in want:
		var c = inst.get_node_or_null(NodePath(child_name))
		if c == null:
			missing.append(child_name + " (node missing)")
		elif c.get_script() == null:
			missing.append(child_name + " (script dead)")
	if want_method != "" and not inst.has_method(want_method):
		missing.append("method '%s' missing" % want_method)
	if missing.is_empty():
		_stage(num, "PASS  %s: loads and builds (%s)" % [label,
				", ".join(want) if not want.is_empty()
				else "code-built, script parsed"])
	else:
		_stage(num, "FAIL  %s: %s" % [label, ", ".join(missing)])
	inst.free()
	return num + 1


func _flush_log() -> void:
	var text := _full_log()
	_log_box.text = text
	var f := FileAccess.open("user://boot_log.txt", FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		print("[Stage0] log written to user://boot_log.txt (",
				text.length(), " chars)")


func _full_log() -> String:
	var L: Array = []
	L.append("== LEVERAGE STAGE 0 BOOT LOG ==")
	L.append(_info.text.replace("\n", " | "))
	L.append("")
	L.append_array(_stage_lines)
	L.append("== END OF STAGE 0 LOG ==")
	return "\n".join(L)


func _copy_log() -> void:
	var text := _full_log()
	_log_box.text = text
	DisplayServer.clipboard_set(text)
	print("[Stage0] log copied to clipboard (", text.length(), " chars)")
