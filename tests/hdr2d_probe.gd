extends Node

## B18 hdr_2d measurement probe (Part 3.3). The full render_check is
## too slow under this sandbox's throttled software renderer, so this
## probe carries the SAME metric render_check uses - the pure-white
## pixel share of a real frame - plus an FPS sample, in a fraction of
## the time. Run once with hdr_2d off and once with it on; the log
## lines are the measurement.

func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("HDR2D SKIP: no display")
		get_tree().quit(0)
		return
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait_s(1.0)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening and opening.has_method("skip"):
		opening.skip()
	await _wait_s(3.0)
	# the frame: same sampling render_check uses (every 3rd pixel)
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/hdr2d_frame.png")
	var white := 0
	var total := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r > 0.965 and c.g > 0.965 and c.b > 0.965:
				white += 1
	# the fps sample: 60 frames of the settled street
	var f0 := Engine.get_frames_drawn()
	await _wait_s(1.0)
	var fps := Engine.get_frames_drawn() - f0
	print("HDR2D hdr_2d=", ProjectSettings.get_setting(
			"rendering/viewport/hdr_2d", false),
			" white_share=%.4f" % (float(white) / float(total)),
			" frames_in_1s=", fps,
			" adapter=", RenderingServer.get_video_adapter_name())
	get_tree().quit(0)
