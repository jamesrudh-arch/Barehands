extends Node3D
const CLS_Humanoid := preload("res://scripts/humanoid.gd")
## A named character on the B23 code-built humanoid framework. The old
## gltf/UAL path rendered as ghost geometry on the physical iPhone
## while passing every Linux check; this rig is built from primitives
## at runtime and renders identically on every renderer. The caller's
## contract is unchanged - build(pieces, tint, accent, idle, speed)
## keeps working: the pieces array is hashed into a deterministic body
## (the same list always builds the same person), tint dresses the
## top, accent carries as the emissive edge enemies use.

var _h: Node = null
var _current := ""
var spec: Dictionary = {}  # the body this rig wears (variety census)


func build(pieces: Array, tint: Color, accent: Color, idle_clip := "Idle",
		idle_speed := 1.0) -> void:
	add_to_group("npc_rig")  # the spawned-vs-animated census
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(pieces))  # stable identity per piece list
	var female := rng.randf() < 0.5
	var spec := {
		"height": rng.randf_range(1.58, 1.9),
		"build": rng.randi_range(0, 2),
		"female": female,
		"hair_style": rng.randi_range(0, 5),
		"hair": Color().from_hsv(rng.randf(), 0.35 + 0.3 * rng.randf(),
				0.04 + 0.14 * rng.randf()),
		"skin": Color().from_hsv(0.07, 0.32 + 0.2 * rng.randf(),
				0.42 + 0.3 * rng.randf()),
		"top": Color(0.2, 0.2, 0.23).lerp(tint, 0.75),
		"bottom": Color(0.13, 0.13, 0.16).lerp(tint, 0.3),
		"jacket": tint.darkened(0.45),
		"jacket_on": rng.randf() < 0.4,
		"accent": accent if accent.a > 0.0 else Color(0, 0, 0, 0),
	}
	if female and rng.randf() < 0.5:
		spec["skirt"] = true
	_h = CLS_Humanoid.new()
	self.spec = spec
	_h.name = "Body"
	add_child(_h)
	_h.call("build", spec)
	play(idle_clip, 0.25, idle_speed)


## Play a clip on the humanoid (poses + procedural locomotion).
func play(clip: String, _blend := 0.25, speed := 1.0) -> void:
	_current = clip
	if _h:
		_h.call("play", clip, 0.25, speed)


## The clip the rig is on (state machines read it).
func current() -> String:
	return _current


func set_speed(speed: float) -> void:
	if _h:
		_h.call("set_speed", speed)


func is_playing() -> bool:
	return _h != null


func main_player() -> AnimationPlayer:
	return _h.call("main_player") if _h else null


## The hero feeds live speed so the stride matches reality.
func observe_speed(v_per_s: float) -> void:
	if _h:
		_h.call("observe_speed", v_per_s)


## A joint for props (the wanderer's phone rides the right hand).
func hand(side: String) -> Node3D:
	return _h.call("hand", side) if _h else null


## Code-built round glasses on the head (Pilsner's hacker look).
func add_glasses(color: Color) -> void:
	var head: Node3D = _h.call("head") if _h else null
	if head == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	for x in [-0.055, 0.055]:
		var lens := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.028
		t.outer_radius = 0.036
		lens.mesh = t
		lens.material_override = mat
		lens.position = Vector3(x, 0.076, 0.102)
		lens.rotation.x = PI / 2.0
		head.add_child(lens)
	var bridge := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.006, 0.006)
	bridge.mesh = bm
	bridge.material_override = mat
	bridge.position = Vector3(0, 0.078, 0.104)
	head.add_child(bridge)


## A thin gold circlet with one spike (the Duchess).
func add_circlet() -> void:
	var head: Node3D = _h.call("head") if _h else null
	if head == null:
		return
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.68, 0.25)
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(0.5, 0.4, 0.15)
	gold.emission_energy_multiplier = 0.25
	var band := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.105
	t.outer_radius = 0.118
	band.mesh = t
	band.material_override = gold
	band.rotation.x = PI / 2.0
	band.position = Vector3(0, 0.1, 0)
	head.add_child(band)
	var spike := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.02
	c.height = 0.09
	spike.mesh = c
	spike.material_override = gold
	spike.position = Vector3(0, 0.17, 0)
	head.add_child(spike)
