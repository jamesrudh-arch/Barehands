extends Node3D

## THE DOCKS — AREA 4, BLOCK 3 (rebuild step 9, from 02_MASTER_DESIGN
## §3.4): the far end of the underpass. Piers over dark water, two
## cranes, the container maze, the fish market's open stalls, DOCK
## WAREHOUSE 9 (sealed with Corporation tape - the kidnap arc's
## story door), the empty lot. Fog and water light the area's own
## way: cold sodium, heavy air, almost no neon. The mobile light
## budget: one warm pier lamp + one crane flood + the fill + fog.

const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_MatLib := preload("res://scripts/world/mat_lib.gd")

const PALETTE := {
	"ground": Color(0.075, 0.075, 0.08),
	"plank": Color(0.14, 0.12, 0.10),
	"steel": Color(0.24, 0.26, 0.3),
	"container_a": Color(0.35, 0.16, 0.12),
	"container_b": Color(0.12, 0.25, 0.3),
	"container_c": Color(0.4, 0.34, 0.14),
	"water": Color(0.02, 0.035, 0.05),
	"sodium": Color(1.0, 0.62, 0.28),
	"guide": Color(0.24, 0.86, 0.52),
	"corp": Color(0.9, 0.75, 0.2),
}

const YARD_X := 46.0   # the walkable half-length
const WATER_Z := -18.0  # where the harbour begins (north)
const PIER_X := [-30.0, -12.0, 8.0, 26.0]


func _ready() -> void:
	_ground()
	_water()
	_piers()
	_cranes()
	_container_maze()
	_market()
	_warehouse9()
	_empty_lot()
	_life()
	_lamps()
	_gates()
	Log.info("Docks ready (area=%s spawn=%s)" % [
			Game.area_id, Game.spawn_id])


# --- the ground + the harbour ----------------------------------------------


func _ground() -> void:
	_solid(self, Vector3(YARD_X * 2.0 + 12.0, 0.2, 22.0),
			Vector3(0, -0.1, WATER_Z / 2.0 + 11.0), PALETTE.ground,
			0.92, 0.0, "concrete")
	# the quay edge: a low lip so the yard reads against the water
	_solid(self, Vector3(YARD_X * 2.0 + 12.0, 0.5, 0.6),
			Vector3(0, 0.05, WATER_Z), PALETTE.steel.darkened(0.2),
			0.7, 0.3)


func _water() -> void:
	# the harbour: dark, low-roughness plane - the wet read without
	# reflection probes (mobile budget)
	var water := MeshInstance3D.new()
	water.name = "Harbour"
	var pm := PlaneMesh.new()
	pm.size = Vector2(220.0, 120.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE.water
	mat.roughness = 0.08
	mat.metallic = 0.25
	pm.material = mat
	water.mesh = pm
	water.position = Vector3(0, -0.35, WATER_Z - 55.0)
	add_child(water)
	# the far-shore silhouette massing (depth read, unwalked)
	for i in 4:
		_solid(self, Vector3(30.0, 6.0 + i * 2.5, 14.0),
				Vector3(-70.0 + i * 44.0, (6.0 + i * 2.5) / 2.0,
				WATER_Z - 46.0), PALETTE.steel.darkened(0.35))


## The piers: plank decks out over the water, walkable to the end.
func _piers() -> void:
	for px in PIER_X:
		var pier := Node3D.new()
		pier.name = "Pier_%d" % int(absf(px))
		pier.position = Vector3(px, 0, WATER_Z)
		add_child(pier)
		_solid(pier, Vector3(4.4, 0.35, 16.0), Vector3(0, -0.18, -8.0),
				PALETTE.plank, 0.95)
		for zz in [-3.0, -13.0]:
			for sx in [-1.9, 1.9]:
				var post := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.12
				pm.bottom_radius = 0.12
				pm.height = 2.2
				pm.material = _mat(PALETTE.plank.darkened(0.2))
				post.mesh = pm
				post.position = Vector3(sx, -1.2, zz)
				post.name = "Pile"
				pier.add_child(post)
		# bollards + a coiled rope read at the pier head
		for sx in [-1.4, 1.4]:
			var bollard := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.16
			bm.bottom_radius = 0.2
			bm.height = 0.5
			bm.material = _mat(PALETTE.steel)
			bollard.mesh = bm
			bollard.position = Vector3(sx, 0.3, -15.2)
			bollard.name = "Bollard"
			pier.add_child(bollard)
			var body := StaticBody3D.new()
			body.position = bollard.position
			var cshape := CollisionShape3D.new()
			var s := BoxShape3D.new()
			s.size = Vector3(0.4, 0.5, 0.4)
			cshape.shape = s
			body.add_child(cshape)
			pier.add_child(body)


## Two cranes: mast + jib over the water, the flood on one.
func _cranes() -> void:
	for spec in [[-21.0, true], [17.0, false]]:
		var x: float = spec[0]
		var lit: bool = spec[1]
		var crane := Node3D.new()
		crane.name = "Crane_%d" % int(absf(x))
		crane.position = Vector3(x, 0, WATER_Z - 1.0)
		add_child(crane)
		for sx in [-1.3, 1.3]:
			_solid(crane, Vector3(0.5, 22.0, 0.5), Vector3(sx, 11.0, 0),
					PALETTE.steel, 0.6, 0.5)
			_solid(crane, Vector3(0.4, 0.4, 3.4), Vector3(sx, 0.2, 0),
					PALETTE.steel.darkened(0.1))
		_solid(crane, Vector3(0.8, 0.9, 26.0), Vector3(0, 21.5, -8.0),
				PALETTE.steel, 0.6, 0.5)
		# the hanging hook + cable
		var cable := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = 9.0
		cm.material = _mat(PALETTE.steel.darkened(0.2))
		cable.mesh = cm
		cable.position = Vector3(0, 16.5, -12.0)
		cable.name = "Cable"
		crane.add_child(cable)
		if lit:
			var flood := OmniLight3D.new()
			flood.name = "Flood"
			flood.position = Vector3(0, 20.5, -6.0)
			flood.light_color = Color(0.85, 0.85, 0.75)
			flood.light_energy = 1.3
			flood.omni_range = 26.0
			crane.add_child(flood)


## The container maze: stacked, walkable lanes between the rows.
func _container_maze() -> void:
	var maze := Node3D.new()
	maze.name = "ContainerMaze"
	maze.position = Vector3(-8.0, 0, -6.0)
	add_child(maze)
	var cols := [PALETTE.container_a, PALETTE.container_b,
			PALETTE.container_c]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9  # deterministic: the maze is the same every visit
	for row in 3:
		for i in 6:
			if rng.randf() < 0.25:
				continue  # the gaps that make it a maze
			var sz := Vector3(6.0, 2.6, 2.5)
			var pos := Vector3(-15.0 + i * 6.2, 1.3, -row * 3.4)
			_solid(maze, sz, pos, cols[rng.randi() % 3], 0.75, 0.2,
					"container")
			# some stacks double up (the climbable read)
			if rng.randf() < 0.3:
				_solid(maze, sz, pos + Vector3(0, 2.6, 0),
						cols[rng.randi() % 3], 0.75, 0.2,
						"container")
	_sign(maze, "THE MAZE", Color(0.62, 0.66, 0.8),
			Vector3(0, 3.6, 2.2), 26)


## The fish market: two open stalls (kind "open" - a walk-in awning
## with the counter + crates), sodium-lit.
## THE LIVING WORLD (S5.3 p2): the yard breathes - walkers along
## the harbour band, the fence at the fish market. No lane parade
## here (the docks are working ground, not a street).
func _life() -> void:
	var peds := load("res://scripts/npc/pedestrian.gd") as GDScript
	for i in 3:
		var p: CharacterBody3D = peds.new()
		var x := -30.0 + 22.0 * i + randf_range(-3.0, 3.0)
		p.position = Vector3(x, 0.05, 4.4)
		add_child(p)
	var CLS_Local := load("res://scripts/npc/local.gd")
	CLS_Local.place(self, "res://assets/native/cast_michelle.tscn",
			"res://assets/native/ual_baked_michelle.res",
			Vector3(30.0, 0.05, -1.6), 0.0, "SAL - THE FENCE")


func _market() -> void:
	var market := Node3D.new()
	market.name = "FishMarket"
	market.position = Vector3(28.0, 0, -4.0)
	add_child(market)
	for i in 2:
		var stall := Node3D.new()
		stall.name = "Stall_%d" % i
		stall.position = Vector3(0, 0, -i * 7.0)
		market.add_child(stall)
		# posts + the awning
		for sx in [-2.2, 2.2]:
			_solid(stall, Vector3(0.18, 2.6, 0.18),
					Vector3(sx, 1.3, -1.4), PALETTE.plank.darkened(0.1))
			_solid(stall, Vector3(0.18, 2.6, 0.18),
					Vector3(sx, 1.3, 1.4), PALETTE.plank.darkened(0.1))
		var awn := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(5.2, 0.1, 3.4)
		am.material = _mat(Color(0.1, 0.13, 0.16))
		awn.mesh = am
		awn.position = Vector3(0, 2.65, 0)
		awn.rotation.x = 0.12
		awn.name = "Awning"
		stall.add_child(awn)
		# the counter + the ice crates
		CLS_Kit.place(stall, "kenney_furniture/kitchenBar.glb",
				Vector3(0, 0, 0.4), 0.0)
		for dx in [-1.6, 1.6]:
			CLS_Kit.place(stall, "kenney_furniture/cardboardBoxOpen.glb",
					Vector3(dx, 0, -1.1))
		_sign(stall, "FISH - morning catch", PALETTE.sodium,
				Vector3(0, 3.0, 0), 22)
	Doors.register(market, "THE FISH MARKET", {"state": "open"})
	var lamp := OmniLight3D.new()
	lamp.name = "MarketLamp"
	lamp.position = Vector3(0, 4.0, -3.5)
	lamp.light_color = PALETTE.sodium
	lamp.light_energy = 1.1
	lamp.omni_range = 14.0
	market.add_child(lamp)


## DOCK WAREHOUSE 9: the story door - sealed with Corporation tape.
func _warehouse9() -> void:
	var w := Node3D.new()
	w.name = "Front_DOCK_WAREHOUSE_9"
	w.position = Vector3(-36.0, 0, -12.0)
	add_child(w)
	for sx in [[-4.4, 3.0], [4.4, 3.0]]:
		_solid(w, Vector3(4.4, 6.4, 6.0), Vector3(sx[0], 3.2, -3.0),
				PALETTE.steel.darkened(0.15), 0.8, 0.25)
	_solid(w, Vector3(13.2, 1.2, 6.0), Vector3(0, 7.0, -3.0),
			PALETTE.steel.darkened(0.3), 0.8, 0.25)
	_sign(w, "DOCK WAREHOUSE 9", PALETTE.corp, Vector3(0, 5.6, 0.2), 40)
	# the Corporation tape: an X of hazard stripes over the doors
	for rot in [-0.6, 0.6]:
		var tape := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(5.6, 0.28, 0.05)
		tm.material = _glow(PALETTE.corp, 0.5)
		tape.mesh = tm
		tape.position = Vector3(0, 2.1, 0.14)
		tape.rotation.z = rot
		tape.name = "Tape"
		w.add_child(tape)
	Doors.register(w, "DOCK WAREHOUSE 9", {
			"state": "locked",
			"reason": "SEALED - Corporation tape across the doors (story)",
			"breakable": false, "hits": 0, "stash": 0, "ambush": []})


## The empty lot: a fenced gravel patch, honestly empty (a story
## space the kidnap arc will use).
func _empty_lot() -> void:
	var lot := Node3D.new()
	lot.name = "TheEmptyLot"
	lot.position = Vector3(34.0, 0, -10.0)
	add_child(lot)
	_solid(lot, Vector3(16.0, 0.14, 12.0), Vector3(0, -0.03, 0),
			Color(0.1, 0.09, 0.08), 0.95)
	for side in [[Vector3(16.4, 1.8, 0.2), Vector3(0, 0.9, -6.0)],
			[Vector3(16.4, 1.8, 0.2), Vector3(0, 0.9, 6.0)],
			[Vector3(0.2, 1.8, 12.4), Vector3(-8.2, 0.9, 0)],
			[Vector3(0.2, 1.8, 12.4), Vector3(8.2, 0.9, 0)]]:
		_solid(lot, side[0], side[1], PALETTE.steel.darkened(0.25),
				0.7, 0.3)
	_sign(lot, "THE EMPTY LOT", Color(0.62, 0.66, 0.8),
			Vector3(0, 2.4, 6.4), 24)
	_sign(lot, "the story keeps this space", Color(0.4, 0.42, 0.5),
			Vector3(0, 1.6, 6.4), 18)
	CLS_Kit.place(lot, "kenney_furniture/trashcan.glb",
			Vector3(6.8, 0, 5.0))


# --- lighting + gates -------------------------------------------------------


func _lamps() -> void:
	# the pier lamp: one warm sodium pool at the yard's heart
	var lamp := OmniLight3D.new()
	lamp.name = "PierLamp"
	lamp.position = Vector3(0, 5.0, WATER_Z + 4.0)
	lamp.light_color = PALETTE.sodium
	lamp.light_energy = 1.2
	lamp.omni_range = 24.0
	add_child(lamp)
	# S5.2: sodium lamps over the container maze (the gate read the
	# containers as mid-grey mush - they had no light on them)
	var m1 := OmniLight3D.new()
	m1.name = "MazeLamp_West"
	m1.position = Vector3(-14.0, 5.0, -2.0)
	m1.light_color = PALETTE.sodium
	m1.light_energy = 2.4
	m1.omni_range = 16.0
	add_child(m1)
	var m2 := OmniLight3D.new()
	m2.name = "MazeLamp_East"
	m2.position = Vector3(2.0, 5.0, -7.0)
	m2.light_color = PALETTE.sodium
	m2.light_energy = 2.4
	m2.omni_range = 16.0
	add_child(m2)
	# the visible sources (the gate: 'light feels sourceless') -
	# poles + hot emissive heads at both maze lamps
	for mp in [Vector3(-14.0, 0, -2.0), Vector3(2.0, 0, -7.0)]:
		var pole := MeshInstance3D.new()
		var polem := CylinderMesh.new()
		polem.top_radius = 0.07
		polem.bottom_radius = 0.09
		polem.height = 5.0
		polem.material = _mat(Color(0.08, 0.08, 0.09))
		pole.mesh = polem
		pole.position = mp + Vector3(0, 2.5, 0)
		pole.name = "MazeLampPole_%d" % int(mp.x)
		add_child(pole)
		var head := MeshInstance3D.new()
		var headm := BoxMesh.new()
		headm.size = Vector3(0.5, 0.16, 0.24)
		headm.material = _glow(PALETTE.sodium, 4.0)
		head.mesh = headm
		head.position = mp + Vector3(0, 5.05, 0)
		head.name = "MazeLampHead_%d" % int(mp.x)
		add_child(head)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.1
	pm.height = 5.2
	pm.material = _mat(PALETTE.steel)
	pole.mesh = pm
	pole.position = Vector3(0, 2.6, WATER_Z + 4.0)
	pole.name = "PierLampPole"
	add_child(pole)
	var fill := DirectionalLight3D.new()
	fill.name = "ColdFill"
	fill.rotation_degrees = Vector3(-50, -20, 0)
	fill.light_color = Color(0.22, 0.26, 0.36)
	fill.light_energy = 0.45
	add_child(fill)
	# the docks' air: heavy cold fog - the area's own look
	var env := WorldEnvironment.new()
	env.name = "DocksAir"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.014, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.08, 0.09, 0.12)
	e.ambient_light_energy = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.075, 0.10)
	e.fog_density = 0.016
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.35
	e.tonemap_white = 1.0
	env.environment = e
	add_child(env)


func _gates() -> void:
	# west: the underpass back to the club district
	_spawn_marker("SpawnFromClub", Vector3(-YARD_X + 4.0, 0.05, 4.4))
	# the DEFAULT 'start' spawn (the neighbourhood's probe-caught
	# bug: no SpawnStart = the hero materializes at the raw origin)
	_spawn_marker("SpawnStart", Vector3(-20.0, 0.05, 4.4))
	_gate(Vector3(-YARD_X - 1.0, 1.0, 4.4), "club_district", "from_docks",
			"← THE CLUB DISTRICT - underpass", Color(0.45, 0.8, 0.95))
	# the honest far edge: the harbour (east) - no gate, the water
	_sign(self, "the harbour ends the walk", Color(0.62, 0.66, 0.8),
			Vector3(YARD_X - 2.0, 2.2, 4.4), 22)


func _spawn_marker(id: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = id
	n.position = pos
	add_child(n)


func _gate(pos: Vector3, to: String, spawn: String, text: String,
		col: Color) -> void:
	var g := Node3D.new()
	g.name = "Gate_" + text.substr(0, 12).replace(" ", "_")
	g.position = pos
	add_child(g)
	for sz2 in [-1.6, 1.6]:
		_solid(g, Vector3(0.4, 3.4, 0.4), Vector3(0, 1.7, sz2),
				PALETTE.steel)
	_solid(g, Vector3(0.4, 0.4, 3.6), Vector3(0, 3.6, 0), PALETTE.steel)
	_sign(g, text, col, Vector3(0, 3.1, 0.3), 32)
	if to != "":
		var zone := Area3D.new()
		zone.name = "GateZone"
		zone.position = Vector3(0, 1.0, 0)
		var col2 := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 3.0, 2.8)
		col2.shape = shape
		zone.add_child(col2)
		g.add_child(zone)
		zone.body_entered.connect(func(b):
			if b.is_in_group("player") and not Game._fading \
					and not b.get_meta("riding", false):
				Game.travel(to, spawn))


# --- small builders ---------------------------------------------------------


func _solid(parent: Node, sz: Vector3, pos: Vector3, col: Color,
		rough := 0.9, metal := 0.0, mat_name := "") -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cshape := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = sz
	cshape.shape = s
	body.add_child(cshape)
	parent.add_child(body)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	var mat: StandardMaterial3D
	if mat_name != "":
		mat = CLS_MatLib.surface(mat_name, sz)
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = rough
		mat.metallic = metal
	bm.material = mat
	m.mesh = bm
	m.position = pos
	parent.add_child(m)


func _sign(parent: Node3D, text: String, col: Color, pos: Vector3,
		size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.font_size = size
	l.outline_size = 10
	l.outline_modulate = Color(0.01, 0.015, 0.04)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.name = "Sign_" + text.substr(0, 14).replace(" ", "_")
	parent.add_child(l)
	return l


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
