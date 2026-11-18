class_name StickInput
extends Control
## All movement input on one node (Stage A). Four schemes the player chooses:
##   floating - the pad appears wherever the left thumb lands
##   fixed    - the classic anchored pad, press starts inside it
##   dpad     - 8-direction pad: the touch-down point is the hub
##   drag     - drag-to-move: a relative swipe from the touch-down point
## The raw pull goes through: dead zone -> rescale -> response curve ->
## sensitivity -> exponential smoothing (instant zero on release) -> optional
## 8-direction snap -> InputBus.move.
##
## Drift and stuck-finger fixes: the stick owns ONE touch index and ignores
## every other finger; release happens on touch-up, on InputBus.locked (the
## setter drops everything), on window focus loss, on pause, and through a
## safety timeout that zeroes a stick whose finger has gone silent. The
## camera half (right side drag) is a separate touch index and only ever
## writes yaw DELTAS, so an idle screen can never turn the camera.

const KNOB_RADIUS := 46.0
const TRAVEL := 150.0          # px of pull for full deflection (larger travel)
const LEFT_ZONE_W := 0.55      # movement half of the screen
const TOP_GUARD := 0.14        # keep clear of the pause button
const STALE_MSEC := 5000.0     # a silent engaged stick is released after this

var _touch := -1               # index owning movement, -1 = none
var _cam_touch := -1           # index owning the camera drag
var _anchor := Vector2.ZERO    # where this stroke started (scheme-relative)
var _center := Vector2.ZERO    # visual pad centre
var _knob := Vector2.ZERO      # visual offset of the knob
var _target := Vector2.ZERO    # post-pipeline desired move
var _dir8 := -1                # active dpad wedge, -1 none
var _cam_last := Vector2.ZERO
var _last_event_msec := 0.0
var _active := false


func _ready() -> void:
	add_to_group("stick")
	Settings.changed.connect(_on_setting)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_on_setting("scheme")


func _on_setting(_key: String) -> void:
	_release(true)
	queue_redraw()


func _process(delta: float) -> void:
	# safety timeout: no events from the owning finger for 5 s -> let go
	if _touch != -1 and Time.get_ticks_msec() - _last_event_msec > STALE_MSEC:
		Log.warn("StickInput: stale finger %d released" % _touch)
		_release(true)
	# smoothing: ease toward the target; snap straight to zero
	if InputBus.move != _target:
		if _target == Vector2.ZERO:
			InputBus.move = Vector2.ZERO
		else:
			var tau: float = maxf(0.001, float(Settings.value("smoothing")))
			var k := 1.0 - exp(-delta / tau)
			InputBus.move = InputBus.move.lerp(_target, k)
			if InputBus.move.distance_to(_target) < 0.01:
				InputBus.move = _target
	# auto-sprint at the edge of the stick
	InputBus.stick_sprint(_active and bool(Settings.value("auto_sprint"))
			and _target.length() >= 0.985)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if InputBus.locked:
		if _touch != -1 or _cam_touch != -1:
			_release(true)
			_release_cam()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch == -1 and _in_left_zone(event.position):
				_touch = event.index
				_anchor = event.position
				_last_event_msec = Time.get_ticks_msec()
				_begin_stroke(event.position)
			elif _cam_touch == -1 and bool(Settings.value("cam_drag")) \
					and not _in_left_zone(event.position):
				_cam_touch = event.index
				_cam_last = event.position
		else:
			if event.index == _touch:
				_release(false)
			elif event.index == _cam_touch:
				_release_cam()
	elif event is InputEventScreenDrag:
		if event.index == _touch:
			_last_event_msec = Time.get_ticks_msec()
			_stroke_to(event.position)
		elif event.index == _cam_touch:
			var d: Vector2 = event.position - _cam_last
			_cam_last = event.position
			var speed: float = 0.0035 * float(Settings.value("cam_speed"))
			InputBus.add_cam_yaw_delta(-d.x * speed)


# --- movement schemes ---------------------------------------------------------


func _begin_stroke(pos: Vector2) -> void:
	_active = true
	match _scheme():
		"fixed":
			_center = _fixed_center()
			_stroke_to(pos)
		"dpad":
			_center = pos
			_dir8 = -1
			InputBus.move = Vector2.ZERO
			_target = Vector2.ZERO
		_:
			_center = pos  # floating pad / drag: planted under the thumb
			_knob = Vector2.ZERO
			_stroke_to(pos)
	queue_redraw()


func _stroke_to(pos: Vector2) -> void:
	match _scheme():
		"dpad":
			_dpad_to(pos)
		"drag":
			_drag_to(pos)
		_:
			_pad_to(pos)


## Fixed or floating pad: absolute pull from the pad centre.
func _pad_to(pos: Vector2) -> void:
	var v := pos - _center
	_knob = v.limit_length(TRAVEL)
	_target = _shape(v.limit_length(TRAVEL) / TRAVEL)


## Drag-to-move: relative swipe from the touch-down point.
func _drag_to(pos: Vector2) -> void:
	var v := pos - _anchor
	_knob = v.limit_length(TRAVEL) * 0.5
	_target = _shape(v.limit_length(TRAVEL) / TRAVEL)


## D-pad: 8 wedges around the touch-down hub; magnitude grows to full at
## half travel (a thumb tap lands at full speed, like a real pad).
func _dpad_to(pos: Vector2) -> void:
	var v := pos - _anchor
	if v.length() < 18.0:
		_dir8 = -1
		_target = Vector2.ZERO
		_knob = Vector2.ZERO
		return
	_dir8 = int(round(fposmod(v.angle() + PI / 8.0 + PI, TAU) / (PI / 4.0))) % 8
	var dir := Vector2.from_angle(float(_dir8) * (PI / 4.0) - PI)
	var mag: float = clampf((v.length() - 18.0) / 60.0, 0.0, 1.0)
	_knob = dir * 34.0
	_target = dir * mag


# --- the response pipeline ------------------------------------------------------


## dead zone -> rescale -> curve -> sensitivity -> snap. `v` is 0..1 length.
func _shape(v: Vector2) -> Vector2:
	var dz: float = float(Settings.value("deadzone"))
	var mag := v.length()
	if mag <= dz:
		return Vector2.ZERO
	mag = (mag - dz) / (1.0 - dz)                  # rescale past the zone
	mag = pow(mag, float(Settings.value("curve")))   # slow start, full at edge
	mag = clampf(mag * float(Settings.value("sensitivity")), 0.0, 1.0)
	var dir := v / v.length()
	if bool(Settings.value("snap8")):
		dir = Vector2.from_angle(roundf((dir.angle() + PI) / (PI / 4.0))
				* (PI / 4.0) - PI)
	return dir * mag


func _scheme() -> String:
	return str(Settings.value("scheme"))


func _in_left_zone(pos: Vector2) -> bool:
	var s := get_viewport_rect().size
	var ok_x := pos.x < s.x * LEFT_ZONE_W
	if bool(Settings.value("left_handed")):
		ok_x = pos.x > s.x * (1.0 - LEFT_ZONE_W)
	return ok_x and pos.y > s.y * TOP_GUARD


func _fixed_center() -> Vector2:
	# where the pad is drawn when nobody is touching: bottom-left home
	var s := get_viewport_rect().size
	var scale: float = float(Settings.value("stick_scale"))
	return Vector2(120.0 * scale, s.y - 120.0 * scale)


## Tests and the debug bot: drive the stick without a finger. The stick
## adopts the value as its own target (so the anti-drift loop keeps it);
## released by _release() / reset_input() / a real touch.
func debug_set_move(v: Vector2) -> void:
	if _touch == -1:
		_target = v
		InputBus.move = v


func _release(from_system: bool) -> void:
	_touch = -1
	_active = false
	_dir8 = -1
	_target = Vector2.ZERO
	InputBus.move = Vector2.ZERO
	InputBus.stick_sprint(false)
	if not from_system:
		InputBus.stick_released.emit()
	queue_redraw()


func _release_cam() -> void:
	_cam_touch = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_PAUSED:
		_release(true)
		_release_cam()


# --- visuals --------------------------------------------------------------------


func _draw() -> void:
	if not _active:
		return
	var scale: float = float(Settings.value("stick_scale"))
	match _scheme():
		"dpad":
			for i in 8:
				var ang := float(i) * (PI / 4.0) - PI
				var p := _center + Vector2.from_angle(ang) * 46.0
				var on := i == _dir8
				draw_circle(p, 17.0 * scale, Color(1, 1, 1, 0.5 if on else 0.16))
			draw_circle(_center, 6.0, Color(1, 1, 1, 0.25))
		"drag":
			draw_circle(_anchor, 10.0, Color(1, 1, 1, 0.22))
			draw_line(_anchor, _anchor + _knob, Color(1, 1, 1, 0.5), 3.0, true)
			draw_circle(_anchor + _knob, 8.0, Color(1, 1, 1, 0.5))
		_:
			draw_circle(_center, TRAVEL * 0.98 * scale, Color(1, 1, 1, 0.05))
			draw_arc(_center, TRAVEL * 0.95 * scale, 0.0, TAU, 48,
					Color(1, 1, 1, 0.30), 2.0, true)
			draw_circle(_center + _knob, KNOB_RADIUS * scale, Color(1, 1, 1, 0.45))
