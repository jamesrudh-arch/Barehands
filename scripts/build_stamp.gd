extends Node
const CLS_BuildInfo := preload("res://scripts/build_info.gd")
## BuildStamp (B16): a small corner label, ALWAYS on screen, showing
## batch + commit + build time. The Xogot lesson: "which build is my
## phone running?" must be answerable in one glance - a stale cached
## import looks identical to a fresh one unless the build says its
## name. Also queryable: BuildStamp.line() for the debug menu and
## SafeBoot.

var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.name = "BuildStamp"
	add_child(layer)
	_label = Label.new()
	_label.text = "%s\nruntime %s" % [CLS_BuildInfo.STAMP,
			_runtime_line()]
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -360.0
	_label.offset_right = -8.0
	_label.offset_top = 4.0
	_label.offset_bottom = 66.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.8, 0.8))
	layer.add_child(_label)
	# the window title too - desktop convenience, ignored on phones
	if DisplayServer.get_name() != "headless":
		get_window().title = "LEVERAGE %s" % CLS_BuildInfo.STAMP


## The runtime line: WHICH GODOT is actually executing this. If
## the device's player (Xogot embeds its own engine build) is not
## the version the code was built against, scripts can fail to
## compile ONLY there - one glance at this line answers it.
func _runtime_line() -> String:
	var v: Dictionary = Engine.get_version_info()
	return "%s %s / %s" % [str(v.get("string", "?")),
			OS.get_name(), Engine.get_architecture_name()]


## THE BOOT TRAP (S5.21b): the gray-screen device report - the
## autoloads drew (this label) but the scene script never ran,
## leaving the bare root + clear color. No logs exist on a phone,
## so the trap renders the verdict ON SCREEN at t+6 s. The boot
## scenes carry heartbeat metas: boot_alive (first line of
## _ready) and boot_drawn (first card built).
var _trap_t := 0.0
var _trapped := false


func _process(delta: float) -> void:
	if _trapped:
		return
	_trap_t += delta
	if _trap_t < 6.0:
		return
	_trapped = true
	var sc := get_tree().current_scene
	var why := ""
	if sc == null:
		why = "NO SCENE - main_scene failed to load"
	elif sc.get_script() == null:
		why = "SCRIPT FAILED: %s" % sc.scene_file_path
	elif not sc.has_meta("boot_alive"):
		why = "SCRIPT DID NOT RUN: %s" 				% str(sc.get_script().resource_path)
	elif not sc.has_meta("boot_drawn"):
		why = "READY CRASHED: %s" 				% str(sc.get_script().resource_path)
	if why != "":
		_label.add_theme_color_override("font_color",
				Color(1.0, 0.3, 0.25, 0.95))
		_label.text = "%s\nruntime %s\nBOOT TRAP: %s" 				% [CLS_BuildInfo.STAMP, _runtime_line(), why]
		Log.info("BuildStamp: BOOT TRAP - %s" % why)


# RETIRED (rebuild step 1): the B17 failsafe camera injected a camera
# into any 3D-looking scene whose viewport camera read null — under
# the new boot chain (and in headless, where get_camera_3d() can read
# null while a scene's own camera is fine) it fought the area scenes
# for ownership of `current`. The one-authoritative-implementation
# law: every rebuilt scene owns its camera, and its suite proves it.


## The one-line stamp everything shows.
func line() -> String:
	return CLS_BuildInfo.STAMP


## Multi-line block for logs and the debug menu (Batch 2: the full
## identity - version, batch, exact code commit, build time, config,
## target platform - from the one authoritative build_info.gd).
func block() -> String:
	return "BUILD %s  commit %s  built %s\nconfig: %s\ntarget: %s" % [
			CLS_BuildInfo.BATCH, CLS_BuildInfo.COMMIT, CLS_BuildInfo.BUILT,
			CLS_BuildInfo.CONFIG, CLS_BuildInfo.PLATFORM]
