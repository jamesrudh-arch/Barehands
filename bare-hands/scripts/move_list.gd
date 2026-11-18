class_name MoveListUI
extends CanvasLayer
## The MOVES screen (Stage A4), opened from the pause menu: the full move
## list for fists, the pipe and the SUPER meter, from scripts/moves.gd.

var _panel: PanelContainer


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	visible = true


func _close() -> void:
	visible = false
	var pause := get_tree().get_first_node_in_group("pause") as PauseMenu
	if pause:
		pause.show_menu()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -250.0
	_panel.offset_right = 250.0
	_panel.offset_top = -200.0
	_panel.offset_bottom = 200.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_section(col, "BARE FISTS", Moves.FISTS)
	_section(col, "WITH THE PIPE", Moves.PIPE)
	_section(col, "METER AND DEFENCE", Moves.SUPER)

	var done := Button.new()
	done.text = "DONE"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(200, 50)
	done.add_theme_font_size_override("font_size", 17)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 0.58, 0.13, 0.55)
	dsb.set_corner_radius_all(8)
	done.add_theme_stylebox_override("normal", dsb)
	done.pressed.connect(_close)
	col.add_child(done)


func _section(col: BoxContainer, title: String, rows: Array) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(t)
	for row in rows:
		var name_l := Label.new()
		name_l.text = "  " + row[0]
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 0.95))
		col.add_child(name_l)
		var how := Label.new()
		how.text = "      input: " + row[1]
		how.add_theme_font_size_override("font_size", 12)
		how.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.9))
		col.add_child(how)
		var desc := Label.new()
		desc.text = "      " + row[2]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.75))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(440, 0)
		col.add_child(desc)
