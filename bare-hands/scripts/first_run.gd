class_name FirstRun
extends CanvasLayer
## The first-run control picker (Stage A2): the very first time the game
## opens, four big cards explain the movement schemes; picking one starts
## the game. Shows once (Settings.first_run_done).

const CHOICES := [
	["floating", "FLOATING STICK", "Touch anywhere on the left - the stick appears under your thumb."],
	["fixed", "FIXED STICK", "A classic joystick pinned to the bottom-left corner."],
	["dpad", "D-PAD", "Eight directions around wherever your thumb lands."],
	["drag", "DRAG TO MOVE", "Swipe from anywhere on the left. Direction and length steer you."],
]


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	if bool(Settings.value("first_run_done")):
		queue_free()
		return
	InputBus.locked = true
	_build()


func _pick_buttons(id: String) -> void:
	Settings.set_value("button_scheme", id)
	Sound.play("ui_confirm_0", -8.0)
	Haptics.fire("ui")


func _process(_delta: float) -> void:
	# stay locked even if the opening cinematic unlocks underneath us
	if not bool(Settings.value("first_run_done")):
		InputBus.locked = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -300.0
	col.offset_right = 300.0
	col.offset_top = -180.0
	col.offset_bottom = 180.0
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var title := Label.new()
	title.text = "HOW DO YOU WANT TO MOVE?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(title)

	var sub := Label.new()
	sub.text = "You can change this any time in Settings."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.8))
	col.add_child(sub)

	for choice in CHOICES:
		var b := Button.new()
		b.name = "Move_" + choice[0]
		b.text = choice[1]
		b.tooltip_text = choice[2]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(600, 74)
		b.add_theme_font_size_override("font_size", 18)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		sb.border_color = Color(1, 0.58, 0.13, 0.45)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var id: String = choice[0]
		var desc: String = choice[2]
		b.pressed.connect(func() -> void: _pick(id))
		col.add_child(b)
		var d := Label.new()
		d.text = desc
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8, 0.75))
		col.add_child(d)


	var _btn_row := HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 8)
	col.add_child(_btn_row)
	var btitle := Label.new()
	btitle.text = "AND YOUR BUTTONS?"
	btitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btitle.add_theme_font_size_override("font_size", 18)
	btitle.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(btitle)
	for id in ["face", "classic"]:
		var b := Button.new()
		b.name = "Btns_" + id
		b.text = "Face buttons\nA light - B heavy - X kick - Y grab" if id == "face" \
				else "Classic\nPUNCH - DODGE - JUMP - SPRINT - GRAB"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(290, 96)
		b.add_theme_font_size_override("font_size", 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		sb.border_color = Color(1, 0.58, 0.13, 0.45)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var bid: String = id
		b.pressed.connect(func() -> void: _pick_buttons(bid))
		_btn_row.add_child(b)


func _pick(scheme: String) -> void:
	Settings.set_value("scheme", scheme)
	Settings.set_value("first_run_done", true)
	InputBus.locked = false
	Sound.play("ui_confirm_0", -8.0)
	Haptics.fire("ui")
	queue_free()
	Log.info("FirstRun: picked scheme '%s'" % scheme)
