extends Node
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.0)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	print("HV hero=%s pos=%s" % [hero != null, hero.global_position])
	var rig := hero.get_node_or_null("Rig") as Node3D
	print("HV rig=%s visible=%s scale=%s pos=%s" % [rig != null,
			rig.visible if rig else "-", rig.scale if rig else "-",
			rig.global_position if rig else "-"])
	if rig:
		var meshes := rig.find_children("*", "MeshInstance3D", true, false)
		print("HV meshes=%d" % meshes.size())
		for mi in meshes.slice(0, 4):
			var m := mi as MeshInstance3D
			var aabb := m.get_aabb()
			print("HV  %s visible=%s layers=%d aabb_pos=%s aabb_size=%s gpos=%s mat=%s" % [
					str(m.name).left(24), m.visible, m.layers,
					aabb.position, aabb.size, m.global_position,
					m.get_active_material(0) != null])
	var cam := get_viewport().get_camera_3d()
	print("HV cam=%s pos=%s" % [cam != null, cam.global_position if cam else "-"])
	var skel := hero.find_children("*", "Skeleton3D", true, false)
	if skel.size() > 0:
		var s := skel[0] as Skeleton3D
		var posed := s.global_transform * s.get_bone_global_pose(
				s.find_bone("Head")).origin
		var rest := s.global_transform * s.get_bone_global_rest(
				s.find_bone("Head")).origin
		print("HV head POSED=%s REST=%s" % [posed, rest])
	# what tracks does the installed idle actually carry?
	var ap := hero.find_children("*", "AnimationPlayer", true, false)
	if ap.size() > 0:
		var p := ap[0] as AnimationPlayer
		for an in p.get_animation_list():
			if "idle" not in str(an):
				continue
			var a := p.get_animation(an)
			print("HV clip %s tracks=%d len=%.2f" % [an,
					a.get_track_count(), a.get_length()])
			for ti in range(minf(6, a.get_track_count())):
				print("HV  track %d type=%d path=%s" % [ti,
						a.track_get_type(ti), a.track_get_path(ti)])
			break
	# screenshot WITH animation
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/hv_anim.png")
	print("HV shot with anim")
	# disable the tree: does the hero appear?
	var tree := hero.get_node_or_null("Rig/Locomotion") as AnimationTree
	if tree:
		tree.active = false
	await _wait_s(0.5)
	get_viewport().get_texture().get_image().save_png("/tmp/shots/hv_rest.png")
	print("HV shot at rest")
	get_tree().quit(0)
