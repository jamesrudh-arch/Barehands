extends CharacterBody3D
## Batch-3 enemies, both use the pack's mannequin. mode 0 = a passive training
## dummy that only reacts to hits; mode 1 = a thug that shambles at the hero,
## telegraphs (red pulse) and swings, so the parry timing can be learned.

const GRAVITY := 22.0
const WALK_SPEED := 1.3
const ATTACK_RANGE := 2.0
const STRIKE_RANGE := 1.7
const TELEGRAPH_TIME := 0.6
const STRIKE_TIME := 0.22  # when the fist would land
const RECOVER_TIME := 1.3
const RESPAWN_TIME := 2.6

enum { IDLE, WALK, TELEGRAPH, STRIKE, RECOVER, FLINCH, STAGGER, DOWN }

@export var mode := 0  # 0 training dummy, 1 thug
@export var max_hp := 5

var state := IDLE
var hp := 1
var _t := 0.0  # game-time clock (stretches with slow-mo, unlike wall time)
var _state_t := 0.0
var _spawn := Vector3.ZERO
var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _flash_color := Color(1, 1, 1)
var _struck := false  # has the current swing been resolved?

@onready var _body: Node3D = $Body
@onready var _anim: AnimationPlayer = $Body/Mannequin/AnimationPlayer
@onready var _mi: MeshInstance3D = $Body/Mannequin/Armature/Skeleton3D/Mannequin


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_spawn = global_position
	_own_materials()  # per-instance copies so flash/telegraph don't tint everyone
	if mode == 0:
		var p := _player()
		if p:
			_face_dir(p.global_position - global_position)  # dummy faces the street


func _own_materials() -> void:
	_mi.mesh = _mi.mesh.duplicate()
	for i in _mi.mesh.get_surface_count():
		var m := _mi.mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			var d := (m as StandardMaterial3D).duplicate()
			d.emission_enabled = true
			d.emission = Color(1, 1, 1)
			d.emission_energy_multiplier = 0.0
			_mi.mesh.surface_set_material(i, d)
			_mats.append(d)


func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	match state:
		IDLE, RECOVER:
			_brake(delta)
			if mode == 1:
				_think()
			elif state == RECOVER and _state_t > 0.5:
				_enter(IDLE)
		WALK:
			_brake(delta)
			_think()
		TELEGRAPH:
			_brake(delta)
			_face_player(delta)
			_pulse(Color(1.0, 0.1, 0.08), 0.8 + 0.5 * sin(_state_t * 25.0))
			if _state_t >= TELEGRAPH_TIME:
				_enter(STRIKE)
				_play("Punch_Jab", 0.05, 2.2)
				_struck = false
		STRIKE:
			_brake(delta)
			if not _struck and _state_t >= STRIKE_TIME:
				_struck = true
				_resolve_strike()
			if _state_t >= 0.45:
				_enter(RECOVER)
		FLINCH:
			_brake(delta)
			if _state_t > 0.35:
				_enter(IDLE if mode == 0 else WALK)
		STAGGER:
			_brake(delta)
			if _state_t > 1.4:
				_enter(RECOVER)
		DOWN:
			_brake(delta)
			if _state_t > RESPAWN_TIME:
				_respawn()
	_apply_flash(delta)
	move_and_slide()


func _think() -> void:
	var p := _player()
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	_face_player(get_physics_process_delta_time())
	if dist <= ATTACK_RANGE:
		_enter(TELEGRAPH)
		_play("Idle", 0.1)
	elif dist < 9.0:
		if state != WALK:
			_enter(WALK)
			_play("Walk", 0.2, 1.1)
		velocity.x = to.x / dist * WALK_SPEED
		velocity.z = to.z / dist * WALK_SPEED
	else:
		if state == WALK:
			_enter(IDLE)
			_play("Idle", 0.2)


func _resolve_strike() -> void:
	var p := _player()
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var fwd := -_body.global_transform.basis.z
	if dist > STRIKE_RANGE or Vector2(fwd.x, fwd.z).dot(Vector2(to.x, to.z).normalized()) < 0.3:
		return  # whiffed, out of arc
	var age: float = p.dodge_age()
	if age < 0.22:  # perfect dodge = parry
		Fx.slow_mo(0.7, 0.35)
		p.open_counter(1.3)
		_enter(STAGGER)
		_play("Hit_Head", 0.05, 1.5)
		_flash_white(Color(0.4, 1.0, 1.0), 2.2)
		Fx.burst(p.global_position + Vector3.UP * 1.3, Color(0.3, 0.95, 1.0))
		if _style():
			_style().add("parry")
		Fx.hit_landed.emit("parry", global_position)
	elif age < 0.38:  # late dodge, just evaded
		if _style():
			_style().add("dodge")
	else:
		p.take_hit(to / dist)


## Called by the hero when a punch connects. kind: jab / cross / counter / slam.
func take_hit(dir: Vector3, kind: String) -> void:
	if state == DOWN:
		return
	dir.y = 0.0
	dir = dir.normalized()
	match kind:
		"jab":
			hp -= 1
			velocity = dir * 3.0
			_play("Hit_Chest", 0.04, 1.5)
			_flash_white(Color(1, 1, 1), 1.6)
		"cross":
			hp -= 2
			velocity = dir * 5.0
			_play("Hit_Head", 0.04, 1.5)
			_flash_white(Color(1, 1, 1), 2.0)
		"counter":  # a counter-hit always knocks the enemy down
			hp = 0
			velocity = dir * 6.0
			_play("Hit_Head", 0.03, 1.8)
			_flash_white(Color(0.4, 1.0, 1.0), 2.4)
		"slam":
			hp = 0
			velocity = dir * 7.5 + Vector3.UP * 2.0
			_flash_white(Color(1.0, 0.5, 0.2), 2.6)
	if hp <= 0:
		_die(kind)
	else:
		_enter(FLINCH)


func _die(cause: String) -> void:
	_enter(DOWN)
	_play("Death01", 0.08, 1.3)
	if _style():
		if cause == "slam":
			_style().add("slam")
		elif cause != "counter":  # the hero already scored the counter itself
			_style().add("takedown")


func _respawn() -> void:
	global_position = _spawn
	velocity = Vector3.ZERO
	hp = max_hp
	_enter(IDLE)
	_play("Idle", 0.15)


func _enter(s: int) -> void:
	state = s
	_state_t = 0.0


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)


func _face_player(delta: float) -> void:
	var p := _player()
	if p:
		_face_dir(p.global_position - global_position, delta)


func _face_dir(dir: Vector3, delta: float = 1.0e9) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	_body.rotation.y = rotate_toward(_body.rotation.y, want, 6.0 * delta)


func _flash_white(color: Color, energy: float) -> void:
	_flash_color = color
	_flash = energy


func _pulse(color: Color, energy: float) -> void:
	_flash_color = color
	_flash = energy


func _apply_flash(delta: float) -> void:
	if state != TELEGRAPH:  # the telegraph pulse drives the brightness
		_flash = maxf(_flash - 6.0 * delta, 0.0)
	for m in _mats:
		m.emission = _flash_color
		m.emission_energy_multiplier = _flash


func _play(anim_name: String, blend: float = 0.25, speed := 1.0) -> void:
	if _anim.current_animation != anim_name:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, blend)
		_anim.speed_scale = speed


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _style() -> Node:
	return get_tree().get_first_node_in_group("style")
