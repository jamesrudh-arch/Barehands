extends Node3D
const CLS_Pickup := preload("res://scripts/pickup.gd")

## B18.3 PART 3C.6: the LOOKDEV strip - every important thing in the
## game under the final lighting, in one place: the cast (hero stand-in
## with the locator treatment, all five enemy kinds with their edges
## and tags), the car with its lamps, a neon sign, the apartment door,
## and the full pickup row. Reached from the debug menu; BACK returns
## to the full game. The gallery sits far off the world axis (x = -780)
## so it can never collide with the street or the interiors.

const X := -780.0


func _ready() -> void:
	_environment()
	_floor()
	_lights()
	var cam := Camera3D.new()
	cam.position = Vector3(X + 14.0, 3.2, 14.0)
	cam.look_at_from_position(cam.position, Vector3(X + 14.0, 1.0, 0.0), Vector3.UP)
	add_child(cam)
	cam.make_current()
	_cast_row()
	_car()
	_sign_and_door()
	_pickup_row()
	_back_button()
	Log.info("LookDev: gallery ready (x=%.0f)" % X)


func _environment() -> void:
	var we := WorldEnvironment.new()
	we.add_to_group("world_env")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.26)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.38
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.02
	we.environment = env
	add_child(we)


func _floor() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.2, 26.0)
	col.shape = box
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(40.0, 0.2, 26.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.045, 0.055, 0.08)
	mat.roughness = 0.25  # wet
	bm.material = mat
	mesh.mesh = bm
	mesh.position = Vector3(0, -0.1, 0)
	body.add_child(mesh)


func _lights() -> void:
	for spec in [
		{"p": Vector3(X + 4, 4.6, 3), "c": Color(1.0, 0.72, 0.4), "e": 2.4},
		{"p": Vector3(X + 14, 4.6, 3), "c": Color(0.7, 0.85, 1.0), "e": 2.0},
		{"p": Vector3(X + 24, 4.6, 3), "c": Color(1.0, 0.5, 0.8), "e": 1.8},
	]:
		var l := OmniLight3D.new()
		l.position = spec["p"]
		l.light_color = spec["c"]
		l.light_energy = spec["e"]
		l.omni_range = 14.0
		add_child(l)


func _cast_row() -> void:
	# the hero stand-in: the dressed-rig treatment + locator ring
	var hero := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.5
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.16, 0.17, 0.2)
	hm.emission_enabled = true
	hm.emission = Color(0.4, 0.9, 1.0)
	hm.emission_energy_multiplier = 0.12
	cap.material = hm
	hero.mesh = cap
	hero.position = Vector3(X + 1.5, 0.85, 0)
	add_child(hero)
	var ring := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(1.1, 1.1)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.35, 0.95, 1.0, 0.35)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tq.material = rm
	ring.mesh = tq
	ring.rotation = Vector3(-PI / 2.0, 0, 0)
	ring.position = Vector3(X + 1.5, 0.03, 0)
	add_child(ring)
	_label("HERO", Vector3(X + 1.5, 2.1, 0))
	# all five enemy kinds, spaced with their tags
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	for k in 5:
		var e := enemy_scene.instantiate()
		e.set("kind", k)
		e.position = Vector3(X + 4.0 + float(k) * 2.6, 0.02, 0)
		add_child(e)
		_label(["DUMMY", "MUSCLE", "COLLECTOR", "CREW", "BOSS"][k],
				Vector3(X + 4.0 + float(k) * 2.6, 2.1, 0))


func _car() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.13, 0.19, 0.16)
	paint.roughness = 0.3
	paint.metallic = 0.5
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.2, 0.55, 1.75)
	bm.material = paint
	body.mesh = bm
	body.position = Vector3(X + 8.0, 0.55, -6.0)
	add_child(body)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.1, 0.5, 1.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.03, 0.05)
	glass.roughness = 0.1
	cm.material = glass
	cabin.mesh = cm
	cabin.position = Vector3(X + 7.75, 1.05, -6.0)
	add_child(cabin)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.88, 0.65)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.6)
	lamp.emission_energy_multiplier = 1.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hz in [-0.55, 0.55]:
		var head := MeshInstance3D.new()
		var hm2 := BoxMesh.new()
		hm2.size = Vector3(0.06, 0.12, 0.3)
		hm2.material = lamp
		head.mesh = hm2
		head.position = Vector3(X + 10.11, 0.62, -6.0 + hz)
		add_child(head)
	_label("THE CAR", Vector3(X + 8.0, 2.1, -6.0))


func _sign_and_door() -> void:
	# a neon sign: dark frame + lettering + the emissive face (capped)
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 1.1)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.2, 0.75)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.18, 0.7)
	fm.emission_energy_multiplier = 1.05
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = fm
	face.mesh = q
	face.position = Vector3(X + 18.5, 3.0, -5.0)
	add_child(face)
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(2.6, 1.3, 0.08)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.05, 0.05, 0.07)
	fb.material = fmat
	frame.mesh = fb
	frame.position = Vector3(X + 18.5, 3.0, -5.08)
	add_child(frame)
	_label("THE SIGN", Vector3(X + 18.5, 4.0, -5.0))
	# the door: glowing frame + dark leaf + handle
	var df := MeshInstance3D.new()
	var dq := BoxMesh.new()
	dq.size = Vector3(1.7, 2.5, 0.12)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.1, 0.12)
	dm.emission_enabled = true
	dm.emission = Color(0.25, 0.95, 0.85)
	dm.emission_energy_multiplier = 1.1
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dq.material = dm
	df.mesh = dq
	df.position = Vector3(X + 22.5, 1.25, -5.0)
	add_child(df)
	_label("THE DOOR", Vector3(X + 22.5, 2.9, -5.0))


func _pickup_row() -> void:
	var kinds := ["pipe", "bat", "bottle", "plank", "chair_leg",
			"cash", "health", "painkillers", "key", "burner"]
	for i in kinds.size():
		var p := CLS_Pickup.new()
		p.setup(kinds[i], 40)
		p.position = Vector3(X + 2.0 + float(i) * 2.2, 0.0, 6.5)
		add_child(p)
	_label("THE PICKUPS", Vector3(X + 12.0, 2.2, 6.5))


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = Color(0.8, 0.9, 0.95, 0.9)
	l.font_size = 40
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.outline_modulate = Color(0.02, 0.02, 0.03)
	l.position = pos
	add_child(l)


func _back_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var b := Button.new()
	b.text = "BACK TO THE GAME"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(280, 64)
	b.add_theme_font_size_override("font_size", 18)
	b.position = Vector2(24, 24)
	b.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layer.add_child(b)
	var stamp := Label.new()
	stamp.text = BuildStamp.block()
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.position = Vector2(24, 100)
	layer.add_child(stamp)
