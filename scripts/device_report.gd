extends RefCounted

## LEVERAGE B18 (Part 6): the DEVICE REPORT. One selectable, copyable
## text block with every fact the phone can tell us: build stamp,
## renderer + API + adapter, window/safe area/FPS/draw calls, hdr_2d and
## the whole environment state, hero + camera + cinematic truth, the
## touch controls and their rectangles, the radar + route + waypoint,
## the autoload census, the materials of the named suspects (the big
## sign, the safehouse door, the grey figure), and the last 10 errors
## or warnings. Built entirely from live scene introspection, guarded
## so it never crashes: it runs from the debug menu, from SafeBoot, and
## inside the test suites.
##
## Static functions only; autoloads are reached through the scene tree
## (static context cannot rely on the global names).

const TONEMAPS := ["LINEAR", "REINHARD", "FILMIC", "ACES", "AGX"]


static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree else null


static func _node(path: String) -> Node:
	var r := _root()
	return r.get_node_or_null(path) if r else null


# --- the report ----------------------------------------------------------------


static func build() -> String:
	var L: Array[String] = []
	L.append("== LEVERAGE DEVICE REPORT ==")
	L.append(_identity())
	L.append(_render_block())
	L.append(_env_block())
	L.append(_hero_block())
	L.append(_cinematic_block())
	L.append(_touch_block())
	L.append(_radar_block())
	L.append(_census_block())
	L.append(_suspects_block())
	L.append(_errors_block())
	L.append("== END OF DEVICE REPORT ==")
	return "\n".join(L)


static func _identity() -> String:
	var stamp := "?"
	var bs := _node("/root/BuildStamp")
	if bs and bs.has_method("block"):
		stamp = str(bs.call("block"))
	var ver: Dictionary = Engine.get_version_info()
	return "BUILD: %s\nGodot: %s | device: %s" % [stamp,
			str(ver.get("string", "?")), OS.get_name()]


static func _render_block() -> String:
	var method := str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "?"))
	var api := "?"
	for key in ["rendering/rendering_device/driver",
			"rendering/driver/rendering_driver"]:
		if ProjectSettings.has_setting(key):
			api = str(ProjectSettings.get_setting(key))
			break
	var adapter := RenderingServer.get_video_adapter_name()
	var window := Vector2i.ZERO
	var vis := Rect2()
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		window = tree.root.size
		vis = tree.root.get_visible_rect()
	var safe := Rect2i()
	var orient := 0
	if DisplayServer.get_name() != "headless":
		safe = DisplayServer.get_display_safe_area()
		orient = DisplayServer.screen_get_orientation()
	var fps := Engine.get_frames_per_second()
	var draws := Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return "-- RENDER --\nrenderer: %s | API: %s | adapter: %s\nwindow: %s | visible rect: %s\norientation: %d | safe area: %s\nfps: %d | draw calls: %d" \
			% [method, api, adapter, str(window), str(vis), orient,
			str(safe), fps, draws]


static func _env_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var env: Environment = null
	if tree:
		for n in tree.get_nodes_in_group("world_env"):
			if n is WorldEnvironment and (n as WorldEnvironment).environment:
				env = (n as WorldEnvironment).environment
				break
	if env == null:
		return "-- ENV --\nno WorldEnvironment in the tree"
	var tm: String = "TONEMAPS[%d]" % env.tonemap_mode \
			if env.tonemap_mode >= TONEMAPS.size() \
			else TONEMAPS[env.tonemap_mode]
	var hdr_2d := str(ProjectSettings.get_setting(
			"rendering/viewport/hdr_2d", false))
	return "-- ENV --\nhdr_2d: %s | tonemap: %s (%d) | white: %.2f | exposure: %.2f\nambient: %s x %.2f | glow: %s (threshold %.2f, intensity %.2f, bloom %.2f)" \
			% [hdr_2d, tm, env.tonemap_mode, env.tonemap_white,
			env.tonemap_exposure, str(env.ambient_light_color),
			env.ambient_light_energy, "on" if env.glow_enabled else "off",
			env.glow_hdr_threshold, env.glow_intensity, env.glow_bloom]


static func _hero_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var hero: Node3D = null
	var cam: Camera3D = null
	if tree:
		for n in tree.get_nodes_in_group("player"):
			hero = n as Node3D
			break
		for n in tree.get_nodes_in_group("camera"):
			cam = n as Camera3D
			break
	var out := "-- HERO --\nhero exists: %s" % ("yes" if hero else "NO")
	if hero:
		out += " | pos %s | visible %s" % [str(hero.global_position.round()),
				"yes" if hero.is_visible_in_tree() else "NO"]
	out += "\ncamera exists: %s" % ("yes" if cam else "NO")
	if cam:
		var tp := str(cam.get("target_path")) if cam.get_script() else "?"
		out += " | pos %s | current %s | target path %s" % [
				str(cam.global_position.round()),
				"yes" if cam.is_current() else "no", tp]
	return out


static func _cinematic_block() -> String:
	const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
	var tree := Engine.get_main_loop() as SceneTree
	var live := false
	if tree:
		live = tree.get_first_node_in_group("opening") != null
	# the node frees itself when it lands - the truth lives in the
	# script's statics, read from the preload (never a tree lookup)
	var boot_s: float = float(Time.get_ticks_msec()) / 1000.0
	return "-- CINEMATIC --\nopening node live: %s | ever finished: %s | forced-end fired: %s | time since boot: %.1f s" \
			% ["yes" if live else "no",
			"yes" if CLS_OpeningShot.ever_finished else "no",
			"yes" if CLS_OpeningShot.forced_end else "no", boot_s]


static func _touch_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var out := "-- TOUCH --\n"
	if tree == null:
		return out + "no scene tree"
	var hud := tree.get_first_node_in_group("hud_buttons")
	var count := 0
	if hud:
		for c in hud.get_children():
			if c.has_signal("down") and c.is_visible_in_tree():
				count += 1
				var r: Rect2 = (c as Control).get_global_rect()
				var child_labels := 0
				for cc in c.get_children():
					if cc is Label:
						child_labels += 1
				out += "%s: rect (%d, %d, %d x %d) labels: 1 self-drawn + %d child\n" \
						% [c.name, int(r.position.x), int(r.position.y),
						int(r.size.x), int(r.size.y), child_labels]
	out += "buttons visible: %d\n" % count
	var stick := tree.get_first_node_in_group("stick")
	if stick:
		var settings := _node("/root/Settings")
		var scheme := "?"
		if settings:
			scheme = str(settings.call("value", "scheme"))
		out += "joystick: exists, scheme %s, active %s" % [scheme,
				str(bool(stick.get("_active")))]
	else:
		out += "joystick: NOT FOUND"
	return out


static func _radar_block() -> String:
	const CLS_MapData := preload("res://scripts/map_data.gd")
	const CLS_FullMap := preload("res://scripts/full_map.gd")
	var tree := Engine.get_main_loop() as SceneTree
	var radar: Control = null
	if tree:
		for n in tree.get_nodes_in_group("radar"):
			radar = n as Control
			break
	var out := "-- RADAR --\nradar exists: %s" % ("yes" if radar else "NO")
	if radar:
		var r: Rect2 = radar.get_global_rect()
		out += " | visible %s | rect (%d, %d, %d x %d) | %s" % [
				"yes" if radar.is_visible_in_tree() else "no",
				int(r.position.x), int(r.position.y), int(r.size.x),
				int(r.size.y),
				"rotating" if bool(radar.get("rotating")) else "north-up"]
		out += " | blips drawn: %d | scale %.2f px/m" % [
				int(radar.get("blips_drawn")), float(radar.get("last_scale"))]
	var nav: Dictionary = CLS_MapData.nav_target()
	if tree and not nav.is_empty():
		var hero := tree.get_first_node_in_group("player") as Node3D
		var dist := -1.0
		if hero:
			dist = (nav["pos"] as Vector2).distance_to(Vector2(
					hero.global_position.x, hero.global_position.z))
		var route := _radar_route()
		out += "\nobjective: %s (%d m) | route: %s (%d nodes, %.0f m)" % [
				str(nav.get("text", "")), int(dist),
				"yes" if route.size() >= 2 else "no", route.size(),
				CLS_MapData.route_length(route)]
	else:
		out += "\nobjective: none"
	out += " | waypoint: %s" % (str(CLS_MapData.waypoint()) \
			if CLS_MapData.has_waypoint() else "none")
	out += "\nmap opened from: radar %d / pause %d / phone %d" % [
			CLS_FullMap.opened_radar, CLS_FullMap.opened_pause,
			CLS_FullMap.opened_phone]
	return out


static func _radar_route() -> PackedVector2Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return PackedVector2Array()
	var radar := tree.get_first_node_in_group("radar")
	if radar == null:
		return PackedVector2Array()
	return radar.get("_route") as PackedVector2Array


static func _census_block() -> String:
	var root := _root()
	if root == null:
		return "-- AUTOLOADS --\nno tree"
	var names: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var key := str(prop.get("name", ""))
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	var alive := 0
	var dead: Array[String] = []
	for n in names:
		var node := root.get_node_or_null("/root/" + n)
		if node == null:
			dead.append(n)
		else:
			alive += 1
	var out := "-- AUTOLOADS --\nalive: %d/%d" % [alive, names.size()]
	if not dead.is_empty():
		out += " | DEAD: " + ", ".join(dead)
	return out


static func _suspects_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "-- SUSPECTS --\nno tree"
	var out := "-- SUSPECTS --\n"
	# the big white sign: the amber neon slab over the shop
	for n in tree.get_nodes_in_group("neon"):
		if "SignAmber" in n.name:
			out += "big sign: %s | %s\n" % [str(n.get_path()),
					_mat_facts(n as MeshInstance3D)]
			break
	# the door: the safehouse door on the north face (not the interior)
	for n in tree.get_nodes_in_group("safehouse"):
		var pos: Vector3 = (n as Node3D).global_position if n is Node3D \
				else Vector3.INF
		if pos != Vector3.INF and absf(pos.x) < 100.0:
			for c in n.get_children():
				if c is MeshInstance3D:
					out += "door: %s | %s\n" % [str(c.get_path()),
							_mat_facts(c as MeshInstance3D)]
			break
	# the grey figure: the training dummy's mannequin + the hero's body
	for e in tree.get_nodes_in_group("enemy"):
		if int(e.get("kind")) == 0:
			var mann := (e as Node).get_node_or_null("Body/Mannequin")
			if mann:
				out += "grey figure (dummy mannequin): %s | %s\n" % [
						str(mann.get_path()), _glb_facts(mann as Node3D)]
			break
	var hero := tree.get_first_node_in_group("player")
	if hero:
		var body := hero.get_node_or_null("Body/Hero/Body")
		if body:
			out += "hero body (UBC gltf): %s | %s" % [
					str(body.get_path()), _glb_facts(body as Node3D)]
	return out


static func _mat_facts(mi: MeshInstance3D) -> String:
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return "no mesh/surfaces"
	var m: Material = mi.mesh.surface_get_material(0)
	if m == null:
		return "material: NONE (engine default grey!)"
	var out := "material: %s" % m.get_class()
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		if sm.emission_enabled:
			out += " emission %s energy %.2f" % [str(sm.emission),
					sm.emission_energy_multiplier]
		else:
			out += " no emission | albedo %s" % str(sm.albedo_color)
	return out


static func _glb_facts(n: Node3D) -> String:
	# how many mesh surfaces, and is the first one textured? (the
	# grey-figure diagnosis: surfaces with no texture = the pale squares)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(n, meshes)
	if meshes.is_empty():
		return "no meshes found underneath"
	var first := meshes[0]
	if first.mesh == null or first.mesh.get_surface_count() == 0:
		return "%d meshes, first has no surface" % meshes.size()
	var m: Material = first.mesh.surface_get_material(0)
	var over: Material = first.material_override
	var tex := "no material"
	if over is StandardMaterial3D:
		tex = "override albedo %s tex %s" % [str((over as StandardMaterial3D).albedo_color),
				"yes" if (over as StandardMaterial3D).albedo_texture else "NO"]
	elif m is StandardMaterial3D:
		tex = "surface albedo %s tex %s" % [str((m as StandardMaterial3D).albedo_color),
				"yes" if (m as StandardMaterial3D).albedo_texture else "NO"]
	return "%d meshes | first: %s | %s" % [meshes.size(), first.name, tex]


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if out.size() >= 3:
		return
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


static func _errors_block() -> String:
	var lg := _node("/root/Log")
	var out := "-- LAST ERRORS/WARNINGS --\n"
	if lg == null or not lg.has_method("recent"):
		return out + "Log autoload missing"
	var recent: Array = lg.call("recent")
	var hits: Array[String] = []
	for line in recent:
		var s := str(line)
		if s.begins_with("ERROR") or s.begins_with("WARN"):
			hits.append(s)
	if hits.is_empty():
		return out + "none"
	var from := maxi(0, hits.size() - 10)
	for i in range(from, hits.size()):
		out += hits[i] + "\n"
	return out.substr(0, out.length() - 1)


# --- the popup (debug menu + SafeBoot share this) ------------------------------


## A selectable-text popup with a COPY LOG button, in the visual-debug
## house style. Adds itself to `parent` (the scene root) and sits on
## top (layer 32).
static func show_popup(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 32
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var box := PanelContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -440.0
	box.offset_right = 440.0
	box.offset_top = -280.0
	box.offset_bottom = 280.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.96)
	sb.border_color = Color(0.2, 0.75, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", sb)
	layer.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	var hint := Label.new()
	hint.text = "Select all, copy, paste it back to the agent:"
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)
	var te := TextEdit.new()
	te.editable = false
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(860, 460)
	te.add_theme_font_size_override("font_size", 13)
	te.text = build()
	col.add_child(te)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var copy := Button.new()
	copy.text = "COPY LOG"
	copy.focus_mode = Control.FOCUS_NONE
	copy.custom_minimum_size = Vector2(180, 48)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(build())
		copy.text = "COPIED")
	row.add_child(copy)
	var close := Button.new()
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(120, 48)
	close.pressed.connect(func(): layer.queue_free())
	row.add_child(close)
