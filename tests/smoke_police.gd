extends Node
## S5.4 HEAT RESPONSE SUITE: the witness layer (crowds vs alleys),
## the fixer text, THE COPY, its cooldown, the quiet decay, and
## the fence's scrub - the crime economy's consequence loop.
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
		print("POLICE PASS %s" % what)
	else:
		_fail += 1
		print("POLICE FAIL %s" % what)

func _kill(n: CharacterBody3D) -> void:
	n.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)

func _ready() -> void:
	var dog := get_tree().create_timer(110.0)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.2)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var police: Node = null
	for p in get_tree().get_nodes_in_group("police"):
		police = p
	# 1) THE WITNESS LAYER: two watchers make it cost more
	var peds := load("res://scripts/npc/pedestrian.gd") as GDScript
	var w1: CharacterBody3D = peds.new()
	w1.position = hero.global_position + Vector3(-4.0, 0.05, 2.0)
	get_tree().current_scene.add_child(w1)
	var w2: CharacterBody3D = peds.new()
	w2.position = hero.global_position + Vector3(-4.0, 0.05, -2.0)
	get_tree().current_scene.add_child(w2)
	await _wait_s(0.3)
	var cls := load("res://scripts/npc/enemy.gd") as GDScript
	var thug: CharacterBody3D = cls.new()
	thug.position = hero.global_position + Vector3(-4.0, 0, 0)
	get_tree().current_scene.add_child(thug)
	await _wait_s(0.3)
	_kill(thug)
	await _wait_s(0.2)
	var h := float(WorldState.get_value("heat", 0.0))
	_check(is_equal_approx(h, 6.0),
			"2 watchers: 4 base + witness_mult (%.1f)" % h)
	_check(w1.state == 2 or w2.state == 2,
			"the seeing walkers panic (w1=%d w2=%d)" % [w1.state,
					w2.state])
	# 2) THE ALLEY: nobody watching, it slides
	var lone: CharacterBody3D = cls.new()
	lone.position = hero.global_position + Vector3(24.0, 0, 18.0)
	get_tree().current_scene.add_child(lone)
	await _wait_s(0.3)
	_kill(lone)
	await _wait_s(0.2)
	h = float(WorldState.get_value("heat", 0.0))
	_check(is_equal_approx(h, 8.4),
			"alley: +4 x0.6 slides (%.1f)" % h)
	# 3) THE FIXER TEXT (heat past fixer_at since the first kill)
	var fixer := false
	for e in WorldState.event_log():
		if e.get("kind", "") == "fixer_text":
			fixer = true
	_check(fixer, "the fixer texted (heat %.1f >= 2.2)" % h)
	# 4) THE COPY: someone studied your tape
	var copy: CharacterBody3D = get_tree().current_scene.find_children(
			"TheCopy", "", true, false)[0] as CharacterBody3D \
			if get_tree().current_scene.find_children("TheCopy", "",
					true, false).size() > 0 else null
	_check(copy != null, "THE COPY is in the world")
	if copy:
		_check(copy.hp > 45.0,
				"the copy is harder than a thug (hp %.0f)" % copy.hp)
		_check(copy.has_meta("npc_label"),
				"the copy wears its name")
		# 5) the kill opens the cooldown window
		_kill(copy)
		await _wait_s(0.3)
		print("POLICE debug copy.state=%d police._copy=%s" % [
				copy.state, str(police._copy)])
		_check(police and police._copy == null,
				"the copy is down")
		_check(police and police._copy_cd_until
				> Time.get_ticks_msec(),
				"the next tape-student waits the cooldown")
	# 6) QUIET DECAY: still streets cool
	h = float(WorldState.get_value("heat", 0.0))
	police._quiet_t = 99.0
	await _wait_s(0.4)
	var h2 := float(WorldState.get_value("heat", 0.0))
	_check(h2 < h, "quiet heat decays (%.2f -> %.2f)" % [h, h2])
	# 7) THE FENCE: cash scrubs heat (the exit valve)
	await Game.travel("docks", "start")
	await _wait_s(1.2)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	WorldState.set_value("heat", 3.0)
	WorldState.set_value("cash", 10000.0)
	var price: int = 0
	hero.global_position = Vector3(30.0, 0.05, -0.5)
	await _wait_s(0.2)
	# snapshot AFTER the settle (a mission beat pays +$2 on arrival
	# - the economy is live; the fence check wants the delta)
	WorldState.set_value("cash", 10000.0)
	# price the LIVE heat (the fence reads it at pay time - the
	# decay nibbles between frames; same frame = exact)
	price = police.fence_price(
			float(WorldState.get_value("heat", 0.0)))
	var paid: bool = police.try_fence(hero)
	_check(paid, "the fence takes the grab")
	_check(float(WorldState.get_value("heat", 0.0)) == 0.0,
			"heat scrubbed to zero")
	_check(is_equal_approx(float(WorldState.get_value("cash", 0.0)),
			10000.0 - price),
			"cash pays the price (%d)" % price)
	_check(not police.try_fence(hero),
			"nothing left to scrub")
	_finish()

func _finish() -> void:
	print("POLICE RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
