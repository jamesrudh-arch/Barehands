#!/usr/bin/env python3
"""B4.2 - smoke_controls: the bible 4A feel-target phase."""
P = "/home/z/my-project/bare-hands/"

s = open(P + "tests/smoke_controls.gd").read()

# register the phase after the buttons-feel phase
old = """	await _test_buttons_feel(player)
	await _test_latency(player)"""
assert s.count(old) == 1
s = s.replace(old, """	await _test_buttons_feel(player)
	await _test_feel_targets(player)
	await _test_latency(player)""")

# the new phase, inserted before the latency section
old = """# --- measured touch-to-action latency ------------------------------------------------------"""
assert s.count(old) == 1
new = '''# --- the bible 4A feel targets (Batch 4) ----------------------------------------------------
## The four Tuning feel numbers, wired: dodge leniency ~120 ms (a tap a
## beat too early is held, not eaten), the light-cancel window 150-350 ms
## (dodge interrupts a LIGHT swing only inside it; heavies commit), the
## chain flowing at the window instead of the full lock, and the parry
## window 300 ms widened 1.5x by DRUNKEN.

func _test_feel_targets(player: CharacterBody3D) -> void:
	await _frame(10)
	InputBus.clear_queues()

	# 1. DODGE LENIENCY: a tap 80 ms before hitstun ends is held (never
	# fires DURING the stun) and fires the first free frame after it.
	player._hitstun_until = player._t + 0.08
	InputBus.queue_dodge()
	await _frame(2)
	_check(player.state != Player.State.DODGE,
			"leniency: no dodge while still stunned")
	var fired := false
	for i in 15:
		await _frame(1)
		if player.state == Player.State.DODGE:
			fired = true
			break
	_check(fired, "leniency: a dodge tapped 80 ms early fires when the stun ends")
	await _frame(40)  # let the dodge finish
	InputBus.clear_queues()

	# 2. Too early even for leniency (400 ms of stun left > 120 ms
	# window): the tap is eaten, exactly as before - leniency never
	# becomes a long buffer.
	player._hitstun_until = player._t + 0.4
	InputBus.queue_dodge()
	var leaked := false
	for i in 30:
		await _frame(1)
		if player.state == Player.State.DODGE:
			leaked = true
			break
	_check(not leaked, "a dodge tapped 400 ms early is dropped (no long buffer)")
	player._hitstun_until = 0.0
	await _frame(2)

	# 3. THE LIGHT-CANCEL WINDOW: a dodge ~70 ms into a jab does not
	# interrupt the swing; the held tap fires when the window opens.
	InputBus.clear_queues()
	InputBus.punch_press()
	InputBus.punch_release()
	await _frame(4)  # the jab is ~65 ms in
	InputBus.dodge_press()
	InputBus.dodge_release()
	await _frame(3)
	_check(player.state == Player.State.PUNCH,
			"a dodge before the window does not interrupt the jab")
	var cancelled := false
	for i in 12:
		await _frame(1)
		if player.state == Player.State.DODGE:
			cancelled = true
			break
	_check(cancelled, "the held dodge cancels the jab when the window opens (150 ms)")
	await _frame(40)
	InputBus.clear_queues()

	# 4. HEAVIES COMMIT (bible: cancel is lights only): a dodge tapped
	# mid-heavy never interrupts the swing, and the heavy's 750 ms lock
	# outlasts the 400 ms queue life - the tap lapses. Commitment costs
	# the dodge's timing; re-tap after the swing.
	InputBus.clear_queues()
	InputBus.punch_press()  # hold: the heavy at 300 ms
	var h := 0
	while not (player._punch_stage == 3 and player._punch_heavy):
		await _frame(1)
		h += 1
		if h > 40:
			break
	_check(player._punch_stage == 3 and player._punch_heavy, "the hold becomes a heavy")
	await _frame(5)  # ~80 ms into the heavy
	InputBus.dodge_press()
	InputBus.dodge_release()
	await _frame(8)
	_check(player.state == Player.State.PUNCH, "a dodge mid-heavy never interrupts the swing")
	InputBus.consume_punch_hold()
	InputBus.punch_release()  # consumed: no light queues on the release
	var leaked2 := false
	for i in 55:  # through the 750 ms lock, past the 400 ms queue life
		await _frame(1)
		if player.state == Player.State.DODGE:
			leaked2 = true
			break
	_check(not leaked2, "the heavy outlasts the dodge tap (re-tap to evade)")
	InputBus.clear_queues()
	await _frame(5)

	# 5. THE CHAIN FLOWS AT THE WINDOW: a buffered cross starts at the
	# cancel window (never before the jab's 200 ms impact), not at the
	# full 420 ms lock - recovery is the next swing's wind-up.
	InputBus.clear_queues()
	InputBus.punch_press()
	InputBus.punch_release()
	var sw := 0
	while player.state != Player.State.PUNCH:
		await _frame(1)
		sw += 1
		if sw > 10:
			break
	await _frame(3)  # buffer the cross at ~65 ms
	InputBus.punch_press()
	InputBus.punch_release()
	var f2 := 0
	while player._punch_stage != 2:
		await _frame(1)
		f2 += 1
		if f2 > 30:
			break
	# impact 200 ms = ~12 frames from the swing's start; the old lock
	# path chained at ~25 frames
	_check(f2 >= 8 and f2 <= 18,
			"the buffered cross flows at the cancel window (%d frames, ~25 at the old lock)" % f2)
	await _frame(30)
	InputBus.clear_queues()

	# 6. THE PARRY WINDOW (Tuning, 300 ms): a block 200 ms old still
	# parries - the shipped const was 150 ms.
	InputBus.clear_queues()
	InputBus.dodge_held = true
	player._enter_block()
	for i in 12:  # 200 ms of guard
		await _frame(1)
	var res: String = player.take_hit(Vector3(1.0, 0.0, 0.0), "heavy")
	_check(res == "parried",
			"a 200 ms-old block parries (window %.0f ms)" % (player._parry_window() * 1000.0))
	InputBus.dodge_held = false
	await _frame(3)
	InputBus.clear_queues()

	# 7. DRUNKEN reads punches (1.5x): a 350 ms-old block parries in
	# that style only - past the 300 ms base window.
	Styles.unlock_all_for_test()
	Styles.switch_to("drunken")
	_check(Styles.parry_mult() == 1.5, "drunken's parry mult is 1.5")
	InputBus.dodge_held = true
	player._enter_block()
	for i in 21:  # 350 ms of guard
		await _frame(1)
	var res2: String = player.take_hit(Vector3(1.0, 0.0, 0.0), "heavy")
	_check(res2 == "parried", "a 350 ms-old DRUNKEN block parries (1.5x the window)")
	InputBus.dodge_held = false
	await _frame(3)
	Styles.switch_to("brawler")
	InputBus.clear_queues()


# --- measured touch-to-action latency ------------------------------------------------------'''
s = s.replace(old, new)
open(P + "tests/smoke_controls.gd", "w").write(s)
print("feel-target phase added")
