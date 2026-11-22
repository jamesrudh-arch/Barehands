extends Node
func _ready() -> void:
	Settings.set_value("first_run_done", true)
	Settings.set_value("play_start_sequence", false)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.call("skip")
	var t := get_tree().root.get_node_or_null("/root/Traffic")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# stand the hero at the KERB like live_play's traffic phase
	if player:
		player.global_position = Vector3(-2.0, 0.02, 8.6)
		var blocks := get_tree().root.get_node_or_null("/root/Blocks")
		if blocks:
			blocks.call("snap_camera_to", player)
	for i in 5:
		await get_tree().create_timer(2.5).timeout
		for c in get_tree().get_nodes_in_group("traffic"):
			var n := c as Node3D
			if float(n.get_meta("speed")) < 0.5:
				var hz: bool = t.call("_hazard_ahead", n, false, 0.0, player) \
						if bool(n.get_meta("east")) == false else false
				var sg: bool = t.call("_signal_stops", n, bool(n.get_meta("east")), 0.0)
				print("PROBE stuck=%s east=%s hazard=%s signal=%s phase_walk=%s player=(%s)" % [
						str(n.global_position.round()), str(n.get_meta("east")), hz, sg,
						str(t.call("walk_phase")),
						str(player.global_position.round()) if player else "none"])
		print("PROBE ---")
	get_tree().quit(0)
