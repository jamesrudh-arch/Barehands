extends Node
## S5.1b diagnostic: the reference-pose decision. Dumps UAL rest +
## A_TPose (track-sampled, no player) + RPM rest as WORLD positions
## of key chain ends, plus arm/leg bone direction angles. The data
## picks the reference pair for the world-orientation baker.
const CHAIN := {
	"UAL": {
		"arm": [["clavicle_l", "upperarm_l"], ["upperarm_l", "hand_l"]],
		"leg": [["pelvis", "thigh_l"], ["thigh_l", "foot_l"]],
		"head": "Head",
	},
	"RPM": {
		"arm": [["LeftShoulder", "LeftArm"], ["LeftArm", "LeftHand"]],
		"leg": [["Hips", "LeftUpLeg"], ["LeftUpLeg", "LeftFoot"]],
		"head": "Head",
	},
}

func _q_at(anim: Animation, path: String, t: float) -> Quaternion:
	var ti := -1
	for i in anim.get_track_count():
		if String(anim.track_get_path(i)) == path:
			ti = i
			break
	if ti < 0:
		return Quaternion.IDENTITY
	var n := anim.track_get_key_count(ti)
	if n == 0:
		return Quaternion.IDENTITY
	var best_t := anim.track_get_key_time(ti, 0)
	var best_q: Quaternion = anim.track_get_key_value(ti, 0)
	var prev_t := best_t
	var prev_q := best_q
	for k in n:
		var kt: float = anim.track_get_key_time(ti, k)
		var kq: Quaternion = anim.track_get_key_value(ti, k)
		if kt <= t:
			prev_t = kt
			prev_q = kq
		if kt >= t and prev_t <= t and kt > prev_t:
			var f := (t - prev_t) / (kt - prev_t)
			return prev_q.slerp(kq, f)
		if absf(kt - t) < absf(best_t - t):
			best_t = kt
			best_q = kq
			prev_t = kt
			prev_q = kq
	return prev_q if prev_t <= t else best_q

func _ready() -> void:
	# --- UAL ---
	var scene: PackedScene = load("res://assets/UAL1_Standard.glb")
	var holder := scene.instantiate()
	add_child(holder)
	var skel: Skeleton3D = holder.find_children("*", "Skeleton3D",
			true, false)[0]
	var ap: AnimationPlayer = holder.find_children("*",
			"AnimationPlayer", true, false)[0]
	var lib := ap.get_animation_library("")
	# rest pose world positions
	_dump("UAL rest", skel, CHAIN["UAL"])
	# A_TPose t=0: sample tracks, apply to skeleton, read globals
	var anim: Animation = lib.get_animation("A_TPose")
	for b in skel.get_bone_count():
		skel.reset_bone_pose(b)
	var base := "Armature/Skeleton3D:"
	for b in skel.get_bone_count():
		var q := _q_at(anim, base + skel.get_bone_name(b), 0.0)
		skel.set_bone_pose_rotation(b, q)
	for b in skel.get_bone_count():
		var p := skel.get_bone_pose_position(b)
		if p.length() > 0.001:
			pass  # (rotation-only: keep rest positions)
	_dump("UAL Tpose t=0", skel, CHAIN["UAL"])
	holder.queue_free()

	# --- RPM hero (from the bundled scene) ---
	var hscene: PackedScene = load("res://assets/native/hero_rpm.tscn")
	var hero := hscene.instantiate()
	add_child(hero)
	var hskel: Skeleton3D = hero.find_children("*", "Skeleton3D",
			true, false)[0]
	_dump("RPM rest", hskel, CHAIN["RPM"])
	get_tree().quit(0)

func _dump(tag: String, skel: Skeleton3D, cfg: Dictionary) -> void:
	var out: Array = []
	for seg in cfg["arm"]:
		out.append("arm %s->%s dir=%s" % [seg[0], seg[1],
				_dir(skel, seg[0], seg[1])])
	for seg in cfg["leg"]:
		out.append("leg %s->%s dir=%s" % [seg[0], seg[1],
				_dir(skel, seg[0], seg[1])])
	var hi: int = skel.find_bone(cfg["head"])
	var hp := skel.get_bone_global_pose(hi).origin
	out.append("%s pos=%s" % [cfg["head"], hp])
	print("REF %s | %s" % [tag, "  ".join(PackedStringArray(out))])

func _dir(skel: Skeleton3D, a: String, b: String) -> String:
	var ia: int = skel.find_bone(a)
	var ib: int = skel.find_bone(b)
	var pa := skel.get_bone_global_pose(ia).origin
	var pb := skel.get_bone_global_pose(ib).origin
	var d := (pb - pa).normalized()
	var up := rad_to_deg(acos(clampf(d.y, -1.0, 1.0)))
	return "(x%.2f y%.2f z%.2f) %ddeg-off-vertical" % [d.x, d.y, d.z,
			int(up)]
