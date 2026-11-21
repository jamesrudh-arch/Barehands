#!/usr/bin/env python3
"""B17 wire: identity, fresh-import robustness, and the known bugs.

- project.godot: name "LEVERAGE B17" (unique per push), Stage0 main
  scene, dark magenta default clear colour ("the game is drawing" is
  visible even with no camera).
- jobs.gd: guard the City.entered_district connect (the one runtime
  Nil abort the reproduction caught beyond the parse failures).
- build_stamp.gd: the failsafe camera (any 3D scene with meshes and no
  current Camera3D gets one after ~2 s).
- safe_boot.gd: the last 10 errors, read from user://logs/godot.log.
- rain.gd: code-generated streak/dot textures (no imported texture
  dependency, no pale squares).
- smoke_null_watch.gd: full 27-autoload census in the 600-frame judge.
- touch_buttons.gd: re-clamp the safe area when the window is resized
  or the orientation changes (landscape).
- tools/gen_build_info.py + CI workflow: paths after the root move.
"""
import re

BASE = "/home/z/my-project/"


def patch(path, pairs, root=BASE):
    s = open(root + path, errors="replace").read()
    for old, new in pairs:
        if old not in s:
            if new in s:
                print("  (already)", path)
                continue
            raise SystemExit("%s: anchor not found:\n%r" % (path, old[:120]))
        if s.count(old) != 1:
            raise SystemExit("%s: anchor not unique: %r" % (path, old[:90]))
        s = s.replace(old, new)
    open(root + path, "w").write(s)
    print("patched", path)


# --- 1. project.godot ---------------------------------------------------------
patch("project.godot", [
    (
        'config/name="LEVERAGE (Bare Hands) B16"',
        # unique EVERY push: Xogot caches projects by name (the B16
        # lesson - a stale cached copy loaded under the old name)
        'config/name="LEVERAGE B17"',
    ),
    (
        'run/main_scene="res://scenes/safe_boot.tscn"',
        # Stage0 first: the zero-dependency boot diagnostic; SafeBoot
        # and the full game are one tap deeper
        'run/main_scene="res://scenes/stage0.tscn"',
    ),
])

# default clear colour -> dark magenta (distinct from Godot's grey)
pg = open(BASE + "project.godot").read()
if "default_clear_color" not in pg:
    assert pg.count("[rendering]\n") == 1
    pg = pg.replace("[rendering]\n",
                    '[rendering]\n\n'
                    '# B17: a distinct dark magenta - if you ever see\n'
                    '# Godot\'s default GREY, nothing is drawing at all\n'
                    'environment/defaults/default_clear_color=Color(0.16, 0.02, 0.12, 1)\n',
                    1)
    open(BASE + "project.godot", "w").write(pg)
    print("patched project.godot (clear colour)")

# --- 2. jobs.gd: the entered_district guard ------------------------------------
patch("scripts/jobs.gd", [
    (
        "\tCity.entered_district.connect(_on_district)",
        """	if City != null:
		City.entered_district.connect(_on_district)
	else:
		push_error("Jobs: City autoload missing - district jobs paused")""",
    ),
])

# --- 3. build_stamp.gd: the failsafe camera ------------------------------------
patch("scripts/build_stamp.gd", [
    (
        """func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS""",
        """func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cam_check_t = 0.0""",
    ),
    (
        """## The one-line stamp everything shows.
func line() -> String:""",
        """# --- the failsafe camera (B17): a 3D scene with meshes and no
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
func line() -> String:""",
    ),
])

# --- 4. safe_boot.gd: last 10 errors from the engine log ------------------------
patch("scripts/safe_boot.gd", [
    (
        '''	L.append("== END OF LOG (COPY LOG puts all of this on the clipboard) ==")''',
        '''	L.append("-- LAST 10 ERRORS (from this run's engine log)")
	L.append_array(_last_errors())
	L.append("== END OF LOG (COPY LOG puts all of this on the clipboard) ==")''',
    ),
    (
        '''func _autoload_census() -> Array[String]:''',
        '''## The tail of Godot's own log for this run: the last 10 error
## lines. In-game GDScript cannot capture native errors, but the
## engine writes them to user://logs/godot.log (Xogot included).
func _last_errors() -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open("user://logs/godot.log", FileAccess.READ)
	if f == null:
		out.append("  (no engine log file yet: user://logs/godot.log)")
		return out
	var errs: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if "ERROR" in line or "SCRIPT ERROR" in line:
			errs.append("  " + line.strip_edges())
	f.close()
	if errs.is_empty():
		out.append("  (no error lines in this run's log)")
	else:
		for e in errs.slice(maxi(0, errs.size() - 10), errs.size()):
			out.append(e)
	return out


func _autoload_census() -> Array[String]:''',
    ),
])

# --- 5. rain.gd: textured streaks and dots (no more pale squares) ---------------
patch("scripts/rain.gd", [
    (
        """	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# without this the quads do not face the camera on Mobile and
	# read as raw squares (the pale-block bug)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var qm := QuadMesh.new()
	qm.size = Vector2(0.008, 0.30)
	qm.material = mat""",
        """	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# without this the quads do not face the camera on Mobile and
	# read as raw squares (the pale-block bug)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# B17: a code-generated streak texture. An UNTEXTURED quad is a
	# pale square when it catches the eye broadside; a soft-edged
	# streak texture is a raindrop at every angle (and needs no
	# imported file, so a fresh import cannot lose it).
	mat.albedo_texture = _streak_texture()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.008, 0.30)
	qm.material = mat""",
    ),
    (
        """	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var qm := QuadMesh.new()
	qm.size = Vector2(0.045, 0.045)
	qm.material = mat
	_splash.mesh = qm""",
        """	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _dot_texture()  # B17: soft dot, not a square
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	qm.material = mat
	_splash.mesh = qm""",
    ),
    (
        """func _build_rain() -> void:""",
        """## A 4x32 soft vertical streak, code-generated (no import).
func _streak_texture() -> ImageTexture:
	var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		var t := absf(float(y) - 15.5) / 15.5
		var a := clampf(1.0 - t * t, 0.0, 1.0) * 0.85
		for x in range(4):
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## A 16x16 soft radial dot for splashes.
func _dot_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 7.5
			var a := clampf(1.0 - d * d, 0.0, 1.0) * 0.8
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _build_rain() -> void:""",
    ),
])

# --- 6. smoke_null_watch.gd: the full census ------------------------------------
patch("tests/smoke_null_watch.gd", [
    (
        """	_check(Music != null, "the Music singleton is alive (the :38 root cause)")""",
        """	_check(Music != null, "the Music singleton is alive (the :38 root cause)")
	var census := ["Tuning", "InputBus", "Settings", "Haptics", "SuperMeter",
			"ComboInput", "Progression", "Log", "Quality", "Visual", "Fx",
			"Sound", "Music", "Tactics", "Composure", "FightScore", "Styles",
			"Wallet", "Heat", "City", "SaveGame", "Dialogue", "Trust",
			"Phone", "Ledger", "FriendHelp", "BuildStamp"]
	var dead := []
	for n in census:
		if get_node_or_null("/root/" + n) == null:
			dead.append(n)
	_check(dead.is_empty(), "every autoload alive at frame 600 (dead: %s)"
			% (", ".join(dead) if not dead.is_empty() else "none"))""",
    ),
])

# --- 7. touch_buttons.gd: re-clamp on resize / orientation ----------------------
patch("scripts/touch_buttons.gd", [
    (
        """func _ready() -> void:
	add_to_group("hud_buttons")""",
        """func _ready() -> void:
	add_to_group("hud_buttons")
	# B17: rotate the phone or resize the window and the safe area
	# changes - the buttons must follow (landscape with a notch ate
	# the corner buttons on device)
	get_viewport().size_changed.connect(_clamp_safe_area)""",
    ),
])

# --- 8. tools/gen_build_info.py: paths after the root move ----------------------
patch("tools/gen_build_info.py", [
    ("bare-hands/scripts/build_info.gd", "scripts/build_info.gd"),
    ("Which folder to import: bare-hands/ (the folder that contains",
     "Which folder to import: the folder that contains"),
], root=BASE)

# --- 9. CI: the project is at the repo root now ---------------------------------
ci = open(BASE + ".github/workflows/godot-check.yml").read()
ci = ci.replace("--path bare-hands --import", "--path . --import")
ci = ci.replace("--path bare-hands res://tests/run_tests.tscn",
                "--path . res://tests/run_tests.tscn")
ci = ci.replace("          cd bare-hands\n", "          cd .\n")
ci = ci.replace("timeout 300 ../Godot_v4.7.2-stable_linux.x86_64",
                "timeout 300 ./Godot_v4.7.2-stable_linux.x86_64")
open(BASE + ".github/workflows/godot-check.yml", "w").write(ci)
print("patched .github/workflows/godot-check.yml")

print("B17 wire complete")
