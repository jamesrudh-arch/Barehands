extends Node3D
const CLS_UalBind := preload("res://scripts/ual_bind.gd")
## A named character built from Universal Base Character pieces (all on the
## shared UAL 65-bone rig), recoloured to a colour identity and dressed by
## code accessories (glasses, circlets). Plays one idle clip in a loop.

var _players: Array[AnimationPlayer] = []


## pieces: paths to gltf scenes; tint: colour identity; accent: emissive edge.
func build(pieces: Array, tint: Color, accent: Color, idle_clip := "Idle",
		idle_speed := 1.0) -> void:
	for path in pieces:
		var ps: PackedScene = load(path)
		if ps == null:
			Log.warn("NpcRig: missing piece %s" % path)
			continue
		var piece := ps.instantiate()
		piece.rotation.y = PI  # the UBC pieces face +Z, like the mannequin
		add_child(piece)
		var skel := _find_class(piece, "Skeleton3D")
		if skel and (piece as Node3D).get_node_or_null("Armature"):
			# recolour every surface toward the identity, add a faint accent edge
			for mi in piece.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				if mesh == null:
					continue
				var dup := mesh.duplicate()
				for i in dup.get_surface_count():
					var m: Material = dup.surface_get_material(i)
					if m is StandardMaterial3D:
						var d := (m as StandardMaterial3D).duplicate()
						d.albedo_color = d.albedo_color.lerp(tint, 0.6)
						d.emission_enabled = true
						d.emission = accent
						d.emission_energy_multiplier = 0.05
						dup.surface_set_material(i, d)
				(mi as MeshInstance3D).mesh = dup
		var p := AnimationPlayer.new()
		p.name = "Clips"
		piece.add_child(p)
		_players.append(p)
	# UalBind grafts the shared, plain-path library (the T-pose fix)
	for p in _players:
		CLS_UalBind.attach(p)
	play(idle_clip, idle_speed)


## Play the clip on EVERY piece (base body and outfits) in lockstep.
func play(clip: String, _blend := 0.25, speed := 1.0) -> void:
	CLS_UalBind.play_all(_players, clip, 0.25, speed)


func set_speed(speed: float) -> void:
	for p in _players:
		p.speed_scale = speed


## Code-built round glasses on the head (Pilsner's hacker look).
func add_glasses(color: Color) -> void:
	var skel := _find_class(self, "Skeleton3D")
	if skel == null:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	skel.add_child(attach)
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
		lens.position = Vector3(x, 0.02, 0.11)
		lens.rotation.x = PI / 2.0
		attach.add_child(lens)
	var bridge := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.006, 0.006)
	bridge.mesh = bm
	bridge.material_override = mat
	bridge.position = Vector3(0, 0.022, 0.112)
	attach.add_child(bridge)


## A thin gold circlet with one spike (the Duchess).
func add_circlet() -> void:
	var skel := _find_class(self, "Skeleton3D")
	if skel == null:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	skel.add_child(attach)
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
	band.position = Vector3(0, 0.07, 0)
	attach.add_child(band)
	var spike := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.02
	c.height = 0.09
	spike.mesh = c
	spike.material_override = gold
	spike.position = Vector3(0, 0.15, 0)
	attach.add_child(spike)


func _find_class(n: Node, what: String) -> Node:
	if n.get_class() == what:
		return n
	for c in n.get_children():
		var r := _find_class(c, what)
		if r:
			return r
	return null
