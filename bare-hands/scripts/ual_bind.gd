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
	Log.info("UalBind: library ready, %d clips rewritten to plain paths" % _lib.get_animation_list().size())
	return _lib


## Duplicate an animation with every track path stripped of the ^ marker.
## (Position and rotation tracks for the same bone share one path - both
## get rewritten.)
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
		elif p.has_animation("Idle"):
			p.play("Idle", blend)
			p.speed_scale = speed
