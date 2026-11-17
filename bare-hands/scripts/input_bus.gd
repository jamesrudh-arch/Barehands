extends Node
## Tiny shared bus between the touch UI and the hero. Autoloaded as "InputBus"
## (see project.godot). The joystick writes `move`; the action buttons write
## `sprint` and queue jump/punch/dodge presses; the camera publishes
## `camera_yaw` so the hero can steer relative to what the player sees.
## Queues expire after 0.4 s of GAME time (so slow motion does not eat a
## buffered counter) and a jump pressed mid-air never fires on landing.

const QUEUE_LIFE_MSEC := 400.0

var move := Vector2.ZERO  # x = strafe, y = forward/back, magnitude 0..1
var sprint := false
var camera_yaw := 0.0  # yaw of the camera's look direction on the ground plane
var locked := false  # true during the opening shot: the hero ignores input

var _game_msec := 0.0
var _jump_at := -99999.0
var _punch_at := -99999.0
var _dodge_at := -99999.0


func _physics_process(delta: float) -> void:
	_game_msec += delta * 1000.0  # scaled: stretches with Engine.time_scale


func queue_jump() -> void:
	_jump_at = _game_msec


func take_jump() -> bool:
	return _take("_jump_at")


func queue_punch() -> void:
	_punch_at = _game_msec


func take_punch() -> bool:
	return _take("_punch_at")


func queue_dodge() -> void:
	_dodge_at = _game_msec


func take_dodge() -> bool:
	return _take("_dodge_at")


## Test hook: drop anything queued so a phase starts from a clean slate.
func clear_queues() -> void:
	_jump_at = -99999.0
	_punch_at = -99999.0
	_dodge_at = -99999.0


func _take(prop: String) -> bool:
	if _game_msec - get(prop) <= QUEUE_LIFE_MSEC:
		set(prop, -99999.0)
		return true
	return false
