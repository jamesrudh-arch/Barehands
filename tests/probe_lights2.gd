extends Node
func _ready() -> void:
	Settings.set_value("first_run_done", true)
	Settings.set_value("skip_intro", true)
	WorldState.reset()
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	await get_tree().create_timer(1.0).timeout
	var count := 0
	for n in get_tree().get_nodes_in_group("lights"):
		count += 1
	# walk the tree for light nodes
	var lights := []
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Light3D:
			lights.append("%s(%s) parent=%s" % [n.name,
					n.get_class(), n.get_parent().name])
		for c in n.get_children():
			stack.append(c)
	print("LIGHTS=%d" % lights.size())
	for l in lights:
		print("  " + l)
	get_tree().quit(0)
