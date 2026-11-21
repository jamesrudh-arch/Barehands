extends Node
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_SettingsUI := preload("res://scripts/settings_ui.gd")
## Batch 14 suite: the difficulty knobs. Three streets - STREET is
## the night as written (bible 14, every old number untouched), HARD
## and BRUTAL turn three screws the player can feel: enemies take
## more sticks to drop, their tells come faster, and hits drain more
## Composure. All of it under one Settings key with a picker in the
## SETTINGS screen.

var _fails := 0
var _checks := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("DIFF FAIL: ", what)
	else:
		print("DIFF ok: ", what)


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
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.2)

	await _test_the_three_streets()
	await _test_enemy_scaling()
	await _test_telegraph_scaling()
	await _test_composure_scaling()
	await _test_the_picker()
	await _test_persistence()
	await _test_street_is_the_bible()

	if _fails == 0:
		print("DIFF PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("DIFF FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _set_diff(d: String) -> void:
	Settings.set_value("difficulty", d)


## A fresh enemy of a kind, spawned under the current difficulty.
func _spawn(kind: int) -> CharacterBody3D:
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	e.set("kind", kind)
	add_child(e)
	e.global_position = Vector3(40.0, 0.02, 40.0)
	return e


# --- A. the three streets are three multipliers -----------------------------------


func _test_the_three_streets() -> void:
	_set_diff("street")
	_check(absf(Settings.diff_mult("hp") - 1.0) < 0.001
			and absf(Settings.diff_mult("telegraph") - 1.0) < 0.001
			and absf(Settings.diff_mult("composure") - 1.0) < 0.001,
			"street is the 1.0 baseline")
	_set_diff("hard")
	_check(absf(Settings.diff_mult("hp") - float(Tuning.v("hard_hp"))) < 0.001
			and absf(Settings.diff_mult("telegraph")
				- float(Tuning.v("hard_telegraph"))) < 0.001,
			"hard reads its screws from tuning")
	_set_diff("brutal")
	_check(absf(Settings.diff_mult("hp") - float(Tuning.v("brutal_hp"))) < 0.001
			and absf(Settings.diff_mult("composure")
				- float(Tuning.v("brutal_composure"))) < 0.001,
			"brutal reads its screws from tuning")


# --- B. enemies take more sticks on harder streets ----------------------------------------


func _test_enemy_scaling() -> void:
	var base := 12  # a bruiser's floor (bible numbers, hit-count)
	_set_diff("street")
	var e := _spawn(2)
	_check(int(e.get("max_hp")) == base,
			"a bruiser drops in %d on street ($max_hp)" % int(e.get("max_hp")))
	e.queue_free()
	_set_diff("hard")
	e = _spawn(2)
	_check(int(e.get("max_hp")) == int(round(base * float(Tuning.v("hard_hp")))),
			"hard thickens the bruiser (%d)" % int(e.get("max_hp")))
	e.queue_free()
	_set_diff("brutal")
	e = _spawn(2)
	_check(int(e.get("max_hp")) == int(round(base * float(Tuning.v("brutal_hp")))),
			"brutal doubles the bruiser (%d)" % int(e.get("max_hp")))
	e.queue_free()
	# the boss keeps his scale
	var boss := 30
	_set_diff("brutal")
	e = _spawn(4)
	_check(int(e.get("max_hp")) == int(round(boss * float(Tuning.v("brutal_hp")))),
			"the boss reads the street too (%d)" % int(e.get("max_hp")))
	e.queue_free()


# --- C. the tells come faster -----------------------------------------------------------------


func _test_telegraph_scaling() -> void:
	_set_diff("street")
	var e := _spawn(1)
	var base: float = e.call("_telegraph_time")
	e.queue_free()
	_set_diff("hard")
	e = _spawn(1)
	var hard: float = e.call("_telegraph_time")
	e.queue_free()
	_set_diff("brutal")
	e = _spawn(1)
	var brutal: float = e.call("_telegraph_time")
	e.queue_free()
	_check(absf(base - 0.6) < 0.01,
			"street tells at the tuning base (%.2f)" % base)
	_check(absf(hard / base - float(Tuning.v("hard_telegraph"))) < 0.02,
			"hard tells come faster (%.2f vs %.2f)" % [hard, base])
	_check(absf(brutal / base - float(Tuning.v("brutal_telegraph"))) < 0.02,
			"brutal tells bite (%.2f vs %.2f)" % [brutal, base])


# --- D. mistakes cost more nerve ---------------------------------------------------------------------


func _test_composure_scaling() -> void:
	_set_diff("street")
	Composure.reset()
	Composure.drain(18.0)
	var street_drain := 100.0 - Composure.value
	Composure.reset()
	_set_diff("hard")
	Composure.drain(18.0)
	var hard_drain := 100.0 - Composure.value
	Composure.reset()
	_set_diff("brutal")
	Composure.drain(18.0)
	var brutal_drain := 100.0 - Composure.value
	Composure.reset()
	_check(absf(street_drain - 18.0) < 0.01,
			"street: a hit drains the bible's 18 (%.1f)" % street_drain)
	_check(absf(hard_drain / street_drain
			- float(Tuning.v("hard_composure"))) < 0.02,
			"hard: the same hit drains more (%.1f)" % hard_drain)
	_check(absf(brutal_drain / street_drain
			- float(Tuning.v("brutal_composure"))) < 0.02,
			"brutal: the same hit drains half again (%.1f)" % brutal_drain)


# --- E. the picker in SETTINGS ------------------------------------------------------------------------


func _test_the_picker() -> void:
	_set_diff("street")
	var ui := get_tree().get_first_node_in_group("settings_ui") as CLS_SettingsUI
	_check(ui != null, "the SETTINGS screen is in the tree")
	ui.open()
	await _wait_s(0.3)
	var buttons := ui.find_children("Difficulty_*", "Button", true, false)
	_check(buttons.size() == 3, "three streets offered (%d)" % buttons.size())
	var street_on := false
	for b in buttons:
		if (b as Button).name == "Difficulty_street" \
				and (b as Button).modulate.r > 1.2:
			street_on = true
	_check(street_on, "the active street glows")
	# picking HARD flips the glow and the lever
	(buttons[1] as Button).pressed.emit()
	await _wait_s(0.2)
	_check(str(Settings.value("difficulty")) == "hard",
			"tapping HARD picks the harder street")
	var hard_glow := false
	for b in buttons:
		if (b as Button).name == "Difficulty_hard" \
				and (b as Button).modulate.r > 1.2:
			hard_glow = true
	_check(hard_glow, "the glow follows the pick")
	ui._close()
	await _wait_s(0.2)


# --- F. the street remembers ------------------------------------------------------------------------------


func _test_persistence() -> void:
	_set_diff("brutal")
	Settings.load_all()
	_check(str(Settings.value("difficulty")) == "brutal",
			"the street persists across a reload")
	_set_diff("street")
	Settings.load_all()
	_check(str(Settings.value("difficulty")) == "street",
			"and back again")


# --- G. street is the bible's night, untouched ------------------------------------------------------------------------


func _test_street_is_the_bible() -> void:
	_set_diff("street")
	var e := _spawn(2)
	_check(int(e.get("max_hp")) == 12 and absf(e.call("_telegraph_time")
			- 0.8) < 0.01,
			"street keeps the old numbers (hp %d)" % int(e.get("max_hp")))
	e.queue_free()
	Composure.reset()
	Composure.drain(10.0)
	_check(absf(100.0 - Composure.value - 10.0) < 0.01,
			"street composure drain is unscaled")
	Composure.reset()
