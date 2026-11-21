extends CanvasLayer

## The Bullet Ledger: every purchase and every shot, printed like a thermal
## receipt. Opened from the pause menu or with the B key. Paper panel,
## monospace columns, dashed rules, zig-zag tear edge at the bottom.


var _rows: VBoxContainer


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ledger"):
		toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()
		Sound.play("ui_bong_0", -6.0)


func _refresh() -> void:
	if _rows == null:
		return
	for c in _rows.get_children():
		c.queue_free()

	_head(_rows, "CINDER CITY AMMUNITION")
	_rule(_rows)
	_line(_rows, "NO ONE IS BORN WITH A GUN", true)
	_rule(_rows)

	if Wallet.entries.is_empty():
		_line(_rows, "nothing on the books", true)
	for e in Wallet.entries:
		var amt: int = e.amount
		var item: String = e.item
		if item.length() > 14:
			item = item.substr(0, 14)
		_line(_rows, "%s %s %s %s$%d" % [
				e.time, String(e.kind).rpad(9), item.rpad(14),
				"+" if amt > 0 else "-", absi(amt)])
	_rule(_rows)
	_line(_rows, "BALANCE                    $%d" % Wallet.cash, true)
	_line(_rows, "BULLET PRICE               $%d" % Wallet.bullet_cost())
	_rule(_rows)
	_line(_rows, "THANK YOU. NO REFUNDS.", true)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var paper := PanelContainer.new()
	paper.name = "Paper"
	paper.anchor_left = 0.5
	paper.anchor_right = 0.5
	paper.anchor_top = 0.5
	paper.anchor_bottom = 0.5
	paper.offset_left = -240.0
	paper.offset_right = 240.0
	paper.offset_top = -270.0
	paper.offset_bottom = 250.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.92, 0.86)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 4.0
	paper.add_theme_stylebox_override("panel", sb)
	add_child(paper)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	paper.add_child(col)

	var title := Label.new()
	title.text = "THE BULLET LEDGER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.15, 0.13, 0.10))
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(440, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	_rows = rows

	var hint := Label.new()
	hint.text = "B or the button to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.37, 0.32))
	col.add_child(hint)


func _line(parent: Node, text: String, center := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _rule(parent: Node) -> void:
	_line(parent, "- - - - - - - - - - - - - - - - - - -", true)


func _head(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
	parent.add_child(l)
