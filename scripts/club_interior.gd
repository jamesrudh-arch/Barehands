extends "res://scripts/venue.gd"
## B19 batch 9: THE VELVET ROOM - the club. A lit dance floor, a DJ
## booth, two speakers, a service bar with stools, and dancers on the
## floor actually DANCING (the UAL's Dance clip). The queue outside
## (the living city) is waiting for exactly this room.

func _init() -> void:
	venue_name = "THE VELVET ROOM"
	interior_x = 960.0
	door_street = Vector3(231.0, 1.0, -10.2)
	door_front = Vector3(231.0, 0.0, -9.8)
	street_return = Vector3(231.0, 0.02, -7.6)
	inside_spawn = Vector3(0, 0.02, 2.2)


func _build_room() -> void:
	room_shell(Vector3(10.0, 3.6, 8.0), Color(0.08, 0.06, 0.09),
			Color(0.1, 0.07, 0.11))
	# the dance floor: a dark dance rug with magenta/cyan glow quads
	furn("kenney_furniture/rugSquare.glb", Vector3(0.4, 0.005, -0.6), 0.0, 3.2)
	_glow_quad(Vector3(0.4, 0.02, -0.6), Color(1.0, 0.16, 0.75), Vector2(3.0, 3.0))
	_glow_quad(Vector3(-2.6, 0.02, 0.4), Color(0.18, 0.95, 0.9), Vector2(1.2, 3.0))
	_glow_quad(Vector3(3.2, 0.02, 0.6), Color(0.18, 0.95, 0.9), Vector2(1.2, 3.0))
	# the DJ booth: desk + a screen that reads as the deck
	furn("kenney_furniture/desk.glb", Vector3(0.4, 0, -3.2), 0.0, 1.15)
	furn("kenney_furniture/televisionModern.glb", Vector3(0.4, 0.5, -3.4), PI, 1.1)
	# the speakers: dark cabinets with a lit cone ring (code-built,
	# honest small props - the kit has no speaker)
	for sx in [-1.6, 2.4]:
		_speaker(Vector3(sx, 0, -3.1))
	# the service bar along the side
	furn("kenney_furniture/kitchenBar.glb", Vector3(3.8, 0, -0.5), -PI / 2.0, 1.15)
	furn("kenney_furniture/stoolBarSquare.glb", Vector3(3.0, 0, -0.9), 0.0, 1.1)
	furn("kenney_furniture/stoolBarSquare.glb", Vector3(3.0, 0, 0.1), 0.0, 1.1)
	furn("kenney_food/bottle-ketchup.glb", Vector3(3.75, 0.48, -0.2), 0.0, 1.0)
	# seating nook + the corner nobody talks about
	furn("kenney_furniture/loungeSofaLong.glb", Vector3(-3.4, 0, 2.6), PI / 2.0, 1.05)
	furn("kenney_furniture/tableCoffee.glb", Vector3(-2.4, 0, 2.6), 0.0, 1.0)
	furn("kenney_furniture/trashcan.glb", Vector3(-4.4, 0, -2.8), 0.0, 1.0)
	# the crowd: dancers on the floor (the UAL Dance clip), a server
	var dancers := [
		[Vector3(-0.8, 0, -1.2), Color(0.5, 0.2, 0.4), "res://assets/cast/Superhero_Female_FullBody.gltf"],
		[Vector3(1.6, 0, -0.4), Color(0.2, 0.4, 0.55), "res://assets/cast/Male_Peasant_Body.gltf"],
		[Vector3(0.4, 0, 0.8), Color(0.55, 0.4, 0.15), "res://assets/cast/Female_Ranger_Body.gltf"],
	]
	for d in dancers:
		var rig := person([d[2]], d[0], d[1], 1.0)
		rig.play("Dance", 0.2, randf_range(0.9, 1.15))


## An additive glow quad on the floor (the club's colour language).
func _glow_quad(pos: Vector3, color: Color, size: Vector2) -> void:
	var shaft: Shader = load("res://shaders/shaft.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shaft
	mat.set_shader_parameter("tint",
			Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("strength", 0.5)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	qm.material = mat
	mi.mesh = qm
	mi.position = pos
	mi.rotation.x = -PI / 2.0
	add_child(mi)


## A speaker: dark box, mesh grille face, a lit ring that pulses.
func _speaker(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(0.55, 1.1, 0.45)
	col.shape = cs
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 1.1, 0.45)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.06, 0.07)
	m.roughness = 0.6
	bm.material = m
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)
	# the pulsing ring (the beat)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.17
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.3, 0.9, 0.85)
	rm.emission_enabled = true
	rm.emission = Color(0.2, 0.85, 0.8)
	rm.emission_energy_multiplier = 0.8
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = rm
	ring.mesh = torus
	ring.position = pos + Vector3(0, 0.7, 0.24)
	add_child(ring)
	var tw := create_tween().set_loops()
	tw.tween_property(rm, "emission_energy_multiplier", 1.1, 0.48)
	tw.tween_property(rm, "emission_energy_multiplier", 0.5, 0.48)
