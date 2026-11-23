extends Node

## REBUILD STEP 5 proof suite: THE COMBAT CORE, live in the home's
## training corner.
##   - the face law: X punch, Y heavy, A kick, B dodge fire the right
##     attacks with the right data (damage/timings per AttackData);
##   - hits LAND on the dummy: damage, reactions, meter gain, the
##     punch chain steps p1->p2->p3 and resets;
##   - cancels: a punch may chain into the next inside the cancel
##     window, never during startup;
##   - the dodge: i-frames window, movement burst;
##   - the styles cycle and PLAY DIFFERENTLY (different clips and
##     numbers behind the same buttons);
##   - posture breaks the dummy (it tips and recovers);
##   - the finisher spends the meter.

var _fails := 0
var _checks := 0


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
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(0.6)
	await _setup_at_dummy()
	await _face_law()
	await _hits_land()
	await _chain_and_cancel()
	await _dodge()
	await _styles()
	await _posture_break()
	await _finisher()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("COMBAT PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("COMBAT FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


func _hero() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _combat() -> Node:
	var h := _hero()
	return h.get_node_or_null("Combat") if h else null


func _dummy() -> Node3D:
	for t in get_tree().get_nodes_in_group("train_target"):
		if str(t.name) == "SparringDummy":
			return t
	return null


func _bag() -> Node3D:
	for t in get_tree().get_nodes_in_group("train_target"):
		if str(t.name) == "PunchingBag":
			return t
	return null


## Stand the hero a step south of the dummy, facing it.
func _setup_at_dummy() -> void:
	var h := _hero()
	var d := _dummy()
	_check(h != null and d != null, "the hero and the dummy exist")
	if h == null or d == null:
		return
	# approach from the NORTH (hall z ends at +-7.5: standing 1.4 m
	# south of the dummy is inside the south wall - the hero fell out
	# of the world, which is exactly what the trace caught)
	h.global_position = d.global_position + Vector3(0, 0.05, -1.4)
	h.set("move_stick", Vector2.ZERO)
	# face the dummy (south, +Z: the model's authored forward at yaw 0)
	h.set("_yaw", 0.0)
	await _wait_s(0.3)


func _face_law() -> void:
	var c := _combat()
	if c == null:
		_check(false, "the combat core is mounted")
		return
	_check(true, "the combat core is mounted")
	_check(c.style_id == "brawler" and c.style != null,
			"the default style is BRAWLER with its data")
	# X fires punch_1
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.1)
	_check(c.phase == 1 or c.phase == 2 or c.phase == 3,
			"X starts the punch (phase %d)" % c.phase)
	var dmg0: float = _dummy().get("hp")
	await _wait_s(0.35)
	var dmg1: float = _dummy().get("hp")
	_check(dmg1 < dmg0,
			"the punch lands: the dummy takes damage (%.1f -> %.1f)" % [dmg0, dmg1])
	await _wait_s(0.5)
	# Y fires the heavy (bigger single hit)
	var c2 := _combat()
	Input.action_press("heavy")
	await get_tree().process_frame
	Input.action_release("heavy")
	await _wait_s(0.55)
	var dmg2: float = _dummy().get("hp")
	_check(dmg2 < dmg1 - 9.0,
			"Y heavy hits harder than the jab (%.1f -> %.1f)" % [dmg1, dmg2])
	await _wait_s(0.5)
	# A fires the kick (bigger again)
	Input.action_press("kick")
	await get_tree().process_frame
	Input.action_release("kick")
	await _wait_s(0.6)
	var dmg3: float = _dummy().get("hp")
	_check(dmg3 < dmg2 - 7.0,
			"A kick lands its own damage (%.1f -> %.1f)" % [dmg2, dmg3])


func _hits_land() -> void:
	# the meter grows with landed hits
	var c := _combat()
	var m0: float = c.meter
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.5)
	_check(c.meter > m0,
			"landing hits feeds the Leverage meter (%.1f -> %.1f)" % [m0, c.meter])
	# a whiff (nobody in reach) does not
	var h := _hero()
	h.global_position += Vector3(0, 0, 6.0)
	await _wait_s(0.3)
	var m1: float = c.meter
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.5)
	_check(c.meter == m1,
			"a whiff feeds nothing (meter %.1f)" % c.meter)
	# the bag also answers
	var bag := _bag()
	var bag_hp0: float = bag.get("hp")
	h.global_position = bag.global_position + Vector3(0, 0.05, -1.4)
	h.set("_yaw", 0.0)
	await _wait_s(0.3)
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.5)
	_check(float(bag.get("hp")) < bag_hp0,
			"the bag takes the punch too (%.1f)" % bag.get("hp"))


func _chain_and_cancel() -> void:
	var c := _combat()
	await _setup_at_dummy()
	# chain: three punches land as p1, p2, p3 (increasing damage)
	var d := _dummy()
	var hp0: float = d.get("hp")
	for i in 3:
		Input.action_press("punch")
		await get_tree().process_frame
		Input.action_release("punch")
		await _wait_s(0.34)
	var hp1: float = d.get("hp")
	_check(hp0 - hp1 >= 4.0 + 5.0 + 8.0 - 0.1,
			"the X X X chain lands p1+p2+p3 (%.1f total)" % (hp0 - hp1))
	# the chain resets after a quiet beat
	await _wait_s(1.2)
	_check(c._chain == 0, "the chain resets after the gap")
	# no input during STARTUP: mash X inside startup does not double-fire
	var hp2: float = d.get("hp")
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.02)
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.7)
	var hp3: float = d.get("hp")
	_check(hp2 - hp3 <= 5.0 + 4.0 + 0.1,
			"a startup-mash cannot double-fire the window (%.1f)" % (hp2 - hp3))


func _dodge() -> void:
	var c := _combat()
	var h := _hero()
	h.set("move_stick", Vector2(0, -0.8))
	Input.action_press("dodge")
	await get_tree().process_frame
	Input.action_release("dodge")
	h.set("move_stick", Vector2.ZERO)
	await _wait_s(0.05)
	_check(c.dodging(), "B dodge opens its i-frame window")
	var p0 := h.global_position
	await _wait_s(0.3)
	_check(h.global_position.distance_to(p0) > 0.8,
			"the dodge moves the hero (%.2f m)" % (
			h.global_position.distance_to(p0)))
	await _wait_s(0.4)
	_check(not c.dodging() and c.phase == 0,
			"the dodge ends back in IDLE (phase %d)" % c.phase)


func _styles() -> void:
	var c := _combat()
	# cycle through all five; each has its own clips + numbers
	var ids := []
	for i in 5:
		Input.action_press("style")
		await get_tree().process_frame
		Input.action_release("style")
		await _wait_s(0.15)
		if not ids.has(c.style_id):
			ids.append(c.style_id)
	_check(ids.size() == 5,
			"the STYLE action cycles all five styles (%s)" % str(ids))
	_check(c.style_id == "brawler",
			"the cycle wraps back to BRAWLER (%s)" % c.style_id)
	# WEAPON plays differently: same X, bigger number, longer reach
	_combat().set_style("weapon")
	await _setup_at_dummy()
	var d := _dummy()
	var hp0: float = d.get("hp")
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.6)
	var hp1: float = d.get("hp")
	_check(hp0 - hp1 >= 7.0 - 0.1,
			"WEAPON X hits harder than BRAWLER X (%.1f)" % (hp0 - hp1))
	# and reaches further: step back out of brawler reach, still lands
	_hero().global_position = d.global_position + Vector3(0, 0.05, -2.0)
	await _wait_s(0.3)
	var hp2: float = d.get("hp")
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	await _wait_s(0.6)
	_check(float(d.get("hp")) < hp2,
			"WEAPON reaches where fists do not (%.1f -> %.1f)" % [hp2,
			d.get("hp")])
	_combat().set_style("brawler")


func _posture_break() -> void:
	await _setup_at_dummy()
	var d := _dummy()
	d.set("posture", 2.0)
	# the heavy carries posture_damage 2.5 - one clean break from 2.0
	# (p1's 1.0 cannot, and the dummy heals posture at 0.8/s)
	Input.action_press("heavy")
	await get_tree().process_frame
	Input.action_release("heavy")
	await _wait_s(0.5)
	_check(int(d.get("tips")) >= 1 and bool(d.get("_broken")),
			"posture hits zero and the dummy BREAKS (tips %d)" % d.get("tips"))
	await _wait_s(1.6)
	_check(not bool(d.get("_broken")) and float(d.get("posture")) > 5.0,
			"the broken dummy rights itself and heals posture")


func _finisher() -> void:
	var c := _combat()
	c.meter = 60.0
	await _setup_at_dummy()
	var d := _dummy()
	# the practice corner resets: the suite's own chew ate the dummy's
	# hp to 0, and a 0 -> 0 delta would hide the finisher's damage
	d.set("hp", 60.0)
	var hp0: float = d.get("hp")
	Input.action_press("super")
	await get_tree().process_frame
	Input.action_release("super")
	await _wait_s(0.8)
	var hp1: float = d.get("hp")
	_check(hp0 - hp1 >= 15.0,
			"the finisher spends meter for the big hit (%.1f)" % (hp0 - hp1))
	_check(c.meter <= 60.0 - 40.0 + 0.1,
			"the finisher spends the meter (%.1f left)" % c.meter)
