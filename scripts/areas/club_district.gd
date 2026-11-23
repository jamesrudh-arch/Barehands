extends Node3D

## THE CLUB DISTRICT — AREA 3, BLOCK 2 (rebuild step 9, from
## 02_MASTER_DESIGN §3.3): the main avenue reached through the
## neighbourhood's east gate. THE VELVET ROOM with its queue, HOTEL
## AURORA's lobby and NEON 9 north; IRON PALM GYM and the Mechanic's
## steel shutter south; the parking structure's chained ramp; the
## crossing with its light; two side streets reading toward rooftops
## (the parkour layer arrives with the systems pass). The densest
## neon on the mobile budget: emissive practicals + two real lights
## + the fill - the avenue GLOWS without a lamp per post.

const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_Vehicle := preload("res://scripts/world/vehicle.gd")
const CLS_MatLib := preload("res://scripts/world/mat_lib.gd")

const PALETTE := {
	"road": Color(0.05, 0.052, 0.065),
	"walk": Color(0.12, 0.12, 0.14),
	"facade": Color(0.09, 0.09, 0.115),
	"facade2": Color(0.12, 0.10, 0.13),
	"trim": Color(0.28, 0.3, 0.36),
	"magenta": Color(0.95, 0.15, 0.5),
	"cyan": Color(0.15, 0.85, 0.88),
	"sodium": Color(1.0, 0.62, 0.28),
	"guide": Color(0.24, 0.86, 0.52),
}

const STREET_X := 58.0
const FRONT_Z := 7.4

## The north fronts: label, x, kind, law.
## open = walk-in interior; locked = the door law with its reason.
const NORTH := [
	["THE VELVET ROOM", -40.0, "open", "club", Color(0.85, 0.15, 0.3)],
	["HOTEL AURORA", -22.0, "open", "hotel", Color(0.35, 0.7, 1.0)],
	["NEON 9", 26.0, "locked", "", Color(0.15, 0.85, 0.8)],
	["THE PARKING STRUCTURE", 44.0, "locked", "", Color(0.7, 0.4, 0.95)],
]

const SOUTH := [
	["IRON PALM GYM", -34.0, "open", "gym", Color(0.95, 0.65, 0.1)],
	["THE MECHANIC", 36.0, "locked", "", Color(0.45, 0.8, 0.95)],
]

const REASONS := {
	"NEON 9": "MEMBERS ONLY - the list closes at midnight",
	"THE PARKING STRUCTURE": "ramp chained - levels closed till the systems pass",
	"THE MECHANIC": "STEEL SHUTTER - the lift's been dead a month",
}

const BREAKABLE := ["NEON 9"]


func _ready() -> void:
	_ground()
	_fronts(NORTH, -1.0)
	_fronts(SOUTH, 1.0)
	_side_streets()
	_crossing()
	_queue_and_props()
	_parked()
	_muscle()
	_life()
	_skyline()
	_lamps()
	_gates()
	Log.info("Club district ready (area=%s spawn=%s)" % [
			Game.area_id, Game.spawn_id])


## The street's muscle: two by the underpass (the docks' block is
## contested ground - the story says someone is always watching it).
func _muscle() -> void:
	var script := load("res://scripts/npc/enemy.gd") as GDScript
	for spec in [[Vector3(50.0, 0.05, -3.0), 0.6], [Vector3(54.0, 0.05, 2.0), -0.9]]:
		var e: CharacterBody3D = script.new()
		e.position = spec[0]
		e.rotation.y = spec[1]
		add_child(e)


## The avenue's parked cars: a sedan by the curb, the taxi at the
## hotel (both drivable - B at the door).
func _parked() -> void:
	CLS_Vehicle.spawn(self, "sedan", Vector3(-12.0, 0.05, 3.2), PI / 2.0)
	CLS_Vehicle.spawn(self, "taxi", Vector3(-22.0, 0.05, -3.2), -PI / 2.0)


# --- the avenue ------------------------------------------------------------


func _ground() -> void:
	# THE WORLD APRON: a huge dark floor under everything - a
	# drivable city must have no void to fall through (the first
	# drive test steered off the road through a side street and the
	# car fell for five seconds before anyone noticed)
	_solid(self, Vector3(420.0, 8.0, 420.0), Vector3(0, -4.2, 0),
			Color(0.03, 0.031, 0.04), 0.95)
	_solid(self, Vector3(STREET_X * 2.0 + 10.0, 0.2, 10.0),
			Vector3(0, -0.1, 0), PALETTE.road, 0.14, 0.05)
	for sz in [-1.0, 1.0]:
		_solid(self, Vector3(STREET_X * 2.0 + 10.0, 0.16, 2.2),
				Vector3(0, -0.08, sz * 5.6), PALETTE.walk, 0.85)


## Fronts on one side (side -1 = north, +1 = south): the facade row.
## THE LIVING WORLD (S5.3 p2): the club strip breathes - the
## same pooled walkers, the lane parade, and the fixer at the
## door the story keeps pointing at.
func _life() -> void:
	var peds := load("res://scripts/npc/pedestrian.gd") as GDScript
	for i in 5:
		var p: CharacterBody3D = peds.new()
		var x := -44.0 + 17.0 * i + randf_range(-4.0, 4.0)
		p.position = Vector3(x, 0.05,
				5.0 if i % 2 == 0 else -5.0)
		add_child(p)
	var CLS_Traffic := load("res://scripts/world/traffic.gd")
	CLS_Traffic.fill(self, 2)
	var CLS_Local := load("res://scripts/npc/local.gd")
	CLS_Local.place(self, "res://assets/native/cast_michelle.tscn",
			"res://assets/native/ual_baked_michelle.res",
			Vector3(-41.5, 0.05, -5.0), 0.0, "VESPER - THE VELVET ROOM")
	CLS_Local.place(self, "res://assets/native/cast_soldier.tscn",
			"res://assets/native/ual_baked_soldier.res",
			Vector3(-35.5, 0.05, 5.0), PI, "TONY - IRON PALM GYM")


## THE SKYLINE (S5.2p3): tenement silhouettes behind the strip -
## dark massing with a few lit windows, so the street reads as a
## city block and not a stage set against the void.
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4751
	for spec in [[-16.0, 4], [16.0, 3]]:
		var zz: float = spec[0]
		for b in spec[1]:
			var w := rng.randf_range(16.0, 26.0)
			var h := rng.randf_range(12.0, 22.0)
			var x: float = -52.0 + float(b) * 30.0 \
				+ rng.randf_range(-4.0, 4.0)
			_solid(self, Vector3(w, h, 9.0), Vector3(x, h / 2.0, zz),
					Color(0.045, 0.042, 0.055), 0.95, 0.0)
			# the lit windows: a sparse grid of warm dots on the
			# street face (emissive, zero lights)
			for r in rng.randi_range(3, 5):
				for c in rng.randi_range(3, 4):
					if rng.randf() < 0.55:
						continue
					var dot := MeshInstance3D.new()
					var dm := BoxMesh.new()
					dm.size = Vector3(0.9, 1.2, 0.08)
					dm.material = _glow(Color(1.0, 0.78, 0.5),
							rng.randf_range(0.35, 0.8))
					dot.mesh = dm
					dot.position = Vector3(
							x - w / 2.0 + 2.0 + c * (w - 3.0) / 4.0,
							2.5 + r * (h - 4.0) / 6.0,
							zz - signf(zz) * 4.56)
					add_child(dot)


## A textured BRICK solid (S5.2p3): _solid's mat path uses the
## floor-tiling convention (one axis dominates); walls need the
## box-aware per-axis scale or the courses come out giant.
func _brick(parent: Node, sz: Vector3, pos: Vector3) -> void:
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
	bm.material = CLS_MatLib.surface_box("brick", sz)
	m.mesh = bm
	m.position = pos
	parent.add_child(m)


func _fronts(table: Array, side: float) -> void:
	for entry in table:
		var label: String = entry[0]
		var x: float = entry[1]
		var kind: String = entry[2]
		var glow: Color = entry[3]
		var front := Node3D.new()
		front.name = "Front_" + label.replace(" ", "_").replace("'", "")
		front.position = Vector3(x, 0, side * FRONT_Z)
		front.rotation.y = PI if side > 0 else 0.0
		add_child(front)
		var law := {"state": "locked", "reason": REASONS.get(label, ""),
				"breakable": label in BREAKABLE, "hits": 3, "stash": 90,
				"ambush": []}
		if kind == "open":
			_open_front(front, label, glow, _kind_of(label))
			law = {"state": "open"}
		else:
			_shut_front(front, label, glow)
		Doors.register(front, label, law)


func _kind_of(label: String) -> String:
	match label:
		"THE VELVET ROOM":
			return "club"
		"HOTEL AURORA":
			return "hotel"
		"IRON PALM GYM":
			return "gym"
	return "store"


func _open_front(front: Node3D, label: String, glow: Color,
		kind: String) -> void:
	# S5.2p3: brick massing + the split-band doorway (street side is
	# rel +Z here - the south fronts are rotated PI, the north face
	# the street at +Z natively)
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_brick(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5))
	_brick(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5))
	var room := Node3D.new()
	room.name = "Room"
	room.position = Vector3(0, 0, -1.5)
	front.add_child(room)
	_solid(room, Vector3(9.6, 0.2, 7.0), Vector3(0, -0.08, -3.5),
			Color(0.13, 0.11, 0.12))
	_solid(room, Vector3(9.6, 0.2, 7.0), Vector3(0, 5.2, -3.5),
			PALETTE.facade.darkened(0.3))
	for wall in [[Vector3(0.3, 5.2, 7.0), Vector3(-4.65, 2.6, -3.5)],
			[Vector3(0.3, 5.2, 7.0), Vector3(4.65, 2.6, -3.5)],
			[Vector3(9.6, 5.2, 0.3), Vector3(0, 2.6, -6.85)]]:
		_solid(room, wall[0], wall[1], PALETTE.facade2)
	for wx in [-2.45, 2.45]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.1, 2.3, 0.12)
		bm.material = _glow(glow, 0.7)
		band.mesh = bm
		band.position = Vector3(wx, 2.5, 0.08)
		band.name = "WindowBand"
		front.add_child(band)
	var interior := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(2.4, 2.7, 0.1)
	im.material = _glow(Color(1.0, 0.72, 0.42), 0.75)
	interior.mesh = im
	interior.position = Vector3(0, 1.55, -0.02)
	interior.name = "DoorGlow"
	front.add_child(interior)
	for jx in [-1.55, 1.55]:
		_solid(front, Vector3(0.34, 4.9, 0.7), Vector3(jx, 2.45, 0.15),
				Color(0.07, 0.06, 0.08))
	_solid(front, Vector3(3.7, 0.55, 0.7), Vector3(0, 4.95, 0.15),
			Color(0.07, 0.06, 0.08))
	var spill := MeshInstance3D.new()
	var sp := QuadMesh.new()
	sp.size = Vector2(2.6, 1.9)
	sp.material = _glow(Color(1.0, 0.72, 0.45), 0.32)
	spill.mesh = sp
	spill.rotation.x = -PI / 2.0
	spill.position = Vector3(0, 0.03, 1.15)
	spill.name = "DoorSpill"
	front.add_child(spill)
	_sign(front, label, glow, Vector3(0, 4.8, 0.2), 42)
	_interior(room, kind, glow)
	var lamp := OmniLight3D.new()
	lamp.name = "RoomLight"
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 3.6, -3.5)
	room.add_child(lamp)


func _interior(room: Node3D, kind: String, glow: Color) -> void:
	match kind:
		"club":
			# the Velvet Room: velvet booths, the long bar, the stage
			CLS_Kit.place(room, "kenney_furniture/kitchenBar.glb",
					Vector3(-2.8, 0, -5.6), 0.0)
			for dx in [-3.4, -1.6, 0.2, 2.0]:
				CLS_Kit.place(room, "kenney_furniture/tableRound.glb",
						Vector3(dx, 0, -2.4))
				CLS_Kit.place(room, "kenney_furniture/chairRounded.glb",
						Vector3(dx + 0.8, 0, -1.6), PI)
			# the stage: a riser + the back-band glow
			_solid(room, Vector3(5.2, 0.35, 3.2), Vector3(2.0, 0.17, -5.2),
					Color(0.2, 0.05, 0.1), 0.7)
			var stage_glow := MeshInstance3D.new()
			var sg := BoxMesh.new()
			sg.size = Vector3(5.0, 1.6, 0.12)
			sg.material = _glow(Color(0.85, 0.15, 0.4), 1.1)
			stage_glow.mesh = sg
			stage_glow.position = Vector3(2.0, 1.6, -6.6)
			stage_glow.name = "StageGlow"
			room.add_child(stage_glow)
			_sign(room, "the back room answers trust",
					Color(0.62, 0.66, 0.8), Vector3(-4.0, 2.0, -6.6), 20)
		"hotel":
			# the lobby: the desk, the waiting seats, the board
			CLS_Kit.place(room, "kenney_furniture/desk.glb",
					Vector3(0, 0, -5.0), 0.0)
			CLS_Kit.place(room, "kenney_furniture/chairDesk.glb",
					Vector3(1.2, 0, -4.2), PI)
			for dx in [-3.2, -1.8]:
				CLS_Kit.place(room, "kenney_furniture/chairRounded.glb",
						Vector3(dx, 0, -2.0))
			CLS_Kit.place(room, "kenney_furniture/cabinetTelevision.glb",
					Vector3(3.6, 0, -5.8), -PI / 2.0)
			_sign(room, "ROOMS BY THE WEEK", Color(0.35, 0.7, 1.0),
					Vector3(0, 3.4, -6.5), 26)
		"gym":
			# IRON PALM: the mat floor read, the rack, the ring corner
			_solid(room, Vector3(8.8, 0.08, 6.4), Vector3(0, 0.05, -3.4),
					Color(0.16, 0.13, 0.1), 0.95)
			for dx in [-3.6, -2.4, 3.2]:
				CLS_Kit.place(room, "kenney_furniture/cardboardBoxClosed.glb",
						Vector3(dx, 0, -5.9))
			CLS_Kit.place(room, "kenney_furniture/lampSquareFloor.glb",
					Vector3(4.0, 0, -5.6))
			_sign(room, "walk-in hours: after dark",
					Color(0.95, 0.65, 0.1), Vector3(-3.0, 2.2, -6.6), 22)


func _shut_front(front: Node3D, label: String, glow: Color) -> void:
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_brick(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5))
	_brick(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5))
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 2.0, 0.12)
	bm.material = _glow(glow, 1.6)
	band.mesh = bm
	band.position = Vector3(0, 2.4, 0.02)
	band.name = "WindowBand"
	front.add_child(band)
	_sign(front, label, glow, Vector3(0, 4.7, 0.2), 38)
	# (doors.gd builds + owns the leaf on the shut front: plank for
	# the breakable, steel for the rest - one door authority)


# --- the streets between the fronts ----------------------------------------


func _side_streets() -> void:
	# two gaps in the south row reading toward rooftops: the alley
	# mouths with their massing (the parkour layer is the systems pass)
	for x in [-8.0, 14.0]:
		var mouth := Node3D.new()
		mouth.name = "SideStreet_%d" % int(x)
		mouth.position = Vector3(x, 0, FRONT_Z)
		add_child(mouth)
		_solid(mouth, Vector3(4.0, 0.16, 12.0), Vector3(0, -0.08, 6.0),
				PALETTE.walk, 0.85)
		for side in [-1.0, 1.0]:
			_solid(mouth, Vector3(0.4, 6.5, 12.0),
					Vector3(side * 2.2, 3.25, 6.0), PALETTE.facade2)
		# the silhouette massing behind (unwalked, unlit - depth read)
		for i in 3:
			_solid(mouth, Vector3(4.0 - i * 0.7, 9.0 + i * 3.0, 4.0),
					Vector3(0, (9.0 + i * 3.0) / 2.0, 12.0 + i * 5.0),
					PALETTE.facade.darkened(0.1 * i))
		_sign(mouth, "side street", Color(0.62, 0.66, 0.8),
				Vector3(0, 3.0, 0.4), 24)


func _crossing() -> void:
	# the crossing at the avenue's centre: the zebra + the light
	var cross := Node3D.new()
	cross.name = "TheCrossing"
	cross.position = Vector3(0, 0, 0)
	add_child(cross)
	for i in 6:
		var stripe := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.7, 0.02, 8.0)
		m.material = _mat(Color(0.75, 0.76, 0.8))
		stripe.mesh = m
		stripe.position = Vector3(-2.1 + i * 0.85, 0.02, 0)
		stripe.name = "Stripe_%d" % i
		cross.add_child(stripe)
	for sx in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07
		pm.bottom_radius = 0.07
		pm.height = 4.2
		pm.material = _mat(PALETTE.trim)
		pole.mesh = pm
		pole.position = Vector3(sx * 4.6, 2.1, 4.2)
		pole.name = "Pole_%s" % ("L" if sx < 0 else "R")
		cross.add_child(pole)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.34, 0.9, 0.3)
		hm.material = _glow(Color(0.2, 0.9, 0.35), 1.4)
		head.mesh = hm
		head.position = Vector3(sx * 4.6, 4.4, 4.2)
		head.name = "Head_%s" % ("L" if sx < 0 else "R")
		cross.add_child(head)
	_sign(cross, "THE CROSSING", Color(0.62, 0.66, 0.8),
			Vector3(0, 3.4, -6.4), 24)


func _queue_and_props() -> void:
	# the Velvet Room's queue: rope posts + a few waiting silhouettes
	# (simple stands now; the crowd pass gives them people)
	var queue := Node3D.new()
	queue.name = "VelvetQueue"
	# probe-caught: the queue used to sit at +FRONT_Z-1.2 - ACROSS
	# the street on the gym's block; the club's own curb is north
	queue.position = Vector3(-40.0, 0, -(FRONT_Z - 1.2))
	add_child(queue)
	for i in 5:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.07
		pm.height = 1.0
		pm.material = _mat(Color(0.1, 0.1, 0.12))
		post.mesh = pm
		post.position = Vector3(1.2 + i * 0.9, 0.5, i * 0.35)
		post.name = "Post_%d" % i
		queue.add_child(post)
		# the queue-goers: tinted locals along the rope (S5.2p3 -
		# the 'sparse' read's cheapest fix is people)
		if i == 1 or i == 2 or i == 4:
			var CLS_Local := load("res://scripts/npc/local.gd")
			var tints := [Color(0.55, 0.5, 0.62), Color(0.35, 0.45, 0.55),
					Color(0.6, 0.42, 0.3)]
			CLS_Local.place(queue,
					"res://assets/native/cast_michelle.tscn",
					"res://assets/native/ual_baked_michelle.res",
					Vector3(0.55 + i * 0.95, 0, 0.55 + i * 0.35),
					-PI / 2.0, "",
					tints[[1, 2, 4].find(i)])
		var body := StaticBody3D.new()
		body.position = post.position
		var cshape := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.24, 1.0, 0.24)
		cshape.shape = s
		body.add_child(cshape)
		queue.add_child(body)
	_sign(queue, "the queue forms before midnight",
			Color(0.85, 0.15, 0.3), Vector3(2.8, 1.6, 0.6), 20)
	# street furniture along the avenue
	for x in [-16.0, 8.0, 30.0]:
		CLS_Kit.place(self, "kenney_furniture/trashcan.glb",
				Vector3(x, 0, 5.4))
	for x in [-28.0, 20.0]:
		CLS_Kit.place(self, "kenney_roads/construction-barrier.glb",
				Vector3(x, 0, -5.4))


# --- lighting + gates -------------------------------------------------------


func _lamps() -> void:
	# two real lights on the avenue + the neon fills + the city fill
	var a := OmniLight3D.new()
	a.name = "AvenueLight_West"
	a.position = Vector3(-20.0, 5.4, 0.0)
	a.light_color = Color(0.9, 0.45, 0.75)
	a.light_energy = 2.6
	a.omni_range = 26.0
	add_child(a)
	var b := OmniLight3D.new()
	b.name = "AvenueLight_East"
	b.position = Vector3(20.0, 5.4, 0.0)
	b.light_color = Color(0.35, 0.8, 0.9)
	b.light_energy = 2.6
	b.omni_range = 26.0
	# S5.2: two more down the avenue - a receding lit line (the gate
	# read 'too dark, nothing anchors the lift')
	var c2 := OmniLight3D.new()
	c2.name = "AvenueLight_FarWest"
	c2.position = Vector3(-48.0, 5.4, 0.0)
	c2.light_color = Color(0.9, 0.45, 0.75)
	c2.light_energy = 2.2
	c2.omni_range = 24.0
	add_child(c2)
	var d2 := OmniLight3D.new()
	d2.name = "AvenueLight_FarEast"
	d2.position = Vector3(48.0, 5.4, 0.0)
	d2.light_color = Color(0.35, 0.8, 0.9)
	d2.light_energy = 2.2
	d2.omni_range = 24.0
	add_child(d2)
	add_child(b)
	# the avenue's wet pools + smears (S5.2: the gate read 'no light
	# pooling on the street') - one pool + one smear per avenue light
	for lx in [-48.0, -20.0, 20.0, 48.0]:
		var warm: bool = lx < 0.0
		var pcol := Color(0.9, 0.45, 0.75) if warm \
				else Color(0.35, 0.8, 0.9)
		var pool := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(7.5, 6.0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(pcol.r, pcol.g, pcol.b, 0.6)
		pmat.emission_enabled = true
		pmat.emission = pcol
		pmat.emission_energy_multiplier = 1.6
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.material = pmat
		pool.mesh = pm
		pool.rotation = Vector3(-PI / 2.0, 0, 0)
		pool.position = Vector3(lx, 0.02, 1.0)
		pool.name = "AvenuePool_%d" % int(lx)
		add_child(pool)
		var smear := MeshInstance3D.new()
		var sm := QuadMesh.new()
		sm.size = Vector2(2.6, 10.0)
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(pcol.r, pcol.g, pcol.b, 0.15)
		smat.emission_enabled = true
		smat.emission = pcol
		smat.emission_energy_multiplier = 0.9
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.material = smat
		smear.mesh = sm
		smear.rotation = Vector3(-PI / 2.0, 0, 0)
		smear.position = Vector3(lx, 0.025, -2.5)
		smear.name = "AvenueSmear_%d" % int(lx)
		add_child(smear)
	var fill := DirectionalLight3D.new()
	fill.name = "CityFill"
	fill.rotation_degrees = Vector3(-55, 30, 0)
	fill.light_color = Color(0.26, 0.24, 0.4)
	fill.light_energy = 0.75
	add_child(fill)
	# the warm haze: the district's own air (fog volume read, mobile)
	var env := WorldEnvironment.new()
	env.name = "DistrictAir"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.012, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.10, 0.09, 0.15)
	e.ambient_light_energy = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.07, 0.05, 0.11)
	e.fog_density = 0.008
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.3
	e.tonemap_white = 1.0
	env.environment = e
	add_child(env)


func _gates() -> void:
	# the DEFAULT 'start' spawn (probe-caught law: without it the
	# hero materializes at the raw origin)
	_spawn_marker("SpawnStart", Vector3(-30.0, 0.05, 2.6))

	# west: back to the neighbourhood
	_spawn_marker("SpawnFromNeighbourhood", Vector3(-STREET_X + 4.0, 0.05, 4.4))
	_gate(Vector3(-STREET_X - 1.0, 1.0, 4.4), "neighbourhood",
			"from_club", "← THE NEIGHBOURHOOD", Color(0.55, 0.95, 1.0))
	# east: the underpass mouth to the docks
	_spawn_marker("SpawnFromDocks", Vector3(STREET_X - 4.0, 0.05, 4.4))
	_gate(Vector3(STREET_X + 1.0, 1.0, 4.4), "docks", "from_club",
			"THE DOCKS - underpass →", Color(0.45, 0.8, 0.95))


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
				PALETTE.trim)
	_solid(g, Vector3(0.4, 0.4, 3.6), Vector3(0, 3.6, 0), PALETTE.trim)
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
	else:
		_solid(g, Vector3(0.3, 3.2, 2.8), Vector3(0, 1.6, 0),
				Color(0.16, 0.17, 0.2))


# --- small builders ---------------------------------------------------------


func _solid(parent: Node, sz: Vector3, pos: Vector3, col: Color,
		rough := 0.9, metal := 0.0) -> void:
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
	var mat := StandardMaterial3D.new()
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
