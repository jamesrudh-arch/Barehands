#!/usr/bin/env python3
"""B16 wire: staleness-proofing + null guards + SafeBoot wiring.

PART 1: unique project name (Xogot caches by name - the stale-build
suspect), BuildStamp autoload first in the chain, SafeBoot as the
temporary main scene, root README import block.

PART 3: the Music null guards. On the device Music registers as Nil
and every bare reference aborts its function every frame:
  fight_score.gd:38  match Music.state      (the spam the owner sees)
  player.gd          _retry_step + _accept_retry
  heat.gd            Music.set_heat every frame
  dialogue.gd        Music.duck per line
All guarded; the guards log ONCE (no spam). Root cause narrative in
TESTING.md: an autoload that fails to instantiate registers null on
the device; sandbox cannot reproduce a device-side registration
failure, which is exactly what SafeBoot's autoload census answers.
Plus OpeningShot.ever_finished (the SafeBoot/null-watch hook).
"""
import re

P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        if old not in s:
            if new in s:
                print("  (already)", path, old[:44].replace("\n", "\\n"))
                continue
            raise SystemExit("%s: anchor not found: %r" % (path, old[:90]))
        if s.count(old) != 1:
            raise SystemExit("%s: anchor not unique: %r" % (path, old[:90]))
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# --- 1. project.godot: unique name, BuildStamp, SafeBoot main scene --------
patch("project.godot", [
    (
        'config/name="Bare Hands 3D"',
        # unique per batch: Xogot caches projects by name, and a stale
        # cached import under the same name looks identical to a fresh
        # one (the B16 lesson)
        'config/name="LEVERAGE (Bare Hands) B16"',
    ),
    (
        'run/main_scene="res://scenes/main.tscn"',
        # TEMPORARY (B16): SafeBoot is the main scene so a fresh import
        # boots into the diagnostic path; START FULL GAME loads
        # scenes/main.tscn. Switch back when the phone is proven clean.
        'run/main_scene="res://scenes/safe_boot.tscn"',
    ),
    (
        "[autoload]\n\nTuning=",
        "[autoload]\n\nBuildStamp=\"*res://scripts/build_stamp.gd\"\nTuning=",
    ),
])

# --- 2. fight_score.gd: the :38 site ------------------------------------------
patch("scripts/fight_score.gd", [
    (
        """func _process(_delta: float) -> void:
	match Music.state:""",
        """func _process(_delta: float) -> void:
	# B16 null guard: on the device the Music singleton has registered
	# as Nil (stale/mixed cache or a registration failure - SafeBoot's
	# autoload census says which), and this match aborted every frame.
	# Guard once, log once, never spam.
	if Music == null:
		if not _music_null_logged:
			_music_null_logged = true
			push_error("FightScore: Music singleton is null on this "
					+ "device - fight ranks are paused until it loads")
		return
	match Music.state:""",
    ),
    (
        """var _in_fight := false
var _card: CanvasLayer = null""",
        """var _in_fight := false
var _card: CanvasLayer = null
var _music_null_logged := false""",
    ),
])

# --- 3. player.gd: the two Music sites ----------------------------------------
patch("scripts/player.gd", [
    (
        """func _retry_step() -> void:
	# a fresh fight means a fresh offer
	if Music.state != Music.State.COMBAT:""",
        """func _retry_step() -> void:
	# a fresh fight means a fresh offer (B16: guard - Music can be
	# null on a device where its autoload failed to register)
	if Music != null and Music.state != Music.State.COMBAT:""",
    ),
    (
        """	Heat.heat = 0.0
	Music.heat = 0.0
	Engine.time_scale = 1.0""",
        """	Heat.heat = 0.0
	if Music != null:
		Music.heat = 0.0
	Engine.time_scale = 1.0""",
    ),
])

# --- 4. heat.gd + dialogue.gd --------------------------------------------------
patch("scripts/heat.gd", [
    (
        """	_enemy_floor()  # the permanent enemy never lets it fully cool
	Music.set_heat(heat)
	_response(delta, p)""",
        """	_enemy_floor()  # the permanent enemy never lets it fully cool
	if Music != null:  # B16: the device can register it null
		Music.set_heat(heat)
	_response(delta, p)""",
    ),
])
patch("scripts/dialogue.gd", [
    (
        """	line_started.emit(_speaker, _voice_id, _line)
	Music.duck(-7.0, 1.0)""",
        """	line_started.emit(_speaker, _voice_id, _line)
	if Music != null:  # B16: the device can register it null
		Music.duck(-7.0, 1.0)""",
    ),
])

# --- 5. opening_shot.gd: ever_finished -----------------------------------------
patch("scripts/opening_shot.gd", [
    (
        """var _end := Vector3.ZERO
var _look_to := Vector3.ZERO
var _born_msec := 0""",
        """var _end := Vector3.ZERO
var _look_to := Vector3.ZERO
var _born_msec := 0

# B16: SafeBoot and smoke_null_watch read this - did the cinematic
# EVER land (skip or watchdog both count as landed)?
static var ever_finished := false""",
    ),
    (
        """func _finish() -> void:
	if _done:
		return
	var skipped := _t < 1.0
	_done = true""",
        """func _finish() -> void:
	if _done:
		return
	var skipped := _t < 1.0
	_done = true
	ever_finished = true""",
    ),
])

# --- 6. debug_panel: the stamp line --------------------------------------------
patch("scripts/debug_panel.gd", [
    (
        """	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.9, 0.95))
	panel.add_child(_label)""",
        """	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.9, 0.95))
	panel.add_child(_label)
	# B16: the build stamp in the debug menu (SafeBoot and the boot
	# corner label show it too)
	var stamp := Label.new()
	stamp.text = BuildStamp.block()
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.add_theme_color_override("font_color", Color(0.55, 0.9, 0.8, 0.9))
	panel.add_child(stamp)""",
    ),
])

print("B16 wire complete")
