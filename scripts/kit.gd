extends Object

## B18.4: the CC0 kit layer. Kenney City Kit and Car Kit models (all
## CC0 1.0 - assets/kits/LICENSE-Kenney-CC0.txt) take over from the
## code-built placeholder boxes. Every call degrades to null when a GLB
## is not importable yet (a fresh import still running): the caller
## keeps its readable code-built fallback, so a missing kit can never
## abort the street, the fight or the boot - the same contract UalBind
## gives the animations.
##
## The kits are Kenney-normalised: every model fits a ~1 m cube, so each
## placement states its own scale. Buildings stretch non-uniformly onto
## their plot (footprint x/z, height y); the sedan is already in metres.

const DIR := "res://assets/kits/"

## Kenney-normalised model sizes (x, y, z) - measured by
## tools/kits_report.py from the GLB accessor bounds. The placement math
## reads these instead of instantiating scenes just to measure them.
const DIMS := {
	"kenney_cars/sedan.glb": Vector3(1.5, 1.45, 2.55),
	"kenney_cars/taxi.glb": Vector3(1.5, 1.65, 2.75),
	"kenney_city/building-garage.glb": Vector3(1.0, 0.55, 1.0),
	"kenney_city/building-small-a.glb": Vector3(1.0, 0.95, 1.0),
	"kenney_city/building-small-b.glb": Vector3(1.0, 1.63, 1.0),
	"kenney_city/building-small-c.glb": Vector3(1.0, 1.75, 1.0),
	"kenney_city/building-small-d.glb": Vector3(1.0, 1.0, 1.05),
	"kenney_city/pavement.glb": Vector3(1.0, 0.06, 1.0),
	"kenney_commercial/building-b.glb": Vector3(0.97, 1.29, 0.94),
	"kenney_commercial/building-c.glb": Vector3(0.88, 0.89, 1.09),
	"kenney_commercial/building-d.glb": Vector3(0.84, 1.29, 0.9),
	"kenney_commercial/building-e.glb": Vector3(1.64, 0.89, 1.01),
	"kenney_commercial/building-f.glb": Vector3(0.84, 1.69, 1.03),
	"kenney_commercial/building-g.glb": Vector3(0.97, 1.69, 0.92),
	"kenney_commercial/building-skyscraper-b.glb": Vector3(1.36, 4.48, 1.36),
	"kenney_commercial/detail-awning.glb": Vector3(0.4, 0.4, 0.15),
	"kenney_commercial/detail-overhang.glb": Vector3(0.5, 0.4, 0.2),
	"kenney_roads/construction-barrier.glb": Vector3(0.1, 0.12, 0.22),
	"kenney_roads/construction-cone.glb": Vector3(0.08, 0.09, 0.08),
	"kenney_roads/construction-light.glb": Vector3(0.08, 0.23, 0.08),
	"kenney_roads/light-curved-double.glb": Vector3(0.05, 0.67, 0.4),
	"kenney_roads/light-square.glb": Vector3(0.05, 0.6, 0.24),
	"kenney_roads/road-bend-sidewalk.glb": Vector3(1.0, 0.02, 1.0),
	"kenney_roads/road-bend.glb": Vector3(1.0, 0.02, 1.0),
	"kenney_roads/road-curve-pavement.glb": Vector3(2.0, 0.02, 2.0),
	"kenney_roads/road-intersection.glb": Vector3(1.0, 0.02, 1.0),
	"kenney_roads/road-straight.glb": Vector3(1.0, 0.02, 1.0),
	# B19 kits (real-scale metres for furniture/food; the city kits stay
	# Kenney-normalised ~1-2.5 m blocks - dims from tools/kits_report.py)
	"kenney_industrial/building-a.glb": Vector3(2.08, 1.47, 1.24),
	"kenney_industrial/building-l.glb": Vector3(2.08, 1.92, 1.87),
	"kenney_industrial/chimney-medium.glb": Vector3(0.45, 1.92, 0.45),
	"kenney_industrial/chimney-large.glb": Vector3(1.0, 1.7, 1.0),
	"kenney_industrial/detail-tank.glb": Vector3(0.85, 0.42, 0.52),
	"kenney_suburban/building-type-a.glb": Vector3(1.3, 0.83, 1.03),
	"kenney_suburban/building-type-b.glb": Vector3(1.83, 1.14, 1.14),
	"kenney_suburban/building-type-c.glb": Vector3(1.29, 1.03, 1.03),
	"kenney_suburban/building-type-d.glb": Vector3(1.76, 1.24, 1.03),
	"kenney_traffic/police.glb": Vector3(1.5, 1.4, 2.9),
	"kenney_traffic/suv.glb": Vector3(1.5, 1.4, 2.55),
	"kenney_traffic/hatchback-sports.glb": Vector3(1.3, 1.25, 2.85),
	"kenney_traffic/van.glb": Vector3(1.5, 1.45, 2.75),
	"kenney_traffic/truck.glb": Vector3(1.5, 1.45, 2.95),
	"kenney_traffic/box.glb": Vector3(0.71, 0.71, 0.71),
	"kenney_furniture/bedSingle.glb": Vector3(1.62, 0.51, 1.89),
	"kenney_furniture/bedDouble.glb": Vector3(1.89, 0.51, 1.89),
	"kenney_furniture/sideTable.glb": Vector3(0.53, 0.38, 0.22),
	"kenney_furniture/sideTableDrawers.glb": Vector3(0.53, 0.38, 0.39),
	"kenney_furniture/chairDesk.glb": Vector3(0.48, 0.42, 0.44),
	"kenney_furniture/chair.glb": Vector3(0.48, 0.42, 0.44),
	"kenney_furniture/chairRounded.glb": Vector3(0.48, 0.42, 0.44),
	"kenney_furniture/stoolBar.glb": Vector3(0.27, 0.43, 0.23),
	"kenney_furniture/table.glb": Vector3(0.73, 0.38, 0.56),
	"kenney_furniture/tableRound.glb": Vector3(0.69, 0.37, 0.8),
	"kenney_furniture/tableCloth.glb": Vector3(0.73, 0.38, 0.56),
	"kenney_furniture/tableCross.glb": Vector3(0.73, 0.38, 0.56),
	"kenney_furniture/kitchenBar.glb": Vector3(0.43, 0.42, 0.21),
	"kenney_furniture/kitchenBarEnd.glb": Vector3(0.1, 0.42, 0.21),
	"kenney_furniture/bookcaseClosed.glb": Vector3(0.4, 0.85, 0.25),
	"kenney_furniture/bookcaseOpen.glb": Vector3(0.4, 0.85, 0.25),
	"kenney_furniture/televisionModern.glb": Vector3(0.68, 0.45, 0.13),
	"kenney_furniture/televisionVintage.glb": Vector3(0.68, 0.45, 0.13),
	"kenney_furniture/cabinetTelevision.glb": Vector3(0.73, 0.38, 0.56),
	"kenney_furniture/loungeSofa.glb": Vector3(0.98, 0.46, 0.41),
	"kenney_furniture/loungeSofaLong.glb": Vector3(0.98, 0.46, 0.82),
	"kenney_furniture/lampSquareFloor.glb": Vector3(0.12, 0.86, 0.12),
	"kenney_furniture/lampRoundFloor.glb": Vector3(0.12, 0.86, 0.12),
	"kenney_furniture/lampWall.glb": Vector3(0.12, 0.3, 0.12),
	"kenney_furniture/pottedPlant.glb": Vector3(0.25, 0.54, 0.29),
	"kenney_furniture/plantSmall1.glb": Vector3(0.25, 0.4, 0.25),
	"kenney_furniture/cardboardBoxClosed.glb": Vector3(0.21, 0.28, 0.21),
	"kenney_furniture/cardboardBoxOpen.glb": Vector3(0.21, 0.28, 0.21),
	"kenney_furniture/trashcan.glb": Vector3(0.5, 0.91, 0.44),
	"kenney_furniture/desk.glb": Vector3(0.73, 0.38, 0.56),
	"kenney_furniture/coatRackStanding.glb": Vector3(0.3, 1.1, 0.3),
	"kenney_furniture/rugSquare.glb": Vector3(1.0, 0.02, 1.0),
	"kenney_furniture/tableCoffee.glb": Vector3(0.69, 0.37, 0.8),
	"kenney_furniture/wallDoorway.glb": Vector3(1.0, 1.0, 0.1),
	"kenney_furniture/wallWindow.glb": Vector3(1.0, 1.0, 0.1),
	"kenney_food/skewer.glb": Vector3(0.6, 0.07, 0.06),
	"kenney_food/cup-coffee.glb": Vector3(0.1, 0.12, 0.1),
	"kenney_food/pan-stew.glb": Vector3(0.4, 0.15, 0.4),
	"kenney_food/frying-pan-lid.glb": Vector3(0.4, 0.12, 0.4),
	"kenney_food/pot-lid.glb": Vector3(0.66, 0.12, 0.63),
	"kenney_food/bottle-ketchup.glb": Vector3(0.08, 0.25, 0.08),
	"kenney_food/cabbage.glb": Vector3(0.2, 0.2, 0.2),
	"kenney_food/loaf-round.glb": Vector3(0.25, 0.15, 0.25),
}

static var _scenes := {}
static var _warned := {}
static var _next_id := 0  # siblings must never collide: Godot renames
		 # duplicates to @Node3D@N@ and every name-based lookup breaks


static func height(rel: String) -> float:
	return DIMS.get(rel, Vector3.ONE).y


static func depth(rel: String) -> float:
	return DIMS.get(rel, Vector3.ONE).z


## The imported PackedScene, or null (fresh import / missing kit).
static func scene(rel: String) -> PackedScene:
	if _scenes.has(rel):
		return _scenes[rel]
	var ps: PackedScene = load(DIR + rel)
	if ps == null:
		if not _warned.has(rel):
			_warned[rel] = true
			Log.warn("Kit: %s not importable yet - the code-built fallback stays" % rel)
		return null
	_scenes[rel] = ps
	return ps


## Place a kit model, uniform scale. Returns the instance or null.
static func place(parent: Node, rel: String, pos := Vector3.ZERO,
		yaw := 0.0, s := 1.0) -> Node3D:
	var n := _spawn(parent, rel, pos, yaw)
	if n != null:
		n.scale = Vector3(s, s, s)
	return n


## Place a kit model with a per-axis scale (buildings onto their plot,
## road tiles onto their lane). Returns the instance or null.
static func place_stretch(parent: Node, rel: String, pos := Vector3.ZERO,
		yaw := 0.0, sx := 1.0, sy := 1.0, sz := 1.0) -> Node3D:
	var n := _spawn(parent, rel, pos, yaw)
	if n != null:
		n.scale = Vector3(sx, sy, sz)
	return n


static func _spawn(parent: Node, rel: String, pos: Vector3, yaw: float) -> Node3D:
	var ps := scene(rel)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	# unique name: two lamps on one street must both stay "Kit_light_..."
	# (a collision silently renames the node to @Node3D@N@)
	_next_id += 1
	n.name = "Kit_%s_%d" % [rel.get_file().get_basename().replace("-", "_"), _next_id]
	n.add_to_group("cc0_kit")
	# deferred: street dressing runs inside _ready while the scene is
	# still setting up children - a direct add_child on the busy parent
	# fails and the street silently loses its kits (the B18.4 probe
	# caught it: 14 placed, 1 alive)
	parent.add_child.call_deferred(n)
	n.position = pos
	n.rotation.y = yaw
	cap_emissions(n)
	return n


## True when the kit file imports (tests pin the integration on this).
static func available(rel: String) -> bool:
	return scene(rel) != null


## How many kit models are live under a parent (the DEVICE REPORT fact).
static func count_under(root: Node) -> int:
	return root.get_tree().get_nodes_in_group("cc0_kit").size()


## A row of the same tile as ONE MultiMesh (one draw call however many
## tiles): the Mobile answer for road lanes and pavement runs. Returns
## the MultiMeshInstance3D or null.
static func tile_row(parent: Node, rel: String, positions: Array,
		s := 1.0, yaw := 0.0) -> MultiMeshInstance3D:
	var ps := scene(rel)
	if ps == null:
		return null
	var tmp: Node3D = ps.instantiate()
	# single-mesh GLBs import with the mesh ON the scene root, not under
	# a child - read both cases
	var mesh: Mesh = null
	if tmp is MeshInstance3D:
		mesh = (tmp as MeshInstance3D).mesh
	else:
		for c in tmp.find_children("*", "MeshInstance3D", true, false):
			if (c as MeshInstance3D).mesh != null:
				mesh = (c as MeshInstance3D).mesh
				break
	tmp.free()
	if mesh == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = positions.size()
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
	for i in positions.size():
		mm.set_instance_transform(i,
				Transform3D(basis, (positions[i] as Vector3)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "KitRow_" + rel.get_file().get_basename().replace("-", "_")
	mmi.multimesh = mm
	mmi.add_to_group("cc0_kit")
	parent.add_child.call_deferred(mmi)  # the caller may still be mid-setup
	return mmi



## A curved double-head lamp post with its own warm sodium light. The
## OmniLight joins the tree (so the ambient moth swarms adopt it) and the
## "street_lights" group (so the quality tier can dim it). Returns true
## when placed.
static func lamp(parent: Node, pos: Vector3, side: float, s := 5.2) -> bool:
	var n := place(parent, "kenney_roads/light-curved-double.glb", pos,
			PI if side > 0 else 0.0, s)
	if n == null:
		return false
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)  # warm sodium (ART_BIBLE)
	light.light_energy = 1.5
	light.omni_range = 11.0
	light.position = Vector3(0, 3.3, -side * 1.1)  # head over the road
	light.add_to_group("street_lights")
	n.add_child(light)
	return true


## Tint a placed kit model toward a colour while keeping its colormap:
## every mesh is duplicated so the shared import is never touched (the
## same ownership rule enemy.gd applies to its characters).
static func tint(n: Node3D, color: Color, mix := 0.5) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.mesh = mi.mesh.duplicate()
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate()
				d.albedo_color = d.albedo_color.lerp(color, mix)
				mi.mesh.surface_set_material(i, d)


## Night-read safety (ART_BIBLE): no kit material may keep emission
## above the 1.1 Mobile cap; albedo keeps its authored colormap.
static func cap_emissions(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if m is StandardMaterial3D \
					and (m as StandardMaterial3D).emission_enabled:
				(m as StandardMaterial3D).emission_energy_multiplier = \
						minf((m as StandardMaterial3D).emission_energy_multiplier, 1.1)
