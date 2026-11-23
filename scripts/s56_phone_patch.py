#!/usr/bin/env python3
## S5.6 PHONE 2.0: the CALLS app - the ring banner with its
## countdown, answer/decline, the offer's choice buttons, the
## missed-call cost (the design: one answer per ring, declining
## has costs, the buzz is the tension sound).
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

patch('scripts/ui/phone.gd', [
# the tab list + call state
(
"""const TABS := ["LEDGER", "MESSAGES", "CONTACTS"]

var _root: Control
var _tab: String = "LEDGER"
var _panel: PanelContainer
var _col: VBoxContainer""",
"""const TABS := ["CALLS", "LEDGER", "MESSAGES", "CONTACTS"]

var _root: Control
var _tab: String = "LEDGER"
var _panel: PanelContainer
var _col: VBoxContainer
# THE CALLS (S5.6): one ring at a time; the banner counts down
# over the street (the world keeps moving); a missed ring costs
# what a decline costs - the Corporation doesn't redial.
var _ring: Dictionary = {}
var _ring_left := 0.0
var _call: Dictionary = {}
var _call_log: Array = []
var _ring_panel: PanelContainer
var _ring_label: Label
var _ring_bar: ColorRect"""
),
(
"""func _ready() -> void:
	name = "Phone"
	layer = 35""",
"""func _ready() -> void:
	name = "Phone"
	add_to_group("phone")
	layer = 35"""
),
# the ring banner (visible even with the phone shut) + countdown
(
"""	_col = VBoxContainer.new()
	_col.name = "Body"
	_panel.add_child(_col)""",
"""	_col = VBoxContainer.new()
	_col.name = "Body"
	_panel.add_child(_col)
	# the ring banner: top-centre, under the objective line, added
	# directly to the CanvasLayer (NOT _root - it must show while
	# the phone slab is shut)
	_ring_panel = PanelContainer.new()
	_ring_panel.name = "RingBanner"
	_ring_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ring_panel.position = Vector2(-170, 84)
	_ring_panel.custom_minimum_size = Vector2(340, 0)
	_ring_panel.visible = false
	add_child(_ring_panel)"""
),
# banner content + countdown in _process
(
"""func _process(_delta: float) -> void:
	# state-based edge (the pause menu lesson: single-frame synthetic
	# presses can fall between ticks)
	var p := Input.is_action_pressed("phone")""",
"""func _process(delta: float) -> void:
	# the ring counts down over the street
	if not _ring.is_empty():
		_ring_left -= delta
		_ring_bar.scale.x = maxf(0.0, _ring_left \\
				/ maxf(0.001, float(_ring.get("duration", 12.0))))
		_ring_bar.position.x = 8.0 * (1.0 - _ring_bar.scale.x)
		if _ring_left <= 0.0:
			_missed()
	# state-based edge (the pause menu lesson: single-frame synthetic
	# presses can fall between ticks)
	var p := Input.is_action_pressed("phone")"""
),
# the ring banner content builder at the end of _ready (after add_child)
(
"""	_ring_panel.visible = false
	add_child(_ring_panel)""",
"""	_ring_panel.visible = false
	add_child(_ring_panel)
	var rcol := VBoxContainer.new()
	_ring_panel.add_child(rcol)
	_ring_label = Label.new()
	_ring_label.name = "Who"
	_ring_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ring_label.add_theme_font_size_override("font_size", 18)
	_ring_label.add_theme_color_override("font_color",
			Color(0.55, 0.95, 1.0))
	_ring_label.add_theme_color_override("font_outline_color",
			Color(0.01, 0.02, 0.03))
	_ring_label.add_theme_constant_override("outline_size", 8)
	rcol.add_child(_ring_label)
	var sub := Label.new()
	sub.text = "open the phone - answer before it stops"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.72, 0.75, 0.85))
	rcol.add_child(sub)
	_ring_bar = ColorRect.new()
	_ring_bar.name = "Count"
	_ring_bar.color = Color(0.55, 0.95, 1.0)
	_ring_bar.custom_minimum_size = Vector2(324, 5)
	rcol.add_child(_ring_bar)"""
),
# the CALLS app + the call API (before _fill's match, after MESSAGES etc)
(
"""func _fill() -> void:
	for c in _col.get_children():
		c.queue_free()
	match _tab:""",
"""## THE CALL (a mission's ring): from/lines/choices/duration, and
## the decline cost a missed ring also pays.
func ring(call: Dictionary) -> void:
	if not _ring.is_empty() or not _call.is_empty():
		return  # one ring at a time (the bible's law)
	_ring = call
	_ring_left = float(call.get("duration", 12.0))
	_ring_label.text = "INCOMING - %s" % str(call.get("from", "?"))
	_ring_panel.visible = true
	Haptics.fire("tick")
	Log.info("Phone: RING - %s (%.0fs)" % [str(call.get("from",
			"?")), _ring_left])


func _answer() -> void:
	_call = _ring
	_ring = {}
	_ring_panel.visible = false
	_call_log.append({"from": _call.get("from", "?"),
			"state": "answered"})
	_tab = "CALLS"
	Log.info("Phone: answered %s" % str(_call.get("from", "?")))
	_fill()


func _hang_up(what: String) -> void:
	_apply(_call.get("decline", {}))
	_call_log.append({"from": _call.get("from", "?"),
			"state": what})
	_call = {}
	Log.info("Phone: %s - the line goes dead" % what)
	_fill()


func _missed() -> void:
	_apply(_ring.get("decline", {}))
	_call_log.append({"from": _ring.get("from", "?"),
			"state": "MISSED"})
	_ring = {}
	_ring_panel.visible = false
	Log.info("Phone: missed - it costs what declining costs")
	Haptics.fire("tick")


## a choice's weight: heat/debt/clean/stash land, flags set
func _apply(eff: Dictionary) -> void:
	if eff.has("heat"):
		WorldState.bump("heat", float(eff["heat"]))
	if eff.has("debt"):
		WorldState.bump("debt", float(eff["debt"]))
	if eff.has("clean_cash"):
		WorldState.bump("clean_cash", float(eff["clean_cash"]))
	if eff.has("stash_cash"):
		WorldState.bump("stash_cash", float(eff["stash_cash"]))
	if eff.has("flag"):
		WorldState.set_flag(str(eff["flag"]))


func _choice(i: int) -> void:
	if _call.is_empty():
		return
	var c: Dictionary = _call.get("choices", [])[i]
	_apply(c)
	_call_log.append({"from": _call.get("from", "?"),
			"state": str(c.get("label", "chose"))})
	_call = {}
	Log.info("Phone: chose '%s'" % str(c.get("label", "?")))
	_fill()


func _call_btn(text: String, col: Color, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(fn)
	return b


func _fill() -> void:
	for c in _col.get_children():
		c.queue_free()
	match _tab:
		"CALLS":
			if not _ring.is_empty():
				_line("INCOMING - %s" % str(_ring.get("from", "?")),
						Color(0.55, 0.95, 1.0), 19)
				_col.add_child(_call_btn("ANSWER",
						Color(0.5, 1.0, 0.7), _answer))
				_col.add_child(_call_btn("DECLINE",
						Color(1.0, 0.5, 0.4),
						func() -> void:
							var d := _ring
							_ring = {}
							_ring_panel.visible = false
							_apply(d.get("decline", {}))
							_call_log.append({"from":
									d.get("from", "?"),
									"state": "declined"})
							_fill()))
			elif not _call.is_empty():
				_line("ON THE LINE - %s" % str(_call.get("from", "?")),
						Color(0.95, 0.75, 0.4), 19)
				for ln in _call.get("lines", []):
					_line(str(ln), Color(0.9, 0.92, 0.98), 15)
				for i in _call.get("choices", []).size():
					var ch: Dictionary = _call.get("choices", [])[i]
					var idx := i
					_col.add_child(_call_btn(
							str(ch.get("label", "?")),
							Color(0.85, 0.9, 1.0),
							func() -> void: _choice(idx)))
			else:
				if _call_log.is_empty():
					_line("no calls tonight - the pocket is quiet",
							Color(0.45, 0.47, 0.58))
				for c in _call_log.slice(maxi(0, _call_log.size() - 8),
						_call_log.size()):
					_line("* %s - %s" % [str(c.get("from", "?")),
							str(c.get("state", "?"))],
							Color(0.75, 0.78, 0.9), 14)"""
),
])
print("PHONE 2.0 WIRED")
