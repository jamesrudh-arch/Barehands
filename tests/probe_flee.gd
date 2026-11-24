extends Node
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _ready() -> void:
	var dog := get_tree().create_timer(60.0, true, false, true)
	dog.timeout.connect(func(): get_tree().quit(1))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.4)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.8)
	var walkers: Array = get_tree().get_nodes_in_group("pedestrian")
	print("FLEE walkers=%d" % walkers.size())
	var w: CharacterBody3D = walkers[0]
	var cls := load("res://scripts/npc/enemy.gd") as GDScript
	var thug: CharacterBody3D = cls.new()
	thug.position = (w as Node3D).global_position + Vector3(4.0, 0, 0)
	get_tree().current_scene.add_child(thug)
	for i in 12:
		await _wait_s(0.3)
		print("FLEE t=%.1f w=(%.1f,%.1f) st=%d thug=(%.1f,%.1f) d=%.1f" % [
				i * 0.3, w.global_position.x, w.global_position.z,
				w.state, thug.global_position.x, thug.global_position.z,
				w.global_position.distance_to(thug.global_position)])
	get_tree().quit(0)
