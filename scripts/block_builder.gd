extends Node3D

## Code-built blocks 2 and 3 (bible 6), the same kit the main street
## wears: box buildings, asphalt, sidewalks, kiosk fronts with lit
## signs. Block 2 - the club quarter: club fronts, the gym (the bible's
## fight-club home: gym + underground tournaments; the door is a sign
## and a place until the tournament batch wires it), the Mechanic's
## garage. Block 3 - the docks: the warehouse with the big shut door
## the final choice happens at (dressing only until the story batch),
## containers, the water, a crane. The market<->foundry ends wear the
## underpass the bible digs between them.

const ASPHALT := Color(0.11, 0.11, 0.115)  # B22: 0.055 read as unlit void
const SIDEWALK := Color(0.2, 0.195, 0.19)
const FACE := Color(0.09, 0.088, 0.09)
const CLS_Kit := preload("res://scripts/kit.gd")

## The kit buildings _building() cycles through (tall first) so adjacent
## plots never wear the same model twice in a row. CC0 - Kenney City Kit.
const KIT_BUILDINGS := [
	"kenney_commercial/building-g.glb",
	"kenney_commercial/building-f.glb",
	"kenney_commercial/building-b.glb",
	"kenney_commercial/building-d.glb",
	"kenney_city/building-small-c.glb",
]

var block_id := ""
var _kit_i := 0


func build_block() -> void:
	_common()
	if block_id == "market":
		_market()
		# B26 WHEELS EVERYWHERE: one drivable car parked kerbside in
		# every far block - no decorative metal anywhere on the street
		_park_car("CarMarket", Vector3(-8.0, 0.0, -5.6), PI,
				Color(0.25, 0.08, 0.06))
	elif block_id == "foundry":
		_foundry()
		_park_car("CarFoundry", Vector3(8.0, 0.0, -5.6), 0.0,
				Color(0.07, 0.09, 0.15))


## B26 WHEELS EVERYWHERE: a drivable car parked on the block's kerb -
## the traffic family's own geometry (code-built, the renderer law),
## wired to the same Vehicle controller as the riverside sedan, with
## headlights, tails and named wheels the base script drives. The
## block tears down and rebuilds as the hero walks; the car is a NEW
## node every time, so it asks the save where it was left.
func _park_car(car_name: String, pos: Vector3, yaw: float,
		paint_col: Color) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = paint_col
	paint.roughness = 0.3
	paint.metallic = 0.5
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.03, 0.05)
	glass.roughness = 0.1
	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.02, 0.02, 0.025)
	tire.roughness = 0.95
	var car := CharacterBody3D.new()
	car.set_script(preload("res://scripts/vehicle.gd"))
	car.name = car_name
	car.position = pos
	car.rotation.y = yaw
	add_child(car)
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(4.2, 1.0, 1.8)
	shape.shape = cs
	shape.position = Vector3.UP * 0.5
	car.add_child(shape)
	# the long axis is +x (the nose), the street sedan's convention:
	# lower body, glass cabin, four wheels the base script rolls
	var lower := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(4.2, 0.52, 1.75)
	lm.material = paint
	lower.mesh = lm
	lower.position = Vector3.UP * 0.52
	car.add_child(lower)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.1, 0.5, 1.6)
	cm.material = glass
	cabin.mesh = cm
	cabin.position = Vector3(-0.25, 1.02, 0)
	car.add_child(cabin)
	for wx in [-1.4, 1.4]:
		for wz in [-0.85, 0.85]:
			var wheel := MeshInstance3D.new()
			wheel.name = "wheel_%s%s" % ["L" if wx < 0 else "R",
					"F" if wx > 0 else "R"]
			var wm := CylinderMesh.new()
			wm.top_radius = 0.32
			wm.bottom_radius = 0.32
			wm.height = 0.22
			wm.material = tire
			wheel.mesh = wm
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(wx, 0.32, wz)
			car.add_child(wheel)
	# the noir lights (heads, tails) - tails named so the brake
	# lights the base script drives actually glow
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.88, 0.65)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.6)
	lamp.emission_energy_multiplier = 1.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(1.0, 0.2, 0.12)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.16, 0.1)
	tail.emission_energy_multiplier = 0.8
	tail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hz in [-0.55, 0.55]:
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.06, 0.12, 0.3)
		hm.material = lamp
		head.mesh = hm
		head.position = Vector3(2.11, 0.62, hz)
		car.add_child(head)
		var t2 := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.06, 0.1, 0.24)
		tm.material = tail
		t2.mesh = tm
		t2.name = "tail_light"
		t2.position = Vector3(-2.11, 0.68, hz)
		car.add_child(t2)
	car.set_meta("slam_surface", "car")
	SaveGame.apply_saved_state(car)


# --- the kit every block wears ------------------------------------------------


func _common() -> void:
	name = "Block_" + block_id
	# ground + collision
	var body := StaticBody3D.new()
	body.name = "Street"
	add_child(body)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(44, 1, 40)
	col.shape = cs
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	var road := MeshInstance3D.new()
	road.name = "Asphalt"
	road.add_to_group("road")
	var rm := BoxMesh.new()
	rm.size = Vector3(44, 1, 40)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = ASPHALT
	rm.material = rmat
	road.mesh = rm
	road.position = Vector3(0, -0.5, 0)
	body.add_child(road)
	# sidewalks both sides
	var slab_mat := StandardMaterial3D.new()
	slab_mat.albedo_color = SIDEWALK
	for sz in [-11.0, 11.0]:
		var sw := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(44, 0.24, 5.0)
		sm.material = slab_mat
		sw.mesh = sm
		sw.position = Vector3(0, -0.12, sz)
		sw.name = "SidewalkSlab"
		add_child(sw)
	# B18.4: the CC0 kit pavement takes the slabs (the same 44 x 0.24 x 5
	# volume, sunk so its top sits 2 cm proud of the asphalt - no foot
	# clip); the plain boxes above stay as the fresh-import fallback
	if CLS_Kit.place_stretch(self, "kenney_city/pavement.glb",
			Vector3(0, -0.22, -11.0), 0.0, 44.0, 4.0, 5.0) \
			and CLS_Kit.place_stretch(self, "kenney_city/pavement.glb",
			Vector3(0, -0.22, 11.0), 0.0, 44.0, 4.0, 5.0):
		for c in get_children():
			if c.name == "SidewalkSlab":
				(c as MeshInstance3D).visible = false
	# center dashes
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.65, 0.55, 0.1)
	for i in range(-4, 5):
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(2.0, 0.02, 0.22)
		dm.material = dash_mat
		dash.mesh = dm
		dash.position = Vector3(i * 4.4, 0.005, 0)
		dash.name = "LaneDash"
		add_child(dash)
	# B18.4: the kit road - marked lane tiles down the centre as ONE
	# MultiMesh (one draw call for all 11 tiles); the dash boxes above
	# are the fallback and hide when the row lands
	var tiles: Array = []
	for i in range(-5, 6):
		tiles.append(Vector3(i * 4.0, -0.065, 0.0))  # top 1.5 cm proud
	if CLS_Kit.tile_row(self, "kenney_roads/road-straight.glb", tiles, 4.0):
		for c in get_children():
			if c.name == "LaneDash":
				(c as MeshInstance3D).visible = false
	# lamps at the curb (warm sodium light; the moths adopt them).
	# B22 (VLM inspection): four end lamps left the mid-street reading
	# as unlit void - densified to every 4 m, skipping the crossing
	for lx in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
		# VLM round 2: pools read as absent against the lifted ambient -
		# push the lamps so the sodium pools are clearly visible
		var full := absf(lx) >= 12.0  # corner lamps full, mid-street soft
		for side in [-1.0, 1.0]:
			CLS_Kit.lamp(self, Vector3(lx, 0, side * 9.0), side, 5.2,
					2.1 if full else 1.6, 12.0 if full else 9.0)
	# B23: the signalised pedestrian crossing at the block centre - a
	# pole per approach (south pole faces the eastbound lane, north
	# pole the westbound), red/amber/green heads + a walk sign for the
	# pavement. Traffic drives the lamps through the crossing_signal
	# group; the materials are per-pole so only THIS pole's head glows.
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.06
		pm.bottom_radius = 0.09
		pm.height = 3.4
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.12, 0.13, 0.15)
		pm.material = pmat
		pole.mesh = pm
		pole.position = Vector3(2.2 * side, 1.7, 9.3 * side)
		var sig := Node3D.new()
		sig.name = "CrossingSignal"
		sig.add_to_group("crossing_signal")
		sig.position = Vector3(2.2 * side, 0, 9.3 * side)
		add_child(sig)
		sig.add_child(pole)
		pole.reparent(sig)
		pole.position = Vector3.ZERO
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.3, 0.95, 0.3)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.08, 0.09, 0.1)
		hm.material = hmat
		head.mesh = hm
		head.position = Vector3(0, 3.4, 0)
		sig.add_child(head)
		for li in 3:
			var lamp := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.09
			lm.height = 0.18
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(0.25, 0.25, 0.25)
			lmat.emission_enabled = true
			lmat.emission_energy_multiplier = 0.0
			match li:
				0:
					lamp.name = "Red"
					lmat.emission = Color(1.0, 0.12, 0.08)
				1:
					lamp.name = "Amber"
					lmat.emission = Color(1.0, 0.7, 0.15)
				2:
					lamp.name = "Green"
					lmat.emission = Color(0.2, 1.0, 0.4)
			lm.material = lmat
			lamp.mesh = lm
			lamp.position = Vector3(0, 3.72 - li * 0.3, 0.18)
			sig.add_child(lamp)
		# the walk sign faces the pavement it serves
		var walk := MeshInstance3D.new()
		walk.name = "WalkSign"
		var wm := QuadMesh.new()
		wm.size = Vector2(0.34, 0.34)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.25, 0.25, 0.25)
		wmat.emission_enabled = true
		wmat.emission = Color(0.5, 1.0, 0.7)
		wmat.emission_energy_multiplier = 0.0
		wm.material = wmat
		walk.mesh = wm
		walk.position = Vector3(0, 2.85, 0.18 * -side)
		walk.rotation.y = PI if side > 0 else 0.0
		sig.add_child(walk)
	# the gates back out (world coords: this node already sits at its
	# block's offset on the axis)
	var west_to := "riverside" if block_id == "market" else "market"
	Blocks.gate(Vector3(global_position.x - 19.0, 1.0, 0.0), west_to, "east")
	Blocks.gate(Vector3(global_position.x + 19.0, 1.0, 0.0),
			"foundry" if block_id == "market" else "market", "west")


## A building volume: dark face, lit window quads, collision. B18.4: a
## Kenney CC0 kit building takes the volume when it imports - uniform
## scale from the plot height, front face on the plot's own front line,
## the box mesh hides (collision stays: the fight geometry is tuned) and
## the lit windows stay, constrained to the kit's real face width.
func _building(cx: float, cz: float, w: float, d: float, h: float,
		windows := true) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(cx, h / 2.0, cz)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(w, h, d)
	col.shape = cs
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _facade_paint(cx, cz)
	mat.roughness = 0.9
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	add_child(body)
	# the face the lit windows may span: the plot width, or the kit's
	# real width when a kit building took the volume
	var face_w := w
	var kit := _kit_building(cx, cz, w, d, h)
	if kit != null:
		mesh.visible = false
		face_w = kit
	else:
		_roofline(cx, cz, w, d, h)
		# B29 THE DRESSED STREET: the code facade wears its stonework -
		# base course at the kerb line + floor ledges under the window
		# rows (kit buildings keep their own geometry)
		var plinth_mat := StandardMaterial3D.new()
		plinth_mat.albedo_color = Color(0.135, 0.13, 0.125)
		plinth_mat.roughness = 0.85
		_stonework(Vector3(cx, 0.55, cz),
				Vector3(w + 0.14, 1.1, d + 0.14), plinth_mat)
		var trim_mat := StandardMaterial3D.new()
		trim_mat.albedo_color = Color(0.23, 0.22, 0.205)
		trim_mat.roughness = 0.8
		var street_side := 1.0 if cz < 0 else -1.0
		var rows := clampf(int((h - 2.2) / 3.0), 1, 4)
		for fl in rows:
			_stonework(Vector3(cx, 1.62 + fl * 3.0,
					cz + street_side * (d / 2.0 + 0.05)),
					Vector3(w + 0.08, 0.09, 0.26), trim_mat)
	if windows:
		# B23 MILESTONE A: a real facade - a full window grid per floor
		# across the street face (some lit, some dark, some skipped:
		# cities have gaps), plus the side face near the corner
		var toward := 1.0 if cz < 0 else -1.0  # which way the street is
		var front := cz + toward * (d / 2.0 + 0.02)
		var floors := int((h - 1.6) / 3.0)
		var cols := maxi(2, int((face_w - 1.6) / 2.3))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(cx * 13.0 + cz * 7.0))
		for fl in floors:
			for c in cols:
				if rng.randf() < 0.18:
					continue  # the gap
				var fx := cx - face_w / 2.0 + 1.1 + c * ((face_w - 2.0) / maxf(cols - 1.0, 1.0))
				var lit := rng.randf() < 0.55
				_window(Vector3(fx, 2.3 + fl * 3.0, front),
						Vector3(0, PI, 0) if cz < 0 else Vector3.ZERO, lit)
				# the near side face gets the corner column read
				if c < 2:
					var side_x := cx + (w / 2.0 + 0.02) * (1.0 if fx > cx else -1.0)
					_window(Vector3(side_x, 2.3 + fl * 3.0,
							cz + toward * (d / 2.0 - 1.0)),
							Vector3(0, PI / 2.0 if fx > cx else -PI / 2.0, 0),
							rng.randf() < 0.3)


## One facade window: a warm lit pane or a dark one. Lit panes join the
## flicker group under the 1.45 glow threshold (the Xogot lesson).

## B29: one static stonework band (plinth / ledge / crown), tagged for
## the facade-detail facts probe. Unlit, unemissive - budget law.
func _stonework(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.add_to_group("facade_detail")
	add_child(mi)
	return mi


func _window(pos: Vector3, rot: Vector3, lit: bool) -> void:
	var win := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(1.1, 1.4)
	var wmat := StandardMaterial3D.new()
	if lit:
		wmat.albedo_color = Color(1.0, 0.82, 0.45)
		wmat.emission_enabled = true
		wmat.emission = Color(1.0, 0.7, 0.3)
		wmat.emission_energy_multiplier = 0.85
	else:
		# dark glass reads as glass, not void (the VLM black-slab catch)
		wmat.albedo_color = Color(0.055, 0.075, 0.115)
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.material = wmat
	win.mesh = wm
	win.position = pos
	win.rotation = rot
	win.add_to_group("facade_window")
	if lit:
		win.add_to_group("emissive_window")
		win.set_meta("base_energy", 0.85)
	add_child(win)


## A per-plot paint from the district palette - deterministic by plot
## position so a block composes the same way every visit.
const FACADE_PALETTE := [
	Color(0.125, 0.108, 0.1),     # old brick, soot-dark
	Color(0.14, 0.14, 0.15),      # poured concrete
	Color(0.165, 0.145, 0.12),    # painted tan, aged
	Color(0.12, 0.13, 0.15),      # slate blue
	Color(0.15, 0.125, 0.115),    # brownstone
]


func _facade_paint(cx: float, cz: float) -> Color:
	var i := int(absf(cx * 3.0 + cz * 5.0)) % FACADE_PALETTE.size()
	return FACADE_PALETTE[i]


## The roof the sky sees: a parapet lip on every building, a water
## tower on some, AC boxes on most - silhouettes, not slabs.
func _roofline(cx: float, cz: float, w: float, d: float, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(cx * 31.0 + cz * 17.0)) + 7
	var lip := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(w + 0.3, 0.45, d + 0.3)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = _facade_paint(cx, cz).darkened(0.25)
	lm.material = lmat
	lip.mesh = lm
	lip.position = Vector3(cx, h + 0.2, cz)
	add_child(lip)
	if rng.randf() < 0.4:
		# the water tower: tank + conical cap + legs, off-centre
		var tx := cx + rng.randf_range(-w / 4.0, w / 4.0)
		var tz := cz + rng.randf_range(-d / 4.0, d / 4.0)
		var tank := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.9
		tm.bottom_radius = 0.9
		tm.height = 1.6
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.09, 0.07, 0.06)
		tm.material = tmat
		tank.mesh = tm
		tank.position = Vector3(tx, h + 1.5, tz)
		add_child(tank)
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.95
		cm.height = 0.55
		cm.material = tmat
		cap.mesh = cm
		cap.position = Vector3(tx, h + 2.55, tz)
		add_child(cap)
	if rng.randf() < 0.75:
		for i in rng.randi_range(1, 3):
			var ac := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(1.1, 0.6, 1.1)
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.12, 0.12, 0.13)
			am.material = amat
			ac.mesh = am
			ac.position = Vector3(cx + rng.randf_range(-w / 3.0, w / 3.0),
					h + 0.55, cz + rng.randf_range(-d / 3.0, d / 3.0))
			add_child(ac)
	if rng.randf() < 0.3:
		# the noir blade sign on the street edge: a vertical marquee
		var toward := 1.0 if cz < 0 else -1.0
		var blade := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.18, 2.6, 0.7)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.7, 0.2, 0.16)
		bmat.emission_enabled = true
		bmat.emission = Color(0.9, 0.25, 0.18)
		bmat.emission_energy_multiplier = 0.6
		bm2.material = bmat
		blade.mesh = bm2
		blade.position = Vector3(cx + w / 2.0 - 0.3, h - 1.6,
				cz + toward * (d / 2.0 + 0.35))
		add_child(blade)


## Try the next kit building on this plot. Returns the kit's face width
## when it took over (the caller hides its box and narrows the windows),
## or -1.0 when the fallback box stays.
func _kit_building(cx: float, cz: float, w: float, d: float, h: float) -> float:
	# B23 MILESTONE A: kit glb buildings no longer take street plots -
	# the physical iPhone rendered gltf assets as ghosts while every
	# Linux check passed. The code facade (palette, window grids,
	# rooflines) owns every plot now; the kit list stays for the day
	# on-device verification proves the glbs render.
	return -1.0
	var rel: String = KIT_BUILDINGS[_kit_i % KIT_BUILDINGS.size()]
	_kit_i += 1
	if not CLS_Kit.available(rel):
		return -1.0
	var s := h / CLS_Kit.height(rel)
	var depth := CLS_Kit.depth(rel) * s
	var toward := 1.0 if cz < 0 else -1.0  # which way the street is
	var k := CLS_Kit.place(self, rel,
			Vector3(cx, 0.0, cz + toward * (d / 2.0 - depth / 2.0)))
	if k == null:
		return -1.0
	k.scale = Vector3(s, s, s)
	return CLS_Kit.DIMS[rel].x * s


## A soft radial pool: transparent centre colour fading to nothing.
## The Xogot lesson: a flat alpha quad reads as a pale square block
## on Mobile; a radial gradient reads as light on wet asphalt.
func _radial(color: Color, peak: float) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, peak))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	grad.add_point(0.55, Color(color.r, color.g, color.b, peak * 0.35))
	tex.gradient = grad
	return tex


## A lit shop front (kiosk): sign quad + door + glow on the ground.
## Shopfronts carry the group + plank metadata Boards looks for.
func _front(label: String, pos: Vector3, color: Color, w := 3.0) -> void:
	var g := Node3D.new()
	g.name = "Front_" + label
	g.add_to_group("shopfront")
	g.set_meta("plank_off", Vector3(0, 0.5, 0.34))
	g.position = pos
	add_child(g)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(w, 3.0, 0.3)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = FACE.darkened(0.4)
	pm.material = pmat
	panel.mesh = pm
	panel.position = Vector3(0, 1.5, 0)
	g.add_child(panel)
	var sign := Label3D.new()
	sign.text = label
	sign.modulate = color
	sign.font_size = 64
	sign.outline_size = 10
	sign.outline_modulate = Color(0.02, 0.02, 0.05)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.position = Vector3(0, 3.4, 0.18)
	if pos.z > 0:
		sign.rotation = Vector3(0, PI, 0)
	g.add_child(sign)
	var glow := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(w, 1.4)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 1, 1, 0.55)
	gmat.albedo_texture = _radial(color, 0.34)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material = gmat
	glow.mesh = gm
	glow.position = Vector3(0, 0.04, 1.2)
	glow.rotation = Vector3(-PI / 2.0, 0, 0)
	if pos.z > 0:
		glow.position = Vector3(0, 0.04, -1.2)
	glow.add_to_group("decal")
	g.add_child(glow)
	# B29 THE DRESSED STREET: the shopfront wears an awning - a tilted
	# canvas blade over the door line, the street's own rain cover.
	# Unlit fabric, no emission; reads at night by the spill beneath.
	var awn := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(w * 0.9, 0.06, 1.15)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.22, 0.1, 0.1).darkened(0.35) \
			if color.r > color.g else Color(0.08, 0.1, 0.2).darkened(0.35)
	amat.roughness = 0.95
	am.material = amat
	awn.mesh = am
	awn.position = Vector3(0, 2.55, 0.62)
	awn.rotation = Vector3(-0.34 if pos.z <= 0 else 0.34, 0, 0)
	awn.add_to_group("facade_detail")
	g.add_child(awn)
	var valance := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(w * 0.9, 0.16, 0.05)
	vm.material = amat
	valance.mesh = vm
	valance.position = Vector3(0, 2.38, 1.12 if pos.z <= 0 else -1.12)
	valance.add_to_group("facade_detail")
	g.add_child(valance)


# --- block 2: the club quarter --------------------------------------------------


func _market() -> void:
	_building(-13.0, -14.0, 12.0, 8.0, 12.0)
	_building(2.0, -14.5, 14.0, 9.0, 15.0)
	_building(14.0, -13.5, 8.0, 7.0, 9.0)
	_building(-10.0, 14.5, 16.0, 9.0, 10.0)
	_building(8.0, 14.0, 14.0, 8.0, 13.0)
	# the clubs, north side
	_front("THE VELVET ROOM", Vector3(-9.0, 0, -9.6), Color(0.85, 0.15, 0.3))
	_front("NEON 9", Vector3(0.5, 0, -9.6), Color(0.15, 0.85, 0.8))
	_front("PALACE", Vector3(8.5, 0, -9.6), Color(0.7, 0.4, 0.95))
	# the south side: the gym (the bible's fight club) + the garage
	_front("IRON PALM GYM", Vector3(-6.5, 0, 9.6), Color(0.95, 0.65, 0.1))
	var gym_note := Label3D.new()
	gym_note.text = "walk-in hours: after dark"
	gym_note.modulate = Color(0.7, 0.65, 0.5)
	gym_note.font_size = 30
	gym_note.position = Vector3(-6.5, 2.2, 8.8)
	gym_note.rotation = Vector3(0, PI, 0)
	add_child(gym_note)
	_front("MECHANIC", Vector3(3.5, 0, 9.6), Color(0.45, 0.8, 0.95))
	# B19: the neighbourhood bar - its door enters a real room
	_front("THE RAIN GLASS", Vector3(-1.2, 0, 9.6), Color(0.95, 0.7, 0.35))
	# the roll-up: a wide light door under a lintel
	var roll := MeshInstance3D.new()
	var rlm := BoxMesh.new()
	rlm.size = Vector3(3.0, 2.6, 0.14)
	var rlmat := StandardMaterial3D.new()
	rlmat.albedo_color = Color(0.42, 0.44, 0.47)
	rlmat.metallic = 0.6
	rlmat.roughness = 0.4
	rlm.material = rlmat
	roll.mesh = rlm
	roll.position = Vector3(3.5, 1.3, 8.95)
	add_child(roll)
	# oil stains by the garage
	for o in [Vector2(2.2, 6.4), Vector2(4.8, 5.8)]:
		var stain := MeshInstance3D.new()
		var stm := QuadMesh.new()
		stm.size = Vector2(1.1, 0.8)
		var stmat := StandardMaterial3D.new()
		stmat.albedo_color = Color(1, 1, 1, 0.8)
		stmat.albedo_texture = _radial(Color(0.02, 0.02, 0.03), 0.75)
		stmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stm.material = stmat
		stain.mesh = stm
		stain.position = Vector3(o.x, 0.015, o.y)
		stain.rotation = Vector3(-PI / 2.0, 0, randf() * PI)
		stain.add_to_group("decal")
		add_child(stain)
	# the underpass mouth at the east end (bible 6: it connects 2-3)
	_underpass(Vector3(16.5, 0, 0), -1)
	# B18.4: the CC0 street props - awnings over two club fronts, a
	# roadworks patch before the underpass, and a skyscraper silhouette
	# in the back fog
	CLS_Kit.place(self, "kenney_commercial/detail-awning.glb",
			Vector3(-9.0, 2.6, -9.15), 0.0, 5.0)
	CLS_Kit.place(self, "kenney_commercial/detail-awning.glb",
			Vector3(8.5, 2.6, 9.15), PI, 5.0)
	_construction(Vector3(12.5, 0, 3.6), 0.15)
	CLS_Kit.place(self, "kenney_commercial/building-skyscraper-b.glb",
			Vector3(-26.0, 0, -22.0), 0.4, 6.0)


## A roadworks patch: barrier, cones, a work light (Kenney City Kit).
func _construction(pos: Vector3, yaw: float) -> void:
	CLS_Kit.place(self, "kenney_roads/construction-barrier.glb", pos, yaw, 6.0)
	CLS_Kit.place(self, "kenney_roads/construction-cone.glb",
			pos + Vector3(1.5, 0, 0.7), yaw, 5.0)
	CLS_Kit.place(self, "kenney_roads/construction-cone.glb",
			pos + Vector3(-1.3, 0, 1.0), yaw, 5.0)
	CLS_Kit.place(self, "kenney_roads/construction-light.glb",
			pos + Vector3(0.2, 0, -1.3), yaw, 5.0)


# --- block 3: the docks ----------------------------------------------------------


func _foundry() -> void:
	# the underpass exit at the west end
	_underpass(Vector3(-16.5, 0, 0), 1)
	# B18.4: roadworks against the warehouse wall (the dock repairs)
	_construction(Vector3(-6.5, 0, -4.8), -0.1)
	# the warehouse: big, dark, the final choice's door shut for now.
	# B19: the placeholder box gives way to the Kenney industrial kit -
	# two shed segments carry the 26 m volume; the collision, the door
	# group and the signs stay exactly where the story expects them.
	var wh := StaticBody3D.new()
	wh.position = Vector3(2.0, 5.0, -13.0)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(26, 10, 12)
	col.shape = cs
	wh.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(26, 10, 12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.09)
	bm.material = mat
	mesh.mesh = bm
	wh.add_child(mesh)
	add_child(wh)
	# B23: the warehouse's street face carries high industrial windows
	# (dim, cool - the night shift inside), so the volume is not a
	# black slab against the sky
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 99
	for i in 9:
		var lit := wrng.randf() < 0.4
		_window(Vector3(-9.0 + i * 2.8, 7.2, -6.98),
				Vector3.ZERO, lit)
	for i in 5:
		_window(Vector3(-9.0 + i * 2.8, 3.4, -6.98),
				Vector3.ZERO, wrng.randf() < 0.25)
	var sheds := 0
	for seg in [-4.5, 8.5]:
		if CLS_Kit.place_stretch(self, "kenney_industrial/building-l.glb",
				Vector3(seg, 0.0, -13.0), 0.0, 6.25, 5.2, 6.4) != null:
			sheds += 1
	if sheds == 2:
		mesh.visible = false  # the box hides; collision + door + signs stay
	var door := MeshInstance3D.new()
	door.add_to_group("warehouse_door")
	var dm := BoxMesh.new()
	dm.size = Vector3(6.0, 6.5, 0.3)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.3, 0.31, 0.33)
	dmat.metallic = 0.5
	dm.material = dmat
	door.mesh = dm
	door.position = Vector3(2.0, 3.25, -6.85)
	add_child(door)
	var sign := Label3D.new()
	sign.text = "MERIDIAN FREIGHT"
	sign.modulate = Color(0.55, 0.12, 0.16)
	sign.font_size = 56
	sign.position = Vector3(2.0, 7.6, -6.8)
	add_child(sign)
	var keep_out := Label3D.new()
	keep_out.text = "keep out"
	keep_out.modulate = Color(0.8, 0.2, 0.2)
	keep_out.font_size = 40
	keep_out.position = Vector3(2.0, 2.2, -6.8)
	add_child(keep_out)
	# B19: the dock works - a chimney stack, a fuel tank, a truck at the
	# loading wall, stacked cargo (all Kenney industrial / car kit), and
	# a burn barrel by the wall (batch 8's real fire, a slam surface)
	CLS_Kit.place(self, "kenney_industrial/chimney-medium.glb",
			Vector3(-13.0, 0.0, -17.5), 0.0, 2.2)
	CLS_Kit.place(self, "kenney_industrial/detail-tank.glb",
			Vector3(15.2, 0.0, -17.0), 0.5, 2.0)
	CLS_Kit.place(self, "kenney_traffic/truck.glb",
			Vector3(11.5, 0.0, -8.8), PI / 2.0, 1.35)
	for b in [Vector3(-11.5, 0.0, -8.2), Vector3(-10.2, 1.15, -8.2),
			Vector3(-11.0, 0.0, -6.9)]:
		CLS_Kit.place(self, "kenney_traffic/box.glb", b, 0.3, 1.6)
	if Fire != null:
		Fire.burning_barrel(self, Vector3(13.5, 0.0, -8.0))
	# containers on the south side. B19: the plain boxes wear the car
	# kit's textured cargo crates, tinted per the dock palette
	var palette := [Color(0.55, 0.2, 0.12), Color(0.15, 0.4, 0.5),
			Color(0.5, 0.45, 0.15), Color(0.3, 0.3, 0.32)]
	var ci := 0
	for c in [Vector3(-9.0, 1.3, 12.0), Vector3(-4.5, 1.3, 13.2),
			Vector3(-9.0, 3.9, 12.4), Vector3(1.0, 1.3, 12.6),
			Vector3(6.0, 1.3, 13.0)]:
		var cb := StaticBody3D.new()
		cb.position = c
		var cc := CollisionShape3D.new()
		var ccs := BoxShape3D.new()
		ccs.size = Vector3(5.0, 2.6, 2.4)
		cc.shape = ccs
		cb.add_child(cc)
		var cm := MeshInstance3D.new()
		var cmm := BoxMesh.new()
		cmm.size = Vector3(5.0, 2.6, 2.4)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = palette[ci % palette.size()]
		cmm.material = cmat
		cm.mesh = cmm
		cb.add_child(cm)
		add_child(cb)
		var crate := CLS_Kit.place_stretch(self, "kenney_traffic/box.glb",
				c, (0.4 if ci % 2 == 0 else -0.3), 7.0, 3.66, 3.38)
		if crate:
			cm.visible = false
			CLS_Kit.tint(crate, palette[ci % palette.size()], 0.5)
			if ci == 0:
				var stencil := Label3D.new()
				stencil.text = "MERIDIAN"
				stencil.modulate = Color(0.85, 0.8, 0.7, 0.85)
				stencil.font_size = 96
				stencil.position = Vector3(0, 0.15, 1.25)
				crate.add_child(stencil)
		ci += 1
	# the water past the east rail
	var water := MeshInstance3D.new()
	water.name = "Water"
	var wm := BoxMesh.new()
	wm.size = Vector3(40, 0.1, 60)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.02, 0.04, 0.07)
	wmat.metallic = 0.85
	wmat.roughness = 0.25
	wm.material = wmat
	water.mesh = wm
	water.position = Vector3(40, -0.45, 0)
	add_child(water)
	var rail := StaticBody3D.new()
	rail.position = Vector3(19.5, 0.6, 0)
	var rc := CollisionShape3D.new()
	var rcs := BoxShape3D.new()
	rcs.size = Vector3(0.4, 1.2, 30)
	rc.shape = rcs
	rail.add_child(rc)
	var rmesh := MeshInstance3D.new()
	var rmm := BoxMesh.new()
	rmm.size = Vector3(0.3, 1.1, 30)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.25, 0.28, 0.3)
	rmm.material = rmat
	rmesh.mesh = rmm
	rail.add_child(rmesh)
	add_child(rail)
	# the crane silhouette against the water
	var mast := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.0, 16.0, 1.0)
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.04, 0.045, 0.055)
	mm.material = mmat
	mast.mesh = mm
	mast.position = Vector3(34.0, 8.0, -12.0)
	add_child(mast)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(12.0, 0.8, 0.8)
	am.material = mmat
	arm.mesh = am
	arm.position = Vector3(30.0, 15.5, -12.0)
	add_child(arm)


## The underpass mouth: dark walls, a low arch, one hard bulb.
func _underpass(pos: Vector3, facing: float) -> void:
	var g := Node3D.new()
	g.name = "Underpass"
	g.add_to_group("underpass")
	g.position = pos
	g.rotation.y = PI / 2.0 if facing < 0 else -PI / 2.0
	add_child(g)
	for wz in [-4.0, 4.0]:
		var wall := StaticBody3D.new()
		wall.position = Vector3(0, 2.0, wz)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(4.5, 4.0, 1.0)
		col.shape = cs
		wall.add_child(col)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.5, 4.0, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.06, 0.06, 0.07)
		bm.material = mat
		mesh.mesh = bm
		wall.add_child(mesh)
		g.add_child(wall)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(4.5, 1.2, 9.0)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.06, 0.06, 0.07)
	lm.material = lmat
	lintel.mesh = lm
	lintel.position = Vector3(0, 4.6, 0)
	g.add_child(lintel)
	var bulb := MeshInstance3D.new()
	var bm2 := QuadMesh.new()
	bm2.size = Vector2(0.3, 0.3)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.85, 0.55)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.75, 0.4)
	bmat.emission_energy_multiplier = 2.0
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm2.material = bmat
	bulb.mesh = bm2
	bulb.position = Vector3(-1.8, 3.6, 0)
	bulb.rotation = Vector3(0, PI / 2.0, 0)
	g.add_child(bulb)
	var tag := Label3D.new()
	tag.text = "UNDERPASS"
	tag.modulate = Color(0.5, 0.55, 0.6)
	tag.font_size = 34
	tag.position = Vector3(-1.6, 4.1, 0)
	tag.rotation = Vector3(0, PI / 2.0, 0)
	g.add_child(tag)
