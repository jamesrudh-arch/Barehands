extends Control
## Touch joystick for phones. Fixed pad pinned bottom-left (anchors set in main.tscn).
## While a finger drags inside the pad it writes a 0..1 direction into InputBus.move.

const KNOB_RADIUS := 44.0
const MAX_PULL := 0.78  # knob travel as a fraction of the pad radius

var _radius := 0.0
var _touch := -1  # active touch index, -1 = released
var _knob := Vector2.ZERO


func _ready() -> void:
	_radius = minf(size.x, size.y) * 0.5
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _hit(event.position):
			_touch = event.index
			_drag_to(event.position)
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_drag_to(event.position)


func _center() -> Vector2:
	return global_position + size * 0.5


func _hit(pos: Vector2) -> bool:
	return pos.distance_to(_center()) <= _radius * 1.15  # a little slack for fingertips


func _drag_to(pos: Vector2) -> void:
	_knob = (pos - _center()).limit_length(_radius * MAX_PULL)
	InputBus.move = _knob / (_radius * MAX_PULL)
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	InputBus.move = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, _radius * 0.98, Color(1, 1, 1, 0.05))
	draw_arc(c, _radius * 0.95, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0, true)
	draw_circle(c + _knob, KNOB_RADIUS, Color(1, 1, 1, 0.45))
