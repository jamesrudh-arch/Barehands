extends Node
## B26 WHEELS EVERYWHERE: the rendered-facts probe for the new street
## metal. render_check guards the whole boot frame; this aims the
## camera at the bicycle and the second sedan and asserts their
## actual PIXELS - paint colours, lamp glows, silhouette shares - so
## "the bike renders" is a measured fact, not an eyeball claim. Also
## proves the traffic VAN body builds as a box van (not sedan steel).
## Needs a real renderer: run under Xvfb + --rendering-driver opengl3.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("WHEELS FAIL: ", what)
	else:
		print("WHEELS ok: ", what)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("WHEELS SKIP: no display (run under Xvfb + opengl3)")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait_s(1.0)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await _wait_s(3.0)

	var bike: Node3D = null
	var car_b: Node3D = null
	for v in get_tree().get_nodes_in_group("vehicle"):
		if (v as Node).name == "Bicycle":
			bike = v as Node3D
		elif (v as Node).name == "ParkedCarB":
			car_b = v as Node3D
	_check(bike != null, "the bicycle is in the world")
	_check(car_b != null, "ParkedCarB is in the world")

	# 1. the bicycle's pixels: camera 6 m from the saddle, looking at it
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	if bike and cam:
		# freeze the follow camera's target to a fixed spot: aim from
		# the road south of the bike, looking north at it
		cam.global_position = bike.global_position + Vector3(-4.2, 1.6, 3.4)
		cam.look_at(bike.global_position + Vector3.UP * 0.8, Vector3.UP)
		_cam_holds(cam, "follow")
		await _wait_s(0.6)
		var img := await _frame()
		img.save_png("/tmp/render_bike.png")
		var facts := _color_facts(img, Rect2i(0, 0, img.get_width(), img.get_height()))
		print("WHEELS stats bike: warm %.4f silver %.4f gray %.4f rubber %.4f"
				% [facts["warm"], facts["silver"], facts["gray"], facts["rubber"]])
		_check(facts["warm"] > 0.0002,
				"the bike's headlamp glow is on the street (%.5f)" % facts["warm"])
		_check(facts["silver"] > 0.0003,
				"the wheel rims read silver (%.5f)" % facts["silver"])
		_check(facts["gray"] > 0.002,
				"the frame tubes read in the frame (%.4f)" % facts["gray"])
		_check(facts["rubber"] > 0.0015,
				"the tires read dark rubber (%.4f)" % facts["rubber"])

	# 2. ParkedCarB's burgundy paint
	if car_b and cam:
		cam.global_position = car_b.global_position + Vector3(-4.8, 2.0, 4.2)
		cam.look_at(car_b.global_position + Vector3.UP * 0.8, Vector3.UP)
		await _wait_s(0.6)
		var img2 := await _frame()
		img2.save_png("/tmp/render_car_b.png")
		var f2 := _color_facts(img2, Rect2i(0, 0, img2.get_width(), img2.get_height()))
		print("WHEELS stats carB: burgundy %.4f warm %.4f cyan %.4f"
				% [f2["burgundy"], f2["warm"], f2["cyan"]])
		_check(f2["burgundy"] > 0.002,
				"ParkedCarB wears burgundy, not sedan green (%.4f)" % f2["burgundy"])
		_check(f2["cyan"] > 0.0002,
				"the cyan edge strips glow on car B (%.5f)" % f2["cyan"])

	# 3. the traffic VAN: geometry facts (the box roof, the tall body)
	var van_probe := Node3D.new()
	add_child(van_probe)
	var body := Traffic.call("_code_car", van_probe, "kenney_traffic/van.glb") as Node3D
	_check(body != null, "the traffic van builds")
	if body:
		var tallest := 0.0
		var longest_roof := 0.0
		for c in body.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not (mi.mesh is BoxMesh):
				continue
			var sz := (mi.mesh as BoxMesh).size
			if sz.y > tallest:
				tallest = sz.y
			if mi.position.y > 1.0 and sz.z > longest_roof:
				longest_roof = sz.z
		_check(tallest > 1.0,
				"the van body is a tall box (tallest %.2f m)" % tallest)
		_check(longest_roof > 3.0,
				"the van's roof runs the load length (%.2f m)" % longest_roof)
	van_probe.queue_free()

	print("WHEELS PASS (%d checks)" % _checks if _fails == 0
			else "WHEELS FAIL (%d of %d checks)" % [_fails, _checks])
	get_tree().quit(1 if _fails > 0 else 0)


func _cam_holds(cam: Node3D, reason: String) -> void:
	# the follow camera re-aims every frame at its target; park it by
	# disabling its processing for the probe frames (restored never -
	# the suite quits right after)
	if reason == "follow":
		cam.set_process(false)
		cam.set_physics_process(false)


func _frame() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


## Sampled colour shares of a frame region: warm lamps, silver rims,
## gray steel, rubber, burgundy paint, cyan strips, red tails.
func _color_facts(img: Image, r: Rect2i) -> Dictionary:
	img.convert(Image.FORMAT_RGB8)
	var counts := {"warm": 0.0, "silver": 0.0, "gray": 0.0, "rubber": 0.0,
			"burgundy": 0.0, "cyan": 0.0, "red": 0.0}
	var n := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			n += 1
			if c.r > 0.55 and c.g > 0.4 and c.b < 0.45 and c.r > c.b + 0.25:
				counts["warm"] += 1.0
			elif absf(c.r - 0.62) < 0.14 and absf(c.g - 0.62) < 0.14 \
					and absf(c.b - 0.62) < 0.14:
				counts["silver"] += 1.0
			elif absf(c.r - 0.32) < 0.1 and absf(c.g - 0.32) < 0.1 \
					and absf(c.b - 0.33) < 0.1:
				counts["gray"] += 1.0
			elif c.r < 0.1 and c.g < 0.1 and c.b < 0.11:
				counts["rubber"] += 1.0
			elif c.r > 0.13 and c.g < 0.12 and c.b < 0.13 and c.r > c.g + 0.05:
				counts["burgundy"] += 1.0
			elif c.g > 0.5 and c.b > 0.5 and c.r < c.g - 0.2:
				counts["cyan"] += 1.0
			elif c.r > 0.35 and c.g < 0.14 and c.b < 0.14:
				counts["red"] += 1.0
	if n > 0:
		for k in counts:
			counts[k] = counts[k] / n
	return counts
