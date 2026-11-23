extends CanvasLayer

## THE PHONE (rebuild step 11): the story's pocket terminal. PHONE
## opens it; the world dims (not pauses - the street keeps moving);
## B/PHONE closes. Three apps, all reading LIVE data: LEDGER (the
## cash, THE DEBT, the heat - the story's numbers), MESSAGES (the
## event log: mission beats, door breaks, deaths - what happened),
## CONTACTS (the cast the story has introduced so far).

const TABS := ["CALLS", "LEDGER", "MESSAGES", "CONTACTS"]

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
var _ring_bar: ColorRect


func _ready() -> void:
	name = "Phone"
	add_to_group("phone")
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	# the phone slab: a tall panel right of centre (landscape)
	_panel = PanelContainer.new()
	_panel.name = "Slab"
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.custom_minimum_size = Vector2(470, 300)
	_panel.position = Vector2(-490, -150)
	_root.add_child(_panel)
	# ONE column inside the panel: a PanelContainer stretches
	# EVERY child to its full rect - tabs and body as siblings
	# drew on top of each other (the call screen made it loud)
	var slab := VBoxContainer.new()
	slab.name = "SlabCol"
	_panel.add_child(slab)
	var head := HBoxContainer.new()
	head.name = "Tabs"
	slab.add_child(head)
	for t in TABS:
		var b := Button.new()
		b.name = "Tab_" + t
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(100, 40)
		b.pressed.connect(_set_tab.bind(t))
		head.add_child(b)
	_col = VBoxContainer.new()
	_col.name = "Body"
	_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slab.add_child(_col)
	# the ring banner: top-centre, under the objective line, added
	# directly to the CanvasLayer (NOT _root - it must show while
	# the phone slab is shut)
	_ring_panel = PanelContainer.new()
	_ring_panel.name = "RingBanner"
	_ring_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ring_panel.position = Vector2(-170, 84)
	_ring_panel.custom_minimum_size = Vector2(340, 0)
	_ring_panel.visible = false
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
	rcol.add_child(_ring_bar)


func _process(delta: float) -> void:
	# the ring counts down over the street
	if not _ring.is_empty():
		_ring_left -= delta
		_ring_bar.scale.x = maxf(0.0, _ring_left \
				/ maxf(0.001, float(_ring.get("duration", 12.0))))
		_ring_bar.position.x = 8.0 * (1.0 - _ring_bar.scale.x)
		if _ring_left <= 0.0:
			_missed()
	# state-based edge (the pause menu lesson: single-frame synthetic
	# presses can fall between ticks)
	var p := Input.is_action_pressed("phone")
	if p and not _was_open and not _root.visible \
			and Game.state == Game.State.PLAY:
		open()
	elif not p and _was_open and _was_hold:
		close()
	_was_open = p
	if _root.visible:
		_fill()


var _was_open := false
var _was_hold := false
var _wired_hero: Node = null  # the one hero whose signal we ride


## The hero's action signal (the proven path - face_action fires
## for every mapped action; the direct poll below stays as the
## controller/keyboard second trigger).
func on_hero_action(action: String) -> void:
	if action != "phone" or Game.state != Game.State.PLAY:
		return
	if not _root.visible:
		open(false)  # signal-opened: the poll may not close it
	else:
		close()


func open(from_poll := true) -> void:
	_root.visible = true
	_was_hold = from_poll  # only the poll's own opens are its closes
	if not _ring.is_empty():
		_tab = "CALLS"  # a ringing phone opens on the call
	_set_tab(_tab)
	Log.info("Phone: open (%s)" % _tab)


func close() -> void:
	_root.visible = false
	_was_hold = false


func _set_tab(t: String) -> void:
	_tab = t
	_fill_dirty = true
	for b in _panel.get_node("Tabs").get_children():
		b.button_pressed = str(b.name).trim_prefix("Tab_") == t
	_fill()


## THE CALL (a mission's ring): from/lines/choices/duration, and
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
	_fill_dirty = true
	_fill()


func _hang_up(what: String) -> void:
	_apply(_call.get("decline", {}))
	_call_log.append({"from": _call.get("from", "?"),
			"state": what})
	_call = {}
	Log.info("Phone: %s - the line goes dead" % what)
	_fill_dirty = true
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
	_fill_dirty = true
	_fill()


func _call_btn(text: String, col: Color, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(fn)
	return b


var _fill_dirty := true

## rebuild only when something changed - the every-frame rebuild
## stacked one frame of dying labels over the new ones (the call
## screen's third line ghosted over the tab row)
func _fill() -> void:
	if not _fill_dirty:
		return
	_fill_dirty = false
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
							_fill_dirty = true
							_fill()))
			elif not _call.is_empty():
				_line("ON THE LINE - %s" % str(_call.get("from", "?")),
						Color(0.95, 0.75, 0.4), 19)
				for ln in _call.get("lines", []):
					_line(str(ln), Color(0.9, 0.92, 0.98), 15)
				var n_ch: int = _call.get("choices", []).size()
				for i in n_ch:
					var ch: Dictionary = _call.get("choices", [])[i]
					var idx: int = i
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
							Color(0.75, 0.78, 0.9), 14)
		"LEDGER":
			_line("DIRTY  $%d" % int(float(WorldState.get_value(
					"stash_cash", 0.0))), Color(0.5, 1.0, 0.7))
			_line("CLEAN  $%d" % int(float(WorldState.get_value(
					"clean_cash", 0.0))), Color(0.55, 0.9, 1.0))
			_line("THE DEBT  $%d" % int(float(WorldState.get_value(
					"debt", 0.0))), Color(1.0, 0.55, 0.3))
			_line("HEAT  %d" % int(float(WorldState.get_value(
					"heat", 0.0))), Color(1.0, 0.45, 0.2))
			# the quick-pay chip (bible: pay_chip on the Ledger)
			var chip := Button.new()
			chip.text = "PAY DEBT  $%d" % int(Tuning.v("pay_chip"))
			chip.custom_minimum_size = Vector2(0, 40)
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			var pay := func() -> void:
				var mkt: Node = null
				for m in get_tree().get_nodes_in_group("market"):
					mkt = m
				if mkt and mkt.pay_debt(Tuning.v("pay_chip")):
					_fill_dirty = true
					_fill()
			chip.pressed.connect(pay)
			_col.add_child(chip)
			_line("the debt eats CLEAN only - launder at the club",
					Color(0.72, 0.75, 0.85), 14)
		"MESSAGES":
			var log: Array = WorldState.event_log()
			if log.is_empty():
				_line("no messages - the street is quiet",
						Color(0.45, 0.47, 0.58))
			for e in log.slice(maxi(0, log.size() - 9), log.size()):
				_line("* %s" % str(e.get("kind", "?")),
						Color(0.75, 0.78, 0.9), 14)
		"CONTACTS":
			_line("THE BROTHER - 'get me out of this'",
					Color(0.95, 0.96, 0.99))
			_line("THE RAIN GLASS - the bar that fronts the errands",
					Color(0.95, 0.96, 0.99))
			_line("the streets have more faces as the story opens them",
					Color(0.45, 0.47, 0.58), 13)


func _line(text: String, col: Color, size := 16) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	_col.add_child(l)
