#!/usr/bin/env python3
"""B4.2b - smoke_controls: the accessibility phase."""
P = "/home/z/my-project/bare-hands/"

s = open(P + "tests/smoke_controls.gd").read()

old = """	await _test_buttons_feel(player)
	await _test_feel_targets(player)
	await _test_latency(player)"""
assert s.count(old) == 1
s = s.replace(old, """	await _test_buttons_feel(player)
	await _test_feel_targets(player)
	await _test_accessibility(player, thug)
	await _test_latency(player)""")

old = """# --- measured touch-to-action latency ------------------------------------------------------"""
assert s.count(old) == 1
new = '''# --- the accessibility four (bible 7, Batch 4) ------------------------------------------------
## block_hold_ms (Tuning): the hold-DODGE -> block threshold, and the
## input bus's tap-vs-hold split follows it. button_scale (Settings):
## every button's size, rebuilt live. shake_scale (Settings): impact
## shake attenuation. autotarget_mult (Tuning): the soft auto-target's
## reach.

func _test_accessibility(player: CharacterBody3D, thug: CharacterBody3D) -> void:
	await _frame(10)
	InputBus.clear_queues()

	# 1. BLOCK HOLD: at the default 250 ms a 133 ms hold is still a
	# tap-wait, not a block; at 100 ms the same hold guards.
	InputBus.dodge_press()
	await _frame(8)
	_check(player.state != Player.State.BLOCK,
			"at 250 ms a 133 ms hold does not block yet")
	InputBus.consume_dodge_hold()
	InputBus.dodge_release()
	await _frame(3)
	Tuning.set_v("block_hold_ms", 100.0)
	InputBus.dodge_press()
	await _frame(8)  # 133 ms >= 100 ms
	_check(player.state == Player.State.BLOCK,
			"at 100 ms a 133 ms hold blocks (easier guard)")
	InputBus.consume_dodge_hold()
	InputBus.dodge_release()
	await _frame(3)
	Tuning.set_v("block_hold_ms", 250.0)
	InputBus.clear_queues()

	# 2. BUTTON SIZE: the slider rebuilds every button 1.3x.
	var punch_btn := _hud._buttons["PunchBtn"] as ActionButton
	var sz0: float = punch_btn.size.x
	Settings.set_value("button_scale", 1.3)
	await _frame(2)
	var sz1: float = (_hud._buttons["PunchBtn"] as ActionButton).size.x
	_check(sz1 > sz0 * 1.2, "button size 1.3 grows the punch button (%.0f -> %.0f)" % [sz0, sz1])
	Settings.set_value("button_scale", 1.0)
	await _frame(2)
	var sz2: float = (_hud._buttons["PunchBtn"] as ActionButton).size.x
	_check(absf(sz2 - sz0) < 1.0, "button size restores (%.0f -> %.0f)" % [sz1, sz2])

	# 3. REDUCED SHAKE: the scale attenuates every impact shake.
	var cam := get_tree().get_first_node_in_group("camera")
	Settings.set_value("shake_scale", 0.0)
	Fx.shake(0.9)
	_check(absf(float(cam._shake)) < 0.01,
			"shake 0 kills the impact shake (%.2f)" % float(cam._shake))
	Settings.set_value("shake_scale", 0.5)
	Fx.shake(0.8)
	_check(absf(float(cam._shake) - 0.4) < 0.01,
			"shake 0.5 halves it (%.2f)" % float(cam._shake))
	Settings.set_value("shake_scale", 1.0)

	# 4. AUTO-TARGET STRENGTH: the reach multiplier. A thug at 2.0 m sits
	# beyond the default 1.7 m reach, inside 1.5x (2.55 m) - read and
	# step away in the same breath so its AI never wakes.
	var park := thug.global_position
	thug.global_position = player.global_position + Vector3(2.0, 0.02, 0.0)
	var far: CharacterBody3D = player._punch_target(-0.5, 0.25)
	Tuning.set_v("autotarget_mult", 1.5)
	var near: CharacterBody3D = player._punch_target(-0.5, 0.25)
	Tuning.set_v("autotarget_mult", 1.0)
	thug.global_position = park
	thug.state = Enemy.State.IDLE
	_check(far == null, "a thug at 2.0 m is beyond the default reach")
	_check(near == thug, "auto-target 1.5x reaches it")
	InputBus.clear_queues()


# --- measured touch-to-action latency ------------------------------------------------------'''
s = s.replace(old, new)
open(P + "tests/smoke_controls.gd", "w").write(s)
print("accessibility phase added")
