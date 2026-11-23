extends Node

## THE KAYKIT LIBRARY SHARE (rebuild step 3, from the step-2 proof):
## installs KayKit animation GLBs onto a KayKit character rig at
## runtime. Same bone family - matched names + RESTs - so every bone
## track keeps its bone subname and re-points at the target
## Skeleton3D; root-node property tracks aim at the player root.
## ONE authoritative implementation: the hero, NPCs and the pipeline
## probe all share clips through this file.

const SOURCES := {
	"locomotion": "res://assets/v2/kaykit_character_animations/Rig_Medium_MovementBasic.glb",
	"ambient": "res://assets/v2/kaykit_character_animations/Rig_Medium_General.glb",
	"posture": "res://assets/v2/kaykit_character_animations/Rig_Medium_MovementAdvanced.glb",
	"combat": "res://assets/v2/kaykit_character_animations/Rig_Medium_CombatMelee.glb",
}


## Install every source library onto `player` (an AnimationPlayer
## whose root_node resolves to the rig root). Returns the number of
## animations shared. Idempotent: existing libraries are replaced.
static func install(player: AnimationPlayer, skel: Skeleton3D) -> int:
	if player == null or skel == null:
		return 0
	# track paths are relative to the PLAYER'S root_node - resolve it
	# and build the path from THERE to the skeleton (the rig nests:
	# Rig/Rig_Medium/Skeleton3D; paths relative to the wrong level
	# silently resolve to null and no animation ever binds)
	var root_node: Node = player.get_node_or_null(player.root_node)
	if root_node == null:
		push_warning("KayKitLib: root_node unresolved (%s)" % player.root_node)
		return 0
	var dst_rel := str(root_node.get_path_to(skel))
	var total := 0
	for lib_name in SOURCES:
		var scene: PackedScene = load(SOURCES[lib_name])
		if scene == null:
			push_warning("KayKitLib: %s missing (%s)" % [lib_name, SOURCES[lib_name]])
			continue
		var holder := scene.instantiate()
		var src_player := _find(holder, AnimationPlayer) as AnimationPlayer
		if src_player == null or not src_player.has_animation_library(""):
			holder.queue_free()
			continue
		var lib := _remap(src_player.get_animation_library(""), dst_rel, skel)
		holder.queue_free()
		if lib == null:
			continue
		if player.has_animation_library(lib_name):
			player.remove_animation_library(lib_name)
		player.add_animation_library(lib_name, lib)
		total += lib.get_animation_list().size()
	return total


## Clone a source library with track paths rewritten onto the target
## skeleton (the step-2 remap, proven). Root-node property tracks
## (root motion) are DROPPED: gameplay locomotion is in-place and the
## character controller owns the root transform - a clip's root track
## would fight the controller every frame.
static func _remap(src_lib: AnimationLibrary, dst_skel_rel: String,
		dst_skel: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for an in src_lib.get_animation_list():
		var anim: Animation = src_lib.get_animation(an)
		var copy := anim.duplicate() as Animation
		for ti in range(copy.get_track_count() - 1, -1, -1):
			var s := str(copy.track_get_path(ti))
			var colon := s.find(":")
			var sub := s.substr(colon + 1) if colon > 0 else ""
			var bone := sub.get_basename().get_file() \
					if sub.find("/") < 0 else ""
			if colon > 0 and dst_skel.find_bone(bone) >= 0:
				copy.track_set_path(ti, "%s:%s" % [dst_skel_rel, sub])
			else:
				copy.remove_track(ti)
		lib.add_animation(an, copy)
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
