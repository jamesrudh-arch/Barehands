extends Node3D
const CLS_MapData := preload("res://scripts/map_data.gd")

## LEVERAGE B18 (Part 6B.3): the 3D objective marker. A tall yellow beam
## over the active objective (or the pinned waypoint), a chevron that
## bobs above it, and a billboard distance label - all no-depth-test so
## they read through buildings, GTA-style. Emission stays at 1.1: bright
## on every renderer, never a white block on Mobile. Also owns the
## OPTIONAL ground route line (Settings route_line_3d, OFF by default):
## a flat unshaded ribbon along the street route, rebuilt at most twice
## a second.

var _beam: MeshInstance3D
var _chevron: MeshInstance3D
var _label: Label3D
var _ribbon: MeshInstance3D
var _t := 0.0
var _route: PackedVector2Array = PackedVector2Array()
var _acc := 0.0


func _ready() -> void:
	add_to_group("objective_marker")

	_beam = MeshInstance3D.new()
	_beam.name = "ObjectiveBeam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.18
	cyl.height = 12.0
	var bm := StandardMaterial3D.new()
	# B18.3 6C.4h: the destination marker wears the guide's colour
	# (green, cyan alt) - yellow stays for pickups only
	var gc := Color(0.25, 1.0, 0.5) \
			if str(Settings.value("guide_colour")) != "cyan" \
			else Color(0.3, 0.95, 1.0)
	bm.albedo_color = Color(gc, 0.34)
	bm.emission_enabled = true
	bm.emission = gc
	bm.emission_energy_multiplier = 1.1
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	cyl.material = bm
	_beam.mesh = cyl
	_beam.position = Vector3(0, 6.0, 0)
	add_child(_beam)

	_chevron = MeshInstance3D.new()
	_chevron.name = "ObjectiveChevron"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 0.6, 0.9)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.25, 1.0, 0.5, 0.95)
	cm.emission_enabled = true
	cm.emission = Color(0.25, 1.0, 0.5)
	cm.emission_energy_multiplier = 1.1
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.no_depth_test = true
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	prism.material = cm
	_chevron.mesh = prism
	_chevron.position = Vector3(0, 4.4, 0)
	add_child(_chevron)

	_label = Label3D.new()
	_label.name = "ObjectiveDistance"
	_label.modulate = Color(1.0, 0.9, 0.55)
	_label.font_size = 44
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.outline_size = 10
	_label.outline_modulate = Color(0.02, 0.02, 0.03)
	_label.position = Vector3(0, 5.6, 0)
	add_child(_label)

	_ribbon = MeshInstance3D.new()
	_ribbon.name = "RouteRibbon"
	_ribbon.visible = false
	var im := ImmediateMesh.new()
	_ribbon.mesh = im
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.25, 1.0, 0.5, 0.30)
	rm.emission_enabled = true
	rm.emission = Color(0.25, 1.0, 0.5)
	rm.emission_energy_multiplier = 0.8
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.no_depth_test = false
	_ribbon.material_override = rm
	add_child(_ribbon)

	Settings.changed.connect(_on_setting)
	_on_setting("route_line_3d")


func _on_setting(key: String) -> void:
	if key == "route_line_3d":
		_ribbon.visible = bool(Settings.value("route_line_3d")) \
				and not _route.is_empty()


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var nav: Dictionary = CLS_MapData.nav_target()
	if hero == null or nav.is_empty():
		visible = false
		return
	visible = true
	var target: Vector2 = nav["pos"]
	global_position = Vector3(target.x, 0.0, target.y)
	_chevron.position.y = 4.4 + 0.25 * sin(_t * 2.2)
	var dist: float = target.distance_to(
			Vector2(hero.global_position.x, hero.global_position.z))
	_label.text = "%d m" % int(round(dist))
	_label.visible = dist > 6.0
	# the optional ground ribbon, rebuilt at most twice a second
	if _ribbon.visible or bool(Settings.value("route_line_3d")):
		_rebuild_ribbon(hero)


func _rebuild_ribbon(hero: Node3D) -> void:
	var hero_xz := Vector2(hero.global_position.x, hero.global_position.z)
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		return
	var path := CLS_MapData.route(hero_xz, nav["pos"])
	if path.size() < 2:
		return
	_route = path
	var im := _ribbon.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	# the ribbon is local to this node (which sits at the target)
	var origin := Vector2(global_position.x, global_position.z)
	for i in range(path.size()):
		var p: Vector2 = path[i]
		var dir: Vector2
		if i == 0:
			dir = path[1] - path[0]
		elif i == path.size() - 1:
			dir = path[i] - path[i - 1]
		else:
			dir = path[i + 1] - path[i - 1]
		dir = dir.normalized()
		var perp := Vector2(-dir.y, dir.x) * 0.22
		var a := p - origin
		im.surface_set_color(Color(0.25, 1.0, 0.5, 0.30))
		im.surface_add_vertex(Vector3(a.x + perp.x, 0.06, a.y + perp.y))
		im.surface_add_vertex(Vector3(a.x - perp.x, 0.06, a.y - perp.y))
	im.surface_end()
