class_name TouchButtons
extends CanvasLayer
## The action side of the HUD (Stage A + combo pass). Two button schemes
## the player chooses in Settings and the first-run picker:
##   face    - the console diamond: A light punch, B heavy punch, X kick,
##             Y grab/throw, with smaller JUMP / DODGE / SPRINT / LOCK
##             beside it. The SUPER button only appears when the meter is
##             full.
##   classic - PUNCH (tap light / hold heavy), DODGE/BLOCK, JUMP, SPRINT,
##             GRAB, LOCK, SUPER with its fill ring.
## Both keep touch-DOWN firing, oversized hit areas, press animation, the
## ui tick, haptics, cooldown rings, the layout editor and left-handed
## mode. Buttons are rebuilt on scheme change; layouts are per-button so
## each scheme remembers its own arrangement.

const CLASSIC_SPECS := [
	# name, label, sub, colour, dx, dy, size
	["PunchBtn", "PUNCH", "", Color(1.0, 0.45, 0.35, 0.95), 152.0, 152.0, 116.0],
	["DodgeBtn", "DODGE", "", Color(0.85, 0.9, 1.0, 0.95), 284.0, 152.0, 116.0],
	["JumpBtn", "JUMP", "", Color(1.0, 0.78, 0.45, 0.95), 152.0, 300.0, 116.0],
	["SprintBtn", "SPRINT", "", Color(0.55, 0.95, 1.0, 0.95), 284.0, 300.0, 116.0],
	["GrabBtn", "GRAB", "", Color(0.75, 1.0, 0.6, 0.95), 284.0, 420.0, 116.0],
	["LockBtn", "LOCK", "", Color(0.8, 0.8, 0.85, 0.9), 416.0, 300.0, 86.0],
	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 152.0, 428.0, 116.0],
	["StyleBtn", "STYLE", "", Color(0.9, 0.7, 0.4, 0.9), 416.0, 428.0, 86.0],
]

const FACE_SPECS := [
	# the diamond: A bottom, B right, X left, Y top
	["FaceA", "A", "LIGHT", Color(1.0, 0.82, 0.6, 0.95), 214.0, 84.0, 108.0],
	["FaceB", "B", "HEAVY", Color(1.0, 0.42, 0.34, 0.95), 106.0, 190.0, 108.0],
	["FaceX", "X", "KICK", Color(0.45, 0.92, 1.0, 0.95), 322.0, 190.0, 108.0],
	["FaceY", "Y", "GRAB", Color(0.72, 1.0, 0.62, 0.95), 214.0, 296.0, 108.0],
	["JumpBtn", "JUMP", "", Color(1.0, 0.78, 0.45, 0.95), 452.0, 148.0, 84.0],
	["DodgeBtn", "DODGE", "", Color(0.85, 0.9, 1.0, 0.95), 452.0, 248.0, 84.0],
	["SprintBtn", "SPRINT", "", Color(0.55, 0.95, 1.0, 0.95), 452.0, 348.0, 84.0],
	["LockBtn", "LOCK", "", Color(0.8, 0.8, 0.85, 0.9), 322.0, 330.0, 74.0],
	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), 106.0, 330.0, 96.0],
	["StyleBtn", "STYLE", "", Color(0.9, 0.7, 0.4, 0.9), 452.0, 448.0, 74.0],
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
var _vp: Vector2


func _ready() -> void:
	add_to_group("hud_buttons")
	_vp = get_viewport().size
	_build_buttons()
	_build_hint()
	_apply_layout()
	Settings.changed.connect(_on_setting)
	SuperMeter.changed.connect(_on_super_meter)
	_on_super_meter(SuperMeter.value)


func _scheme() -> String:
	return "face" if str(Settings.value("button_scheme")) == "face" else "classic"


func _specs() -> Array:
	return FACE_SPECS if _scheme() == "face" else CLASSIC_SPECS


func _on_setting(key: String) -> void:
	if key == "button_scheme":
		_build_buttons()
		_apply_layout()
	elif key == "button_scale":
		# rebuilt rects (the default positions carry the size); the
		# stored mirror offsets were computed against the old rects, so
		# a left-handed layout re-mirrors after the rebuild
		_build_buttons()
		if Settings.value("left_handed"):
			apply_preset("left")
		_apply_layout()
	elif key == "layout" or key == "left_handed" or key == "opacity":
		_apply_layout()


# --- buttons ---------------------------------------------------------------------


func _build_buttons() -> void:
	for name in _buttons:
		(_buttons[name] as ActionButton).queue_free()
	_buttons.clear()
	_default_rects.clear()
	for spec in _specs():
		var name: String = spec[0]
		var b := ActionButton.new()
		b.name = name
		b.label = spec[1]
		b.sub = spec[2]
		b.tint = spec[3]
		# accessibility (bible 7): button size on top of presets and
		# the editor's per-button scale
		var sz: float = spec[6] * clampf(float(Settings.value("button_scale")), 0.6, 1.6)
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.size = Vector2(sz, sz)
		b.position = Vector2(-spec[4] - sz, -spec[5] - sz)
		b.down.connect(_on_down.bind(name))
		b.up.connect(_on_up.bind(name))
		add_child(b)
		_buttons[name] = b
		_default_rects[name] = Rect2(b.position, b.size)
	_apply_super_visibility()


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
			InputBus.press_face("A")
		"DodgeBtn":
			InputBus.stamp_action("dodge_down")
			InputBus.dodge_press()
		"GrabBtn", "FaceY":
			InputBus.queue_grab()
			InputBus.press_face("Y")
		"LockBtn":
			_toggle_lock()
		"SuperBtn":
			InputBus.queue_super()
		"StyleBtn":
			_open_wheel()
		"FaceA":
			InputBus.stamp_action("punch_down")
			InputBus.queue_punch()
			InputBus.press_face("A")
		"FaceB":
			InputBus.stamp_action("punch_down")
			InputBus.queue_heavy()
			InputBus.press_face("B")
		"FaceX":
			InputBus.queue_kick()
			InputBus.press_face("X")


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


## The style wheel (Batch 3): one shared instance, code-built.
func _open_wheel() -> void:
	var w := get_tree().root.get_node_or_null("StyleWheel") as StyleWheel
	if w == null:
		w = StyleWheel.new()
		w.name = "StyleWheel"
		get_tree().root.add_child.call_deferred(w)
		await get_tree().process_frame
	if w:
		w.open()


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
		_set_ring("FaceA", p.punch_cooldown_01())
		_set_ring("FaceB", p.punch_cooldown_01())
		_set_ring("FaceX", p.punch_cooldown_01())
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


func _on_super_meter(value: float) -> void:
	var b := _buttons.get("SuperBtn") as ActionButton
	if b == null:
		return
	b.charged = SuperMeter.is_full()
	# the ring shows the FILL (drains as the meter grows)
	b.cooldown = 1.0 - SuperMeter.frac()
	_apply_super_visibility()


## Face scheme: the SUPER button only exists on screen while the meter is
## full; Classic keeps it visible with its fill ring.
func _apply_super_visibility() -> void:
	var b := _buttons.get("SuperBtn") as ActionButton
	if b:
		b.visible = _scheme() == "classic" or SuperMeter.is_full()


# --- layout: presets, editor overrides, opacity ------------------------------------


func _apply_layout() -> void:
	var opacity: float = float(Settings.value("opacity"))
	for name in _buttons:
		var b := _buttons[name] as ActionButton
		var def: Rect2 = _default_rects[name]
		var over: Dictionary = Settings.layout_for(name)
		b.position = def.position + Vector2(float(over.get("dx", 0.0)), float(over.get("dy", 0.0)))
		b.size = def.size * float(over.get("scale", 1.0))
		b.modulate = Color(1, 1, 1, opacity * float(over.get("opacity", 1.0)))
	_apply_super_visibility()


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


## Presets are generic over whichever buttons exist (both schemes).
func apply_preset(id: String) -> void:
	Settings.set_value("preset", id)
	var layout := {}
	match id:
		"compact":
			for name in _buttons:
				layout[name] = {"dx": 34.0, "dy": 30.0, "scale": 0.85, "opacity": 1.0}
		"left":
			# mirror every button horizontally around the screen centre
			for name in _buttons:
				var def: Rect2 = _default_rects[name]
				var cx := def.position.x + def.size.x * 0.5
				layout[name] = {"dx": _vp.x - 2.0 * cx, "dy": 0.0, "scale": 1.0, "opacity": 1.0}
	Settings.set_value("layout", layout)
	Settings.set_value("left_handed", id == "left")
	Settings.changed.emit("layout")


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
