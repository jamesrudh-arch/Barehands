extends CharacterBody3D
const CLS_NightLook := preload("res://scripts/world/night_look.gd")

## A NAMED LOCAL (overhaul S5.3): the street's fixed points of
## life - a face at the venues the missions already name. Standing
## at the door, talking-idle clip, a small billboarded name above.
## The routine is deliberately minimal (they are anchors, not
## actors): face the street, breathe, exist. Group "pedestrian"
## for the life count; NOT "npc" (the punch cone must not touch
## them) and not "enemy" (they never flee-check).

const ALIASES := {
	"Idle_A": "Idle_Talking_Loop",
	"Idle_B": "Idle_Loop",
}

var _rig: Node3D = null
var _anim: AnimationPlayer = null


## Static spawner: cast_path = a cast bundle tscn, bake = its UAL
## bake; name floats over the head.
static func place(parent: Node, cast_path: String, bake_path: String,
		pos: Vector3, face_yaw: float, who: String,
		tint := Color.WHITE) -> Node3D:
	var script := load("res://scripts/npc/local.gd") as GDScript
	var npc: CharacterBody3D = script.new()
	npc.position = pos
	npc.rotation.y = face_yaw
	npc.set_meta("who", who)
	npc.set_meta("cast", cast_path)
	npc.set_meta("bake", bake_path)
	if tint != Color.WHITE:
		npc.set_meta("tint", tint)
	parent.add_child(npc)
	return npc


func _ready() -> void:
	add_to_group("pedestrian")
	add_to_group("local")
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.75
	col.shape = shape
	col.position = Vector3(0, 0.87, 0)
	collision_layer = 4
	collision_mask = 1
	add_child(col)
	var cast: String = get_meta("cast",
			"res://assets/native/cast_michelle.tscn")
	var bake: String = get_meta("bake",
			"res://assets/native/ual_baked_michelle.res")
	var packed: PackedScene = load(cast)
	if packed:
		_rig = packed.instantiate()
		_rig.name = "Rig"
		add_child(_rig)
		CLS_NightLook.blob(self, 0.5)
	var skel: Skeleton3D = _find(_rig, Skeleton3D)
	_anim = _find(_rig, AnimationPlayer)
	if _anim == null and skel != null:
		_anim = AnimationPlayer.new()
		_anim.name = "Anim"
		_rig.add_child(_anim)
	if _anim and skel:
		_anim.root_node = _anim.get_path_to(_rig)
		var lib := load("res://scripts/player/ual_lib.gd")
		var n: int = lib.install(_anim, skel, bake, ALIASES)
		if n < 40:
			push_error("Local: bake install failed (%d)" % n)
		if _anim.has_animation("ambient/Idle_A"):
			_anim.play("ambient/Idle_A")
	# the name: small, billboarded, readable against the night
	# (queue-goers and other background bodies pass who="" - no tag)
	if String(get_meta("who", "LOCAL")) != "":
		var label := Label3D.new()
		label.text = String(get_meta("who", "LOCAL"))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.012
		label.font_size = 48
		label.modulate = Color(1.0, 0.92, 0.75, 0.85)
		label.outline_size = 10
		label.position = Vector3(0, 2.05, 0)
		add_child(label)
	if has_meta("tint"):
		_apply_tint(_rig, get_meta("tint") as Color)


## Per-instance clothing tint (the pedestrian law: OVERRIDE on the
## mesh instance - surface_set_material mutates the SHARED mesh).
func _apply_tint(rig: Node, tint: Color) -> void:
	if rig == null or tint == Color.WHITE:
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s_idx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s_idx)
			if mat is StandardMaterial3D:
				var clone: StandardMaterial3D = \
						(mat as StandardMaterial3D).duplicate()
				clone.albedo_color = tint
				(mi as MeshInstance3D).set_surface_override_material(
						s_idx, clone)


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
