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
	_label.text = CLS_BuildInfo.STAMP
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -360.0
	_label.offset_right = -8.0
	_label.offset_top = 6.0
	_label.offset_bottom = 26.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.8, 0.8))
	layer.add_child(_label)
	# the window title too - desktop convenience, ignored on phones
	if DisplayServer.get_name() != "headless":
		get_window().title = "LEVERAGE %s" % CLS_BuildInfo.STAMP


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
