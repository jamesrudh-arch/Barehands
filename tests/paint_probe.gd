extends Node
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1
func _ready() -> void:
	var dog := get_tree().create_timer(40.0, true, false, true)
	dog.timeout.connect(func(): get_tree().quit(1))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.2)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.5)
	var v := get_tree().get_first_node_in_group("vehicle")
	print("PAINT vehicle=%s" % str(v != null))
	if v:
		for child in v.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child as MeshInstance3D
			var n: int = mi.get_surface_override_material_count()
			for i in n:
				var m: Material = mi.get_active_material(i)
				var sm := m as StandardMaterial3D
				if sm:
					print("PAINT %s surf%d tex=%s col=%s" % [
							mi.name, i, str(sm.albedo_texture != null),
							str(sm.albedo_color)])
	get_tree().quit(0)
