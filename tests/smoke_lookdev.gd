extends Node

## B18.3 PART 3C.6: the LookDev gallery loads, carries the full cast
## and prop row, a current camera, a WorldEnvironment and the way back.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("LOOKDEV FAIL: ", what)
	else:
		print("LOOKDEV ok: ", what)


func _ready() -> void:
	var scene: Node = load("res://scenes/lookdev.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	_check(get_tree().get_first_node_in_group("world_env") != null,
			"a WorldEnvironment is present")
	var cam := get_viewport().get_camera_3d()
	_check(cam != null and cam.current, "a camera is current")
	var enemies := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and absf((e as Node3D).global_position.x + 780.0) < 30.0:
			enemies += 1
	_check(enemies == 5, "all five enemy kinds stand in the gallery (%d)" % enemies)
	var pickups := 0
	for p in get_tree().get_nodes_in_group("pickup"):
		if p is Node3D and absf((p as Node3D).global_position.x + 780.0) < 30.0:
			pickups += 1
	_check(pickups == 10, "the full pickup row shows (%d)" % pickups)
	var labels := 0
	for c in scene.find_children("*", "Label3D", true, false):
		labels += 1
	_check(labels >= 9, "the gallery is labelled (%d)" % labels)
	var back: Button = null
	for b in scene.find_children("*", "Button", true, false):
		back = b
	_check(back != null and back.text.begins_with("BACK"),
			"the BACK button returns to the game")
	if _fails == 0:
		print("LOOKDEV PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("LOOKDEV FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
