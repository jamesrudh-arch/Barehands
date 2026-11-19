class_name Enemy
extends CharacterBody3D
## Series-2 enemies on the pack's mannequin. kind 0 = training dummy (reacts
## only), 1 = brawler (the classic thug rhythm), 2 = armoured bruiser (light
## hits bounce off: force heavies, pipes and finishers), 3 = knife attacker
## (fast, short telegraph, lunging strike), 4 = boss (big, armoured, three-
## hit combos). Group behaviour comes from the Tactics autoload: enemies
## take surround slots around the hero and only one attacks at a time.

const GRAVITY := 22.0
const STRIKE_RANGE := 1.7
const RECOVER_TIME := 1.3
const RESPAWN_TIME := 2.6

enum State { IDLE, WALK, TELEGRAPH, STRIKE, RECOVER, FLINCH, STAGGER, DOWN, GRABBED, LAUNCHED }

@export var kind := 0  # 0 dummy, 1 brawler, 2 bruiser, 3 knife, 4 boss
@export var max_hp := 5

var state: State = State.IDLE
var hp := 1
var _t := 0.0
var _state_t := 0.0
var _spawn := Vector3.ZERO
var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _flash_color := Color(1, 1, 1)
var _edge := 0.0          # the intended per-kind silhouette glow
var _edge_color := Color(1, 1, 1)
var _struck := false
var _topple := 0.0
# posture (Batch 2, bible 4A): fills from landed hits and parries; at the
# cap the enemy BREAKS - a long gold stagger that opens the finisher.
var posture := 0.0
var _posture_at := 0  # msec of the last posture damage (regen delay)
var _posture_break := false
var _stagger_dur := 1.4
var _posture_fill: MeshInstance3D = null  # billboard gold bar
var _combo_step := 0  # boss: where in the 3-hit combo we are
var _next_is_grab := false  # boss: every third attack cycle is a grab
var _cycle := 0

# per-kind tuning: [walk speed, attack range, telegraph time, strike time, armour]
const TUNING := {
	0: [0.0, 2.0, 0.6, 0.22, 0],
	1: [1.3, 2.0, 0.6, 0.22, 0],
	2: [1.0, 2.2, 0.8, 0.28, 3],
	3: [2.6, 2.6, 0.32, 0.20, 0],
	4: [1.6, 2.4, 0.7, 0.24, 4],
}
# per-kind identity: body tint + emission edge so silhouettes read at a glance
const LOOK := {
	0: [Color(0.55, 0.55, 0.6), 0.0],
	1: [Color(0.42, 0.30, 0.24), 0.0],
	2: [Color(0.16, 0.17, 0.20), 0.06],  # gunmetal + faint edge
	3: [Color(0.20, 0.16, 0.12), 0.0],   # wiry, dark leathers
	4: [Color(0.28, 0.08, 0.10), 0.10],  # blood-red boss
}


func _ready() -> void:
	_build_posture_bar()
	add_to_group("enemy")
	hp = max_hp
	_spawn = global_position
	_own_materials()
	# P0.1 T-pose fix: an enemy that spawns beyond the 10 m think radius
	# never entered WALK, so _think's idle branch skipped it and NOTHING
	# ever called play() - the mannequin stood in the glb rest pose
	# (a T-pose) until the player walked close. Idle from the first frame,
	# wherever the enemy stands, dummy or alive.
	_play("Idle", 0.0)
	var tun: Array = TUNING[kind]
	_apply_look()
	if kind == 0:
		var p := _player()
		if p:
			_face_dir(p.global_position - global_position)
	if kind == 4:
		_body.scale = Vector3(1.28, 1.28, 1.28)
		max_hp = maxf(max_hp, 30)
		hp = max_hp
	elif kind == 2:
		_body.scale = Vector3(1.18, 1.18, 1.18)
		max_hp = maxf(max_hp, 12)
		hp = max_hp


func _apply_look() -> void:
	var look: Array = LOOK[kind]
	var tint: Color = look[0]
	var edge: float = look[1]
	_edge = edge
	_edge_color = tint * 2.5
	for m in _mats:
		m.albedo_color = m.albedo_color.lerp(tint, 0.55)
		if edge > 0.0:
			m.emission = tint * 2.5
			m.emission_energy_multiplier = edge


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


func _walk_speed() -> float:
	return TUNING[kind][0]


func _attack_range() -> float:
	return TUNING[kind][1]


func _telegraph_time() -> float:
	if kind == 4 and _combo_step > 0:
		return 0.25  # the combo links fast
	return TUNING[kind][2]


func _armour() -> int:
	return TUNING[kind][4]


func _physics_process(delta: float) -> void:
	if Fx.is_frozen(self):
		return  # selective hitstop: the target holds mid-impact
	_t += delta
	_state_t += delta
	_posture_step(delta)
	if not is_on_floor():
		# a launched enemy falls HEAVIER: a floaty arc reads as a figure
		# hovering over the HUD on the phone
		var g := GRAVITY * (1.35 if state == State.LAUNCHED else 1.0)
		velocity.y = maxf(velocity.y - g * delta, -30.0)

	match state:
		State.IDLE, State.RECOVER:
			_brake(delta)
			if kind > 0:
				_think()
			elif state == State.RECOVER and _state_t > 0.5:
				_enter(State.IDLE)
		State.WALK:
			_brake(delta)
			_think()
		State.TELEGRAPH:
			_brake(delta)
			_face_player(delta)
			var pulse := Color(1.0, 0.1, 0.08)
			if kind == 3:
				pulse = Color(1.0, 0.55, 0.1)  # the knife telegraphs fast and orange
			elif kind == 4 and _next_is_grab:
				pulse = Color(0.2, 0.9, 0.3)  # the boss grab telegraphs green
			_pulse(pulse, 0.8 + 0.5 * sin(_state_t * (30.0 if kind == 3 else 25.0)))
			if _state_t >= _telegraph_time():
				_enter(State.STRIKE)
				_play("Punch_Jab", 0.05, 2.4 if kind != 2 else 1.6)
				_struck = false
				if kind == 3:  # the knife lunges in
					var p0 := _player()
					if p0:
						var lunge := (p0.global_position - global_position)
						lunge.y = 0.0
						lunge = lunge.normalized()
						velocity.x = lunge.x * 5.0
						velocity.z = lunge.z * 5.0
						Sound.play_v("knife", 2, -6.0, 1.0, 0.06)
		State.STRIKE:
			_brake(delta)
			if not _struck and _state_t >= TUNING[kind][3]:
				_struck = true
				_resolve_strike()
			if _state_t >= 0.45:
				_enter(State.RECOVER)
				Tactics.release(self)  # token held through the whole swing
		State.FLINCH:
			_brake(delta)
			if _state_t > 0.35:
				_enter(State.IDLE if kind == 0 else State.WALK)
		State.STAGGER:
			_brake(delta)
			if _state_t > _stagger_dur:
				_enter(State.RECOVER)
		State.DOWN:
			_brake(delta)
			if _topple < 1.0:  # ragdoll-lite: keel over
				_topple = minf(_topple + delta * 2.4, 1.0)
				_body.rotation.x = -_topple * 1.45
				_body.position.y = _topple * 0.25
			if _state_t > RESPAWN_TIME:
				_respawn()
		State.GRABBED:
			_brake(delta)  # position is driven by the hero; just settle
		State.LAUNCHED:
			# airborne, no control: flailing until the ground stops it
			if is_on_floor() and _state_t > 0.2:
				Fx.burst(global_position + Vector3.UP * 0.5, Color(0.6, 0.65, 0.75))
				Sound.play("body_heavy_0", -8.0)
				_enter(State.STAGGER)
	_apply_flash(delta)
	move_and_slide()


func _think() -> void:
	var p := _player()
	if p == null:
		return
	if p.state == Player.State.GRAB:
		# someone is being held: circle at a distance
		_keep_range(p, 2.6)
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	_face_player(get_physics_process_delta_time())

	var goal: Vector3 = to / maxf(dist, 0.1)  # default: straight at the hero
	# group tactics: walk to the surround slot instead when others are near
	if kind != 4 and Tactics.slots_active(p):
		var slot: Vector3 = Tactics.slot_for(self, p)
		var to_slot := slot - global_position
		to_slot.y = 0.0
		if to_slot.length() > 0.4:
			goal = to_slot / maxf(to_slot.length(), 0.1)
		if dist <= _attack_range():
			if not Tactics.can_attack(self):
				_brake(get_physics_process_delta_time())  # wait for the token
				if state == State.WALK:
					_play("Idle", 0.2)
				return
	if dist <= _attack_range():
		if Tactics.can_attack(self) or kind == 4:
			Tactics.attack(self)
			_enter(State.TELEGRAPH)
			_play("Idle", 0.1)
		else:
			_brake(get_physics_process_delta_time())
			if state == State.WALK:
				_play("Idle", 0.2)
	elif dist < 10.0:
		if state != State.WALK:
			_enter(State.WALK)
			_play("Walk", 0.2, 1.1 * (_walk_speed() / 1.3))
		velocity.x = goal.x * _walk_speed()
		velocity.z = goal.z * _walk_speed()
	else:
		if state == State.WALK:
			_enter(State.IDLE)
			_play("Idle", 0.2)
			Tactics.release(self)


func _keep_range(p: Node3D, want: float) -> void:
	var to := global_position - p.global_position
	to.y = 0.0
	var dist := to.length()
	if dist < want - 0.4:
		velocity.x = to.x / dist * _walk_speed() * 0.6
		velocity.z = to.z / dist * _walk_speed() * 0.6
	else:
		_brake(get_physics_process_delta_time())


func _resolve_strike() -> void:
	var p := _player()
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var fwd := -_body.global_transform.basis.z
	if dist > STRIKE_RANGE + (0.9 if kind == 3 else 0.0) or \
			Vector2(fwd.x, fwd.z).dot(Vector2(to.x, to.z).normalized()) < 0.3:
		return  # whiffed (token released when the swing ends)
	var age: float = p.dodge_age()
	var block: float = p.block_age()
	if age < 0.22 or block <= 0.15:  # perfect dodge or perfect block = parry
		parried()
	elif age < 0.38:
		if _style():
			_style().add("dodge")
	else:
		var result: String = p.take_hit(to / dist, self)
		if result == "blocked":
			_enter(State.RECOVER)  # the guard held: back off and reset
		elif result == "hit":
			Fx.hit_stop(3, [self, p])  # the hero is clipped: a beat of weight
		# boss combo: chain up to three hits, then a grab cycle
		if kind == 4:
			_combo_step += 1
			if _combo_step >= 3:
				_combo_step = 0
				_cycle += 1
				_next_is_grab = _cycle % 3 == 0
	if kind == 4 and _next_is_grab and state == State.STRIKE:
		var result2: String = p.take_hit(to / dist + Vector3.UP * 0.5, self)
		if result2 == "hit":
			Fx.slow_mo(0.35, 0.5)  # the boss grab lands heavy


## Shared parry flow: the attacker is staggered, the counter window opens.
func parried() -> void:
	Fx.slow_mo(0.7, 0.35)
	_posture_gain(Tuning.v("parry_posture_damage"))
	var p := _player()
	if p:
		p.open_counter(1.3)
	_enter(State.STAGGER)
	_play("Hit_Head", 0.05, 1.5)
	_flash_white(Color(0.4, 1.0, 1.0), 2.2)
	if p:
		Fx.burst(p.global_position + Vector3.UP * 1.3, Color(0.3, 0.95, 1.0))
	if _style():
		_style().add("parry")
	Fx.camera_punch(-6.0)
	Fx.screen_flash(Color(0.35, 0.9, 1.0))
	Fx.haptic(40)
	Fx.emit_hit("parry", global_position)
	Tactics.release(self)


## Called by the hero when a hit connects. kind: jab/cross/hook/heavy/pipe/
## pipe_heavy/knee/counter/slam_*/launcher/finisher.
func take_hit(dir: Vector3, hit_kind: String) -> void:
	if state == State.DOWN or state == State.GRABBED:
		if state == State.GRABBED and hit_kind == "knee":
			hp -= 1
			_flash_white(Color(1, 1, 1), 1.4)
			velocity = dir * 0.5
			if hp <= 0:
				_die(hit_kind)
			return
		return
	dir.y = 0.0
	dir = dir.normalized()
	var dmg := _damage_of(hit_kind)
	# knockback and posture both live in res://attacks/<kind>.tres
	# (knockback: x = push, y = lift, z = lateral); the match below keeps
	# only the reaction identity - anim, flash, launches, DOWN states.
	var ad := AttackData.for_attack(hit_kind)
	var knock := ad.knockback.x
	match hit_kind:
		"jab":
			_play("Hit_Chest", 0.04, 1.5)
			_flash_white(Color(1, 1, 1), 1.6)
		"cross", "hook":
			_play("Hit_Head", 0.04, 1.5)
			_flash_white(Color(1, 1, 1), 2.0)
		"heavy", "pipe_heavy":
			_play("Hit_Head", 0.04, 1.2)
			_flash_white(Color(1, 0.9, 0.7), 2.4)
		"pipe":
			_play("Hit_Chest", 0.04, 1.3)
			_flash_white(Color(0.8, 0.85, 1.0), 2.0)
		"launcher":
			hp -= dmg
			velocity = dir * 2.5 + Vector3.UP * 6.5
			_enter(State.LAUNCHED)
			_play("Hit_Head", 0.04, 1.0)
			_flash_white(Color(0.5, 0.85, 1.0), 2.4)
			return
		"counter":
			dmg = 99
			_play("Hit_Head", 0.03, 1.8)
			_flash_white(Color(0.4, 1.0, 1.0), 2.4)
		"tap":
			_play("Hit_Chest", 0.04, 1.6)
			_flash_white(Color(1, 1, 1), 1.5)
		"kick":
			_play("Hit_Chest", 0.04, 1.4)
			_flash_white(Color(1.0, 0.85, 0.5), 2.2)
		"sweep":
			dmg = _damage_of("kick")
			velocity = dir * knock
			_enter(State.DOWN)  # dumped onto the asphalt, not dead
			_play("Hit_Chest", 0.04, 1.1)
			_flash_white(Color(0.9, 0.9, 0.9), 1.8)
			return
		"throw_slam":
			dmg = 3
			velocity = dir * knock + Vector3.UP * 2.0
			_enter(State.DOWN)
			_play("Death01", 0.05, 1.0)
			_flash_white(Color(1.0, 0.6, 0.3), 2.6)
			return
			_play("Hit_Chest", 0.04, 1.4)
			_flash_white(Color(1.0, 0.85, 0.5), 2.2)
		"backfist":
			_play("Hit_Head", 0.04, 1.9)
			_flash_white(Color(1.0, 0.85, 0.55), 2.0)
		"backfist_counter":
			_play("Hit_Head", 0.03, 1.6)
			_flash_white(Color(0.4, 1.0, 1.0), 2.6)
		"super":
			dmg = 99
			hp -= dmg
			velocity = dir * 7.5 + Vector3.UP * 5.5
			_play("Death01", 0.04, 1.1)
			_flash_white(Color(1.0, 0.5, 0.2), 3.2)
			if hp <= 0:
				_die("super")
				return
			_enter(State.LAUNCHED)
			return
		"finisher":
			dmg = 99
			_play("Hit_Head", 0.03, 0.9)
			_flash_white(Color(1.0, 0.3, 0.25), 3.0)
		"knee":
			_play("Hit_Chest", 0.04, 1.8)
			_flash_white(Color(1, 1, 1), 1.4)
		"shot":
			_play("Hit_Head", 0.04, 1.0)
			_flash_white(Color(1.0, 0.8, 0.4), 2.6)
		_:
			if hit_kind.begins_with("slam"):
				dmg = 99
				_flash_white(Color(1.0, 0.5, 0.2), 2.6)
	hp -= dmg
	# armour: light hits chip hp but never stagger the big ones
	var armoured_hit: bool = dmg < _armour() and \
			not hit_kind in ["counter", "finisher"] and not hit_kind.begins_with("slam")
	if armoured_hit:
		_flash_white(Color(0.7, 0.75, 0.85), 1.1)  # a dull clang, no reaction
		Sound.play("metal_click_0", -6.0, 1.3)
		velocity = dir * 1.2
		if hp <= 0:
			_die(hit_kind)
		return
	velocity = dir * knock
	if not armoured_hit:
		_posture_gain(ad.posture_damage)
	if hp <= 0:
		_die(hit_kind)
	elif hit_kind != "knee" and not _posture_break:
		_enter(State.FLINCH)


func _damage_of(hit_kind: String) -> int:
	return {"jab": 1, "cross": 2, "hook": 2, "heavy": 3, "counter": 99,
			"pipe": 2, "pipe_heavy": 4, "knee": 1, "launcher": 1, "shot": 6,
			"backfist": 2, "backfist_counter": 6, "kick": 2, "super": 99,
			"throw_slam": 3, "tap": 1}.get(hit_kind, 1)


func _die(cause: String) -> void:
	_enter(State.DOWN)
	Heat.on_violence("knockdown", global_position)
	_play("Death01", 0.08, 1.3)
	if cause in ["counter", "slam", "slam_wall", "slam_car", "slam_shutter", "slam_rail",
			"finisher"] or cause.begins_with("slam"):
		Fx.slow_mo(0.4, 0.45)  # short cinematic finisher beat
	if _style():
		if cause.begins_with("slam"):
			_style().add(cause)
		elif cause == "finisher":
			_style().add("finisher")
		elif cause != "counter":
			_style().add("takedown")
	Tactics.release(self)


func _respawn() -> void:
	_topple = 0.0
	_body.rotation.x = 0.0
	_body.position.y = 0.0
	global_position = _spawn
	velocity = Vector3.ZERO
	hp = max_hp
	_enter(State.IDLE)
	_play("Idle", 0.15)
	Tactics.release(self)


# --- grabbed by the hero --------------------------------------------------------


func grabbed_by(holder: CharacterBody3D) -> void:
	_enter(State.GRABBED)
	velocity = Vector3.ZERO
	_play("Hit_Chest", 0.05, 0.7)
	_face_dir(holder.global_position - global_position)
	Tactics.release(self)


## The hero releases: a throw sends us flying, a timeout just lets go.
func release_grab(dir: Vector3, speed: float) -> void:
	if speed > 0.0:
		velocity = dir * speed + Vector3.UP * 1.5
		_enter(State.LAUNCHED)
		_play("Hit_Head", 0.05, 1.2)
		Sound.play("cloth_0", -6.0)
	else:
		_enter(State.RECOVER)


func _enter(s: int) -> void:
	state = s
	_state_t = 0.0
	if s != State.STAGGER:
		_posture_break = false
		_stagger_dur = 1.4


## --- posture (Batch 2) ------------------------------------------------------------

func posture_broken() -> bool:
	return _posture_break


## Posture damage from a landed hit or a parry. At the cap: the BREAK -
## a long gold stagger that opens the finisher window.
func _posture_gain(amount: float) -> void:
	if amount <= 0.0 or state in [State.DOWN, State.GRABBED, State.LAUNCHED]:
		return
	_posture_at = Time.get_ticks_msec()
	posture = minf(posture + amount, Tuning.v("posture_max"))
	if posture >= Tuning.v("posture_max"):
		posture = 0.0
		_posture_break = true
		_stagger_dur = Tuning.v("posture_break_seconds")
		_enter(State.STAGGER)
		_play("Hit_Head", 0.05, 0.8)
		_flash_white(Color(1.0, 0.85, 0.2), 3.2)  # gold: the tell
		Sound.play("metal_ring_1", -8.0, 0.7)
		Fx.shake(0.3)
		if _style():
			_style().add("posture")
		_posture_flash_bar()


func _posture_step(delta: float) -> void:
	# the bar eases back down once nothing has threatened it for a beat -
	# slow enough that SUSTAINED pressure always reaches the break; only
	# walking away (a whiffed string, a reset) lets it drain
	if _posture_at > 0 and Time.get_ticks_msec() - _posture_at > 2500:
		posture = maxf(posture - Tuning.v("posture_regen_per_s") * delta, 0.0)
	if _posture_fill != null:
		var frac := clampf(posture / Tuning.v("posture_max"), 0.0, 1.0)
		_posture_fill.visible = frac > 0.06
		_posture_fill.scale.x = maxf(frac, 0.01)
		_posture_fill.position.x = -0.35 * (1.0 - frac)


## A brief all-bar flash as the break lands (the bar empties, so the
## flash is the cue the window opened).
func _posture_flash_bar() -> void:
	if _posture_fill == null:
		return
	var tw := create_tween()
	_posture_fill.visible = true
	_posture_fill.scale.x = 1.0
	_posture_fill.position.x = 0.0
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: _posture_fill.visible = false)


## The billboard: two unshaded quads above the head, gold fill on dark.
func _build_posture_bar() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 2.45, 0.0)
	add_child(holder)
	_bar_quad(holder, 0.74, Color(0.05, 0.05, 0.06, 0.85))
	_posture_fill = _bar_quad(holder, 0.7, Color(1.0, 0.82, 0.25))
	_posture_fill.visible = false


func _bar_quad(parent: Node, size_x: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size_x, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = color
	q.material = m
	mi.mesh = q
	parent.add_child(mi)
	return mi


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
	if state != State.TELEGRAPH:
		_flash = maxf(_flash - 6.0 * delta, 0.0)
	for m in _mats:
		if _flash > 0.0:
			m.emission = _flash_color
		else:
			m.emission = _edge_color  # the silhouette edge (faint, intended)
		m.emission_energy_multiplier = _flash + _edge


func _play(anim_name: String, blend: float = 0.25, speed := 1.0) -> void:
	if _anim.current_animation != anim_name:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, blend)
		_anim.speed_scale = speed


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _style() -> Node:
	return get_tree().get_first_node_in_group("style")


@onready var _body: Node3D = $Body
@onready var _anim: AnimationPlayer = $Body/Mannequin/AnimationPlayer
@onready var _mi: MeshInstance3D = $Body/Mannequin/Armature/Skeleton3D/Mannequin
