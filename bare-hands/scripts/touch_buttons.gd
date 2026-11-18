class_name TouchButtons
extends CanvasLayer
## The action side of the HUD (Stage A2/A3). Builds its own buttons in code
## (ActionButton - touch-DOWN triggers, oversized hit areas, press
## animations, a soft tick, per-action haptics, cooldown rings), applies the
## player's layout (presets, the editor, opacity) and keeps the one-time
## hint label. Also feeds the debug panel's latency numbers.

const BUTTON_SPECS := [
	# name, label, colour, dx, dy (from the bottom-right corner, px)
	["PunchBtn", "PUNCH", Color(1.0, 0.45, 0.35, 0.95), 152.0, 152.0],
	["DodgeBtn", "DODGE", Color(0.85, 0.9, 1.0, 0.95), 284.0, 152.0],
	["JumpBtn", "JUMP", Color(1.0, 0.78, 0.45, 0.95), 152.0, 300.0],
	["SprintBtn", "SPRINT", Color(0.55, 0.95, 1.0, 0.95), 284.0, 300.0],
	["GrabBtn", "GRAB", Color(0.75, 1.0, 0.6, 0.95), 284.0, 420.0],
	["LockBtn", "LOCK", Color(0.8, 0.8, 0.85, 0.9), 416.0, 300.0],
	["SuperBtn", "SUPER", Color(1.0, 0.62, 0.2, 1.0), 152.0, 428.0],
]

var hint_shown := false
var _hint_fade := 0.0
var _buttons: Dictionary = {}  # name -> ActionButton
var _default_rects: Dictionary = {}  # name -> Rect2 before any layout
var _editing := false
var _edit_sel := ""
var _edit_drag := false
var _edit_last := Vector2.ZERO
var _toolbar: PanelContainer
var _hint: Label


func _ready() -> void:
	_build_buttons()
	_build_hint()
	_apply_layout()
	Settings.changed.connect(_on_setting)
	SuperMeter.changed.connect(_on_super_meter)
	_on_super_meter(SuperMeter.value)


func _on_super_meter(value: float) -> void:
	var b := _buttons.get("SuperBtn") as ActionButton
	if b:
		b.charged = SuperMeter.is_full()
		# the ring shows the FILL (drains as the meter grows)
		b.cooldown = 1.0 - SuperMeter.frac()


# --- buttons ---------------------------------------------------------------------


func _build_buttons() -> void:
	for spec in BUTTON_SPECS:
		var name: String = spec[0]
		var b := ActionButton.new()
		b.name = name
		b.label = spec[1]
		b.tint = spec[2]
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.size = Vector2(116, 116)
		b.position = Vector2(-spec[3] - 116.0, -spec[4] - 116.0)
		b.down.connect(_on_down.bind(name))
		b.up.connect(_on_up.bind(name))
		add_child(b)
		_buttons[name] = b
		_default_rects[name] = Rect2(b.position, b.size)


func _on_down(name: String) -> void:
	if _editing:
		return
	Sound.play("ui_click_0", -12.0, 1.0, 0.03)
	Haptics.fire("ui")
	match name:
		"JumpBtn":
			InputBus.queue_jump()
		"SprintBtn":
			InputBus.press_sprint()
		"PunchBtn":
			InputBus.stamp_action("punch_down")
			InputBus.punch_press()
		"DodgeBtn":
			InputBus.stamp_action("dodge_down")
			InputBus.dodge_press()
		"GrabBtn":
			InputBus.queue_grab()
		"LockBtn":
			_toggle_lock()
		"SuperBtn":
			InputBus.queue_super()


func _on_up(name: String) -> void:
	if _editing:
		return
	match name:
		"SprintBtn":
			InputBus.release_sprint()
		"PunchBtn":
			InputBus.punch_release()
		"DodgeBtn":
			InputBus.dodge_release()


func _toggle_lock() -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.toggle_lock()


# --- per-frame state: cooldown rings, charged glow ---------------------------------


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var p := player as CharacterBody3D
		_set_ring("PunchBtn", p.punch_cooldown_01())
		_set_ring("DodgeBtn", p.dodge_cooldown_01())
	if _hint_fade > 0.0:
		_hint_fade -= delta
		if _hint_fade <= 0.0:
			_hint.visible = false
		elif _hint_fade < 0.5:
			_hint.modulate.a = _hint_fade / 0.5


func _set_ring(name: String, cd: float) -> void:
	var b := _buttons.get(name) as ActionButton
	if b:
		b.cooldown = cd


## The SUPER button lights up when the meter is full (Stage A4 wires this).
func set_super_charged(on: bool) -> void:
	var b := _buttons.get("SuperBtn") as ActionButton
	if b:
		b.charged = on


# --- layout: presets, editor overrides, opacity ------------------------------------


func _on_setting(key: String) -> void:
	if key == "layout" or key == "left_handed" or key == "opacity":
		_apply_layout()


func _apply_layout() -> void:
	var opacity: float = float(Settings.value("opacity"))
	for name in _buttons:
		var b := _buttons[name] as ActionButton
		var def: Rect2 = _default_rects[name]
		var over: Dictionary = Settings.layout_for(name)
		b.position = def.position + Vector2(float(over.get("dx", 0.0)), float(over.get("dy", 0.0)))
		b.size = def.size * float(over.get("scale", 1.0))
		b.modulate = Color(1, 1, 1, opacity * float(over.get("opacity", 1.0)))


# --- the layout editor ---------------------------------------------------------------


func begin_layout_edit() -> void:
	_editing = true
	_edit_sel = ""
	for name in _buttons:
		(_buttons[name] as ActionButton).editable = true
	_build_toolbar()


func end_layout_edit() -> void:
	_editing = false
	for name in _buttons:
		(_buttons[name] as ActionButton).editable = false
	if _toolbar:
		_toolbar.queue_free()
		_toolbar = null
	_apply_layout()


func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.anchor_left = 0.5
	_toolbar.anchor_right = 0.5
	_toolbar.anchor_top = 0.0
	_toolbar.anchor_bottom = 0.0
	_toolbar.offset_left = -230.0
	_toolbar.offset_right = 230.0
	_toolbar.offset_top = 12.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_toolbar.add_theme_stylebox_override("panel", sb)
	add_child(_toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_toolbar.add_child(row)

	var sel := Label.new()
	sel.name = "SelLabel"
	sel.text = "none"
	sel.custom_minimum_size = Vector2(90, 0)
	sel.add_theme_font_size_override("font_size", 13)
	row.add_child(sel)
	_edit_btn(row, "  -  ", func() -> void: _nudge_scale(-0.08))
	_edit_btn(row, "  +  ", func() -> void: _nudge_scale(0.08))
	var sl := HSlider.new()
	sl.min_value = 0.3
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size = Vector2(110, 32)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void: _set_opacity(v))
	row.add_child(sl)
	_edit_btn(row, "DONE", func() -> void:
		end_layout_edit()
		var s := get_tree().get_first_node_in_group("settings_ui") as SettingsUI
		if s:
			s.open())
	var lbl := Label.new()
	lbl.text = "drag a button; tap to select"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.7))
	row.add_child(lbl)


func _edit_btn(row: BoxContainer, text: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 40)
	b.pressed.connect(fn)
	row.add_child(b)


func _input(event: InputEvent) -> void:
	if not _editing:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_edit_sel = _button_at(event.position)
			_edit_drag = _edit_sel != ""
			_edit_last = event.position
			_update_sel_label()
		elif _edit_drag and _edit_sel != "":
			_save_override(_edit_sel)
			_edit_drag = false
	elif event is InputEventScreenDrag and _edit_drag and _edit_sel != "":
		var b := _buttons[_edit_sel] as ActionButton
		b.position += event.position - _edit_last
		_edit_last = event.position


func _button_at(pos: Vector2) -> String:
	for name in _buttons:
		var b := _buttons[name] as ActionButton
		if Rect2(b.position, b.size).has_point(pos):
			return name
	return ""


func _update_sel_label() -> void:
	if _toolbar:
		var l := _toolbar.find_children("SelLabel", "Label", true, false)
		if l.size() > 0:
			(l[0] as Label).text = _edit_sel if _edit_sel != "" else "none"


func _nudge_scale(d: float) -> void:
	if _edit_sel == "":
		return
	var over := Settings.layout_for(_edit_sel)
	over["scale"] = clampf(float(over.get("scale", 1.0)) + d, 0.6, 1.6)
	Settings.set_layout_for(_edit_sel, over)
	_apply_layout()


func _set_opacity(v: float) -> void:
	if _edit_sel == "":
		return
	var over := Settings.layout_for(_edit_sel)
	over["opacity"] = v
	Settings.set_layout_for(_edit_sel, over)
	_apply_layout()


func _save_override(name: String) -> void:
	var b := _buttons[name] as ActionButton
	var def: Rect2 = _default_rects[name]
	var over := Settings.layout_for(name)
	over["dx"] = b.position.x - def.position.x
	over["dy"] = b.position.y - def.position.y
	Settings.set_layout_for(name, over)


# --- hints ---------------------------------------------------------------------------


## Called by the hero the first time the player stands near a climbable edge.
func show_hint(text: String, dur := 2.8) -> void:
	hint_shown = true
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint.visible = true
	_hint_fade = dur


func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.visible = false
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -260.0
	_hint.offset_right = 260.0
	_hint.offset_top = -96.0
	_hint.offset_bottom = -64.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 0.9))
	add_child(_hint)
