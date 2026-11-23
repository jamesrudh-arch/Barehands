extends Node

## THE COMBAT CORE (rebuild step 5): the attack state machine on the
## hero. X punch chain / Y heavy / A kick / B dodge (i-frames) / hold
## GUARD, behind the current style's data tables - the buttons stay
## constant, the five styles change the moves. Hits land on group
## "train_target" (the bag, the dummy; NPCs join at their step) with
## damage, knockback, haptics, audio, meter gain and SELECTIVE
## hitstop (the attacker's and the target's animation pause - never
## the engine clock). The Leverage Strike meter and the Style Rank
## live here; the HUD reads them at step 8.

const STYLES := {
	"brawler": "res://data/styles/brawler.tres",
	"kickboxing": "res://data/styles/kickboxing.tres",
	"grappling": "res://data/styles/grappling.tres",
	"drunken": "res://data/styles/drunken.tres",
	"weapon": "res://data/styles/weapon.tres",
}

enum Phase { IDLE, STARTUP, ACTIVE, RECOVER, DODGE, GUARD }

const DODGE_S := 0.34
const DODGE_IFRAMES_S := 0.22
const DODGE_SPEED := 6.5
const CHAIN_RESET_S := 0.9
const METER_MAX := 100.0
const FINISHER_COST := 40.0

signal hit_landed(target: Node, damage: float)
signal style_changed(id: String)

var phase: Phase = Phase.IDLE
var style_id := "brawler"
var style: Resource = null
var meter := 0.0            # the Leverage Strike meter
var rank := 0               # Style Rank: 0..4 (D..S)
var combo_count := 0

var _hero: CharacterBody3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _attack: Resource = null  # the live AttackData
var _chain := 0               # punch chain position 0..2
var _t := 0.0
var _hit_done := false
var _chain_gap := 0.0
var _rank_decay := 0.0
var _dodge_dir := Vector3.ZERO
var _hitstop_s := 0.0
var _hitstop_paused := false


func _ready() -> void:
	name = "Combat"
	_hero = get_parent() as CharacterBody3D
	set_style("brawler")


func set_style(id: String) -> void:
	if not STYLES.has(id):
		return
	style = load(STYLES[id])
	if style == null:
		return
	style_id = id
	_chain = 0
	style_changed.emit(id)
	# the stance reads on the idle blend: swap the tree's idle clip
	# (AnimationNodeBlendTree is a Resource: has_node/get_node, not
	# the Node variants)
	if _tree and _anim and _anim.has_animation(style.stance_clip) 			and _tree.tree_root.has_node("idle"):
		var idle_node: AnimationNode = _tree.tree_root.get_node("idle")
		if idle_node is AnimationNodeAnimation:
			idle_node.animation = style.stance_clip


func mount(anim: AnimationPlayer, tree: AnimationTree) -> void:
	_anim = anim
	_tree = tree


func _process(delta: float) -> void:
	_t += delta
	# chain reset: the punch chain falls back after a quiet beat
	if phase == Phase.IDLE:
		_chain_gap += delta
		if _chain_gap > CHAIN_RESET_S:
			_chain = 0
	# rank decay: the style rank fades without hits
	if rank > 0:
		_rank_decay += delta
		if _rank_decay > 4.0:
			rank -= 1
			_rank_decay = 0.0
	# selective hitstop: freeze OUR animation only (never the clock)
	if _hitstop_s > 0.0:
		_hitstop_s -= delta
		if _anim and not _hitstop_paused:
			_anim.pause()
			_hitstop_paused = true
		return
	if _hitstop_paused:
		_hitstop_paused = false
		if _anim:
			_anim.play()
	match phase:
		Phase.STARTUP:
			if _t >= _attack.startup_s:
				phase = Phase.ACTIVE
				_t = 0.0
				_hit_done = false
				Log.info("CBT trace: ->ACTIVE %s at t=%.3f" % [
						_attack.id, _t])
		Phase.ACTIVE:
			if not _hit_done:
				_try_hit()
			if _t >= _attack.active_s:
				phase = Phase.RECOVER
				_t = 0.0
		Phase.RECOVER:
			if _t >= _attack.recover_s:
				_finish_attack()
		Phase.DODGE:
			if _hero:
				_hero.velocity.x = _dodge_dir.x * DODGE_SPEED
				_hero.velocity.z = _dodge_dir.z * DODGE_SPEED
			if _t >= DODGE_S:
				phase = Phase.IDLE
				_restore_tree()


## The input surface (the hero's face_action signal lands here).
func on_action(action: String) -> void:
	if _hero == null:
		return
	match action:
		"punch":
			_start_attack(_chain_attack())
		"heavy":
			_start_attack(style.heavy)
		"kick":
			_start_attack(style.kick)
		"dodge":
			_start_dodge()
		"guard":
			_start_guard()
		"super":
			_try_finisher()


func _chain_attack() -> Resource:
	_chain_gap = 0.0
	var atk: Resource = null
	match _chain:
		0:
			atk = style.punch_1
		1:
			atk = style.punch_2
		2:
			atk = style.punch_3
	_chain = (_chain + 1) % 3
	return atk


func _start_attack(atk: Resource) -> void:
	if atk == null:
		return
	# cancels: a new attack may enter during RECOVER after its cancel
	# point; never during STARTUP/ACTIVE
	if phase in [Phase.STARTUP, Phase.ACTIVE]:
		return
	if phase == Phase.RECOVER and _t < _attack.cancel_from_s:
		return
	if phase == Phase.DODGE and _t < DODGE_IFRAMES_S * 0.5:
		return
	_attack = atk
	phase = Phase.STARTUP
	_t = 0.0
	_hit_done = false
	_play_clip(atk.clip)
	# the lunge: a small push along the visual rig's facing
	# (the KayKit model's authored forward is +Z at rig yaw 0)
	if _hero:
		var rig := _hero.get_node_or_null("Rig") as Node3D
		var yaw := rig.rotation.y if rig else 0.0
		var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
		_hero.velocity.x = fwd.x * 2.2
		_hero.velocity.z = fwd.z * 2.2


func _start_dodge() -> void:
	if phase in [Phase.STARTUP, Phase.ACTIVE] and _t < 0.05:
		return
	if phase == Phase.DODGE:
		return
	phase = Phase.DODGE
	_t = 0.0
	# dodge toward the stick (or backward off nothing)
	var v := Vector2.ZERO
	if _hero and _hero.get("move_stick") != null:
		v = _hero.move_stick
	if v.length() < 0.2:
		v = Vector2(0, 0.8)  # a backstep
	var fwd := Vector3(0, 0, -1)
	var cam := _hero.get_viewport().get_camera_3d()
	if cam:
		var xz := cam.global_transform.basis.z
		xz.y = 0.0
		if xz.length() > 0.01:
			fwd = -xz.normalized()
	var right := fwd.cross(Vector3.UP)
	_dodge_dir = (fwd * -v.y + right * v.x).normalized()
	var clip := "posture/Dodge_Backward"
	if v.length() >= 0.2:
		clip = "posture/Dodge_Forward" if absf(v.y) > absf(v.x) \
				else ("posture/Dodge_Right" if v.x > 0 else "posture/Dodge_Left")
	_play_clip(StringName(clip))
	Haptics.fire("parry")


func _start_guard() -> void:
	if phase in [Phase.STARTUP, Phase.ACTIVE]:
		return
	phase = Phase.GUARD
	_play_clip("combat/Melee_Blocking")


func release_guard() -> void:
	if phase == Phase.GUARD:
		phase = Phase.IDLE
		_restore_tree()


func _try_finisher() -> void:
	if meter < FINISHER_COST or phase in [Phase.STARTUP, Phase.ACTIVE]:
		return
	meter -= FINISHER_COST
	_start_attack(style.finisher)


func _play_clip(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _tree:
		_tree.active = false
	_anim.stop()
	_anim.play(clip)


func _restore_tree() -> void:
	if _tree:
		_tree.active = true
	if _anim:
		_anim.stop()


func _finish_attack() -> void:
	phase = Phase.IDLE
	_t = 0.0
	_restore_tree()
	# the stance clip: re-point the idle node per style (a style swap
	# during the attack re-targets on the next attack)
	if _tree and _anim:
		_tree.active = true


## The hit: a frontal cone sweep against the live targets.
func _try_hit() -> void:
	if _attack == null or _hero == null:
		return
	var rig := _hero.get_node_or_null("Rig") as Node3D
	var yaw := rig.rotation.y if rig else 0.0
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var from := _hero.global_position + Vector3.UP * 1.1
	var landed := 0
	for target in get_tree().get_nodes_in_group("train_target"):
		var n := target as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var to := n.global_position + Vector3.UP * 1.1 - from
		if to.length() > _attack.reach:
			continue
		if to.length() > 0.01 and fwd.angle_to(to.normalized()) > _attack.arc:
			continue
		if not n.has_method("take_hit"):
			continue
		n.take_hit(float(_attack.damage), float(_attack.knockback), fwd,
				float(_attack.posture_damage))
		landed += 1
		hit_landed.emit(n, float(_attack.damage))
		# the mission module listens for its beats (M0: hit the bag)
		var missions := get_tree().get_first_node_in_group("missions")
		if missions and missions.has_method("note_hit"):
			missions.note_hit(n)
	_hit_done = true
	if landed > 0:
		combo_count += 1
		meter = minf(meter + float(_attack.meter_gain), METER_MAX)
		if rank < 4 and combo_count % 4 == 0:
			rank += 1
		_rank_decay = 0.0
		Haptics.fire(_attack.haptic)
		for layer in _attack.audio_layers:
			Sound.play(layer, -3.0)
		Fx.emit_hit("kick", from + fwd * 1.2)
		_hitstop_s = 0.05  # the selective freeze, attacker only
	else:
		Sound.play("cloth_2", -12.0, 1.2)  # the whiff


## A dodge's i-frames (read by the damage path when enemies land).
func dodging() -> bool:
	return phase == Phase.DODGE and _t < DODGE_IFRAMES_S


## True while a swing owns the body (the hero locks stick movement).
func swinging() -> bool:
	return phase in [Phase.STARTUP, Phase.ACTIVE]


func guarding() -> bool:
	return phase == Phase.GUARD
