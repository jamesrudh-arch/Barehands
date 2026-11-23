extends Node
## S5.1c FIGHT GATE v2: frame-catch the 0.18s SWING window, the
## thug's Hit_A reaction and the Death_A collapse - in-game, real
## AI. A watchdog guarantees exit (the v1 burst probe hung silently
## inside the hero-punch path and timed out with zero evidence).
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

# the punch cone reads the RIG node's yaw (combat.gd law), not the
# hero body's - look_at on the body misses (probe-caught twice)
func _face_rig(hero: Node3D, thug: Node3D) -> void:
	var rig := hero.get_node_or_null("Rig") as Node3D
	if rig == null:
		return
	var d := thug.global_position - hero.global_position
	rig.rotation.y = atan2(d.x, d.z)

func _snap(cam: Camera3D, hero: Node3D, name: String) -> void:
	cam.global_position = hero.global_position + Vector3(3.2, 2.0, 3.0)
	cam.look_at(hero.global_position + Vector3(-0.9, 1.3, 0.1))
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/%s.png" % name)

func _ready() -> void:
	# the watchdog: never hang the probe again (v1 law)
	var dog := get_tree().create_timer(70.0)
	dog.timeout.connect(func(): 
		print("FIGHT watchdog exit")
		get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.2)
	print("FIGHT stage=travel-done")
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var cls := load("res://scripts/npc/enemy.gd")
	var thug: CharacterBody3D = cls.new()
	thug.position = hero.position + Vector3(-2.6, 0, 0.5)
	get_tree().current_scene.add_child(thug)
	await _wait_s(0.3)
	# the capture camera (the rig-silencing law + look_at after add_child)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	await get_tree().process_frame
	cam.fov = 50.0
	cam.current = true
	print("FIGHT stage=camera")
	# 1) THE THUG'S SWING: poll every frame, burst the 0.18s window
	var seen := {}
	var burst_i := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and burst_i < 3:
		await get_tree().process_frame
		var st: int = thug.state
		seen[st] = true
		if st == 5:  # SWING
			await _snap(cam, hero, "fight_thugswing_%02d" % burst_i)
			burst_i += 1
			await _wait_s(0.3)
	print("FIGHT thug-swing shots=%d states_seen=%s hp=%.0f" % [
			burst_i, str(seen.keys()), thug.hp])
	# 2) THE HERO'S PUNCH -> the thug's HITSTUN (Hit_A reaction).
	# The punch cone needs the thug IN RANGE (it closes to ~1.7 m on
	# its own) and the hero FACING it (probe-caught: punches at
	# spawn-default facing miss - hp never moved).
	thug.hp = 60.0  # tank the burst: no DOWNED mid-capture
	var t1 := Time.get_ticks_msec()
	while hero.global_position.distance_to(thug.global_position) > 2.0 \
			and Time.get_ticks_msec() - t1 < 8000:
		await get_tree().process_frame
	_face_rig(hero, thug)
	await get_tree().process_frame
	Input.action_press("punch")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("punch")
	for i in 4:
		await _snap(cam, hero, "fight_heropunch_%02d" % i)
		await _wait_s(0.14)
	print("FIGHT hero-punch shots=4 state=%s hp=%.0f" % [thug.state,
			thug.hp])
	# 3) THE KILL -> Death_A (the knockback pushed the thug out of
	# reach - probe-caught: the kill punch whiffed at 2.0+ m)
	thug.hp = 1.0
	thug.posture = 0.0
	var t2 := Time.get_ticks_msec()
	while hero.global_position.distance_to(thug.global_position) > 1.5 			and Time.get_ticks_msec() - t2 < 8000:
		await get_tree().process_frame
	_face_rig(hero, thug)
	Input.action_press("punch")
	await get_tree().create_timer(0.16).timeout
	Input.action_release("punch")
	await _wait_s(0.25)
	await _snap(cam, hero, "fight_death_00")
	await _wait_s(0.8)
	await _snap(cam, hero, "fight_death_01")
	print("FIGHT death shots=2 state=%s hp=%.0f" % [thug.state,
			thug.hp])
	get_tree().quit(0)
