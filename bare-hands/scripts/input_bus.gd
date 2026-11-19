extends Node
## Tiny shared bus between the touch UI and the hero. Autoloaded as "InputBus"
## (see project.godot). The stick writes `move`; the action buttons write
## `sprint` and queue jump/grab presses; the camera publishes `camera_yaw`.
## PUNCH and DODGE distinguish taps from holds: a quick release queues the
## light action, holding past the threshold means heavy/block (the player
## polls punch_age()/dodge_age()). Queues expire after 0.4 s of GAME time so
## slow motion does not eat a buffered counter and a mid-air jump never
## fires on landing.
##
## `locked` doubles as the input reset: the moment ANY system locks input
## (cutscene, dialogue, shop, pause-adjacent panels) the stick, held buttons
## and queues are dropped, so a phone finger-state from before the lock can
## never leak movement into the locked scene (the stuck-stick fix).

const QUEUE_LIFE_MSEC := 400.0
const PUNCH_HOLD_MSEC := 300.0
const DODGE_HOLD_MSEC := 250.0

var move := Vector2.ZERO  # x = strafe, y = forward/back, magnitude 0..1
var camera_yaw := 0.0  # yaw of the camera's look direction on the ground plane

## Sprint is the OR of the button hold and the stick's auto-sprint edge.
var sprint := false:
	get:
		return _sprint_btn or _sprint_stick
var _sprint_btn := false
var _sprint_stick := false
var _cam_yaw_delta := 0.0  # right-side drag accumulates here, camera consumes
var punch_held := false
var dodge_held := false

var locked := false:
	set(v):
		if v and not locked:
			reset_input()
		locked = v

var _game_msec := 0.0
var _stamps := {}  # action id -> usec when the touch landed / the action fired


## Latency measurement: the HUD stamps the touch, the player stamps the
## action; the debug panel shows the difference.
## The face buttons' logical presses (A/B/X/Y) - also what the combo
## buffer listens to. direction: "f"/"b"/"" captured from the stick.
signal face_pressed(token: String, direction: String)


func press_face(token: String) -> void:
	var d := ""
	var m := move
	if m.length() > 0.45:
		d = "f" if m.y < 0.0 else "b"
	face_pressed.emit(token, d)


func stamp_action(id: String) -> void:
	_stamps[id + "_touch"] = Time.get_ticks_usec()


func stamp_fired(id: String) -> void:
	_stamps[id + "_fired"] = Time.get_ticks_usec()


func latency_msec(id: String) -> float:
	var a: float = _stamps.get(id + "_touch", 0.0)
	var b: float = _stamps.get(id + "_fired", 0.0)
	if a <= 0.0 or b <= a:
		return -1.0
	return (b - a) / 1000.0
var _jump_at := -99999.0
var _punch_at := -99999.0
var _heavy_at := -99999.0
var _kick_at := -99999.0
var _dodge_at := -99999.0
var _grab_at := -99999.0
var _super_at := -99999.0
var _punch_down_at := -99999.0
var _dodge_down_at := -99999.0
var _punch_hold_consumed := true
var _dodge_hold_consumed := true


func _physics_process(delta: float) -> void:
	_game_msec += delta * 1000.0  # scaled: stretches with Engine.time_scale


## Drop EVERYTHING a finger might still be holding. Called on lock, on
## focus loss, on pause, on scheme change - the stuck-stick fix.
func reset_input() -> void:
	move = Vector2.ZERO
	_sprint_btn = false
	_sprint_stick = false
	punch_held = false
	dodge_held = false
	clear_queues()
	stick_released.emit()


func press_sprint() -> void:
	_sprint_btn = true


func release_sprint() -> void:
	_sprint_btn = false


func stick_sprint(active: bool) -> void:
	_sprint_stick = active


func add_cam_yaw_delta(d: float) -> void:
	_cam_yaw_delta += d


func take_cam_yaw_delta() -> float:
	var d := _cam_yaw_delta
	_cam_yaw_delta = 0.0
	return d


## The stick calls this when its finger is genuinely gone (or was never
## there); the HUD re-centres its visuals.
signal stick_released


func queue_jump() -> void:
	_jump_at = _game_msec


func take_jump() -> bool:
	return _take("_jump_at")


## A raw light-punch queue (tests and simple taps).
func queue_punch() -> void:
	_punch_at = _game_msec


func take_punch() -> bool:
	return _take("_punch_at")


## Face-button scheme: B is an instant heavy (Classic gets heavies by
## holding PUNCH), X is a kick.
func queue_heavy() -> void:
	_heavy_at = _game_msec


func take_heavy() -> bool:
	return _take("_heavy_at")


func queue_kick() -> void:
	_kick_at = _game_msec


func take_kick() -> bool:
	return _take("_kick_at")


## Is a grab waiting, and was it pressed BEFORE any swing queued after it?
## (The combo pass: Y then B must not let the heavy eat the grab.)
func grab_pending() -> bool:
	return _game_msec - _grab_at <= QUEUE_LIFE_MSEC


func grab_is_older() -> bool:
	if _game_msec - _grab_at > QUEUE_LIFE_MSEC:
		return false
	return _grab_at <= maxf(_heavy_at, maxf(_punch_at, _kick_at))


func queue_dodge() -> void:
	_dodge_at = _game_msec


func take_dodge() -> bool:
	return _take("_dodge_at")


## Is a dodge waiting, and when was it tapped? (GAME-time stamp, like the
## queue itself.) Peek WITHOUT consuming: dodge leniency (bible 4A) holds
## a too-early tap under its ORIGINAL stamp so the queue's life keeps
## running from the real tap - leniency can never extend the buffer.
func dodge_stamp() -> float:
	return _dodge_at if _game_msec - _dodge_at <= QUEUE_LIFE_MSEC else -99999.0


func queue_grab() -> void:
	_grab_at = _game_msec


func take_grab() -> bool:
	return _take("_grab_at")


func queue_super() -> void:
	_super_at = _game_msec


func take_super() -> bool:
	return _take("_super_at")


# --- press / release with tap-vs-hold ------------------------------------------


func punch_press() -> void:
	punch_held = true
	_punch_down_at = _game_msec
	_punch_hold_consumed = false


func punch_release() -> void:
	punch_held = false
	if not _punch_hold_consumed and _game_msec - _punch_down_at < PUNCH_HOLD_MSEC:
		queue_punch()  # a tap: the light punch fires on release


func punch_age() -> float:
	return (_game_msec - _punch_down_at) / 1000.0 if punch_held else -1.0


func consume_punch_hold() -> void:
	_punch_hold_consumed = true


func dodge_press() -> void:
	dodge_held = true
	_dodge_down_at = _game_msec
	_dodge_hold_consumed = false


func dodge_release() -> void:
	dodge_held = false
	if not _dodge_hold_consumed and _game_msec - _dodge_down_at < DODGE_HOLD_MSEC:
		queue_dodge()  # a tap: the dodge fires on release


func dodge_age() -> float:
	return (_game_msec - _dodge_down_at) / 1000.0 if dodge_held else -1.0


func consume_dodge_hold() -> void:
	_dodge_hold_consumed = true


## Test hook: drop anything queued so a phase starts from a clean slate.
func clear_queues() -> void:
	_jump_at = -99999.0
	_punch_at = -99999.0
	_heavy_at = -99999.0
	_kick_at = -99999.0
	_dodge_at = -99999.0
	_grab_at = -99999.0
	_super_at = -99999.0


func _take(prop: String) -> bool:
	if _game_msec - get(prop) <= QUEUE_LIFE_MSEC:
		set(prop, -99999.0)
		return true
	return false
