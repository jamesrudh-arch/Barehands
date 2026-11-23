extends CharacterBody3D

## AN ENEMY (rebuild step 11): the street's muscle on the proven
## KayKit pipeline. The AI is honest and readable - the player must
## SEE what is coming: ALERT (spots the hero), APPROACH (walks in),
## TELEGRAPH (the wind-up, a visible lean + audio cue), SWING (the
## hit window - dodging it with B's i-frames works), RECOVER, and
## the receiving side: HITSTUN on the hero's hits, POSTURE that
## breaks, DOWNED when hp empties (the Death_A clip, then back up at
## quarter health after a beat - the street does not stay empty).
## Group "npc"; the combat core's cone hits anything in it.

const RIG := "res://assets/native/thug_kaykit_barbarian.tscn"
const CLS_KayKitLib := preload("res://scripts/player/kaykit_lib.gd")

enum State { IDLE, ALERT, APPROACH, TELEGRAPH, SWING, RECOVER,
		HITSTUN, DOWNED }

const WALK := 2.6
const GRAVITY := 18.0
const SPOT_R := 11.0
const ATTACK_R := 1.9
const TELEGRAPH_S := 0.45
const SWING_S := 0.18
const RECOVER_S := 0.75
const HITSTUN_S := 0.35
const DOWN_S := 5.0
const DAMAGE := 8.0
const MAX_HP := 40.0
const POSTURE_MAX := 8.0

var state: State = State.IDLE
var hp := MAX_HP
var posture := POSTURE_MAX
var _t := 0.0
var _vel_y := 0.0
var _yaw := 0.0
var _rig: Node3D = null
var _skel: Skeleton3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _hero: CharacterBody3D = null
var _swing_hit := false  # one swing, one hit (no per-frame multi-hits)


func _ready() -> void:
	add_to_group("npc")
	add_to_group("enemy")
	name = "Thug"
	var col := CollisionShape3D.new()
	col.name = "BodyShape"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.8
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	collision_layer = 4  # its own layer: the hero's sword-cone is a
	# query, not a collider; the world is 1, cars 2, enemies 4
	collision_mask = 1  # the ground
	add_child(col)
	var packed: PackedScene = load(RIG)
	if packed:
		_rig = packed.instantiate()
		_rig.name = "Rig"
		add_child(_rig)
		_skel = _find(_rig, Skeleton3D) as Skeleton3D
		_anim = _find(_rig, AnimationPlayer) as AnimationPlayer
		if _anim:
			_anim.root_node = _anim.get_path_to(_rig)
		if _anim and _skel:
			var shared: int = CLS_KayKitLib.install(_anim, _skel)
			if shared < 4:
				push_error("Thug: the share failed (%d)" % shared)
		_build_tree()
	_play("ambient/Idle_A")


## The locomotion tree: idle <-> walk, the same chained-Blend2
## pattern the hero uses.
func _build_tree() -> void:
	if _anim == null:
		return
	_tree = AnimationTree.new()
	_tree.name = "Locomotion"
	_rig.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	var root := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = _first(["idle_a"])
	var walk := AnimationNodeAnimation.new()
	walk.animation = _first(["walking_a"])
	var b := AnimationNodeBlend2.new()
	root.add_node("idle", idle)
	root.add_node("walk", walk)
	root.add_node("blend", b)
	root.connect_node("blend", 0, "idle")
	root.connect_node("blend", 1, "walk")
	root.connect_node("output", 0, "blend")
	_tree.tree_root = root
	_tree.active = true


func _first(keys: Array) -> StringName:
	for an in _anim.get_animation_list():
		var s := str(an).to_lower()
		for k in keys:
			if k in s:
				return StringName(str(an))
	for an in _anim.get_animation_list():
		return an
	return &""


func _play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _tree:
		_tree.active = false
	_anim.stop()
	_anim.play(clip)


func _process(delta: float) -> void:
	_t += delta
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") \
				as CharacterBody3D
	if _hero == null:
		return
	var to_hero := _hero.global_position - global_position
	to_hero.y = 0.0
	var dist := to_hero.length()
	# gravity
	if is_on_floor():
		_vel_y = 0.0
	else:
		_vel_y -= GRAVITY * delta
	match state:
		State.IDLE:
			if dist < SPOT_R:
				state = State.ALERT
				_t = 0.0
				_play("ambient/Idle_B")  # the head comes up
		State.ALERT:
			_face(to_hero, delta)
			if _t > 0.4:
				state = State.APPROACH
				_t = 0.0
				if _tree:
					_tree.active = true
					_tree.set("parameters/blend/blend_amount", 1.0)
		State.APPROACH:
			_face(to_hero, delta)
			if dist > ATTACK_R:
				var dir := to_hero.normalized()
				velocity = dir * WALK
				move_and_slide()
			else:
				state = State.TELEGRAPH
				_t = 0.0
				velocity = Vector3.ZERO
				_play("combat/Melee_Unarmed_Idle")
				# THE TELEGRAPH: the lean + the cue the player reads
				Sound.play("cloth_2", -10.0, 0.7)
		State.TELEGRAPH:
			_face(to_hero, delta)
			if _t >= TELEGRAPH_S:
				state = State.SWING
				_t = 0.0
				_swing_hit = false
				_play("combat/Melee_Unarmed_Attack_Punch_A")
				Sound.play("punch_med_1", -8.0, 0.85)
		State.SWING:
			if not _swing_hit and _t >= SWING_S * 0.5 \
					and dist <= ATTACK_R + 0.4:
				_try_hit_hero()
			if _t >= SWING_S:
				state = State.RECOVER
				_t = 0.0
		State.RECOVER:
			if _t >= RECOVER_S:
				state = State.APPROACH if dist > ATTACK_R \
						else State.TELEGRAPH
				_t = 0.0
				if state == State.APPROACH and _tree:
					_tree.active = true
					_tree.set("parameters/blend/blend_amount", 1.0)
		State.HITSTUN:
			if _t >= HITSTUN_S:
				state = State.APPROACH if dist > ATTACK_R \
						else State.TELEGRAPH
				_t = 0.0
				if _tree:
					_tree.active = true
					_tree.set("parameters/blend/blend_amount", 1.0)
		State.DOWNED:
			if _t >= DOWN_S:
				hp = MAX_HP * 0.25
				posture = POSTURE_MAX
				state = State.IDLE
				_t = 0.0
				_play("ambient/Idle_A")


## The swing's hit: a cone check the hero can DODGE (the i-frames).
func _try_hit_hero() -> void:
	_swing_hit = true
	var to := _hero.global_position - global_position
	to.y = 0.0
	if to.length() > ATTACK_R + 0.5:
		return
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, _yaw)
	if fwd.angle_to(to.normalized()) > 1.1:
		return
	# the hero's combat layer answers for the dodge i-frames
	var combat := _hero.get_node_or_null("Combat")
	if combat and combat.has_method("dodging") \
			and combat.call("dodging"):
		Sound.play("cloth_2", -8.0, 1.4)  # the whiff past the ear
		return
	if _hero.has_method("take_damage"):
		_hero.call("take_damage", DAMAGE, fwd)


func _face(to: Vector3, delta: float) -> void:
	if to.length() < 0.05:
		return
	var want := atan2(to.x, to.z)
	_yaw = lerp_angle(_yaw, want, 8.0 * delta)
	if _rig:
		_rig.rotation.y = _yaw + PI  # the model faces +Z at yaw 0


## The combat core calls this (same contract as the train targets).
func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:
	if state == State.DOWNED:
		return
	hp -= damage
	posture -= posture_damage
	state = State.HITSTUN
	_t = 0.0
	velocity = from_dir.normalized() * knockback
	move_and_slide()
	_play("ambient/Hit_A" if hp > MAX_HP * 0.4 else "ambient/Hit_B")
	Sound.play("body_med_0", -4.0, randf_range(0.9, 1.1))
	if posture <= 0.0:
		posture = POSTURE_MAX
		state = State.HITSTUN
		_t = -0.3  # the break stuns longer
		hp -= 4.0
	if hp <= 0.0:
		state = State.DOWNED
		_t = 0.0
		_play("ambient/Death_A")
		Sound.play("body_heavy_0", -3.0, 0.8)
		WorldState.bump("heat", 4.0)  # the street saw it


func _find(root_n: Node, what) -> Node:
	if root_n == null:
		return null
	if is_instance_of(root_n, what):
		return root_n
	for c in root_n.get_children():
		var f := _find(c, what)
		if f:
			return f
	return null
