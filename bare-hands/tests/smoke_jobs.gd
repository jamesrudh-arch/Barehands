extends Node
## Batch 10 suite: the jobs (bible 4F). The board costs a beat, the
## walk is the recon, the five templates execute for real, Clean
## Hands pays the friend while Wrecking burns them and heats the
## block, overuse marks their business, the day is the deadline, and
## everything survives a save.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("JOBS FAIL: ", what)
	else:
		print("JOBS ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.2)
	_player = _main.get_node("Player") as CharacterBody3D
	var thug := _main.get_node("Thug") as Node
	if thug:
		thug.queue_free()  # this suite owns the street

	await _test_board_and_beats()
	await _test_recon_delivery_clean()
	await _test_delivery_wrecking()
	await _test_rescue()
	await _test_coerced()
	await _test_hit()
	await _test_turf()
	await _test_overuse()
	await _test_day_cold()
	await _test_persistence()
	await _test_map_board_ui()

	if _fails == 0:
		print("JOBS PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("JOBS FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _goto(district: String) -> void:
	# cross-block travel goes through the REAL walk (a raw teleport gets
	# leashed back to the built block and walks you through a gate)
	if Blocks._current != district:
		Blocks.travel(district, "west")
		await _wait_s(2.2)  # the fade both ways
	else:
		await _wait_s(0.3)


func _at_spot(j: Dictionary) -> void:
	# a teleport INSIDE the current block is safe - no gate, no leash
	_player.global_position = Jobs._spot(j)
	await _wait_s(0.7)  # let the 0.4s execution poll see it


func _down_all() -> void:
	for e in Jobs._spawned:
		if is_instance_valid(e):
			var en := e as Enemy
			en.set("hp", 0)
			en.call("_enter", Enemy.State.DOWN)  # raw state= skips _enter -> instant respawn
	await _wait_s(0.6)  # the 0.4s poll counts them


func _markers() -> int:
	return get_tree().get_nodes_in_group("job_marker").size()


func _take_flow(id: String) -> Dictionary:
	Jobs.reset_for_test()
	Jobs.offers = [id]
	Jobs.changed.emit()
	Ledger.beats_left = 3  # tests take many jobs on one day
	var j := Jobs.job_by_id(id)
	var beats0 := Ledger.beats_left
	if not Jobs.take(id):
		return {}
	_check(Ledger.beats_left == beats0 - 1, "taking %s spends a beat" % id)
	return j


# --- A. the board -------------------------------------------------------------------


func _test_board_and_beats() -> void:
	Jobs.reset_for_test()
	_check(Jobs.offers.size() == 4, "the board opens with four offers (%d)" % Jobs.offers.size())
	_check(Jobs.active.is_empty(), "no live job at boot")
	# no beats -> the fixer's line is busy
	Ledger.beats_left = 0
	var id: String = Jobs.offers[0]
	_check(not Jobs.take(id), "with no beats left, taking is refused")
	_check(Jobs.offers.has(id), "a refused take leaves the offer on the board")
	Ledger.beats_left = 3
	# one job at a time
	_check(Jobs.take(id), "the take lands with beats back")
	_check(not Jobs.take(Jobs.offers[0]) if Jobs.offers.size() > 0 else true,
			"no second job while one is live")


# --- B. delivery, clean hands -------------------------------------------------------


func _test_recon_delivery_clean() -> void:
	var j := _take_flow("courier_market")
	if j.is_empty():
		return
	_check(Jobs.active["phase"] == "RECON", "taken job waits on recon")
	_check(_markers() == 0, "no marker before recon - eyes before hands")
	# the wrong district changes nothing
	await _goto("foundry")
	_check(Jobs.active["phase"] == "RECON", "the wrong block teaches nothing")
	await _goto("market")
	_check(Jobs.active["phase"] == "READY", "walking the block finds the spot")
	_check(_markers() == 1, "the drop light stands")
	var dirty0 := Wallet.dirty
	var t0 := Trust.value("club_owner")
	# stand ON the spot; easy drop, no ambush
	_at_spot(j)
	_check(Jobs.active["phase"] == "READY" or Jobs.active["phase"] == "DONE",
			"the drop resolves on touch")
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "the case lands (phase %s)" % Jobs.active["phase"])
	_check(Wallet.dirty == dirty0 + j["pay"], "dirty pay lands ($%d)" % j["pay"])
	_check(absf(Trust.value("club_owner") - (t0 + 10.0)) < 0.01,
			"clean hands pay the friend +10 (%.0f)" % Trust.value("club_owner"))
	_check(_markers() == 0, "the light is gone when it's done")


# --- C. delivery, wrecking ball -------------------------------------------------------


func _test_delivery_wrecking() -> void:
	var j := _take_flow("courier_foundry")
	if j.is_empty():
		return
	await _goto("foundry")
	_check(_markers() == 1 and Jobs._spawned.size() == 0,
			"the hard drop waits quiet until touched")
	# touch: the ambush steps out, the case still lands
	_at_spot(j)
	await _wait_s(1.2)
	_check(Jobs._spawned.size() == 2, "the drop bites - two step out (%d)" % Jobs._spawned.size())
	var h0 := Heat.heat
	var t0 := Trust.value("mechanic")
	_down_all()  # drop them both: wrecking
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "the case lands anyway")
	_check(absf(Trust.value("mechanic") - (t0 - 10.0)) < 0.01,
			"wrecking their setup burns the friend -10 (%.0f)" % Trust.value("mechanic"))
	_check(Heat.heat >= h0 + 1.0 - 0.01, "wrecking heats the block (%.2f)" % Heat.heat)


# --- D. rescue -------------------------------------------------------------------------


func _test_rescue() -> void:
	var j := _take_flow("free_brothers_man")
	if j.is_empty():
		return
	await _goto("market")
	_check(Jobs._spawned.size() == 1, "one guard stands over the body")
	_check(get_tree().get_nodes_in_group("job_prop").size() == 1,
			"the held body is there")
	var dirty0 := Wallet.dirty
	_down_all()
	_at_spot(j)
	await _wait_s(1.2)
	_check(Jobs.active["phase"] == "DONE", "guard down, the body walks (%s)" % Jobs.active["phase"])
	_check(Wallet.dirty == dirty0 + j["pay"], "rescue pay lands ($%d)" % j["pay"])
	_check(get_tree().get_nodes_in_group("job_prop").size() == 0,
			"the body is cleared with the job")


# --- E. coerced --------------------------------------------------------------------------


func _test_coerced() -> void:
	var j := _take_flow("lean_riverside")
	if j.is_empty():
		return
	Heat.heat = 0.0
	await _goto("riverside")
	_check(Jobs._spawned.size() == 0, "a calm block means words only")
	var dirty0 := Wallet.dirty
	var t0 := Trust.value("brother")
	_at_spot(j)
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "the lean lands quiet")
	_check(Wallet.dirty == dirty0 + j["pay"], "coerced pay lands ($%d)" % j["pay"])
	_check(absf(Trust.value("brother") - (t0 + 10.0)) < 0.01,
			"words only: the friend's trust is up (%.0f)" % Trust.value("brother"))
	# a hot block changes the deal
	var j2 := _take_flow("lean_fenced")
	if not j2.is_empty():
		await _goto("foundry")
		Heat.heat = 3.0  # set late: real-time decay eats it during travel
		_at_spot(j2)
		await _wait_s(1.5)
		_check(Jobs._spawned.size() == 1, "a hot block gets you a guard")
		_down_all()
		await _wait_s(1.5)
		_check(Jobs.active["phase"] == "DONE", "the hot lean still finishes")


# --- F. hit ---------------------------------------------------------------------------------


func _test_hit() -> void:
	var j := _take_flow("cut_enforcer")
	if j.is_empty():
		return
	await _goto("market")
	_check(Jobs._spawned.size() == 1, "the mark stands in the open")
	var dirty0 := Wallet.dirty
	_down_all()
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "the mark drops")
	_check(Wallet.dirty == dirty0 + j["pay"], "hit pay lands ($%d)" % j["pay"])
	_check(Jobs.active["downed"] == 1, "one body on the floor counts")


# --- G. turf ----------------------------------------------------------------------------------


func _test_turf() -> void:
	var j := _take_flow("hold_market")
	if j.is_empty():
		return
	await _goto("market")
	var alive := Jobs._spawned.size()
	_check(alive == 2, "wave one: two want the corner (%d)" % alive)
	_down_all()
	await _wait_s(2.0)  # wave gap ~1.2s of poll time
	_check(Jobs._spawned.size() == 2, "wave two comes")
	_down_all()
	await _wait_s(2.0)
	_check(Jobs._spawned.size() == 3, "wave three comes heavy")
	_down_all()
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "three waves held, the corner is yours")
	_check(Jobs.active["downed"] >= 7, "the floor is littered (%d)" % Jobs.active["downed"])


# --- H. overuse (bible 4F: their business eats it) ----------------------------------------------


func _test_overuse() -> void:
	Jobs.reset_for_test()
	# three setups through the club owner: the third one warns and marks
	var homes: Array = ["courier_market", "lean_fenced", "hold_market"]
	var scars0 := City.damage_points("market").size()
	for id in homes:
		Ledger.beats_left = 3
		Jobs.offers = [id]
		Jobs.changed.emit()
		if not Jobs.take(id):
			_check(false, "take %s (beats left %d)" % [id, Ledger.beats_left])
			return
		var oj := Jobs.job_by_id(id)
		await _goto(oj["district"])
		var guard := 0
		while Jobs.active.get("phase", "") == "READY" and guard < 14:
			guard += 1
			if Jobs._spawned.size() > 0:
				_down_all()  # waves need one drop each
			else:
				_at_spot(oj)
			await _wait_s(1.6)
	_check(City.damage_points("market").size() >= scars0 + 1,
			"overuse marks the friend's home block")


# --- I. the day is the deadline ------------------------------------------------------------------


func _test_day_cold() -> void:
	var j := _take_flow("free_foundry_hand")
	if j.is_empty():
		return
	var t0 := Trust.value("mechanic")
	var day0 := Ledger.day
	Ledger.end_day_early()
	await _wait_s(1.0)
	_check(Ledger.day == day0 + 1, "the day rolled")
	_check(Jobs.active.get("phase", "") == "LOST",
			"a live job goes cold with the day (%s)" % str(Jobs.active.get("phase")))
	_check(absf(Trust.value("mechanic") - (t0 - 10.0)) < 0.01,
			"a cold job burns the friend -10 (%.0f)" % Trust.value("mechanic"))
	_check(_markers() == 0 and Jobs._spawned.is_empty(),
			"the night sweeps the board")
	_check(Jobs.offers.size() == 4, "the morning board is fresh (%d)" % Jobs.offers.size())


# --- J. persistence -------------------------------------------------------------------------------


func _test_persistence() -> void:
	var j := _take_flow("cut_snitch")
	if j.is_empty():
		return
	await _goto("foundry")
	_check(Jobs.active["phase"] == "READY", "ready to save")
	var d := Jobs.to_dict()
	_check(not str(d).contains("_counted"), "no node refs in the save")
	_check(not JSON.stringify(d).is_empty(), "the save serializes")
	Jobs._clear_entities()
	Jobs.active = {}
	await _wait_s(0.3)  # queue_free is deferred - let the old marker leave the group
	Jobs.from_dict(d)
	_check(Jobs.active["phase"] == "READY" and Jobs.active["id"] == "cut_snitch",
			"the live job roundtrips")
	_check(_markers() == 1, "the mark's light comes back with the load")
	_down_all()
	await _wait_s(1.5)
	_check(Jobs.active["phase"] == "DONE", "the loaded job still finishes")


# --- K. the board on the map ------------------------------------------------------------------------


func _test_map_board_ui() -> void:
	Jobs.reset_for_test()
	var ui: CanvasLayer = null
	for n in _walk(get_tree().root, []):
		if n.get_script() and str(n.get_script().resource_path).ends_with("phone_ui.gd"):
			ui = n
			break
	_check(ui != null, "the phone screen exists")
	if ui == null:
		return
	ui._open_map()
	await _wait_s(0.4)
	var takes := 0
	for n in _walk(get_tree().root, []):
		if n is Button and (n as Button).text.begins_with("TAKE - "):
			takes += 1
	_check(takes == Jobs.offers.size(),
			"the board lists every offer with a TAKE (%d/%d)" % [takes, Jobs.offers.size()])
	var chips := 0
	for n in _walk(get_tree().root, []):
		if n is Label and (n as Label).text.begins_with("JOBS "):
			chips += 1
	_check(chips >= 1, "the map shows the JOBS chip (%d)" % chips)


func _walk(node: Node, into: Array) -> Array:
	for c in node.get_children():
		into.append(c)
		_walk(c, into)
	return into
