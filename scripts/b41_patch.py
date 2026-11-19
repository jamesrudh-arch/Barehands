#!/usr/bin/env python3
"""B4.1 - wire the bible 4A feel targets (Batch 4 controls).

Audit found the Tuning keys (parry_window_ms 300 / dodge_window_ms 120 /
cancel_start_ms 150 / cancel_end_ms 350) registered but unwired, and
AttackData's cancel fields unread by the player. This patch:

  input_bus.gd: dodge_stamp() - peek a pending dodge without consuming
                it, so a too-early tap can be HELD under its original
                stamp (leniency never extends the buffer's life).
  player.gd:    - parry window: const 150 ms -> Tuning parry_window_ms
                  (300) * Styles.parry_mult() (Drunken reads punches).
                - dodge leniency: a tap during hitstun / mid-air is not
                  eaten; it fires the first free frame inside the
                  Tuning dodge_window_ms (120) - or just stays queued in
                  air (queue life still applies from the REAL tap).
                - light-cancel window: dodge may cancel a swing only
                  inside cancel_start..cancel_end (lights only; heavies/
                  kick/super are committed - their taps buffer through
                  the swing and fire after, not mid-swing).
                - the light chain flows at max(cancel_start, impact)
                  instead of the full lock: recovery is the next swing's
                  wind-up. The impact always lands first.
  styles.gd:    parry_mult per style (drunken 1.5, the rest default 1).
"""
import re

P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: pattern not unique/found: %r" % (path, old[:60])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# ---------------------------------------------------------------- input_bus
patch("scripts/input_bus.gd", [(
    """func take_dodge() -> bool:
	return _take("_dodge_at")""",
    """func take_dodge() -> bool:
	return _take("_dodge_at")


## Is a dodge waiting, and when was it tapped? (GAME-time stamp, like the
## queue itself.) Peek WITHOUT consuming: dodge leniency (bible 4A) holds
## a too-early tap under its ORIGINAL stamp so the queue's life keeps
## running from the real tap - leniency can never extend the buffer.
func dodge_stamp() -> float:
	return _dodge_at if _game_msec - _dodge_at <= QUEUE_LIFE_MSEC else -99999.0"""
)])

# ------------------------------------------------------------------ player
patch("scripts/player.gd", [
    # 1. parry window: const -> Tuning * style mult
    (
        """const BLOCK_PARRY_WINDOW := 0.15  # a block this young parries""",
        """const BLOCK_PARRY_WINDOW := 0.15  # legacy floor; see _parry_window()"""
    ),
    (
        """func _buffer_time() -> float:
	return Tuning.v("input_buffer_ms") / 1000.0""",
        """func _buffer_time() -> float:
	return Tuning.v("input_buffer_ms") / 1000.0


## The parry window (bible 4A: generous, ~300 ms) - live-tunable from the
## debug TUNING PANEL. DRUNKEN reads punches like a prophecy: the style's
## mult (styles.gd) widens it; everyone else parries at the base window.
func _parry_window() -> float:
	return Tuning.v("parry_window_ms") / 1000.0 * Styles.parry_mult()


## The light-cancel window (bible 4A: 150-350 ms, lights only). WHETHER a
## swing may cancel is per-attack DATA (AttackData cancel_end_ms > 0 -
## heavies, the kick, the super and the combo string are 0 = committed);
## WHEN the window sits is the owner's live feel dial (Tuning). A dodge
## inside the window aborts the swing (a deliberate whiff-cancel); the
## buffered chain flows from max(window_start, impact) so a cancel never
## eats the hit itself.
func _cancel_open() -> bool:
	if _punch_heavy or _punch_stage >= 4:
		return false
	var id := "jab" if _punch_stage == 1 else ("cross" if _punch_stage == 2 else "hook")
	if AttackData.for_attack(id).cancel_end_ms <= 0.0:
		return false
	return _punch_t >= Tuning.v("cancel_start_ms") / 1000.0 \\
			and _punch_t <= Tuning.v("cancel_end_ms") / 1000.0"""
    ),
    # 2. dispatch: peek the dodge, consume only when it fires
    (
        """	elif InputBus.take_dodge():
		_try_dodge()""",
        """	elif InputBus.dodge_stamp() > -99999.0:
		_try_dodge()  # peek: leniency decides inside whether to eat it"""
    ),
    # 3. parry site
    (
        """		if _block_t <= BLOCK_PARRY_WINDOW:""",
        """		if _block_t <= _parry_window():"""
    ),
    # 4. punch-step dodge gate: lights only, inside the cancel window;
    #    outside it the tap is NOT eaten - it buffers through the swing
    (
        """	if _punch_stage == 6:
		if InputBus.take_dodge() and _combo_cancellable():
			_try_dodge()  # dodge cancels a combo (level perk, PART 3)
			return
		_combo_step(delta)
		return
	if InputBus.take_dodge():
		_try_dodge()  # dodge cancels a swing
		return""",
        """	if _punch_stage == 6:
		if InputBus.take_dodge() and _combo_cancellable():
			_try_dodge()  # dodge cancels a combo (level perk, PART 3)
			return
		_combo_step(delta)
		return
	# dodge-cancel of a swing: LIGHTS ONLY, inside the cancel window (bible
	# 4A). Outside it (a heavy, the kick/super, or before/after a light's
	# window) the tap is not eaten - it stays queued under its original
	# stamp and fires the moment the swing ends and _combat_input runs
	# again, so a heavy's commitment costs the timing, never the dodge.
	if _cancel_open() and InputBus.take_dodge():
		_try_dodge()
		return"""
    ),
    # 5. the light chain flows at the cancel window (never before impact)
    (
        """	if _punch_t >= _lock_time():
		if not _punch_heavy and _punch_stage < 3 and _t - _punch_buffered_at < _buffer_time():
			_start_punch(_punch_stage + 1, false)  # the light chain
		else:
			state = State.GROUND""",
        """	# The light chain flows at the CANCEL WINDOW, not the full lock
	# (bible 4A: 150-350 ms, lights only): the swing's recovery is the
	# next swing's wind-up, so a buffered jab-cross-hook ripples. Never
	# before the impact lands - the window opens the recovery, it does
	# not eat the hit. Heavies and stage-3 finishes keep the full lock.
	var chain_at := _lock_time()
	if not _punch_heavy and _punch_stage < 3 and _cancel_open():
		chain_at = maxf(Tuning.v("cancel_start_ms") / 1000.0, _impact_time())
	if _punch_t >= chain_at:
		if not _punch_heavy and _punch_stage < 3 and _t - _punch_buffered_at < _buffer_time():
			_start_punch(_punch_stage + 1, false)  # the light chain
		else:
			state = State.GROUND"""
    ),
    # 6. dodge leniency in _try_dodge + record only when the move happens
    (
        """func _try_dodge() -> void:
	Tactics.record_player_move("dodge")
	if state == State.GRAB:
		_grab_throw()
		return
	if state not in [State.GROUND, State.PUNCH, State.BLOCK] or _t < _hitstun_until:
		return
	var stick := _stick()""",
        """func _try_dodge() -> void:
	if state == State.GRAB:
		InputBus.take_dodge()  # the throw is the dodge's answer
		Tactics.record_player_move("dodge")
		_grab_throw()
		return
	if state not in [State.GROUND, State.PUNCH, State.BLOCK] or _t < _hitstun_until:
		# Dodge leniency (bible 4A ~120 ms): a tap a beat too early is
		# not lost. If the hero comes free inside the window - hitstun
		# about to end, or mid-air about to land - the tap stays queued
		# under its ORIGINAL stamp (the queue's life keeps running from
		# the real tap; leniency never extends the buffer) and fires the
		# first frame the hero can move. Too early even for leniency:
		# eat the tap, as before. (Mid-dodge needs nothing here: nothing
		# polls the queue in DODGE, so the tap simply waits it out.)
		var soon := state == State.AIR \\
				or _hitstun_until - _t <= Tuning.v("dodge_window_ms") / 1000.0
		if not soon:
			InputBus.take_dodge()
		return
	InputBus.take_dodge()
	Tactics.record_player_move("dodge")
	var stick := _stick()"""
    ),
])

# ------------------------------------------------------------------ styles
patch("scripts/styles.gd", [
    (
        """		"id": "drunken", "name": "DRUNKEN BOXING", "teacher": "the Drunk",
		"unlock_level": 7, "color": Color(0.85, 0.75, 0.3),
		"counters_kind": 4,""",
        """		"id": "drunken", "name": "DRUNKEN BOXING", "teacher": "the Drunk",
		"unlock_level": 7, "color": Color(0.85, 0.75, 0.3),
		"counters_kind": 4, "parry_mult": 1.5,"""
    ),
    (
        """## The soft bonus multiplier on style points vs a countered kind.
func counter_style_mult(kind: int) -> float:
	return 1.3 if counters_kind(kind) else 1.0""",
        """## The soft bonus multiplier on style points vs a countered kind.
func counter_style_mult(kind: int) -> float:
	return 1.3 if counters_kind(kind) else 1.0


## How much wider this style's parry window is (bible 4A: "parry generous
## with the right style"). The Drunk reads punches like a prophecy - 1.5x
## the base window; every other style parries at the base Tuning value.
func parry_mult() -> float:
	return float(current_def().get("parry_mult", 1.0))"""
    ),
])

print("B4.1 patch complete")
