#!/usr/bin/env python3
## S5.9 THE PHONE COMPLETE: MAP (the drawn city + taxi fast-travel
## at a fare), NOTES (the journal), dynamic CONTACTS with trust,
## SETTINGS (volumes + haptics), the typewriter call lines, and
## voicemail replay from the call log.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:90])); sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

patch('scripts/tuning.gd', [
(
"""	"launder_cap_drift": 0.35,  # each window the cap drifts +/-35%""",
"""	"launder_cap_drift": 0.35,  # each window the cap drifts +/-35%
	"taxi_fare": 25.0,  # the cab rides clean, any corner of the city"""
),
])

patch('scripts/ui/phone.gd', [
# the seven apps, two rows
(
"""const TABS := ["CALLS", "LEDGER", "MESSAGES", "CONTACTS"]""",
"""const TABS := ["CALLS", "MAP", "LEDGER", "MESSAGES",
	"NOTES", "CONTACTS", "SETTINGS"]

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
	"airport": {"at": Vector2(0.86, 0.22), "label": "THE AIRPORT",
			"locked": true},
	"second_city": {"at": Vector2(0.60, 0.12),
			"label": "THE SECOND CITY", "locked": true},
}
const CITY_LINKS := [["warehouse", "neighbourhood"],
	["neighbourhood", "club_district"], ["club_district", "docks"],
	["club_district", "airport"], ["airport", "second_city"]]"""
),
# the tab row becomes a grid (7 apps, 4 columns, 2 rows)
(
"""	# ONE column inside the panel: a PanelContainer stretches
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
		head.add_child(b)""",
"""	# ONE column inside the panel: a PanelContainer stretches
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
		head.add_child(b)"""
),
# voicemail + trust state
(
"""var _ring: Dictionary = {}
var _ring_left := 0.0
var _call: Dictionary = {}
var _call_log: Array = []""",
"""var _ring: Dictionary = {}
var _ring_left := 0.0
var _call: Dictionary = {}
var _call_log: Array = []
var _replay: Dictionary = {}  # a logged call, re-read"""
),
# the log entries keep the whole call (voicemail)
(
"""	_call_log.append({"from": _call.get("from", "?"),
			"state": "answered"})""",
"""	_call_log.append({"from": _call.get("from", "?"),
			"state": "answered", "call": _call.duplicate(true)})"""
),
# the CALLS fill: typewriter + choices-after + voicemail replay
(
"""			elif not _call.is_empty():
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
							Color(0.75, 0.78, 0.9), 14)""",
"""			elif not _call.is_empty():
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
									_fill()))"""
),
])
print("PHONE APPS PHASE 1")

patch('scripts/ui/phone.gd', [
# the new apps in _fill's match + the typewriter
(
"""		"MESSAGES":
			var log: Array = WorldState.event_log()""",
"""		"MAP":
			var map_draw := CityMap.new()
			map_draw.custom_minimum_size = Vector2(430, 220)
			_col.add_child(map_draw)
			_line("TAXI - anywhere in the city, the meter runs $%d"
					% int(Tuning.v("taxi_fare")),
					Color(0.72, 0.75, 0.85), 13)
			var row := HBoxContainer.new()
			_col.add_child(row)
			for a in ["neighbourhood", "club_district", "docks",
					"warehouse"]:
				var dest := a
				var tb := Button.new()
				tb.text = _short_area(dest)
				tb.tooltip_text = str(CITY[dest]["label"])
				tb.custom_minimum_size = Vector2(104, 40)
				tb.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
				tb.disabled = Game.area_id == dest
				tb.pressed.connect(_taxi.bind(dest))
				row.add_child(tb)
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
			var log: Array = WorldState.event_log()"""
),
])

# --- the helpers appended at the end of the class -------------------
s = open('scripts/ui/phone.gd').read()
helpers = '''

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
	if float(res.get("paid", 0.0)) <= 0.0:
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
	if l.length() > 12:
		l = l.substr(0, 11) + "."
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
	if WorldState.flag("mission_done:m3") \\
			or WorldState.flag("m3_talked"):
		out.append(["MARLA - THE RAIN GLASS", "marla"])
	if WorldState.flag("mission_done:m3") \\
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
	sl.value = float(Settings.value(key)) if Settings.value(key) \\
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
		for link in phone_link_consts():
			var a: Vector2 = city_at(link[0]) * sz
			var b: Vector2 = city_at(link[1]) * sz
			draw_line(a, b, Color(0.25, 0.28, 0.4), 2.0)
		for id in phone_city_consts():
			var d: Dictionary = phone_city_consts()[id]
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
'''
s = s.rstrip() + '\n' + helpers
open('scripts/ui/phone.gd','w').write(s)
print("helpers + CityMap appended")
