extends CharacterBody3D

## THE HERO (rebuild step 3): a real rigged, animated protagonist on
## the proven KayKit pipeline. The visual rig is the native bundled
## character (assets/native/hero_kaykit_rogue.tscn, no import cache
## needed); this script owns movement, the locomotion AnimationTree,
## and the action surface (the InputMap is the single input truth —
## keyboard/controller actions, with the touch UI feeding analog
## sticks in directly).
##
## Locomotion: idle <-> walk <-> run blended by speed; crouch blend;
## jump physics (the airborne clip pass lands with the combat anim
## states at step 5 - recorded in 00_DEVELOPMENT_STATE).

const CLS_KayKitLib := preload("res://scripts/player/kaykit_lib.gd")
const CLS_Combat := preload("res://scripts/player/combat.gd")
const RIG := "res://assets/native/hero_kaykit_rogue.tscn"

const WALK_SPEED := 3.1
const RUN_SPEED := 5.6
const ACCEL := 14.0
const GRAVITY := 18.0
const JUMP_VEL := 6.4
const TURN_SPEED := 11.0

## The face-button law (06_CONTROL_MAP): X punch, Y heavy, A kick,
## B dodge. Outside combat B becomes the context verb.
signal face_action(action: String)

var move_stick := Vector2.ZERO   # set by the touch UI (analog)
var crouching := false
var last_action := ""            # the debug/test hook: the last fired action

var _rig: Node3D = null
var _skel: Skeleton3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _yaw := 0.0
var _vel_y := 0.0
var _grounded := true
var _combat: Node = null


func _ready() -> void:
	add_to_group("player")
	name = "Hero"
	_build_body()
	_build_rig()
	_build_tree()


func _build_body() -> void:
	var col := CollisionShape3D.new()
	col.name = "BodyShape"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.75
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)


func _build_rig() -> void:
	var packed: PackedScene = load(RIG)
	if packed == null:
		push_error("Hero: the native rig is missing (%s)" % RIG)
		return
	_rig = packed.instantiate()
	_rig.name = "Rig"
	add_child(_rig)
	_skel = _find(_rig, Skeleton3D) as Skeleton3D
	_anim = _find(_rig, AnimationPlayer) as AnimationPlayer
	if _anim == null and _skel != null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_rig.add_child(_anim)
	if _anim:
		# ALWAYS rebase root_node: the packed native scene carries the
		# absolute path from the tree it was saved in - stale there,
		# fatal for every animation track after a re-instantiate
		_anim.root_node = _anim.get_path_to(_rig)
	if _anim and _skel:
		var shared: int = CLS_KayKitLib.install(_anim, _skel)
		if shared < 4:
			push_error("Hero: the KayKit share failed (%d clips)" % shared)


## The locomotion tree: idle --speed--> walk --speed--> run, chained
## Blend2s (the proven pattern from the step-2 proof), plus crouch as
## a third blend layer.
func _build_tree() -> void:
	if _anim == null:
		return
	_tree = AnimationTree.new()
	_tree.name = "Locomotion"
	_rig.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	var root := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = _clip("ambient", ["idle_a"])
	var walk := AnimationNodeAnimation.new()
	walk.animation = _clip("locomotion", ["walking_a"])
	var run := AnimationNodeAnimation.new()
	run.animation = _clip("locomotion", ["running_a"])
	var crouch := AnimationNodeAnimation.new()
	crouch.animation = _clip("posture", ["crouching"])
	var b_walk := AnimationNodeBlend2.new()
	var b_run := AnimationNodeBlend2.new()
	var b_crouch := AnimationNodeBlend2.new()
	root.add_node("idle", idle)
	root.add_node("walk", walk)
	root.add_node("run", run)
	root.add_node("crouch", crouch)
	root.add_node("b_walk", b_walk)
	root.add_node("b_run", b_run)
	root.add_node("b_crouch", b_crouch)
	# 4.7 connect_node(input_node, input_index, output_node): the
	# FIRST arg is the DESTINATION and its input slot, the LAST arg is
	# the SOURCE - the graph ends wired INTO the special "output"
	root.connect_node("b_walk", 0, "idle")
	root.connect_node("b_walk", 1, "walk")
	root.connect_node("b_run", 0, "b_walk")
	root.connect_node("b_run", 1, "run")
	root.connect_node("b_crouch", 0, "b_run")
	root.connect_node("b_crouch", 1, "crouch")
	root.connect_node("output", 0, "b_crouch")
	_tree.tree_root = root
	_tree.active = true
	_set_param("b_walk/blend_amount", 0.0)
	_set_param("b_run/blend_amount", 0.0)
	_set_param("b_crouch/blend_amount", 0.0)
	# the combat core rides the same player + tree
	_combat = CLS_Combat.new()
	add_child(_combat)
	_combat.mount(_anim, _tree)
	face_action.connect(func(a): _combat.on_action(a))


func _clip(lib: String, keys: Array) -> StringName:
	for an in _anim.get_animation_list():
		var s := str(an).to_lower()
		if not s.begins_with(lib + "/"):
			continue
		for k in keys:
			if k in s:
				return StringName(str(an))
	for an in _anim.get_animation_list():
		return an
	return &""


func _set_param(path: String, value: float) -> void:
	if _tree:
		_tree.set("parameters/%s" % path, value)


func _param(path: String) -> float:
	if _tree == null:
		return 0.0
	return float(_tree.get("parameters/%s" % path))


func _physics_process(delta: float) -> void:
	var stick := move_stick
	if stick == Vector2.ZERO:
		stick = Input.get_vector("move_left", "move_right",
				"move_up", "move_down")
	_actions()
	# combat owns the body during a swing; guard releases on let-go
	if _combat:
		if _combat.swinging():
			stick = Vector2.ZERO
		if _combat.guarding() and not Input.is_action_pressed("guard"):
			_combat.release_guard()
	var sprint := Input.is_action_pressed("sprint") \
			or stick.length() > 0.97  # full push = auto-sprint (the map)
	crouching = _crouch_held()
	var max_speed := RUN_SPEED if (sprint and not crouching) else WALK_SPEED
	if crouching:
		max_speed = 1.6
	# camera-relative movement
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	if cam:
		var xz := cam.global_transform.basis.z
		xz.y = 0.0
		if xz.length() > 0.01:
			fwd = -xz.normalized()
	var right := fwd.cross(Vector3.UP)
	var wish := (fwd * -stick.y + right * stick.x) * max_speed
	wish.y = 0.0
	var target := wish.length() / RUN_SPEED
	# gravity + jump
	if is_on_floor():
		_grounded = true
		_vel_y = 0.0
		if Input.is_action_just_pressed("jump"):
			_vel_y = JUMP_VEL
			_grounded = false
	else:
		_grounded = false
		_vel_y -= GRAVITY * delta
	velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta * 4.0)
	velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta * 4.0)
	velocity.y = _vel_y
	move_and_slide()
	# face the movement; blend the tree by speed
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.4:
		var want := atan2(flat.x, flat.y)
		_yaw = lerp_angle(_yaw, want, TURN_SPEED * delta)
	if _rig:
		_rig.rotation.y = _yaw
	_set_param("b_walk/blend_amount", clampf(target * 2.0, 0.0, 1.0))
	_set_param("b_run/blend_amount", clampf(target * 2.0 - 1.0, 0.0, 1.0))
	_set_param("b_crouch/blend_amount",
			1.0 if (crouching and _grounded) else 0.0)


## Crouch: the posture library clips + a slow move; the touch UI has
## no CROUCH pill yet (06 lists crouch under movement) - the keyboard
## Ctrl and the controller stick-click carry it until the HUD pass.
func _crouch_held() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or _crouch_flag


var _crouch_flag := false


func set_crouch(on: bool) -> void:
	_crouch_flag = on


## The action surface: every mapped action records itself (the test
## hook) and face actions signal the combat layer (step 5).
func _actions() -> void:
	for action in ["punch", "heavy", "kick", "dodge", "guard", "grab",
			"sprint", "jump", "lock", "style", "super", "phone"]:
		if Input.is_action_just_pressed(action):
			last_action = action
			if action == "style" and _combat:
				_cycle_style()
			elif action == "dodge":
				# B at a door answers the door law instead of dodging
				# (the combat-priority rule returns with enemies)
				if Doors.context_verb(global_position) != "" \
						and Doors.try_nearest(self):
					return
				face_action.emit(action)
			else:
				face_action.emit(action)
			break


func context_verb() -> String:
	# THE B-CONTEXT LAW: near a registered door, B answers the door
	# (OPEN/TRY/BREAK/LOOK); swinging or mid-fight it stays DODGE
	if _combat and (_combat.swinging() or _combat.guarding()):
		return ""
	return Doors.context_verb(global_position)


func _find(root: Node, what) -> Node:
	if root == null:
		return null
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var found := _find(c, what)
		if found:
			return found
	return null


## The style cycle (the hold-flick wheel lands with the HUD step;
## until then the STYLE action walks the five in order).
func _cycle_style() -> void:
	var order := ["brawler", "kickboxing", "grappling", "drunken", "weapon"]
	var i := order.find(_combat.style_id)
	_combat.set_style(order[(i + 1) % order.size()])
	Log.info("Hero: style -> %s" % _combat.style_id)
