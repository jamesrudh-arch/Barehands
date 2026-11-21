extends CanvasLayer

## The money on screen: the balance (top-right, under the style meter),
## a "-$5" pop that rises and fades every time cash moves, a one-line
## receipt ticker for the latest entry, and the first-offer modal that shows
## the cost of each bullet before the gun is ever taken.

var _label: Label
var _pop: Label
var _ticker: Label
var _pop_a := 0.0
var _pop_text := ""
var _ticker_a := 0.0
var _modal: PanelContainer


func _ready() -> void:
	layer = 6
	add_to_group("cash_hud")

	_label = Label.new()
	_label.text = "$ %d" % Wallet.total()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -220.0
	_label.offset_right = -16.0
	_label.offset_top = 92.0
	_label.offset_bottom = 124.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	add_child(_label)

	_pop = Label.new()
	_pop.anchor_left = 1.0
	_label.anchor_right = 1.0
	_pop.offset_left = -160.0
	_pop.offset_right = -16.0
	_pop.offset_top = 124.0
	_pop.offset_bottom = 152.0
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pop.add_theme_font_size_override("font_size", 18)
	_pop.modulate.a = 0.0
	add_child(_pop)

	_ticker = Label.new()
	_ticker.offset_left = 20.0
	_ticker.offset_top = 64.0
	_ticker.offset_right = 520.0
	_ticker.offset_bottom = 88.0
	_ticker.add_theme_font_size_override("font_size", 13)
	_ticker.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 0.9))
	_ticker.modulate.a = 0.0
	add_child(_ticker)

	Wallet.changed.connect(_on_cash)
	Wallet.entry_added.connect(_on_entry)


func _process(delta: float) -> void:
	if _pop_a > 0.0:
		_pop_a = maxf(_pop_a - delta, 0.0)
		_pop.modulate.a = _pop_a
		_pop.offset_top = 124.0 - (1.0 - _pop_a) * 34.0
		_pop.offset_bottom = _pop.offset_top + 28.0
	if _ticker_a > 0.0:
		_ticker_a = maxf(_ticker_a - delta * 0.5, 0.0)
		_ticker.modulate.a = minf(_ticker_a, 1.0)


func _on_cash(cash: int, delta: int) -> void:
	_label.text = "$ %d" % Wallet.total()
	_pop_text = ("+$%d" % delta) if delta > 0 else ("-$%d" % -delta)
	_pop.text = _pop_text
	_pop.add_theme_color_override("font_color",
			Color(0.5, 1.0, 0.6) if delta > 0 else Color(1.0, 0.45, 0.4))
	_pop_a = 1.6
	Sound.play("coins_0" if delta > 0 else "ui_click_0", -10.0)


func _on_entry(entry: Dictionary) -> void:
	_ticker.text = "%s  %s  %s  %s$%d   BAL $%d" % [entry.time, entry.kind,
			entry.item, "+" if entry.amount > 0 else "-", absi(entry.amount),
			entry.balance]
	_ticker_a = 3.0


## The first time a gun is offered, the price of every bullet is on the
## table before anything is owned.
func show_gun_offer(on_take: Callable, on_leave: Callable) -> void:
	if _modal:
		return
	Wallet.gun_offered = true
	InputBus.locked = true
	_modal = PanelContainer.new()
	_modal.anchor_left = 0.5
	_modal.anchor_right = 0.5
	_modal.anchor_top = 0.5
	_modal.anchor_bottom = 0.5
	_modal.offset_left = -230.0
	_modal.offset_right = 230.0
	_modal.offset_top = -150.0
	_modal.offset_bottom = 110.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.032, 0.04, 0.96)
	sb.border_color = Color(0.92, 0.88, 0.78, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	_modal.add_theme_stylebox_override("panel", sb)
	add_child(_modal)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_modal.add_child(col)

	var title := Label.new()
	title.text = "THE LEDGER IRON"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	col.add_child(title)

	var body := Label.new()
	body.text = "A test piece. No gun is free.\nEvery bullet you fire costs $%d of your own money.\nThe ledger remembers each one." % Wallet.bullet_cost()
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(400, 0)
	col.add_child(body)

	var heat_line := Label.new()
	heat_line.text = "HEAT .......... %s (%.1f)" % [Heat.tier_name(), Heat.heat]
	heat_line.add_theme_font_size_override("font_size", 17)
	heat_line.add_theme_color_override("font_color", Color(1.0, 0.65, 0.45))
	col.add_child(heat_line)

	var price := Label.new()
	price.text = "BULLET ........ $%d" % Wallet.bullet_cost()
	price.add_theme_font_size_override("font_size", 17)
	price.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	col.add_child(price)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var choices: Array = [["TAKE IT", on_take], ["LEAVE IT", on_leave]]
	for choice in choices:
		var b := Button.new()
		b.text = choice[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(180, 52)
		b.add_theme_font_size_override("font_size", 16)
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = Color(0.10, 0.10, 0.12, 0.9)
		qsb.border_color = Color(0.92, 0.88, 0.78, 0.4)
		qsb.set_border_width_all(1)
		qsb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", qsb)
		b.pressed.connect(func() -> void:
			_close_offer()
			(choice[1] as Callable).call())
		row.add_child(b)


func _close_offer() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
	InputBus.locked = false
