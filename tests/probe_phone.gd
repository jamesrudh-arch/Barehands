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
	await _wait_s(1.5)
	print("PROBE group phone size=%d" % get_tree(
			).get_nodes_in_group("phone").size())
	print("PROBE Game._phone=%s" % str(Game._phone))
	if Game._phone != null:
		print("PROBE phone name=%s groups=%s" % [Game._phone.name,
				str(Game._phone.get_groups())])
	get_tree().quit(0)
