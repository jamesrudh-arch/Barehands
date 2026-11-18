class_name HeroRig
extends Node3D
## The noir hero: Quaternius' Universal Base Character body dressed in the
## Modular Outfits ranger set, with hair, beard and a code-built fedora and
## swing coat. Every piece shares the UAL 65-bone rig, so the pack's clips
## play on all of them in lockstep - this node fans the play() calls out.

const UAL := "res://assets/UAL1_Standard.glb"

var _players: Array[AnimationPlayer] = []
var _current := ""
var _hat: Node3D
var _coat: Array[Node3D] = []
var _pipe: MeshInstance3D = null
var _coat_swing := 0.0
var _velocity_fn: Callable  # set by the hero: reads current velocity for coat sway


func _ready() -> void:
	# The pieces ship animation-less, so the rig owns one AnimationPlayer per
	# piece (root_node = the piece node, so the UAL "Armature/Skeleton3D:x"
	# track paths resolve on each of them).
	var tmp: Node = load(UAL).instantiate()
	var lib: AnimationLibrary = tmp.get_node("AnimationPlayer").get_animation_library("")
	for piece in get_children():
		if piece is not Node3D:
			continue
		var p := AnimationPlayer.new()
		p.name = "Clips"
		piece.add_child(p)
		p.add_animation_library("", lib)
		_players.append(p)
	tmp.free()
	_build_hat()
	_build_coat()


## Play a clip on every piece in lockstep. Returns true if the clip changed.
func play(clip: String, blend: float = 0.25, speed := 1.0) -> bool:
	var changed := false
	for p in _players:
		if p.current_animation != clip:
			p.play(clip, blend)
			changed = true
	set_speed(speed)
	_current = clip
	return changed


## Locomotion retunes the speed every frame without restarting the clip.
func set_speed(speed: float) -> void:
	for p in _players:
		p.speed_scale = speed


func current() -> String:
	return _current


## The first piece's player - tests and tools read animation state from it.
func main_player() -> AnimationPlayer:
	return _players[0] if _players.size() > 0 else null


func is_playing() -> bool:
	return _players.size() > 0 and _players[0].is_playing()


func _physics_process(delta: float) -> void:
	# Coat swing: a damped pendulum driven by the hero's speed.
	if _velocity_fn.is_valid() and not _coat.is_empty():
		var v: Vector3 = _velocity_fn.call()
		var speed := Vector2(v.x, v.z).length()
		_coat_swing = lerpf(_coat_swing, clampf(speed / 6.0, 0.0, 1.0), 6.0 * delta)
		var t := Time.get_ticks_msec() / 1000.0
		var sway := sin(t * 9.0) * 0.06 * _coat_swing
		for i in _coat.size():
			_coat[i].rotation.x = -0.25 * _coat_swing + sway * (1.0 if i == 0 else -1.0)


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
	if on and _pipe == null:
		var skel := _find_skel()
		if skel == null:
			return
		var attach := BoneAttachment3D.new()
		attach.bone_name = "hand_r"
		skel.add_child(attach)
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
		attach.add_child(_pipe)
		_pipe.rotation = Vector3(1.2, 0.0, 0.35)
		_pipe.position = Vector3(0.0, 0.08, 0.05)
	elif not on and _pipe != null:
		_pipe.get_parent().queue_free()  # frees the attachment + pipe
		_pipe = null


## Fedora: crown + brim, tilted, riding the Head bone.
func _build_hat() -> void:
	var skel := _find_skel()
	if skel == null:
		return
	_hat = Node3D.new()
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	skel.add_child(attach)  # must be a DIRECT child of the skeleton
	attach.add_child(_hat)
	_hat.add_child(_make_hat_meshes())
	_hat.rotation = Vector3(0.06, 0.10, -0.05)


func _make_hat_meshes() -> Node3D:
	var holder := Node3D.new()
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.10, 0.09, 0.11)
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
	band_mat.albedo_color = Color(0.55, 0.12, 0.10)
	band_mat.roughness = 0.6
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


## Long coat skirt: two light panels hung from the pelvis that swing with speed.
func _build_coat() -> void:
	var skel := _find_skel()
	if skel == null:
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.13, 0.12, 0.145)
	cloth.roughness = 0.9
	for x in [-0.09, 0.09]:
		var panel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.19, 0.52, 0.03)
		panel.mesh = bm
		panel.material_override = cloth
		panel.position = Vector3(x, -0.28, 0.10)
		var attach := BoneAttachment3D.new()
		attach.bone_name = "pelvis"
		skel.add_child(attach)
		attach.add_child(panel)
		_coat.append(panel)


func _find_skel() -> Skeleton3D:
	for piece in get_children():
		var s := _find_class(piece, "Skeleton3D")
		if s:
			return s
	return null


func _find_class(n: Node, what: String) -> Node:
	if n.get_class() == what:
		return n
	for c in n.get_children():
		var r := _find_class(c, what)
		if r:
			return r
	return null
