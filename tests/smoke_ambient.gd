extends Node
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")

## B18.3 PART 6F suite: AMBIENT LIFE. Boots the real street, checks
## the moth swarm exists and stays under the device cap, moths orbit
## real light positions, the creatures exist (rat, pigeon, cat), and
## they react to the hero (the pigeon flees, the cat darts off).

var _fails := 0
var _checks := 0
var _main: Node
var _hero: Node3D
var _al: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("AMBIENT FAIL: ", what)
	else:
		print("AMBIENT ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().create_timer(minf(left, 0.25)).timeout
		left -= minf(left, 0.25)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.6)
	_hero = get_tree().get_first_node_in_group("player") as Node3D
	_al = get_tree().get_first_node_in_group("ambient_life")

	_swarm()
	await _creatures_react()

	if _fails == 0:
		print("AMBIENT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("AMBIENT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _swarm() -> void:
	_check(_al != null, "the ambient life node exists")
	if _al == null:
		return
	var insects := int(_al.call("insect_count"))
	_check(insects >= 6, "moths are circling (%d)" % insects)
	_check(insects <= int(_al.call("insect_cap")),
			"the swarm stays under the cap (%d <= %d)" % [insects, int(_al.call("insect_cap"))])
	var mm: MultiMesh = _al.get("_moth_mm")
	_check(mm != null and mm.instance_count == insects,
			"the MultiMesh carries every moth (%d)" % (mm.instance_count if mm else -1))
	# the orbit data keeps the moths at light height (a multimesh
	# transform readback is a dummy-renderer identity in headless, so
	# the check reads the orbit params the renderer will draw)
	var ok_pos := true
	var swarms: Array = _al.get("_swarms")
	for d in (_al.get("_moth_data") as Array):
		var c: Vector3 = swarms[d["swarm"]]["centre"]
		var y := c.y + float(d["h"])
		if y < 1.6 or y > 4.8:
			ok_pos = false
			break
	_check(ok_pos, "the moths circle at light height")
	var near = _al.call("nearest_lit_swarm")
	_check(near != Vector3.INF, "a lit swarm is findable")


func _creatures_react() -> void:
	if _al == null or _hero == null:
		_check(false, "ambient/hero present for the creature test")
		return
	var kinds := {}
	var pigeon: MeshInstance3D = null
	var cat: MeshInstance3D = null
	for c in _al.get("_creatures"):
		kinds[c["kind"]] = int(kinds.get(c["kind"], 0)) + 1
		if c["kind"] == "pigeon" and pigeon == null:
			pigeon = c["node"]
		if c["kind"] == "cat":
			cat = c["node"]
	_check(int(kinds.get("rat", 0)) >= 1, "a rat scurries near the bins")
	_check(int(kinds.get("pigeon", 0)) >= 1, "pigeons sit on the ledges")
	_check(int(kinds.get("cat", 0)) >= 1, "the stray cat watches the street")
	_check(int(_al.call("creature_count")) <= int(_al.call("creature_cap")),
			"creatures stay under the cap")
	# the pigeon flees when the hero comes close
	if pigeon:
		var p0 := pigeon.global_position
		_hero.global_position = p0 + Vector3(1.2, 0.0, 0.0)
		await _wait_s(1.4)
		_check(pigeon.global_position.distance_to(p0) > 0.5,
				"the pigeon flutters away from the hero")
	# the cat darts off its hood
	if cat:
		var c0 := cat.global_position
		_hero.global_position = c0 + Vector3(0.8, 0.0, 0.0)
		await _wait_s(1.4)
		_check(cat.global_position.distance_to(c0) > 0.5,
				"the cat darts off when the hero gets close")
