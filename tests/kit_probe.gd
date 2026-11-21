extends Node

## B18.4: graphics facts probe - draw calls and triangles of the live
## main street, sampled over frames (deferred spawns settled first).
## Rendered run only (Xvfb + opengl3): draw calls do not exist headless.
## Run: DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . \
##      --rendering-driver opengl3 res://tests/kit_probe.tscn

const SETTLE_FRAMES := 180  # 3 s: pickups, crowd, ambience all landed
const SAMPLE_FRAMES := 120

var _main: Node
var _tick := 0
var _draws_max := 0
var _tris_max := 0
var _draws_sum := 0
var _tris_sum := 0
var _samples := 0


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()


func _process(_delta: float) -> void:
	_tick += 1
	if _tick < SETTLE_FRAMES:
		return
	if _tick >= SETTLE_FRAMES + SAMPLE_FRAMES:
		_report()
		get_tree().quit(0)
		return
	var draws := int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris := int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	_draws_max = maxi(_draws_max, draws)
	_tris_max = maxi(_tris_max, tris)
	_draws_sum += draws
	_tris_sum += tris
	_samples += 1


func _report() -> void:
	var avg_d := _draws_sum / maxi(_samples, 1)
	var avg_t := _tris_sum / maxi(_samples, 1)
	var kits := get_tree().get_nodes_in_group("cc0_kit").size()
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/kit_probe.png")
	print("KITPROBE frame saved /tmp/kit_probe.png (%d x %d)" % [img.get_width(), img.get_height()])
	print("KITPROBE draw_calls max=%d avg=%d" % [_draws_max, avg_d])
	print("KITPROBE triangles max=%d avg=%d" % [_tris_max, avg_t])
	print("KITPROBE cc0_kit nodes=%d" % kits)
	print("KITPROBE PASS (frames sampled %d)" % _samples)
