extends Node3D

## THE WAREHOUSE — AREA 1, THE HOME (rebuild step 4, from
## 02_MASTER_DESIGN §3): the ~20x15 m converted warehouse, fully
## furnished — the corner loft bed, the workbench, the phone table,
## the fridge, the floor lamp, the weapon rack (pipe, bat, bottles),
## the TRAINING CORNER (punching bag, sparring dummy, mirror), the
## LOCKED big roller door, the side door into the private YARD
## (fence, bins, crates, the gate that opens onto the neighbourhood
## at step 6, the flickering lamp). Warm practical light, the one
## private place in Cinder City. Furniture from the Kenney CC0 kit
## (kit.gd's proven placement contract); training props code-built
## in the art-direction palette.

const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_MatLib := preload("res://scripts/world/mat_lib.gd")
const CLS_TrainTarget := preload("res://scripts/world/train_target.gd")

const PALETTE := {
	"ink": Color(0.02, 0.023, 0.06),
	"floor": Color(0.16, 0.15, 0.17),
	"wall": Color(0.10, 0.10, 0.12),
	"steel": Color(0.30, 0.32, 0.36),
	"wood": Color(0.30, 0.21, 0.13),
	"warm": Color(1.0, 0.78, 0.55),
	"guide": Color(0.24, 0.86, 0.52),
	"accent": Color(1.0, 0.0, 0.5),
}


func _ready() -> void:
	_shell()
	_home()
	_training_corner()
	_yard()
	_lighting()
	_markers()
	Log.info("Warehouse home ready (area=%s spawn=%s)" % [
			Game.area_id, Game.spawn_id])


# --- the shell: floor, walls, the two doors ------------------------------


func _shell() -> void:
	_solid_mesh(Vector3(20.0, 0.2, 15.0), Vector3(0, -0.1, 0),
			PALETTE.floor, "concrete")
	# north wall carries the big LOCKED roller door; east wall the side
	# door to the yard. West/south stay plain.
	_wall_with(Vector3(20.6, 4.0, 0.3), Vector3(0, 2.0, -7.5), "south")
	_wall_with(Vector3(0.3, 4.0, 15.3), Vector3(-10.15, 2.0, 0), "west")
	_wall_with(Vector3(20.6, 4.0, 0.3), Vector3(0, 2.0, 7.5), "north_roller")
	_wall_with(Vector3(0.3, 4.0, 15.3), Vector3(10.15, 2.0, 0), "east_side")
	# the ceiling: dark corrugated, one hanging bulb hole later
	_solid_mesh(Vector3(20.6, 0.2, 15.3), Vector3(0, 4.1, 0),
			PALETTE.wall.darkened(0.4))


## A wall section; named pieces get their feature built onto them.
func _wall_with(sz: Vector3, pos: Vector3, kind: String) -> void:
	if kind == "east_side":
		# the east wall has a REAL 1.2 m doorway at z=0: two segments
		# + a lintel, so the hero walks through into the yard
		_solid_mesh(Vector3(0.3, 4.0, 6.9), pos + Vector3(0, 0, -4.2),
				PALETTE.wall)
		_solid_mesh(Vector3(0.3, 4.0, 6.9), pos + Vector3(0, 0, 4.2),
				PALETTE.wall)
		_solid_mesh(Vector3(0.3, 1.6, 1.2), pos + Vector3(0, 3.2, 0),
				PALETTE.wall)
		_side_door(pos + Vector3(-0.25, 0, 0))
		return
	_solid_mesh(sz, pos, PALETTE.wall, "corrugated")
	if kind == "north_roller":
		_roller_door(pos + Vector3(0, -0.2, -0.25))


## The big roller door: steel slats, closed and LOCKED (the street
## opens with the neighbourhood build - the sign says so honestly).
func _roller_door(pos: Vector3) -> void:
	var g := Node3D.new()
	g.name = "RollerDoor"
	g.position = pos
	add_child(g)
	for i in 7:
		var slat := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(5.0, 0.5, 0.1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE.steel.darkened(0.1 + 0.04 * i)
		mat.metallic = 0.55
		mat.roughness = 0.55
		m.material = mat
		slat.mesh = m
		slat.position = Vector3(0, 0.35 + i * 0.52, 0)
		slat.name = "Slat_%d" % i
		g.add_child(slat)
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.5, 0.4, 0.16)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = PALETTE.accent.darkened(0.35)
	lm.material = lmat
	lock.mesh = lm
	lock.position = Vector3(1.6, 1.1, -0.02)
	lock.name = "Lock"
	g.add_child(lock)
	_sign(g, Vector3(0, 2.6, -0.3),
			"LOCKED - the street opens with the neighbourhood build",
			Color(1.0, 0.69, 0.13))


## The side door: open frame into the yard (the way out).
func _side_door(pos: Vector3) -> void:
	var g := Node3D.new()
	g.name = "SideDoor"
	g.position = pos
	g.rotation.y = -PI / 2.0
	add_child(g)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.5, 2.4, 0.18)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = PALETTE.steel
	fm.material = fmat
	frame.mesh = fm
	frame.position = Vector3(0, 1.2, 0)
	g.add_child(frame)
	# the open doorway glow: a warm quad + spill light into the hall
	var glow := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(1.1, 2.1)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.98, 0.8, 0.55)
	gmat.emission_enabled = true
	gmat.emission = Color(0.9, 0.65, 0.35)
	gmat.emission_energy_multiplier = 0.8
	gm.material = gmat
	glow.mesh = gm
	glow.position = Vector3(0, 1.15, 0.05)
	glow.name = "Glow"
	g.add_child(glow)
	_sign(g, Vector3(0, 2.8, 0.1), "THE YARD", Color(0.55, 0.95, 1.0))


# --- the home furnishings ---------------------------------------------------


func _home() -> void:
	# the corner loft bed: a raised platform + the Kenney single bed
	var loft := Node3D.new()
	loft.name = "Loft"
	loft.position = Vector3(-7.6, 0, -5.4)
	add_child(loft)
	_solid_mesh_parent(loft, Vector3(4.4, 0.5, 3.4), Vector3(0, 0.25, 0),
			PALETTE.wood.darkened(0.25))
	_solid_mesh_parent(loft, Vector3(0.35, 0.9, 0.35), Vector3(-1.9, -0.2, -1.4),
			PALETTE.steel.darkened(0.3))
	_solid_mesh_parent(loft, Vector3(0.35, 0.9, 0.35), Vector3(1.9, -0.2, -1.4),
			PALETTE.steel.darkened(0.3))
	_solid_mesh_parent(loft, Vector3(0.35, 0.9, 0.35), Vector3(-1.9, -0.2, 1.4),
			PALETTE.steel.darkened(0.3))
	_solid_mesh_parent(loft, Vector3(0.35, 0.9, 0.35), Vector3(1.9, -0.2, 1.4),
			PALETTE.steel.darkened(0.3))
	_place(loft, "kenney_furniture/bedSingle.glb", Vector3(0, 0.5, 0.2))
	_place(loft, "kenney_furniture/sideTable.glb", Vector3(1.6, 0.5, -1.1))
	# the workbench (the Kenney desk)
	var desk := _place(self, "kenney_furniture/desk.glb",
			Vector3(-6.5, 0, 4.8), PI)
	if desk:
		_sign(desk, Vector3(0, 1.2, -0.3), "THE WORKBENCH",
				Color(0.55, 0.95, 1.0))
	# the phone table: side table + the phone prop + the honest note
	var phone := Node3D.new()
	phone.name = "PhoneTable"
	phone.position = Vector3(-8.9, 0, 1.8)
	add_child(phone)
	_place(phone, "kenney_furniture/sideTableDrawers.glb", Vector3.ZERO, PI / 2.0)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.03, 0.34)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = PALETTE.ink
	bmat.emission_enabled = true
	bmat.emission = Color(0.0, 0.94, 1.0)
	bmat.emission_energy_multiplier = 0.7
	bm.material = bmat
	box.mesh = bm
	box.position = Vector3(0, 0.41, 0)
	box.name = "Phone"
	phone.add_child(box)
	_sign(phone, Vector3(0, 1.3, 0), "calls arrive with the phone build",
			Color(0.62, 0.66, 0.8))
	# the fridge: code-built (the kit has none) - palette-passed steel
	var fridge := Node3D.new()
	fridge.name = "Fridge"
	fridge.position = Vector3(9.2, 0, 6.3)
	add_child(fridge)
	_solid_mesh_parent(fridge, Vector3(0.8, 1.85, 0.75), Vector3(0, 0.93, 0),
			Color(0.24, 0.26, 0.3))
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.05, 0.6, 0.05)
	hm.material = _mat(PALETTE.steel.lightened(0.25))
	handle.mesh = hm
	handle.position = Vector3(-0.28, 1.1, 0.4)
	fridge.add_child(handle)
	# the floor lamp (Kenney) + its practical light in _lighting()
	_place(self, "kenney_furniture/lampRoundFloor.glb", Vector3(-4.5, 0, -6.0))
	# the weapon rack: code-built wall rack + pipe, bat, two bottles
	var rack := Node3D.new()
	rack.name = "WeaponRack"
	rack.position = Vector3(-9.6, 0, 4.6)
	rack.rotation.y = PI / 2.0
	add_child(rack)
	_solid_mesh_parent(rack, Vector3(1.9, 0.1, 0.32), Vector3(0, 1.5, 0),
			PALETTE.wood)
	_solid_mesh_parent(rack, Vector3(1.9, 0.1, 0.32), Vector3(0, 0.95, 0),
			PALETTE.wood)
	_pipe(rack, Vector3(-0.6, 1.22, 0))
	_bat(rack, Vector3(0.0, 1.22, 0))
	_bottle(rack, Vector3(0.5, 1.06, 0), "Bottle_1")
	_bottle(rack, Vector3(0.62, 1.06, 0), "Bottle_2")
	_sign(rack, Vector3(0, 2.0, 0), "THE RACK - pipe, bat, bottles",
			Color(0.55, 0.95, 1.0))
	# crates + boxes by the roller door (Kenney)
	_place(self, "kenney_furniture/cardboardBoxClosed.glb",
			Vector3(6.8, 0, -6.2), 0.3)
	_place(self, "kenney_furniture/cardboardBoxOpen.glb",
			Vector3(7.6, 0, -5.4), -0.2)
	_place(self, "kenney_furniture/trashcan.glb", Vector3(8.6, 0, -6.6))


# --- the training corner ----------------------------------------------------


func _training_corner() -> void:
	var corner := Node3D.new()
	corner.name = "TrainingCorner"
	corner.position = Vector3(6.4, 0, 4.6)
	add_child(corner)
	# the punching bag: chain + a heavy cylinder that can sway
	# (a TRAIN TARGET - the combat core hits it)
	var bag := CLS_TrainTarget.new()
	bag.name = "PunchingBag"
	bag.position = Vector3(2.4, 0, 1.2)
	corner.add_child(bag)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.8
	chain.mesh = cm
	chain.position = Vector3(0, 3.6, 0)
	chain.name = "Chain"
	bag.add_child(chain)
	var body := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.30
	bmesh.bottom_radius = 0.26
	bmesh.height = 1.15
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.35, 0.12, 0.12)
	bmat.roughness = 0.85
	bmesh.material = bmat
	body.mesh = bmesh
	body.position = Vector3(0, 2.6, 0)
	body.name = "Bag"
	bag.add_child(body)
	var anchor := _solid_parent(bag, Vector3(0.7, 0.4, 0.7),
			Vector3(0, 3.95, 0), Color(0.05, 0.05, 0.06))
	anchor.name = "Anchor"
	# the sparring dummy: a pole + capsule torso + head, padded arms
	# (a TRAIN TARGET with posture that breaks)
	var dummy := CLS_TrainTarget.new()
	dummy.name = "SparringDummy"
	dummy.position = Vector3(0.4, 0, 1.6)
	corner.add_child(dummy)
	_solid_mesh_parent(dummy, Vector3(0.28, 1.0, 0.28), Vector3(0, 0.5, 0),
			PALETTE.steel.darkened(0.2))
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.26
	tm.height = 1.0
	tm.material = _mat(Color(0.42, 0.24, 0.12))
	torso.mesh = tm
	torso.position = Vector3(0, 1.55, 0)
	torso.name = "Torso"
	dummy.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	hm.material = _mat(Color(0.62, 0.42, 0.22))
	head.mesh = hm
	head.position = Vector3(0, 2.2, 0)
	head.name = "Head"
	dummy.add_child(head)
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.09
		am.height = 0.7
		am.material = _mat(Color(0.2, 0.2, 0.24))
		arm.mesh = am
		arm.position = Vector3(sx * 0.42, 1.62, 0)
		arm.rotation.z = sx * 1.2
		arm.name = "Arm_%s" % ("L" if sx < 0 else "R")
		dummy.add_child(arm)
	# the mirror: a tall reflective panel on the west-facing wall side
	var mirror := Node3D.new()
	mirror.name = "Mirror"
	mirror.position = Vector3(2.6, 0, -1.8)
	mirror.rotation.y = PI / 2.0
	corner.add_child(mirror)
	var frame := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(1.4, 2.3, 0.08)
	fmesh.material = _mat(PALETTE.wood)
	frame.mesh = fmesh
	frame.position = Vector3(0, 1.25, 0)
	mirror.add_child(frame)
	var pane := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.24, 2.14, 0.02)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.62, 0.70, 0.78)
	pmat.metallic = 0.9
	pmat.roughness = 0.08
	pm.material = pmat
	pane.mesh = pm
	pane.position = Vector3(0, 1.25, 0.05)
	pane.name = "Pane"
	mirror.add_child(pane)
	_sign(corner, Vector3(0.4, 2.9, 1.6), "TRAINING CORNER",
			Color(1.0, 0.69, 0.13))


# --- the private yard -------------------------------------------------------


func _yard() -> void:
	var yard := Node3D.new()
	yard.name = "Yard"
	yard.position = Vector3(10.15 + 7.5, 0, 0)  # east of the side door
	add_child(yard)
	_solid_mesh_parent(yard, Vector3(15.0, 0.2, 10.0), Vector3(0, -0.1, 0),
			Color(0.12, 0.12, 0.13))
	# the fence: the WEST side carries the same 1.5 m doorway gap as
	# the home's east wall (the side door path must stay open), the
	# east side carries the gate
	for spec in [
		[Vector3(15.4, 2.2, 0.24), Vector3(0, 1.1, -5.0)],
		[Vector3(15.4, 2.2, 0.24), Vector3(0, 1.1, 5.0)],
		[Vector3(0.24, 2.2, 4.65), Vector3(-7.5, 1.1, -2.875)],
		[Vector3(0.24, 2.2, 4.65), Vector3(-7.5, 1.1, 2.875)],
		[Vector3(3.9, 2.2, 0.24), Vector3(5.55, 1.1, -5.0)],
		[Vector3(3.9, 2.2, 0.24), Vector3(5.55, 1.1, 5.0)],
	]:
		_solid_mesh_parent(yard, spec[0], spec[1],
				PALETTE.wall.lightened(0.06))
	# THE GATE: the way out to the street (a real travel gate since
	# step 6 - walk through, fade, the neighbourhood loads)
	var gate := Node3D.new()
	gate.name = "YardGate"
	gate.position = Vector3(7.4, 0, 0)
	yard.add_child(gate)
	for sz in [-1.4, 1.4]:
		_solid_mesh_parent(gate, Vector3(0.24, 2.4, 0.3),
				Vector3(0, 1.2, sz), Color(0.16, 0.17, 0.2))
	_solid_mesh_parent(gate, Vector3(0.24, 0.5, 3.1), Vector3(0, 2.45, 0),
			Color(0.16, 0.17, 0.2))
	_sign(gate, Vector3(-0.6, 2.0, 0), "THE STREET",
			Color(0.55, 0.95, 1.0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.95, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	glow.position = Vector3(-0.6, 2.6, 0)
	gate.add_child(glow)
	var zone := Area3D.new()
	zone.name = "GateZone"
	var zcol := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(1.2, 2.6, 2.6)
	zcol.shape = zs
	zone.add_child(zcol)
	gate.add_child(zone)
	zone.body_entered.connect(func(b):
		if b.is_in_group("player") and not Game._fading:
			Game.travel("neighbourhood", "from_home"))
	# bins + crates (Kenney)
	_place(yard, "kenney_furniture/trashcan.glb", Vector3(-5.6, 0, -3.6))
	_place(yard, "kenney_furniture/trashcan.glb", Vector3(-5.0, 0, -4.1), 0.7)
	_place(yard, "kenney_furniture/cardboardBoxClosed.glb",
			Vector3(-4.2, 0, 3.8), 0.4)
	_place(yard, "kenney_furniture/cardboardBoxOpen.glb",
			Vector3(-3.3, 0, 4.2), -0.3)
	_place(yard, "kenney_furniture/lampSquareFloor.glb",
			Vector3(4.6, 0, -3.8))


# --- lighting (2-3 dynamic lights + practicals) -----------------------------


func _lighting() -> void:
	# the main warm hall light
	var main := OmniLight3D.new()
	main.name = "MainLight"
	main.position = Vector3(0, 3.4, 0)
	main.light_color = PALETTE.warm
	main.omni_range = 17.0
	main.light_energy = 1.35
	add_child(main)
	# the bed-corner practical (the lamp's own glow)
	var bed := OmniLight3D.new()
	bed.name = "BedLamp"
	bed.position = Vector3(-4.5, 1.7, -6.0)
	bed.light_color = Color(1.0, 0.72, 0.42)
	bed.omni_range = 6.5
	bed.light_energy = 0.9
	add_child(bed)
	# the side-door spill into the hall
	var spill := OmniLight3D.new()
	spill.name = "DoorSpill"
	spill.position = Vector3(9.4, 2.0, 0)
	spill.light_color = Color(0.9, 0.78, 0.6)
	spill.omni_range = 5.0
	spill.light_energy = 0.7
	add_child(spill)
	# the yard's flickering sodium lamp (the one light outside)
	var yard_lamp := OmniLight3D.new()
	yard_lamp.name = "YardLamp"
	yard_lamp.position = Vector3(14.0, 3.0, -3.8)
	yard_lamp.light_color = Color(1.0, 0.62, 0.28)
	yard_lamp.omni_range = 9.0
	yard_lamp.light_energy = 1.1
	add_child(yard_lamp)
	var tw := create_tween().set_loops()
	tw.tween_property(yard_lamp, "light_energy", 0.25, 0.08) \
			.set_delay(randf_range(0.8, 2.2))
	tw.tween_property(yard_lamp, "light_energy", 1.1, 0.12)
	# the soft city fill so nothing reads pure black
	var fill := DirectionalLight3D.new()
	fill.name = "CityFill"
	fill.rotation_degrees = Vector3(-55, 30, 0)
	fill.light_color = Color(0.30, 0.33, 0.46)
	fill.light_energy = 0.42
	add_child(fill)


# --- markers ----------------------------------------------------------------


func _markers() -> void:
	var spawn := Node3D.new()
	spawn.name = "SpawnStart"
	spawn.position = Vector3(0, 0.05, 3.0)
	add_child(spawn)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.55
	rm.outer_radius = 0.7
	rm.material = _glow_mat(PALETTE.guide)
	ring.mesh = rm
	ring.position = Vector3(0, 0.05, 3.0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.name = "SpawnRing"
	add_child(ring)
	_sign(self, Vector3(0, 2.6, -6.8),
			"THE WAREHOUSE - home", Color(1.0, 0.85, 0.55))


# --- small builders ---------------------------------------------------------


func _place(parent: Node, rel: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := CLS_Kit.place(parent, rel, pos, yaw)
	if n == null:
		return null
	# a stand-in collider box: kit meshes are visual-only (the GLB
	# root is often a plain Node3D - merge the child mesh boxes)
	var box := _kit_aabb(n)
	if box.size.length() > 0.01:
		var col := _collider_for(n, box)
		parent.call_deferred("add_child", col)
	return n


func _kit_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	if n is VisualInstance3D:
		out = (n as VisualInstance3D).get_aabb()
	else:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (mi as MeshInstance3D).get_aabb()
			box = (mi as Node3D).transform * box
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
	return out


func _collider_for(n: Node3D, aabb: AABB) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Col_" + n.name
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	col.shape = shape
	body.add_child(col)
	body.position = n.position + aabb.get_center()
	body.rotation.y = n.rotation.y
	return body


func _solid_mesh(sz: Vector3, pos: Vector3, col: Color,
		mat_name := "") -> void:
	_solid_mesh_parent_mat(self, sz, pos, col, mat_name)


func _solid_mesh_parent(parent: Node, sz: Vector3, pos: Vector3,
		col: Color) -> MeshInstance3D:
	return _solid_mesh_parent_mat(parent, sz, pos, col, "")


func _solid_mesh_parent_mat(parent: Node, sz: Vector3, pos: Vector3,
		col: Color, mat_name: String) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = sz
	shape.shape = s
	body.add_child(shape)
	parent.add_child(body)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	if mat_name != "":
		bm.material = CLS_MatLib.surface(mat_name, sz)
	else:
		bm.material = _mat(col)
	m.mesh = bm
	m.position = pos
	parent.add_child(m)
	return m


func _solid_parent(parent: Node, sz: Vector3, pos: Vector3,
		col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = sz
	shape.shape = s
	body.add_child(shape)
	parent.add_child(body)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	bm.material = _mat(col)
	m.mesh = bm
	m.position = pos
	parent.add_child(m)
	return body


func _pipe(parent: Node3D, pos: Vector3) -> void:
	var pipe := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.035
	m.bottom_radius = 0.035
	m.height = 1.0
	m.material = _mat(Color(0.5, 0.52, 0.56))
	pipe.mesh = m
	pipe.rotation.z = PI / 2.0
	pipe.position = pos
	pipe.name = "Pipe"
	parent.add_child(pipe)


func _bat(parent: Node3D, pos: Vector3) -> void:
	var bat := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.025
	m.bottom_radius = 0.045
	m.height = 0.85
	m.material = _mat(PALETTE.wood.lightened(0.12))
	bat.mesh = m
	bat.rotation.z = PI / 2.0 - 0.12
	bat.position = pos
	bat.name = "Bat"
	parent.add_child(bat)


func _bottle(parent: Node3D, pos: Vector3, id := "Bottle") -> void:
	var bottle := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.035
	m.bottom_radius = 0.04
	m.height = 0.26
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.35, 0.2)
	mat.metallic = 0.2
	mat.roughness = 0.15
	m.material = mat
	bottle.mesh = m
	bottle.position = pos
	bottle.name = id
	parent.add_child(bottle)


func _sign(parent: Node3D, pos: Vector3, text: String, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.font_size = 30
	l.outline_size = 10
	l.outline_modulate = Color(0.01, 0.015, 0.04)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.name = "Sign_" + text.substr(0, 12).replace(" ", "_")
	parent.add_child(l)
	return l


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m


func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.2
	return m
