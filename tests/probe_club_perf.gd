extends Node

## THE CLUB PERF PROBE: what does llvmpipe actually spend the
## ~290 ms on? Phases: all-on -> glow-off -> lens-off -> both.

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	Settings.set_value("skip_intro", true)
	Settings.set_value("noir_lens", true)
	WorldState.reset()
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("club_district", "start")
	await get_tree().create_timer(2.0).timeout
	var env: Environment = null
	var we := get_tree().get_nodes_in_group("world_env")
	for n in get_tree().current_scene.get_children():
		if n is WorldEnvironment:
			env = n.environment
	if env == null:
		for n in get_tree().root.get_children():
			if n is WorldEnvironment:
				env = n.environment
	print("ENV=", env != null)
	var lens: CanvasLayer = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer and "Noir" in str(n.name):
			lens = n
	print("LENS=", lens != null)
	await _phase("all-on")
	if env:
		env.glow_enabled = false
	await _phase("glow-off")
	if env:
		env.glow_enabled = true
	if lens:
		lens.visible = false
	await _phase("lens-off")
	if env:
		env.glow_enabled = false
	await _phase("both-off")
	get_tree().quit(0)


func _phase(id: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var ms: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
		await get_tree().process_frame
		ms.append(float(Time.get_ticks_msec() - t0))
	# derive per-frame deltas
	var d: Array = []
	for i in range(1, ms.size()):
		d.append(ms[i] - ms[i - 1])
	d.sort()
	var p50: int = d[int(d.size() * 0.5)] if d.size() > 2 else -1
	var p95: int = d[int(d.size() * 0.95)] if d.size() > 2 else -1
	print("PHASE %s p50=%dms p95=%dms n=%d" % [id, p50, p95, d.size()])
