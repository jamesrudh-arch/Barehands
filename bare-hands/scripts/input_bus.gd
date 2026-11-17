extends Node
## Tiny shared bus between the touch UI and the hero. Autoloaded as "InputBus"
## (see project.godot). The joystick writes `move`; the JUMP/SPRINT buttons
## write `sprint` and queue jumps; the camera publishes `camera_yaw` so the
## hero can steer relative to what the player sees.

var move := Vector2.ZERO  # x = strafe, y = forward/back, magnitude 0..1
var sprint := false
var camera_yaw := 0.0  # yaw of the camera's look direction on the ground plane

var _jump_pending := false
var _punch_pending := false
var _dodge_pending := false


func queue_jump() -> void:
	_jump_pending = true


func take_jump() -> bool:
	if _jump_pending:
		_jump_pending = false
		return true
	return false


func queue_punch() -> void:
	_punch_pending = true


func take_punch() -> bool:
	if _punch_pending:
		_punch_pending = false
		return true
	return false


func queue_dodge() -> void:
	_dodge_pending = true


func take_dodge() -> bool:
	if _dodge_pending:
		_dodge_pending = false
		return true
	return false
