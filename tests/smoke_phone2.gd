extends Node
## S5.9 PHONE COMPLETE: seven apps, the taxi map, the journal, the
## dynamic contacts, the settings sliders, the typewriter, the
## voicemail.
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
		print("PH2 PASS %s" % what)
	else:
		_fail += 1
		print("PH2 FAIL %s" % what)

func _ph() -> Node:
	return get_tree().get_first_node_in_group("phone")

func _labels() -> Array:
	var out: Array = []
	if _ph() == null:
		return out
	var phn := _ph()
	if phn == null:
		return out
	var body := phn.get_node_or_null("Root/Slab/SlabCol/BodyScroll/Body")
	if body == null:
		return out
	for l in body.get_children():
		if l is Label and is_instance_valid(l):
			out.append(l)
	return out

func _ready() -> void:
	var dog := get_tree().create_timer(160.0, true, false, true)
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
	var ph := _ph()
	_check(ph != null, "the phone rides Game")
	if ph == null:
		_finish()
		return
	# --- the seven apps on a grid
	ph.open(false)
	await _wait_s(0.3)
	var grid := ph.get_node("Root/Slab/SlabCol/Tabs") as GridContainer
	_check(grid != null and grid.get_child_count() == 8,
			"eight apps on the tab grid")
	# --- THE MAP + THE TAXI
	ph._set_tab("MAP")
	await _wait_s(0.3)
	var mapc: Control = null
	for c in ph.get_node("Root/Slab/SlabCol/BodyScroll/Body").get_children():
		if c is Control and not (c is Label) and not (c is Button):
			mapc = c
	_check(mapc != null and mapc is Control,
			"the city diagram draws")
	WorldState.set_value("clean_cash", 200.0)
	WorldState.set_value("stash_cash", 0.0)
	ph._taxi("club_district")
	await _wait_s(2.0)
	_check(Game.area_id == "club_district",
			"the taxi crosses the city")
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 175.0),
			"the meter runs $25 clean")
	# broke: no ride
	WorldState.set_value("clean_cash", 0.0)
	var ev0 := WorldState.event_log().size()
	ph._taxi("docks")
	await _wait_s(0.5)
	_check(Game.area_id == "club_district" and WorldState.event_log(
			).size() > ev0, "a broke pocket gets no cab (vendor_no)")
	# --- THE JOURNAL
	var ms := get_tree().get_first_node_in_group("missions")
	ms.start("res://data/missions/m2.tres")
	await _wait_s(0.4)
	ph._set_tab("NOTES")
	await _wait_s(0.3)
	var txt := ""
	for l in _labels():
		txt += str((l as Label).text) + "\n"
	_check(txt.contains("FIRST BLOOD") and txt.contains("muscle"),
			"NOTES shows the active contract + objective")
	WorldState.set_flag("mission_done:m3")
	ph._fill_dirty = true
	ph._fill()
	await _wait_s(0.2)
	txt = ""
	for l in _labels():
		txt += str((l as Label).text) + "\n"
	_check(txt.contains("THE OLD DRUNK"),
			"NOTES keeps the done list")
	# --- THE CONTACTS (introduced by the story)
	WorldState.set_flag("mission_done:m0")
	WorldState.set_flag("mission_done:m2")
	WorldState.set_flag("mission_done:m1")
	WorldState.set_flag("m3_talked")
	ph._set_tab("CONTACTS")
	await _wait_s(0.3)
	txt = ""
	for l in _labels():
		txt += str((l as Label).text) + "\n"
	_check(txt.contains("THE BROTHER") and txt.contains("TONY")
			and txt.contains("MARLA") and txt.contains("trust 70"),
			"CONTACTS: the cast the story introduced, trust 70")
	WorldState.set_value("trust:tony", 85.0)
	ph._fill_dirty = true
	ph._fill()
	await _wait_s(0.2)
	txt = ""
	for l in _labels():
		txt += str((l as Label).text) + "\n"
	_check(txt.contains("trust 85"),
			"trust moves with the story (tony 85)")
	# --- THE SETTINGS sliders move real buses
	ph._set_tab("SETTINGS")
	await _wait_s(0.3)
	var sliders: Array = []
	for c in ph.get_node("Root/Slab/SlabCol/BodyScroll/Body").get_children():
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is HSlider:
					sliders.append(cc)
	_check(sliders.size() >= 3, "three volume sliders")
	var before := AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("SFX"))
	(sliders[2] as HSlider).set_value_no_signal(0.1)
	(sliders[2] as HSlider).value_changed.emit(0.1)
	await _wait_s(0.2)
	_check(AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("SFX")) < before - 10.0,
			"the SFX slider turns the real bus down")
	# --- THE TYPEWRITER + THE VOICEMAIL
	ph.ring({"from": "THE BROTHER", "duration": 30.0,
			"lines": ["You picked up. Good."],
			"choices": [{"label": "LISTEN", "flag": "bro_heard"}],
			"decline": {}})
	ph._answer()
	await _wait_s(0.3)
	var typing := false
	for l in _labels():
		if (l as Label).visible_characters \
				< (l as Label).text.length():
			typing = true
	_check(typing, "the line types out (characters hidden)")
	await _wait_s(4.0)
	var btns: Array = []
	for c in ph.get_node("Root/Slab/SlabCol/BodyScroll/Body").get_children():
		if c is Button:
			btns.append(c)
	_check(btns.size() >= 1
			and is_equal_approx(
			float((btns[0] as Button).modulate.a), 1.0),
			"the choice arrives after the last word")
	ph._choice(0)
	await _wait_s(0.3)
	_check(WorldState.flag("bro_heard"), "the choice lands")
	ph._set_tab("CALLS")
	await _wait_s(0.3)
	# the log entry carries the call; replay re-reads it
	var has_voicemail := false
	for c in ph.get_node("Root/Slab/SlabCol/BodyScroll/Body").get_children():
		if c is Button and str((c as Button).text) \
				== "PLAY VOICEMAIL":
			has_voicemail = true
			(c as Button).pressed.emit()
	_check(has_voicemail, "the call log offers the voicemail")
	await _wait_s(0.3)
	_check(not ph._replay.is_empty(),
			"the voicemail replays the call")
	_finish()

func _finish() -> void:
	print("PH2 RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
