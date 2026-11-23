extends Node

## THE MISSION MODULE (rebuild step 7): hosts by Game, drives the
## story spine. One active mission at a time; each stage completes on
## a REAL condition evaluated against the live world (never a timer):
## moved / camera / punch_landed / door_tried / street_reached /
## package_taken / delivered. The objective banner (a minimal top
## line - the full HUD pass is next) always says what to do, and the
## green marker pulse says where. Rewards + completion land in
## WorldState; `next` chains.

const M0 := "res://data/missions/m0.tres"

signal mission_completed(id: String)
signal stage_changed(objective: String)

var active: Resource = null
var stage_index := 0
var _stage_t := 0.0
var _hero_start := Vector3.ZERO
var _cam_yaw0 := 0.0
var _banner: Label
var _layer: CanvasLayer
var _marker: Node3D = null
var _package: Node3D = null
var _has_package := false
var _last_area := ""
var _defeat_count := 0
var _pending_spawn: Array = []
var _punch_wired := false


func _ready() -> void:
	name = "Missions"
	add_to_group("missions")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 30
	_layer.name = "MissionLayer"
	add_child(_layer)
	_banner = Label.new()
	_banner.name = "ObjectiveBanner"
	_banner.text = ""
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_top = 40.0
	_banner.offset_bottom = 72.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 20)
	_banner.add_theme_color_override("font_color", Color(0.85, 0.98, 0.8))
	_banner.add_theme_color_override("font_outline_color",
			Color(0.01, 0.02, 0.03))
	_banner.add_theme_constant_override("outline_size", 10)
	_layer.add_child(_banner)
	# world events feed conditions
	WorldState.event_fired.connect(_on_event)


## Start a mission by resource path or leave it loaded.
func start(path: String) -> void:
	var m: Resource = load(path)  # MissionData by path (no class_name deps)
	if m == null:
		push_error("Missions: cannot load %s" % path)
		return
	if active != null and active.id == m.id:
		return  # already running - the chain or the player said so
	active = m
	stage_index = 0
	_stage_t = 0.0
	WorldState.set_flag("mission_active:" + m.id)
	_enter_stage()
	Log.info("Mission start: %s - %s" % [m.id, m.title])


func _enter_stage() -> void:
	if active == null or stage_index >= active.stages.size():
		return
	var stage: Dictionary = active.stages[stage_index]
	_banner.text = stage.get("objective", "")
	stage_changed.emit(_banner.text)
	_capture_condition_state(stage.get("check", ""))
	_place_marker(stage)
	_defeat_count = 0
	_pending_spawn = stage.get("spawn", [])
	# in-area stages spawn NOW; cross-area stages wait for the
	# travel to land (the _process branch below)
	if not _pending_spawn.is_empty() \
			and Game.area_id == str(stage.get("area", "")) \
			and _scene_landed():
		_spawn_muscle()
	if stage.get("check", "") == "package_taken" and not _has_package \
			and Game.area_id == str(stage.get("area", "")) \
			and _scene_landed():
		_spawn_package(stage)
	# THE CALL (M6): the stage's phone rings the moment it lands
	if stage.has("ring"):
		var ph := get_tree().get_first_node_in_group("phone")
		if ph and is_instance_valid(ph):
			ph.ring(stage.get("ring", {}))
	_stage_t = 0.0
	Log.info("Mission stage: %s (%s)" % [stage.get("objective", ""),
			stage.get("check", "")])


func _capture_condition_state(check: String) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	_hero_start = hero.global_position \
			if hero and is_instance_valid(hero) else Vector3.ZERO
	var rig := get_tree().get_first_node_in_group("camera_rig") as Node3D
	_cam_yaw0 = float(rig.get("yaw")) \
			if rig and is_instance_valid(rig) else 0.0

## The green objective marker: a pulsing ring at the stage position
## (only in the stage's own area).
func _place_marker(stage: Dictionary) -> void:
	_drop_marker()
	if Game.area_id != str(stage.get("area", "")):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_marker = Node3D.new()
	_marker.name = "ObjectiveMarker"
	_marker.position = stage.get("marker", Vector3.ZERO)
	scene.add_child(_marker)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.5
	rm.outer_radius = 0.66
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.86, 0.52)
	mat.emission_enabled = true
	mat.emission = Color(0.24, 0.86, 0.52)
	mat.emission_energy_multiplier = 1.4
	rm.material = mat
	ring.mesh = rm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.name = "Ring"
	_marker.add_child(ring)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 2.4
	cm.material = mat
	col.mesh = cm
	col.position = Vector3(0, 1.2, 0)
	col.name = "Beam"
	_marker.add_child(col)


func _drop_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## The package prop on the workbench (M1).
func _spawn_package(st: Dictionary = {}) -> void:
	_drop_package()
	var scene := get_tree().current_scene
	if scene == null:
		return
	# M1's workbench box; any later stage names its own counter
	var at := Vector3(-6.5, 1.05, 4.8)
	var want_area := "warehouse"
	if not st.is_empty():
		at = st.get("marker", at)
		want_area = str(st.get("area", want_area))
	if Game.area_id != want_area:
		return
	_package = Node3D.new()
	_package.name = "ThePackage"
	_package.position = at
	scene.add_child(_package)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.3, 0.36)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.3, 0.16)
	bm.material = mat
	box.mesh = bm
	box.name = "Box"
	_package.add_child(box)
	var tag := Label3D.new()
	tag.text = "THE PACKAGE"
	tag.modulate = Color(0.55, 0.95, 1.0)
	tag.font_size = 26
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 0.55, 0)
	_package.add_child(tag)


func _drop_package() -> void:
	if _package and is_instance_valid(_package):
		_package.queue_free()
	_package = null


## the current scene really IS the area Game claims (the fade
## gap: area_id flips before the swap lands)
func _scene_landed() -> bool:
	var scene := get_tree().current_scene
	return scene != null and str(scene.scene_file_path) == str(
			Game.AREAS.get(Game.area_id, ""))


func _process(delta: float) -> void:
	_stage_t += delta
	# a travel frees the marker/package with the old scene. But
	# Game.area_id flips BEFORE the swap lands (during the fade) -
	# placing then writes into the DYING scene. Wait until the
	# current scene's file IS the new area's file, then re-place.
	if Game.area_id != _last_area:
		if _scene_landed():
			_last_area = Game.area_id
			if active != null and stage_index < active.stages.size():
				var st: Dictionary = active.stages[stage_index]
				_place_marker(st)
				if st.get("check", "") == "package_taken" \
						and not _has_package:
					_spawn_package(st)
				if not _pending_spawn.is_empty():
					_spawn_muscle()
	if _marker and is_instance_valid(_marker):
		var ring := _marker.get_node_or_null("Ring") as MeshInstance3D
		if ring:
			ring.scale = Vector3.ONE * (1.0 + 0.12
					* sin(_stage_t * 3.0))
	# M4's other answer: a fist near the stage's door. The hero
	# instance dies on travel - rewire when the stage wants it.
	var hero_w := get_tree().get_first_node_in_group("player") as Node3D
	if hero_w == null or not is_instance_valid(hero_w):
		_punch_wired = false
	elif not _punch_wired:
		if not hero_w.face_action.is_connected(_on_hero_action):
			hero_w.face_action.connect(_on_hero_action)
		_punch_wired = true
	if active == null:
		return
	var check: String = active.stages[stage_index].get("check", "")
	# the package collects by walking to it (no button needed yet -
	# the interaction verb arrives with the world interactions pass)
	if check == "package_taken" and _package and is_instance_valid(_package):
		var h := get_tree().get_first_node_in_group("player") as Node3D
		if h and is_instance_valid(h) and h.global_position.distance_to(
				_package.global_position) < 1.6:
			take_package()
	if _check_condition(check):
		_advance()


## THE conditions - each reads the real world, nothing times out.
func _check_condition(check: String) -> bool:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	match check:
		"moved":
			return hero != null and is_instance_valid(hero) \
					and hero.global_position.distance_to(_hero_start) > 2.5
		"camera":
			var rig := get_tree().get_first_node_in_group("camera_rig") \
					as Node3D
			if rig == null or hero == null:
				return false
			var yaw: float = float(rig.get("yaw"))
			return absf(yaw - _cam_yaw0) > 1.0 \
					or absf(yaw - _cam_yaw0) > PI * 2.0 - 1.0
		"punch_landed":
			# the combat core's hit_landed signal sets the flag below
			return WorldState.flag("m0_hit_the_bag")
		"door_tried":
			return WorldState.flag("m0_tried_the_gate")
		"street_reached":
			return Game.area_id == "neighbourhood"
		"at_area":
			var st_a: Dictionary = active.stages[stage_index]
			return Game.area_id == str(st_a.get("area", ""))
		"reach":
			# stand at the marker (M5's corner, the boss's curb)
			var st_r: Dictionary = active.stages[stage_index]
			return hero != null and is_instance_valid(hero) \
					and Game.area_id == str(st_r.get("area", "")) \
					and hero.global_position.distance_to(
					st_r.get("marker", Vector3.ZERO)) < 2.6
		"package_taken":
			return _has_package
		"defeat":
			# real bodies, counted by the enemy_down event
			var st_d: Dictionary = active.stages[stage_index]
			return _defeat_count >= int(st_d.get("need", 1))
		"area_clear":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) \
						and float(e.get("hp")) > 0.0:
					return false
			return true
		"any_flag":
			# the choice stages (M4's talk-or-break, M6's answer)
			var st_f: Dictionary = active.stages[stage_index]
			for f in st_f.get("flags", []):
				if WorldState.flag(str(f)):
					return true
			return false
		"delivered":
			# markers live in their OWN area's coordinate space: a
			# raw distance across scenes "delivered" M1 from the
			# warehouse workbench (2.06 m from the street marker) -
			# the area must match before any distance is read
			var stage: Dictionary = active.stages[stage_index]
			if _has_package and hero != null \
					and is_instance_valid(hero) \
					and Game.area_id == str(stage.get("area", "")) \
					and hero.global_position.distance_to(
					stage.get("marker", Vector3.ZERO)) < 2.6:
				consume_package()
				return true
			return false
	return false


## GRAB at a choice spot (M4's grille, M3's ask): the street's
## other verb. Runs after police + market in the hero's chain.
func try_grab(hero: Node3D) -> bool:
	if active == null or hero == null or not is_instance_valid(hero):
		return false
	if stage_index >= active.stages.size():
		return false
	var st: Dictionary = active.stages[stage_index]
	if not st.has("grab_flag") or Game.area_id != str(st.get("area", "")):
		return false
	if hero.global_position.distance_to(
			st.get("marker", Vector3.ZERO)) > 3.4:
		return false
	WorldState.set_flag(str(st["grab_flag"]))
	WorldState.push_event("choice", {"what": str(st["grab_flag"])})
	Log.info("Mission: the grab answers (%s)" % st["grab_flag"])
	return true


## a fist near the stage's marker (M4: the grille gives way)
func _on_hero_action(action: String) -> void:
	if active == null or stage_index >= active.stages.size():
		return
	var st: Dictionary = active.stages[stage_index]
	if action != "punch" or not st.has("punch_flag"):
		return
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null or not is_instance_valid(hero):
		return
	if hero.global_position.distance_to(
			st.get("marker", Vector3.ZERO)) > 3.4:
		return
	WorldState.set_flag(str(st["punch_flag"]))
	WorldState.bump("heat", 2.0)  # the street heard the steel
	WorldState.set_flag("door_broken:" + str(st.get("door", "")))
	WorldState.push_event("choice", {"what": str(st["punch_flag"])})
	Log.info("Mission: the fist answers (%s)" % st["punch_flag"])


## the stage's muscle (M2's gym, M5's collectors), spawned when
## the area has landed. Refusing the Corporation sends harder men.
func _spawn_muscle() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var escalate := 1.0
	if WorldState.flag("m6_declined"):
		escalate = Tuning.v("escalate_hp_mult")
	var script := load("res://scripts/npc/enemy.gd") as GDScript
	for spec in _pending_spawn:
		var e: CharacterBody3D = script.new()
		e.position = spec.get("pos", Vector3.ZERO)
		e.rotation.y = float(spec.get("rot", 0.0))
		if spec.has("hp"):
			e.set("hp", float(spec["hp"]) * escalate)
		else:
			e.set("hp", float(e.get("hp")) * escalate)
		e.add_to_group("mission_spawn")
		scene.add_child(e)
		Log.info("Mission: muscle at %s (hp %.0f)" % [
				str(spec.get("pos", Vector3.ZERO)),
				float(e.get("hp"))])
	_pending_spawn = []


func _drop_spawned() -> void:
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.queue_free()


func _advance() -> void:
	_drop_spawned()
	stage_index += 1
	if stage_index >= active.stages.size():
		_complete()
	else:
		_enter_stage()


func _complete() -> void:
	var m := active
	_banner.text = "%s - DONE%s" % [m.title,
			" (+$%d)" % m.reward_cash if m.reward_cash > 0 else ""]
	WorldState.set_flag("mission_done:" + m.id)
	WorldState.set_value("mission_active:" + m.id, false)
	if m.reward_cash > 0:
		WorldState.bump("stash_cash", float(m.reward_cash))
	if m.reward_clean > 0:
		WorldState.bump("clean_cash", float(m.reward_clean))
		WorldState.push_event("paid_clean", {"amount":
				m.reward_clean})
	if m.reward_xp > 0.0:
		WorldState.bump("xp", m.reward_xp)
	mission_completed.emit(m.id)
	Log.info("Mission complete: %s (+$%d, +%.0fxp)" % [m.id,
			m.reward_cash, m.reward_xp])
	Sound.play("cloth_2", -6.0, 0.8)
	Haptics.fire("super")
	var finished := active
	active = null
	_drop_marker()
	_drop_package()
	if finished.next != "":
		var next_path := "res://data/missions/%s.tres" % finished.next
		await get_tree().create_timer(1.6).timeout
		start(next_path)
	else:
		_banner.text = "Free the night - the city is yours"


## World events feed the flag conditions.
func _on_event(kind: String, data: Dictionary) -> void:
	if str(kind) == "enemy_down":
		_defeat_count += 1
		return
	if kind == "door_tried" and Game.area_id == "warehouse":
		WorldState.set_flag("m0_tried_the_gate")
	if kind == "ambush_woke":
		pass


## The combat core calls this on every landed hit (the bag check).
func note_hit(target: Node) -> void:
	if target != null and str(target.name) == "PunchingBag":
		WorldState.set_flag("m0_hit_the_bag")


## The hero touches the package (M1 stage 1).
func take_package() -> void:
	_has_package = true
	_drop_package()
	WorldState.push_event("package_taken", {})
	_banner.text = "Carry it to THE RAIN GLASS"
	if active and stage_index < active.stages.size():
		var stage: Dictionary = active.stages[stage_index]
		stage["objective"] = "Carry it to THE RAIN GLASS"
		stage_changed.emit(_banner.text)
	Log.info("Missions: package taken")


func has_package() -> bool:
	return _has_package


## The player enters the bar (delivered check is proximity, but the
## package is consumed on delivery).
func consume_package() -> void:
	_has_package = false
