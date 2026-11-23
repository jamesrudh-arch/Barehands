extends Node3D

## THE AIRPORT — AREA 5 (02 §3): the terminal exterior + the
## tarmac + a PARKED PLANE you can board (the Second City beyond).
## Cold floodlit blue-white against the city's sodium - the only
## place in Cinder City that smells like elsewhere. Compact and
## real: a check-in front, the departures board, the fence, the
## plane at its stand with the stairs down.

const CLS_MatLib := preload("res://scripts/world/mat_lib.gd")

const PALETTE := {
	"ink": Color(0.015, 0.02, 0.035),
	"concrete": Color(0.16, 0.17, 0.19),
	"steel": Color(0.30, 0.33, 0.38),
	"glass": Color(0.25, 0.4, 0.55),
	"flood": Color(0.8, 0.9, 1.0),
	"guide": Color(0.24, 0.86, 0.52),
}


func _ready() -> void:
	_ground()
	_terminal()
	_fence()
	_plane()
	_lighting()
	_markers()
	_life()
	Log.info("Airport ready (area=%s spawn=%s)" % [
			Game.area_id, Game.spawn_id])


func _ground() -> void:
	_solid(self, Vector3(90.0, 0.1, 60.0), Vector3(0, -0.05, 0),
			PALETTE.concrete, 0.92, 0.0, "concrete")
	# the taxiway line: pale paint stripes
	for x in range(-36, 40, 8):
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(3.4, 0.012, 0.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.78, 0.8)
		sm.material = mat
		stripe.mesh = sm
		stripe.position = Vector3(x, 0.056, -4.0)
		add_child(stripe)


func _terminal() -> void:
	var front := Node3D.new()
	front.name = "Front_THE_TERMINAL"
	front.position = Vector3(0, 0, 22.0)
	add_child(front)
	# the hall: a long low glass box with a dark roof
	_solid(front, Vector3(34.0, 5.0, 6.0), Vector3(0, 2.5, 0),
			PALETTE.glass, 0.25, 0.6)
	_solid(front, Vector3(36.0, 0.6, 7.0), Vector3(0, 5.3, 0),
			PALETTE.steel, 0.5, 0.4)
	# the departures board: a lit panel over the door
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10.0, 1.6, 0.15)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.05, 0.08, 0.12)
	bmat.emission_enabled = true
	bmat.emission = Color(0.25, 0.5, 0.7)
	bmat.emission_energy_multiplier = 1.2
	bm.material = bmat
	board.mesh = bm
	board.position = Vector3(0, 4.2, -3.2)
	front.add_child(board)
	var tag := Label3D.new()
	tag.text = "DEPARTURES"
	tag.font_size = 44
	tag.outline_size = 10
	tag.modulate = Color(0.7, 0.9, 1.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	tag.position = Vector3(0, 4.2, -3.1)
	front.add_child(tag)
	Doors.register(front, "THE TERMINAL", {"state": "open"})


func _fence() -> void:
	for x in range(-42, 44, 6):
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.18, 2.6, 0.18)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE.steel.darkened(0.2)
		pm.material = mat
		post.mesh = pm
		post.position = Vector3(x, 1.3, 12.0)
		add_child(post)


## THE PARKED PLANE (02 §3: "a PARKED PLANE you can board")
func _plane() -> void:
	var p := Node3D.new()
	p.name = "Front_THE_PLANE"
	p.position = Vector3(0, 0, -14.0)
	add_child(p)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.82, 0.84, 0.87)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.12)
	# fuselage: a fat cylinder on its side
	var fus := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.8
	fm.bottom_radius = 1.8
	fm.height = 18.0
	fm.material = white
	fus.mesh = fm
	fus.rotation_degrees = Vector3(0, 0, 90)
	fus.position = Vector3(0, 2.6, 0)
	p.add_child(fus)
	# the nose cone
	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 1.8
	nm.height = 3.4
	nm.material = white
	nose.mesh = nm
	nose.position = Vector3(10.5, 2.6, 0)
	nose.scale = Vector3(1.4, 1.0, 1.0)
	p.add_child(nose)
	# wings
	for s in [-1, 1]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(5.0, 0.35, 11.0)
		wm.material = white
		wing.mesh = wm
		wing.position = Vector3(-1.0, 2.2, s * 6.5)
		wing.rotation_degrees = Vector3(0, s * 6.0, 0)
		p.add_child(wing)
	# the tail
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.4, 4.2, 3.4)
	tm.material = white
	tail.mesh = tm
	tail.position = Vector3(-8.6, 5.0, 0)
	p.add_child(tail)
	# the boarding stairs (the door in)
	var stairs := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.8, 0.18, 4.6)
	sm.material = dark
	stairs.mesh = sm
	stairs.position = Vector3(4.6, 0.9, 2.9)
	stairs.rotation_degrees = Vector3(-22, 0, 0)
	p.add_child(stairs)
	var tag := Label3D.new()
	tag.text = "THE PLANE - BOARD (GRAB)"
	tag.font_size = 34
	tag.outline_size = 10
	tag.modulate = Color(0.55, 0.95, 1.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(4.6, 3.4, 2.6)
	p.add_child(tag)


func _lighting() -> void:
	var env := WorldEnvironment.new()
	env.name = "Air"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = PALETTE.ink
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.09, 0.11, 0.15)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.35
	e.tonemap_white = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.07, 0.1)
	e.fog_density = 0.006
	env.environment = e
	add_child(env)
	# two floodlights: the tarmac's cold stare
	for x in [-14.0, 14.0]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.12
		pm.height = 9.0
		pm.material = StandardMaterial3D.new()
		(pm.material as StandardMaterial3D).albedo_color = \
				PALETTE.steel
		pole.mesh = pm
		pole.position = Vector3(x, 4.5, 8.0)
		add_child(pole)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(1.4, 0.3, 0.8)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.9, 0.95, 1.0)
		hmat.emission_enabled = true
		hmat.emission = PALETTE.flood
		hmat.emission_energy_multiplier = 2.2
		hm.material = hmat
		head.mesh = hm
		head.position = Vector3(x, 9.1, 8.0)
		add_child(head)
		var l := OmniLight3D.new()
		l.light_color = PALETTE.flood
		l.light_energy = 2.4
		l.omni_range = 26.0
		l.position = Vector3(x, 8.8, 8.0)
		add_child(l)


func _markers() -> void:
	_spawn_marker("SpawnStart", Vector3(0.0, 0.05, 14.0))


## the city's proven box: body + mesh, MatLib surface when named
func _solid(parent: Node, sz: Vector3, pos: Vector3, col: Color,
		rough := 0.9, metal := 0.0, mat_name := "") -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cshape := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cshape.shape = sh
	body.add_child(cshape)
	parent.add_child(body)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	bm.material = mat
	m.mesh = bm
	body.add_child(m)


func _spawn_marker(id: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = id
	n.position = pos
	add_child(n)


## the pilot at the stairs + two ground crew walkers
func _life() -> void:
	var CLS_Local := load("res://scripts/npc/local.gd")
	CLS_Local.place(self, "res://assets/native/cast_soldier.tscn",
			"res://assets/native/ual_baked_soldier.res",
			Vector3(3.4, 0.05, 5.0), PI, "THE PILOT - THE STAND")
	var CLS_Pedestrian := load("res://scripts/npc/pedestrian.gd")
	for i in 2:
		var p: CharacterBody3D = CLS_Pedestrian.new()
		p.position = Vector3(-20.0 + i * 14.0, 0.05, 6.0)
		add_child(p)
