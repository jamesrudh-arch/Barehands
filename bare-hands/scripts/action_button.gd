class_name ActionButton
extends Control
## One touch action button (Stage A3). Fires the instant a finger lands
## (touch-DOWN, not click). The hit area is the whole control rect while the
## drawn visual is smaller - a fingertip can land a little off-centre and
## still register. Draws its own visual: a soft disc, a label, a press
## animation (scale + brighten), an optional cooldown arc and a charged
## glow. Sounds and haptics are decided by the owner (touch_buttons).

signal down
signal up

var label := "BUTTON"
var tint := Color(1, 0.58, 0.45, 0.95)
var visual_scale := 0.80  # drawn disc vs hit rect
var cooldown := 0.0       # 0 = ready, 1 = just used (arc drains to 0)
var charged := false      # full glow (the SUPER button when the meter is full)
var editable := false     # layout-editor mode: no actions, just drags

var _press := 0.0         # press animation 0..1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if editable:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = 1.0
			down.emit()
		else:
			_up()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = 1.0
			down.emit()
		else:
			_up()


func _up() -> void:
	_press = maxf(_press, 0.35)
	up.emit()


func _process(delta: float) -> void:
	if _press > 0.0:
		_press = maxf(0.0, _press - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 * visual_scale
	var press_r := r * (1.0 - 0.10 * _press)
	# charged: a breathing outer glow
	if charged:
		var t := Time.get_ticks_msec() / 1000.0
		var gr := r * (1.18 + 0.05 * sin(t * 5.0))
		draw_arc(c, gr, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.45), 3.0, true)
	# the disc
	var fill := Color(tint.r, tint.g, tint.b, 0.16 + 0.30 * _press)
	if charged:
		fill = Color(tint.r * 1.2, tint.g * 1.1, tint.b, 0.42)
	draw_circle(c, press_r, fill)
	draw_arc(c, press_r, 0.0, TAU, 40,
			Color(tint.r, tint.g, tint.b, 0.85 if _press > 0.0 else 0.55),
			2.5 + 1.5 * _press, true)
	# cooldown arc: drains clockwise from the top
	if cooldown > 0.003:
		draw_arc(c, press_r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cooldown),
				40, Color(1, 1, 1, 0.5), 3.0, true)
	# label
	var font := get_theme_default_font()
	var fs := maxi(12, int(r * 0.42))
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, c - ts * 0.5, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.92))
