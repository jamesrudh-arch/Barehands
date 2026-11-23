extends Node
## S5.4 PISTOL SUITE: draw, stance, fire, hitscan damage, ammo,
## reload, holster - the deterministic layer under the VLM gate.
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("GUN PASS %s" % what)
	else:
		_fail += 1
		print("GUN FAIL %s" % what)

func _ready() -> void:
	var dog := get_tree().create_timer(90.0)
	dog.timeout.connect(func(): _finish())
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
	var gun: Node = hero.get_node_or_null("Gun")
	_check(gun != null, "the gun rides the hero")
	if gun == null:
		_finish()
		return
	_check(not gun.drawn and gun.ammo == 12 and gun.reserve == 24,
			"holstered start (12+24)")
	# a thug down the hall, in the open
	var cls := load("res://scripts/npc/enemy.gd") as GDScript
	var thug: CharacterBody3D = cls.new()
	thug.name = "SuiteThug"   # the warehouse's own muscle took the
	# first shot (closest in the cone - correct behavior); track OURS
	thug.position = hero.global_position + Vector3(-6.0, 0, 0)
	get_tree().current_scene.add_child(thug)
	await _wait_s(0.4)
	var hp0: float = thug.hp
	# DRAW
	gun.draw()
	await _wait_s(0.3)
	_check(gun.drawn, "drawn")
	var pistol := hero.find_children("Pistol", "Node3D", true, false)
	_check(pistol.size() > 0 and pistol[0].visible,
			"the pistol shows in hand (%d)" % pistol.size())
	# the parameter-path GET is write-only in practice; the blend
	# tree's own node is the readable truth
	var bt: AnimationNodeBlendTree = gun._tree.tree_root
	var idleanim := (bt.get_node("idle") as AnimationNodeAnimation)
	_check(str(idleanim.animation).find("Pistol") >= 0,
			"the tree runs the pistol stance (%s)" % str(
					idleanim.animation))
	# face the thug (the RIG yaw law) and FIRE - aim at its CURRENT
	# position (a circling thug walks out of a stale snapshot)
	var rig := hero.get_node_or_null("Rig") as Node3D
	var d := thug.global_position - hero.global_position
	rig.rotation.y = atan2(d.x, d.z)
	await get_tree().process_frame
	d = thug.global_position - hero.global_position
	rig.rotation.y = atan2(d.x, d.z)
	gun.fire()
	await _wait_s(0.8)
	_check(gun.ammo == 11, "fire spends ammo (11)")
	_check(thug.hp < hp0, "the shot damages at range (%.0f < %.0f)"
			% [thug.hp, hp0])
	# empty the clip -> auto-reload
	thug.hp = 500.0
	gun.ammo = 1
	gun._cd = 0.0
	gun._busy_s = 0.0
	rig.rotation.y = atan2(d.x, d.z)
	gun.fire()
	await _wait_s(0.2)
	_check(gun.ammo == 0 and gun._reloading,
			"dry fire auto-reloads (reloading=%s)" % gun._reloading)
	await _wait_s(2.0)
	_check(gun.ammo == 12 and gun.reserve == 12,
			"reload restores the clip (12+12)")
	# HOLSTER
	gun.holster()
	await _wait_s(0.2)
	_check(not gun.drawn and not pistol[0].visible,
			"holster hides the pistol")
	_finish()

func _finish() -> void:
	print("GUN RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
