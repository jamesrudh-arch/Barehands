extends Node

## THE NIGHT LOOK (S5.16 art pass): the city's shared cinematic
## grade + neon signage + lamp cones. One library, applied by every
## area - the audit's finding was that the city read as "flat
## untextured" even WITH the PBR library live: the grade had no
## GLOW (emissions rendered as flat rectangles, no halo), no
## contrast/saturation (filmic + exposure alone = mush), and the
## lamps lit nothing between their heads and the ground.
## Glow works on EVERY renderer incl. Compatibility (Godot docs:
## "Glow, tonemapping, depth/height fog... work everywhere").

## THE GRADE: ACES + glow + a noir contrast/saturation lift.
## Applied ON TOP of each area's authored fog/ambient - the
## worldsim still modulates fog/ambient per phase above it.
static func grade(e: Environment, exposure := 1.3) -> void:
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	# ACES renders ~20% darker than FILMIC at the same exposure -
	# the areas were authored on filmic numbers
	e.tonemap_exposure = exposure - 0.15
	e.tonemap_white = 1.0
	# the bloom: only HDR sources bloom (emissives + hot
	# speculars), not the lit concrete
	e.glow_enabled = true
	# VLM-tuned (S5.16): the road hotspot blew out at 0.85/1.2 -
	# raise the threshold so ONLY true HDR pixels (lamps, neon)
	# bloom, and pull the strength back one notch
	e.glow_intensity = 0.45
	e.glow_strength = 0.8
	e.glow_bloom = 0.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_hdr_threshold = 1.05
	e.glow_hdr_scale = 1.0
	# two bloom radii: a tight inner halo + a wide city haze
	e.set_glow_level(3, 0.45)
	e.set_glow_level(5, 0.2)
	# the grade: lift contrast so silhouettes read, sat so the
	# sodium/magenta split pops - noir is TEAL shadows vs WARM
	# sources, not gray
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.04
	e.adjustment_saturation = 1.06
	# S5.16 GRADED DEPTH: aerial perspective mixes the sky colour
	# into distance + a height plane hugs the street - fog fades
	# WITH distance instead of a uniform wash (the VLM's
	# "buildings sit at the same contrast as midground")
	e.fog_aerial_perspective = 0.35
	e.fog_sky_affect = 0.1
	e.fog_height = 1.2
	e.fog_height_density = 0.06


## A NEON SIGN: bright text + a thin emissive tube frame behind it
## (the tube blooms - Label3D text alone is LDR and stays flat).
## `flicker` pulses one sign: the street's living detail.
static func sign(parent: Node3D, text: String, pos: Vector3,
		yaw: float, col: Color, font_size := 56,
		flicker := false) -> Label3D:
	var holder := Node3D.new()
	holder.name = "Neon_" + text.substr(0, 12).replace(" ", "_")
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	# the tube frame: emissive quad scaled to the lettering - street
	# signs carry ~0.7 m letters (readable at 25 m; 0.44 m ones
	# blurred to color panels in the gate)
	var tube := MeshInstance3D.new()
	var tm := QuadMesh.new()
	var letter_w := font_size * 0.00115
	tm.size = Vector2(text.length() * letter_w + 0.5,
			font_size * 0.011 + 0.28)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.01, 0.01, 0.03)
	tmat.emission_enabled = true
	tmat.emission = col
	tmat.emission_energy_multiplier = 1.8
	tm.material = tmat
	tube.mesh = tm
	tube.position = Vector3(0, 0, 0.02)
	holder.add_child(tube)
	# the text: dark cutout lettering on the glowing tube
	var l := Label3D.new()
	l.text = text
	l.modulate = Color(0.02, 0.02, 0.05)
	l.font_size = font_size
	l.outline_size = 8
	l.outline_modulate = col
	l.position = Vector3(0, 0, 0.06)
	holder.add_child(l)
	# the colored bleed: a halo on the wall behind the tube + the
	# wet smear on the pavement below it (neon LIGHTS its street)
	holder.add_child(halo(holder, Vector3(0, 0, -0.06), col,
			1.2 + text.length() * 0.14))
	wet_streak(holder, Vector3(0, 0, -0.85), col, 6.0, 2.0)
	if flicker:
		var tw := holder.create_tween().set_loops()
		tw.tween_property(tmat, "emission_energy_multiplier", 0.3, 0.09)
		tw.tween_property(tmat, "emission_energy_multiplier", 1.8, 0.05)
		tw.tween_interval(2.2)
		tw.tween_property(tmat, "emission_energy_multiplier", 0.3, 0.05)
		tw.tween_property(tmat, "emission_energy_multiplier", 1.8, 0.09)
	return l


## A LAMP CONE: the cheap fake-volumetric under every sodium head
## - an additive cone that gives the night air something to see.
## No lights, no shadows: one transparent cone per lamp.
static func cone(parent: Node3D, pos: Vector3, col: Color,
		radius := 3.4, height := 4.4) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "LampCone"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = radius
	cm.height = height
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.085)
	cm.material = mat
	m.mesh = cm
	# hang from the lamp head: top at pos, reaching the ground
	m.position = pos + Vector3(0, -height * 0.5, 0)
	parent.add_child(m)
	return m


## A CONTACT SHADOW: the soft dark disc under a character - the
## gate read "pasted onto the ground"; real per-lamp shadows are
## too dear on Mobile, the blob grounds everyone for one quad.
static var _blob_tex: ImageTexture

static func blob(parent: Node3D, radius := 0.55) -> MeshInstance3D:
	if _blob_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.0, 0.0, 0.02, a * a * 0.55))
		_blob_tex = ImageTexture.create_from_image(img)
	var m := MeshInstance3D.new()
	m.name = "BlobShadow"
	var qm := QuadMesh.new()
	qm.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _blob_tex
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	m.mesh = qm
	m.rotation.x = -PI / 2.0
	m.position = Vector3(0, 0.02, 0)
	parent.add_child(m)
	return m


## A SOFT HALO: the additive radial sprite behind a glowing thing -
## the colored bleed onto the wall that sells neon (the gate's
## "hard-edged quad with no halo" finding).
static var _halo_tex: ImageTexture

static func halo(parent: Node3D, pos: Vector3, col: Color,
		size := 3.2) -> MeshInstance3D:
	if _halo_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.2)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_halo_tex = ImageTexture.create_from_image(img)
	var m := MeshInstance3D.new()
	m.name = "NeonHalo"
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _halo_tex
	mat.albedo_color = Color(col.r, col.g, col.b, 0.4)
	qm.material = mat
	m.mesh = qm
	m.position = pos
	parent.add_child(m)
	return m


## THE WET STREAK: the smeared vertical reflection a light paints
## on wet pavement - the #1 noir tell (the gate: "reflect the PAWN
## sign and streetlights as smeared streaks on the pavement").
## A ground quad with an alpha falloff, additive, the light's color.
static var _streak_tex: ImageTexture

static func wet_streak(parent: Node3D, pos: Vector3, col: Color,
		length := 6.0, width := 1.5) -> MeshInstance3D:
	if _streak_tex == null:
		var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 64:
				var fx := absf(float(x) - 31.5) / 32.0
				var fy := absf(float(y) - 7.5) / 8.0
				var a := (1.0 - fy) * pow(1.0 - fx, 1.6)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_streak_tex = ImageTexture.create_from_image(img)
	var m := MeshInstance3D.new()
	m.name = "WetStreak"
	var qm := QuadMesh.new()
	qm.size = Vector2(length, width)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _streak_tex
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	qm.material = mat
	m.mesh = qm
	m.rotation.x = -PI / 2.0
	m.position = pos + Vector3(0, 0.015, 0)
	parent.add_child(m)
	return m
