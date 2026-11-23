extends CharacterBody3D

## THE HERO (overhaul S5.1): a realistic, rigged, animated
## protagonist on the Ready Player Me rig (the Mixamo skeleton
## family). The visual rig is the native bundled character
## (assets/native/hero_rpm.tscn, no import cache needed); this
## script owns movement, the locomotion AnimationTree, and the
## action surface (the InputMap is the single input truth —
## keyboard/controller actions, with the touch UI feeding analog
## sticks in directly).
##
## Locomotion: idle <-> walk <-> run blended by speed; crouch blend;
## jump physics. Combat SWING clips ride the KayKit family through
## kaykit_lib on the training rigs; on this rig the bespoke combat
## clips land with the UAL retarget (S5.1b) - attacks fire, hit and
## land meanwhile (combat._play_clip no-ops missing clips).

const CLS_MixamoLib := preload("res://scripts/player/mixamo_lib.gd")
const CLS_UALLib := preload("res://scripts/player/ual_lib.gd")
const CLS_Combat := preload("res://scripts/player/combat.gd")
const CLS_Gun := preload("res://scripts/player/gun.gd")
const RIG := "res://assets/native/hero_rpm.tscn"

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
var hp := 100.0                  # the health the enemies chew (step 11)
const MAX_HP := 100.0
const DEATH_SERVICE := 50.0      # DEBT=DEATH: the clinic's price

var _rig: Node3D = null
var _skel: Skeleton3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _yaw := 0.0
var _vel_y := 0.0
var _grounded := true
var _combat: Node = null
var _gun: Node = null


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
	# mask 1|2: the world AND the parked cars hold the hero up
	collision_mask = 3
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
		var shared: int = CLS_MixamoLib.install(_anim, _skel)
		if shared < 4:
			push_error("Hero: the Mixamo share failed (%d clips)" % shared)
		# S5.1b: the UAL library (43 mocap clips, world-frame
		# transferred via the one-time bake - the punch gate is
		# GREEN: guard/extension/recovery all read as a real jab)
		var ual: int = CLS_UALLib.install(_anim, _skel)
		if ual < 40:
			push_error("Hero: the UAL retarget failed (%d clips)" % ual)


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
	_gun = CLS_Gun.new()
	_gun.name = "Gun"
	add_child(_gun)
	_gun.mount(self, _anim, _tree, _rig)
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
	# the water and the void: below the world is death, same as the
	# harbour walk-off (the docks' water has no floor)
	if global_position.y < -6.0:
		die("the water")
	_var_stick_processing(delta)


func _var_stick_processing(delta: float) -> void:
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
	if _gun and _gun.drawn:
		max_speed *= CLS_Gun.SPEED_SCALE  # the aimed shuffle
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
			"sprint", "jump", "lock", "style", "super", "phone", "draw"]:
		if Input.is_action_just_pressed(action):
			last_action = action
			if action == "draw" and _gun:
				_gun.toggle()
			elif action == "grab":
				# GRAB at the fence pays the scrub (police.gd owns
				# the law; anywhere else it stays GRAB)
				var paid := false
				for p in get_tree().get_nodes_in_group("police"):
					if p.try_fence(self):
						paid = true
						break
				if not paid:
					face_action.emit(action)
			elif action == "punch" and _gun and _gun.drawn:
				_gun.fire()
			elif action == "heavy" and _gun and _gun.drawn:
				_gun.reload()
			elif action == "style" and _combat:
				_cycle_style()
			elif action == "dodge":
				# B at a CAR enters it; at a door it answers the door
				# law instead of dodging (the combat-priority rule
				# returns with enemies)
				if _try_vehicle():
					return
				if Doors.context_verb(global_position) != "" \
						and Doors.try_nearest(self):
					return
				face_action.emit(action)
			else:
				face_action.emit(action)
			break


func context_verb() -> String:
	# THE B-CONTEXT LAW: a car at arm's reach answers first, then a
	# registered door (OPEN/TRY/BREAK/LOOK); swinging or mid-fight
	# it stays DODGE
	if _combat and (_combat.swinging() or _combat.guarding()):
		return ""
	for v in get_tree().get_nodes_in_group("vehicle"):
		var vn := v as Node3D
		if vn == null or not is_instance_valid(vn):
			continue
		if vn.global_position.distance_to(global_position) < 3.0 \
				and v.has_method("verb_for"):
			return str(v.call("verb_for", self))
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


## B at a car: enter it (the car's try_use mounts the hero).
func _try_vehicle() -> bool:
	for v in get_tree().get_nodes_in_group("vehicle"):
		var vn := v as Node3D
		if vn == null or not is_instance_valid(vn):
			continue
		if vn.global_position.distance_to(global_position) < 3.0 \
				and v.has_method("try_use"):
			v.call("try_use", self)
			return true
	return false


## The enemy's swing lands (combat.gd calls this through the AI).
func take_damage(damage: float, from_dir: Vector3) -> void:
	hp = maxf(hp - damage, 0.0)
	velocity += from_dir.normalized() * 3.0
	Haptics.fire("down" if hp <= 0.0 else "heavy")
	Sound.play("body_med_0", -6.0, 1.1)
	if hp <= 0.0:
		die("a beating")


## DEBT=DEATH (the clinic's sign, the story's rule): dying costs
## the service fee and puts you back on your feet at the area's
## start spawn.
func die(cause: String) -> void:
	WorldState.bump("debt", DEATH_SERVICE)
	WorldState.bump("heat", 6.0)
	hp = MAX_HP
	var area := get_tree().current_scene
	var spawn: Node3D = null
	if area:
		spawn = area.get_node_or_null("SpawnStart") as Node3D
		if spawn == null:
			# any spawn marker: the area's first Spawn* node
			for c in area.get_children():
				if str(c.name).begins_with("Spawn"):
					spawn = c as Node3D
					break
	if spawn:
		global_position = spawn.global_position
	velocity = Vector3.ZERO
	_vel_y = 0.0
	Fx.emit_hit("slip", global_position + Vector3.UP)
	Log.info("Hero: down (%s) - the clinic's fee lands on the debt" % cause)
