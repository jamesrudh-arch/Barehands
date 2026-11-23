extends Node

## USER OVERRIDES R1-R4 proof suite. Proves, against the real builds:
## R1  the warehouse IS the start scene and it is SMALL (no street
##     systems inside it);
## R2  the VISIBLE gate exists (slats, the light, the sign) and its
##     walk-out zone fires with main.tscn as the target; the street
##     lands the hero at the warehouse front on the foundry block and
##     the street-side door is wired home;
## R3  the second camera control - the visible pad - exists in BOTH
##     scenes and its drag reaches the camera through InputBus;
## R4  the button law is the DEFAULT: X punch, Y heavy, A kick, B
##     dodge (context outside combat; B is never kick).
## The literal change_scene_to_file call is Godot's own machinery and
## is proven on the device; here the trigger, the target path, the
## arrival state and the return wiring are the truth under test. The
## fade_s setting is stretched so a pending scene change cannot kill
## the suite mid-run.

const CLS_Buttons := preload("res://scripts/touch_buttons.gd")

var _fails := 0
var _checks := 0
var _wh: Node3D = null


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
	Settings.set_value("fade_s", 6.0)   # stretch the fades; suite survives
	var scene_path: String = ProjectSettings.get_setting(
			"application/run/main_scene", "")
	_check(scene_path == "res://scenes/warehouse.tscn",
			"R1: the warehouse is the game's start scene (%s)" % scene_path)

	_wh = load("res://scenes/warehouse.tscn").instantiate()
	add_child(_wh)
	await _wait_s(0.6)

	_warehouse_small()
	_gate_visible()
	_button_law()
	await _cam_pad()
	await _street_legs()
	await _gate_fires()

	if _fails == 0:
		print("WAREHOUSE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("WAREHOUSE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


## R1: a room, not a world - no cast, no shopfronts, no radar, no map.
## The Player subtree (the shared hero rig) and the UI layer (the real
## touch controls) don't count: the claim is about the ROOM.
func _warehouse_small() -> void:
	var count := 0
	for n in _wh.get_children():
		if str(n.name) == "Player" or str(n.name) == "UI":
			continue
		count += 1 + _count_deep(n)
	_check(count < 90, "R1: the start room is small (%d own nodes)" % count)
	_check(get_tree().get_nodes_in_group("cast_npc").is_empty()
			and get_tree().get_nodes_in_group("shopfront").is_empty()
			and get_tree().get_nodes_in_group("full_map").is_empty()
			and get_tree().get_nodes_in_group("radar").is_empty(),
			"R1: no street systems live inside the warehouse")
	_check(get_tree().get_first_node_in_group("enemy") == null,
			"R1: no enemies in the start room")


func _count_deep(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		c += 1 + _count_deep(ch)
	return c


## R2: the gate you can SEE - the node, the slats, the sign, the light.
func _gate_visible() -> void:
	var gate := _wh.get_node_or_null("Gate") as Node3D
	_check(gate != null and gate.is_in_group("warehouse_gate"),
			"R2: the gate node exists and is marked")
	if gate == null:
		return
	var slats := 0
	var lit := false
	var signed := false
	for ch in gate.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is BoxMesh:
			slats += 1
		if ch is OmniLight3D:
			lit = true
		if ch is Label3D and str((ch as Label3D).text) == "THE STREET":
			signed = true
	_check(slats >= 5, "R2: the roller shutter is built from slats (%d)" % slats)
	_check(lit, "R2: light spills under the gate")
	_check(signed, "R2: the gate says where it goes (THE STREET)")
	var zone := _wh.get_node_or_null("Gate")  # exit zone sits on the root
	var exit_zone: Area3D = null
	for ch in _wh.get_children():
		if ch is Area3D:
			exit_zone = ch
	_check(exit_zone != null, "R2: the walk-out zone exists")
	_check(str(_wh.get_meta("street_path", "")) == "res://scenes/main.tscn",
			"R2: the gate's target is the street scene")


## R4: the button law is the default scheme, and it says what it must.
func _button_law() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	_check(hud != null and hud is CanvasLayer,
			"R4: the real touch controls are mounted")
	var scheme: String = hud.call("_scheme")
	_check(scheme == "fight",
			"R4: the X/Y/A/B diamond is the DEFAULT scheme (%s)" % scheme)
	var by_label := {}
	for spec in CLS_Buttons.FIGHT_SPECS:
		by_label[spec[1]] = spec[2]
	_check(by_label.get("X") == "PUNCH", "R4: X is PUNCH")
	_check(by_label.get("Y") == "HEAVY", "R4: Y is HEAVY")
	_check(by_label.get("A") == "KICK", "R4: A is KICK")
	_check(by_label.get("B") == "DODGE", "R4: B is DODGE (never kick)")


## R3: the pad exists in the start scene AND on the street, and its
## drag moves the camera through the shared InputBus pipe.
func _cam_pad() -> void:
	var pad := get_tree().get_first_node_in_group("hud").get_node_or_null(
			"CamPad") as Control
	_check(pad != null, "R3: the camera pad exists beside the move stick")
	if pad == null:
		return
	var yaw_before: float = InputBus.camera_yaw
	pad.call("apply_delta", 160.0)
	await _wait_s(0.2)
	_check(absf(InputBus.camera_yaw - yaw_before) > 0.3,
			"R3: a pad drag swings the camera (%.2f -> %.2f)"
			% [yaw_before, InputBus.camera_yaw])


## The street legs: arrival from the warehouse lands on the docks at
## the hero's own front door; the return zone is wired; the pad rides
## the street UI too.
func _street_legs() -> void:
	# free the warehouse instance first: one player, one hud
	_wh.queue_free()
	await _wait_s(0.3)
	Settings.set_value("arrived_from", "warehouse")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as Node
	if opening:
		opening.skip()
	await _wait_s(3.0)

	var hero := get_tree().get_first_node_in_group("player") as Node3D
	_check(hero != null, "street: the hero exists")
	if hero:
		_check(absf(hero.global_position.x - 482.0) < 3.0
				and absf(hero.global_position.z + 4.6) < 3.0,
				"R2: arrival lands at the warehouse front (%.1f, %.1f)"
				% [hero.global_position.x, hero.global_position.z])
	_check(City.district_now() == "foundry",
			"R2: arrival sets the foundry district (%s)" % City.district_now())
	var foundry := false
	for n in get_tree().get_nodes_in_group("warehouse_door"):
		foundry = true
	_check(foundry, "R2: the foundry block (and the shut front) is built")
	var ret := get_tree().get_first_node_in_group("warehouse_return") as Area3D
	_check(ret != null, "R2: the street-side door is wired as the way home")
	if ret:
		_check(str(ret.get_meta("target", "")) == "res://scenes/warehouse.tscn",
				"R2: the return target is the warehouse scene")
	_check(Settings.value("arrived_from") == null
			or str(Settings.value("arrived_from")) == "",
			"R2: the arrival flag is consumed")
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	_check(hud != null and hud.get_node_or_null("CamPad") != null,
			"R3: the camera pad rides the street UI too")

	# the return zone fires
	if hero and ret:
		hero.global_position = ret.global_position + Vector3(0, 0, 0.2)
		await _wait_s(0.5)
		_check(bool(ret.get_meta("went_home", false)),
				"R2: walking into the front door triggers the way home")
	main.queue_free()
	await _wait_s(0.3)


## The gate zone fires with the street as its target (the last leg -
## its scene change is stretched away by fade_s).
func _gate_fires() -> void:
	Settings.set_value("arrived_from", "")
	_wh = load("res://scenes/warehouse.tscn").instantiate()
	add_child(_wh)
	await _wait_s(0.6)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var exit_zone: Area3D = null
	for ch in _wh.get_children():
		if ch is Area3D:
			exit_zone = ch
	print("  [debug] gate leg: hero=%s zone=%s players=%d"
			% [str(hero.get_path()) if hero else "null", str(exit_zone),
					get_tree().get_nodes_in_group("player").size()])
	print("  [debug] wh root at %s, street main=%s"
			% [str(_wh.global_position),
					str(get_node_or_null("/root/Main"))])
	if hero and exit_zone:
		var target := _wh.to_global(Vector3(0.0, 0.5, 6.8))
		hero.global_position = target
		print("  [trace] assigned %s -> hero now %s vel=%s"
				% [str(target), str(hero.global_position), str(hero.velocity)])
		for j in 6:
			await _wait_s(0.1)
			print("  [trace] t=%.1f pos=%s vel=%s parent=%s"
					% [0.1 * (j + 1), str(hero.global_position.round()),
							str(hero.velocity.round()),
							str(hero.get_parent().name)])
		_check(bool(_wh.get_meta("went_to_street", false)),
				"R2: walking out the gate triggers the street")
	_wh.queue_free()
