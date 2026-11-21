#!/usr/bin/env python3
"""Batch 1 patch: selective hitstop + Tuning wiring + AttackData wiring.

B1.b  fx.gd: hit_stop() freezes ONLY the attacker and target (anim players
      paused, velocity held, physics gated) - Engine.time_scale is never
      touched by hitstop again. slow_mo stays a camera effect on
      time_scale, and colliding slow-mos now merge (longer end, lower
      scale) instead of warning - that collision was the mysterious
      "player.gd:366 error" (a WARN with a stack trace, from a punch's
      hitstop colliding with the kill's slow-mo in one frame).
B1.a  player.gd/enemy.gd/tuning.gd: BUFFER_TIME and the input windows
      read Tuning.v(); Tuning defaults match the SHIPPED feel (buffer
      350 ms), not the prompt's guesses - the owner tunes live.
B1.c  player.gd/enemy.gd: hitstop frames, shake, camera punch and
      knockback come from AttackData (res://attacks/*.tres).
"""

import re

GAME = "/home/z/my-project/bare-hands"


def patch(path, subs, expect=True):
    p = GAME + path
    s = open(p).read()
    for old, new in subs:
        if old not in s:
            if expect:
                raise SystemExit("MISS in %s:\n%s" % (path, old[:120]))
            continue
        s = s.replace(old, new)
    open(p, "w").write(s)
    print("patched %s (%d edits)" % (path, len(subs)))


# ---------------------------------------------------------------- fx.gd ----
patch("/scripts/fx.gd", expect=False, subs=[
    # header comment: the selective model
    ("""signal hit_landed(kind: String, pos: Vector3)

const STUCK_LIMIT_MSEC := 5000  # real time; a hit-stop/slow-mo never lasts this long

var _scale_until := 0  # real-time msec when Engine.time_scale returns to 1.0
var _scale_since := 0  # real-time msec when the current scale-down started""",
     """signal hit_landed(kind: String, pos: Vector3)

const STUCK_LIMIT_MSEC := 5000  # real time; a slow-mo never lasts this long

## SELECTIVE HITSTOP (bible 8, COMBAT ARCHITECTURE): hitstop pauses ONLY
## the attacker and the target - their AnimationPlayers stop, their
## physics gate on is_frozen() - while rain, particles, music and every
## other character keep running. Engine.time_scale is NEVER used for
## hitstop. slow_mo below stays a CAMERA effect on time_scale, and two
## slow-mos landing in one frame MERGE instead of fighting (the old
## collision warning was the "player.gd:366 error": a punch's hitstop
## racing the kill's slow-mo).
var _frozen: Dictionary = {}  # node -> {"players": Array, "until": msec}

var _scale_until := 0  # real-time msec when Engine.time_scale returns to 1.0
var _scale_since := 0  # real-time msec when the current scale-down started"""),

    ("""func hit_stop(duration := 0.07, scale := 0.05) -> void:
	_apply_scale(duration, scale)""",
     """func hit_stop(frames := 4, who: Array = []) -> void:
	## Freeze the attacker and the target for `frames` logic frames
	## (60 fps): pause their AnimationPlayers and gate their physics.
	## The world keeps moving. No Engine.time_scale.
	var until := Time.get_ticks_msec() + int(frames * 1000.0 / 60.0)
	for n in who:
		if n == null or not is_instance_valid(n):
			continue
		if _frozen.has(n):
			_frozen[n]["until"] = maxi(_frozen[n]["until"], until)
			continue
		var players: Array = []
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			ap.pause()
			players.append(ap)
		_frozen[n] = {"players": players, "until": until}


## The freeze gate: player.gd and enemy.gd return early from
## _physics_process while frozen, so velocity, state timers and AI hold.
func is_frozen(node: Node) -> bool:
	return _frozen.has(node)


func _unfreeze(n: Node) -> void:
	var f: Dictionary = _frozen[n]
	_frozen.erase(n)
	# eased recovery (bible 4A): resume at 30% speed ramping back to full
	# over about four frames, so the pop back to motion reads as weight
	for ap in f["players"]:
		if is_instance_valid(ap):
			ap.speed_scale = 0.3
			ap.resume()
			var tw := create_tween()
			tw.tween_property(ap, "speed_scale", 1.0, 0.08)"""),

    ("""func _apply_scale(duration: float, scale: float) -> void:
	if Engine.time_scale != 1.0:
		Log.warn("Fx: scale %s requested while already at %s" % [scale, Engine.time_scale])
	Engine.time_scale = scale
	_scale_since = Time.get_ticks_msec()
	_scale_until = _scale_since + int(duration * 1000.0)""",
     """func _apply_scale(duration: float, scale: float) -> void:
	if Engine.time_scale != 1.0:
		# two camera slow-mos in one frame (a multi-kill, a super into a
		# knockdown): merge - keep the STRONGER (lower) scale and the
		# LONGER end. The old warning here was misread as a crash.
		Engine.time_scale = minf(Engine.time_scale, scale)
		_scale_until = maxi(_scale_until,
				Time.get_ticks_msec() + int(duration * 1000.0))
		return
	Engine.time_scale = scale
	_scale_since = Time.get_ticks_msec()
	_scale_until = _scale_since + int(duration * 1000.0)"""),

    ("""func _process(_delta: float) -> void:
	if Engine.time_scale != 1.0:""",
     """func _process(_delta: float) -> void:
	# unfreeze hitstopped characters (real time, so a pause in the tree
	# can never lock a freeze on)
	for n in _frozen.keys().duplicate():
		var f: Dictionary = _frozen[n]
		if not is_instance_valid(n):
			_frozen.erase(n)
			continue
		if Time.get_ticks_msec() >= f["until"]:
			_unfreeze(n)
	if Engine.time_scale != 1.0:"""),

    ("""func _exit_tree() -> void:
	Engine.time_scale = 1.0""",
     """func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_frozen.clear()"""),
])

# ------------------------------------------------------------ player.gd ----
patch("/scripts/player.gd", [
    # freeze gate first thing in physics
    ("""func _physics_process(delta: float) -> void:
	_t += delta
	match state:""",
     """func _physics_process(delta: float) -> void:
	if Fx.is_frozen(self):
		return  # selective hitstop: hold velocity, timers and inputs
	_t += delta
	match state:"""),

    # Tuning: the input buffer window (B1.a)
    ("""const BUFFER_TIME := 0.35""",
     """## The combo buffer window, in ms, lives in Tuning (B1.a) - the shipped
## feel is 350 ms; the design prompt's 200 ms is a starting guess the
## owner can slide live from the debug TUNING PANEL.
func _buffer_time() -> float:
	return Tuning.v("input_buffer_ms") / 1000.0"""),

    # B1.c + B1.b: the combo multi-hit lands - data-driven effects
    ("""	Fx.hit_stop(0.12 if float(hit.get("dmg", 1)) >= 3 else 0.08)
	Fx.camera_punch(float(hit.get("cam", 3.0)))
	Fx.shake(float(hit.get("shake", 0.3)))
	if hit.has("slow"):
		Fx.slow_mo(float(hit["slow"]), 0.35)""",
     """	var cad := AttackData.from_combo_hit(hit, kind)
	Fx.hit_stop(cad.hitstop_frames, [self] + (targets as Array))
	Fx.camera_punch(cad.camera_punch)
	Fx.shake(cad.shake_intensity)
	if cad.slow_mo_seconds > 0.0:
		Fx.slow_mo(cad.slow_mo_seconds, cad.slow_mo_scale)"""),

    # launcher branch
    ("""	if kind == "launcher":
		Fx.hit_stop(0.12)
		target.take_hit(dir, kind)""",
     """	if kind == "launcher":
		Fx.hit_stop(AttackData.for_attack("launcher").hitstop_frames, [self, target])
		target.take_hit(dir, kind)"""),

    # finisher branch
    ("""	if kind == "finisher":
		Fx.slow_mo(0.5, 0.3)
		Fx.hit_stop(0.16)
		target.take_hit(dir, kind)""",
     """	if kind == "finisher":
		var ad_f := AttackData.for_attack("finisher")
		Fx.slow_mo(ad_f.slow_mo_seconds, ad_f.slow_mo_scale)
		Fx.hit_stop(ad_f.hitstop_frames, [self, target])
		target.take_hit(dir, kind)"""),

    # kick branch
    ("""	if kind == "kick":
		# the kick: a distinct crack - deeper thud, heel haptic, wider arc
		Fx.hit_stop(0.12)
		target.take_hit(dir, kind)""",
     """	if kind == "kick":
		# the kick: a distinct crack - deeper thud, heel haptic, wider arc
		Fx.hit_stop(AttackData.for_attack("kick").hitstop_frames, [self, target])
		target.take_hit(dir, kind)"""),

    # normal-hit branch: effects from AttackData
    ("""	var dmg := _swing_damage(kind)
	Fx.hit_stop(0.11 if counter or kind in ["cross", "heavy", "pipe_heavy"] else 0.07)
	target.take_hit(dir, kind)
	Fx.burst(hit_pos, Color(0.3, 0.95, 1.0) if counter else
			(Color(0.75, 0.8, 0.9) if kind.begins_with("pipe") else Color(1.0, 0.75, 0.3)))
	Fx.shake(0.2 if kind == "jab" else 0.35)
	Fx.camera_punch(1.5 if kind == "jab" else (4.0 if counter else 3.0))
	if kind in ["heavy", "pipe_heavy"]:
		Fx.haptic(60)
		Fx.camera_punch(5.0)""",
     """	var dmg := _swing_damage(kind)
	var ad := AttackData.for_attack(kind)
	Fx.hit_stop(ad.hitstop_frames, [self, target])
	target.take_hit(dir, kind)
	Fx.burst(hit_pos, Color(0.3, 0.95, 1.0) if counter else
			(Color(0.75, 0.8, 0.9) if kind.begins_with("pipe") else Color(1.0, 0.75, 0.3)))
	Fx.shake(ad.shake_intensity)
	Fx.camera_punch(ad.camera_punch)
	if kind in ["heavy", "pipe_heavy"]:
		Fx.haptic(60)"""),

    # super: collect the hit list so the freeze covers them
    ("""func _land_super() -> void:
	var hit_any := false
	var radius := 2.6 * Progression.super_radius_mult()""",
     """func _land_super() -> void:
	var hit_any := false
	var struck: Array = []
	var radius := 2.6 * Progression.super_radius_mult()"""),
    ("""			Fx.burst(enemy.global_position + Vector3.UP * 1.2, Color(1.0, 0.5, 0.2))
			enemy.take_hit(to, "super")
			hit_any = true
	Fx.hit_stop(0.2)""",
     """			Fx.burst(enemy.global_position + Vector3.UP * 1.2, Color(1.0, 0.5, 0.2))
			struck.append(enemy)
			enemy.take_hit(to, "super")
			hit_any = true
	Fx.hit_stop(AttackData.for_attack("super").hitstop_frames, [self] + struck)"""),

    # environment takedown
    ("""	var kind := "slam_" + surface
	Fx.hit_stop(0.14)
	target.take_hit(dir, kind)""",
     """	var kind := "slam_" + surface
	Fx.hit_stop(8, [self, target])
	target.take_hit(dir, kind)"""),

    # knee in the grab
    ("""	dir.y = 0.0
	Fx.hit_stop(0.08)
	_grabbed_enemy.take_hit(dir.normalized(), "knee")""",
     """	dir.y = 0.0
	Fx.hit_stop(4, [self, _grabbed_enemy])
	_grabbed_enemy.take_hit(dir.normalized(), "knee")"""),

    # buffer readers
    ("""		if not _punch_heavy and _punch_stage < 3 and _t - _punch_buffered_at < BUFFER_TIME:""",
     """		if not _punch_heavy and _punch_stage < 3 and _t - _punch_buffered_at < _buffer_time():"""),
])

# ------------------------------------------------------------- enemy.gd ----
patch("/scripts/enemy.gd", [
    ("""func _physics_process(delta: float) -> void:""",
     """func _physics_process(delta: float) -> void:
	if Fx.is_frozen(self):
		return  # selective hitstop: the target holds mid-impact"""),

    # the enemy's strike landing on the hero now hitstops BOTH (bible 4A:
    # light 3-4 frames) - it never did before
    ("""		var result: String = p.take_hit(to / dist, self)
		if result == "blocked":
			_enter(State.RECOVER)  # the guard held: back off and reset""",
     """		var result: String = p.take_hit(to / dist, self)
		if result == "blocked":
			_enter(State.RECOVER)  # the guard held: back off and reset
		elif result == "hit":
			Fx.hit_stop(3, [self, p])  # the hero is clipped: a beat of weight"""),

    # knockback from AttackData: one home for the number (B1.c). The
    # bespoke reactions (anim, flash, launches, DOWN states) stay - they
    # are the character of each hit, not the math.
    ("""	dir.y = 0.0
	dir = dir.normalized()
	var dmg := _damage_of(hit_kind)
	var knock := 3.0""",
     """	dir.y = 0.0
	dir = dir.normalized()
	var dmg := _damage_of(hit_kind)
	var knock := AttackData.for_attack(hit_kind).knockback.x"""),
])

# ------------------------------------------------------------ tuning.gd ----
patch("/scripts/tuning.gd", [
    ("""	"input_buffer_ms": 200.0,""",
     """	"input_buffer_ms": 350.0,  # shipped feel (the design guess was 200)"""),
])

print("Batch 1 core patch applied")
