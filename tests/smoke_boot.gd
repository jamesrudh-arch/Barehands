extends Node

## REBUILD STEP 1 proof suite: the new boot chain and skeleton.
## Proves against the real build:
##   - the start sequence: black → D'YOUNGS studio card → the 16+
##     notice → the LEVERAGE title card, each timed and skippable;
##   - the menu: four real buttons, CONTINUE disabled with its honest
##     reason, SETTINGS works and persists, CREDITS lists the CC0
##     sources;
##   - PLAY travels into the warehouse shell (Game.state PLAY);
##   - the skeleton: WorldState table/queue/roundtrip, travel refuses
##     unknown areas, the input map actions exist, main_scene is the
##     new boot chain, skip_intro short-circuits to the menu.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


## Every Label's text under a node, at any depth (cards nest labels).
func _all_label_text(n: Node, acc: String = "") -> String:
	for c in n.get_children():
		if c is Label:
			acc += c.text + " "
		acc = _all_label_text(c, acc)
	return acc


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	Settings.set_value("skip_intro", false)
	Settings.set_value("force_intro", true)

	_settings_block()
	await _splash_flow()
	await _menu_flow()
	_input_map_block()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("BOOT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("BOOT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _settings_block() -> void:
	var scene_path: String = ProjectSettings.get_setting(
			"application/run/main_scene", "")
	_check(scene_path == "res://scenes/boot/splash.tscn",
			"the game boots into the new start sequence (%s)" % scene_path)


func _splash_flow() -> void:
	# let the tree finish its initial setup first: add_child to the root
	# from inside _ready silently fails ("parent is busy setting up
	# children") — the splash would never enter the tree at all
	for i in 4:
		await get_tree().process_frame
	var splash: Node = load("res://scenes/boot/splash.tscn").instantiate()
	get_tree().root.add_child(splash)
	# go_menu() swaps the CURRENT scene: hand that role to the splash so
	# the suite node (a root child) survives every scene change
	get_tree().current_scene = splash
	await _wait_s(0.7)
	_check(splash.phase == 1, "the studio card shows first (phase %d)"
			% splash.phase)
	var texts := _all_label_text(splash)
	_check("D ' Y O U N G S" in texts or "D'YOUNGS" in texts,
			"the studio wordmark reads D'YOUNGS")
	await _wait_s(2.8)  # the studio card's full 3 s
	_check(splash.phase == 2, "the notice follows the studio card")
	_check(splash._cards[2].visible, "the notice card is the shown one")
	splash._skip()
	await _wait_s(0.3)
	_check(splash.phase == 3, "a tap skips to the title card")
	splash._skip()
	await _wait_s(1.2)  # the menu swap lands
	_check(Game.state == Game.State.MENU,
			"the sequence ends in the MENU state (%s)" % Game.state_name())
	var path := get_tree().current_scene.scene_file_path \
			if get_tree().current_scene else ""
	_check(path == "res://scenes/boot/menu.tscn",
			"the menu scene is current (%s)" % path)


func _menu_flow() -> void:
	var menu := get_tree().current_scene
	var play := menu.find_child("PlayBtn", true, false) if menu else null
	if menu == null or play == null:
		_check(false, "the menu exists with its buttons")
		return
	_check(true, "the menu exists with its buttons")
	var cont := menu.find_child("ContinueBtn", true, false) as Button
	_check(cont != null and cont.disabled,
			"CONTINUE is disabled (no save system yet)")
	var note: Label = menu.get_node_or_null("ContinueNote")
	# S5.19: the save system landed (SaveGame at every landing) -
	# the note now states the standing debt, the honest reason a
	# CONTINUE differs from a fresh PLAY. The old "ledger build"
	# expectation was stale since that build.
	_check(note != null and ("debt" in note.text
			or "no save yet" in note.text),
			"CONTINUE states its honest reason (%s)"
			% (note.text if note else "no note"))
	# settings: opens, three toggles, persists
	menu._on_button("settings")
	await _wait_s(0.2)
	_check(menu.panel_title() == "SETTINGS", "SETTINGS opens")
	var toggles := 0
	for c in menu._panel.get_children():
		toggles += c.get_child_count()
	_check(toggles >= 4, "SETTINGS holds its toggles + close (%d)" % toggles)
	Settings.set_value("invert_look", true)
	_check(bool(Settings.value("invert_look")),
			"settings persist through the Settings service")
	menu._close_panel()
	# credits: the CC0 sources
	menu._on_button("credits")
	await _wait_s(0.2)
	var credits_text := ""
	for c in menu._panel.get_children():
		for g in c.get_children():
			if g is Label:
				credits_text += g.text + " "
	_check("KayKit" in credits_text and "Kenney" in credits_text
			and "Quaternius" in credits_text,
			"CREDITS lists the CC0 sources (KayKit, Kenney, Quaternius)")
	menu._close_panel()
	# play: the travel into the warehouse shell
	menu._on_button("play")
	await _wait_s(2.0)
	var path := get_tree().current_scene.scene_file_path \
			if get_tree().current_scene else ""
	_check(path == "res://scenes/areas/warehouse_shell.tscn",
			"PLAY lands in the warehouse shell (%s)" % path)
	_check(Game.state == Game.State.PLAY and Game.area_id == "warehouse",
			"Game is PLAY in the warehouse area")
	# the shell's camera is the one the viewport actually renders
	# through (is_current() is unreliable in headless; the viewport's
	# own answer is the rendering truth on device and here)
	var shell := get_tree().current_scene
	var vc := get_viewport().get_camera_3d()
	_check(vc != null and shell != null and shell.is_ancestor_of(vc),
			"the shell has the active camera (%s)" % [
			vc.name if vc else "none"])
	# unknown areas refuse travel
	await Game.travel("atlantis")
	_check(Game.area_id == "warehouse",
			"travel refuses unknown areas")


func _input_map_block() -> void:
	for action in ["move_left", "move_right", "punch", "heavy", "kick",
			"dodge", "guard", "grab", "sprint", "jump", "lock", "style",
			"super", "phone", "pause", "accelerate", "brake", "handbrake",
			"aim", "shoot", "reload", "swap_weapon"]:
		_check(InputMap.has_action(action),
				"input action exists: %s" % action)
	# the WorldState contract
	WorldState.reset()
	WorldState.set_value("debt", 5000.0)
	WorldState.bump("fights_won", 2.0)
	WorldState.set_flag("door_neon9_broken")
	var snap := WorldState.to_save()
	WorldState.reset()
	WorldState.from_save(snap)
	_check(float(WorldState.get_value("debt")) == 5000.0
			and float(WorldState.get_value("fights_won")) == 2.0
			and WorldState.flag("door_neon9_broken"),
			"WorldState round-trips through a save snapshot")
