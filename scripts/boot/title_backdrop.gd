extends Node3D

## THE TITLE BACKDROP (rebuild step 12): the city at night, drifting
## past a slow tracking camera - the club avenue's grammar (emissive
## window bands, neon signs, the wet road, the haze) as a looping
## title scene. Menu-cost only: ~20 facade slabs, two lights, fog,
## no colliders, nothing walks. The camera drifts sideways through
## the street's length and wraps - an endless avenue.

const PALETTE := {
	"road": Color(0.05, 0.052, 0.065),
	"facade": Color(0.09, 0.09, 0.115),
	"facade2": Color(0.12, 0.10, 0.13),
	"sodium": Color(1.0, 0.62, 0.28),
	"magenta": Color(0.95, 0.15, 0.5),
	"cyan": Color(0.15, 0.85, 0.88),
}

const BLOCK := 12.0   # the facade cadence
const COUNT := 22     # facade slabs in the loop
const DRIFT := 1.1    # m/s the camera slides


func _ready() -> void:
	_ground()
	_facades()
	_lights_and_air()
	var cam := Camera3D.new()
	cam.name = "TitleCamera"
	cam.position = Vector3(0, 3.2, 14.0)
	cam.fov = 55.0
	# a slight angle down the street for depth
	cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	add_child(cam)


func _process(delta: float) -> void:
	var cam := get_node_or_null("TitleCamera") as Camera3D
	if cam == null:
		return
	cam.position.x += DRIFT * delta
	# the wrap: jump back one full loop's length (seamless - the
	# facades repeat every COUNT * BLOCK / 2 metres on both sides)
	var loop := BLOCK * COUNT / 2.0
	if cam.position.x >= loop:
		cam.position.x -= loop


func _ground() -> void:
	# the wet road + the far glow line
	var road := MeshInstance3D.new()
	road.name = "Road"
	var pm := PlaneMesh.new()
	pm.size = Vector2(BLOCK * COUNT + 40.0, 26.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE.road
	mat.roughness = 0.12
	mat.metallic = 0.2
	pm.material = mat
	road.mesh = pm
	road.position = Vector3(0, 0, 0)
	add_child(road)
	# the horizon glow strip at the street's end
	var glow := MeshInstance3D.new()
	glow.name = "HorizonGlow"
	var gm := BoxMesh.new()
	gm.size = Vector3(BLOCK * COUNT + 40.0, 1.6, 0.5)
	gm.material = _glow(Color(0.5, 0.3, 0.55), 0.5)
	glow.mesh = gm
	glow.position = Vector3(0, 0.8, -60.0)
	add_child(glow)


func _facades() -> void:
	# both sides of the street, the slab + its emissive band + a
	# neon sign every third slab; both sides share one cadence so
	# the camera wrap is seamless
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var i := 0
	for side in [-1.0, 1.0]:
		for b in range(-1, COUNT / 2 + 1):
			var x := b * BLOCK + BLOCK / 2.0
			var h := 7.0 + rng.randf() * 6.0
			var node := Node3D.new()
			node.name = "Slab_%d_%d" % [int(side), b]
			node.position = Vector3(x, 0, side * 13.0)
			add_child(node)
			var slab := MeshInstance3D.new()
			slab.name = "Mass"
			var sm := BoxMesh.new()
			sm.size = Vector3(BLOCK - 1.2, h, 3.4)
			sm.material = _mat(PALETTE.facade if (b + i) % 2 == 0
					else PALETTE.facade2)  # b<0: guard slab
			slab.mesh = sm
			slab.position = Vector3(0, h / 2.0, 0)
			node.add_child(slab)
			# the window band: emissive, the city's light signature
			var band := MeshInstance3D.new()
			band.name = "Band"
			var bm := BoxMesh.new()
			bm.size = Vector3(BLOCK - 2.6, 1.8 + rng.randf() * 0.8, 0.1)
			var col: Color = PALETTE.sodium
			if b % 3 == 0:
				col = PALETTE.magenta
			elif b % 3 == 1:
				col = PALETTE.cyan
			bm.material = _glow(col, 0.55)
			band.mesh = bm
			band.position = Vector3(0, 3.0 + rng.randf() * 2.0,
					-side * 1.75)
			node.add_child(band)
			# a neon sign every third slab
			if b % 3 == 0:
				var sign := Label3D.new()
				sign.name = "Neon"
				sign.text = ["THE VELVET ROOM", "NEON 9", "AURORA",
						"NOODLES", "IRON PALM"][b % 5]
				sign.modulate = col
				sign.font_size = 30
				sign.outline_size = 8
				sign.outline_modulate = Color(0.01, 0.015, 0.04)
				sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sign.position = Vector3(0, h * 0.72, -side * 1.8)
				node.add_child(sign)
			i += 1


func _lights_and_air() -> void:
	# two coloured lights strung down the street + the cold fill
	var a := OmniLight3D.new()
	a.name = "Light_A"
	a.position = Vector3(-18.0, 6.0, 0.0)
	a.light_color = PALETTE.magenta
	a.light_energy = 1.0
	a.omni_range = 24.0
	add_child(a)
	var b := OmniLight3D.new()
	b.name = "Light_B"
	b.position = Vector3(18.0, 6.0, 0.0)
	b.light_color = PALETTE.cyan
	b.light_energy = 1.0
	b.omni_range = 24.0
	add_child(b)
	var fill := DirectionalLight3D.new()
	fill.name = "ColdFill"
	fill.rotation_degrees = Vector3(-55, 25, 0)
	fill.light_color = Color(0.24, 0.22, 0.4)
	fill.light_energy = 0.5
	add_child(fill)
	# the title scene's own air
	var env := WorldEnvironment.new()
	env.name = "TitleAir"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.012, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.045, 0.09)
	e.ambient_light_energy = 1.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.07, 0.05, 0.1)
	e.fog_density = 0.014
	env.environment = e
	add_child(env)


# --- small builders (the area idiom, collider-free) ---------------------


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
