extends Object

## The one place the Universal Animation Library gets bound to a character.
## The T-pose fix: every character's pieces are UBC gltf scenes whose
## skeletons share the UAL's 65 bone names, but two things could break the
## binding on an exported phone build -
##   1. the library load. B17: it is a RUNTIME load() with a null
##      guard, NOT a parse-time preload - a preload of an imported
##      .glb makes this script (and every script that preloads it:
##      player, enemy, npc_rig, and the autoloads that compile them)
##      fail to parse on a FRESH IMPORT before the GLB is converted,
##      which killed the hero on device. With the guard, a not-yet-
##      imported GLB costs the animations only, one logged error, and
##      every character still stands and fights (code-built rigs).
##   2. the UAL's tracks address bones through scene-unique names
##      (^"Armature/Skeleton3D:bone"), which depend on unique-name flags
##      surviving import. We rewrite every track to the plain relative path
##      "Armature/Skeleton3D:bone", resolved from each player's root node -
##      deterministic everywhere.
## One rewritten library is shared by every player in the game.

const UAL_PATH := "res://assets/UAL1_Standard.glb"

static var _lib: AnimationLibrary
static var _failed := false
static var _warned_noanim := false


## The rewritten, shareable library (built once). null = the GLB is
## not loadable right now (fresh import still running, or the asset
## is missing) - callers must treat null as "no animations yet".
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	if _failed:
		return null
	var ual: PackedScene = load(UAL_PATH)
	if ual == null:
		_failed = true
		push_error("UalBind: UAL1_Standard.glb will not load (import "
				+ "still running, or the file is missing) - characters "
				+ "run without animations until it does")
		return null
	var tmp: Node = ual.instantiate()
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
	var lib := library()
	if lib == null:
		return  # no library yet - the rig still stands and plays poses
	player.add_animation_library("", lib)


## Every player in `players` plays the clip, in lockstep.
static func play_all(players: Array[AnimationPlayer], clip: String, blend := 0.25,
		speed := 1.0) -> void:
	for p: AnimationPlayer in players:
		if p.has_animation(clip):
			p.play(clip, blend)
			p.speed_scale = speed
		elif p.has_animation("Idle"):
			# the runtime library carries short names (Idle, Walk, ...).
			# A miss falls back to the pack idle and SAYS so - a bad clip
			# name must never silently T-pose a character again.
			Log.warn("UalBind: clip '%s' missing - falling back to Idle" % clip)
			p.play("Idle", blend)
			p.speed_scale = speed
		else:
			if not _warned_noanim:
				_warned_noanim = true
				Log.warn("UalBind: no animations attached (library "
						+ "unavailable) - clips will not play")
