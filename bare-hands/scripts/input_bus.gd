extends Node
## Tiny shared bus between the touch UI and the hero. Autoloaded as "InputBus"
## (see project.godot). The joystick writes `move`; the action buttons write
## `sprint` and queue jump/grab presses; the camera publishes `camera_yaw`.
## PUNCH and DODGE distinguish taps from holds: a quick release queues the
## light action, holding past the threshold means heavy/block (the player
## polls punch_age()/dodge_age()). Queues expire after 0.4 s of GAME time so
## slow motion does not eat a buffered counter and a mid-air jump never
## fires on landing.

const QUEUE_LIFE_MSEC := 400.0
const PUNCH_HOLD_MSEC := 300.0
const DODGE_HOLD_MSEC := 250.0

var move := Vector2.ZERO  # x = strafe, y = forward/back, magnitude 0..1
var sprint := false
var camera_yaw := 0.0  # yaw of the camera's look direction on the ground plane
var locked := false  # true during cutscenes: the hero ignores input
var punch_held := false
var dodge_held := false

var _game_msec := 0.0
var _jump_at := -99999.0
var _punch_at := -99999.0
var _dodge_at := -99999.0
var _grab_at := -99999.0
var _punch_down_at := -99999.0
var _dodge_down_at := -99999.0
var _punch_hold_consumed := true
var _dodge_hold_consumed := true


func _physics_process(delta: float) -> void:
	_game_msec += delta * 1000.0  # scaled: stretches with Engine.time_scale


func queue_jump() -> void:
	_jump_at = _game_msec


func take_jump() -> bool:
	return _take("_jump_at")


## A raw light-punch queue (tests and simple taps).
func queue_punch() -> void:
	_punch_at = _game_msec


func take_punch() -> bool:
	return _take("_punch_at")


func queue_dodge() -> void:
	_dodge_at = _game_msec


func take_dodge() -> bool:
	return _take("_dodge_at")


func queue_grab() -> void:
	_grab_at = _game_msec


func take_grab() -> bool:
	return _take("_grab_at")


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
	_dodge_at = -99999.0
	_grab_at = -99999.0


func _take(prop: String) -> bool:
	if _game_msec - get(prop) <= QUEUE_LIFE_MSEC:
		set(prop, -99999.0)
		return true
	return false
