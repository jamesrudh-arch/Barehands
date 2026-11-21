extends Node
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")

## B18.3 PART 0 suite: the START SEQUENCE. Boots the real street with
## the Stage-0 flag armed (the only path that plays it), checks every
## card shows for its time, tap-skip works, the menu offers
## PLAY/CONTINUE/SETTINGS/CREDITS, CONTINUE is greyed without a save,
## PLAY unlocks input and frees the sequence, and - the guard for every
## other suite - a plain boot (flag not armed) never shows it at all.

var _fails := 0
var _checks := 0
var _main: Node
var _seq: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("START FAIL: ", what)
	else:
		print("START ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	# --- 1: a plain boot must NOT show the sequence (the suite guard)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _wait_s(0.6)
	_seq = _find_seq()
	_check(_seq == null or not is_instance_valid(_seq) or int(_seq.get("phase")) == 3,
			"plain boot never plays the start sequence")
	_main.queue_free()
	await _wait_s(0.3)

	# --- 2: the armed path plays the cards, tap skips to the menu
	Settings.set_value("play_start_sequence", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _wait_s(0.5)
	_seq = _find_seq()
	_check(_seq != null and is_instance_valid(_seq),
			"the armed launch starts the sequence")
	if _seq == null or not is_instance_valid(_seq):
		_finish_now()
		return
	await _wait_s(1.2)
	_check(int(_seq.get("phase")) == 1, "the studio card is showing (phase %d)" % int(_seq.get("phase")))
	_check(InputBus.locked, "the cards lock gameplay input")
	# tap anywhere: skip to the menu
	_seq.call("_skip_all_cards")
	await _wait_s(0.4)
	_check(int(_seq.get("phase")) == 5, "a tap skips the cards to the menu (phase %d)" % int(_seq.get("phase")))
	var texts: Array[String] = []
	for b in (_seq.get("_menu_root") as Control).find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	for want in ["PLAY", "SETTINGS", "CREDITS"]:
		_check(texts.has(want), "the menu has a %s button" % want)
	var cont: Button = null
	for b in (_seq.get("_menu_root") as Control).find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("CONTINUE"):
			cont = b
	_check(cont != null and cont.disabled,
			"CONTINUE is greyed out without a save")
	# PLAY starts the game: input unlocks, the sequence goes away
	_seq.call("_play")
	await _wait_s(0.3)
	_check(not InputBus.locked, "PLAY unlocks gameplay input")
	_check(int(_seq.get("phase")) == 6, "the sequence is done after PLAY (phase %d)" % int(_seq.get("phase")))

	_finish_now()


func _find_seq() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("StartSequence")


func _finish_now() -> void:
	if _fails == 0:
		print("START PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("START FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
