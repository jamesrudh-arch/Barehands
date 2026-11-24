extends CanvasLayer

## THE PHONE (rebuild step 11): the story's pocket terminal. PHONE
## opens it; the world dims (not pauses - the street keeps moving);
## B/PHONE closes. Three apps, all reading LIVE data: LEDGER (the
## cash, THE DEBT, the heat - the story's numbers), MESSAGES (the
## event log: mission beats, door breaks, deaths - what happened),
## CONTACTS (the cast the story has introduced so far).

const TABS := ["CALLS", "MAP", "LEDGER", "BOARD",
	"MESSAGES", "NOTES", "CONTACTS", "SETTINGS"]

## the city as the MAP draws it (relative coords, connections).
## The airport + second city land with S5.14 - the map shows them
## locked until then (the bible: the whole city is knowable).
const CITY := {
	"warehouse": {"at": Vector2(0.14, 0.74), "label": "THE WAREHOUSE"},
	"neighbourhood": {"at": Vector2(0.38, 0.60),
			"label": "THE NEIGHBOURHOOD"},
	"club_district": {"at": Vector2(0.62, 0.48),
			"label": "THE CLUB DISTRICT"},
	"docks": {"at": Vector2(0.86, 0.64), "label": "THE DOCKS"},
	"airport": {"at": Vector2(0.86, 0.22), "label": "THE AIRPORT"},
	"second_city": {"at": Vector2(0.60, 0.12),
			"label": "THE SECOND CITY", "locked": true,
			"note": "by plane only - board at the airport"},
}
const CITY_LINKS := [["warehouse", "neighbourhood"],
	["neighbourhood", "club_district"], ["club_district", "docks"],
	["club_district", "airport"], ["airport", "second_city"]]

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
var _replay: Dictionary = {}  # a logged call, re-read
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
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.05, 0.12, 0.96)
	ps.border_color = Color(0.79, 0.02, 0.5)
	ps.border_width_bottom = 2
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 10.0
	ps.content_margin_right = 10.0
	ps.content_margin_top = 8.0
	ps.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", ps)
	_root.add_child(_panel)
	# ONE column inside the panel: a PanelContainer stretches
	# EVERY child to its full rect - tabs and body as siblings
	# drew on top of each other (the call screen made it loud)
	var slab := VBoxContainer.new()
	slab.name = "SlabCol"
	_panel.add_child(slab)
	var head := GridContainer.new()
	head.name = "Tabs"
	head.columns = 4
	slab.add_child(head)
	for t in TABS:
		var b := Button.new()
		b.name = "Tab_" + t
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(100, 36)
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.pressed.connect(_set_tab.bind(t))
		head.add_child(b)
	# the body SCROLLS (S5.15 gate law: THE CHOICE's buttons fell
	# below the panel fold - a call longer than the screen pushed
	# the choices out of view; on a phone that is a soft-lock)
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slab.add_child(scroll)
	_col = VBoxContainer.new()
	_col.name = "Body"
	_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_col)
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
	for b in _panel.get_node("SlabCol/Tabs").get_children():
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
	# answering pulls the CALL forward, whatever tab was open (the
	# gate law: a choice behind the BOARD tab is no choice at all)
	_tab = "CALLS"
	_fill_dirty = true
	_call = _ring
	_ring = {}
	_ring_panel.visible = false
	_call_log.append({"from": _call.get("from", "?"),
			"state": "answered", "call": _call.duplicate(true)})
	# S5.20 THE VOICE: Marla's finale rings are spoken (the cold
	# open's tongtong, on the Voice bus; the hero stays text)
	var lines: Array = _call.get("lines", [])
	if not lines.is_empty():
		var l0 := str(lines[0])
		var clip := ""
		if "counting house" in l0:
			clip = "vo_m7_ring1"
		elif "in your hands" in l0:
			clip = "vo_m7_ring2"
		# S5.23: the Corporation speaks too - the cold caller
		# (jam, the counterweight to Marla's tongtong), routed
		# by its first line so every corp ring finds its voice
		elif str(_call.get("from", "")) == "THE CORPORATION":
			if "noticed" in l0:
				clip = "vo_corp_m6"
			elif "courtesy" in l0:
				clip = "vo_corp_j9"
			elif "our building" in l0:
				clip = "vo_corp_k4"
		if clip != "":
			Sound.play(clip, -2.5, 0.97, 0.0, "Voice")
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
	if eff.has("also_flag"):
		WorldState.set_flag(str(eff["also_flag"]))
	# THE CHOICE's teeth: some prices zero a pool outright
	for k in eff.get("zero", []):
		WorldState.set_value(str(k), 0.0)
	if eff.has("also_flag"):
		WorldState.set_flag(str(eff["also_flag"]))
	# THE CHOICE's teeth: some prices zero a pool outright
	for k in eff.get("zero", []):
		WorldState.set_value(str(k), 0.0)


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
				_type_call(_call, true)
			elif not _replay.is_empty():
				_line("VOICEMAIL - %s" % str(_replay.get("from", "?")),
						Color(0.7, 0.8, 0.95), 18)
				_type_call(_replay, false)
				_col.add_child(_call_btn("HANG UP",
						Color(0.75, 0.78, 0.9),
						func() -> void:
							_replay = {}
							_fill_dirty = true
							_fill()))
			else:
				if _call_log.is_empty():
					_line("no calls tonight - the pocket is quiet",
							Color(0.45, 0.47, 0.58))
				for c in _call_log.slice(maxi(0, _call_log.size() - 8),
						_call_log.size()):
					_line("* %s - %s" % [str(c.get("from", "?")),
							str(c.get("state", "?"))],
							Color(0.75, 0.78, 0.9), 14)
					if c.has("call") and not (c.get("call",
							{}) as Dictionary).is_empty():
						var ent: Dictionary = c
						_col.add_child(_call_btn("PLAY VOICEMAIL",
								Color(0.6, 0.75, 0.9),
								func() -> void:
									_replay = ent.get("call", {})
									_tab = "CALLS"
									_fill_dirty = true
									_fill()))
		"LEDGER":
			_line("DIRTY  $%d" % int(float(WorldState.get_value(
					"stash_cash", 0.0))), Color(0.5, 1.0, 0.7))
			_line("CLEAN  $%d" % int(float(WorldState.get_value(
					"clean_cash", 0.0))), Color(0.55, 0.9, 1.0))
			_line("THE DEBT  $%d" % int(float(WorldState.get_value(
					"debt", 0.0))), Color(1.0, 0.55, 0.3))
			if WorldState.flag("story_done"):
				# S5.19: the finale landed - the ledger says so
				_line("THE DEBT IS DONE - the city keeps the rest",
						Color(1.0, 0.8, 0.4))
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
		"MAP":
			var map_draw := CityMap.new()
			map_draw.custom_minimum_size = Vector2(430, 220)
			_col.add_child(map_draw)
			_line("TAXI - anywhere in the city, the meter runs $%d"
					% int(Tuning.v("taxi_fare")),
					Color(0.72, 0.75, 0.85), 13)
			var row := HBoxContainer.new()
			_col.add_child(row)
			for a in ["neighbourhood", "club_district", "docks",
					"warehouse", "airport"]:
				var dest: String = a
				var tb := Button.new()
				tb.text = _short_area(dest)
				tb.tooltip_text = str(CITY[dest]["label"])
				tb.custom_minimum_size = Vector2(104, 40)
				tb.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
				tb.disabled = Game.area_id == dest
				tb.pressed.connect(_taxi.bind(dest))
				row.add_child(tb)
		"BOARD":
			var lv := get_tree().get_first_node_in_group("leverage")
			if lv == null:
				_line("the board is dark", Color(0.45, 0.47, 0.58))
			else:
				var clues: Array = lv.clues()
				if clues.is_empty():
					_line("no clues - the street owes you nothing yet",
							Color(0.45, 0.47, 0.58), 15)
				var targets := {}
				for c in clues:
					var t := str(c.get("target", "?"))
					if not targets.has(t):
						targets[t] = []
					(targets[t] as Array).append(c)
				for t in targets:
					var arr: Array = targets[t]
					var fresh := 0
					for c in arr:
						if not lv.clue_stale(c):
							fresh += 1
					var status := "%d piece(s)" % arr.size()
					if lv.linked(t):
						status = "LINKED - the dirt is ready"
					elif fresh == 0 and arr.size() >= 2:
						status = "STALE - the trail went cold"
					elif arr.size() >= 2:
						status = "%d piece(s), %d fresh" % [arr.size(), fresh]
					_line("%s  [%s]" % [t, status],
							Color(0.55, 0.95, 1.0)
							if lv.linked(t) else Color(0.75, 0.78, 0.9), 15)
					for c in arr:
						var stale_tag := " (stale)" if lv.clue_stale(c) else ""
						_line("  - %s%s" % [str(c.get("text", "?")),
								stale_tag],
								Color(0.6, 0.63, 0.78)
								if lv.clue_stale(c)
								else Color(0.85, 0.88, 0.95), 13)
				_line("two fresh pieces on one name unlock the squeeze",
						Color(0.45, 0.47, 0.58), 12)
		"NOTES":
			var ms := get_tree().get_first_node_in_group("missions")
			if ms and ms.active != null:
				_line("ACTIVE: %s" % str(ms.active.title),
						Color(0.95, 0.96, 0.99), 18)
				var obj: String = str(ms.active.stages[
						ms.stage_index].get("objective", ""))
				_line(obj, Color(0.75, 0.78, 0.9), 15)
			else:
				_line("no active contract - free the night",
						Color(0.45, 0.47, 0.58), 15)
			_line("- - - - -", Color(0.3, 0.32, 0.42), 13)
			for mid in _mission_titles():
				if WorldState.flag("mission_done:" + mid[0]):
					_line("DONE: %s" % mid[1],
							Color(0.5, 0.7, 0.55), 14)
		"CONTACTS":
			for c in _contacts():
				var nm: String = c[0]
				var trust: int = int(float(WorldState.get_value(
						"trust:" + c[1], 70.0)))
				_line("%s - trust %d" % [nm, trust],
						Color(0.95, 0.96, 0.99), 15)
			_line("the Corporation is not on this list",
					Color(0.45, 0.47, 0.58), 13)
		"SETTINGS":
			_setting_slider("MASTER", "Master", "vol_master", 0.8)
			_setting_slider("MUSIC", "Music", "vol_music", 0.7)
			_setting_slider("SFX", "SFX", "vol_sfx", 0.9)
			var hrow := HBoxContainer.new()
			_col.add_child(hrow)
			_line_in(hrow, "HAPTICS", Color(0.9, 0.92, 0.98), 14)
			var hb := CheckButton.new()
			hb.button_pressed = not Settings.value("haptics_off")
			hb.toggled.connect(func(on: bool):
					Settings.set_value("haptics_off", not on))
			hrow.add_child(hb)
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


## THE TYPEWRITER: the lines type out; the choices arrive after
## the last word (the bible's call pacing). Replays skip ahead.
func _type_call(call: Dictionary, with_choices: bool) -> void:
	_line("ON THE LINE - %s" % str(call.get("from", "?")),
			Color(0.95, 0.75, 0.4), 19)
	var total := 0.0
	var labels: Array = []
	for ln in call.get("lines", []):
		var l := Label.new()
		l.text = str(ln)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(430, 0)
		l.visible_characters = 0
		_col.add_child(l)
		labels.append(l)
		total += str(ln).length() / 45.0
	for l in labels:
		var lab: Label = l
		var n: int = lab.text.length()
		var tw := create_tween()
		tw.tween_property(lab, "visible_characters", n,
				maxf(0.25, n / 45.0))
	if with_choices:
		# the buttons wait for the last word
		var btns: Array = []
		var n_ch: int = call.get("choices", []).size()
		for i in n_ch:
			var ch: Dictionary = call.get("choices", [])[i]
			var idx: int = i
			var b := _call_btn(str(ch.get("label", "?")),
					Color(0.85, 0.9, 1.0),
					func() -> void: _choice(idx))
			b.modulate.a = 0.0
			_col.add_child(b)
			btns.append(b)
		var t := get_tree().create_timer(total + 0.15)
		t.timeout.connect(func() -> void:
				for b in btns:
					if is_instance_valid(b):
						(b as Button).modulate.a = 1.0)


## THE TAXI: the meter runs clean, the city opens
func _taxi(dest: String) -> void:
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	if mkt == null:
		return
	var res: Dictionary = mkt.pay(float(Tuning.v("taxi_fare")))
	if not bool(res.get("ok", false)):
		WorldState.push_event("vendor_no", {"who": "THE CAB",
				"msg": "Meter's $%d. Walk if you're broke." % int(
						Tuning.v("taxi_fare"))})
		_fill_dirty = true
		_fill()
		return
	close()
	Game.travel(dest, "start")
	WorldState.push_event("taxi", {"to": dest,
			"fare": float(Tuning.v("taxi_fare"))})


func _short_area(a: String) -> String:
	var l: String = str(CITY[a]["label"]).trim_prefix("THE ")
	match a:
		"neighbourhood":
			l = "HOME BLOCK"
		"club_district":
			l = "CLUB STRIP"
		"warehouse":
			l = "WAREHOUSE"
		"docks":
			l = "DOCKS"
		"airport":
			l = "AIRPORT"
	return l


## mission id -> title, straight from the data (cached once)
var _titles: Array = []
func _mission_titles() -> Array:
	if not _titles.is_empty():
		return _titles
	var dir := DirAccess.open("res://data/missions")
	if dir != null:
		for f in dir.get_files():
			if str(f).ends_with(".tres"):
				var m: Resource = load("res://data/missions/" + f)
				if m != null and m.get("id") != null:
					_titles.append([str(m.get("id")),
							str(m.get("title"))])
	return _titles


## the cast the story has introduced (flag-gated), with trust
func _contacts() -> Array:
	var out: Array = []
	if WorldState.flag("mission_done:m0"):
		out.append(["THE BROTHER - 'get me out of this'", "brother"])
	if WorldState.flag("mission_done:m3") \
			or WorldState.flag("m3_talked"):
		out.append(["MARLA - THE RAIN GLASS", "marla"])
	if WorldState.flag("mission_done:m3") \
			or WorldState.flag("m3_talked"):
		out.append(["OLD DEE - MAMA SUN'S", "old_dee"])
	if WorldState.flag("mission_done:m2"):
		out.append(["TONY - IRON PALM GYM", "tony"])
	if WorldState.flag("mission_done:m1"):
		out.append(["VESPER - THE VELVET ROOM", "vesper"])
	if WorldState.flag("mission_done:m1"):
		out.append(["SAL - the fish market", "sal"])
	if out.is_empty():
		out.append(["the night hasn't introduced anyone yet",
				"none"])
	return out


func _setting_slider(label: String, bus: String, key: String,
		def: float) -> void:
	var row := HBoxContainer.new()
	_col.add_child(row)
	_line_in(row, label, Color(0.9, 0.92, 0.98), 14)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size = Vector2(220, 32)
	sl.value = float(Settings.value(key)) if Settings.value(key) \
			!= null else def
	sl.value_changed.connect(func(v: float):
			Sound.set_bus_vol(bus, v)
			Settings.set_value(key, v))
	row.add_child(sl)


func _line_in(box: BoxContainer, text: String, col: Color,
		size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)


## THE CITY DIAGRAM: nodes, links, the green HERE ring
class CityMap:
	extends Control

	func _draw() -> void:
		var sz := size
		var font := ThemeDB.fallback_font
		for link in CITY_LINKS:
			var a: Vector2 = (CITY[link[0]]["at"] as Vector2) * sz
			var b: Vector2 = (CITY[link[1]]["at"] as Vector2) * sz
			draw_line(a, b, Color(0.25, 0.28, 0.4), 2.0)
		for id in CITY:
			var d: Dictionary = CITY[id]
			var at: Vector2 = d["at"] * sz
			var here: bool = Game.area_id == str(id)
			var locked: bool = bool(d.get("locked", false))
			var col := Color(0.55, 0.58, 0.72)
			if locked:
				col = Color(0.3, 0.32, 0.42)
			elif here:
				col = Color(0.24, 0.86, 0.52)
			draw_circle(at, 9.0, col)
			if here:
				draw_arc(at, 14.0, 0.0, TAU, 24,
						Color(0.24, 0.86, 0.52), 2.0)
			var lbl: String = str(d["label"])
			if locked:
				lbl += " (locked)"
			draw_string(font, at + Vector2(-52, 24), lbl,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.75, 0.78, 0.9))
