extends Node

## REBUILD STEP 4 proof suite: THE WAREHOUSE HOME (area 1).
##   - every furnishing from 02_MASTER_DESIGN §3 exists and is named:
##     the loft bed, the workbench, the phone table (+phone), the
##     fridge, the lamp, the weapon rack (pipe/bat/bottles), the
##     TRAINING CORNER (bag, dummy, mirror);
##   - the roller door is LOCKED with its honest sign; the side door
##     is an OPEN doorway;
##   - the yard: enterable on foot (the hero walks out through the
##     doorway and stands on yard ground), fence + gate with its
##     sign, bins/crates;
##   - the light rig: 3+ lights incl. the flickering yard lamp;
##   - furniture carries collision (a wall of boxes stops the hero);
##   - renders alive: the warm hall + the yard.

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
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(0.6)
	await _furnishings()
	await _doors()
	await _yard_walk()
	await _collision_block()
	_lights()
	await _render()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("HOME PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("HOME FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _home() -> Node:
	return get_tree().current_scene


func _has(name: String) -> bool:
	return _home() != null and _home().has_node(name)


func _find_deep(name: String) -> Node:
	if _home() == null:
		return null
	return _find_in(_home(), name)


func _find_in(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var f := _find_in(c, name)
		if f:
			return f
	return null


func _furnishings() -> void:
	for name in ["Loft", "PhoneTable", "Fridge", "WeaponRack",
			"TrainingCorner", "RollerDoor", "SideDoor", "Yard"]:
		_check(_has(name), "the home has its %s" % name)
	# the bed + bedside table on the loft (Kenney kits)
	var loft := _find_deep("Loft")
	var kits := 0
	if loft:
		for c in loft.get_children():
			if str(c.name).begins_with("Kit_"):
				kits += 1
	_check(loft != null and kits >= 2,
			"the loft bed is furnished from the kit (%d pieces)" % kits)
	# the phone on its table
	_check(_find_deep("Phone") != null, "the phone sits on its table")
	# the weapon rack carries its arms
	var rack := _find_deep("WeaponRack")
	var arms := 0
	if rack:
		for c in rack.get_children():
			if c.name == "Pipe" or c.name == "Bat" \
					or str(c.name).begins_with("Bottle"):
				arms += 1
	_check(rack != null and arms >= 4,
			"the rack holds pipe, bat and bottles (%d arms)" % arms)
	# the training corner: bag, dummy, mirror
	for name in ["PunchingBag", "SparringDummy", "Mirror"]:
		_check(_find_deep(name) != null,
				"the training corner has its %s" % name.to_lower())
	# the desk (the workbench) placed from the kit
	var desk := false
	for c in _home().get_children():
		if str(c.name).begins_with("Kit_desk"):
			desk = true
	_check(desk, "the workbench is the Kenney desk")


func _doors() -> void:
	var roller := _find_deep("RollerDoor")
	var lock := roller.get_node_or_null("Lock") if roller else null
	_check(roller != null and lock != null,
			"the big roller door is LOCKED (the lock is on it)")
	var roller_sign := _sign_text(roller)
	_check("LOCKED" in roller_sign,
			"the roller door says why it is locked (%s)" % roller_sign)
	var side := _find_deep("SideDoor")
	_check(side != null and side.get_node_or_null("Glow") != null,
			"the side door glows open toward the yard")
	var gate := _find_deep("YardGate")
	var gate_sign := _sign_text(gate)
	_check(gate != null and "NEIGHBOURHOOD" in gate_sign,
			"the yard gate is signposted for the street build (%s)" % gate_sign)


func _sign_text(node: Node) -> String:
	if node == null:
		return ""
	for c in node.get_children():
		if c is Label3D:
			return c.text
	return ""


func _yard_walk() -> void:
	# drive the hero east through the side doorway into the yard
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		_check(false, "the hero exists for the yard walk")
		return
	hero.global_position = Vector3(7.5, 0.05, 0.0)  # just inside the hall
	hero.set("move_stick", Vector2(1.0, 0.0))       # run east
	await _wait_s(1.6)
	hero.set("move_stick", Vector2.ZERO)
	var x: float = hero.global_position.x
	_check(x > 10.4,
			"the hero walks out the side door into the yard (x %.2f)" % x)
	# the hero stands on solid ground: a down-ray hits within a step
	var space := hero.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
			hero.global_position + Vector3(0, 0.4, 0),
			hero.global_position + Vector3(0, -1.2, 0))
	var hit := space.intersect_ray(q)
	_check(not hit.is_empty(),
			"the yard floor carries the hero (ray hit %s)" % [
			hit.get("collider").name if hit.has("collider") else "-"])
	# and can run back inside
	hero.set("move_stick", Vector2(-1.0, 0.0))
	await _wait_s(1.6)
	hero.set("move_stick", Vector2.ZERO)
	_check(hero.global_position.x < 10.0,
			"the hero runs back inside (x %.2f)" % hero.global_position.x)


func _collision_block() -> void:
	# the fridge blocks: place the hero west of it and push east
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		_check(false, "the hero exists for the collision check")
		return
	hero.global_position = Vector3(7.6, 0.05, 6.3)
	hero.set("move_stick", Vector2(1.0, 0.0))
	await _wait_s(0.9)
	hero.set("move_stick", Vector2.ZERO)
	_check(hero.global_position.x < 9.6,
			"the fridge's collider stops the hero (x %.2f)" % (
			hero.global_position.x))


func _lights() -> void:
	var names := []
	if _home():
		for c in _home().get_children():
			if c is Light3D:
				names.append(c.name)
	_check(names.size() >= 4,
			"the light rig: main + bed + door spill + yard flicker (%d)" % (
			names.size()))
	_check(_has("YardLamp"), "the yard lamp exists (the flicker)")


func _render() -> void:
	await _wait_s(0.3)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_check(false, "the home renders (no image in this mode)")
		return
	img.save_png("/tmp/render/smoke_home.png")
	var l8 := img.duplicate()
	l8.convert(Image.FORMAT_L8)
	l8.resize(64, 36)
	var bins := {}
	var total := 0
	for y in l8.get_height():
		for x in l8.get_width():
			var v: int = l8.get_pixel(x, y).r8
			bins[v] = int(bins.get(v, 0)) + 1
			total += 1
	var mid := 0
	for i in range(10, 246):
		mid += int(bins.get(i, 0))
	_check(total > 0 and float(mid) / float(total) > 0.05,
			"the lit home renders alive (mid-tone %.1f%%)" % (
			100.0 * mid / maxf(total, 1.0)))
