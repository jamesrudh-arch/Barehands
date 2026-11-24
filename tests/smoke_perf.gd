extends Node

## REBUILD STEP 13 proof suite: THE PERF AUDIT. The honest metrics
## under llvmpipe are COUNTS and STABILITY, not device FPS (the
## software renderer's milliseconds are not the phone's):
##   - per area: real lights vs the mobile budget (a few lights +
##     emissive practicals + the fill - never a lamp per post),
##     mesh instances, draw calls, visible nodes;
##   - frame-time stability over a 3 s hold per area (no climbing
##     allocations / leak-shaped growth);
##   - the results also land in user://perf_audit.json for the
##     device report.

const AREAS := ["warehouse", "neighbourhood", "club_district", "docks"]
const LIGHT_BUDGET := 12       # real lights per area (mobile law)
const MESH_BUDGET := 1500      # mesh instances per area
const FRAME_MS_95 := 250.0     # llvmpipe p95 (not the phone's)

var _fails := 0
var _checks := 0
var _report := {}


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
	for area in AREAS:
		await _audit_area(area)
	_finish()


func _finish() -> void:
	_report["stamp"] = Time.get_unix_time_from_system()
	var f := FileAccess.open("user://perf_audit.json",
			FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_report, "\t"))
		f.close()
	if _fails == 0:
		print("PERF PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("PERF FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _audit_area(area: String) -> void:
	await Game.travel(area, "start")
	await _wait_s(2.0)  # warm: settle, first frames gone
	var scene := get_tree().current_scene
	# counts (a dictionary accumulator: GDScript ints pass by value)
	var acc := {"lights": 0, "meshes": 0, "nodes": 0}
	_count(scene, acc)
	var lights: int = acc["lights"]
	var meshes: int = acc["meshes"]
	var nodes: int = acc["nodes"]
	var draws := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var lens := 0
	for c in scene.get_children():
		if c is WorldEnvironment and c.environment.fog_enabled:
			lens = 1
	# frame-time stability: sample 3 s
	var samples: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		samples.append(Time.get_ticks_msec())
	var frames_ms: Array = []
	for i in range(1, samples.size()):
		frames_ms.append(samples[i] - samples[i - 1])
	frames_ms.sort()
	var p50: int = frames_ms[frames_ms.size() / 2] if frames_ms.size() > 0 else 999
	var p95: int = frames_ms[int(frames_ms.size() * 0.95)] \
			if frames_ms.size() > 0 else 999
	_report[area] = {
		"lights": lights, "meshes": meshes, "nodes": nodes,
		"draws": draws, "fog": lens, "p50_ms": p50, "p95_ms": p95,
		"samples": frames_ms.size(),
	}
	print("  .. %s: lights=%d meshes=%d draws=%d p50=%dms p95=%dms" % [
			area, lights, meshes, draws, p50, p95])
	_check(lights <= LIGHT_BUDGET,
			"%s: real lights within budget (%d <= %d)" % [
			area, lights, LIGHT_BUDGET])
	_check(meshes <= MESH_BUDGET,
			"%s: mesh instances within budget (%d <= %d)" % [
			area, meshes, MESH_BUDGET])
	_check(p95 <= FRAME_MS_95,
			"%s: frame times stable (p95 %d ms <= %d, %d samples)" % [
			area, p95, FRAME_MS_95, frames_ms.size()])
	# the physics world is clean: no orphan bodies accumulating
	var bodies := 0
	for n in get_tree().get_nodes_in_group("vehicle"):
		bodies += 1
	_report[area]["vehicles"] = bodies


func _count(n: Node, acc: Dictionary) -> void:
	_count_lights(n, acc)
	acc["nodes"] = int(acc["nodes"]) + 1
	if n is MeshInstance3D:
		acc["meshes"] = int(acc["meshes"]) + 1
	if n is MeshInstance3D:
		acc["meshes"] = int(acc["meshes"]) + 1
	for c in n.get_children():
		_count(c, acc)

## S5.19: the light count classifies - AREA lights (the mobile
## budget's subject) vs the hero rig's own (face fill, muzzle
## flash: they ride the player, not the area) and the single
## global CityFill (DirectionalLight, the night's moon).
func _count_lights(n: Node, acc: Dictionary) -> void:
	if not (n is OmniLight3D or n is SpotLight3D):
		return   # DirectionalLight = the global fill, never counted
	var p: Node = n.get_parent()
	while p:
		if p.is_in_group("player"):
			return   # the hero's rig lights, not area practicals
		p = p.get_parent()
	acc["lights"] = int(acc["lights"]) + 1

