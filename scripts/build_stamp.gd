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
	_cam_check_t = 0.0
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


# --- the failsafe camera (B17): a 3D scene with meshes and no
# current Camera3D gets one, ~2 s in, logged once. A grey screen
# (default clear colour) means NOTHING is rendering - this makes
# sure a camera at least exists in every 3D scene.

var _cam_check_t := 0.0
var _cam_added := false


func _process(delta: float) -> void:
	if _cam_added:
		return
	_cam_check_t += delta
	if _cam_check_t < 2.0:
		return
	_cam_check_t = 0.0
	if get_viewport().get_camera_3d() != null:
		return  # a real camera is rendering - never interfere
	var has_mesh := false
	var root := get_tree().current_scene
	if root:
		var stack: Array = [root]
		while stack:
			var node = stack.pop_back()
			if node is MeshInstance3D:
				has_mesh = true
				break
			for c in node.get_children():
				stack.append(c)
	if not has_mesh:
		return  # pure 2D scene (Stage0) - no camera needed
	var cam := Camera3D.new()
	cam.name = "FailsafeCamera"
	cam.position = Vector3(4.0, 3.5, 4.0)
	cam.look_at(Vector3.ZERO)
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	_cam_added = true
	push_error("BuildStamp: no Camera3D was active - a FAILSAFE camera "
			+ "was created. A real camera script failed somewhere.")


## The one-line stamp everything shows.
func line() -> String:
	return CLS_BuildInfo.STAMP


## Multi-line block for logs and the debug menu.
func block() -> String:
	return "BUILD %s  commit %s  built %s" % [
			CLS_BuildInfo.BATCH, CLS_BuildInfo.COMMIT, CLS_BuildInfo.BUILT]
