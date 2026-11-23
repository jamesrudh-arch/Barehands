extends Node
## S5.6 STORY GATE: the Corporation's call - the ring banner over
## the living street, then the offer on the line.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _ready() -> void:
	var dog := get_tree().create_timer(70.0, true, false, true)
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
	WorldState.set_value("stash_cash", 850.0)
	WorldState.set_value("clean_cash", 480.0)
	WorldState.set_value("debt", 5900.0)
	var ms := get_tree().get_first_node_in_group("missions")
	ms.start("res://data/missions/m6.tres")
	await _wait_s(1.2)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/call_ring.png")
	var ph := get_tree().get_first_node_in_group("phone")
	ph._tab = "CALLS"
	ph.open(false)
	await _wait_s(0.4)
	ph._answer()
	await _wait_s(0.6)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/call_offer.png")
	print("CALL GATE captured")
	get_tree().quit(0)
