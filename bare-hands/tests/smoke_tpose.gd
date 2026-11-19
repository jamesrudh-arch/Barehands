extends Node
## P0.1 diagnostic probe: WHY does a distant NPC stand in a T-pose?
## Logs, for EVERY AnimationPlayer under main.tscn (cast bases, cast OUTFIT
## pieces, trainer, dummy, thugs, distant muscle spawns):
##   - the clip it requested (current_animation / the owner's state)
##   - whether that clip exists in the player's runtime library
##   - is_playing, paused, speed_scale, autoplay
##   - distance to the player, is_visible_in_tree, in-frustum
## plus the full runtime clip list. Exits non-zero if any character skeleton
## is not animating, so it doubles as the regression test skeleton.

var _main: Node3D
var _player: CharacterBody3D
var _fails := 0

func _p(msg: String) -> void:
	print("TPOSE ", msg)

func _fail(msg: String) -> void:
	_fails += 1
	_p("FAIL " + msg)

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# the runtime library's actual clip list, once
	var lib := UalBind.library()
	var names: Array = []
	for n in lib.get_animation_list():
		names.append(n)
	names.sort()
	_p("library clips (%d): %s" % [names.size(), ", ".join(names)])

	# distant muscle exactly the way city.gd spawns them (radius 14 m)
	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	for spec in [{"kind": 1, "pos": Vector3(13.0, 0.02, -13.0)},
			{"kind": 2, "pos": Vector3(-14.0, 0.02, 12.0)}]:
		var e := enemy_scene.instantiate() as CharacterBody3D
		e.set("kind", spec["kind"])
		_main.add_child(e)
		e.global_position = spec["pos"]

	# let every state machine settle into its idle
	for i in 90:
		await get_tree().physics_frame

	var cam := get_viewport().get_camera_3d()
	var checked := 0
	for ap in _anim_players(_main):
		checked += 1
		var path := String(ap.get_path()).replace("/root/Node/", "")
		var owner_root := _char_root(ap)
		var dist := 0.0
		if _player and owner_root:
			dist = _player.global_position.distance_to(owner_root.global_position)
		var cur: String = ap.current_animation
		var has := lib.has_animation(cur) if cur != "" else true
		var in_frustum := "?"
		var vis := "?"
		if cam and owner_root:
			in_frustum = str(cam.is_position_in_frustum(owner_root.global_position))
		if owner_root:
			vis = str(owner_root.is_visible_in_tree())
		_p("%-52s clip=%-16s has=%s playing=%s speed=%.2f dist=%4.1fm vis=%s frustum=%s" % [
			path, cur if cur != "" else "(none)", has, ap.is_playing(),
			ap.speed_scale, dist, vis, in_frustum])
		# a character AnimationPlayer that is not playing anything IS a T-pose
		if not ap.is_playing():
			_fail("%s not playing (clip='%s' has=%s dist=%.1f)" % [path, cur, has, dist])

	_p("checked %d AnimationPlayers, %d not animating" % [checked, _fails])
	if _fails == 0:
		_p("PASS")
		get_tree().quit(0)
	else:
		_p("FAIL (%d)" % _fails)
		get_tree().quit(1)

func _anim_players(root: Node) -> Array:
	var out: Array = []
	for c in _walk(root):
		if c is AnimationPlayer:
			out.append(c)
	return out

func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out

func _char_root(n: Node) -> Node3D:
	var cur: Node = n
	while cur:
		if cur is CharacterBody3D:
			return cur
		cur = cur.get_parent()
	return null
