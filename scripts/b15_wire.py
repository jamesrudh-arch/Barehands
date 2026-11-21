#!/usr/bin/env python3
"""B15 wire: the six Xogot visual bugs, fixed at the source.

Bug 1 signs/doors pure white + orange halo: the environment glowed
everything above hdr 1.05 (bloomed windows sat at energy 1.4, neon at
~3.5). New baked defaults: ACES tonemap, glow 0.5 / bloom 0.05 /
hdr 1.45, windows 0.85, neon capped at 1.8 and scaled by the Visual
profile. Signs keep their shape with a dark outline.

Bug 2 pale squares: rain and splash particle materials never set
BILLBOARD_PARTICLE - on Mobile the quads can show face-on as raw
squares. Now billboarded; the ground glow and oil-stain quads swap
their flat alpha fill for radial gradient textures.

Bug 3 grey figure: the boot-area Dummy was literally Color(0.55,
0.55, 0.6) - a grey man in the street. Re-tinted a worn tan training
dummy.

Bug 4 flat teal strip / no hero: the opening cinematic hides the
whole HUD and freezes the camera until _finish(); if it ever stalls
the game strands. Now: PROCESS_MODE_ALWAYS, _end captured deferred
(after the camera's own _ready), and a 12 s watchdog force-finishes.

Bug 5 touch controls: buttons exist but ignored the phone safe area;
_apply_layout now clamps every button inside it (canvas coords via
the viewport transform). Landscape lock confirmed (orientation=0).

Bug 6 rain too thick: quad 0.012x0.34 -> 0.008x0.30, scale 0.6-1.1,
alpha 0.26.

Plus the Visual autoload hooks: windows carry base_energy metadata
and join "emissive_window", neon joins "neon", RainLayer gets
visual_apply(), Enemy gets set_edge_glow(), FollowCamera gets
snap_framing(), the debug menu gains a VISUAL DEBUG button.
"""
import re

P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        if old not in s:
            if new in s:
                print("  (already)", path, old[:48].replace("\n", "\\n"))
                continue
            raise SystemExit("%s: anchor not found: %r" % (path, old[:80]))
        if s.count(old) != 1:
            raise SystemExit("%s: anchor not unique: %r" % (path, old[:80]))
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# --- 1. main.tscn: environment defaults + groups for Visual ---------------
patch("scenes/main.tscn", [
    (
        "tonemap_mode = 2",
        "tonemap_mode = 3",
    ),
    (
        "glow_intensity = 0.70",
        "glow_intensity = 0.50",
    ),
    (
        "glow_bloom = 0.1",
        "glow_bloom = 0.05",
    ),
    (
        "glow_hdr_threshold = 1.05",
        "glow_hdr_threshold = 1.45",
    ),
    (
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]',
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="." groups=["world_env"]]',
    ),
    (
        '[node name="Moon" type="DirectionalLight3D" parent="."]',
        '[node name="Moon" type="DirectionalLight3D" parent="." groups=["street_lights"]]',
    ),
])

# --- 2. project.godot: the Visual autoload --------------------------------
patch("project.godot", [
    (
        'Quality="*res://scripts/quality.gd"',
        'Quality="*res://scripts/quality.gd"\nVisual="*res://scripts/visual.gd"',
    ),
])

# --- 3. block_builder: windows, signs, glow quads, stains ------------------
patch("scripts/block_builder.gd", [
    # windows: energy 0.85, group + base metadata for the Visual profile
    (
        """			if lit:
				wmat.albedo_color = Color(1.0, 0.82, 0.45)
				wmat.emission_enabled = true
				wmat.emission = Color(1.0, 0.7, 0.3)
				wmat.emission_energy_multiplier = 1.4""",
        """			if lit:
				wmat.albedo_color = Color(1.0, 0.82, 0.45)
				wmat.emission_enabled = true
				wmat.emission = Color(1.0, 0.7, 0.3)
				# 0.85 stays under the 1.45 glow threshold: warm
				# windows, not orange halos (the Xogot lesson)
				wmat.emission_energy_multiplier = 0.85""",
    ),
    (
        """			win.rotation = Vector3(0, PI, 0) if cz < 0 else Vector3.ZERO
			add_child(win)""",
        """			win.rotation = Vector3(0, PI, 0) if cz < 0 else Vector3.ZERO
			if lit:
				win.add_to_group("emissive_window")
				win.set_meta("base_energy", 0.85)
			add_child(win)""",
    ),
    # signs: keep their shape when dimmer - a dark outline
    (
        """	var sign := Label3D.new()
	sign.text = label
	sign.modulate = color
	sign.font_size = 64""",
        """	var sign := Label3D.new()
	sign.text = label
	sign.modulate = color
	sign.font_size = 64
	sign.outline_size = 10
	sign.outline_color = Color(0.02, 0.02, 0.05)""",
    ),
    # the ground glow: flat pale quad -> radial gradient pool of light
    (
        """	var glow := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(w, 1.4)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(color.r, color.g, color.b, 0.16)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material = gmat""",
        """	var glow := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(w, 1.4)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 1, 1, 0.55)
	gmat.albedo_texture = _radial(color, 0.34)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material = gmat""",
    ),
    (
        """	glow.position = Vector3(0, 0.04, 1.2)
	glow.rotation = Vector3(-PI / 2.0, 0, 0)
	if pos.z > 0:
		glow.position = Vector3(0, 0.04, -1.2)
	g.add_child(glow)""",
        """	glow.position = Vector3(0, 0.04, 1.2)
	glow.rotation = Vector3(-PI / 2.0, 0, 0)
	if pos.z > 0:
		glow.position = Vector3(0, 0.04, -1.2)
	glow.add_to_group("decal")
	g.add_child(glow)""",
    ),
    # oil stains: flat dark quads -> soft radial patches
    (
        """		var stm := QuadMesh.new()
		stm.size = Vector2(1.1, 0.8)
		var stmat := StandardMaterial3D.new()
		stmat.albedo_color = Color(0.02, 0.02, 0.03, 0.6)
		stmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stm.material = stmat""",
        """		var stm := QuadMesh.new()
		stm.size = Vector2(1.1, 0.8)
		var stmat := StandardMaterial3D.new()
		stmat.albedo_color = Color(1, 1, 1, 0.8)
		stmat.albedo_texture = _radial(Color(0.02, 0.02, 0.03), 0.75)
		stmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stm.material = stmat""",
    ),
    (
        """		stain.rotation = Vector3(-PI / 2.0, 0, randf() * PI)
		add_child(stain)""",
        """		stain.rotation = Vector3(-PI / 2.0, 0, randf() * PI)
		stain.add_to_group("decal")
		add_child(stain)""",
    ),
])

# the _radial helper (appended near the top of the class, before _front)
s = open(P + "scripts/block_builder.gd").read()
anchor = "## A lit shop front (kiosk): sign quad + door + glow on the ground."
helper = '''## A soft radial pool: transparent centre colour fading to nothing.
## The Xogot lesson: a flat alpha quad reads as a pale square block
## on Mobile; a radial gradient reads as light on wet asphalt.
func _radial(color: Color, peak: float) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, peak))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	grad.add_point(0.55, Color(color.r, color.g, color.b, peak * 0.35))
	tex.gradient = grad
	return tex


'''
if helper not in s:
    assert s.count(anchor) == 1
    s = s.replace(anchor, helper + anchor)
    open(P + "scripts/block_builder.gd", "w").write(s)
    print("block_builder radial helper added")

# --- 4. neon: cap + Visual multiplier + group ------------------------------
patch("scripts/neon.gd", [
    (
        """	_mat = (m as StandardMaterial3D).duplicate()
	mi.mesh.surface_set_material(0, _mat)
	_base = _mat.emission_energy_multiplier""",
        """	_mat = (m as StandardMaterial3D).duplicate()
	mi.mesh.surface_set_material(0, _mat)
	# capped: above ~2 the sign stops being a sign and becomes a
	# white block with a halo (the Xogot lesson)
	_base = minf(_mat.emission_energy_multiplier, 1.8)
	_mat.emission_energy_multiplier = _base
	add_to_group("neon")""",
    ),
    (
        """func _process(delta: float) -> void:
	if _mat == null:
		return
	_t += delta""",
        """func _process(delta: float) -> void:
	if _mat == null:
		return
	# the Visual profile scales every sign together (XOGOT SAFE caps
	# emission so colour and detail survive)
	var _m := float(get_meta("emission_mult", 1.0))
	_t += delta""",
    ),
    (
        """			_mat.emission_energy_multiplier = _base * (0.95 + 0.05 * sin(_t * 1.7 + _seed))""",
        """			_mat.emission_energy_multiplier = _base * _m * (0.95 + 0.05 * sin(_t * 1.7 + _seed))""",
    ),
    (
        """			_mat.emission_energy_multiplier = _base * dip""",
        """			_mat.emission_energy_multiplier = _base * _m * dip""",
    ),
    (
        """			_mat.emission_energy_multiplier = _base * buzz""",
        """			_mat.emission_energy_multiplier = _base * _m * buzz""",
    ),
    (
        """			_mat.emission_energy_multiplier = _base * on""",
        """			_mat.emission_energy_multiplier = _base * _m * on""",
    ),
])

# --- 5. rain: thin streaks, billboarded, visual_apply ----------------------
patch("scripts/rain.gd", [
    (
        """	_rain.scale_amount_min = 0.7
	_rain.scale_amount_max = 1.3""",
        """	_rain.scale_amount_min = 0.6
	_rain.scale_amount_max = 1.1""",
    ),
    (
        """	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.30)""",
        """	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.26)""",
    ),
    (
        """	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.34)""",
        """	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# without this the quads do not face the camera on Mobile and
	# read as raw squares (the pale-block bug)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLE
	var qm := QuadMesh.new()
	qm.size = Vector2(0.008, 0.30)""",
    ),
    (
        """	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.045, 0.045)""",
        """	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLE
	var qm := QuadMesh.new()
	qm.size = Vector2(0.045, 0.045)""",
    ),
    (
        """func _apply_tier(tier: String) -> void:
	if tier == Quality.HIGH:
		_rain.amount = 700
		_splash.emitting = true
	else:
		_rain.amount = 350
		_splash.emitting = false""",
        """func _apply_tier(tier: String) -> void:
	if tier == Quality.HIGH:
		_rain.amount = 700
		_splash.emitting = splash_allowed
	else:
		_rain.amount = 350
		_splash.emitting = false


## The Visual profile drives this (the VISUAL DEBUG panel): rain on
## or off, streak width in metres, splashes on or off.
var rain_on := true
var streak_width := 0.008
var splash_allowed := false


func visual_apply(want_rain: bool, width: float, want_splash: bool) -> void:
	rain_on = want_rain
	splash_allowed = want_splash
	streak_width = width
	_rain.emitting = want_rain
	_rain.visible = want_rain
	if _rain.mesh is QuadMesh:
		(_rain.mesh as QuadMesh).size = Vector2(width, 0.30)
	_apply_tier(Quality.tier)""",
    ),
])

# --- 6. enemy: the dummy is a worn training dummy, not a grey man ----------
patch("scripts/enemy.gd", [
    (
        """	0: [Color(0.55, 0.55, 0.6), 0.0],""",
        """	0: [Color(0.62, 0.50, 0.36), 0.0],  # worn tan: a training dummy reads as gear, not a grey man""",
    ),
    (
        """func _apply_look() -> void:""",
        """## The VISUAL DEBUG panel: silhouette edges on or off.
func set_edge_glow(on: bool) -> void:
	for m in _mats:
		m.emission_energy_multiplier = _edge if on else 0.0


func _apply_look() -> void:""",
    ),
])

# --- 7. opening shot: never strand the game -------------------------------
patch("scripts/opening_shot.gd", [
    (
        """func _ready() -> void:
	add_to_group("opening")
	_camera = get_node("../Camera") as FollowCamera
	_camera.set_frozen(true)
	_end = _camera.global_position""",
        """func _ready() -> void:
	add_to_group("opening")
	# a cinematic must never strand the game: even if the tree is
	# paused underneath us, we keep flying and we always land
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = get_node("../Camera") as FollowCamera
	_camera.set_frozen(true)
	# deferred: the follow camera's _ready places the follow pose;
	# capture it AFTER, or a node-order change strands the camera
	_end = _camera.global_position
	call_deferred("_recapture_end")
	_born_msec = Time.get_ticks_msec()""",
    ),
    (
        """var _end := Vector3.ZERO
var _look_to := Vector3.ZERO""",
        """var _end := Vector3.ZERO
var _look_to := Vector3.ZERO
var _born_msec := 0


func _recapture_end() -> void:
	var pivot: Vector3 = _camera._pivot()
	_end = pivot + Vector3(0.0, _camera.height, _camera.distance)
	_look_to = get_node("../Player").global_position + Vector3.UP * 1.5""",
    ),
    (
        """func _process(delta: float) -> void:
	if _done:
		return
	_t += delta / DURATION""",
        """func _process(delta: float) -> void:
	if _done:
		return
	# the watchdog: whatever stall or pause happens elsewhere, the
	# cinematic lands and hands the game back inside 12 s
	if Time.get_ticks_msec() - _born_msec > 12000:
		_finish()
		return
	_t += delta / DURATION""",
    ),
])

# --- 8. touch buttons: respect the phone safe area -------------------------
patch("scripts/touch_buttons.gd", [
    (
        """		b.position = def.position + Vector2(float(over.get("dx", 0.0)), float(over.get("dy", 0.0)))
		b.size = def.size * float(over.get("scale", 1.0))
		b.modulate = Color(1, 1, 1, opacity * float(over.get("opacity", 1.0)))
	_apply_super_visibility()""",
        """		b.position = def.position + Vector2(float(over.get("dx", 0.0)), float(over.get("dy", 0.0)))
		b.size = def.size * float(over.get("scale", 1.0))
		b.modulate = Color(1, 1, 1, opacity * float(over.get("opacity", 1.0)))
	_clamp_safe_area()
	_apply_super_visibility()


## The phone's notch and home bar eat screen; every button stays
## inside the safe area (the Xogot lesson: controls that sit under
## the corner curve are controls you cannot see).
func _clamp_safe_area() -> void:
	var ft := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = ft * Rect2(DisplayServer.get_display_safe_area())
	safe = safe.intersection(get_viewport().get_visible_rect())
	if safe.size.x < 8.0 or safe.size.y < 8.0:
		return  # headless / degenerate: leave the layout alone
	for name in _buttons:
		var b := _buttons[name] as ActionButton
		var r := b.get_global_rect()
		var tx := clampf(r.position.x, safe.position.x,
				safe.end.x - r.size.x)
		var ty := clampf(r.position.y, safe.position.y,
				safe.end.y - r.size.y)
		if not is_equal_approx(tx, r.position.x) \\
				or not is_equal_approx(ty, r.position.y):
			b.position += Vector2(tx - r.position.x, ty - r.position.y)""",
    ),
])

# --- 9. camera: instant framing for the panel's sliders --------------------
patch("scripts/camera_follow.gd", [
    (
        """## Impact shake: 0.2 jab, 0.35 cross, 0.9 slam.""",
        """## The VISUAL DEBUG panel sets height/distance and wants it NOW.
func snap_framing() -> void:
	_height_now = height
	_dist_now = distance


## Impact shake: 0.2 jab, 0.35 cross, 0.9 slam.""",
    ),
])

# --- 10. debug menu: the VISUAL DEBUG entry --------------------------------
patch("scripts/debug_panel.gd", [
    (
        """	var tests := Button.new()
	tests.text = "TEST RUNNER"
	tests.focus_mode = Control.FOCUS_NONE
	tests.pressed.connect(_toggle_tool.bind("TestRunner"))
	jumps.add_child(tests)""",
        """	var tests := Button.new()
	tests.text = "TEST RUNNER"
	tests.focus_mode = Control.FOCUS_NONE
	tests.pressed.connect(_toggle_tool.bind("TestRunner"))
	jumps.add_child(tests)
	# B15: live visual diagnosis - glow, rain, decals, camera, safe
	# presets, copy-settings, screenshots (the Xogot bug hunt)
	var vis := Button.new()
	vis.text = "VISUAL DEBUG"
	vis.focus_mode = Control.FOCUS_NONE
	vis.pressed.connect(_toggle_tool.bind("VisualPanel"))
	jumps.add_child(vis)""",
    ),
    (
        """		if name == "TuningPanel":
			tool = TuningPanel.new()
			tool.name = "TuningPanel"
		else:""",
        """		if name == "TuningPanel":
			tool = TuningPanel.new()
			tool.name = "TuningPanel"
		elif name == "VisualPanel":
			tool = VisualDebug.new()
			tool.name = "VisualPanel"
		else:""",
    ),
])

print("B15 wire complete")
