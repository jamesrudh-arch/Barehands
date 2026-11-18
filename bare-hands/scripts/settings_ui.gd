class_name SettingsUI
extends CanvasLayer
## The SETTINGS screen (Stage A2), opened from the pause menu. Everything the
## player can tune about controls lives here: movement scheme, stick feel,
## camera drag, auto-sprint, 8-way snap, HUD opacity, haptics, layout
## presets (Classic / Compact / Left-handed) and a visual layout editor.
## Built in code; layer 16 sits above the pause menu. The tree stays paused
## while open (the pause menu owns the pause).

const SCHEMES := [
	["floating", "Floating stick", "The pad appears wherever your left thumb lands."],
	["fixed", "Fixed stick", "A pad pinned to the bottom-left corner."],
	["dpad", "D-pad", "8-direction pad around where your thumb lands."],
	["drag", "Drag to move", "Swipe from anywhere on the left; direction is movement."],
]

const BUTTON_NAMES := ["JumpBtn", "SprintBtn", "PunchBtn", "DodgeBtn", "GrabBtn", "LockBtn"]

var _panel: PanelContainer
var _scroll: ScrollContainer
var _editing := false
var _selected := "PunchBtn"


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	visible = true


func _close() -> void:
	visible = false
	if _editing:
		_end_layout_edit()
	# back to the pause menu
	var pause := get_tree().get_first_node_in_group("pause") as PauseMenu
	if pause:
		pause.show_menu()


# --- the screen -----------------------------------------------------------------


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = -190.0
	_panel.offset_bottom = 190.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	_scroll.add_child(col)

	_title(col, "SETTINGS")
	_scheme_picker(col)
	_slider(col, "Sensitivity", "sensitivity", 0.4, 2.0, 0.05)
	_slider(col, "Dead zone", "deadzone", 0.05, 0.35, 0.01)
	_slider(col, "Response curve", "curve", 1.0, 3.0, 0.1)
	_slider(col, "Smoothing", "smoothing", 0.0, 0.2, 0.01)
	_slider(col, "Stick size", "stick_scale", 0.7, 1.5, 0.05)
	_toggle(col, "Drag right side to turn camera", "cam_drag")
	_slider(col, "Camera speed", "cam_speed", 0.4, 2.0, 0.05)
	_toggle(col, "Auto-sprint at stick edge", "auto_sprint")
	_toggle(col, "Snap movement to 8 directions", "snap8")
	_slider(col, "HUD opacity", "opacity", 0.3, 1.0, 0.05)
	_toggle(col, "Haptics", "haptics_on")
	_slider(col, "Haptic strength", "haptic_str", 0.0, 1.0, 0.05)
	_layout_section(col)

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


func _title(col: BoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(l)


func _scheme_picker(col: BoxContainer) -> void:
	_title(col, "MOVEMENT")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for spec in SCHEMES:
		var id: String = spec[0]
		var b := Button.new()
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(210, 64)
		b.tooltip_text = spec[2]
		b.add_theme_font_size_override("font_size", 15)
		_style(b)
		b.pressed.connect(func() -> void:
			Settings.set_value("scheme", id)
			_refresh())
		b.name = "Scheme_" + id
		grid.add_child(b)
	_refresh()


func _refresh() -> void:
	var scheme := str(Settings.value("scheme"))
	for b in _scroll.find_children("Scheme_*", "Button", true, false):
		var on := b.name == "Scheme_" + scheme
		(b as Button).modulate = Color(1.4, 1.15, 0.8) if on else Color.WHITE


func _slider(col: BoxContainer, label: String, key: String, mn: float, mx: float,
		step: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 14)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.value = float(Settings.value(key))
	sl.custom_minimum_size = Vector2(180, 36)
	sl.focus_mode = Control.FOCUS_NONE
	var val := Label.new()
	val.text = "%.2f" % sl.value
	val.custom_minimum_size = Vector2(52, 0)
	val.add_theme_font_size_override("font_size", 13)
	sl.value_changed.connect(func(v: float) -> void:
		val.text = "%.2f" % v
		Settings.set_value(key, v))
	row.add_child(l)
	row.add_child(sl)
	row.add_child(val)
	col.add_child(row)


func _toggle(col: BoxContainer, label: String, key: String) -> void:
	var b := Button.new()
	b.text = "%s: %s" % [label, "ON" if bool(Settings.value(key)) else "OFF"]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 44)
	b.add_theme_font_size_override("font_size", 14)
	_style(b)
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not bool(Settings.value(key)))
		b.text = "%s: %s" % [label, "ON" if bool(Settings.value(key)) else "OFF"])
	col.add_child(b)


func _style(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
	sb.border_color = Color(1, 0.58, 0.13, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)


# --- layout presets + editor ------------------------------------------------------


func _layout_section(col: BoxContainer) -> void:
	_title(col, "BUTTON LAYOUT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for preset in ["classic", "compact", "left"]:
		var b := Button.new()
		b.text = {"classic": "Classic", "compact": "Compact", "left": "Left-handed"}[preset]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 48)
		b.add_theme_font_size_override("font_size", 14)
		_style(b)
		var p: String = preset
		b.pressed.connect(func() -> void: _apply_preset(p))
		row.add_child(b)
	var edit := Button.new()
	edit.text = "EDIT LAYOUT"
	edit.focus_mode = Control.FOCUS_NONE
	edit.custom_minimum_size = Vector2(380, 48)
	edit.add_theme_font_size_override("font_size", 14)
	_style(edit)
	edit.pressed.connect(_start_layout_edit)
	col.add_child(edit)
	var note := Label.new()
	note.text = "Editor: drag buttons anywhere, tap to select,\nthen resize and set opacity. Pull right to reset."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.7))
	col.add_child(note)


func _apply_preset(id: String) -> void:
	Settings.set_value("preset", id)
	var layout := {}
	match id:
		"compact":
			for n in BUTTON_NAMES:
				layout[n] = {"dx": 34.0, "dy": 30.0, "scale": 0.85, "opacity": 1.0}
		"left":
			# mirror the cluster to the bottom-left, stick zone flips right
			layout = {
				"PunchBtn": {"dx": -300.0, "dy": 120.0, "scale": 1.0, "opacity": 1.0},
				"DodgeBtn": {"dx": -170.0, "dy": 120.0, "scale": 1.0, "opacity": 1.0},
				"JumpBtn": {"dx": -300.0, "dy": -20.0, "scale": 1.0, "opacity": 1.0},
				"SprintBtn": {"dx": -170.0, "dy": -20.0, "scale": 1.0, "opacity": 1.0},
				"GrabBtn": {"dx": -300.0, "dy": -150.0, "scale": 1.0, "opacity": 1.0},
				"LockBtn": {"dx": -560.0, "dy": 0.0, "scale": 1.0, "opacity": 1.0},
			}
			Settings.set_value("left_handed", true)
	Settings.set_value("layout", layout)
	if id != "left":
		Settings.set_value("left_handed", false)
	Settings.changed.emit("layout")


func _start_layout_edit() -> void:
	_editing = true
	visible = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("begin_layout_edit"):
		hud.begin_layout_edit()
	get_tree().paused = true


func _end_layout_edit() -> void:
	_editing = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("end_layout_edit"):
		hud.end_layout_edit()
