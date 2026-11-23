extends Control

## USER OVERRIDES R3: the SECOND camera control - a visible camera pad
## on the screen's right edge, beside the move stick. A thumb-drag on
## the pad swings the camera (yaw) through the SAME pipe the right-edge
## drag already feeds (InputBus.add_cam_yaw_delta), so the two controls
## can never disagree; the camera consumes one merged stream. A small
## pad, not a full-rect layer: the action buttons and the edge drag
## keep every pixel they had.

const PAD_RADIUS := 62.0
const KNOB_RADIUS := 22.0
const SENS := 0.011          # radians per pixel of drag

var _dragging := false
var _last := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(PAD_RADIUS * 2.0 + 16.0, PAD_RADIUS * 2.0 + 16.0)
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	position = Vector2(-24.0, -140.0)   # above the action cluster
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	# round, not square - the pad answers only inside the ring
	return point.distance_to(size * 0.5) <= PAD_RADIUS + 8.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_last = event.position
			accept_event()
		else:
			_dragging = false
			queue_redraw()
	elif event is InputEventScreenDrag and _dragging:
		apply_delta(event.position.x - _last.x)
		_last = event.position
		accept_event()


## The one write: both the pad drag and the suite test push yaw through
## here, into the shared InputBus pipe the follow camera consumes.
func apply_delta(dx: float) -> void:
	InputBus.add_cam_yaw_delta(-dx * SENS)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ring := Color(0.45, 0.85, 0.9, 0.30 if _dragging else 0.18)
	draw_arc(c, PAD_RADIUS, 0.0, TAU, 40, ring, 2.5, true)
	draw_circle(c, 4.0, Color(0.45, 0.85, 0.9, 0.5))
	var font := get_theme_default_font()
	draw_string(font, c + Vector2(-14, PAD_RADIUS + 14), "CAM",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.8, 0.85, 0.75))
	if _dragging:
		var off := (_last - c).limit_length(PAD_RADIUS - KNOB_RADIUS)
		draw_circle(c + off, KNOB_RADIUS, Color(0.55, 0.95, 1.0, 0.4))
