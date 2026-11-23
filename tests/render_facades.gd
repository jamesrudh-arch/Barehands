extends Node
## B29 THE DRESSED STREET: the rendered-facts probe for the facade
## jewelry. render_check guards the whole boot; this aims the camera
## at a riverside building face and proves the stonework is THERE:
## the facade_detail group carries the plinth + ledges + crowns, the
## frame renders, and the base course reads as a darker band against
## the wall above it (a measured pixel fact, not an eyeball claim).
## Needs a real renderer: Xvfb + --rendering-driver opengl3.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FACADE FAIL: ", what)
	else:
		print("FACADE ok: ", what)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FACADE SKIP: no display (run under Xvfb + opengl3)")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	Settings.set_value("dynamic_events", false)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait_s(1.0)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await _wait_s(3.0)

	# 1. the jewelry exists: plinths + ledges + crowns on all six
	#    riverside volumes (6 x (1 plinth + ledges + 1 crown) > 18)
	var detail := get_tree().get_nodes_in_group("facade_detail")
	_check(detail.size() >= 18,
			"the riverside volumes wear their stonework (%d bands)" % detail.size())
	var ledges := 0
	var plinths := 0
	for d in detail:
		var mi := d as MeshInstance3D
		if mi and mi.mesh is BoxMesh:
			var sz := (mi.mesh as BoxMesh).size
			if sz.y < 0.2 and sz.z < 0.4:
				ledges += 1
			elif sz.y > 0.8:
				plinths += 1
	_check(plinths >= 6, "every building has its base course (%d)" % plinths)
	_check(ledges >= 8, "the floor-line ledges run under the lit rows (%d)" % ledges)

	# 2. the awnings: the far blocks' shopfronts wear canvas (walked to,
	#    not teleported - the same road the player walks)
	await Blocks.travel("market", "east")
	var awnings := 0
	for d in get_tree().get_nodes_in_group("facade_detail"):
		var mi := d as MeshInstance3D
		if mi and mi.mesh is BoxMesh:
			var sz := (mi.mesh as BoxMesh).size
			if absf(sz.x) > 1.5 and absf(sz.z - 1.15) < 0.02:
				awnings += 1
	_check(awnings >= 2, "the market shopfronts wear awnings (%d)" % awnings)
	_check(get_tree().get_nodes_in_group("facade_detail").size()
			>= detail.size() + awnings + 4,
			"the market's code buildings carry stonework too (%d total)"
			% get_tree().get_nodes_in_group("facade_detail").size())
	await Blocks.travel("riverside", "west")

	# 3. the PIXEL fact: the base course reads darker than the wall above
	#    (BuildingB south face, from across the street)
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	var face := Vector3(1.5, 0.0, -9.0)  # BuildingB street face line
	cam.global_position = Vector3(1.5, 1.6, -3.4)
	cam.look_at(face + Vector3(0.0, 1.6, 0.0), Vector3.UP)
	cam.set_process(false)
	cam.set_physics_process(false)
	await _wait_s(0.7)
	var img := await _frame()
	img.save_png("/tmp/render_facades.png")
	# the plinth band sits at world y 0..1.1 -> the lower third of the
	# frame centre; sample two horizontal strips and compare means
	var lo := _band_mean(img, 0.62)   # plinth height
	var hi := _band_mean(img, 0.35)   # wall above
	print("FACADE stats: plinth %.3f vs wall %.3f" % [lo, hi])
	_check(lo < hi * 0.92,
			"the base course reads as a darker band (%.3f < %.3f)" % [lo, hi])

	_finish()


## Mean luminance of a horizontal strip of the frame (y 0..1).
func _band_mean(img: Image, y_frac: float) -> float:
	img.convert(Image.FORMAT_L8)
	var y := int(float(img.get_height()) * y_frac)
	var sum := 0.0
	var n := 0
	for x in range(int(float(img.get_width()) * 0.3),
			int(float(img.get_width()) * 0.7), 3):
		sum += float(img.get_pixel(x, y).r)
		n += 1
	return sum / maxf(n, 1.0)


func _frame() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _finish() -> void:
	await _wait_s(0.4)
	print("FACADE PASS (%d checks)" % _checks if _fails == 0
			else "FACADE FAIL (%d of %d checks)" % [_fails, _checks])
	get_tree().quit(1 if _fails > 0 else 0)
