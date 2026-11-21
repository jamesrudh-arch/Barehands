extends CanvasLayer
const CLS_SettingsUI := preload("res://scripts/settings_ui.gd")
## PAUSE button + the pause menu: resume, and the Quality override
## (Auto / Low / High). Built in code; layer 15 sits over the HUD.

var _panel: PanelContainer
var _fps_line: Label
var _quality_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	add_to_group("pause")
	_build_pause_button()
	_build_panel()
	get_tree().paused = false


func _build_pause_button() -> void:
	var btn := Button.new()
	btn.text = "II"
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = 0.0
	btn.anchor_top = 0.0
	btn.position = Vector2(84, 10)
	btn.custom_minimum_size = Vector2(52, 34)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.35)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.pressed.connect(_toggle)
	add_child(btn)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -150.0
	_panel.offset_right = 150.0
	_panel.offset_top = -170.0
	_panel.offset_bottom = 330.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(title)

	_fps_line = Label.new()
	_fps_line.add_theme_font_size_override("font_size", 13)
	_fps_line.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.8))
	col.add_child(_fps_line)

	_quality_label = Label.new()
	_quality_label.add_theme_font_size_override("font_size", 14)
	_quality_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 0.9))
	col.add_child(_quality_label)

	for mode in ["Auto", "Low", "High"]:
		var b := Button.new()
		b.text = "Quality: %s" % mode
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 54)
		b.add_theme_font_size_override("font_size", 16)
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
		qsb.border_color = Color(1, 0.58, 0.13, 0.35)
		qsb.set_border_width_all(1)
		qsb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", qsb)
		var mode_name: String = mode
		b.pressed.connect(func() -> void:
			Quality.set_override(mode_name)
			_refresh_quality())
		col.add_child(b)

	for bus_name in ["Master", "Music", "SFX", "Ambience", "Voice"]:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = bus_name
		lbl.custom_minimum_size = Vector2(92, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = Sound.get_bus_vol(bus_name)
		sl.custom_minimum_size = Vector2(140, 32)
		sl.focus_mode = Control.FOCUS_NONE
		var bn: String = bus_name
		sl.value_changed.connect(func(v: float) -> void: Sound.set_bus_vol(bn, v))
		row.add_child(lbl)
		row.add_child(sl)
		col.add_child(row)

	var ledger := Button.new()
	ledger.text = "LEDGER  (B)"
	ledger.focus_mode = Control.FOCUS_NONE
	ledger.custom_minimum_size = Vector2(240, 54)
	ledger.add_theme_font_size_override("font_size", 16)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.10, 0.09, 0.06, 0.8)
	lsb.border_color = Color(0.92, 0.88, 0.78, 0.4)
	lsb.set_border_width_all(1)
	lsb.set_corner_radius_all(8)
	ledger.add_theme_stylebox_override("normal", lsb)
	ledger.pressed.connect(func() -> void:
		var ui := get_tree().get_first_node_in_group("ledger")
		if ui:
			ui.toggle())
	col.add_child(ledger)

	var moves := Button.new()
	moves.text = "MOVES"
	moves.focus_mode = Control.FOCUS_NONE
	moves.custom_minimum_size = Vector2(240, 54)
	moves.add_theme_font_size_override("font_size", 16)
	moves.add_theme_stylebox_override("normal", _flat())
	moves.pressed.connect(_open_moves)
	col.add_child(moves)

	var settings := Button.new()
	settings.text = "SETTINGS"
	settings.focus_mode = Control.FOCUS_NONE
	settings.custom_minimum_size = Vector2(240, 54)
	settings.add_theme_font_size_override("font_size", 16)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
	tsb.border_color = Color(1, 0.58, 0.13, 0.35)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(8)
	settings.add_theme_stylebox_override("normal", tsb)
	settings.pressed.connect(_open_settings)
	col.add_child(settings)

	var resume := Button.new()
	resume.text = "RESUME"
	resume.focus_mode = Control.FOCUS_NONE
	resume.custom_minimum_size = Vector2(240, 54)
	resume.add_theme_font_size_override("font_size", 17)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(1, 0.58, 0.13, 0.55)
	rsb.set_corner_radius_all(8)
	resume.add_theme_stylebox_override("normal", rsb)
	resume.pressed.connect(_toggle)
	col.add_child(resume)


func _flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
	sb.border_color = Color(1, 0.58, 0.13, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb


func _open_moves() -> void:
	_panel.visible = false
	var m := get_tree().get_first_node_in_group("moves")
	if m:
		m.open()


func _open_settings() -> void:
	_panel.visible = false
	var s := get_tree().get_first_node_in_group("settings_ui") as CLS_SettingsUI
	if s:
		s.open()


## Menus call this when they take over without unpausing.
func hide_menu() -> void:
	_panel.visible = false


## SettingsUI calls this on DONE: bring the pause panel back.
func show_menu() -> void:
	if get_tree().paused:
		_panel.visible = true
		_refresh_quality()


func _toggle() -> void:
	get_tree().paused = not get_tree().paused
	_panel.visible = get_tree().paused
	if _panel.visible:
		_refresh_quality()


func _refresh_quality() -> void:
	_quality_label.text = "Tier: %s  (override: %s)" % [Quality.tier, Quality.override]


func _process(_delta: float) -> void:
	if _panel.visible and _fps_line:
		_fps_line.text = "%d fps" % Engine.get_frames_per_second()
