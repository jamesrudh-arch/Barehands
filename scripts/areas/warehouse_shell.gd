extends Node3D

## THE WAREHOUSE SHELL (rebuild step 1): the smallest playable landing
## place for PLAY — a readable warm-lit room so the boot chain has
## somewhere real to arrive. The full home (bed, workbench, phone
## table, weapon rack, training corner, yard, gate — 02_MASTER_DESIGN
## §3 area 1) lands at teardown step 4.

func _ready() -> void:
	# floor + four walls: the 20x15 converted warehouse footprint
	_floor(Vector3(20.0, 0.2, 15.0), Vector3(0, -0.1, 0),
			Color(0.16, 0.15, 0.17))
	_floor(Vector3(20.6, 4.0, 0.3), Vector3(0, 2.0, -7.5),
			Color(0.1, 0.1, 0.12))
	_floor(Vector3(20.6, 4.0, 0.3), Vector3(0, 2.0, 7.5),
			Color(0.1, 0.1, 0.12))
	_floor(Vector3(0.3, 4.0, 15.3), Vector3(-10.15, 2.0, 0),
			Color(0.11, 0.11, 0.13))
	_floor(Vector3(0.3, 4.0, 15.3), Vector3(10.15, 2.0, 0),
			Color(0.11, 0.11, 0.13))
	# the warm practical light + a soft fill so nothing is pure black
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.4, 0)
	lamp.light_color = Color(1.0, 0.78, 0.55)
	lamp.omni_range = 16.0
	lamp.light_energy = 1.4
	add_child(lamp)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, 30, 0)
	fill.light_color = Color(0.35, 0.38, 0.5)
	fill.light_energy = 0.5
	add_child(fill)
	# the camera is the camera RIG's (mounted by Game with the hero in
	# PLAY) - one camera authority per scene, the BuildStamp lesson
	# the shell's name plate, honest about what it is
	var plate := Label3D.new()
	plate.text = "THE WAREHOUSE\nrebuild step 4 fills the home"
	plate.modulate = Color(1.0, 0.85, 0.55)
	plate.font_size = 40
	plate.outline_size = 10
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0, 2.4, -5.0)
	add_child(plate)
	# the spawn marker (Game lands the hero here by spawn id "start")
	var spawn := Node3D.new()
	spawn.name = "SpawnStart"
	spawn.position = Vector3(0, 0.05, 3.0)
	add_child(spawn)
	# a spawn ring so the arrival spot reads
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.55
	rm.outer_radius = 0.7
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.24, 0.86, 0.52)
	rmat.emission_enabled = true
	rmat.emission = Color(0.24, 0.86, 0.52)
	rmat.emission_energy_multiplier = 1.2
	rm.material = rmat
	ring.mesh = rm
	ring.position = Vector3(0, 0.05, 3.0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	add_child(ring)
	Log.info("Warehouse shell ready (area_id=%s spawn=%s)" %
			[Game.area_id, Game.spawn_id])


func _floor(sz: Vector3, pos: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = sz
	shape.shape = cs
	body.add_child(shape)
	add_child(body)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	bm.material = mat
	m.mesh = bm
	m.position = pos
	add_child(m)
