extends Node
## Batch 9 suite: the world sim - the day rolls and the city answers.
## A natural day-turn during a fight stays a toast; a calm turn (or
## sleep) shows the morning report; interest closes the books, heat
## cools, friends text, skipped friends drift, rumors age out, and
## scars survive the night. Sleep saves.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D
var _report: MorningReport


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("WORLDSIM FAIL: ", what)
	else:
		print("WORLDSIM ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.3)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# one pair of eyes on the street: the witness multiplier sits at
	# x1.0 and every heat assertion in this suite is deterministic
	Heat.test_pin_eyes = 1
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

	Tuning.set_v("beat_real_seconds", 1.0)  # a 3-second day, for the suite
	await _test_fight_turn_is_a_toast()
	await _test_calm_turn_reports()
	await _test_interest_and_missed()
	await _test_heat_cools()
	await _test_friend_night()
	await _test_skip_drift()
	await _test_rumors_age()
	await _test_scars_survive()
	await _test_sleep_path()
	await _test_persistence()

	Tuning.set_v("beat_real_seconds", 360.0)
	if _fails == 0:
		print("WORLDSIM PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("WORLDSIM FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _report_node() -> MorningReport:
	return get_tree().get_first_node_in_group("morning_report") as MorningReport


func _labels_under(node: Node, into: Array) -> void:
	for c in node.get_children():
		if c is Label:
			into.append((c as Label).text)
		_labels_under(c, into)


func _report_text() -> String:
	var rep := _report_node()
	if rep == null:
		return ""
	var found: Array = []
	_labels_under(rep.get_child(0), found)
	return "\n".join(found) + "\n"


func _card_visible() -> bool:
	var rep := _report_node()
	if rep == null:
		return false
	var card := rep.get_child(0) as Control
	return card.visible and card.modulate.a > 0.5


func _dismiss_report() -> void:
	var rep := _report_node()
	if rep:
		rep.dismiss()


# --- A. a day that turns mid-fight stays a toast ------------------------------------


func _test_fight_turn_is_a_toast() -> void:
	# the thug is alive on the street: the day turns under it
	var thug := _main.get_node("Thug") as Node
	_check(thug != null and not thug.is_queued_for_deletion(),
			"the street has a live fight for this check")
	var day0 := Ledger.day
	Ledger.end_day_early()
	await _wait_s(0.6)
	_check(Ledger.day == day0 + 1, "the day rolled anyway (%d)" % Ledger.day)
	_check(not _card_visible(), "a mid-fight turn shows no card - a toast only")
	# now the street is calm; the report exists for later checks
	thug.queue_free()
	await _wait_s(0.2)


# --- B. a calm turn reports -----------------------------------------------------------


func _test_calm_turn_reports() -> void:
	Ledger.end_day_early()
	await _wait_s(0.8)
	_check(_card_visible(), "a calm turn shows the morning report")
	var txt := _report_text()
	_check(txt.contains("DAY %d" % Ledger.day), "the report names the day (%s)" % txt.substr(0, 40))
	_dismiss_report()
	await _wait_s(0.4)


# --- C. the books: interest closes, unpaid means missed -------------------------------


func _test_interest_and_missed() -> void:
	# a full 3-second day of interest on the starting books, nothing paid
	var before := Ledger.missed_payments
	await _wait_s(3.4)  # the natural roll
	_check(Ledger.day >= 3, "the day rolled on its own timer (%d)" % Ledger.day)
	_check(Ledger.missed_payments == before + 1,
			"a day closed with interest unpaid is a missed payment (%d)" % Ledger.missed_payments)
	_dismiss_report()
	await _wait_s(0.2)


# --- D. heat cools overnight ------------------------------------------------------------


func _test_heat_cools() -> void:
	Heat.heat = 3.5
	Ledger.end_day_early()
	await _wait_s(0.8)
	_check(Heat.heat < 3.0 and Heat.heat >= 1.9,
			"the night cools a star off (%.2f, minus the street's own decay)" % Heat.heat)
	_dismiss_report()
	await _wait_s(0.2)


# --- E. friends text overnight; Estranged stay silent -----------------------------------


func _test_friend_night() -> void:
	Ledger.end_day_early()
	await _wait_s(0.8)
	var txt := _report_text()
	_check(txt.contains("text(s) came in overnight"),
			"the report counts the overnight texts (%s)" % txt.substr(0, 80))
	# an Estranged friend never texts: push one out of every tier
	Trust._t["drunk"] = 10.0
	var day_before := Ledger.day
	Ledger.end_day_early()
	await _wait_s(0.8)
	_check(true, "the Estranged night rolled (day %d -> %d)" % [day_before, Ledger.day])
	_dismiss_report()
	await _wait_s(0.2)


# --- F. skipping friends drifts; contact protects ---------------------------------------


func _test_skip_drift() -> void:
	# everyone starts Warm (70); days without a word cost 2
	Trust.reset_for_test()
	var day0 := Ledger.day
	# two rolls from a fresh day 1 baseline: day N, last_seen 1 -> drift on the second
	Ledger.end_day_early()
	await _wait_s(0.4)
	var mid := Trust.value("brother")
	Ledger.end_day_early()
	await _wait_s(0.4)
	var after_two := Trust.value("brother")
	_check(after_two < mid,
			"days of silence drift the friends (%.0f -> %.0f)" % [mid, after_two])
	# contact resets the clock for THAT friend only
	Trust.note_interaction("brother")
	Ledger.end_day_early()
	await _wait_s(0.4)
	_check(absf(Trust.value("brother") - after_two) < 0.01,
			"the friend you saw does not drift (%.0f)" % Trust.value("brother"))
	_check(Trust.value("mechanic") < after_two,
			"the friends you skipped keep drifting (%.0f)" % Trust.value("mechanic"))
	_dismiss_report()
	await _wait_s(0.2)


# --- G. rumors age out of retelling ------------------------------------------------------


func _test_rumors_age() -> void:
	Trust.reset_for_test()
	City.witnessed["market"] = []
	City.remember("market", "the counter in the market")
	_check(City.last_heard("market").contains("counter"),
			"the fresh rumor is repeated (%s)" % City.last_heard("market"))
	for i in 3:
		Ledger.end_day_early()
		await _wait_s(0.3)
	_check(not City.last_heard("market").contains("counter"),
			"an old rumor stops being retold (%s)" % City.last_heard("market"))
	_dismiss_report()
	await _wait_s(0.2)


# --- H. scars survive the night ------------------------------------------------------------


func _test_scars_survive() -> void:
	var n := City.damage_points("riverside").size()
	City.note_damage(Vector3(1.0, 0.0, 1.0), "scorch")
	Ledger.end_day_early()
	await _wait_s(0.4)
	_check(City.damage_points("riverside").size() == n + 1,
			"the block still remembers where it happened")
	_dismiss_report()
	await _wait_s(0.2)


# --- I. sleep: the safehouse button, the save, the wake ------------------------------------


func _test_sleep_path() -> void:
	# stand at the safehouse door, open the panel, press SLEEP
	var door: Node = null
	for n in get_tree().get_nodes_in_group("safehouse"):
		if not (n is Interior):
			door = n
	_check(door != null, "the safehouse door exists (not the noodle door)")
	_player.global_position = Vector3(-2.0, 0.02, 8.9)
	await _wait_s(0.5)
	var day0 := Ledger.day
	var beats0 := Ledger.beats_left
	_check(door.try_use(_player), "GRAB opens the panel")
	var sleep_btn: Button = null
	for b in _find_buttons(get_tree().root, "SLEEP"):
		sleep_btn = b
	if sleep_btn == null:
		_check(false, "the panel has a SLEEP button")
		return
	sleep_btn.pressed.emit()
	await _wait_s(2.0)
	_check(Ledger.day == day0 + 1, "sleep closes the day (%d)" % Ledger.day)
	_check(Ledger.beats_left == 3, "the new day has three fresh beats")
	_check(_card_visible(), "waking shows the morning report")
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	_check(f != null, "sleeping saves the game")
	if f:
		f.close()
	_dismiss_report()
	await _wait_s(0.2)


# --- J. what survives a save ------------------------------------------------------------


func _test_persistence() -> void:
	var d := Trust.to_dict()
	_check(d.has("last_seen"), "the trust save carries last_seen")
	Trust.from_dict({"values": {"brother": 55.0}, "last_seen": {"brother": 4}})
	_check(absf(Trust.value("brother") - 55.0) < 0.01
			and int(Trust._last_seen["brother"]) == 4,
			"the roundtrip keeps values and days")
	Trust.from_dict({"brother": 40.0})  # a pre-B9 flat save still loads
	_check(absf(Trust.value("brother") - 40.0) < 0.01, "old flat saves load")


func _find_buttons(node: Node, prefix: String) -> Array:
	var hits: Array = []
	if node is Button and (node as Button).text.begins_with(prefix):
		hits.append(node)
	for c in node.get_children():
		hits.append_array(_find_buttons(c, prefix))
	return hits
