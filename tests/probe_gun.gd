extends Node
## S5.4 PISTOL GATE: the hero draws and fires at a thug - the aim
## stance, the muzzle flash, the hit reaction, framed for the VLM.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	var dog := get_tree().create_timer(70.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.5)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var cls := load("res://scripts/npc/enemy.gd") as GDScript
	var thug: CharacterBody3D = cls.new()
	thug.name = "GateThug"
	thug.hp = 40.0  # the shot lands low -> Hit_B flinch
	thug.position = hero.global_position + Vector3(-3.4, 0, 0)
	get_tree().current_scene.add_child(thug)
	await _wait_s(0.3)
	# FREEZE the thug: a circling enemy rotates the hero out of any
	# fixed camera (probe-caught twice - 'turned mostly away' was a
	# back view with the flash occluded by the hero's own body)
	thug.set_physics_process(false)
	# the capture camera (silence the rig - the fight-probe law)
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
	cam.global_position = hero.global_position + Vector3(1.4, 1.7, 2.6)
	cam.look_at(hero.global_position + Vector3(-2.0, 1.2, 0))
	var gun: Node = hero.get_node("Gun")
	var hand := hero.find_children("GunHand", "BoneAttachment3D",
			true, false)
	# aim at the thug (fresh - it circles)
	var d := thug.global_position - hero.global_position
	var rig := hero.get_node_or_null("Rig") as Node3D
	rig.rotation.y = atan2(d.x, d.z)
	# DRAW -> the stance reads
	gun.draw()
	await _wait_s(0.7)
	if hand.size() > 0:
		var hb: BoneAttachment3D = hand[0]
		var b := hb.global_transform.basis
		print("GUN hand world pos=%s" % str(hb.global_position))
		print("GUN hand +X=%s +Y=%s +Z=%s" % [str(b.x),
				str(b.y), str(b.z)])
	d = thug.global_position - hero.global_position
	rig.rotation.y = atan2(d.x, d.z)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/gun_aim.png")
	# FIRE -> the flash + shoot pose
	gun._cd = 0.0
	gun.fire()
	await get_tree().create_timer(0.05).timeout
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/gun_fire.png")
	# the hit reaction
	await _wait_s(0.18)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/gun_hit.png")
	print("GUN gate captured hp=%.0f" % thug.hp)
	get_tree().quit(0)
