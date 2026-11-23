extends Node

## THE MIXAMO-FAMILY LIBRARY SHARE (overhaul S5.1): installs
## Mixamo-convention animation GLBs (Xbot, Soldier, Michelle - and
## any future Mixamo-family clip) onto a Mixamo-convention character
## rig (the Ready Player Me hero). Same bone family - the plain
## Mixamo names (Hips/Spine/LeftArm...) + the same RESTs - so the
## KayKit-proven share machinery applies VERBATIM once the
## `mixamorig_` prefix is stripped. Clip names are normalised to the
## hero tree's expectations (idle_a / walking_a / running_a /
## crouching), so hero.gd's lookups do not change.
## ONE authoritative implementation alongside kaykit_lib.gd (which
## stays: the KayKit family + the training corner still use it).

const SOURCES := {
	"locomotion": "res://assets/v2/cast/Xbot.glb",
	"ambient": "res://assets/v2/cast/Soldier.glb",
	"posture": "res://assets/v2/cast/Xbot.glb",
}

# clip renames -> the hero tree's names (library/name)
const RENAME := {
	"idle": "idle_a", "walk": "walking_a", "run": "running_a",
	"sneak_pose": "crouching", "Idle": "idle_b", "Walk": "walking_b",
	"Run": "running_b",
}


## Install the libraries onto `player` (AnimationPlayer whose
## root_node reaches the rig). Returns the clips shared.
static func install(player: AnimationPlayer, skel: Skeleton3D) -> int:
	if player == null or skel == null:
		return 0
	var root_node: Node = player.get_node_or_null(player.root_node)
	if root_node == null:
		push_warning("MixamoLib: root_node unresolved")
		return 0
	var dst_rel := str(root_node.get_path_to(skel))
	var total := 0
	for lib_name in SOURCES:
		var scene: PackedScene = load(SOURCES[lib_name])
		if scene == null:
			push_warning("MixamoLib: %s missing" % SOURCES[lib_name])
			continue
		var holder := scene.instantiate()
		var src_player := _find(holder, AnimationPlayer) as AnimationPlayer
		if src_player == null or not src_player.has_animation_library(""):
			holder.queue_free()
			continue
		var lib := _remap(src_player.get_animation_library(""), dst_rel,
				skel, lib_name)
		holder.queue_free()
		if lib == null:
			continue
		if player.has_animation_library(lib_name):
			player.remove_animation_library(lib_name)
		player.add_animation_library(lib_name, lib)
		total += lib.get_animation_list().size()
	return total


## Clone a source library: strip the mixamorig_ prefix off bone
## tracks, keep only tracks whose bone EXISTS on the target rig,
## drop root property tracks (the controller owns the root transform
## - the KayKit law), rename clips to the hero tree's names.
## THE S5.1 LAW: Mixamo clips drive mixamorig_Hips POSITION (the
## root motion) - three.js clips are not in-place, so keeping the
## hips position track TELEPORTS the skeleton 100 m down the street
## every frame (probe-caught: head POSED z=104). The skeleton's
## ROOT bone keeps rotation only.
static func _remap(src_lib: AnimationLibrary, dst_skel_rel: String,
		dst_skel: Skeleton3D, lib_name: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var seen := {}
	var root_bone := ""
	for b in dst_skel.get_bone_count():
		if dst_skel.get_bone_parent(b) == -1:
			root_bone = dst_skel.get_bone_name(b)
			break
	for an in src_lib.get_animation_list():
		var anim: Animation = src_lib.get_animation(an)
		var copy := anim.duplicate() as Animation
		for ti in range(copy.get_track_count() - 1, -1, -1):
			var s := str(copy.track_get_path(ti))
			var colon := s.find(":")
			if colon < 0:
				copy.remove_track(ti)
				continue
			var sub := s.substr(colon + 1)
			var bone := sub.get_basename().get_file() \
					if sub.find("/") < 0 else ""
			bone = bone.trim_prefix("mixamorig_")
			# THE S5.1 LAW (probe-caught twice): bone POSITION/SCALE
			# tracks are authored for the SOURCE rig's bone lengths -
			# replayed on another rig they displace the skeleton by
			# metres (head z=104 with hips motion, z=6.5 from finger/
			# head position tracks). Cross-rig sharing is ROTATION-
			# ONLY; positions come from the destination rest.
			var tt := copy.track_get_type(ti)
			if tt == Animation.TYPE_POSITION_3D \
					or tt == Animation.TYPE_SCALE_3D:
				copy.remove_track(ti)
				continue
			if bone != "" and dst_skel.find_bone(bone) >= 0:
				copy.track_set_path(ti, "%s:%s" % [
						dst_skel_rel, bone])
			else:
				copy.remove_track(ti)
		# the library-level rename (per-library so the same source can
		# feed two libraries with different clips)
		var name := str(an)
		if lib_name == "posture" and name in ["sneak_pose", "sad_pose"]:
			name = RENAME.get(name, name)
		elif lib_name != "posture":
			name = RENAME.get(name, name)
		if name == "TPose":
			continue  # the bind pose is not a clip
		if seen.has(name):
			continue
		seen[name] = true
		lib.add_animation(name, copy)
	return lib


static func _find(root: Node, what) -> Node:
	if root == null:
		return null
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var found := _find(c, what)
		if found:
			return found
	return null
