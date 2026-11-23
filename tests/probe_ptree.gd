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
	await _wait_s(1.4)
	var ph := get_tree().get_first_node_in_group("phone")
	ph.open(false)
	await _wait_s(0.3)
	print("PTREE before: phone=%s Root=%s body=%s" % [
			str(ph != null),
			str(ph.get_node_or_null("Root") != null),
			str(ph.get_node_or_null("Root/Slab/SlabCol/Body") != null)])
	WorldState.set_value("clean_cash", 200.0)
	ph._taxi("club_district")
	await _wait_s(2.5)
	ph = get_tree().get_first_node_in_group("phone")
	print("PTREE after: phone=%s area=%s Root=%s body=%s n_phone_group=%d" % [
			str(ph != null), Game.area_id,
			str(ph.get_node_or_null("Root") != null),
			str(ph.get_node_or_null("Root/Slab/SlabCol/Body") != null),
			get_tree().get_nodes_in_group("phone").size()])
	var ms := get_tree().get_first_node_in_group("missions")
	ms.start("res://data/missions/m2.tres")
	await _wait_s(0.5)
	ph._set_tab("NOTES")
	await _wait_s(0.3)
	var body := ph.get_node_or_null("Root/Slab/SlabCol/Body")
	print("PTREE notes body=%s kids=%d" % [str(body != null),
			body.get_child_count() if body != null else -1])
	for c in (body.get_children() if body != null else []):
		if c is Label:
			print("PTREE label: %s" % (c as Label).text.substr(0, 40))
	get_tree().quit(0)
