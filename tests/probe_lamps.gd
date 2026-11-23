extends Node
func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	await get_tree().create_timer(1.0).timeout
	var lights := 0
	var posts := 0
	var pools := 0
	for n in get_tree().get_nodes_in_group("__nodes"):
		pass
	for c in get_tree().current_scene.get_children():
		var n := str(c.name)
		if n.find("LampLight") >= 0:
			lights += 1
		if n.find("LampPost") >= 0:
			posts += 1
		if n.find("LightPool") >= 0:
			pools += 1
	print("LAMPS posts=%d lights=%d pools=%d street_x=%s kids=%d" % [
			posts, lights, pools,
			get_tree().current_scene.get("STREET_X"),
			get_tree().current_scene.get_child_count()])
	for c in get_tree().current_scene.get_children():
		var n := str(c.name)
		if n.find("LampPost") >= 0 or n.find("LampLight") >= 0:
			print("LAMPNODE %s at %s" % [n, c.position])
	get_tree().quit(0)
