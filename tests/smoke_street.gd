extends Node

## REBUILD STEP 6 proof suite: THE NEIGHBOURHOOD + THE DOOR LAW.
##   - the street loads with >=12 registered fronts, the named signs;
##   - the three OPEN fronts have real interiors you can WALK INTO;
##   - the law: approach prompt, TRY with the reason, BREAK (B
##     shoulders + A kicks), the stash drops and collects into the
##     world ledger, steel refuses with its reason;
##   - WorldState: a broken door STAYS broken across a home->street
##     round trip;
##   - the gates: the west gate walks you home, the yard gate walks
##     you back to the street;
##   - a rendered frame is alive.

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
	await Game.travel("neighbourhood", "from_home")
	await _wait_s(0.8)
	await _fronts()
	await _open_interiors()
	await _door_law()
	await _stash_collect()
	await _roundtrip_persistence()
	await _render()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("STREET PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("STREET FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


## Teleport the hero SAFELY: position, zero the velocity (a hero that
## was falling carries ~-100 m/s and tunnels straight through the
## sidewalk box on the next frame - the whole door block fell to it),
## and set the facing.
func _place(hero: CharacterBody3D, pos: Vector3, yaw: float) -> void:
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.set("_yaw", yaw)


func _fronts() -> void:
	var scene := get_tree().current_scene
	_check(scene != null
			and scene.scene_file_path == "res://scenes/areas/neighbourhood.tscn",
			"the street scene is current")
	var list := Doors.door_list()
	_check(list.size() >= 12,
			"the street carries %d registered fronts" % list.size())
	for name in ["MAMA SUN'S NOODLES", "THE RAIN GLASS", "CORNER STORE",
			"THE BARBER", "THE PAWN DESK", "THE LAUNDROMAT", "THE CLINIC",
			"THE NEWSSTAND"]:
		var state := Doors.state_of(name)
		_check(state != "", "%s answers the law (%s)" % [name, state])
	_check(Doors.state_of("MAMA SUN'S NOODLES") == "open"
			and Doors.state_of("CORNER STORE") == "open",
			"the noodle shop and the store are OPEN")
	_check(Doors.state_of("THE CLINIC") == "locked",
			"the clinic is LOCKED")
	# the signs exist and read (R16: once, outlined, coloured)
	var signs := 0
	for n in _find_all(scene, Label3D):
		if str(n.name).begins_with("Sign_"):
			signs += 1
	_check(signs >= 14, "the street's signs are up (%d)" % signs)
	var hero := _hero()
	_check(hero != null, "the hero lands on the street")
	if hero:
		_check(hero.global_position.x < -50.0,
				"the hero lands at the home-side end (x %.1f)" % (
				hero.global_position.x))


func _find_all(root: Node, what) -> Array:
	var out := []
	if root == null:
		return out
	for c in root.get_children():
		if is_instance_of(c, what):
			out.append(c)
		out.append_array(_find_all(c, what))
	return out


func _open_interiors() -> void:
	# walk into the noodle shop through its real doorway
	var hero := _hero()
	var front := _find_deep("Front_MAMA_SUNS_NOODLES")
	_check(front != null, "the noodle front exists")
	if hero == null or front == null:
		return
	_place(hero, front.global_position + Vector3(0, 0.05, -2.2), PI)
	hero.set("move_stick", Vector2(0, -0.9))  # north, through the doorway
	await _wait_s(1.4)
	hero.set("move_stick", Vector2.ZERO)
	var local := front.to_local(hero.global_position)
	_check(local.z < -1.0 and absf(local.x) < 4.0,
			"the hero walked INTO the noodle shop (local %s)" % local)
	# and back out (from the threshold: the room's tables block a
	# straight lane - the two-way DOORWAY is what this proves)
	_place(hero, front.global_position + Vector3(0, 0.05, -0.5), 0.0)
	hero.set("move_stick", Vector2(0, 0.9))
	await _wait_s(1.0)
	hero.set("move_stick", Vector2.ZERO)
	local = front.to_local(hero.global_position)
	_check(local.z > 0.0,
			"the hero walked back out to the street (local z %.1f)" % local.z)
	# the room is dressed (furniture from the kit)
	var room := front.get_node_or_null("Room")
	var kits := 0
	if room:
		for c in room.get_children():
			if str(c.name).begins_with("Kit_"):
				kits += 1
	_check(room != null and kits >= 3,
			"the interior is dressed (%d kit pieces)" % kits)


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


func _door_law() -> void:
	var hero := _hero()
	# 1. the clinic: TRY, read the reason, steel refuses
	var clinic := _find_deep("Front_THE_CLINIC")
	_place(hero, clinic.global_position + Vector3(0, 0.05, -1.8), 0.0)
	await _wait_s(0.5)
	_check(Doors.context_verb(hero.global_position) == "TRY",
			"the B verb near a locked door is TRY")
	_check(Doors.try_nearest(hero), "the try answers")
	var prompt: Label3D = _law_of("THE CLINIC").get("prompt")
	_check("DEBT=DEATH" in prompt.text and "LOCKED" in prompt.text,
			"the clinic says why (%s)" % prompt.text)
	Doors.try_nearest(hero)
	Doors.try_nearest(hero)
	_check(Doors.state_of("THE CLINIC") == "locked",
			"the clinic door never breaks")
	_check(Doors.context_verb(hero.global_position) == "TRY",
			"steel never offers BREAK")
	# 2. the laundromat: B shoulders (3 hits -> broken + stash)
	var law := _law_of("THE LAUNDROMAT")
	var front := _find_deep("Front_THE_LAUNDROMAT")
	_place(hero, front.global_position + Vector3(0, 0.05, -1.8), 0.0)
	await _wait_s(0.5)
	Doors.try_nearest(hero)
	_check(Doors.context_verb(hero.global_position) == "BREAK",
			"the verb turns BREAK after the try")
	for i in 3:
		Doors.try_nearest(hero)
		await _wait_s(0.1)
	_check(Doors.state_of("THE LAUNDROMAT") == "broken",
			"three shoulders burst the laundromat door")
	var leaf: MeshInstance3D = law.get("leaf")
	_check(leaf != null and absf(leaf.rotation.y) > 0.5,
			"the leaf swung off its hinge (%.2f)" % (
			leaf.rotation.y if leaf else -9.0))
	var stashes := get_tree().get_nodes_in_group("stash")
	_check(stashes.size() >= 1,
			"the stash dropped behind the broken door")
	# 3. the dailies: the KICK path (try, then A kicks)
	_place(hero, _find_deep("Front_THE_DAILIES").global_position \
			+ Vector3(0, 0.05, 1.8), PI)  # south fronts face north
	await _wait_s(0.5)
	Doors.kick_door(hero)
	_check(_law_of("THE DAILIES").get("tried", false),
			"the first kick tries the handle")
	for i in 3:
		Doors.kick_door(hero)
		await _wait_s(0.12)
	_check(Doors.state_of("THE DAILIES") == "broken",
			"three kicks burst the dailies door")
	_check(WorldState.flag("door_broken:THE DAILIES"),
			"the world remembers the broken door")


func _law_of(label: String) -> Dictionary:
	for law in Doors.door_list():
		if law["label"] == label:
			return law
	return {}


func _stash_collect() -> void:
	var hero := _hero()
	var stashes := get_tree().get_nodes_in_group("stash")
	if stashes.is_empty():
		_check(false, "a stash exists to collect")
		return
	var cash0: float = float(WorldState.get_value("stash_cash", 0.0))
	var s := stashes[0] as Node3D
	_place(hero, s.global_position + Vector3(0.6, 0.05, 0), 0.0)
	await _wait_s(0.6)
	_check(float(WorldState.get_value("stash_cash", 0.0)) > cash0,
			"touching the stash collects it into the ledger (%.0f -> %.0f)"
			% [cash0, float(WorldState.get_value("stash_cash", 0.0))])


func _roundtrip_persistence() -> void:
	# walk into the west gate: home; the yard gate: back to the street
	# - the broken laundromat must STILL be broken after the loop
	var hero := _hero()
	_place(hero, Vector3(-58.0, 0.05, 4.4), PI)
	hero.set("move_stick", Vector2(-1.0, 0.0))
	await _wait_s(1.6)
	hero.set("move_stick", Vector2.ZERO)
	await _wait_s(1.2)
	_check(Game.area_id == "warehouse",
			"the west gate walks the hero home (area %s)" % Game.area_id)
	if Game.area_id != "warehouse":
		return
	# through the yard: side door east, then the street gate east
	hero = _hero()
	_place(hero, Vector3(6.0, 0.05, 0.0), 0.0)
	hero.set("move_stick", Vector2(1.0, 0.0))
	await _wait_s(3.2)
	hero.set("move_stick", Vector2.ZERO)
	await _wait_s(1.2)
	_check(Game.area_id == "neighbourhood",
			"the yard gate walks back to the street (area %s)" % Game.area_id)
	if Game.area_id != "neighbourhood":
		return
	_check(Doors.state_of("THE LAUNDROMAT") == "broken",
			"the broken laundromat STAYS broken after the round trip")
	_check(Doors.state_of("THE CLINIC") == "locked",
			"the unbroken clinic stays locked")


func _render() -> void:
	await _wait_s(0.3)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_check(false, "the street renders (no image in this mode)")
		return
	img.save_png("/tmp/render/smoke_street.png")
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
			"the night street renders alive (mid-tone %.1f%%)" % (
			100.0 * mid / maxf(total, 1.0)))
