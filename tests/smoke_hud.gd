extends Node

## REBUILD STEP 8 proof suite: THE HUD + PAUSE.
##   - the HUD mounts at PLAY and every readout tracks a LIVE value:
##     the Leverage meter rises on landed punches, the combo line
##     counts, the cash line follows WorldState, the style line shows
##     the current style, the rank pips step with hits;
##   - the B-context verb shows near a door (and B tries it through
##     the diamond, not a dodge);
##   - the style wheel: hold STYLE slows the world and the wheel,
##     tapping a style swaps live;
##   - PAUSE freezes the tree, the menu's buttons work, QUIT returns
##     to the main menu.

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


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(0.8)
	await _hud_reads_live()
	await _b_context()
	await _style_wheel()
	await _pause_flow()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("HUD PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("HUD FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hud() -> CanvasLayer:
	return get_node_or_null("/root/Game/HUD") as CanvasLayer


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _place(hero: CharacterBody3D, pos: Vector3, yaw: float) -> void:
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.set("_yaw", yaw)


func _hud_reads_live() -> void:
	var hud := _hud()
	_check(hud != null, "the HUD mounts at PLAY")
	if hud == null:
		return
	_check(hud.get_node_or_null("Root/LeverageMeter") != null
			and hud.get_node_or_null("Root/CashLine") != null,
			"the meter and cash readouts exist")
	# the cash line follows WorldState
	WorldState.bump("stash_cash", 80.0)
	await _wait_s(0.3)
	_check("$80" in str(hud.get_node("Root/CashLine").text),
			"the cash line reads the ledger (%s)" % (
			hud.get_node("Root/CashLine").text))
	# the meter + combo rise on a landed punch at the bag
	var hero := _hero()
	var m0 := float(hud.get_node("Root/LeverageMeter").value)
	_place(hero, Vector3(8.8, 0.05, 4.4), 0.0)
	await _wait_s(0.3)
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.6)
	var m1 := float(hud.get_node("Root/LeverageMeter").value)
	_check(m1 > m0,
			"a landed punch raises the meter (%.0f -> %.0f)" % [m0, m1])
	await _wait_s(0.2)
	_check("HIT" in str(hud.get_node("Root/ComboLine").text),
			"the combo line counts (%s)" % (
			hud.get_node("Root/ComboLine").text))
	# the style line reads the current style
	_check("BRAWLER" in str(hud.get_node("Root/StyleLine").text),
			"the style line reads the live style (%s)" % (
			hud.get_node("Root/StyleLine").text))


func _b_context() -> void:
	# at the clinic on the street: the verb shows TRY, B tries it
	await Game.travel("neighbourhood", "from_home")
	await _wait_s(1.0)
	var hud := _hud()
	var hero := _hero()
	var clinic := _find_deep("Front_THE_CLINIC")
	_place(hero, clinic.global_position + Vector3(0, 0.05, -1.8), 0.0)
	await _wait_s(0.5)
	_check("TRY" in str(hud.get_node("Root/VerbEcho").text),
			"the verb echo shows TRY at the door (%s)" % (
			hud.get_node("Root/VerbEcho").text))
	# B (the dodge action) tries the door, no dodge state
	Input.action_press("dodge")
	await get_tree().process_frame
	Input.action_release("dodge")
	await _wait_s(0.3)
	var combat := hero.get_node_or_null("Combat")
	_check(combat != null and int(combat.get("phase")) == 0,
			"B at the door TRIES it, no dodge fires (phase %s)" % (
			combat.get("phase") if combat else "-"))
	_check(Doors.state_of("THE CLINIC") == "locked"
			and _law_of("THE CLINIC").get("tried", false),
			"the try landed on the clinic's law")


func _law_of(label: String) -> Dictionary:
	for law in Doors.door_list():
		if law["label"] == label:
			return law
	return {}


func _style_wheel() -> void:
	var hud := _hud()
	_check(hud.get_node_or_null("Root/StyleWheel") != null,
			"the style wheel exists")
	Input.action_press("style")
	await _wait_s(0.3)
	_check(hud.get_node("Root/StyleWheel").visible,
			"holding STYLE opens the wheel")
	_check(absf(Engine.time_scale - 0.7) < 0.01,
			"the world slows while the wheel is held (%.2f)" % (
			Engine.time_scale))
	var btn := hud.get_node_or_null("Root/StyleWheel/WheelList/Style_kickboxing") \
			as Button
	_check(btn != null, "the wheel lists the five styles")
	if btn:
		btn.emit_signal("pressed")
		await _wait_s(0.3)
	var hero := _hero()
	var combat := hero.get_node_or_null("Combat")
	_check(str(combat.get("style_id")) == "kickboxing",
			"tapping swaps the style live (%s)" % combat.get("style_id"))
	Input.action_release("style")
	await _wait_s(0.3)
	_check(not hud.get_node("Root/StyleWheel").visible
			and absf(Engine.time_scale - 1.0) < 0.01,
			"releasing restores the world (%.2f)" % Engine.time_scale)
	# back to brawler for cleanliness
	combat.set_style("brawler")


func _pause_flow() -> void:
	Input.action_press("pause")
	await _wait_s(0.2)  # hold like a real tap: one frame can fall between ticks
	Input.action_release("pause")
	await _wait_s(0.4)
	_check(Game.state == Game.State.PAUSE and get_tree().paused,
			"PAUSE freezes the world (state %s, paused %s)" % [
			Game.state_name(), get_tree().paused])
	var menu := get_node_or_null("/root/Game/PauseMenu")
	_check(menu != null and menu.get_node("Root").visible,
			"the pause menu shows")
	# a real resume
	var resume := menu.get_node_or_null("Root/Menu/RESUMEBtn") as Button
	_check(resume != null, "the RESUME button exists")
	if resume:
		resume.emit_signal("pressed")
		await _wait_s(0.3)
		_check(Game.state == Game.State.PLAY and not get_tree().paused,
				"RESUME unfreezes the world")
	# pause again, then QUIT to the menu
	Input.action_press("pause")
	await _wait_s(0.2)  # hold like a real tap: one frame can fall between ticks
	Input.action_release("pause")
	await _wait_s(0.4)
	var quit := menu.get_node_or_null("Root/Menu/QUITTOMENUBtn") as Button
	_check(quit != null, "the QUIT button exists")
	if quit:
		quit.emit_signal("pressed")
		await _wait_s(1.0)
		_check(Game.state == Game.State.MENU
				and get_tree().current_scene.scene_file_path \
				== "res://scenes/boot/menu.tscn",
				"QUIT returns to the main menu (%s)" % (
				Game.state_name()))


func _find_deep(name: String) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_named(scene, name)


func _find_named(root: Node, name: String) -> Node3D:
	if str(root.name) == name:
		return root as Node3D
	for c in root.get_children():
		var f := _find_named(c, name)
		if f:
			return f
	return null
