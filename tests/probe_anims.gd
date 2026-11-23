extends Node
func _ready() -> void:
	var dog := get_tree().create_timer(50.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await get_tree().create_timer(1.5).timeout
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var anims: Array = []
	for ap in hero.find_children("*", "AnimationPlayer", true, false):
		for a in ap.get_animation_list():
			anims.append(str(a))
	var pistol: Array = []
	for a in anims:
		if "pistol" in a.to_lower():
			pistol.append(a)
	print("ANIMS total=%d pistol=%s" % [anims.size(), str(pistol)])
	# where is the warehouse muscle?
	for n in get_tree().get_nodes_in_group("npc"):
		print("ANIMS npc %s at %s (dist %.1f)" % [n.name,
				str(n.global_position),
				n.global_position.distance_to(
						hero.global_position)])
	get_tree().quit(0)
