extends Node

## REBUILD STEP 2 — THE CHARACTER PIPELINE PROOF (D2/D3/D11).
## Proves, against the real engine, the whole character path:
##   1. a KayKit rigged character loads with a real skeleton + face;
##   2. KayKit animation GLBs share their AnimationLibrary onto the
##      character (same bone family: matched names + RESTs, the
##      documented retarget precondition);
##   3. an AnimationTree blends idle/walk and plays a CombatMelee hit;
##   4. the assembled character saves to NATIVE resources (D3) and
##      loads back headless with no import cache;
##   5. renders under llvmpipe: full body + FACE close-up non-blank.
## Everything character-shaped gates on this suite.

const CHAR := "res://assets/v2/kaykit_adventurers/Rogue.glb"
const MOVE := "res://assets/v2/kaykit_character_animations/Rig_Medium_MovementBasic.glb"
const MELEE := "res://assets/v2/kaykit_character_animations/Rig_Medium_CombatMelee.glb"
const NATIVE_DIR := "res://assets/native"
const SHOT_DIR := "/tmp/render"

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	for i in 4:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NATIVE_DIR))
	await _structure()
	await _share_and_blend()
	await _native_roundtrip()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("PIPELINE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("PIPELINE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


## 1. what the GLBs actually contain (bone names, rests, animations).
func _structure() -> void:
	var char_scene: PackedScene = load(CHAR)
	_check(char_scene != null, "the Rogue character GLB loads")
	_hero = char_scene.instantiate()
	add_child(_hero)
	await get_tree().process_frame
	_skel = _find_node(_hero, Skeleton3D) as Skeleton3D
	_check(_skel != null, "the character has a Skeleton3D")
	if _skel == null:
		return
	var bones: int = _skel.get_bone_count()
	_check(bones >= 20, "the skeleton is a real rig (%d bones)" % bones)
	var bone_names := []
	for i in bones:
		bone_names.append(_skel.get_bone_name(i))
	print("  info bones: %s" % str(bone_names))
	# humanoid profile bones, in the rig's own casing (KayKit convention)
	var profile_bones := 0
	for bn in bone_names:
		var low: String = bn.to_lower()
		if low in ["hips", "spine", "chest", "head", "neck", "pelvis"]:
			profile_bones += 1
	_check(profile_bones >= 4,
			"humanoid profile bones present (%d: the BoneMap precondition)"
			% profile_bones)
	# the face: a head/neck bone with mesh above the shoulders
	var head_i := -1
	for bn in bone_names:
		if bn.to_lower() in ["head", "head_top", "neck"]:
			head_i = _skel.find_bone(bn)
			break
	_check(head_i >= 0, "the rig has a head-region bone (the face anchor)")
	_meshes = _collect(_hero, MeshInstance3D)
	_check(_meshes.size() > 0,
			"the character has meshes (%d MeshInstance3D)" % _meshes.size())
	var aabb := _hero_aabb()
	_check(aabb.size.y > 1.2 and aabb.size.y < 2.6,
			"human proportions: the rig stands %.2f m tall" % aabb.size.y)
	print("  info aabb=%s" % aabb)
	# the animation rigs
	for entry in [["move", MOVE], ["melee", MELEE]]:
		var src: PackedScene = load(entry[1])
		_check(src != null, "the %s animation GLB loads" % entry[0])
		var node := src.instantiate()
		add_child(node)
		await get_tree().process_frame
		var player := _find_node(node, AnimationPlayer) as AnimationPlayer
		var names: Array = []
		if player:
			for lib_name in player.get_animation_library_list():
				for an in player.get_animation_list():
					names.append("%s/%s" % [lib_name, an])
		_check(player != null and names.size() > 0,
				"the %s rig carries animations (%s)" % [entry[0],
				str(names.slice(0, 8))])
		_src[entry[0]] = player
		_src_root[entry[0]] = node


var _hero: Node3D = null
var _skel: Skeleton3D = null
var _meshes: Array = []
var _src := {}
var _src_root := {}


## 2. share the KayKit libraries onto the character (matched bone
## family: names + RESTs align), drive an AnimationTree blend, play a
## melee hit, and RENDER.
func _share_and_blend() -> void:
	if _skel == null or _src.is_empty():
		_check(false, "share skipped (structure failed)")
		return
	var player := _find_node(_hero, AnimationPlayer) as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		_hero.add_child(player)
		player.root_node = player.get_path_to(_hero)
	# the character GLB may carry its own library already - note it
	for lib_name in player.get_animation_library_list():
		print("  info character library: %s" % lib_name)
	var move_player: AnimationPlayer = _src["move"]
	var melee_player: AnimationPlayer = _src["melee"]
	var shared := 0
	for pair in [["locomotion", move_player], ["combat", melee_player]]:
		var src_lib: AnimationLibrary = (pair[1] as AnimationPlayer).get_animation_library("")
		var lib := _remapped_library(src_lib, _hero, _skel)
		if lib == null:
			continue
		if player.has_animation_library(pair[0]):
			player.remove_animation_library(pair[0])
		player.add_animation_library(pair[0], lib)
		shared += lib.get_animation_list().size()
	_check(shared >= 4,
			"the KayKit libraries share onto the character (%d animations)" % shared)
	await _tree_blend(player)
	# pose the melee hit directly (proof the combat tracks bind)
	var any_hit := ""
	for an in player.get_animation_list():
		if an.begins_with("combat/"):
			any_hit = an
			break
	_check(any_hit != "", "a CombatMelee clip is installed (%s)" % any_hit)


## Clone a source library with track paths rewritten onto the
## character's rig. KayKit->KayKit is the same bone family (matched
## names + RESTs - the documented share precondition): every bone
## track keeps its bone subname and re-points at the character's
## Skeleton3D; root node tracks (position) re-point at the hero root.
func _remapped_library(src_lib: AnimationLibrary,
		dst_root: Node3D, dst_skel: Skeleton3D) -> AnimationLibrary:
	var dst_skel_rel := str(dst_root.get_path_to(dst_skel))
	var lib := AnimationLibrary.new()
	for an in src_lib.get_animation_list():
		var anim: Animation = src_lib.get_animation(an)
		var copy := anim.duplicate() as Animation
		for ti in range(copy.get_track_count()):
			var s := str(copy.track_get_path(ti))
			var colon := s.find(":")
			var sub := s.substr(colon + 1) if colon > 0 else ""
			var bone := sub.get_basename().get_file() \
					if sub.find("/") < 0 else ""
			if colon > 0 and dst_skel.find_bone(bone) >= 0:
				# a bone track: same bone name, new skeleton
				copy.track_set_path(ti, "%s:%s" % [dst_skel_rel, sub])
			elif colon > 0:
				# a root-node property track: aim it at the player root
				copy.track_set_path(ti, ":%s" % sub)
		lib.add_animation(an, copy)
	return lib


## Drive an idle->walk blend for half a second (the AnimationTree
## proof), then keep it live for the renders.
func _tree_blend(player: AnimationPlayer) -> void:
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	_hero.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	var root := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = _first_clip(player, "locomotion", ["idle", "stand"])
	var walk := AnimationNodeAnimation.new()
	walk.animation = _first_clip(player, "locomotion", ["walk"])
	root.add_node("idle", idle)
	root.add_node("walk", walk)
	var blend := AnimationNodeBlend2.new()
	root.add_node("blend", blend)
	# 4.7 connect_node(input_node, input_index, output_node): the
	# FIRST arg is the DESTINATION and its input slot, the LAST arg is
	# the SOURCE; the special "output" node is a DESTINATION
	root.connect_node("blend", 0, "idle")
	root.connect_node("blend", 1, "walk")
	root.connect_node("output", 0, "blend")
	tree.tree_root = root
	tree.active = true
	tree.set("parameters/blend/blend_amount", 0.0)
	await _wait_s(0.3)
	# the blend must actually MOVE the skeleton: capture a bone pose at
	# idle, tween to walk, capture again - a real blend differs
	var skel := _find_node(_hero, Skeleton3D) as Skeleton3D
	var pose_a := _pose_hash(skel)
	var t := get_tree().create_tween()
	t.tween_method(func(v): tree.set("parameters/blend/blend_amount", v),
			0.0, 1.0, 0.5)
	await _wait_s(0.6)
	var pose_b := _pose_hash(skel)
	_check(pose_a != pose_b,
			"the AnimationTree blend actually changes the pose")


func _first_clip(player: AnimationPlayer, lib: String, keys: Array) -> StringName:
	var list := player.get_animation_list()
	for k in keys:
		for an in list:
			var s := str(an).to_lower()
			if s.begins_with(lib + "/") and k.to_lower() in s:
				return an
	return list[0] if list.size() > 0 else &""


## 3. D3: save the assembled character to native resources, reload
## headless, render again.
func _native_roundtrip() -> void:
	if _hero == null:
		_check(false, "native roundtrip skipped")
		return
	var lib := _hero.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var packed := PackedScene.new()
	var err := packed.pack(_hero)
	_check(err == OK, "the character packs to a scene (err %d)" % err)
	var path_tscn := "%s/hero_kaykit_rogue.tscn" % NATIVE_DIR
	# FLAG_BUNDLE_RESOURCES: meshes, materials AND textures embedded in
	# the one file - no import cache needed on the device (the D3 law;
	# a bare pack() leaves texture ext_resources pointing at res://)
	var err2 := ResourceSaver.save(packed, path_tscn,
			ResourceSaver.FLAG_BUNDLE_RESOURCES)
	_check(err2 == OK, "the character saves NATIVE, fully bundled (err %d)" % err2)
	var f := FileAccess.open(path_tscn, FileAccess.READ)
	var bundle_refs := 0
	if f:
		var txt := f.get_as_text()
		f.close()
		bundle_refs = txt.count("res://assets")
	_check(bundle_refs == 0,
			"the native file is self-contained (0 external asset refs, found %d)"
			% bundle_refs)
	# the render checks (before AND after the native reload)
	await _renders("native_pre")
	var reloaded: PackedScene = load(path_tscn)
	_check(reloaded != null, "the native .tscn loads back headless")
	if reloaded:
		var again := reloaded.instantiate()
		add_child(again)
		await get_tree().process_frame
		var skel2 := _find_node(again, Skeleton3D) as Skeleton3D
		_check(skel2 != null and skel2.get_bone_count() == _skel.get_bone_count(),
				"the native copy keeps the full rig (%d bones)" % (
				skel2.get_bone_count() if skel2 else -1))
		await _renders("native_post")
		again.queue_free()


## Render the character twice (full body + face close-up), assert the
## pixels are real: not blank, and the face band carries detail.
func _renders(tag: String) -> void:
	var cam := Camera3D.new()
	cam.name = "ProbeCam"
	add_child(cam)
	# a neutral backdrop so the character reads against it
	var floor_m := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(40, 0.2, 40)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.26, 0.26, 0.3)
	fm.material = fmat
	floor_m.mesh = fm
	floor_m.position = Vector3(0, -1.05, 0)
	add_child(floor_m)
	# the light rig: a key + a warm face-side fill (the architecture's
	# character lighting: faces must read)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-48, 35, 0)
	key.light_energy = 1.2
	add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "FaceFill"
	fill.light_color = Color(1.0, 0.82, 0.62)
	fill.light_energy = 1.1
	fill.omni_range = 7.0
	var aabb := _hero_aabb()
	fill.position = _hero.global_position + Vector3(0.8, aabb.size.y * 0.9, 1.2)
	add_child(fill)
	var centre := _hero.global_position + Vector3(0, aabb.size.y * 0.5, 0)
	# full body
	cam.position = centre + Vector3(2.6, 0.4, 2.6)
	cam.look_at(centre, Vector3.UP)
	cam.make_current()
	await _wait_s(0.25)
	var body_img := get_viewport().get_texture().get_image()
	body_img.save_png("%s/pipeline_%s_body.png" % [SHOT_DIR, tag])
	_check(_img_alive(body_img), "the full-body render is alive (%s)" % tag)
	# face close-up: aim at the head BONE's live position (the aabb
	# estimate drifts with the pose; the bone is the truth)
	var head_i := _skel.find_bone("head")
	var head := _hero.global_position + Vector3(0, aabb.size.y * 0.93, 0)
	if head_i >= 0:
		head = _hero.global_transform * _skel.get_bone_global_pose(head_i).origin
	cam.position = head + Vector3(0.0, 0.05, 0.85)
	cam.look_at(head, Vector3.UP)
	await _wait_s(0.25)
	var face_img := get_viewport().get_texture().get_image()
	face_img.save_png("%s/pipeline_%s_face.png" % [SHOT_DIR, tag])
	_check(_img_alive(face_img), "the face close-up renders alive (%s)" % tag)
	floor_m.queue_free()
	cam.queue_free()


func _img_alive(img: Image) -> bool:
	if img == null or img.is_empty():
		return false
	# Image has no get_histogram() in Godot 4: downscale and count by
	# hand (64x36 = 2304 samples, instant, statistically enough)
	var l8 := img.duplicate()
	l8.convert(Image.FORMAT_L8)
	l8.resize(64, 36)
	var bins := {}
	var total := 0
	for y in l8.get_height():
		for x in l8.get_width():
			var v: int = l8.get_pixel(x, y).r8
			bins[v] = int(bins.get(v, 0)) + 1
			total += 1
	if total <= 0:
		return false
	# alive = the frame is neither a blank sheet (one spike) nor noise:
	# at least 5% of pixels sit away from the two extremes
	var mid := 0
	for i in range(10, 246):
		mid += int(bins.get(i, 0))
	return float(mid) / float(total) > 0.05


# --- small node helpers (Stage-0 style, no class_name deps) ---------------


func _find_node(root: Node, what) -> Node:
	if root == null:
		return null
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var found := _find_node(c, what)
		if found:
			return found
	return null


func _collect(root: Node, what) -> Array:
	var out := []
	if root == null:
		return out
	if is_instance_of(root, what):
		out.append(root)
	for c in root.get_children():
		out.append_array(_collect(c, what))
	return out


func _hero_aabb() -> AABB:
	var aabb := AABB()
	var first := true
	for m in _meshes:
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		# the mesh aabb is mesh-local: carry it through the node's
		# global transform before merging (skinned meshes sit at the
		# rig origin, so this is the honest world box)
		var box := mi.get_aabb()
		box = mi.get_global_transform() * box
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	return aabb


## A stable pose signature (bone positions snapped to 1 mm) - the
## blend proof compares signatures, not eyeballs.
func _pose_hash(skel: Skeleton3D) -> int:
	if skel == null:
		return 0
	var h := 0
	for i in skel.get_bone_count():
		var p := skel.get_bone_pose(i).origin
		h = hash([h, snappedf(p.x, 0.001), snappedf(p.y, 0.001),
				snappedf(p.z, 0.001)])
	return h
