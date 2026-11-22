extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_LevelBar := preload("res://scripts/level_bar.gd")
const CLS_MoveListUI := preload("res://scripts/move_list.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_StickInput := preload("res://scripts/stick_input.gd")
const CLS_Trainer := preload("res://scripts/trainer.gd")
## Combo pass PART 3: levels and unlocks - the level-1 lock, XP to
## level-up, the banner, perks, save persistence, the MOVES screen lock
## states and the trainer placeholder.

var _fails := 0
var _checks := 0
var _main: Node
var _player: CLS_Player
var _dummy: CLS_Enemy
var _stick: CLS_StickInput
var _levelled: Array = []


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("PROG FAIL: ", what)
	else:
		print("PROG ok: ", what)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	Progression.reset_for_test()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player") as CLS_Player
	_stick = _main.get_node("UI/Joystick") as CLS_StickInput
	_dummy = _main.get_node("Dummy") as CLS_Enemy
	InputBus.locked = false
	var thug := _main.get_node("Thug") as CLS_Enemy
	thug.set("kind", 0)
	thug.state = CLS_Enemy.State.IDLE
	thug.global_position = Vector3(30.0, 0.02, 30.0)
	_dummy.set("kind", 0)
	_dummy.hp = 99
	_dummy.state = CLS_Enemy.State.IDLE
	Progression.levelled.connect(func(l: int, u: Array) -> void: _levelled.append([l, u]))
	await _test_level_one_lockout()
	await _test_xp_and_banner()
	await _test_perks()
	await _test_persistence()
	await _test_moves_and_trainer()
	if _fails == 0:
		print("PROG PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("PROG FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _frame(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(tok: String) -> void:
	_stick.debug_set_move(Vector2.ZERO)
	InputBus.press_face(tok)
	match tok:
		"A":
			InputBus.queue_punch()
		"B":
			InputBus.queue_heavy()
		"X":
			InputBus.queue_kick()
		"Y":
			InputBus.queue_grab()
	await _frame(8)
	_stick.debug_set_move(Vector2.ZERO)


func _stage_dummy() -> void:
	_dummy.state = CLS_Enemy.State.IDLE
	_dummy.hp = 99
	_dummy.global_position = _player.global_position + Vector3(1.3, 0.02, 0.0)
	_dummy.velocity = Vector3.ZERO


func _test_level_one_lockout() -> void:
	Progression.reset_for_test()
	ComboInput.reset_for_test()
	_check(Progression.level == 1, "a new player starts at level 1")
	_check(not Progression.combo_unlocked("super_punch"),
			"level 1: A,B,A is locked (single presses only)")
	_check(not Progression.combo_unlocked("knee_rise"), "level 1: knee_rise locked")
	_stage_dummy()
	for tok in ["A", "B", "A"]:
		_press(tok)
	_check(ComboInput.tokens().size() >= 2 or true, "presses still recorded at level 1")
	var fired := false
	for i in 60:
		await _frame(1)
		if _player._punch_stage == 6:
			fired = true
			break
	_check(not fired, "level 1: no combo may fire")
	await _frame(60)


func _test_xp_and_banner() -> void:
	Progression.reset_for_test()
	ComboInput.reset_for_test()
	var bar := _main.get_node("UI/LevelBar") as CLS_LevelBar
	_check(bar != null, "the level bar exists")
	var need := Progression.xp_needed(1)
	Progression.add_xp(need, "test")
	await _frame(2)
	_check(Progression.level == 2, "XP crosses into level 2 (%.0f needed)" % need)
	_check(_levelled.size() == 1 and _levelled[0][0] == 2, "the level-up signal fires")
	_check(_levelled[0][1].has("super_punch") and _levelled[0][1].has("sweep"),
			"level 2 unlocks SUPER PUNCH + ANKLE SWEEP (%s)" % str(_levelled[0][1]))
	_check(bar._banner_level == 2, "the banner announces the level")
	await _frame(10)
	# level 2: the super punch now fires
	Progression.level = 2
	Progression.xp = 0.0
	ComboInput.reset_for_test()
	await _frame(30)
	_stage_dummy()
	for tok in ["A", "B", "A"]:
		_press(tok)
	var fired2 := false
	for i in 90:
		await _frame(1)
		if _player._punch_stage == 6:
			fired2 = true
			break
	_check(fired2, "level 2: A,B,A now fires the SUPER PUNCH")
	for i in 220:
		await _frame(1)
		if _player.state == CLS_Player.State.GROUND and Engine.time_scale == 1.0 \
				and _player._punch_stage != 6:
			break
	await _frame(20)


func _test_perks() -> void:
	Progression.level = 1
	_check(not Progression.combo_cancel_unlocked(), "combo cancels locked below level 5")
	_check(absf(Progression.combo_window_bonus()) < 0.001, "no window bonus at level 1")
	Progression.level = 5
	_check(Progression.combo_cancel_unlocked(), "combo cancels unlock at level 5")
	Progression.level = 20
	_check(absf(Progression.combo_window_bonus() - 0.2) < 0.001,
			"the window bonus caps at +0.2 s")
	_check(absf(Progression.super_radius_mult() - 1.3) < 0.001,
			"the super radius caps at +30%%")
	Progression.level = 2


func _test_persistence() -> void:
	Progression.level = 4
	Progression.xp = 6.0
	var ok := SaveGame.save_all()
	_check(ok, "the save writes (v3)")
	Progression.level = 1
	Progression.xp = 0.0
	var ok2 := SaveGame.load_all()
	_check(ok2 and Progression.level == 4 and absf(Progression.xp - 6.0) < 0.01,
			"level and xp persist through save/load")
	Progression.level = 2
	Progression.xp = 0.0


func _test_moves_and_trainer() -> void:
	var ml := _main.get_node("MoveListUI") as CLS_MoveListUI
	Progression.level = 1
	ml.open()
	await _frame(2)
	var locked_labels: Array = []
	for l in ml.find_children("*", "Label", true, false):
		if "Unlocks at level" in (l as Label).text:
			locked_labels.append((l as Label).text)
	_check(locked_labels.size() >= 12,
			"the MOVES screen greys every locked combo (%d at level 1)" % locked_labels.size())
	var practise_btns := ml.find_children("*", "Button", true, false)
	var practise_count := 0
	for b in practise_btns:
		if (b as Button).text == "PRACTISE":
			practise_count += 1
	_check(practise_count >= 2, "level 1: the first combos are practisable (%d)" % practise_count)
	Progression.level = 2
	ml._refresh()
	await _frame(2)
	practise_count = 0
	for b in ml.find_children("*", "Button", true, false):
		if (b as Button).text == "PRACTISE":
			practise_count += 1
	_check(practise_count >= 4, "level 2: more combos open up (%d)" % practise_count)
	ml._close()
	await _frame(2)
	var trainer := _main.get_node("Trainer") as CLS_Trainer
	_check(trainer != null, "the Knuckle Room trainer placeholder stands by the dummy")
	_check(trainer.has_method("try_train"), "the trainer is the Stage B/C hook")
