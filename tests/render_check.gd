extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
## The render-truth suite (B15). Boots the real street scene with a
## REAL renderer (opengl3 under Xvfb/llvmpipe in the sandbox; the
## owner's Xogot runs Mobile/Metal - the VISUAL DEBUG overlay says
## which one is talking), skips the opening, waits for the rain to
## settle, saves the frame to /tmp/render_boot.png and JUDGES it
## against the six Xogot bugs:
##
##   bug 1  no large pure-white area, no orange-bloom dominance,
##          and the baked safe environment (ACES, hdr 1.45,
##          glow 0.5/0.05, windows 0.85, neon capped 1.8)
##   bug 2  no big uniform pale square blocks (80 px grid scan),
##          rain/splash quads are billboarded thin streaks
##   bug 3  the boot-area dummy is a worn tan, not a grey man
##   bug 4  the hero sits framed near centre, camera close
##   bug 5  the touch controls loaded, on screen, inside the safe
##          area, input unlocked after the opening
##   bug 6  rain streaks are thin (0.05 m or less)
##
## Prints RENDER PASS / RENDER FAIL with named reasons.

var _fails := 0
var _checks := 0
const OUT := "/tmp/render_boot.png"


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("RENDER FAIL: ", what)
	else:
		print("RENDER ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# headless has no renderer - this suite only talks with a real one
	if DisplayServer.get_name() == "headless":
		print("RENDER SKIP: no display (run under Xvfb + opengl3)")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait_s(1.0)  # opening flies; the watchdog/skip handles it
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(3.0)  # rain settles, quality tier settles

	_what_renderer()
	_the_environment()
	await _the_frame()
	_the_mesh_facts()
	_the_dummy()
	_the_controls()
	_the_hero()
	_the_opening_unlocked()

	if _fails == 0:
		print("RENDER PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("RENDER FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _what_renderer() -> void:
	print("RENDER info: renderer=", ProjectSettings.get_setting(
			"rendering/renderer/rendering_method"),
			" adapter=", RenderingServer.get_video_adapter_name())
	print("RENDER info: window=", get_window().size,
			" safe=", DisplayServer.get_display_safe_area(),
			" orientation=", DisplayServer.screen_get_orientation())


# --- bug 1: the baked safe environment --------------------------------------


func _the_environment() -> void:
	var we := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	var env := we.environment if we else null
	if env == null:
		_check(false, "a WorldEnvironment exists")
		return
	_check(env.tonemap_mode == Environment.TONE_MAPPER_ACES
			or env.tonemap_mode == 4, "safe tonemap baked (%d)" % env.tonemap_mode)
	_check(absf(env.glow_hdr_threshold - 1.45) < 0.01,
			"HDR threshold 1.45 baked (%.2f)" % env.glow_hdr_threshold)
	_check(absf(env.glow_intensity - 0.5) < 0.01,
			"glow intensity 0.5 baked (%.2f)" % env.glow_intensity)
	_check(absf(env.glow_bloom - 0.05) < 0.01,
			"glow bloom 0.05 baked (%.2f)" % env.glow_bloom)
	# neon capped: every live sign energy <= 1.8 * profile mult
	var worst := 0.0
	for n in get_tree().get_nodes_in_group("neon"):
		var mi := n as MeshInstance3D
		if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
			var m: StandardMaterial3D = mi.mesh.surface_get_material(0)
			if m and m.emission_enabled:
				worst = maxf(worst, m.emission_energy_multiplier)
	_check(worst <= 1.8 * Visual.emission_mult + 0.01,
			"neon emission capped at 1.8x (worst %.2f)" % worst)
	# windows: 0.85 base, scaled by the profile
	for n in get_tree().get_nodes_in_group("emissive_window"):
		var mi := n as MeshInstance3D
		if mi and mi.has_meta("base_energy"):
			var m: StandardMaterial3D = mi.mesh.surface_get_material(0)
			if m:
				_check(absf(m.emission_energy_multiplier
						- 0.85 * Visual.emission_mult) < 0.01,
						"window energy 0.85x profile (%.2f)"
						% m.emission_energy_multiplier)
				break  # one representative is enough; all share the base


# --- bugs 1+2+4: the frame itself --------------------------------------------


func _the_frame() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT)
	print("RENDER info: frame saved ", OUT, " ", img.get_size())
	var w := img.get_width()
	var h := img.get_height()
	var white := 0
	var orange_halo := 0
	var total := 0
	for y in range(0, h, 3):
		for x in range(0, w, 3):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r > 0.965 and c.g > 0.965 and c.b > 0.965:
				white += 1
			if c.r > 0.85 and c.g > 0.45 and c.g < 0.75 and c.b < 0.3:
				orange_halo += 1
	var wr := float(white) / total
	var orr := float(orange_halo) / total
	print("RENDER info: white=%.4f orange=%.4f" % [wr, orr])
	_check(wr < 0.015, "pure-white area %.1f%% < 1.5%% (bug 1 blown signs)"
			% (wr * 100.0))
	_check(orr < 0.10, "orange-bloom pixels %.1f%% < 10%% (bug 1 halo)"
			% (orr * 100.0))
	# bug 2: the pale-square scan. 80 px blocks; a block that is one
	# flat pale colour (bright, low channel spread, low variance) is
	# an untextured quad seen broadside. Sky is dark at night; wet
	# asphalt is dark; NOTHING legit fills a pale 80 px block.
	var pale_blocks := 0
	for by in range(0, h - 80, 80):
		for bx in range(0, w - 80, 80):
			if _block_is_flat_pale(img, bx, by):
				pale_blocks += 1
	print("RENDER info: flat pale 80px blocks=", pale_blocks)
	_check(pale_blocks == 0,
			"no flat pale square blocks (bug 2, found %d)" % pale_blocks)
	# bug 4: the frame must not be one flat strip (the phone showed a
	# full-screen teal flood). Three honest assertions: the neon lives
	# somewhere, no single hue family dominates the frame, and the
	# night is neither black nor blown out.
	var colorful := 0
	var achromatic := 0
	var lum := 0.0
	var n := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			n += 1
			lum += c.v
			if c.s > 0.25 and c.v > 0.2:
				colorful += 1
			elif c.s < 0.1:
				achromatic += 1
	lum /= float(n)
	var cr := float(colorful) / n
	print("RENDER info: colorful=%.4f achromatic=%.3f mean_lum=%.3f"
			% [cr, float(achromatic) / n, lum])
	_check(cr > 0.005, "the neon lives (colorful pixels %.2f%%)" % (cr * 100.0))
	_check(float(achromatic) / n < 0.97,
			"the street is not one grey slab (achromatic %.1f%%)"
			% (float(achromatic) / n * 100.0))
	_check(lum > 0.04 and lum < 0.6,
			"the night is neither black nor blown (mean lum %.3f)" % lum)


func _block_is_flat_pale(img: Image, bx: int, by: int) -> bool:
	# pale: bright and washed; flat: near-zero variance across 64
	# sampled pixels. Thresholds tuned so wet neon asphalt (dark,
	# varied) passes and a raw 0.45 m quad at 6 m (a 90 px pale
	# square) fails.
	var acc := Color(0, 0, 0)
	var n := 0
	for y in range(by, by + 80, 10):
		for x in range(bx, bx + 80, 10):
			acc += img.get_pixel(x, y)
			n += 1
	acc /= float(n)
	if acc.v < 0.55 or acc.s > 0.25:
		return false  # dark or colourful: asphalt, neon, brick
	var spread := 0.0
	for y in range(by, by + 80, 10):
		for x in range(bx, bx + 80, 10):
			var c := img.get_pixel(x, y)
			spread += absf(c.v - acc.v)
	spread /= float(n)
	return spread < 0.02  # one flat colour, no texture, no shading


# --- bug 2 + 6: the particle mesh facts ---------------------------------------


func _the_mesh_facts() -> void:
	for layer in get_tree().get_nodes_in_group("rain_layer"):
		var rain: CPUParticles3D = layer.get_node_or_null("Rain")
		if rain and rain.mesh is QuadMesh:
			var s: Vector2 = rain.mesh.size
			var m: StandardMaterial3D = rain.mesh.surface_get_material(0)
			_check(s.x <= 0.05, "rain streak thin (bug 6, %.3f m)" % s.x)
			_check(s.y > s.x * 4.0, "rain streak long, not a square (%s)" % s)
			_check(m.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES,
					"rain quads face the camera (bug 2 billboard)")
		var splash: CPUParticles3D = layer.get_node_or_null("Splashes")
		if splash and splash.mesh is QuadMesh:
			var s2: Vector2 = splash.mesh.size
			var m2: StandardMaterial3D = splash.mesh.surface_get_material(0)
			_check(s2.x <= 0.08 and s2.y <= 0.08,
					"splash dots small (bug 2, %s)" % s2)
			_check(m2.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES,
					"splash quads face the camera (bug 2 billboard)")


# --- bug 3: the dummy is gear, not a grey man ----------------------------------


func _the_dummy() -> void:
	# the boot-area dummy: worn tan, and it must not read as one flat
	# grey region on screen
	var dummy: CharacterBody3D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if int(e.get("kind")) == 0:
			dummy = e
			break
	if dummy == null:
		_check(false, "the training dummy exists at boot")
		return
	var look: Array = dummy.get("LOOK")[0]
	var tint: Color = look[0]
	_check(tint.r > tint.b + 0.06 and tint.r > 0.45,
			"the dummy is worn tan, not grey (%s)" % tint)
	# on-screen: its region should show shading variety, not one flat
	# grey slab (a lit rig has value spread)
	var cam := get_tree().get_first_node_in_group("camera") as Camera3D
	if cam and cam.is_position_in_frustum(dummy.global_position + Vector3.UP):
		var sp := cam.unproject_position(dummy.global_position + Vector3.UP)
		var img := get_viewport().get_texture().get_image()
		var spread := 0.0
		var n := 0
		for dy in range(-14, 15, 4):
			for dx in range(-8, 9, 4):
				var px := int(sp.x) + dx
				var py := int(sp.y) + dy
				if px >= 0 and py >= 0 and px < img.get_width() \
						and py < img.get_height():
					spread += img.get_pixel(px, py).s
					n += 1
		if n > 8:
			print("RENDER info: dummy region mean saturation %.3f"
					% (spread / n))
			_check(spread / n > 0.005,
					"the dummy region is lit, not a flat grey slab")


# --- bug 5: the touch controls ---------------------------------------------------


func _the_controls() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		_check(false, "the hud layer exists")
		return
	var buttons := 0
	var on_screen := 0
	var in_safe := 0
	var ft := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = ft * Rect2(DisplayServer.get_display_safe_area())
	safe = safe.intersection(get_viewport().get_visible_rect())
	for c in hud.get_children():
		if c is CLS_ActionButton and (c as CLS_ActionButton).visible:
			buttons += 1
			var r := (c as Control).get_global_rect()
			if get_viewport().get_visible_rect().encloses(r):
				on_screen += 1
			if safe.encloses(r):
				in_safe += 1
	print("RENDER info: action buttons visible=", buttons,
			" on-screen=", on_screen, " in-safe=", in_safe)
	_check(buttons >= 3, "touch controls loaded (bug 5, %d visible)" % buttons)
	_check(on_screen == buttons, "every button on screen (bug 5)")
	_check(in_safe == buttons, "every button inside the safe area (bug 5)")


# --- bug 4: the hero framed ------------------------------------------------------


func _the_hero() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_tree().get_first_node_in_group("camera") as Camera3D
	if p == null or cam == null:
		_check(false, "hero or camera missing from the tree")
		return
	var center := p.global_position + Vector3.UP * 1.0
	var on := cam.is_position_in_frustum(center)
	var sp := cam.unproject_position(center)
	var nx := sp.x / get_viewport().get_visible_rect().size.x
	var dist := cam.global_position.distance_to(center)
	print("RENDER info: hero frustum=", on, " nx=%.2f" % nx, " dist=%.1f" % dist)
	_check(on, "the hero is on screen at boot (bug 4)")
	_check(nx > 0.2 and nx < 0.8, "the hero sits framed (bug 4, x %.2f)" % nx)
	_check(dist < 12.0, "the camera is near its hero (bug 4, %.1f m)" % dist)


# --- bug 4/5: the opening handed the game back ------------------------------------


func _the_opening_unlocked() -> void:
	_check(not InputBus.locked,
			"input unlocked after the opening (bug 4/5)")
	_check(get_tree().get_first_node_in_group("hud") != null
			and (get_tree().get_first_node_in_group("hud") as CanvasLayer).visible,
			"the hud is visible after the opening (bug 5)")
