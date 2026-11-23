extends Node

## THE CITY SURFACE (S5.12): the permanent record of escalation.
## Schedules move the cast with the beats; scorch and memorials
## persist where blood landed; a broken-and-unpaid shop boards up;
## crowds thin when the block runs hot; the street gossips and the
## stories distort over beats. Everything rides WorldState (saved).

const SCHEDULES := {
	"OLD DEE": {
		0: Vector3(-40.4, 0.05, 5.4),   # DUSK: the counter
		1: Vector3(-40.4, 0.05, 5.4),   # MIDNIGHT: still serving
		2: Vector3(-42.6, 0.05, 6.6),   # 3 AM: inside the doorway
	},
	"MARLA": {
		0: Vector3(-4.6, 0.05, 5.4),    # DUSK: the bar front
		1: Vector3(-4.6, 0.05, 5.4),
		2: Vector3(-9.0, 0.05, 5.4),    # 3 AM: down the block
	},
	"TONY": {
		0: Vector3(-35.5, 0.05, 5.0),   # DUSK: the gym counter
		1: Vector3(-35.5, 0.05, 5.0),
		2: Vector3(-33.0, 0.05, 3.2),   # 3 AM: the lock-up walk
	},
	"VESPER": {
		0: Vector3(-41.5, 0.05, -5.0),  # DUSK: the back curb
		1: Vector3(-41.5, 0.05, -5.0),
		2: Vector3(-41.5, 0.05, 1.0),   # 3 AM: out front, watching
	},
	"SAL": {
		0: Vector3(30.0, 0.05, -1.6),   # the stall, all night
		1: Vector3(30.0, 0.05, -1.6),
		2: Vector3(28.0, 0.05, -3.6),   # 3 AM: the awning
	},
}

var _scene_inst: Node = null
var _last_gossip_beat := -1


func _ready() -> void:
	name = "Surface"
	add_to_group("surface")
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldState.event_fired.connect(_on_event)
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws and not ws.beat_advanced.is_connected(_on_beat):
		ws.beat_advanced.connect(_on_beat)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _scene_inst:
		return
	_scene_inst = scene
	_apply_schedules()
	_apply_scars()
	_apply_boards()


## the cast keeps its hours (label prefix keys the schedule)
func _apply_schedules() -> void:
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws == null:
		return
	var ph: int = int(ws.beat()) % 3
	for l in get_tree().get_nodes_in_group("local"):
		var label := str(l.get_meta("who", ""))
		for who in SCHEDULES:
			if label.begins_with(who):
				var spot: Vector3 = SCHEDULES[who][ph]
				l.global_position = spot
				break


## scorch where crimes burned, memorials where named men fell
func _apply_scars() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var area := Game.area_id
	var i := 0
	for s in float_list("scorch_list"):
		var d: Dictionary = s
		if str(d.get("area", "")) != area:
			continue
		_scorch(scene, Vector3(d.get("pos", Vector3.ZERO)), i)
		i += 1
	for m in float_list("memorial_list"):
		var d2: Dictionary = m
		if str(d2.get("area", "")) != area:
			continue
		_memorial(scene, Vector3(d2.get("pos", Vector3.ZERO)),
				str(d2.get("who", "a fighter")), i)
		i += 1


func _scorch(scene: Node, at: Vector3, i: int) -> void:
	if scene.get_node_or_null("Scorch_%d" % i) != null:
		return
	var m := MeshInstance3D.new()
	m.name = "Scorch_%d" % i
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85
	cm.bottom_radius = 0.95
	cm.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04)
	mat.roughness = 1.0
	cm.material = mat
	m.mesh = cm
	m.position = at + Vector3(0, 0.011, 0)
	scene.add_child(m)


func _memorial(scene: Node, at: Vector3, who: String, i: int) -> void:
	if scene.get_node_or_null("Memorial_%d" % i) != null:
		return
	var g := Node3D.new()
	g.name = "Memorial_%d" % i
	g.position = at
	scene.add_child(g)
	var card := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.26, 0.34, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.88, 0.8)
	bm.material = mat
	card.mesh = bm
	card.position = Vector3(0, 0.32, 0)
	card.rotation_degrees = Vector3(-12, 0, 0)
	g.add_child(card)
	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.03
	fm.bottom_radius = 0.05
	fm.height = 0.16
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1.0, 0.72, 0.25)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.6, 0.2)
	em.emission_energy_multiplier = 1.6
	fm.material = em
	flame.mesh = fm
	flame.position = Vector3(0.12, 0.09, 0)
	g.add_child(flame)
	var tag := Label3D.new()
	tag.text = "FOR %s" % who
	tag.font_size = 22
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.95, 0.9, 0.8)
	tag.position = Vector3(0, 0.75, 0)
	g.add_child(tag)


## a broken-and-unpaid shop boards up (M4's answer, unhealed)
func _apply_boards() -> void:
	if Game.area_id != "neighbourhood":
		return
	if not WorldState.flag("m4_broke") or WorldState.flag("pawn_paid"):
		return
	if WorldState.flag("pawn_boarded"):
		var scene := get_tree().current_scene
		if scene and scene.get_node_or_null("Boards_PAWN") == null:
			_boards(scene)
		return
	WorldState.set_flag("pawn_boarded")
	var scene := get_tree().current_scene
	if scene:
		_boards(scene)
	WorldState.push_event("boards", {"who": "THE PAWN DESK",
			"msg": "The pawn desk boards up. The street noticed."})


func _boards(scene: Node) -> void:
	var b := MeshInstance3D.new()
	b.name = "Boards_PAWN"
	var bm := BoxMesh.new()
	bm.size = Vector3(3.6, 1.6, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.3, 0.16)
	mat.roughness = 0.95
	bm.material = mat
	b.mesh = bm
	b.position = Vector3(-18.0, 1.4, 7.45)
	b.rotation_degrees = Vector3(0, 0, -2.0)
	scene.add_child(b)


## crowds thin when the block runs hot
func _on_beat(_beat: int, _name: String) -> void:
	_apply_schedules()
	var heat := float(WorldState.get_value("heat", 0.0))
	if heat >= 8.0:
		var gone := 0
		for p in get_tree().get_nodes_in_group("pedestrian"):
			if gone >= 2:
				break
			if is_instance_valid(p):
				p.queue_free()
				gone += 1
		if gone > 0:
			WorldState.push_event("thinning", {"msg":
					"The street empties early. Nobody wants witnesses."})
			Log.info("Surface: the street thins (%d walkers gone)" % gone)


## the record: crimes scorch, named men memorialize
func _on_event(kind: String, data: Dictionary) -> void:
	if str(kind) == "crime" and data.has("pos"):
		_remember("scorch_list", {
				"area": Game.area_id,
				"pos": data.get("pos", Vector3.ZERO)})
	elif str(kind) == "enemy_down":
		var who := str(data.get("who", ""))
		if who.begins_with("THE LIEUTENANT") or who.begins_with("THE COPY") \
				or who.begins_with("THE STUDENT"):
			var e := get_tree().get_first_node_in_group("enemy")
			# the fallen body's position if still valid
			for n in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(n) and str(n.get_meta("name",
						n.name)).begins_with(who.substr(0, 8)):
					_remember("memorial_list", {
							"area": Game.area_id,
							"pos": n.global_position, "who": who})
					break


func _remember(key: String, entry: Dictionary) -> void:
	var lst: Array = WorldState.get_value(key, [])
	lst.append(entry)
	while lst.size() > 12:
		lst.pop_front()
	WorldState.set_value(key, lst)


func float_list(key: String) -> Array:
	return WorldState.get_value(key, [])
