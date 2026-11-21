class_name SafeBoot
extends Node
## SafeBoot (B16): the device diagnostic scene, and the TEMPORARY main
## scene. It skips the opening cinematic and every optional system and
## builds the minimum honest game: a lit floor, the REAL hero (the
## actual player.tscn with player.gd), the REAL touch controls (the
## actual touch_buttons.gd + stick_input.gd), a real FollowCamera, and
## one dummy enemy. If THIS scene is broken on the phone, the cause is
## core (autoloads, scene loading, fonts) - not the city.
##
## The big log answers, on device: which build is running, which
## renderer, the autoload census (is Music null? that is the
## fight_score spam root), whether the hero and touch controls exist,
## whether the cinematic ever finishes - with COPY LOG for pasting
## back. Each optional system toggles on ONE AT A TIME so a single
## culprit can be isolated by hand.
##
## The full game stays one tap away: START FULL GAME loads main.tscn.

const SYSTEMS := [
	["cinematic", "CINEMATIC", "the opening shot (hides the HUD, freezes the camera until it lands; a 12 s watchdog force-finishes)"],
	["city", "CITY", "blocks.gd - the three districts, gates, interiors, wanderers"],
	["rain", "RAIN", "rain.gd - the rain layer + splashes"],
	["signs", "SIGNS", "the real sign/window/door material test wall (Label3D + StandardMaterial3D)"],
	["npcs", "NPCS", "cast.gd (the four faces) + trainer.gd"],
	["post", "POST-PROCESS", "the glow stack (ACES, hdr 1.45, 0.5/0.05)"],
	["music", "MUSIC", "the Music bus (unmuted stems)"],
	["fightscore", "FIGHT SCORE", "FightScore processing (the :38 error site)"],
]

var _on := {}          # system id -> bool
var _nodes := {}       # system id -> Node
var _log_box: TextEdit
var _header: Label
var _footer: Label
var _refresh_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the base world - deliberately boring: nothing here can fail but
	# the core engine itself
	_build_world()
	_build_ui()
	_build_diag()
	_log("SafeBoot up - base world built (floor, light, env, hero, camera, dummy, controls)")
	_log("TIP: toggle ONE system at a time; after each, watch the log and the frame")
	_fill_log()


# --- the base world ---------------------------------------------------------


func _build_world() -> void:
	# environment first (group world_env so the Visual profile applies)
	var we := WorldEnvironment.new()
	we.add_to_group("world_env")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.26)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.45
	env.glow_enabled = false  # minimal boot; the POST toggle enables it
	we.environment = env
	add_child(we)

	# the floor: plain, lit, collision
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.2, 80.0)
	col.shape = box
	floor_body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(80.0, 0.2, 80.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.095, 0.11)
	bm.material = mat
	mesh.mesh = bm
	floor_body.add_child(mesh)
	add_child(floor_body)

	# one plain light so the floor and hero are visible
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.9, -1.1, 0.0)
	sun.light_energy = 0.75
	sun.shadow_enabled = false
	add_child(sun)

	# the REAL hero - the actual scene the full game uses
	var hero: Node = load("res://scenes/player.tscn").instantiate()
	hero.name = "Player"
	hero.position = Vector3(0.0, 0.1, 3.0)
	add_child(hero)

	# a real follow camera (sibling of Player, exactly like main.tscn)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 70.0
	cam.script = load("res://scripts/camera_follow.gd")
	add_child(cam)

	# one dummy enemy - the same node the full game spawns at boot
	var dummy: Node = load("res://scenes/enemy.tscn").instantiate()
	dummy.name = "Dummy"
	dummy.kind = 0  # (main.tscn said 'mode' - not a real property; it is 'kind')
	dummy.max_hp = 5
	dummy.position = Vector3(-1.3, 0.02, -4.5)
	add_child(dummy)


func _build_ui() -> void:
	# the REAL touch controls, mounted exactly like main.tscn mounts
	# them: a "UI" CanvasLayer running touch_buttons.gd (group hud)
	# with a full-rect Joystick control running stick_input.gd
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.script = load("res://scripts/touch_buttons.gd")
	ui.add_to_group("hud")
	add_child(ui)
	var stick := Control.new()
	stick.name = "Joystick"
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.script = load("res://scripts/stick_input.gd")
	ui.add_child(stick)


# --- the diagnostic panel ------------------------------------------------------


func _build_diag() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.name = "Diag"
	add_child(layer)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_right = -12.0
	root.offset_top = 8.0
	root.offset_bottom = -8.0
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	root.add_child(_header)

	_log_box = TextEdit.new()
	_log_box.editable = false
	_log_box.custom_minimum_size = Vector2(0, 330)
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_font_size_override("font_size", 13)
	root.add_child(_log_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var copy := Button.new()
	copy.text = "COPY LOG"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(_copy_log)
	actions.add_child(copy)
	var refresh := Button.new()
	refresh.text = "REFRESH LOG"
	refresh.focus_mode = Control.FOCUS_NONE
	refresh.pressed.connect(func(): _fill_log())
	actions.add_child(refresh)
	var full := Button.new()
	full.text = "START FULL GAME"
	full.focus_mode = Control.FOCUS_NONE
	full.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	actions.add_child(full)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 6)
	root.add_child(toggles)
	for sys in SYSTEMS:
		var id: String = sys[0]
		_on[id] = false
		var b := Button.new()
		b.text = sys[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.toggle_mode = true
		b.button_pressed = false
		b.toggled.connect(func(on: bool): _toggle(id, on))
		toggles.add_child(b)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.6, 0.75, 0.7))
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_footer)
	_footer.text = "SafeBoot is the temporary main scene (project.godot run/main_scene). " \
			+ "The full game is START FULL GAME, or switch run/main_scene back to scenes/main.tscn."


# --- the system toggles ---------------------------------------------------------


func _toggle(id: String, on: bool) -> void:
	if _on.get(id, false) == on:
		return
	_on[id] = on
	if not on:
		if _nodes.has(id) and is_instance_valid(_nodes[id]):
			_nodes[id].queue_free()
			_nodes.erase(id)
		_after_off(id)
		_log("SYSTEM OFF: %s" % id.to_upper())
		_fill_log()
		return
	var node := _build_system(id)
	if node:
		_nodes[id] = node
		add_child(node)
	_log("SYSTEM ON: %s" % id.to_upper())
	_fill_log()


func _after_off(id: String) -> void:
	# removing the cinematic must never strand the camera or the input
	if id == "cinematic":
		InputBus.locked = false
		var cam := get_tree().get_first_node_in_group("camera")
		if cam is FollowCamera:
			(cam as FollowCamera).set_frozen(false)
	elif id == "post":
		Visual.post_on = false
		Visual.apply_post()
	elif id == "music":
		var idx := AudioServer.get_bus_index("Music")
		if idx >= 0:
			AudioServer.set_bus_mute(idx, true)
	elif id == "fightscore":
		if FightScore != null:
			FightScore.set_process(false)


func _build_system(id: String) -> Node:
	match id:
		"cinematic":
			var n := Node.new()
			n.name = "OpeningShot"
			n.script = load("res://scripts/opening_shot.gd")
			return n
		"city":
			var c := Node3D.new()
			c.name = "Blocks"
			c.script = load("res://scripts/blocks.gd")
			return c
		"rain":
			var r := Node3D.new()
			r.name = "RainLayer"
			r.script = load("res://scripts/rain.gd")
			return r
		"signs":
			return _build_sign_test()
		"npcs":
			var holder := Node3D.new()
			holder.name = "Npcs"
			var cast := Node3D.new()
			cast.name = "Cast"
			cast.script = load("res://scripts/cast.gd")
			holder.add_child(cast)
			var trainer := Node3D.new()
			trainer.name = "Trainer"
			trainer.position = Vector3(-3.4, 0.02, -6.2)
			trainer.script = load("res://scripts/trainer.gd")
			holder.add_child(trainer)
			return holder
		"post":
			Visual.post_on = true
			Visual.apply_post()
			return null  # no node - it flips the env in place
		"music":
			var idx := AudioServer.get_bus_index("Music")
			if idx >= 0:
				AudioServer.set_bus_mute(idx, false)
			return null
		"fightscore":
			if FightScore != null:
				FightScore.set_process(true)
			return null
	return null


## The sign test wall: the REAL material types the full game uses, so
## the phone can answer "do fonts and materials load on iOS?" in one
## look. If these three signs read as coloured text on dark panels,
## Label3D + the built-in font + StandardMaterial3D are fine on the
## device, and any white signs in the full game are a STALE BUILD.
func _build_sign_test() -> Node3D:
	var g := Node3D.new()
	g.name = "SignTest"
	var fronts := [
		["THE VELVET ROOM", Color(0.85, 0.15, 0.3), Vector3(-7.0, 0, -9.6)],
		["NEON 9", Color(0.15, 0.85, 0.8), Vector3(0.0, 0, -9.6)],
		["PALACE", Color(0.7, 0.4, 0.95), Vector3(7.0, 0, -9.6)],
	]
	for front in fronts:
		var label: String = front[0]
		var color: Color = front[1]
		var pos: Vector3 = front[2]
		# the door-side panel (BoxMesh + StandardMaterial3D, no texture)
		var panel := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(3.0, 3.0, 0.3)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.05, 0.05, 0.08).darkened(0.4)
		pm.material = pmat
		panel.mesh = pm
		panel.position = pos + Vector3(0, 1.5, 0)
		g.add_child(panel)
		# the sign itself: Label3D, built-in font, the B15 outline
		var sign := Label3D.new()
		sign.text = label
		sign.modulate = color
		sign.font_size = 64
		sign.outline_size = 10
		sign.outline_modulate = Color(0.02, 0.02, 0.05)
		sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sign.position = pos + Vector3(0, 3.4, 0.18)
		sign.rotation = Vector3(0, PI, 0)
		g.add_child(sign)
		# one lit window quad (emission 0.85 - under the 1.45 threshold)
		var win := MeshInstance3D.new()
		var wm := QuadMesh.new()
		wm.size = Vector2(0.9, 1.2)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(1.0, 0.82, 0.45)
		wmat.emission_enabled = true
		wmat.emission = Color(1.0, 0.7, 0.3)
		wmat.emission_energy_multiplier = 0.85
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.material = wmat
		win.mesh = wm
		win.position = pos + Vector3(0.8, 1.6, 0.16)
		win.rotation = Vector3(0, PI, 0)
		g.add_child(win)
	_log("sign test: Label3D (Godot built-in font, NO external texture) + " \
			+ "StandardMaterial3D (window emission 0.85, under the 1.45 glow threshold)")
	return g


# --- the log --------------------------------------------------------------------


## The declared autoload names, straight from project.godot (4.7 has
## no get_autoload_list(); the property list carries them).
func _declared_autoloads() -> Array[String]:
	var names: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var key: String = prop.get("name", "")
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	return names


func _log(text: String) -> void:
	print("[SafeBoot] ", text)


func _fill_log() -> void:
	if _log_box == null:
		return
	_log_box.text = _build_log()


func _copy_log() -> void:
	var text := _build_log()
	_log_box.text = text
	DisplayServer.clipboard_set(text)
	_log("log copied to clipboard (%d chars) - paste it back to the agent" % text.length())


func _autoload_census() -> Array[String]:
	# THE phone diagnostic: every autoload, is its singleton actually
	# alive? A null here (Music was, on the device) is the root cause
	# of the fight_score.gd:38 spam and everything it breaks downstream.
	var out: Array[String] = []
	var alive := 0
	var dead := 0
	for name in _declared_autoloads():
		var node := get_node_or_null("/root/" + name)
		if node == null:
			dead += 1
			out.append("  %s: NULL  <-- SINGLETON FAILED TO REGISTER" % name)
		else:
			alive += 1
			out.append("  %s: ok (%s)" % [name, node.get_class()])
	out.append("  autoloads alive: %d/%d" % [alive, alive + dead])
	return out


func _build_log() -> String:
	var L: Array[String] = []
	L.append("== LEVERAGE SAFEBOOT LOG ==")
	L.append(BuildStamp.block())
	L.append("renderer: %s / %s" % [
			ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			RenderingServer.get_video_adapter_name()])
	L.append("window: %s   orientation: %s" % [
			get_window().size, DisplayServer.screen_get_orientation()])
	L.append("safe area: %s" % DisplayServer.get_display_safe_area())
	L.append("fps: %d   draw calls: %d" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	L.append("")
	L.append("-- AUTOLOAD CENSUS (any NULL = that system is dead on this device)")
	L.append_array(_autoload_census())
	L.append("")
	var hero := get_tree().get_first_node_in_group("player")
	L.append("hero: %s  at %s" % [
			"EXISTS (%s)" % hero.name if hero else "MISSING <-- the no-hero bug",
			str(hero.global_position) if hero else "-"])
	var cam := get_tree().get_first_node_in_group("camera")
	L.append("camera: %s" % ("EXISTS" if cam else "MISSING"))
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is ActionButton and (c as ActionButton).visible:
				buttons += 1
	L.append("touch controls: %s (%d action buttons visible, safe-area clamped)"
			% ["LOADED" if buttons > 0 else "MISSING <-- the no-controls bug", buttons])
	L.append("cinematic ever finished: %s (watchdog force-finishes at 12 s)"
			% str(OpeningShot.ever_finished))
	L.append("InputBus.locked: %s" % str(InputBus.locked))
	L.append("Music singleton: %s   state: %s" % [
			"ok" if Music != null else "NULL <-- fight_score.gd:38 spam",
			str((Music.state if Music != null else -1))])
	L.append("FightScore singleton: %s" % ("ok" if FightScore != null else "NULL"))
	L.append("")
	L.append("-- THE DUMMY (the grey-figure question)")
	var dummy := get_node_or_null("Dummy")
	if dummy:
		L.append("node 'Dummy' (enemy.tscn, kind 0 training dummy) at %s" % dummy.position)
		L.append("  tint: worn TAN Color(0.62, 0.50, 0.36) since B15;")
		L.append("  it was GREY Color(0.55, 0.55, 0.6) up to B14 - if you")
		L.append("  see a grey man in the FULL game, the phone is on a stale build.")
	else:
		L.append("Dummy node MISSING (enemy.tscn failed to load?)")
	L.append("")
	L.append("-- SYSTEM TOGGLES (one at a time; base scene is all-off)")
	for sys in SYSTEMS:
		L.append("  %s: %s - %s" % [sys[1],
				"ON" if _on.get(sys[0], false) else "off", sys[2]])
	L.append("")
	L.append("-- SIGN MATERIAL FACTS (the white-signs question)")
	L.append("  signs are Label3D nodes: Godot's BUILT-IN font, no external")
	L.append("  texture or font file. Doors/panels are BoxMesh + StandardMaterial3D.")
	L.append("  windows emit at 0.85 (under the 1.45 glow threshold since B15).")
	L.append("  White flat signs on this device = a stale pre-B15 build")
	L.append("  (glow threshold was 1.05, windows 1.4) - the build stamp above")
	L.append("  settles it; also press SIGNS for the live material test wall.")
	L.append("")
	L.append("== END OF LOG (COPY LOG puts all of this on the clipboard) ==")
	return "\n".join(L)


func _process(delta: float) -> void:
	if _header == null:
		return
	_refresh_t += delta
	if _refresh_t < 0.5:
		return
	_refresh_t = 0.0
	_header.text = "%s   |   fps %d   draw %d   |   hero %s   buttons %s" % [
			BuildStamp.line(), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"ok" if get_tree().get_first_node_in_group("player") else "MISSING",
			"ok" if get_tree().get_first_node_in_group("hud") else "MISSING"]
