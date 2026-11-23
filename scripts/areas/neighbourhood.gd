extends Node3D

## THE NEIGHBOURHOOD — AREA 2, BLOCK 1 (rebuild step 6, from
## 02_MASTER_DESIGN §3.2): the street reached through the home's yard
## gate. Eight named fronts on the north side (three OPEN with real
## walk-in interiors: MAMA SUN'S NOODLES, THE RAIN GLASS, the corner
## store), housing and the newsstand south, two alleys, a small
## plaza, the subway entrance mouth, vending machines - and every
## shut front answers THE DOOR LAW (world/doors.gd: try, reason,
## break). Night sodium-and-neon per the art direction: the light
## BUDGET is mobile (a few real lights + emissive practicals + the
## city fill), never a lamp per post.

const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_Vehicle := preload("res://scripts/world/vehicle.gd")

const PALETTE := {
	"road": Color(0.055, 0.058, 0.07),
	"walk": Color(0.13, 0.13, 0.15),
	"facade": Color(0.11, 0.11, 0.13),
	"facade2": Color(0.14, 0.12, 0.11),
	"trim": Color(0.3, 0.32, 0.36),
	"sodium": Color(1.0, 0.62, 0.28),
	"guide": Color(0.24, 0.86, 0.52),
}

const STREET_X := 62.0   # the walkable half-length
const FRONT_Z := 7.2     # where the fronts stand
const PLAZA_X0 := 34.0
const PLAZA_X1 := 50.0

## The north fronts: label, x, kind, door law.
## open = a real doorway + interior; locked = the law with its reason.
const NORTH := [
	["MAMA SUN'S NOODLES", -42.0, "open", "noodle", Color(1.0, 0.62, 0.2)],
	["THE BARBER", -30.0, "locked", "", Color(0.4, 0.8, 0.95)],
	["THE PAWN DESK", -18.0, "locked", "", Color(0.85, 0.75, 0.3)],
	["THE RAIN GLASS", -6.0, "open", "bar", Color(0.95, 0.7, 0.35)],
	["CORNER STORE", 6.0, "open", "store", Color(0.3, 0.95, 0.6)],
	["THE LAUNDROMAT", 18.0, "locked", "", Color(0.5, 0.6, 1.0)],
	["THE CLINIC", 30.0, "locked", "", Color(0.9, 0.25, 0.25)],
]

## locked reasons in plain street words (R16: legible, honest)
const REASONS := {
	"THE BARBER": "chair's busted - back Tuesday",
	"THE PAWN DESK": "shuttered - the grille is steel",
	"THE LAUNDROMAT": "out of order - the dryers ate a dime",
	"THE CLINIC": "DEBT=DEATH - the sign says the rest",
	"THE NEWSSTAND": "gone home - papers sold out",
}

## the breakable ones (wood, 3 hits, a stash behind)
const BREAKABLE := ["THE LAUNDROMAT", "THE DAILIES"]


func _ready() -> void:
	_ground()
	_fronts_north()
	_fronts_south()
	_plaza()
	_subway()
	_vending()
	_lamps()
	_parked()
	_gates()
	Log.info("Neighbourhood ready (area=%s spawn=%s, %d fronts)" % [
			Game.area_id, Game.spawn_id, Doors.door_list().size()])


## A sedan parked by the plaza (drivable - the street's one car
## until the traffic pass fills the lanes).
func _parked() -> void:
	CLS_Vehicle.spawn(self, "sedan", Vector3(40.0, 0.05, -3.2), -PI / 2.0)


# --- the ground: road + sidewalks -----------------------------------------


func _ground() -> void:
	# THE WORLD APRON: no voids to fall through, ever (the vehicle
	# step's law - a drivable city has ground everywhere)
	_solid(self, Vector3(420.0, 8.0, 420.0), Vector3(0, -4.2, 0),
			Color(0.03, 0.031, 0.04), 0.95)
	# the road: dark, low-roughness (the wet-night read without a
	# reflection probe per street - mobile budget). COLLIDERS FIRST:
	# a mesh-only street is a hole - the whole door block fell
	# through it (the DBG line caught y=-5.35 under the sidewalk).
	_solid(self, Vector3(STREET_X * 2.0 + 8.0, 0.2, 8.0),
			Vector3(0, -0.1, 0), PALETTE.road, 0.18, 0.1)
	# the sidewalk strips both sides
	for sz in [-1.0, 1.0]:
		_solid(self, Vector3(STREET_X * 2.0 + 8.0, 0.24, 3.4),
				Vector3(0, -0.08, sz * 5.7), PALETTE.walk, 0.85, 0.0)
	# lane dashes down the middle (emissive-less, just lighter)
	for i in range(-12, 13):
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(1.6, 0.02, 0.12)
		dm.material = _mat(Color(0.5, 0.5, 0.42))
		dash.mesh = dm
		dash.position = Vector3(i * 5.0, 0.011, 0)
		add_child(dash)
	# puddles: the low-roughness pools that read as wet night
	for p in [Vector3(-24, 0.012, 1.6), Vector3(10, 0.012, -2.2),
			Vector3(44, 0.012, 1.2)]:
		var pool := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.3
		pm.bottom_radius = 1.3
		pm.height = 0.01
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.08, 0.09, 0.12)
		pmat.roughness = 0.05
		pmat.metallic = 0.4
		pm.material = pmat
		pool.mesh = pm
		pool.position = p
		pool.scale = Vector3(1.0, 1.0, 0.6)
		add_child(pool)


# --- the north fronts ------------------------------------------------------


func _fronts_north() -> void:
	for entry in NORTH:
		var label: String = entry[0]
		var x: float = entry[1]
		var kind: String = entry[2]
		var glow: Color = entry[4]
		if kind == "open":
			_open_front(label, x, glow, entry[3])
		else:
			_shut_front(label, x, glow)
	# the alley mouths: gaps with dressing between the fronts
	for x in [-36.0, 24.0]:
		_alley(x)


## An OPEN front: a code facade with a REAL doorway + the interior
## room behind it, lit warm. The door law answers OPEN.
func _open_front(label: String, x: float, glow: Color,
		kind: String) -> void:
	var front := Node3D.new()
	front.name = "Front_" + label.replace("'", "").replace(" ", "_")
	front.position = Vector3(x, 0, FRONT_Z)
	add_child(front)
	# the facade mass: two wall slabs + a header, the doorway between
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_solid(front, Vector3(3.4, 5.2, 3.0),
				Vector3(sx[0], 2.6, -1.5), PALETTE.facade)
	_solid(front, Vector3(9.6, 1.4, 3.0), Vector3(0, 5.9, -1.5),
			PALETTE.facade2)
	# the interior shell (the room the doorway leads into)
	var room := Node3D.new()
	room.name = "Room"
	room.position = Vector3(0, 0, -1.5)
	front.add_child(room)
	_solid(room, Vector3(9.6, 0.2, 7.0), Vector3(0, -0.08, -3.5),
			Color(0.15, 0.13, 0.12))
	_solid(room, Vector3(9.6, 0.2, 7.0), Vector3(0, 5.0, -3.5),
			PALETTE.facade.darkened(0.3))
	_solid(room, Vector3(0.3, 5.0, 7.0), Vector3(-4.65, 2.5, -3.5),
			PALETTE.facade2)
	_solid(room, Vector3(0.3, 5.0, 7.0), Vector3(4.65, 2.5, -3.5),
			PALETTE.facade2)
	_solid(room, Vector3(9.6, 5.0, 0.3), Vector3(0, 2.5, -6.85),
			PALETTE.facade2)
	# the window band: emissive, the shop's glow onto the street
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 2.2, 0.12)
	bm.material = _glow(glow, 0.65)
	band.mesh = bm
	band.position = Vector3(0, 2.4, 0.02)
	band.name = "WindowBand"
	front.add_child(band)
	# the neon sign
	_sign(front, label, glow, Vector3(0, 4.6, 0.2), 40)
	# the interior dressing per kind + its warm light
	_interior_dressing(room, kind)
	var lamp := OmniLight3D.new()
	lamp.name = "RoomLight"
	lamp.light_color = Color(1.0, 0.8, 0.58)
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 3.4, -3.5)
	room.add_child(lamp)
	# (no threshold box: a 6 cm lip blocks a capsule with no step-up -
	# the doorway reads by the glow band alone)
	Doors.register(front, label, {"state": "open"})


func _interior_dressing(room: Node3D, kind: String) -> void:
	match kind:
		"noodle":
			CLS_Kit.place(room, "kenney_furniture/kitchenBar.glb",
					Vector3(-3.0, 0, -4.4), PI)
			for dx in [-1.4, 0.6, 2.4]:
				CLS_Kit.place(room, "kenney_furniture/tableRound.glb",
						Vector3(dx, 0, -2.2))
				CLS_Kit.place(room, "kenney_furniture/chair.glb",
						Vector3(dx + 0.8, 0, -1.4), PI)
			CLS_Kit.place(room, "kenney_furniture/trashcan.glb",
					Vector3(3.9, 0, -5.8))
		"bar":
			CLS_Kit.place(room, "kenney_furniture/kitchenBar.glb",
					Vector3(-2.4, 0, -5.6), 0.0)
			for dx in [-0.4, 1.6]:
				CLS_Kit.place(room, "kenney_furniture/stoolBar.glb",
						Vector3(dx, 0, -4.6))
			CLS_Kit.place(room, "kenney_furniture/tableCross.glb",
					Vector3(2.6, 0, -2.4), 0.3)
			CLS_Kit.place(room, "kenney_furniture/chairRounded.glb",
					Vector3(3.4, 0, -1.6), -1.2)
			CLS_Kit.place(room, "kenney_furniture/lampSquareFloor.glb",
					Vector3(4.0, 0, -5.6))
		"store":
			for dz in [-2.0, -4.0]:
				CLS_Kit.place(room, "kenney_furniture/bookcaseOpen.glb",
						Vector3(-3.6, 0, dz), PI / 2.0)
				CLS_Kit.place(room, "kenney_furniture/bookcaseClosed.glb",
						Vector3(3.6, 0, dz), -PI / 2.0)
			CLS_Kit.place(room, "kenney_furniture/desk.glb",
					Vector3(0, 0, -5.6), PI)
			CLS_Kit.place(room, "kenney_furniture/cabinetTelevision.glb",
					Vector3(4.0, 0, -6.2), PI)
		_:
			CLS_Kit.place(room, "kenney_furniture/desk.glb",
					Vector3(0, 0, -4.0), PI)


## A SHUT front: the kit building + the door leaf + the law.
func _shut_front(label: String, x: float, glow: Color) -> void:
	var front := Node3D.new()
	front.name = "Front_" + label.replace("'", "").replace(" ", "_")
	front.position = Vector3(x, 0, FRONT_Z)
	add_child(front)
	var b := CLS_Kit.place(front, "kenney_city/building-small-c.glb",
			Vector3(0, 0, -2.2))
	if b:
		b.scale = Vector3(2.6, 2.2, 1.4)
		var col := _collider_for(b, AABB(
				Vector3(-4.6, 0, -3.6), Vector3(9.2, 7.2, 2.8)))
		add_child(col)
	_sign(front, label, glow, Vector3(0, 4.4, 0.9), 34)
	var law := {"state": "locked", "reason": REASONS.get(label,
			"no answer - the bell's dead")}
	if label in BREAKABLE:
		law["breakable"] = true
		law["hits"] = 3
		law["stash"] = 60 if label == "THE LAUNDROMAT" else 30
	Doors.register(front, label, law)


# --- the south side --------------------------------------------------------


func _fronts_south() -> void:
	# housing blocks (kit, all locked) + the newsstand kiosk
	var names := ["THE NEWSSTAND", "ROW HOUSES", "THE ROOMS UPSTAIRS",
			"OLD COURT", "THE DAILIES"]
	var kits := ["building-small-a", "building-small-b", "building-small-d",
			"building-small-a", "building-small-b"]
	for i in range(5):
		var x := -44.0 + i * 22.0
		var front := Node3D.new()
		front.name = "Front_" + names[i].replace(" ", "_")
		front.position = Vector3(x, 0, -FRONT_Z)
		add_child(front)
		var b := CLS_Kit.place(front,
				"kenney_city/%s.glb" % kits[i], Vector3(0, 0, 2.2), PI)
		if b:
			b.scale = Vector3(2.8, 2.4, 1.4)
			var col := _collider_for(b, AABB(
					Vector3(-4.8, 0, 0.8), Vector3(9.6, 7.4, 2.8)))
			add_child(col)
		var glow := Color(0.55, 0.75, 1.0) if i % 2 == 0 \
				else Color(1.0, 0.7, 0.4)
		_sign(front, names[i], glow, Vector3(0, 4.6, -0.9), 30)
		var law := {"state": "locked",
				"reason": REASONS.get(names[i],
						"no answer - the bell's dead")}
		if names[i] in BREAKABLE:
			law["breakable"] = true
			law["hits"] = 3
			law["stash"] = 30
		Doors.register(front, names[i], law)
	# the plaza pocket replaces one housing slot south-east
	_plaza_south()


## The plaza: a widened sidewalk pocket with planters + a bench.
func _plaza_south() -> void:
	var plaza := Node3D.new()
	plaza.name = "Plaza"
	plaza.position = Vector3((PLAZA_X0 + PLAZA_X1) * 0.5, 0, -FRONT_Z)
	add_child(plaza)
	_solid(plaza, Vector3(PLAZA_X1 - PLAZA_X0 + 6.0, 0.26, 5.0),
			Vector3(0, -0.06, 1.0), Color(0.16, 0.16, 0.18))
	for px in [-6.0, 0.0, 6.0]:
		var planter := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.4, 0.7, 1.4)
		m.material = _mat(PALETTE.trim.darkened(0.3))
		planter.mesh = m
		planter.position = Vector3(px, 0.35, 1.6)
		plaza.add_child(planter)
		var shrub := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.0
		sm.material = _mat(Color(0.12, 0.28, 0.14))
		shrub.mesh = sm
		shrub.position = Vector3(px, 1.0, 1.6)
		plaza.add_child(shrub)
		var pcol := StaticBody3D.new()
		pcol.position = Vector3(px, 0.35, 1.6)
		var pc := CollisionShape3D.new()
		var ps := BoxShape3D.new()
		ps.size = Vector3(1.4, 0.7, 1.4)
		pc.shape = ps
		pcol.add_child(pc)
		plaza.add_child(pcol)
	CLS_Kit.place(plaza, "kenney_furniture/chairRounded.glb",
			Vector3(-3.0, 0, -0.4), 0.2)
	CLS_Kit.place(plaza, "kenney_furniture/chairRounded.glb",
			Vector3(3.0, 0, -0.4), -0.2)
	_sign(plaza, "THE PLAZA", Color(0.55, 0.95, 1.0),
			Vector3(0, 3.4, 2.4), 34)


func _plaza() -> void:
	pass  # (the plaza lives on the south side; kept the name for the
	      # 02_MASTER_DESIGN cross-reference)


# --- the subway mouth, vending, alleys, lamps -------------------------------


func _subway() -> void:
	var sub := Node3D.new()
	sub.name = "SubwayEntrance"
	sub.position = Vector3(48.0, 0, -FRONT_Z + 1.0)
	add_child(sub)
	# the stair mouth: dark steps descending into the ground
	for i in 5:
		var step := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(3.2, 0.3, 0.6)
		m.material = _mat(Color(0.1, 0.1, 0.12).darkened(0.05 * i))
		step.mesh = m
		step.position = Vector3(0, -0.15 * i - 0.15, 0.5 * i)
		sub.add_child(step)
	_solid(sub, Vector3(3.6, 0.9, 0.3), Vector3(-1.95, 0.45, 0.8),
			PALETTE.trim)
	_solid(sub, Vector3(3.6, 0.9, 0.3), Vector3(1.95, 0.45, 0.8),
			PALETTE.trim)
	_sign(sub, "SUBWAY - the metro opens with the transit build",
			Color(0.4, 0.8, 1.0), Vector3(0, 1.9, -0.4), 26)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.8, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	glow.position = Vector3(0, 1.6, -0.4)
	sub.add_child(glow)


func _vending() -> void:
	for x in [40.0, 41.8]:
		var vm := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.9, 1.9, 0.7)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.08, 0.25) if x > 40.9 \
				else Color(0.08, 0.25, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.5) if x > 40.9 \
				else Color(0.3, 0.9, 1.0)
		mat.emission_energy_multiplier = 0.5
		m.material = mat
		vm.mesh = m
		vm.position = Vector3(x, 0.95, FRONT_Z - 0.2)
		vm.name = "Vending"
		add_child(vm)
		var body := StaticBody3D.new()
		body.position = Vector3(x, 0.95, FRONT_Z - 0.2)
		var col := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.9, 1.9, 0.7)
		col.shape = s
		body.add_child(col)
		add_child(body)


func _alley(x: float) -> void:
	var alley := Node3D.new()
	alley.name = "Alley_%d" % int(x)
	alley.position = Vector3(x, 0, FRONT_Z - 2.6)
	add_child(alley)
	CLS_Kit.place(alley, "kenney_furniture/trashcan.glb", Vector3(-0.6, 0, 0))
	CLS_Kit.place(alley, "kenney_furniture/trashcan.glb", Vector3(0.3, 0, 0.5), 0.5)
	CLS_Kit.place(alley, "kenney_furniture/cardboardBoxClosed.glb",
			Vector3(0.8, 0, -0.4), 0.2)
	_sign(alley, "ALLEY", Color(0.4, 0.4, 0.5),
			Vector3(0, 2.8, -0.6), 24)
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.72, 0.4)
	bulb.light_energy = 0.55
	bulb.omni_range = 5.0
	bulb.position = Vector3(0, 3.4, -0.6)
	alley.add_child(bulb)
	var tw := create_tween().set_loops()
	tw.tween_property(bulb, "light_energy", 0.15, 0.07) \
			.set_delay(randf_range(0.6, 1.8))
	tw.tween_property(bulb, "light_energy", 0.55, 0.1)


## Sodium lamp posts the whole street, but only a FEW carry a real
## light (the mobile budget): the rest read by emissive head + a
## light-pool decal.
func _lamps() -> void:
	var lit := {-46.0: true, -12.0: true, 22.0: true, 54.0: true}
	for i in range(-60, 61, 16):
		for sz in [-1.0, 1.0]:
			var x := float(i) + (4.0 if sz < 0 else -4.0)
			if absf(x) > STREET_X:
				continue
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.07
			pm.bottom_radius = 0.09
			pm.height = 4.6
			pm.material = _mat(PALETTE.trim.darkened(0.4))
			post.mesh = pm
			post.position = Vector3(x, 2.3, sz * 7.4)
			post.name = "LampPost"
			add_child(post)
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.5, 0.16, 0.24)
			hm.material = _glow(PALETTE.sodium, 0.9)
			head.mesh = hm
			head.position = Vector3(x, 4.55, sz * 7.0)
			head.name = "LampHead"
			add_child(head)
			# the light pool decal on the walk
			var pool := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(4.2, 3.0)
			var qmat := StandardMaterial3D.new()
			qmat.albedo_color = Color(1.0, 0.72, 0.4, 0.14)
			qmat.emission_enabled = true
			qmat.emission = Color(1.0, 0.72, 0.4)
			qmat.emission_energy_multiplier = 0.16
			qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			qm.material = qmat
			pool.mesh = qm
			pool.rotation = Vector3(-PI / 2.0, 0, 0)
			pool.position = Vector3(x, 0.015, sz * 5.8)
			pool.name = "LightPool"
			add_child(pool)
			if lit.has(x) and sz > 0:
				var light := OmniLight3D.new()
				light.light_color = PALETTE.sodium
				light.light_energy = 1.1
				light.omni_range = 11.0
				light.position = Vector3(x, 4.4, sz * 6.8)
				light.name = "LampLight"
				add_child(light)
	# the city fill: the night sky's cold wash
	var fill := DirectionalLight3D.new()
	fill.name = "CityFill"
	fill.rotation_degrees = Vector3(-62, 24, 0)
	fill.light_color = Color(0.26, 0.3, 0.45)
	fill.light_energy = 0.5
	add_child(fill)


# --- gates + spawns ---------------------------------------------------------


func _gates() -> void:
	# west end: the way home (the yard gate lands you here)
	var home := Node3D.new()
	home.name = "SpawnFromHome"
	home.position = Vector3(-STREET_X + 2.0, 0.05, 4.4)
	add_child(home)
	_gate(Vector3(-STREET_X - 1.0, 1.0, 4.4), "warehouse", "from_street",
			"← THE WAREHOUSE", Color(0.55, 0.95, 1.0))
	# east end: THE CLUB DISTRICT - the main avenue's gate (real
	# travel since step 9)
	_gate(Vector3(STREET_X + 1.0, 1.0, 4.4), "club_district",
			"from_neighbourhood", "THE CLUB QUARTER →",
			Color(1.0, 0.69, 0.13))
	_spawn_marker("SpawnFromStreet", Vector3(-STREET_X + 4.0, 0.05, 0.0))


func _spawn_marker(id: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = id
	n.position = pos
	add_child(n)


## A visible, signposted gate: an Area3D doorway + a lit sign.
func _gate(pos: Vector3, to: String, spawn: String, text: String,
		col: Color) -> void:
	var g := Node3D.new()
	g.name = "Gate_" + text.substr(0, 12).replace(" ", "_")
	g.position = pos
	add_child(g)
	# the frame opens ALONG the street (x): posts flank the lane in
	# z, the header spans them - a walker on the sidewalk passes
	# BETWEEN the posts, never into one
	for sz2 in [-1.6, 1.6]:
		_solid(g, Vector3(0.4, 3.4, 0.4), Vector3(0, 1.7, sz2),
				PALETTE.trim)
	_solid(g, Vector3(0.4, 0.4, 3.6), Vector3(0, 3.6, 0), PALETTE.trim)
	_sign(g, text, col, Vector3(0, 3.1, 0.3), 32)
	if to != "":
		var zone := Area3D.new()
		zone.name = "GateZone"
		var col2 := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(2.4, 3.0, 2.4)
		col2.shape = s
		zone.add_child(col2)
		g.add_child(zone)
		zone.body_entered.connect(func(b):
			if b.is_in_group("player") and not Game._fading \
					and not b.get_meta("riding", false):
				Game.travel(to, spawn))
	else:
		# the honest locked gate: solid across the lane, signed
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


func _collider_for(n: Node3D, aabb: AABB) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Col_" + n.name
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = aabb.size
	col.shape = s
	body.add_child(col)
	body.position = n.position + aabb.get_center() * n.scale
	body.rotation.y = n.rotation.y
	return body
