class_name UalBind
extends Object
## The one place the Universal Animation Library gets bound to a character.
## The T-pose fix: every character's pieces are UBC gltf scenes whose
## skeletons share the UAL's 65 bone names, but two things could break the
## binding on an exported phone build -
##   1. loading the library with a runtime load() of a string path (the
##      export can drop the remap, leaving the library null and the
##      character at rest). Here the UAL scene is a PRELOAD: a compile-time
##      dependency the exporter must include.
##   2. the UAL's tracks address bones through scene-unique names
##      (^"Armature/Skeleton3D:bone"), which depend on unique-name flags
##      surviving import. We rewrite every track to the plain relative path
##      "Armature/Skeleton3D:bone", resolved from each player's root node -
##      deterministic everywhere.
## One rewritten library is shared by every player in the game.

const UAL_SCENE: PackedScene = preload("res://assets/UAL1_Standard.glb")

static var _lib: AnimationLibrary


## The rewritten, shareable library (built once).
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	var tmp: Node = UAL_SCENE.instantiate()
	var src: AnimationLibrary = tmp.get_node("AnimationPlayer").get_animation_library("")
	tmp.free()
	_lib = AnimationLibrary.new()
	for anim_name in src.get_animation_list():
		_lib.add_animation(anim_name, _rewritten(src.get_animation(anim_name)))
	_add_code_clips(_lib)
	Log.info("UalBind: library ready, %d clips rewritten to plain paths" % _lib.get_animation_list().size())
	return _lib


## Duplicate an animation with every track path stripped of the ^ marker.
## (Position and rotation tracks for the same bone share one path - both
## get rewritten.)
## Clips the pack does not have, built in code. Kick_Code: the right leg
## chambers, snaps out at hip height, recovers - plus a pelvis lean, spine
## counter and a guard arm so it reads as a kick, not a leg raise. Built
## from the same plain bone paths the rewritten library uses.
static func _add_code_clips(lib: AnimationLibrary) -> void:
	lib.add_animation("Kick_Code", _kick_clip())
	Log.info("UalBind: code clips added (Kick_Code)")


static func _kick_clip() -> Animation:
	var a := Animation.new()
	a.length = 0.5
	# path -> [time0, rot0, time1, rot1, ...] as X-axis rotations (rad);
	# the hero faces -Z, so +X on the thigh lifts the knee forward.
	var marks := {
		"Armature/Skeleton3D:thigh_r": [0.0, 0.0, 0.12, 1.45, 0.22, 1.75, 0.36, 1.25, 0.5, 0.0],
		"Armature/Skeleton3D:calf_r": [0.0, 0.0, 0.12, -1.6, 0.22, -0.12, 0.36, -1.45, 0.5, 0.0],
		"Armature/Skeleton3D:foot_r": [0.0, 0.0, 0.12, -0.3, 0.22, 0.45, 0.36, -0.1, 0.5, 0.0],
		"Armature/Skeleton3D:pelvis": [0.0, 0.0, 0.12, -0.12, 0.22, -0.18, 0.36, -0.1, 0.5, 0.0],
		"Armature/Skeleton3D:spine_01": [0.0, 0.0, 0.12, 0.1, 0.22, 0.16, 0.36, 0.08, 0.5, 0.0],
		"Armature/Skeleton3D:upperarm_l": [0.0, 0.0, 0.12, 0.7, 0.22, 0.9, 0.36, 0.6, 0.5, 0.0],
		"Armature/Skeleton3D:upperarm_r": [0.0, 0.0, 0.12, -0.4, 0.22, -0.5, 0.36, -0.3, 0.5, 0.0],
	}
	for path in marks:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(path))
		var keys: Array = marks[path]
		for i in range(0, keys.size(), 2):
			a.rotation_track_insert_key(t, keys[i],
					Quaternion.from_euler(Vector3(keys[i + 1], 0.0, 0.0)))
		a.track_set_interpolation_type(t, Animation.InterpolationType.INTERPOLATION_CUBIC)
	a.loop_mode = Animation.LOOP_NONE
	return a


static func _rewritten(a: Animation) -> Animation:
	var out := a.duplicate()
	for t in out.get_track_count():
		var p: NodePath = out.track_get_path(t)
		if str(p).begins_with("^"):
			out.track_set_path(t, NodePath(str(p).substr(1)))
	return out


## Graft the library onto a player (root_node stays the player's parent,
## so plain "Armature/Skeleton3D:x" paths resolve inside its own piece).
static func attach(player: AnimationPlayer) -> void:
	player.add_animation_library("", library())


## Every player in `players` plays the clip, in lockstep.
static func play_all(players: Array[AnimationPlayer], clip: String, blend := 0.25,
		speed := 1.0) -> void:
	for p: AnimationPlayer in players:
		if p.has_animation(clip):
			p.play(clip, blend)
			p.speed_scale = speed
		elif p.has_animation("Idle_Loop"):
			# a miss used to fall back to "Idle", which does not exist in
			# this pack either - the character stood in a T-pose. Fall back
			# to the real idle and say so, so a bad name never hides again.
			if not p.has_animation(clip):
				Log.warn("UalBind: clip '%s' missing - falling back to Idle_Loop" % clip)
			p.play("Idle_Loop", blend)
			p.speed_scale = speed
		else:
			Log.warn("UalBind: clip '%s' missing and no idle available" % clip)
