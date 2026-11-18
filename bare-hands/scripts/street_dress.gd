class_name StreetDress
extends Node3D
## Code-built street furniture so the block reads as a place: fire escapes,
## hanging wires, window AC units, individually lit windows, mirror puddles,
## additive light shafts, grates with rising steam, bins, bags and a hydrant.
## Everything is static and cheap; shafts and steam answer to the Quality tier.

const ShaftShader := preload("res://shaders/shaft.gdshader")


func _ready() -> void:
	_fire_escape(Vector3(-10.2, 0.0, -9.0), 3.4, 3)   # BuildingA south face
	_fire_escape(Vector3(-8.4, 0.0, 9.0), 3.0, 2)     # BuildingD north face
	_wires()
	_windows()
	_ac_units()
	_puddles()
	_shafts()
	_grates_and_steam()
	_props()


# --- fire escapes ------------------------------------------------------------


## A zigzag of platforms bolted to a facade, with thin railings.
func _fire_escape(base: Vector3, floor_h: float, floors: int) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.10, 0.105, 0.12)
	metal.roughness = 0.55
	metal.metallic = 0.4
	var escape := Node3D.new()
	escape.name = "FireEscape"
	add_child(escape)
	var side := 1.0
	for f in range(floors):
		var y := 1.2 + f * floor_h
		var plat := _box(Vector3(2.4, 0.07, 0.85), metal)
		plat.position = base + Vector3(0.0, y, side * 0.45)
		escape.add_child(plat)
		# railing: two thin bars + posts
		var rail := _box(Vector3(2.4, 0.05, 0.05), metal)
		rail.position = plat.position + Vector3(0.0, 0.75, side * 0.40)
		escape.add_child(rail)
		for px in [-1.15, 0.0, 1.15]:
			var post := _box(Vector3(0.06, 0.78, 0.06), metal)
			post.position = plat.position + Vector3(px, 0.39, side * 0.40)
			escape.add_child(post)
		# the diagonal stair hint between levels
		if f < floors - 1:
			var stair := _box(Vector3(0.7, 0.06, 0.4), metal)
			stair.position = base + Vector3(0.8, y + floor_h * 0.5, side * 0.25)
			stair.rotation.z = side * 0.85
			escape.add_child(stair)
		side = -side  # alternate: zigzag up the facade


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi


# --- wires between buildings ---------------------------------------------------


func _wires() -> void:
	var cable := StandardMaterial3D.new()
	cable.albedo_color = Color(0.02, 0.02, 0.025)
	cable.roughness = 0.9
	for spec in [
		{"a": Vector3(-4.6, 10.6, -9.0), "b": Vector3(7.6, 9.4, -9.0)},
		{"a": Vector3(-1.0, 11.2, -9.4), "b": Vector3(10.5, 9.8, -9.0)},
		{"a": Vector3(-12.5, 10.8, 9.0), "b": Vector3(-2.0, 9.6, 9.0)},
	]:
		var a: Vector3 = spec["a"]
		var b: Vector3 = spec["b"]
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.015
		cyl.bottom_radius = 0.015
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 4
		cyl.material = cable
		mi.mesh = cyl
		add_child(mi)
		mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)


# --- windows that are lit one by one --------------------------------------------


func _windows() -> void:
	for spec in [
		{"p": Vector3(-12.8, 2.6, -8.95), "c": Color(1.0, 0.72, 0.35), "e": 1.6},
		{"p": Vector3(-6.4, 4.4, -8.95), "c": Color(0.55, 0.75, 0.95), "e": 1.1},
		{"p": Vector3(-11.0, 6.8, -8.95), "c": Color(1.0, 0.8, 0.45), "e": 0.7},
		{"p": Vector3(-12.9, 5.9, 8.95), "c": Color(1.0, 0.68, 0.3), "e": 1.3},
		{"p": Vector3(-3.6, 3.6, 8.95), "c": Color(0.5, 0.8, 0.9), "e": 0.9},
		{"p": Vector3(8.0, 2.9, -8.95), "c": Color(1.0, 0.75, 0.4), "e": 1.2},
	]:
		var p: Vector3 = spec["p"]
		var c: Color = spec["c"]
		var e: float = spec["e"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c * 0.25
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = e
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 0.6)
		qm.material = mat
		mi.mesh = qm
		mi.position = p
		if p.z > 0.0:
			mi.rotation.y = PI  # face north-facing buildings south
		add_child(mi)


func _ac_units() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.19)
	metal.roughness = 0.7
	for p in [Vector3(-10.5, 2.1, -8.9), Vector3(-7.3, 5.3, -8.9),
			Vector3(-9.5, 2.1, 8.9), Vector3(-4.8, 6.7, 8.9)]:
		var mi := _box(Vector3(0.55, 0.4, 0.42), metal)
		mi.position = p
		add_child(mi)


# --- mirror puddles (real specular pop under the neon lights) --------------------


func _puddles() -> void:
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.015, 0.02, 0.035)
	puddle.roughness = 0.03
	puddle.metallic = 1.0
	for spec in [
		{"p": Vector3(7.0, 0.012, -6.0), "r": 1.5},
		{"p": Vector3(-4.0, 0.012, 3.2), "r": 1.1},
		{"p": Vector3(10.5, 0.012, 5.5), "r": 1.7},
		{"p": Vector3(-12.0, 0.012, 4.6), "r": 1.2},
		{"p": Vector3(0.5, 0.012, -2.8), "r": 0.9},
	]:
		var p: Vector3 = spec["p"]
		var r: float = spec["r"]
		var mi := MeshInstance3D.new()
		var cm := QuadMesh.new()
		cm.size = Vector2(r * 2.0, r * 2.0)
		cm.material = puddle
		mi.mesh = cm
		mi.position = p
		mi.rotation.x = -PI / 2.0
		add_child(mi)
		mi.add_to_group("puddle")


# --- additive light shafts (Quality tier toggles these) ---------------------------


func _shafts() -> void:
	_shaft(Vector3(14.0, 1.6, 8.0), Vector2(1.1, 3.2), Color(1.0, 0.62, 0.22))  # kiosk amber
	_shaft(Vector3(-9.0, 1.8, -8.4), Vector2(1.5, 3.6), Color(0.35, 0.85, 1.0))  # window cyan
	_shaft(Vector3(-13.0, 1.5, 6.0), Vector2(1.0, 3.0), Color(1.0, 0.25, 0.2))  # thug street red


func _shaft(pos: Vector3, size: Vector2, tint: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = ShaftShader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", 0.5)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	qm.material = mat
	mi.mesh = qm
	mi.position = pos
	mi.rotation.y = 0.4  # a touch of angle so it never reads as a flat card
	add_child(mi)
	mi.add_to_group("shafts")


# --- grates + steam ---------------------------------------------------------------


func _grates_and_steam() -> void:
	var grate := StandardMaterial3D.new()
	grate.albedo_color = Color(0.05, 0.055, 0.065)
	grate.roughness = 0.4
	grate.metallic = 0.7
	for p in [Vector3(-2.0, 0.016, 2.0), Vector3(5.0, 0.016, -5.5), Vector3(-11.0, 0.016, 6.0)]:
		var mi := _box(Vector3(1.3, 0.03, 0.8), grate)
		mi.position = p
		add_child(mi)
		var steam := _steam(p + Vector3.UP * 0.25)
		add_child(steam)
		steam.add_to_group("steam")


func _steam(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 3.2
	p.position = pos
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.05, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.7, 0.8, 0.10)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.45, 0.55)
	mat.emission_energy_multiplier = 0.25
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.55)
	qm.material = mat
	p.mesh = qm
	p.emitting = true
	return p


# --- sidewalk props ----------------------------------------------------------------


func _props() -> void:
	var bin_mat := StandardMaterial3D.new()
	bin_mat.albedo_color = Color(0.07, 0.09, 0.08)
	bin_mat.roughness = 0.8
	for p in [Vector3(-3.4, 0.0, -8.3), Vector3(12.8, 0.0, -7.9)]:
		var body := StaticBody3D.new()
		body.position = p
		add_child(body)
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.35
		cs.height = 0.95
		shape.shape = cs
		shape.position = Vector3.UP * 0.48
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.28
		cm.height = 0.95
		cm.material = bin_mat
		mi.mesh = cm
		mi.position = Vector3.UP * 0.48
		body.add_child(mi)
		var rim := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.35
		rm.bottom_radius = 0.35
		rm.height = 0.06
		rm.material = bin_mat
		rim.mesh = rm
		rim.position = Vector3.UP * 0.95
		body.add_child(rim)
	# squashed bin bags beside the bins
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.04, 0.04, 0.045)
	bag_mat.roughness = 0.95
	for spec in [
		{"p": Vector3(-2.9, 0.14, -8.4), "s": Vector3(0.45, 0.3, 0.35)},
		{"p": Vector3(-2.7, 0.11, -8.05), "s": Vector3(0.3, 0.22, 0.28)},
		{"p": Vector3(13.2, 0.12, -8.2), "s": Vector3(0.35, 0.25, 0.3)},
	]:
		var mi := _box(spec["s"], bag_mat)
		mi.position = spec["p"]
		add_child(mi)
	# a hydrant on the north sidewalk
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.35, 0.05, 0.04)
	red.roughness = 0.5
	var hydrant := StaticBody3D.new()
	hydrant.position = Vector3(3.8, 0.0, 8.3)
	add_child(hydrant)
	var hs := CollisionShape3D.new()
	var hcs := CylinderShape3D.new()
	hcs.radius = 0.16
	hcs.height = 0.6
	hs.shape = hcs
	hs.position = Vector3.UP * 0.3
	hydrant.add_child(hs)
	var hm := MeshInstance3D.new()
	var hcm := CylinderMesh.new()
	hcm.top_radius = 0.13
	hcm.bottom_radius = 0.16
	hcm.height = 0.6
	hcm.material = red
	hm.mesh = hcm
	hm.position = Vector3.UP * 0.3
	hydrant.add_child(hm)
	var cap := MeshInstance3D.new()
	var capm := SphereMesh.new()
	capm.radius = 0.13
	capm.height = 0.2
	capm.material = red
	cap.mesh = capm
	cap.position = Vector3.UP * 0.62
	hydrant.add_child(cap)
