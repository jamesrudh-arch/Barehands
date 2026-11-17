extends Node
## Headless smoke test for Batch 2 — not part of the game.
## Run from the project folder:  godot --headless res://tests/smoke.tscn
## Checks: mannequin size, analog run speeds, sprint, model turn-to-face,
## jump, code-faked ledge climb, camera follow + wall pull-in, anim states.

var _main: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _anim: AnimationPlayer
var _fails := 0
var _phase := 0
var _pf := 0  # frame inside the current phase

var _max_speed := 0.0
var _speed_sum := 0.0
var _speed_n := 0
var _max_y := 0.0
var _saw_air_anim := false
var _saw_climb := false
var _yaw_end := 0.0
var _climb_try := -1
const CLIMB_START := Vector3(9.0, 0.02, -4.8)
const JUMP_AT := [8, 12, 16, 20]


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as CharacterBody3D
	_camera = _main.get_node("Camera") as Camera3D
	_anim = _player.get_node("Body/Mannequin/AnimationPlayer")


func _flat_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _physics_process(_delta: float) -> void:
	_pf += 1
	match _phase:
		0:
			_settle()
		1:
			_run()
		2:
			_half_push()
		3:
			_sprint_south()
		4:
			_jump()
		5:
			_climb()
		6:
			_camera_wall()
		_:
			_finish()


func _next() -> void:
	_phase += 1
	_pf = 0


func _settle() -> void:
	if _pf == 40:
		var mi := _player.get_node("Body/Mannequin/Armature/Skeleton3D/Mannequin") as MeshInstance3D
		var h := (mi.global_transform * mi.mesh.get_aabb()).size.y if mi and mi.mesh else 0.0
		_check(h > 1.55 and h < 1.85, "mannequin world height ~1.7 (got %.2f)" % h)
		_check(_anim.current_animation == "Idle", "idles with the pack's Idle clip (got %s)" % _anim.current_animation)
		_next()


func _run() -> void:
	InputBus.move = Vector2(0, -1)
	_max_speed = maxf(_max_speed, _flat_speed())
	if _pf == 1:
		_camera.global_position = _player.global_position + Vector3(0, 3, 6.5)
	if _pf >= 90:
		InputBus.move = Vector2.ZERO
		_check(_max_speed >= 5.0, "full push reaches run speed (max %.1f)" % _max_speed)
		_check(_player.global_position.z < -2.0, "travelled north")
		_check(_camera.global_position.distance_to(_player.global_position) < 9.5, "camera follows while running")
		_next()


func _half_push() -> void:
	InputBus.move = Vector2(0, -0.45)
	if _pf > 40:
		_speed_sum += _flat_speed()
		_speed_n += 1
	if _pf >= 70:
		InputBus.move = Vector2.ZERO
		var avg := _speed_sum / maxf(_speed_n, 1.0)
		_check(avg > 2.0 and avg < 3.8, "half push paces between walk and run (%.1f)" % avg)
		_check(_anim.current_animation == "Walk", "walk clip at half push")
		_next()


func _sprint_south() -> void:
	if _pf <= 80:
		InputBus.move = Vector2(0, 1)
		InputBus.sprint = true
		_max_speed = maxf(_max_speed, _flat_speed())
	else:
		InputBus.move = Vector2.ZERO
		InputBus.sprint = false
		if _pf == 90:
			_check(_max_speed >= 6.2, "sprint button tops run speed (max %.1f)" % _max_speed)
			_check(_anim.current_animation == "Sprint", "sprint clip at full sprint (got %s)" % _anim.current_animation)
		if _pf >= 150:
			_yaw_end = _player.get_node("Body").rotation.y
			var d := absf(wrapf(_yaw_end - PI, -PI, PI))
			_check(d < 0.4, "model turned to face travel south")
			_check(_flat_speed() < 0.4, "smooth decel to a stop (%.2f)" % _flat_speed())
			_check(_anim.current_animation == "Idle", "back to idle after stopping")
			_next()


func _jump() -> void:
	if _pf == 5:
		InputBus.queue_jump()
	if not _player.is_on_floor():
		_max_y = maxf(_max_y, _player.global_position.y)
		if _anim.current_animation in ["Jump_Start", "Jump"]:
			_saw_air_anim = true
	if _pf > 5 and _player.is_on_floor() and _max_y > 0.5:
		_check(_max_y >= 0.9, "jump gains ~1.2 m of height (%.2f)" % _max_y)
		_check(_saw_air_anim, "jump clips play in the air")
		_next()
	elif _pf > 240:
		_check(false, "jump never left the ground / never landed")
		_next()


func _climb() -> void:
	if _pf == 1:
		_climb_try += 1
		if _climb_try >= JUMP_AT.size():
			_check(false, "ledge climb never triggered")
			_next()
			return
		_player.global_position = CLIMB_START
		_player.velocity = Vector3.ZERO
		_camera.set("_yaw", 0.0)  # behind the run-up so "up" on the stick runs north
		_camera.global_position = CLIMB_START + Vector3(0, 3, 6.5)
	InputBus.move = Vector2(0, -1)
	if _pf == JUMP_AT[_climb_try]:
		InputBus.queue_jump()
	if _player.state == 2:  # CLIMB
		_saw_climb = true
	if _saw_climb and _player.is_on_floor() and _player.state == 0:
		InputBus.move = Vector2.ZERO
		_check(_player.global_position.y > 3.0, "pulled up onto the 3.4 m annex roof (%.2f)" % _player.global_position.y)
		_next()
	elif _pf > 140:
		InputBus.move = Vector2.ZERO  # retry with a later jump
		_pf = 0


func _camera_wall() -> void:
	if _pf == 1:
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(1.5, 0.05, -9.15)
		_camera.global_position = _player.global_position + Vector3(0, 3, 6.5)
		_camera.set("_yaw", PI)
	if _pf >= 60:
		var pivot := _player.global_position + Vector3.UP * 1.5
		var cam_d := _camera.global_position.distance_to(pivot)
		_check(_camera.global_position.z > -10.2, "camera pulled out of the building wall (z %.2f)" % _camera.global_position.z)
		_check(cam_d < 6.2, "boom shortened against the wall (%.2f m)" % cam_d)
		_next()


func _finish() -> void:
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)
