#!/usr/bin/env python3
## S5.2 part 3 (lookdev) patch: brick on the code massing, real lit
## doorways on the open fronts, club queue people, skyline massing
## behind the club strip. Asserted replaces; fails loudly.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ---------------------------------------------------------------- mat_lib
patch('scripts/world/mat_lib.gd', [(
"""static func surface(name: String, world_size: Vector3) -> StandardMaterial3D:""",
"""## Box-aware surface: uv scaled PER AXIS so walls tile at true
## world scale on every face (surface() assumes a ground plane -
## one axis dominates and wall faces came out with giant bricks).
static func surface_box(name: String, world_size: Vector3) -> StandardMaterial3D:
	var mat := surface(name, world_size)
	var def: Array = DEFS.get(name, [])
	var tile: float = def[4] if def.size() > 4 else 0.0
	if tile > 0.0:
		mat.uv1_scale = Vector3(
				maxf(world_size.x, 0.01) / tile,
					maxf(world_size.y, 0.01) / tile,
					maxf(world_size.z, 0.01) / tile)
	return mat

static func surface(name: String, world_size: Vector3) -> StandardMaterial3D:"""
)])

# ---------------------------------------------------------------- local.gd
patch('scripts/npc/local.gd', [
(
"""	# the name: small, billboarded, readable against the night
	var label := Label3D.new()
	label.text = String(get_meta("who", "LOCAL"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.012
	label.font_size = 48
	label.modulate = Color(1.0, 0.92, 0.75, 0.85)
	label.outline_size = 10
	label.position = Vector3(0, 2.05, 0)
	add_child(label)""",
"""	# the name: small, billboarded, readable against the night
	# (queue-goers and other background bodies pass who="" - no tag)
	if String(get_meta("who", "LOCAL")) != "":
		var label := Label3D.new()
		label.text = String(get_meta("who", "LOCAL"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.012
		label.font_size = 48
		label.modulate = Color(1.0, 0.92, 0.75, 0.85)
		label.outline_size = 10
		label.position = Vector3(0, 2.05, 0)
		add_child(label)
	if has_meta("tint"):
		_apply_tint(_rig, get_meta("tint") as Color)


## Per-instance clothing tint (the pedestrian law: OVERRIDE on the
## mesh instance - surface_set_material mutates the SHARED mesh).
func _apply_tint(rig: Node, tint: Color) -> void:
	if rig == null or tint == Color.WHITE:
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s_idx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s_idx)
			if mat is StandardMaterial3D:
				var clone: StandardMaterial3D = \\
						(mat as StandardMaterial3D).duplicate()
				clone.albedo_color = tint
				(mi as MeshInstance3D).set_surface_override_material(
						s_idx, clone)"""
),
])

# ---------------------------------------------------------- neighbourhood
patch('scripts/areas/neighbourhood.gd', [
(
"""	# the facade mass: two wall slabs + a header, the doorway between
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_solid(front, Vector3(3.4, 5.2, 3.0),
				Vector3(sx[0], 2.6, -1.5), PALETTE.facade)
	_solid(front, Vector3(9.6, 1.4, 3.0), Vector3(0, 5.9, -1.5),
			PALETTE.facade2)""",
"""	# the facade mass: two wall slabs + a header, the doorway between
	# (S5.2p3: BRICK on the code massing - box-scaled so the courses
	# read at true size on the wall faces)
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_brick(front, Vector3(3.4, 5.2, 3.0), Vector3(sx[0], 2.6, -1.5))
	_brick(front, Vector3(9.6, 1.4, 3.0), Vector3(0, 5.9, -1.5))"""
),
(
"""	# the window band: emissive, the shop's glow onto the street
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 2.2, 0.12)
	bm.material = _glow(glow, 0.65)
	band.mesh = bm
	band.position = Vector3(0, 2.4, 0.02)
	band.name = "WindowBand"
	front.add_child(band)""",
"""	# the shopfront: TWO lit window bands flanking the doorway (the
	# old single 7m band covered the door gap - you walked THROUGH
	# the glow; now the door is a real dark opening between lit
	# windows) + jambs/lintel + the warm spill on the pavement
	# (emissive quad, not a light - the mobile light budget)
	for wx in [-2.45, 2.45]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.1, 2.2, 0.12)
		bm.material = _glow(glow, 0.65)
		band.mesh = bm
		band.position = Vector3(wx, 2.4, 0.02)
		band.name = "WindowBand"
		front.add_child(band)
	for jx in [-1.55, 1.55]:
		_solid(front, Vector3(0.34, 4.8, 0.7), Vector3(jx, 2.4, -0.15),
				Color(0.07, 0.06, 0.08))
	_solid(front, Vector3(3.7, 0.55, 0.7), Vector3(0, 4.9, -0.15),
			Color(0.07, 0.06, 0.08))
	var spill := MeshInstance3D.new()
	var sp := QuadMesh.new()
	sp.size = Vector3(2.6, 1.9)
	sp.material = _glow(Color(1.0, 0.72, 0.45), 0.32)
	spill.mesh = sp
	spill.rotation.x = -PI / 2.0
	spill.position = Vector3(0, 0.03, -1.15)
	spill.name = "DoorSpill"
	front.add_child(spill)"""
),
])

# ---------------------------------------------------------- club district
s = open('scripts/areas/club_district.gd').read()
oldml = "const CLS_Vehicle := preload(\"res://scripts/world/vehicle.gd\")"
assert oldml in s
s = s.replace(oldml, oldml + "\nconst CLS_MatLib := preload(\"res://scripts/world/mat_lib.gd\")", 1)
open('scripts/areas/club_district.gd', 'w').write(s)
print("club MatLib preload added")

patch('scripts/areas/club_district.gd', [
# open front: brick + split bands + doorway (street side +Z here)
(
"""	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_solid(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5),
				PALETTE.facade)
	_solid(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5),
			PALETTE.facade2)
	var room := Node3D.new()
	room.name = "Room"
	room.position = Vector3(0, 0, -1.5)""",
"""	# S5.2p3: brick massing + the split-band doorway (street side is
	# rel +Z here - the south fronts are rotated PI, the north face
	# the street at +Z natively)
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_brick(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5))
	_brick(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5))
	var room := Node3D.new()
	room.name = "Room"
	room.position = Vector3(0, 0, -1.5)"""
),
(
"""	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 2.3, 0.12)
	bm.material = _glow(glow, 0.7)
	band.mesh = bm
	band.position = Vector3(0, 2.5, 0.02)
	band.name = "WindowBand"
	front.add_child(band)
	_sign(front, label, glow, Vector3(0, 4.8, 0.2), 42)""",
"""	for wx in [-2.45, 2.45]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.1, 2.3, 0.12)
		bm.material = _glow(glow, 0.7)
		band.mesh = bm
		band.position = Vector3(wx, 2.5, 0.02)
		band.name = "WindowBand"
		front.add_child(band)
	for jx in [-1.55, 1.55]:
		_solid(front, Vector3(0.34, 4.9, 0.7), Vector3(jx, 2.45, 0.15),
				Color(0.07, 0.06, 0.08))
	_solid(front, Vector3(3.7, 0.55, 0.7), Vector3(0, 4.95, 0.15),
			Color(0.07, 0.06, 0.08))
	var spill := MeshInstance3D.new()
	var sp := QuadMesh.new()
	sp.size = Vector3(2.6, 1.9)
	sp.material = _glow(Color(1.0, 0.72, 0.45), 0.32)
	spill.mesh = sp
	spill.rotation.x = -PI / 2.0
	spill.position = Vector3(0, 0.03, 1.15)
	spill.name = "DoorSpill"
	front.add_child(spill)
	_sign(front, label, glow, Vector3(0, 4.8, 0.2), 42)"""
),
# shut front: brick massing
(
"""func _shut_front(front: Node3D, label: String, glow: Color) -> void:
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_solid(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5),
				PALETTE.facade)
	_solid(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5),
			PALETTE.facade2)""",
"""func _shut_front(front: Node3D, label: String, glow: Color) -> void:
	for sx in [[-3.1, 2.6], [3.1, 2.6]]:
		_brick(front, Vector3(3.4, 5.4, 3.0), Vector3(sx[0], 2.7, -1.5))
	_brick(front, Vector3(9.6, 1.5, 3.0), Vector3(0, 6.1, -1.5))"""
),
# queue: real people in the line (the dev note said 'the crowd pass
# gives them people' - the pedestrian system now exists)
(
"""		var body := StaticBody3D.new()
		body.position = post.position
		var cshape := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.24, 1.0, 0.24)""",
"""		# the queue-goers: tinted locals along the rope (S5.2p3 -
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
		s.size = Vector3(0.24, 1.0, 0.24)"""
),
# skyline massing behind the strip (kills the stage-set read)
(
"""	_parked()
	_muscle()
	_life()""",
"""	_parked()
	_muscle()
	_life()
	_skyline()"""
),
(
"""func _fronts(table: Array, side: float) -> void:""",
"""## THE SKYLINE (S5.2p3): tenement silhouettes behind the strip -
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
			var x := -52.0 + b * 30.0 + rng.randf_range(-4.0, 4.0)
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


func _fronts(table: Array, side: float) -> void:"""
),
])

# the brick helper into both areas (append after _solid in each)
for path, anchor in [
        ('scripts/areas/neighbourhood.gd', 'func _sign(parent: Node3D, text: String, col: Color, pos: Vector3,'),
        ('scripts/areas/club_district.gd', 'func _fronts(table: Array, side: float) -> void:')]:
    helper = """## A textured BRICK solid (S5.2p3): _solid's mat path uses the
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


"""
    s = open(path).read()
    if anchor not in s:
        print("MISS anchor in %s" % path); sys.exit(1)
    s = s.replace(anchor, helper + anchor, 1)
    open(path, 'w').write(s)
    print("helper -> %s" % path)
print("ALL PATCHES OK")
