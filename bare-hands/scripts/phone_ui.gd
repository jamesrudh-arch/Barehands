extends CanvasLayer
## The phone's screen, built entirely in code (the debug-panel pattern:
## main.tscn stays declarative). Owns four surfaces, shown by Phone.state:
## the RING banner (combat keeps running under it - no input lock), the
## CALL screen (dim + slow, the world crawls while you talk), the app
## GRID (Last Call / Map / Log) and the screens behind those two apps.
## Neon-noir: dark glass, cyan answers, magenta costs.

const MAGENTA := Color(1.0, 0.0, 0.498)
const CYAN := Color(0.0, 0.941, 1.0)

var _banner: PanelContainer
var _banner_name: Label
var _banner_kind: Label
var _banner_bar: ColorRect
var _answer_btn: Button  # set at build; the beat cost renames it
var _screen: Control  # call screen + app screens share the dim
var _dim: ColorRect
var _call_card: PanelContainer
var _call_name: Label
var _call_line: Label
var _call_choices: HBoxContainer
var _app_grid: VBoxContainer
var _app_title: Label
var _app_body: VBoxContainer


func _ready() -> void:
	layer = 6
	_build_banner()
	_build_screen()
	visible = false
	Phone.state_changed.connect(_on_state)
	Phone.log_changed.connect(_on_log)
	_on_state()


func _process(_delta: float) -> void:
	if Phone.state == Phone.State.RINGING:
		var p := Phone.ring_progress()
		_banner_bar.custom_minimum_size.x = 240.0 * p
		_banner_bar.size.x = 240.0 * p
		visible = true


# --- the ring banner (never locks input; the fight keeps swinging) ---------------


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "RingBanner"
	_banner.visible = false
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_left = -200.0
	_banner.offset_right = 200.0
	_banner.offset_top = 14.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	sb.border_color = MAGENTA
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 10.0
	_banner.add_theme_stylebox_override("panel", sb)
	add_child(_banner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_banner.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	_banner_name = _label("", 19, Color(0.95, 0.95, 0.98))
	_banner_name.name = "Caller"
	head.add_child(_banner_name)

	_banner_kind = _label("", 12, MAGENTA)
	_banner_kind.name = "Kind"
	head.add_child(_banner_kind)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.05, 0.1, 0.9)
	bar_bg.custom_minimum_size = Vector2(240, 5)
	col.add_child(bar_bg)

	_banner_bar = ColorRect.new()
	_banner_bar.color = MAGENTA
	_banner_bar.custom_minimum_size = Vector2(240, 5)
	bar_bg.add_child(_banner_bar)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	_answer_btn = _btn("ANSWER", CYAN, func(): Phone.answer())
	_answer_btn.name = "AnswerBtn"
	buttons.add_child(_answer_btn)
	buttons.add_child(_btn("DECLINE", MAGENTA, func(): Phone.decline()))


# --- the dim screen: call + apps ------------------------------------------------


func _build_screen() -> void:
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.visible = false
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP  # eats stray touches
	add_child(_screen)

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.02, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_dim)

	_app_grid = _build_apps()
	_screen.add_child(_app_grid)

	_call_card = _build_call()
	_screen.add_child(_call_card)

	_app_title = _label("", 22, CYAN)
	_app_title.name = "AppTitle"
	_app_title.visible = false
	_screen.add_child(_app_title)

	_app_body = VBoxContainer.new()
	_app_body.name = "AppBody"
	_app_body.visible = false
	_app_body.set_anchors_preset(Control.PRESET_CENTER)
	_app_body.offset_left = -330.0
	_app_body.offset_right = 330.0
	_app_body.offset_top = -190.0
	_app_body.offset_bottom = 190.0
	_screen.add_child(_app_body)


func _build_apps() -> VBoxContainer:
	var grid := VBoxContainer.new()
	grid.name = "Apps"
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.add_theme_constant_override("separation", 14)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.offset_left = -160.0
	grid.offset_right = 160.0

	var title := _label("PHONE", 26, Color(0.95, 0.95, 0.98))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(title)

	var last := _app_button("LAST CALL", "redial the last number, once",
			Color(0.95, 0.75, 0.35), func(): _open_last_call())
	last.name = "LastCallBtn"
	grid.add_child(last)

	var map_b := _app_button("MAP", "three blocks, what you've seen",
			Color(0.5, 0.85, 0.95), func(): _open_map())
	map_b.name = "MapBtn"
	grid.add_child(map_b)

	var log_b := _app_button("CALLS", "voicemails, texts, promises",
			Color(0.75, 0.6, 0.9), func(): _open_log())
	log_b.name = "LogBtn"
	grid.add_child(log_b)

	var ledger_b := _app_button("LEDGER", "the debt book - live interest",
			Color(0.85, 0.45, 0.3), func(): _open_ledger())
	ledger_b.name = "LedgerBtn"
	grid.add_child(ledger_b)

	grid.add_child(_btn("CLOSE", Color(0.6, 0.6, 0.65), func(): Phone.close()))
	return grid


func _build_call() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "CallCard"
	card.visible = false
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -320.0
	card.offset_right = 320.0
	card.offset_top = -150.0
	card.offset_bottom = 150.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	_call_name = _label("", 20, CYAN)
	col.add_child(_call_name)

	_call_line = _label("", 17, Color(0.95, 0.95, 0.98))
	_call_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_call_line.custom_minimum_size = Vector2(560, 0)
	col.add_child(_call_line)

	# tap the card to advance lines; the choices land on the last line
	var advance := Button.new()
	advance.text = "..."
	advance.flat = true
	advance.focus_mode = Control.FOCUS_NONE
	advance.pressed.connect(func():
		if not Phone.at_last_line():
			Phone.advance_line()
		_refresh_call())
	col.add_child(advance)

	_call_choices = HBoxContainer.new()
	_call_choices.add_theme_constant_override("separation", 12)
	_call_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_call_choices)

	var hang := _btn("HANG UP", MAGENTA, func(): Phone.hang_up())
	col.add_child(hang)
	return card


# --- app screens ----------------------------------------------------------------


func _open_last_call() -> void:
	if not Phone.last_call_redial():
		_show_app_note("LAST CALL", "no number left, or already used")
	else:
		Phone.close()  # the ring banner takes it from here


func _open_map() -> void:
	_show_app("MAP")
	for child in _app_body.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_app_body.add_child(row)
	var now := City.district_now()
	for d in City.DISTRICTS:
		row.add_child(_map_card(d, d == now))
	var note := _label("no fast travel - the streets are the travel", 12,
			Color(0.6, 0.62, 0.68))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_app_body.add_child(note)
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _show_grid()))


func _map_card(district: String, is_now: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if Phone.has_visited(district):
		# heat tints the block (0 calm -> 5 hunted)
		var h := clampf(Heat.heat / 5.0, 0.0, 1.0)
		sb.bg_color = Color(0.05 + 0.25 * h, 0.08 * (1.0 - h), 0.1 * (1.0 - h), 0.95)
		sb.border_color = CYAN if is_now else Color(0.3, 0.5, 0.55)
		sb.set_border_width_all(2 if is_now else 1)
	else:
		sb.bg_color = Color(0.02, 0.02, 0.03, 0.95)
		sb.border_color = Color(0.15, 0.15, 0.2)
		sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	if Phone.has_visited(district):
		col.add_child(_label(district.to_upper(), 16,
				Color(0.92, 0.95, 0.98)))
		col.add_child(_label("here" if is_now else " ", 12, CYAN if is_now else Color(0.4, 0.4, 0.45)))
	else:
		col.add_child(_label("???", 16, Color(0.3, 0.3, 0.35)))
		col.add_child(_label("not yet walked", 12, Color(0.3, 0.3, 0.35)))
	return card


func _open_log() -> void:
	_show_app("CALLS")
	for child in _app_body.get_children():
		child.queue_free()
	var entries := Phone.log_entries()
	if entries.is_empty():
		_show_app_note("CALLS", "no calls yet - the city hasn't noticed you")
		return
	for e in entries:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.06, 0.9)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		row.add_theme_stylebox_override("panel", sb)
		_app_body.add_child(row)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)

		var who: Dictionary = Phone.sender(str(e.get("caller", "")))
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		col.add_child(head)
		head.add_child(_label(who.get("name", "?"), 15, who.get("color", Color.GRAY)))
		var outcome := str(e.get("outcome", ""))
		var oc_color := Color(0.6, 0.65, 0.7)
		if outcome in ["missed", "declined", "refused", "backed out"]:
			oc_color = MAGENTA
		elif outcome in ["paid", "promised", "answered"]:
			oc_color = CYAN
		head.add_child(_label(outcome.to_upper(), 12, oc_color))
		if float(e.get("countdown", 0.0)) > 0.0:
			head.add_child(_label("T-%ds" % int(e["countdown"]), 12,
					Color(0.95, 0.75, 0.35)))

		if e.has("text"):
			col.add_child(_label(str(e["text"]), 13, Color(0.85, 0.87, 0.9)))
		if e.has("voicemail"):
			col.add_child(_label(str(e["voicemail"][0]), 13, Color(0.7, 0.72, 0.78)))
			var play := _btn("PLAY VOICEMAIL", CYAN, func():
				_show_voicemail(e))
			col.add_child(play)
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _show_grid()))


## The debt book (bible 4G + the 30-min loop): lenders with live
## balances, the day/beat strip, both pockets, laundering, and the
## Trust column - "The Ledger always shows Trust" (bible line 106).
func _open_ledger() -> void:
	_show_app("LEDGER")
	for child in _app_body.get_children():
		child.queue_free()

	var strip := _label("DAY %d  -  %s  -  %d BEAT(S) LEFT" % [Ledger.day,
			Ledger.beat_name(), Ledger.beats_left], 14, Color(0.9, 0.8, 0.5))
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_app_body.add_child(strip)

	if Ledger.defaulted:
		var d := _label("DEFAULT - THE CITY HUNTS", 20, MAGENTA)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_app_body.add_child(d)
	elif Ledger.missed_payments > 0:
		var m := _label("MISSED PAYMENTS: %d of 3" % Ledger.missed_payments, 13, MAGENTA)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_app_body.add_child(m)

	for id in ["family", "corp", "crew"]:
		_app_body.add_child(_lender_row(id))

	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 14)
	cash_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_app_body.add_child(cash_row)
	cash_row.add_child(_label("CLEAN $%d   DIRTY $%d" % [Wallet.cash, Wallet.dirty],
			15, Color(0.7, 0.85, 0.75)))
	var launder_b := _btn("LAUNDER DIRTY (-20%%)", CYAN, func():
		Ledger.launder(Wallet.dirty)
		_open_ledger())
	launder_b.custom_minimum_size = Vector2(230, 40)
	cash_row.add_child(launder_b)

	_app_body.add_child(_trust_column())
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _show_grid()))


func _lender_row(id: String) -> PanelContainer:
	var who: Dictionary = Ledger.LENDERS[id]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.9)
	sb.border_color = who["color"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_label(who["name"], 15, who["color"]))
	var rate := "0%" if Ledger.rate_of(id) == 0.0 else "%d%%/day" % int(round(Ledger.rate_of(id) * 100.0))
	row.add_child(_label("$%d  (%s)" % [int(round(Ledger.debt[id])), rate], 15,
			Color(0.92, 0.93, 0.95)))
	row.add_child(_label(who["line"], 10, Color(0.5, 0.52, 0.58)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if Ledger.debt[id] > 0.5:
		var chip := int(Tuning.v("pay_chip"))
		row.add_child(_btn("PAY $%d" % chip, CYAN, func():
			Ledger.pay(id, chip)
			_open_ledger()))
		row.add_child(_btn("PAY ALL", MAGENTA, func():
			Ledger.pay(id, int(Ledger.debt[id]) + 1)
			_open_ledger()))
	return card


func _trust_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(_label("TRUST", 12, Color(0.6, 0.65, 0.7)))
	for id in Trust.FRIENDS:
		var f: Dictionary = Trust.FRIENDS[id]
		var v := Trust.value(id)
		var c := Color(0.4, 0.75, 0.5)
		if v < 60.0:
			c = Color(0.9, 0.75, 0.35)
		if v < 30.0:
			c = MAGENTA
		col.add_child(_label("%s  %d  (%s)" % [f["name"], int(v), Trust.tier(id)], 12, c))
	return col


func _show_voicemail(entry: Dictionary) -> void:
	_show_app("VOICEMAIL")
	for child in _app_body.get_children():
		child.queue_free()
	for line in entry.get("voicemail", []):
		var l := _label(str(line), 15, Color(0.9, 0.92, 0.95))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_app_body.add_child(l)
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _open_log()))


func _show_app(title: String) -> void:
	_app_grid.visible = false
	_call_card.visible = false
	_app_title.text = title
	_app_title.visible = true
	_app_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_app_title.offset_top = 60.0
	_app_title.offset_left = -100.0
	_app_title.offset_right = 100.0
	_app_body.visible = true


func _show_app_note(title: String, note: String) -> void:
	_show_app(title)
	for child in _app_body.get_children():
		child.queue_free()
	var l := _label(note, 15, Color(0.65, 0.68, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_app_body.add_child(l)
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _show_grid()))


func _show_grid() -> void:
	_app_title.visible = false
	_app_body.visible = false
	_call_card.visible = false
	_app_grid.visible = true


# --- state plumbing ---------------------------------------------------------------


func _on_state() -> void:
	visible = true
	var ringing := Phone.state == Phone.State.RINGING
	_banner.visible = ringing
	if ringing:
		var who: Dictionary = Trust.FRIENDS.get(Phone.caller_id(), {})
		_banner_name.text = who.get("name", "?")
		_banner_name.add_theme_color_override("font_color", who.get("color", Color.WHITE))
		_banner_kind.text = Phone.call_kind().to_upper() + " CALL"
		if _answer_btn:
			# answering spends a Beat (the 30-min loop): say so, and go
			# dark when the day has none left
			if Phone.beats_left() > 0:
				_answer_btn.text = "ANSWER - 1 BEAT"
				_answer_btn.disabled = false
			else:
				_answer_btn.text = "NO BEATS LEFT"
				_answer_btn.disabled = true
		_screen.visible = false
		return
	_screen.visible = Phone.state in [Phone.State.ON_CALL, Phone.State.OPEN]
	_call_card.visible = Phone.state == Phone.State.ON_CALL
	_app_grid.visible = Phone.state == Phone.State.OPEN
	if Phone.state == Phone.State.ON_CALL:
		_refresh_call()
	elif Phone.state == Phone.State.IDLE:
		_show_grid()


func _refresh_call() -> void:
	if Phone.state != Phone.State.ON_CALL:
		return
	var who: Dictionary = Trust.FRIENDS.get(Phone.caller_id(), {})
	_call_name.text = who.get("name", "?")
	_call_line.text = str(Phone.call_lines()[Phone.call_line_i()])
	for child in _call_choices.get_children():
		child.queue_free()
	var choice := Phone.call_choice()
	if not choice.is_empty():
		for key in ["pay", "in", "refuse", "out"]:
			if choice.has(key):
				var opt: String = key
				_call_choices.add_child(_btn(choice[key],
						CYAN if key in ["pay", "in"] else MAGENTA,
						func(): Phone.choose(opt)))


func _on_log() -> void:
	if _app_body.visible and _app_title.text == "CALLS":
		_open_log()


# --- widget helpers ----------------------------------------------------------------


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _btn(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 52)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.9)
	b.add_theme_stylebox_override("pressed", sbp)
	b.pressed.connect(cb)
	return b


func _app_button(title: String, sub: String, color: Color, cb: Callable) -> Button:
	var b := _btn("", color, cb)
	b.custom_minimum_size = Vector2(320, 64)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	b.add_child(col)
	col.add_child(_label(title, 18, color))
	col.add_child(_label(sub, 11, Color(0.55, 0.58, 0.62)))
	return b
