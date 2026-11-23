extends CanvasLayer

## THE TOUCH UI (rebuild step 3): the on-screen controls, GENERATED
## from the control table (06_CONTROL_MAP.md). The same table that
## names the actions proves itself against the InputMap at build -
## a button whose action is missing fails loudly instead of dying.
## Layout: floating MOVE stick bottom-left, LOOK stick + the X/Y/A/B
## diamond + pills bottom-right, all inside the safe area, landscape.

const CLS_CameraRig := preload("res://scripts/player/camera_rig.gd")

## The ONE control table: letter -> action. X punch, Y heavy, A kick,
## B dodge (B's label swaps to the context verb outside combat).
const FACE := [
	["X", "punch", Vector2(-74, 0)],
	["Y", "heavy", Vector2(0, -70)],
	["A", "kick", Vector2(0, 70)],
	["B", "dodge", Vector2(74, 0)],
]
const PILLS := [
	["GUARD", "guard"], ["GRAB", "grab"], ["SPRINT", "sprint"],
	["JUMP", "jump"], ["LOCK", "lock"],
]

const STICK_R := 86.0
const BTN_R := 34.0   # the diamond buttons (68 pt targets)
const PILL_H := 44.0

var _root: Control
var _move_stick: Node2D
var _look_stick: Node2D
var _b_label: Label = null
var _move_from := Vector2.ZERO
var _move_active := false
var _look_last := Vector2.ZERO


func _ready() -> void:
	layer = 20
	name = "TouchUI"
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# the table IS the contract: every action must exist in the map
	for entry in FACE + PILLS:
		var action: String = entry[1]
		if not InputMap.has_action(action):
			push_error("TouchUI: action '%s' missing from the InputMap"
					% action)
	_build_sticks()
	_build_diamond()
	_build_pills()


# --- the sticks (floating move + fixed look) ----------------------------------


func _build_sticks() -> void:
	_move_stick = _stick("MoveStick", Color(0.55, 0.95, 1.0, 0.5))
	_look_stick = _stick("LookStick", Color(1.0, 0.3, 0.6, 0.45))
	_move_stick.position = Vector2(190, _safe_bottom() - 190)
	_look_stick.position = Vector2(_safe_right() - 330, _safe_bottom() - 170)


func _stick(id: String, tint: Color) -> Node2D:
	var n := Node2D.new()
	n.name = id
	n.set_script(null)
	_root.add_child(n)
	# the ring + the nub, drawn as simple panels
	var ring := Panel.new()
	ring.name = "Ring"
	ring.custom_minimum_size = Vector2(STICK_R * 2.0, STICK_R * 2.0)
	ring.size = Vector2(STICK_R * 2.0, STICK_R * 2.0)
	ring.position = -Vector2(STICK_R, STICK_R)
	ring.modulate = tint
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(ring, tint)
	n.add_child(ring)
	var nub := Panel.new()
	nub.name = "Nub"
	nub.custom_minimum_size = Vector2(52, 52)
	nub.size = Vector2(52, 52)
	nub.position = -Vector2(26, 26)
	nub.modulate = Color(1, 1, 1, 0.5)
	nub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(nub, Color(0.85, 0.88, 1.0, 0.4))
	n.add_child(nub)
	return n


func _style_panel(p: Panel, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.12)
	sb.set_corner_radius_all(64)
	sb.set_border_width_all(2)
	sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)


# --- the diamond + pills ------------------------------------------------------


func _build_diamond() -> void:
	var centre := Vector2(_safe_right() - 150, _safe_bottom() - 150)
	for entry in FACE:
		var letter: String = entry[0]
		var action: String = entry[1]
		var off: Vector2 = entry[2]
		var b := Button.new()
		b.name = "Face_" + letter
		b.text = letter
		b.custom_minimum_size = Vector2(BTN_R * 2.0, BTN_R * 2.0)
		b.position = centre + off - Vector2(BTN_R, BTN_R)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
		b.add_theme_color_override("font_pressed_color", Color(0, 0.94, 1.0))
		b.pressed.connect(_fire.bind(action))
		b.button_down.connect(_hold_on.bind(action))
		b.button_up.connect(_hold_off.bind(action))
		_root.add_child(b)
		if action == "dodge":
			var lbl := Label.new()
			lbl.name = "VerbLabel"
			lbl.text = "DODGE"
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color",
					Color(0.62, 0.66, 0.8))
			lbl.position = centre + off - Vector2(30, 12) \
					+ Vector2(0, BTN_R + 6)
			lbl.size = Vector2(60, 16)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_root.add_child(lbl)
			_b_label = lbl


const DRIVE_PILLS := [
	["GAS", "accelerate"], ["BRAKE", "brake"],
	["HANDBRAKE", "handbrake"], ["HORN", "horn"],
]

var _foot_pills: Array = []
var _drive_pills: Array = []


func _build_pills() -> void:
	var y := _safe_bottom() - 44.0
	_foot_pills = _pill_row(PILLS, _safe_right() - 150.0 - 250.0, y)
	_drive_pills = _pill_row(DRIVE_PILLS, _safe_right() - 150.0 - 250.0, y)
	for b in _drive_pills:
		b.visible = false


func _pill_row(entries: Array, x: float, y: float) -> Array:
	var out: Array = []
	for entry in entries:
		var label: String = entry[0]
		var action: String = entry[1]
		var b := Button.new()
		b.name = "Pill_" + label
		b.text = label
		b.custom_minimum_size = Vector2(84, PILL_H)
		b.position = Vector2(x, y)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_fire.bind(action))
		b.button_down.connect(_hold_on.bind(action))
		b.button_up.connect(_hold_off.bind(action))
		_root.add_child(b)
		out.append(b)
		x += 92.0
	return out


## The driving control swap: on foot pills vs GAS/BRAKE/HANDBRAKE/
## HORN (06_CONTROL_MAP's driving table).
func set_driving(on: bool) -> void:
	for b in _foot_pills:
		if is_instance_valid(b):
			b.visible = not on
	for b in _drive_pills:
		if is_instance_valid(b):
			b.visible = on


# --- input plumbing -----------------------------------------------------------


## Fire-and-forget actions (punch/heavy/kick/dodge/...) press+release.
func _fire(action: String) -> void:
	Input.action_press(action)
	Input.action_release(action)


## Hold actions (guard/grab/sprint/lock) press on down, release on up.
func _hold_on(action: String) -> void:
	Input.action_press(action)


func _hold_off(action: String) -> void:
	Input.action_release(action)


## The context verb on B's label ("" resets to DODGE).
func set_context_verb(verb: String) -> void:
	if _b_label:
		_b_label.text = verb if verb != "" else "DODGE"


## Multi-touch: the sticks claim their pointer; buttons are Controls
## and take care of themselves. Screen drags feed the sticks.
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var p: Vector2 = ev.position
			if _hit(_move_stick, p, STICK_R + 40.0):
				_move_active = true
				_move_from = p
			elif _hit(_look_stick, p, STICK_R + 40.0):
				_look_last = p
		else:
			_move_active = false
			_stick_nub(_move_stick, Vector2.ZERO)
			var hero := get_tree().get_first_node_in_group("player") as Node
			if hero:
				hero.set("move_stick", Vector2.ZERO)
			_look_last = Vector2.ZERO
	elif ev is InputEventScreenDrag:
		var p: Vector2 = ev.position
		if _move_active:
			var v := (p - _move_from).limit_length(STICK_R) / STICK_R
			_stick_nub(_move_stick, v * STICK_R)
			var hero := get_tree().get_first_node_in_group("player") as Node
			if hero:
				hero.set("move_stick", v)
		elif _look_last != Vector2.ZERO and _hit(_look_stick, p, STICK_R + 70.0):
			var d := p - _look_last
			_look_last = p
			_stick_nub(_look_stick, d.limit_length(STICK_R))
			var rig := get_tree().get_first_node_in_group("camera_rig") as CLS_CameraRig
			if rig:
				rig.add_look(d.x, d.y)


func _hit(stick: Node2D, p: Vector2, radius: float) -> bool:
	return stick != null and stick.position.distance_to(p) < radius


func _stick_nub(stick: Node2D, offset: Vector2) -> void:
	var nub := stick.get_node_or_null("Nub") as Control
	if nub:
		nub.position = -Vector2(26, 26) + offset


func _safe_bottom() -> float:
	var r := _root.get_viewport_rect()
	return r.size.y - 24.0


func _safe_right() -> float:
	var r := _root.get_viewport_rect()
	return r.size.x - 24.0
