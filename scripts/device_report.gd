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
	L.append(_audio_block())
	L.append(_characters_block())
	L.append(_ambient_block())
	L.append(_env_block())
	L.append(_hero_block())
	L.append(_cinematic_block())
	L.append(_touch_block())
	L.append(_radar_block())
	L.append(_guide_block())
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


## B18.3 (BUG 10, Part 3B): the CHARACTER AND VEHICLE CENSUS. Every
## hero, enemy, street NPC, trainer and vehicle, with the facts that
## decide whether it can be SEEN: exists, visible, distance to the
## camera, frustum, mesh + skeleton counts, the first material and its
## albedo, the animation playing, an approximate on-screen pixel area,
## and whether the lit fallback figure took over. Pixel areas are
## ESTIMATES from the camera projection (the true raster count needs a
## GPU readback).
static func _characters_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var out := "-- CHARACTERS + VEHICLES --\n"
	if tree == null:
		return out + "no scene tree"
	var cam := tree.get_first_node_in_group("camera") as Camera3D
	var rows: Array[String] = []
	var groups := [["player", "HERO"], ["enemy", "ENEMY"],
			["cast", "NPC"], ["trainer", "TRAINER"]]
	for g in groups:
		for n in tree.get_nodes_in_group(g[0]):
			rows.append(_census_row(n, g[1], cam))
	# vehicles: the parked car (slam_surface == "car"; crates and bins
	# share the takedown meta but are not vehicles)
	var seen := {}
	for n in tree.root.find_children("*", "StaticBody3D", true, false):
		if str(n.get_meta("slam_surface", "")) == "car" and not seen.has(n):
			seen[n] = true
			rows.append(_census_row(n, "VEHICLE", cam))
	if rows.is_empty():
		return out + "nothing alive found"
	for r in rows:
		out += r + "\n"
	var dark := 0
	for n in tree.get_nodes_in_group("enemy"):
		if n is Node3D and bool(n.get("fallback_figure")):
			dark += 1
	out += "lit fallback figures in use: %d" % dark
	return out


static func _census_row(n: Node, role: String, cam: Camera3D) -> String:
	var n3 := n as Node3D
	var vis: bool = n3.is_visible_in_tree()
	var pos := n3.global_position
	var dist := -1.0
	var in_frustum := false
	var px := -1
	if cam:
		dist = cam.global_position.distance_to(pos)
		if not cam.is_position_behind(pos):
			var sp := cam.unproject_position(pos)
			var vr := cam.get_viewport().get_visible_rect()
			in_frustum = vr.has_point(sp)
			# approximate: a 0.9 m wide figure at this distance + fov
			var w := 0.9 / maxf(dist, 0.5) * vr.size.y
			px = int(w * w)
	var meshes := 0
	var skel := false
	var mat_kind := "none"
	var albedo := "-"
	for c in n3.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var mi := c as MeshInstance3D
		if mi.get_node_or_null("../Skeleton3D") != null or mi.find_children("Skeleton3D", "", true, false).size() > 0:
			skel = true
		if mi.mesh != null and mi.mesh.get_surface_count() > 0 and mat_kind == "none":
			var m := mi.mesh.surface_get_material(0)
			mat_kind = str(m.get_class()) if m != null else "null"
			if m is StandardMaterial3D:
				var a: Color = (m as StandardMaterial3D).albedo_color
				albedo = "(%.2f, %.2f, %.2f)" % [a.r, a.g, a.b]
	var anim := "-"
	for c in n3.find_children("*", "AnimationPlayer", true, false):
		if (c as AnimationPlayer).current_animation != "":
			anim = str((c as AnimationPlayer).current_animation)
			break
	var fb := ""
	if n.get("fallback_figure") != null and bool(n.get("fallback_figure")):
		fb = " [LIT FALLBACK]"
	return "%s %s | vis %s | %d m | frustum %s | ~%d px | meshes %d | skel %s | %s %s%s" % [
			role, str(n.name), str(vis), int(dist), str(in_frustum), px,
			meshes, str(skel), mat_kind, albedo, fb]


## B18.3 (BUG 15, Part 6): the ambient-life facts.
static func _ambient_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var out := "-- AMBIENT LIFE --\n"
	if tree == null:
		return out + "no scene tree"
	var al := tree.get_first_node_in_group("ambient_life")
	if al == null:
		return out + "ambient life node NOT FOUND"
	var insects := int(al.call("insect_count"))
	var creatures := int(al.call("creature_count"))
	var swarm: Vector3 = al.call("nearest_lit_swarm")
	var near := "n/a"
	if swarm != Vector3.INF:
		var hero := tree.get_first_node_in_group("player") as Node3D
		if hero:
			near = "%d m" % int(hero.global_position.distance_to(swarm))
	out += "insects: %d (cap %d) | creatures: %d (cap %d) | nearest lit swarm: %s" % [
			insects, int(al.call("insect_cap")), creatures,
			int(al.call("creature_cap")), near]
	return out


## B18.3 (BUG 13): the audio facts - buses, mix rate, device, the
## bank, the Music autoload, null-stream players, TTS state.
static func _audio_block() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var out := "-- AUDIO --\n"
	if tree == null:
		return out + "no scene tree"
	var buses: Array[String] = []
	for i in AudioServer.bus_count:
		buses.append("%s %s dB%s%s" % [AudioServer.get_bus_name(i),
				"%.1f" % AudioServer.get_bus_volume_db(i),
				" MUTE" if AudioServer.is_bus_mute(i) else "",
				" SOLO" if AudioServer.is_bus_solo(i) else ""])
	out += "buses (%d): %s\n" % [AudioServer.bus_count, " | ".join(buses)]
	out += "mix rate: %d Hz\n" % AudioServer.get_mix_rate()
	out += "configured driver: %s\n" % str(ProjectSettings.get_setting(
			"audio/driver/driver", "Default"))
	var sound: Node = tree.root.get_node_or_null("/root/Sound")
	var music: Node = tree.root.get_node_or_null("/root/Music")
	var bank := 0
	if sound:
		bank = int((sound.get("_bank") as Dictionary).size())
	out += "SfxSynth bank: %s (%d clips)\n" % [
			"loaded" if sound else "NIL", bank]
	out += "Music autoload: %s\n" % ("exists" if music else "NIL")
	var nulls := 0
	var playing := 0
	var players := 0
	for n in tree.root.find_children("*", "AudioStreamPlayer", true, false):
		players += 1
		if n.stream == null:
			nulls += 1
		elif (n as AudioStreamPlayer).playing:
			playing += 1
	out += "players: %d total, %d playing, %d with NULL stream\n" % [
			players, playing, nulls]
	var narr: Node = tree.root.get_node_or_null("/root/Narrator")
	var tts_voices := "no"
	if narr and narr.has_method("tts_enabled") and narr.call("tts_enabled"):
		tts_voices = "yes"
	out += "TTS setting: %s | English voice: %s | narrator fallback used: %s" % [
			str(ProjectSettings.get_setting("audio/general/text_to_speech", false)),
			tts_voices,
			"yes" if narr and bool(narr.get("fallback_used")) else "no"]
	return out


static func _render_block() -> String:
	# B18.3 (3C): the graphics facts - renderer, adapter, quality
	# preset, triangles, draw calls, the LookDev availability
	var gq := "Auto"
	var qn := _node("/root/Quality")
	if qn:
		gq = "%s (tier %s)" % [str(qn.get("override")), str(qn.get("tier"))]
	var tris := int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
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
	return "-- RENDER --\nrenderer: %s | API: %s | adapter: %s\nwindow: %s | visible rect: %s\norientation: %d | safe area: %s\nfps: %d | draw calls: %d | triangles: %d\nquality: %s | LookDev scene: %s" \
			% [method, api, adapter, str(window), str(vis), orient,
			str(safe), fps, draws, tris, gq,
			"yes" if ResourceLoader.exists("res://scenes/lookdev.tscn") else "no"]


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
	# B18 1B (BUG 6): the orientation policy + the duplicate-set audit -
	# two button sets alive at once is the landscape-overlap mechanism
	var orient := str(ProjectSettings.get_setting(
			"display/window/handheld/orientation", "?"))
	var policy := "sensor_landscape (portrait locked out)" if orient == "4" \
			else "orientation setting %s" % orient
	var names := {}
	var dupes: Array[String] = []
	for n in tree.get_nodes_in_group("hud_buttons"):
		for c in n.get_children():
			if c.has_signal("down"):
				if names.has(c.name) and not dupes.has(c.name):
					dupes.append(c.name)
				names[c.name] = true
	out += "\norientation policy: %s | window %s | visible rect %s" % [
			policy, str(tree.root.size), str(tree.root.get_visible_rect().size)]
	out += "\nbuttons built: %d | duplicate button sets: %s" % [names.size(),
			"NONE" if dupes.is_empty() else "FOUND: " + ", ".join(dupes)]
	return out


static func _guide_block() -> String:
	const CLS_MapData := preload("res://scripts/map_data.gd")
	var tree := Engine.get_main_loop() as SceneTree
	var out := "-- GUIDE --\n"
	if tree == null:
		return out + "no scene tree"
	var hero := tree.get_first_node_in_group("player") as Node3D
	var nav: Dictionary = CLS_MapData.nav_target()
	var dist := -1.0
	if not nav.is_empty() and hero:
		var p: Vector2 = nav["pos"]
		dist = p.distance_to(
				Vector2(hero.global_position.x, hero.global_position.z))
	out += "objective: %s" % str(nav.get("text", "none")) \
			if not nav.is_empty() else "objective: none"
	if dist >= 0.0:
		out += " (%d m)\n" % int(dist)
	else:
		out += "\n"
	var sonar := "?"
	var interval := -1.0
	var settings := _node("/root/Settings")
	if settings:
		sonar = "on" if bool(settings.call("value", "sonar_on")) else "off"
	var guide := tree.get_first_node_in_group("guide")
	if guide and dist >= 0.0 and guide.has_method("ping_interval"):
		interval = float(guide.call("ping_interval", dist))
	out += "sonar: %s | ping interval now: %s s (shortens as you close in)\n" \
			% [sonar, "%.2f" % interval if interval >= 0.0 else "n/a"]
	var best: Node = null
	var best_d := INF
	for n in tree.get_nodes_in_group("door_prompt"):
		if n is Node3D and hero:
			var d: float = (n as Node3D).global_position.distance_to(
					hero.global_position)
			if d < best_d:
				best_d = d
				best = n
	if best:
		out += "nearest door: %s | state: %s | %d m away" % [
				str(best.get_meta("door_name", best.name)),
				str(best.get_meta("door_state", "?")), int(best_d)]
	else:
		out += "nearest door: none registered"
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
