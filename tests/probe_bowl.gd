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
	await _wait_s(1.5)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.5)
	var ws := get_tree().get_first_node_in_group("worldsim")
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	while int(ws.beat()) % 3 != 1:
		ws.advance_beat()
	hero.set("hp", 40.0)
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	WorldState.set_value("clean_cash", 200.0)
	print("PROBE beat=%d hp=%s clean=%s" % [ws.beat(),
			str(hero.get("hp")),
			str(WorldState.get_value("clean_cash"))])
	var got: bool = mkt.try_grab(hero)
	print("PROBE try_grab=%s" % str(got))
	await _wait_s(0.3)
	print("PROBE after clean=%s hp=%s" % [
			str(WorldState.get_value("clean_cash")),
			str(hero.get("hp"))])
	for e in WorldState.event_log().slice(-3,
			WorldState.event_log().size()):
		print("PROBE ev %s %s" % [str(e.get("kind")),
				str(e.get("who", ""))])
	get_tree().quit(0)
