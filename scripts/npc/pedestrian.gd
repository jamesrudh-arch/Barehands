extends CharacterBody3D
const CLS_NightLook := preload("res://scripts/world/night_look.gd")

## A PEDESTRIAN (overhaul S5.3): the street's background life on the
## same cast bundles as the hero and the thug - realistic humans,
## the one-time UAL bakes (instant load), the same idle/walk blend
## tree. The routine is honest and legible: WALK a sidewalk stretch,
## IDLE a beat (watching the street), FLEE when trouble gets close
## (any thug within earshot sends them sprinting the other way).
## Group "pedestrian" - deliberately NOT "npc", so the hero's punch
## cone (a group query) never touches them: the street's bystanders
## are scenery with instincts, not heavy bags.

const RIGS := [
	{
		"cast": "res://assets/native/cast_michelle.tscn",
		"bake": "res://assets/native/ual_baked_michelle.res",
	},
	{
		"cast": "res://assets/native/cast_soldier.tscn",
		"bake": "res://assets/native/ual_baked_soldier.res",
	},
]

# the tree's clip names -> UAL sources (the KayKit-era convention)
const ALIASES := {
	"Idle_A": "Idle_Loop",
	"Idle_B": "Idle_Talking_Loop",
	"walking_a": "Walk_Loop",
	"running_a": "Sprint_Loop",
}

enum State { WALK, IDLE, FLEE }

const WALK := 1.35
const RUN := 3.4
const GRAVITY := 18.0
const FLEE_R := 6.5

var state: State = State.WALK
var _t := 0.0
var _vel_y := 0.0
var _lane_z := 4.9
var _dir := 1.0
var _target_x := 0.0
var _rig: Node3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _blend := 0.0
var _tint := Color.WHITE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("pedestrian")
	_rng.randomize()
	_lane_z = _lane_z if _rng.randf() < 0.5 else -_lane_z
	_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_target_x = _dir * _rng.randf_range(8.0, 46.0)
	# the cast: alternate Michelle/Soldier, tinted Michelle for
	# crowd variety (the same face beats a plastic crowd)
	var pick: int = _rng.randi() % RIGS.size()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.75
	col.shape = shape
	col.position = Vector3(0, 0.87, 0)
	collision_layer = 4  # solid to the hero, but the cone ignores us
	collision_mask = 1   # the ground
	add_child(col)
	var packed: PackedScene = load(RIGS[pick]["cast"])
	if packed == null:
		queue_free()
		return
	_rig = packed.instantiate()
	_rig.name = "Rig"
	add_child(_rig)
	if pick == 0:
		_tint = Color.from_hsv(_rng.randf(), 0.22, randf_range(0.75, 1.0))
		_apply_tint(_rig, _tint)
	var skel: Skeleton3D = _find(_rig, Skeleton3D)
	CLS_NightLook.blob(self, 0.5)
	_anim = _find(_rig, AnimationPlayer)
	if _anim == null and skel != null:
		_anim = AnimationPlayer.new()
		_anim.name = "Anim"
		_rig.add_child(_anim)
	if _anim and skel:
		_anim.root_node = _anim.get_path_to(_rig)
		var lib := load("res://scripts/player/ual_lib.gd")
		var n: int = lib.install(_anim, skel, RIGS[pick]["bake"],
				ALIASES)
		if n < 40:
			push_error("Pedestrian: bake install failed (%d)" % n)
		_build_tree()
	_play("ambient/Idle_A")


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		_vel_y -= GRAVITY * delta
	var hvel := Vector3.ZERO
	# trouble check: any thug within earshot sends us running
	if state != State.FLEE:
		for e in get_tree().get_nodes_in_group("enemy"):
			var en := e as Node3D
			if en != null and is_instance_valid(en) \
					and global_position.distance_to(en.global_position) \
					< FLEE_R:
				_flee_from(en.global_position)
				break
	match state:
		State.WALK:
			hvel = _step_towards(Vector3(_target_x, 0, _lane_z),
					WALK, delta)
			if absf(global_position.x - _target_x) < 0.6:
				_be_idle()
		State.IDLE:
			if _t > _idle_len:
				_new_stretch()
		State.FLEE:
			hvel = _flee_vel
			_play_run()
			if _t > 4.0:
				_be_idle()
	velocity = Vector3(hvel.x, _vel_y, hvel.z)
	move_and_slide()
	_blend = clampf(_blend + (1.0 if hvel.length() > 0.2 else -1.0) \
			* delta * 3.0, 0.0, 1.0)
	if _tree:
		_tree.set("parameters/blend/blend_amount", _blend)
	# face the walk direction
	if hvel.length() > 0.2:
		_yaw_towards(hvel)


var _idle_len := 2.0
var _flee_vel := Vector3.ZERO


func _be_idle() -> void:
	state = State.IDLE
	_t = 0.0
	_idle_len = _rng.randf_range(2.0, 6.0)
	_play("ambient/Idle_A" if _rng.randf() < 0.7
			else "ambient/Idle_B")


func _new_stretch() -> void:
	state = State.WALK
	_t = 0.0
	# back to the walk clip if we fled
	if _tree and _tree.active \
			and _anim.has_animation("ambient/walking_a"):
		_swap_walk_clip("ambient/walking_a")
	_dir = -_dir if _rng.randf() < 0.7 else _dir
	_target_x = clampf(_dir * _rng.randf_range(8.0, 46.0), -52.0, 30.0)


func _flee_from(danger: Vector3) -> void:
	state = State.FLEE
	_t = 0.0
	var away := global_position - danger
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(_dir, 0, 0)
	_flee_vel = away.normalized() * RUN
	if absf(_flee_vel.x) < 0.5:
		_flee_vel.x = _dir * RUN
	_play_run()


func _step_towards(target: Vector3, speed: float,
		delta: float) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return Vector3.ZERO
	return to.normalized() * speed


## FLEE speed: swap the tree's walk node to the sprint clip (the
## tree owns the player while active - a direct _anim.play fights
## it frame by frame; the parameter path is the sanctioned swap).
func _play_run() -> void:
	if _tree and _tree.active \
			and _anim.has_animation("ambient/running_a"):
		_swap_walk_clip("ambient/running_a")
		_blend = 1.0
	elif _anim and _anim.has_animation("ambient/running_a") \
			and not _tree:
		if String(_anim.current_animation) != "ambient/running_a":
			_anim.play("ambient/running_a")


func _yaw_towards(v: Vector3) -> void:
	rotation.y = atan2(v.x, v.z)


func _play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _tree and _tree.active:
		return  # the tree owns idle/walk; _play is for treeless rigs
	if String(_anim.current_animation) != clip:
		_anim.stop()
		_anim.play(clip)


## The locomotion tree: idle <-> walk (the enemy's chained-Blend2
## pattern; the FLEE blend leans on the same walk amount for now -
## the sprint clip swaps in via _play_run when the tree is idle).
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


## The clip swap law (probe-caught): the tree parameter path
## 'parameters/<node>/animation' is a SILENT NO-OP - the blend
## tree's own node is the writable target.
func _swap_walk_clip(clip: String) -> void:
	var bt := _tree.tree_root as AnimationNodeBlendTree
	if bt == null:
		return
	var node := bt.get_node("walk") as AnimationNodeAnimation
	if node:
		node.animation = StringName(clip)  # a StringName clip id


func _first(keys: Array) -> StringName:
	for an in _anim.get_animation_list():
		var s := str(an).to_lower()
		for k in keys:
			if k in s:
				return StringName(str(an))
	return &""


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


## Per-instance clothing tint: OVERRIDE materials on the mesh
## instance (surface_set_material would mutate the SHARED mesh -
## every Michelle in the crowd wears the same jacket - probe-caught
## law of shared resources; overrides are per-instance).
func _apply_tint(rig: Node, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s_idx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s_idx)
			if mat is StandardMaterial3D:
				var clone: StandardMaterial3D = \
						(mat as StandardMaterial3D).duplicate()
				clone.albedo_color = tint
				(mi as MeshInstance3D).set_surface_override_material(
						s_idx, clone)
