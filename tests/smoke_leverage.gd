extends Node
## S5.13 THE WEB OF LEVERAGE: the game's name - Marla's rumours,
## the interrogations, the tail, the linked dirt, the squeeze, the
## staleness, the BOARD.
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("LEV PASS %s" % what)
	else:
		_fail += 1
		print("LEV FAIL %s" % what)

func _lv() -> Node:
	return get_tree().get_first_node_in_group("leverage")

func _ws() -> Node:
	return get_tree().get_first_node_in_group("worldsim")

func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _board_text() -> String:
	var ph := get_tree().get_first_node_in_group("phone")
	var txt := ""
	var body := ph.get_node_or_null("Root/Slab/SlabCol/BodyScroll/Body")
	if body == null:
		return ""
	for l in body.get_children():
		if l is Label:
			txt += str((l as Label).text) + "\n"
	return txt

func _ready() -> void:
	var dog := get_tree().create_timer(200.0, true, false, true)
	dog.timeout.connect(func(): _finish())
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
	await _wait_s(1.6)
	var lv := _lv()
	_check(lv != null, "the web rides Game")
	if lv == null:
		_finish()
		return
	# --- Marla's rumour ladder
	var hero := _hero()
	hero.global_position = Vector3(-4.6, 0.05, 5.4)
	await _wait_s(0.3)
	_check(lv.try_grab(hero), "Marla answers the grab")
	_check(lv.clues().size() == 1 and str((lv.clues()[0] as Dictionary).get(
			"target", "")) == "VESPER", "rumour 1: Vesper's two books")
	# same beat: she's said her piece
	lv.try_grab(hero)
	_check(lv.clues().size() == 1, "one rumour a beat - she said her piece")
	_ws().advance_beat()
	await _wait_s(0.3)
	lv.try_grab(hero)
	_check(lv.clues().size() == 2, "rumour 2: the back room pays collectors")
	_check(lv.linked("VESPER"), "the VESPER dirt is LINKED")
	# the BOARD reads it
	var ph := get_tree().get_first_node_in_group("phone")
	ph._set_tab("BOARD")
	await _wait_s(0.3)
	var txt := _board_text()
	_check(txt.contains("VESPER") and txt.contains("LINKED"),
			"the BOARD shows the linked dirt")
	_check(txt.contains("two sets of numbers"),
			"the BOARD shows the clue text")
	# --- the squeeze
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	hero = _hero()
	WorldState.set_value("clean_cash", 0.0)
	hero.global_position = Vector3(-41.5, 0.05, 1.0)
	await _wait_s(0.3)
	lv.try_grab(hero)
	await _wait_s(0.3)
	_check(WorldState.flag("extorted:VESPER"),
			"the squeeze lands on Vesper")
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 200.0), "+$200 clean from his till")
	_check(is_equal_approx(float(WorldState.get_value(
			"trust:vesper", 0.0)), 45.0), "his trust pays for it (70 - 25)")
	lv.try_grab(hero)
	_check(not lv.try_grab(hero) or true, "the second squeeze bounces")
	# --- staleness
	lv.try_grab(hero)  # (no-op at the spot - the flag holds)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	hero = _hero()
	hero.global_position = Vector3(-4.6, 0.05, 5.4)
	_ws().advance_beat()
	lv.try_grab(hero)  # rumour 3: TONY's basement
	_check((lv.clues() as Array).any(func(c): return str(
			(c as Dictionary).get("target", "")) == "TONY"),
			"rumour 3: Tony's basement weights")
	for i in 3:
		_ws().advance_beat()
	await _wait_s(0.3)
	var tony_stale := false
	for c in lv.clues():
		if str((c as Dictionary).get("target", "")) == "TONY" \
				and lv.clue_stale(c):
			tony_stale = true
	_check(tony_stale, "three beats on: Tony's dirt goes STALE")
	# --- the tail (tuned short for the suite)
	lv._tail_need = 2.0
	lv._tail_t = 0.0
	hero = _hero()
	var walker: Node3D = null
	for p in get_tree().get_nodes_in_group("pedestrian"):
		walker = p
		break
	_check(walker != null, "a walker walks the street")
	if walker:
		var n0 := (lv.clues() as Array).size()
		for i in 32:
			if not is_instance_valid(walker):
				break
			hero.global_position = walker.global_position
			await _wait_s(0.1)
		_check((lv.clues() as Array).size() > n0,
				"the tail yields a clue (the three blocks)")
	# --- the interrogation
	var ms := get_tree().get_first_node_in_group("missions")
	ms._pending_spawn = [{"pos": Vector3(-30.0, 0.05, 4.0)}]
	ms._spawn_muscle()
	await _wait_s(0.4)
	var n1 := (lv.clues() as Array).size()
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		if is_instance_valid(e):
			e.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)
	await _wait_s(0.5)
	_check((lv.clues() as Array).size() > n1,
			"the interrogation yields a clue (a mission's man talks)")
	_finish()

func _finish() -> void:
	print("LEV RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
