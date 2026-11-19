#!/usr/bin/env python3
"""B4.2 - the bible Controls accessibility four, wired.

  block_hold_ms  (Tuning 250)   hold-DODGE -> block threshold + the
                                dodge tap-vs-hold split (they read the
                                same key so they can never disagree);
                                lower = easier block (hold-to-block).
  autotarget_mult (Tuning 1.0)  soft auto-target strength: reach
                                multiplier on _punch_target.
  button_scale  (Settings 1.0)  every action button's size, on top of
                                presets and the layout editor; Settings
                                screen slider next to HUD opacity.
  shake_scale   (Settings 1.0)  Fx.shake attenuation 0..1 (reduced
                                shake); Settings screen slider.
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:60])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# tuning: the two combat-feel keys (the TUNING PANEL exposes them live)
patch("scripts/tuning.gd", [(
    '''	"input_buffer_ms": 350.0,  # shipped feel (the design guess was 200)''',
    '''	"input_buffer_ms": 350.0,  # shipped feel (the design guess was 200)
	"block_hold_ms": 250.0,  # hold-DODGE this long -> block (lower = easier)
	"autotarget_mult": 1.0,  # soft auto-target strength: reach multiplier'''
)])

# settings: the two comfort keys
patch("scripts/settings.gd", [(
    '''	"opacity": 0.85,''',
    '''	"opacity": 0.85,
	"button_scale": 1.0,
	"shake_scale": 1.0,'''
)])

# player: block threshold + auto-target strength
patch("scripts/player.gd", [
    (
        """	# hold-DODGE becomes a block after 0.25 s
	if InputBus.dodge_held and InputBus.dodge_age() >= 0.25 and \\""",
        """	# hold-DODGE becomes a block after block_hold_ms (accessibility:
	# lower = easier to guard; the input bus splits tap-vs-hold on the
	# SAME key so the two can never disagree)
	if InputBus.dodge_held and InputBus.dodge_age() >= Tuning.v("block_hold_ms") / 1000.0 and \\"""
    ),
    (
        """	var best_d := PUNCH_REACH + reach_slack""",
        """	# soft auto-target strength (bible 7): the reach multiplier -
	# 1.5 sticks to anyone nearby, 0.5 demands real aim
	var best_d := (PUNCH_REACH + reach_slack) * Tuning.v("autotarget_mult")"""
    ),
])

# input bus: the tap-vs-hold split follows the block threshold
patch("scripts/input_bus.gd", [(
    """func dodge_release() -> void:
	dodge_held = false
	if not _dodge_hold_consumed and _game_msec - _dodge_down_at < DODGE_HOLD_MSEC:
		queue_dodge()  # a tap: the dodge fires on release""",
    """func dodge_release() -> void:
	dodge_held = false
	# the tap-vs-hold split reads the SAME key the player's block check
	# uses (Tuning block_hold_ms) - a lower threshold must let the tap
	# dodge on a quick release too, or the two would disagree
	if not _dodge_hold_consumed and _game_msec - _dodge_down_at < Tuning.v("block_hold_ms"):
		queue_dodge()  # a tap: the dodge fires on release"""
)])

# fx: reduced shake
patch("scripts/fx.gd", [(
    """func shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(amount)""",
    """func shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		# accessibility (bible 7): reduced shake scales every impact
		cam.shake(amount * clampf(float(Settings.value("shake_scale")), 0.0, 1.0))"""
)])

# touch buttons: button_scale at build + live rebuild
patch("scripts/touch_buttons.gd", [
    (
        """		var sz: float = spec[6]""",
        """		# accessibility (bible 7): button size on top of presets and
		# the editor's per-button scale
		var sz: float = spec[6] * clampf(float(Settings.value("button_scale")), 0.6, 1.6)"""
    ),
    (
        """func _on_setting(key: String) -> void:
	if key == "button_scheme":
		_build_buttons()
		_apply_layout()
	elif key == "layout" or key == "left_handed" or key == "opacity":
		_apply_layout()""",
        """func _on_setting(key: String) -> void:
	if key == "button_scheme":
		_build_buttons()
		_apply_layout()
	elif key == "button_scale":
		# rebuilt rects (the default positions carry the size); the
		# stored mirror offsets were computed against the old rects, so
		# a left-handed layout re-mirrors after the rebuild
		_build_buttons()
		if Settings.value("left_handed"):
			apply_preset("left")
		_apply_layout()
	elif key == "layout" or key == "left_handed" or key == "opacity":
		_apply_layout()"""
    ),
])

# settings screen: the two comfort sliders next to HUD opacity
patch("scripts/settings_ui.gd", [(
    '''	_slider(col, "HUD opacity", "opacity", 0.3, 1.0, 0.05)''',
    '''	_slider(col, "HUD opacity", "opacity", 0.3, 1.0, 0.05)
	_slider(col, "Button size", "button_scale", 0.7, 1.5, 0.05)
	_slider(col, "Screen shake", "shake_scale", 0.0, 1.0, 0.05)'''
)])

print("B4.2 patch complete")
