extends Node
const CLS_FollowCamera := preload("res://scripts/camera_follow.gd")
const CLS_HeroRig := preload("res://scripts/hero_rig.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
const CLS_Player := preload("res://scripts/player.gd")
const CLS_StickInput := preload("res://scripts/stick_input.gd")
## Headless smoke test for movement — not part of the game.
## Run from the project folder:  godot --headless res://tests/smoke.tscn
## Checks: mannequin size, model faces its travel direction (hand bones vs
## movement), analog run speeds, sprint, jump, ledge climb, camera follow +
## wall pull-in, anim states. Combat has its own tests/smoke_combat.tscn.

var _main: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _hand_l := -1
var _hand_r := -1
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
var _l_sum := 0.0  # hand bone X samples, for facing checks
var _r_sum := 0.0
var _face_n := 0
var _climb_face_ok := false
var _max_fov := 70.0
const CLIMB_START := Vector3(9.0, 0.02, -4.8)
const JUMP_AT := [6, 10, 14, 18]  # deliberately imperfect timings: tests forgiveness


var _stick: CLS_StickInput


## Drive movement through the REAL stick (its anti-drift loop owns move).
func _set_move(v: Vector2) -> void:
	if _stick:
		_stick.debug_set_move(v)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # the picker would lock input
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_stick = _main.get_node("UI/Joystick")
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()  # tests drive input themselves
	_player = _main.get_node("Player") as CharacterBody3D
	_camera = _main.get_node("Camera") as Camera3D
	_anim = (_player.get_node("Body/Hero") as CLS_HeroRig).main_player()
	_skel = _player.get_node("Body/Hero/Body/Armature/Skeleton3D") as Skeleton3D
	_hand_l = _skel.find_bone("hand_l")
	_hand_r = _skel.find_bone("hand_r")


func _hand_x(idx: int) -> float:
	return (_skel.global_transform * _skel.get_bone_global_pose(idx)).origin.x


func _sample_hands() -> void:
	_l_sum += _hand_x(_hand_l)
	_r_sum += _hand_x(_hand_r)
	_face_n += 1


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
			_hint()
		7:
			_camera_wall()
		8:
			_fov_kick()
		9:
			_pushin_lock()
		_:
			_finish()


func _next() -> void:
	_phase += 1
	_pf = 0


func _settle() -> void:
	if _pf == 40:
		var head := _skel.get_bone_global_pose(_skel.find_bone("Head")).origin.y
		var h: float = head + 0.12  # head bone sits just under the crown
		_check(h > 1.55 and h < 1.85, "hero world height ~1.7 (got %.2f)" % h)
		_check(_anim.current_animation == "Idle", "idles with the pack's Idle clip (got %s)" % _anim.current_animation)
		_check(not InputBus.locked, "opening shot skipped, input unlocked")
		_next()


func _run() -> void:
	_set_move(Vector2(0, -1))
	_max_speed = maxf(_max_speed, _flat_speed())
	if _pf == 1:
		_camera.global_position = _player.global_position + Vector3(0, 3, 6.5)
	if _pf > 70:
		_sample_hands()
	if _pf >= 90:
		_set_move(Vector2.ZERO)
		_check(_max_speed >= 5.0, "full push reaches run speed (max %.1f)" % _max_speed)
		_check(_player.global_position.z < -2.0, "travelled north")
		_check(_camera.global_position.distance_to(_player.global_position) < 9.5, "camera follows while running")
		var l := _l_sum / _face_n
		var r := _r_sum / _face_n
		_check(l < _player.global_position.x and r > _player.global_position.x,
				"model faces travel (north): left hand west, right hand east (%.2f / %.2f)" % [l, r])
		_l_sum = 0.0
		_r_sum = 0.0
		_face_n = 0
		_next()


func _half_push() -> void:
	_set_move(Vector2(0, -0.45))
	if _pf > 40:
		_speed_sum += _flat_speed()
		_speed_n += 1
	if _pf >= 70:
		_set_move(Vector2.ZERO)
		var avg := _speed_sum / maxf(_speed_n, 1.0)
		_check(avg > 2.0 and avg < 3.8, "half push paces between walk and run (%.1f)" % avg)
		_check(_anim.current_animation == "Walk", "walk clip at half push")
		_next()


func _sprint_south() -> void:
	if _pf <= 80:
		_set_move(Vector2(0, 1))
		InputBus.press_sprint()
		_max_speed = maxf(_max_speed, _flat_speed())
		if _pf > 60:
			_sample_hands()
	else:
		_set_move(Vector2.ZERO)
		InputBus.release_sprint()
		if _pf == 90:
			_check(_max_speed >= 6.2, "sprint button tops run speed (max %.1f)" % _max_speed)
			_check(_anim.current_animation == "Sprint", "sprint clip at full sprint (got %s)" % _anim.current_animation)
			var l := _l_sum / maxf(_face_n, 1.0)
			var r := _r_sum / maxf(_face_n, 1.0)
			_check(l > _player.global_position.x and r < _player.global_position.x,
					"model faces travel (south): left hand east, right hand west (%.2f / %.2f)" % [l, r])
			_l_sum = 0.0
			_r_sum = 0.0
			_face_n = 0
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
	_set_move(Vector2(0, -1))
	if _pf == JUMP_AT[_climb_try]:
		InputBus.queue_jump()
	if _player.state == CLS_Player.State.CLIMB:  # the body faces into the wall
		_sample_hands()
		_saw_climb = true
	if _saw_climb and _player.is_on_floor() and _player.state == CLS_Player.State.GROUND:
		_set_move(Vector2.ZERO)
		_check(_player.global_position.y > 3.0, "pulled up onto the 3.4 m annex roof (%.2f)" % _player.global_position.y)
		var l := _l_sum / maxf(_face_n, 1.0)
		var r := _r_sum / maxf(_face_n, 1.0)
		_check(l < r, "climb pose faces the wall (left hand west of right, %.2f < %.2f)" % [l, r])
		_next()
	elif _pf > 140:
		_set_move(Vector2.ZERO)  # retry with a later jump
		_l_sum = 0.0
		_r_sum = 0.0
		_face_n = 0
		_pf = 0


func _hint() -> void:
	if _pf == 1:
		_player.global_position = Vector3(9.0, 0.02, -5.6)  # 1.1 m from the annex face, facing it
		_player.velocity = Vector3.ZERO
	if _pf >= 40:
		var hud := _main.get_node("UI")
		_check(hud.hint_shown, "climb hint shown once near a climbable edge")
		_next()


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


func _fov_kick() -> void:
	if _pf == 1:
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(0.0, 0.02, 8.0)
		_camera.global_position = _player.global_position + Vector3(0, 3, 6)
	_set_move(Vector2(0, -1))
	InputBus.press_sprint()
	_max_fov = maxf(_max_fov, _camera.fov)
	if _pf >= 90:
		_set_move(Vector2.ZERO)
		InputBus.release_sprint()
		_check(_max_fov > 73.0, "sprint kicks the field of view out (fov %.1f)" % _max_fov)
		_next()


func _pushin_lock() -> void:
	if _pf == 1:
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(-2.6, 0.02, -4.5)  # beside the dummy
		_camera.global_position = _player.global_position + Vector3(0, 3, 6)
	if _pf == 100:
		var cam_d := _camera.global_position.distance_to(_player.global_position + Vector3.UP * 1.5)
		_check(cam_d < 5.3, "camera pushes in near an enemy (%.2f m)" % cam_d)
		(_camera as CLS_FollowCamera).toggle_lock()
		_check((_camera as CLS_FollowCamera).lock_target() != null, "lock-on grabs the nearest enemy")
	if _pf == 130:
		_check((_camera as CLS_FollowCamera).lock_target() != null, "lock-on holds while the enemy stands")
		(_camera as CLS_FollowCamera).toggle_lock()
		_check((_camera as CLS_FollowCamera).lock_target() == null, "lock-on toggles off")
		_next()


func _finish() -> void:
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)