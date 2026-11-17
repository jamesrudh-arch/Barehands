extends Node3D
## Headless smoke test for Batch 1 — not part of the game.
## Run from the project folder:  godot --headless res://tests/smoke.tscn
## Checks: main scene loads, the hero walks from stick input, the camera follows.

const WALK_FRAMES := 90
const SETTLE_FRAMES := 45

var _player: Node3D
var _camera: Camera3D
var _start := Vector3.ZERO
var _frame := 0
var _walk_err := 0.0


func _ready() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_camera = main.get_node("Camera")
	_start = _player.global_position
	InputBus.move = Vector2(0, -1)  # stick pushed "up": walk away from the camera


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame < WALK_FRAMES:
		# while walking the camera may trail by up to speed/follow_speed ~ 1.2 m
		_walk_err = _camera.global_position.distance_to(_player.global_position + _camera.offset)
		return
	if _frame == WALK_FRAMES:
		InputBus.move = Vector2.ZERO  # let go of the stick
		return
	if _frame < WALK_FRAMES + SETTLE_FRAMES:
		return
	var moved := _start.distance_to(_player.global_position)
	var cam_err := _camera.global_position.distance_to(_player.global_position + _camera.offset)
	print("SMOKE moved=%.2f walk_err=%.2f settled_err=%.2f" % [moved, _walk_err, cam_err])
	if moved > 2.0 and _walk_err < 1.5 and cam_err < 0.2:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL")
		get_tree().quit(1)
