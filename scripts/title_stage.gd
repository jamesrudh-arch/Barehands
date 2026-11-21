extends Node3D
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")

## B18.3 PART 0B (BUG 17): the TITLE KEY ART - a real-time 3D scene in
## the big-open-world-cover style. A huge EXTRUDED LEVERAGE (TextMesh)
## rises out of the wet ground (a mirrored dark copy fakes the
## reflection - no SSR, no probe, phone-cheap), the cast stands behind
## it in layers (three bosses at the back in the fog, the crew row
## behind the logo, the HERO front-right in a fighting stance with lit
## eyes), magenta rims from the left, cyan from the right, a slow
## camera drift. If the TextMesh comes out empty (a font failure), the
## stage reports 2D and the start sequence keeps its drawn wordmark -
## the title screen always looks intentional. Log which mode runs.

const STAGE_X := -780.0

var mode := "3d"  # "3d" or "2d fallback"
var _cam: Camera3D
var _logo: MeshInstance3D
var _logo_mirror: MeshInstance3D
var _sweep: OmniLight3D
var _t := 0.0
var _active := false


func _ready() -> void:
	add_to_group("title_stage")
	visible = false
	position = Vector3(STAGE_X, 0.0, 0.0)


## The start sequence calls this when the title card begins.
func show_title() -> void:
	if not _active:
		_build()
	_active = true
	visible = true
	if _cam:
		_cam.make_current()
	if _logo:
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_logo, "position:y", 0.0, 1.4).from(-4.0)
		if _logo_mirror:
			tw.parallel().tween_property(_logo_mirror, "position:y",
					-0.02, 1.4).from(-8.02)
		tw.finished.connect(func():
			Sound.play("sub_hit_0", -8.0, 0.6)
			Sound.play_v("bell_heavy", 2, -14.0, 0.55))


## PLAY / CONTINUE: hand the view back to the follow camera.
func hide_title() -> void:
	_active = false
	visible = false
	var cam := get_tree().get_first_node_in_group("camera") as Camera3D
	if cam:
		cam.make_current()


func is_3d() -> bool:
	return mode == "3d" and _logo != null


func _build() -> void:
	_environment()
	_ground()
	_lights()
	_build_logo()
	_build_cast()
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 2.6, 17.5)
	_cam.fov = 42.0
	add_child(_cam)


func _environment() -> void:
	var we := WorldEnvironment.new()
	we.add_to_group("world_env")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.16, 0.22)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.02
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)


func _ground() -> void:
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.045, 0.06)
	mat.roughness = 0.18  # wet
	mat.metallic = 0.2
	pm.material = mat
	mesh.mesh = pm
	add_child(mesh)


func _lights() -> void:
	# magenta from the left, cyan from the right, a soft key on the hero
	for spec in [
		{"p": Vector3(-9, 3.4, 5), "c": Color(1.0, 0.18, 0.72), "e": 3.0},
		{"p": Vector3(9, 3.4, 5), "c": Color(0.16, 0.9, 1.0), "e": 3.0},
		{"p": Vector3(5.2, 3.0, 6.5), "c": Color(0.9, 0.85, 0.8), "e": 1.2},
	]:
		var l := OmniLight3D.new()
		l.position = spec["p"]
		l.light_color = spec["c"]
		l.light_energy = spec["e"]
		l.omni_range = 22.0
		add_child(l)
	# the slow reflected sweep across the logo
	_sweep = OmniLight3D.new()
	_sweep.light_color = Color(0.85, 0.95, 1.0)
	_sweep.light_energy = 2.0
	_sweep.omni_range = 14.0
	_sweep.position = Vector3(-8, 1.2, 3.5)
	add_child(_sweep)


func _build_logo() -> void:
	var tm := TextMesh.new()
	tm.text = "LEVERAGE"
	tm.depth = 0.55
	tm.font_size = 64
	tm.curve_step = 4.0
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Black", "Arial", "sans-serif"])
	tm.font = f
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.75, 0.8)
	mat.metallic = 1.0
	mat.roughness = 0.22
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.55, 0.6)
	mat.emission_energy_multiplier = 0.08
	tm.material = mat
	_logo = MeshInstance3D.new()
	_logo.mesh = tm
	# centred on the stage, letters standing on the ground
	var aabb := tm.get_aabb()
	_logo.position = Vector3(-aabb.size.x * 0.5, 1.6, 0.0)
	add_child(_logo)
	if aabb.size.x < 0.5:
		mode = "2d fallback"
		Log.warn("TitleStage: TextMesh came out empty - the 2D wordmark carries the title")
		return
	# the fake wet reflection: a mirrored dark copy under the ground
	var mm := tm.duplicate() as TextMesh
	var mmat := mat.duplicate() as StandardMaterial3D
	mmat.albedo_color = Color(0.05, 0.06, 0.08)
	mmat.emission_energy_multiplier = 0.03
	mmat.metallic = 0.4
	mmat.roughness = 0.5
	mm.material = mmat
	_logo_mirror = MeshInstance3D.new()
	_logo_mirror.mesh = mm
	_logo_mirror.scale = Vector3(1, -1, 1)
	_logo_mirror.position = Vector3(-aabb.size.x * 0.5, -1.62, 0.0)
	add_child(_logo_mirror)


## A posed figure - B19: a REAL Universal Base Character (idle clip
## running, never a T-pose) carrying the fog-silhouette treatment: the
## emissive body material rides on top as an override, so the cast
## reads as shaped silhouettes with a rim, not capsules. Distinct per
## role by colour, scale, model and silhouette props.
func _figure(pos: Vector3, colour: Color, opts := {}) -> Node3D:
	var fig := Node3D.new()
	fig.position = pos
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = colour
	body_mat.emission_enabled = true
	body_mat.emission = colour * 0.8
	body_mat.emission_energy_multiplier = 0.07
	var rig := CLS_NpcRig.new()
	rig.build([opts.get("model",
			"res://assets/hero/Superhero_Male_FullBody.gltf")],
			colour, colour * 0.4, "Idle",
			float(opts.get("idle_speed", 0.85)))
	var s := float(opts.get("scale", 1.0))
	rig.scale = Vector3(s, s, s)
	# the silhouette treatment: one emissive material over every surface
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = body_mat
	fig.add_child(rig)
	if opts.get("stance", "") == "fight":
		# the lit eyes (the noir hero read)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var eq := QuadMesh.new()
			eq.size = Vector2(0.05, 0.03)
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(0.85, 0.98, 1.0)
			em.emission_enabled = true
			em.emission = Color(0.7, 0.95, 1.0)
			em.emission_energy_multiplier = 1.0
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			eq.material = em
			eye.mesh = eq
			eye.position = Vector3(side * 0.055, 1.62 * s, 0.12)
			fig.add_child(eye)
	elif opts.get("hat", false):
		var brim := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.22
		bc.bottom_radius = 0.24
		bc.height = 0.05
		bc.material = body_mat
		brim.mesh = bc
		brim.position = Vector3(0, 1.72 * s, 0)
		fig.add_child(brim)
	return fig


func _build_cast() -> void:
	# BACK ROW: the three bosses, raised, back in the fog - each a real
	# UBC character now (B19), silhouetted by the emissive override
	add_child(_figure(Vector3(-3.4, 0.6, -7.5), Color(0.10, 0.10, 0.13),
			{"hat": true, "scale": 1.05,
				"model": "res://assets/cast/Male_Knight_Body_Armor.gltf"}))  # the Family boss
	add_child(_figure(Vector3(0.0, 0.6, -8.5), Color(0.12, 0.16, 0.22),
			{"broad": true, "scale": 1.0,
				"model": "res://assets/cast/Superhero_Female_FullBody.gltf"}))  # the Corporation
	add_child(_figure(Vector3(3.4, 0.6, -7.5), Color(0.28, 0.10, 0.10),
			{"scale": 1.0,
				"model": "res://assets/cast/Male_Peasant_Body.gltf"}))  # the Crew leader
	# MIDDLE ROW: the crew behind the logo, evenly spaced - mixed bodies
	# so no two neighbours wear the same silhouette
	var crew_colours := [Color(0.3, 0.24, 0.18), Color(0.16, 0.2, 0.26),
			Color(0.24, 0.14, 0.12), Color(0.36, 0.3, 0.16),
			Color(0.14, 0.24, 0.18), Color(0.2, 0.16, 0.26)]
	var crew_models := ["res://assets/cast/Male_Peasant_Body.gltf",
			"res://assets/cast/Female_Ranger_Body.gltf",
			"res://assets/cast/Male_Knight_Body_Armor.gltf",
			"res://assets/hero/Superhero_Male_FullBody.gltf",
			"res://assets/cast/Superhero_Female_FullBody.gltf",
			"res://assets/cast/Male_Peasant_Body.gltf"]
	for i in crew_colours.size():
		var x := -7.5 + float(i) * 3.0
		add_child(_figure(Vector3(x, 0.0, -3.0), crew_colours[i],
				{"scale": 0.92, "model": crew_models[i]}))
	# FRONT RIGHT: the hero, larger, fighting stance, eyes lit - the
	# hero's own model
	add_child(_figure(Vector3(5.2, 0.0, 4.2), Color(0.14, 0.15, 0.19),
			{"stance": "fight", "scale": 1.25,
				"model": "res://assets/hero/Superhero_Male_FullBody.gltf"}))
	Log.info("TitleStage: cast placed (real UBC characters, idle clips running)")


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	# the slow camera drift (a gentle dolly, no post-processing)
	if _cam:
		_cam.position.x = 0.0 + 1.4 * sin(_t * 0.16)
		_cam.position.y = 2.6 + 0.25 * sin(_t * 0.23)
		_cam.look_at_from_position(_cam.position, Vector3(0, 1.5, 0), Vector3.UP)
	# the light sweep crosses the logo every ~8 s
	if _sweep:
		var f := fmod(_t, 8.0) / 8.0
		_sweep.position.x = -8.0 + f * 16.0
		_sweep.light_energy = 1.6 * sin(f * PI)
