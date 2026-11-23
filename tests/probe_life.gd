extends Node
## S5.3 p2 GATE: the club strip + the docks yard with their new
## life. Two captures through the game's own camera (the composed-
## camera graveyard law).
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	var dog := get_tree().create_timer(70.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	for spec in [["club_district", "club"], ["docks", "docks"]]:
		await Game.travel(spec[0], "start")
		await _wait_s(2.5)
		# face DOWN the street at the club (the spawn view stares at
		# the venue wall - the lanes and walkers live along the axis)
		if spec[0] == "club_district":
			var h := get_tree().get_first_node_in_group(
					"player") as Node3D
			var r := h.get_node_or_null("Rig") as Node3D
			if r:
				r.rotation.y = -PI / 2.0
			await _wait_s(1.0)
		for i in 3:
			await _wait_s(1.8)
			get_viewport().get_texture().get_image().save_png(
					"/tmp/shots/%s_%02d.png" % [spec[1], i])
		print("LIFE %s captured" % spec[0])
	get_tree().quit(0)
