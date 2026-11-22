extends Node3D
const CLS_Humanoid := preload("res://scripts/humanoid.gd")
## B23 MILESTONE A: the noir hero rebuilt on the code-built humanoid.
## The Quaternius gltf pieces rendered as ghost geometry on the
## physical iPhone (the B18-B22 "grey figure" fight); this body is
## constructed from primitives at runtime and renders identically on
## every renderer. Fedora + swing coat + pipe stay code-built, now
## attached to the humanoid's joints. The rig contract is unchanged:
## play(clip, blend, speed) / set_speed / current / main_player, so
## the hero's state machine, suites and tools keep working.

var _h: Node = null
var _current := ""
var _hat: Node3D
var _coat: Array[Node3D] = []
var _pipe: MeshInstance3D = null
var _coat_swing := 0.0
var _velocity_fn: Callable  # set by the hero: reads current velocity


func _ready() -> void:
	# the gltf pieces the scene still carries are released: the humanoid
	# replaces them outright (a half-loaded piece stack is the ghost
	# the iPhone showed). Deferred: freeing SYNCHRONOUSLY mid-cascade
	# marks main "busy setting up children" and every later _ready
	# add_child (street_dress, trainer, the lamps) then fails - the B23
	# probe catch. The humanoid is named Person so the dying pieces
	# cannot shadow it.
	for piece in get_children():
		if piece is Node3D:
			piece.queue_free()
	_h = CLS_Humanoid.new()
	_h.name = "Person"
	add_child(_h)
	_h.call("build", {
		"height": 1.82, "build": 1, "hair_style": 1,
		"skin": Color(0.68, 0.52, 0.4),
		"hair": Color(0.16, 0.13, 0.09),
		"top": Color(0.2, 0.19, 0.23),
		"bottom": Color(0.16, 0.16, 0.19),
		"jacket": Color(0.17, 0.16, 0.2), "jacket_on": true,
	})
	_build_hat()
	_build_coat()


## Play a clip (poses + procedural locomotion). Returns true on change.
func play(clip: String, blend: float = 0.25, speed := 1.0) -> bool:
	var changed := clip != _current
	if changed:
		_current = clip
	if _h:
		_h.call("play", clip, blend, speed)
	return changed


## Locomotion retunes the stride every frame without restarting.
func set_speed(speed: float) -> void:
	if _h:
		_h.call("set_speed", speed)


func current() -> String:
	return _current


func main_player() -> AnimationPlayer:
	return _h.call("main_player") if _h else null


func is_playing() -> bool:
	return _h != null


func _physics_process(delta: float) -> void:
	# Coat swing: a damped pendulum driven by the hero's speed; the
	# same signal feeds the humanoid's stride so cloth and legs agree.
	if _velocity_fn.is_valid():
		var v: Vector3 = _velocity_fn.call()
		var speed := Vector2(v.x, v.z).length()
		if _h:
			_h.call("observe_speed", speed)
		_coat_swing = lerpf(_coat_swing, clampf(speed / 6.0, 0.0, 1.0),
				6.0 * delta)
		var t := Time.get_ticks_msec() / 1000.0
		var sway := sin(t * 9.0) * 0.06 * _coat_swing
		for i in _coat.size():
			_coat[i].rotation.x = -0.08 - 0.25 * _coat_swing \
					+ sway * (1.0 if i % 2 == 0 else -0.6)


## Recolour the coat panels and the hat felt (the tailor's work).
func set_coat_color(c: Color) -> void:
	for p in _coat:
		var mat: StandardMaterial3D = (p as MeshInstance3D).material_override
		if mat:
			mat.albedo_color = c
	for mi in _find_hat_meshes():
		var hm: StandardMaterial3D = (mi as MeshInstance3D).material_override
		if hm:
			hm.albedo_color = c * 0.85


func _find_hat_meshes() -> Array:
	var out: Array = []
	if _hat:
		for c in _hat.find_children("*", "MeshInstance3D", true, false):
			if c.name == "Crown" or c.name == "Brim":
				out.append(c)
	return out


## The steel pipe rides the right hand when equipped.
func equip_pipe(on: bool) -> void:
	if on and _pipe == null and _h:
		var hr: Node3D = _h.call("hand", "r") if _h else null
		var anchor := hr
		if anchor == null:
			return
		_pipe = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.028
		cyl.bottom_radius = 0.028
		cyl.height = 0.85
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.24, 0.25, 0.28)
		m.roughness = 0.35
		m.metallic = 0.8
		cyl.material = m
		_pipe.mesh = cyl
		anchor.add_child(_pipe)
		_pipe.rotation = Vector3(1.2, 0.0, 0.35)
		_pipe.position = Vector3(0.0, 0.08, 0.05)
	elif not on and _pipe != null:
		_pipe.get_parent().queue_free()
		_pipe = null


## Fedora: crown + brim, tilted, riding the humanoid's head joint.
func _build_hat() -> void:
	var head: Node3D = _h.call("head") if _h else null
	if head == null:
		return
	# the fedora reads at phone distance: 20% oversized with a bright
	# band (the VLM catch - the hat vanished into the head at 360p)
	_hat = Node3D.new()
	head.add_child(_hat)
	_hat.add_child(_make_hat_meshes())
	_hat.scale = Vector3.ONE * 1.2
	_hat.rotation = Vector3(0.06, 0.10, -0.05)
	_hat.position = Vector3(0, 0.05, 0)


func _make_hat_meshes() -> Node3D:
	var holder := Node3D.new()
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.16, 0.15, 0.18)
	felt.roughness = 0.85
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.105
	cm.bottom_radius = 0.125
	cm.height = 0.14
	crown.mesh = cm
	crown.material_override = felt
	crown.position = Vector3(0, 0.145, 0)
	holder.add_child(crown)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.127
	bm.bottom_radius = 0.127
	bm.height = 0.035
	band.mesh = bm
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.75, 0.2, 0.14)
	band_mat.roughness = 0.6
	band_mat.emission_enabled = true
	band_mat.emission = Color(0.6, 0.12, 0.08)
	band_mat.emission_energy_multiplier = 0.3
	band.material_override = band_mat
	band.position = Vector3(0, 0.09, 0)
	holder.add_child(band)
	var brim := MeshInstance3D.new()
	var br := CylinderMesh.new()
	br.top_radius = 0.185
	br.bottom_radius = 0.185
	br.height = 0.012
	brim.mesh = br
	brim.material_override = felt
	brim.position = Vector3(0, 0.075, 0)
	holder.add_child(brim)
	return holder


## Long coat skirt: five panels fanned around the pelvis that swing
## with speed, riding the humanoid's hips joint.
func _build_coat() -> void:
	var hips: Node3D = _h.call("hips") if _h else null
	if hips == null:
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.19, 0.18, 0.21)
	cloth.roughness = 0.9
	for deg in [-72.0, -36.0, 0.0, 36.0, 72.0]:
		var panel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.20, 0.55, 0.035)
		panel.mesh = bm
		panel.material_override = cloth
		var ang := deg_to_rad(deg)
		panel.position = Vector3(sin(ang) * 0.17, -0.30, cos(ang) * 0.15)
		panel.rotation.y = ang
		panel.rotation.x = -0.08  # flares out a touch
		hips.add_child(panel)
		_coat.append(panel)
