extends Node3D

## THE SECOND CITY — AREA 6 (02 §3): "a small separate hub - a
## plaza, a few streets, a bar, a mission giver; its own look and
## music; return by plane." Warmer than Cinder City ever allowed
## itself: amber windows, terracotta walls, a fountain that
## actually runs. The giver's jobs are leverage-flavored asks.

const CLS_MatLib := preload("res://scripts/world/mat_lib.gd")

const PALETTE := {
	"ink": Color(0.03, 0.02, 0.02),
	"terracotta": Color(0.32, 0.2, 0.14),
	"stone": Color(0.24, 0.22, 0.2),
	"amber": Color(1.0, 0.72, 0.35),
	"guide": Color(0.24, 0.86, 0.52),
}

## the plaza's fronts: label, x, kind
const FRONTS := [
	["THE ANCHOR", -12.0, "open", "bar"],
	["THE MONEY DESK", -2.0, "open", "store"],
	["ROOMS", 8.0, "locked", ""],
]


func _ready() -> void:
	_ground()
	_fronts()
	_fountain()
	_plane_home()
	_lighting()
	_markers()
	_life()
	Log.info("Second city ready (area=%s spawn=%s)" % [
			Game.area_id, Game.spawn_id])


func _ground() -> void:
	# the plaza: stone tiles, a warm square
	_solid(self, Vector3(52.0, 0.1, 40.0), Vector3(0, -0.05, 0),
			PALETTE.stone, 0.92, 0.0, "concrete")
	_solid(self, Vector3(30.0, 0.11, 22.0), Vector3(0, 0.0, -2.0),
			PALETTE.stone.darkened(0.12), 0.92, 0.0, "concrete")


func _fronts() -> void:
	for f in FRONTS:
		var label: String = f[0]
		var x: float = f[1]
		var kind: String = f[2]
		var front := Node3D.new()
		front.name = "Front_" + label.replace(" ", "_")
		front.position = Vector3(x, 0, 12.0)
		add_child(front)
		# terracotta massing
		_solid(front, Vector3(8.0, 6.5, 6.0), Vector3(0, 3.25, 0),
				PALETTE.terracotta, 0.95, 0.0, "brick")
		# the lit doorway + amber panes (the city's own look)
		var pane := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.6, 2.6, 0.1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE.amber
		mat.emission_enabled = true
		mat.emission = PALETTE.amber
		mat.emission_energy_multiplier = 1.1
		pm.material = mat
		pane.mesh = pm
		pane.position = Vector3(0, 1.4, -3.06)
		front.add_child(pane)
		for s in [-1, 1]:
			var win := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.8, 1.6, 0.1)
			wm.material = mat
			win.mesh = wm
			win.position = Vector3(s * 2.6, 2.4, -3.06)
			front.add_child(win)
		var tag := Label3D.new()
		tag.text = label
		tag.font_size = 40
		tag.outline_size = 10
		tag.modulate = Color(0.98, 0.82, 0.55)
		tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		tag.position = Vector3(0, 5.0, -3.1)
		front.add_child(tag)
		var law := {"state": "open"} if kind == "open" else {
				"state": "locked",
				"reason": "the key is with the desk, the desk is closed"}
		Doors.register(front, label, law)


## the fountain: a low bowl + a center jet glow
func _fountain() -> void:
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 3.0
	bm.bottom_radius = 3.2
	bm.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE.stone
	bm.material = mat
	bowl.mesh = bm
	bowl.position = Vector3(0, 0.25, -4.0)
	add_child(bowl)
	var jet := MeshInstance3D.new()
	var jm := CylinderMesh.new()
	jm.top_radius = 0.22
	jm.bottom_radius = 0.4
	jm.height = 2.2
	var jmat := StandardMaterial3D.new()
	jmat.albedo_color = Color(0.7, 0.8, 0.9, 0.7)
	jmat.emission_enabled = true
	jmat.emission = Color(0.5, 0.7, 0.9)
	jmat.emission_energy_multiplier = 0.8
	jmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jm.material = jmat
	jet.mesh = jm
	jet.position = Vector3(0, 1.4, -4.0)
	add_child(jet)
	var l := OmniLight3D.new()
	l.light_color = Color(0.9, 0.8, 0.6)
	l.light_energy = 1.2
	l.omni_range = 10.0
	l.position = Vector3(0, 2.2, -4.0)
	add_child(l)


## the return plane: parked at the plaza's east end
func _plane_home() -> void:
	var p := Node3D.new()
	p.name = "Front_THE_RETURN_PLANE"
	p.position = Vector3(20.0, 0, -10.0)
	add_child(p)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.8, 0.78, 0.74)
	var fus := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.6
	fm.bottom_radius = 1.6
	fm.height = 14.0
	fm.material = white
	fus.mesh = fm
	fus.rotation_degrees = Vector3(0, 0, 90)
	fus.position = Vector3(0, 2.4, 0)
	p.add_child(fus)
	for s in [-1, 1]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(4.0, 0.3, 9.0)
		wm.material = white
		wing.mesh = wm
		wing.position = Vector3(-0.8, 2.0, s * 5.2)
		p.add_child(wing)
	var tag := Label3D.new()
	tag.text = "THE RETURN FLIGHT - BOARD (GRAB)"
	tag.font_size = 30
	tag.outline_size = 10
	tag.modulate = Color(0.55, 0.95, 1.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(3.6, 3.2, 2.2)
	p.add_child(tag)


func _lighting() -> void:
	var env := WorldEnvironment.new()
	env.name = "SecondAir"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = PALETTE.ink
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.12, 0.09, 0.07)
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.3
	e.tonemap_white = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.06, 0.05)
	e.fog_density = 0.007
	env.environment = e
	add_child(env)
	# amber posts around the plaza (the city's warmth)
	for x in [-16.0, 16.0]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.08
		pm.bottom_radius = 0.11
		pm.height = 5.4
		pm.material = StandardMaterial3D.new()
		(pm.material as StandardMaterial3D).albedo_color = \
				Color(0.12, 0.1, 0.09)
		pole.mesh = pm
		pole.position = Vector3(x, 2.7, 4.0)
		add_child(pole)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.5, 0.4, 0.5)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = PALETTE.amber
		hmat.emission_enabled = true
		hmat.emission = PALETTE.amber
		hmat.emission_energy_multiplier = 2.0
		hm.material = hmat
		head.mesh = hm
		head.position = Vector3(x, 5.5, 4.0)
		add_child(head)
		var l := OmniLight3D.new()
		l.light_color = PALETTE.amber
		l.light_energy = 2.0
		l.omni_range = 18.0
		l.position = Vector3(x, 5.2, 4.0)
		add_child(l)


func _markers() -> void:
	_spawn_marker("SpawnStart", Vector3(-4.0, 0.05, 6.0))


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


## THE GIVER (the mission giver of the second hub) + walkers
func _life() -> void:
	var CLS_Local := load("res://scripts/npc/local.gd")
	CLS_Local.place(self, "res://assets/native/cast_michelle.tscn",
			"res://assets/native/ual_baked_michelle.res",
			Vector3(-12.0, 0.05, 8.0), PI, "THE GIVER - THE ANCHOR")
	var CLS_Pedestrian := load("res://scripts/npc/pedestrian.gd")
	for i in 3:
		var p: CharacterBody3D = CLS_Pedestrian.new()
		p.position = Vector3(-14.0 + i * 10.0, 0.05, 2.0)
		add_child(p)
