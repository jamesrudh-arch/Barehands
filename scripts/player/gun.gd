extends Node

## THE PISTOL (S5.4): draw, aim, fire, reload - the UAL pistol set
## on the hero's own bake, a code-built noir pistol bolted to the
## right hand bone, a cone hitscan with muzzle flash + gunshot +
## knockback. The draw action toggles; while drawn the locomotion
## tree runs the aim stance and the punch button fires instead of
## swinging (the face-button law: the buttons stay constant, the
## drawn state re-points them). Lawed by every fight probe before
## it: the cone reads the RIG node's yaw, one-shot clips go through
## the tree-off/_anim.play/restore pattern, never a direct play
## against a live tree.

signal ammo_changed(in_clip: int, reserve: int)

## the market sells boxes; the HUD rides the signal
func add_reserve(n: int) -> void:
	reserve = mini(reserve + n, 72)  # three boxes: pocket limit
	ammo_changed.emit(ammo, reserve)
signal shot_landed(target: Node, damage: float)

const CLIP := 12
const DAMAGE := 26.0
const REACH := 34.0
const ARC := 0.22
const KNOCKBACK := 7.0
const POSTURE := 4.0
const SHOT_CD := 0.42
const RELOAD_S := 1.6
const SPEED_SCALE := 0.55  # the drawn walk is a aimed shuffle

var drawn := false
var ammo := CLIP
var reserve := 24

var _hero: CharacterBody3D = null
var _anim: AnimationPlayer = null
var _tree: AnimationTree = null
var _rig: Node3D = null
var _pistol: Node3D = null
var _flash: MeshInstance3D = null
var _bang: OmniLight3D = null
var _saved := {}          # tree node -> animation, to restore
var _cd := 0.0
var _busy_s := 0.0        # one-shot clip window (tree disabled)
var _reloading := false
var _reload_left := 0.0
var _flash_s := 0.0


func mount(hero: CharacterBody3D, anim: AnimationPlayer,
		tree: AnimationTree, rig: Node3D) -> void:
	_hero = hero
	_anim = anim
	_tree = tree
	_rig = rig
	_build_pistol()


func bang_on() -> void:
	if _bang:
		_bang.visible = true

func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
	if _flash_s > 0.0:
		_flash_s -= delta
		if _flash_s <= 0.0:
			if _flash:
				_flash.visible = false
			if _bang:
				_bang.visible = false
	if _busy_s > 0.0:
		_busy_s -= delta
		if _busy_s <= 0.0:
			_restore_tree()
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func toggle() -> void:
	if drawn:
		holster()
	else:
		draw()


func draw() -> void:
	if drawn or _anim == null:
		return
	drawn = true
	if _pistol:
		_pistol.visible = true
	_swap_stance(true)
	ammo_changed.emit(ammo, reserve)
	Log.info("Gun: drawn (%d+%d)" % [ammo, reserve])


func holster() -> void:
	if not drawn:
		return
	drawn = false
	_reloading = false
	if _pistol:
		_pistol.visible = false
	_swap_stance(false)
	ammo_changed.emit(-1, reserve)
	Log.info("Gun: holstered")


## The aim stance: point the tree's idle/walk/run nodes at the
## pistol clips (the pedestrian's tree-parameter law - the tree
## owns the player while active).
func _swap_stance(on: bool) -> void:
	if _tree == null or _anim == null:
		return
	var nodes := ["idle", "walk", "run"]
	# PROBE LAW: 'parameters/<node>/animation' is NOT a tree
	# parameter (the set is a silent no-op, the get returns null) -
	# the AnimationNodeAnimation NODE is the only writable target
	# (this no-op also hid the pedestrian's flee sprint swap)
	var bt := _tree.tree_root as AnimationNodeBlendTree
	if bt == null:
		return
	if on:
		var stance := _clip(["pistol_idle"])
		if stance == &"":
			push_error("Gun: no pistol clips in the bake")
			return
		for n in nodes:
			var node := bt.get_node(n) as AnimationNodeAnimation
			if node:
				if not _saved.has(n):
					_saved[n] = node.animation
				node.animation = stance  # a StringName clip id
	else:
		for n in nodes:
			if _saved.has(n):
				var node := bt.get_node(n) as AnimationNodeAnimation
				if node:
					node.animation = _saved[n]
		_saved.clear()


func fire() -> void:
	if not drawn or _cd > 0.0 or _reloading or _busy_s > 0.0:
		return
	ammo -= 1
	if ammo == 0:
		reload()  # the empty clip rolls straight into the reload
	_cd = SHOT_CD
	_play_oneshot("combat/Pistol_Shoot", 0.5)
	if _flash:
		_flash.visible = true
		_flash_s = 0.13
	bang_on()

	Sound.play("gun_test_0", -4.0)
	_hitscan()
	ammo_changed.emit(ammo, reserve)


func reload() -> void:
	if not drawn or _reloading or _busy_s > 0.0:
		return
	if ammo >= CLIP or reserve <= 0:
		return
	_reloading = true
	_reload_left = RELOAD_S
	_play_oneshot("combat/Pistol_Reload", RELOAD_S)
	Sound.play("cloth_2", -14.0, 1.4)


func _finish_reload() -> void:
	_reloading = false
	var take := mini(CLIP - ammo, reserve)
	ammo += take
	reserve -= take
	ammo_changed.emit(ammo, reserve)
	Log.info("Gun: reloaded (%d+%d)" % [ammo, reserve])


## The hitscan: the punch cone's long-armed cousin - group query,
## RIG yaw for the forward, chest height origin.
func _hitscan() -> void:
	if _hero == null:
		return
	var yaw := 0.0
	if _rig:
		yaw = _rig.rotation.y
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var from := _hero.global_position + Vector3.UP * 1.3
	var best: Node3D = null
	var best_d := REACH
	for target in get_tree().get_nodes_in_group("npc") \
			+ get_tree().get_nodes_in_group("train_target"):
		var n := target as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var to := n.global_position + Vector3.UP * 1.1 - from
		if to.length() > best_d:
			continue
		if to.length() > 0.01 \
				and fwd.angle_to(to.normalized()) > ARC:
			continue
		if not n.has_method("take_hit"):
			continue
		best = n
		best_d = to.length()
	if best:
		best.take_hit(DAMAGE, KNOCKBACK, fwd, POSTURE)
		shot_landed.emit(best, DAMAGE)
		Log.info("Gun: hit %s at %.1fm" % [best.name, best_d])


## The one-shot pattern (combat.gd's law): the tree must be OFF or
## it fights the player frame by frame.
func _play_oneshot(clip: String, window: float) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _tree:
		_tree.active = false
	_anim.stop()
	_anim.play(clip)
	_busy_s = window


func _restore_tree() -> void:
	if _tree:
		_tree.active = true
	if _anim:
		_anim.stop()


func _clip(keys: Array) -> StringName:
	for an in _anim.get_animation_list():
		var s := str(an).to_lower()
		for k in keys:
			if k in s:
				return StringName(str(an))
	return &""


## A code-built noir pistol (the box tradition - the sedan's light
## boxes, the storefront panes): slide, barrel, grip, trigger
## guard; dark gunmetal, a bright muzzle flash box at the tip.
## Bolted to the RightHand bone via a BoneAttachment3D.
func _build_pistol() -> void:
	var skel: Skeleton3D = null
	for c in _rig.get_children():
		if c is Skeleton3D:
			skel = c
			break
	if skel == null:
		skel = _find(_rig, Skeleton3D)
	if skel == null:
		push_error("Gun: no skeleton under the rig")
		return
	var attach := BoneAttachment3D.new()
	attach.name = "GunHand"
	attach.bone_name = "RightHand"
	skel.add_child(attach)
	_pistol = Node3D.new()
	_pistol.name = "Pistol"
	attach.add_child(_pistol)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.09, 0.095, 0.11)
	metal.roughness = 0.35
	metal.metallic = 0.85
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.1, 0.07)
	wood.roughness = 0.8
	# BUILT IN HAND SPACE (probe-measured at the aim pose: hand
	# +X points at the target, +Z is up - the first build ran
	# along +Z and pointed at the sky); ~1.6x scale for the
	# mobile read (the readability-over-realism law)
	var slide := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.30, 0.055, 0.085)
	sm.material = metal
	slide.mesh = sm
	slide.position = Vector3(0.11, 0.0, 0.075)
	_pistol.add_child(slide)
	var barrel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.04, 0.05)
	bm.material = metal
	barrel.mesh = bm
	barrel.position = Vector3(0.30, 0.0, 0.075)
	_pistol.add_child(barrel)
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.075, 0.06, 0.16)
	gm.material = wood
	grip.mesh = gm
	grip.position = Vector3(-0.02, 0.0, -0.02)
	_pistol.add_child(grip)
	var guard := MeshInstance3D.new()
	var ggm := BoxMesh.new()
	ggm.size = Vector3(0.015, 0.014, 0.07)
	ggm.material = metal
	guard.mesh = ggm
	guard.position = Vector3(0.06, 0.0, 0.02)
	_pistol.add_child(guard)
	_bang = OmniLight3D.new()
	# the muzzle flash: bright emissive box + a MOMENTARY
	# OmniLight (probe law: unlit emissive reads dim in the
	# capture pipeline and on night streets - the light sells the
	# shot to the gun, the hands and the wall behind)
	_bang = OmniLight3D.new()
	_bang.name = "Bang"
	_bang.light_color = Color(1.0, 0.82, 0.5)
	_bang.light_energy = 5.0
	_bang.omni_range = 7.0
	_bang.position = Vector3(0.42, 0.0, 0.075)
	_bang.visible = false
	_pistol.add_child(_bang)
	# the flash box: bright emissive, hidden until the shot
	_flash = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.30, 0.26, 0.26)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.85, 0.5)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.8, 0.4)
	fmat.emission_energy_multiplier = 4.0
	fm.material = fmat
	_flash.mesh = fm
	_flash.position = Vector3(0.40, 0.0, 0.075)
	_flash.visible = false
	_pistol.add_child(_flash)
	_pistol.visible = false


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
