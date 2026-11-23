extends Node
func _ready() -> void:
	var scene: PackedScene = load("res://assets/UAL1_Standard.glb")
	print("SRC packed=%s" % (scene != null))
	var holder := scene.instantiate()
	add_child(holder)
	var ap := _find(holder, AnimationPlayer)
	if ap == null:
		print("SRC no AnimationPlayer!")
		get_tree().quit(0)
		return
	print("SRC libs: %s" % str(ap.get_animation_library_list()))
	var total := 0
	for l in ap.get_animation_library_list():
		var lib: AnimationLibrary = ap.get_animation_library(l)
		var n: int = lib.get_animation_list().size()
		total += n
		print("SRC lib %s = %d" % [l, n])
	print("SRC total=%d" % total)
	var sk := _find(holder, Skeleton3D)
	print("SRC skeleton=%s" % (sk != null))
	if sk:
		print("SRC bones=%d pelvis=%d" % [sk.get_bone_count(),
				sk.find_bone("pelvis")])
	# and the TRACK PATHS of one clip (what bone names they carry)
	var a: Animation = ap.get_animation("Punch_Cross")
	if a:
		for ti in range(minf(4, a.get_track_count())):
			print("SRC track %d type=%d path=%s" % [ti,
					a.track_get_type(ti), a.track_get_path(ti)])
	get_tree().quit(0)

func _find(root: Node, what) -> Node:
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var f := _find(c, what)
		if f:
			return f
	return null
