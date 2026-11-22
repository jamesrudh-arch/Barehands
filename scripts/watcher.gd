extends Node3D
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
## Gate A (the living street): a thug leaning on a wall, watching the
## hero come and go - a cigarette ember, a name tag, and a head that
## follows you. Not a fighter: atmosphere with eyes.

const WATCH_RANGE := 9.0

var _rig: CLS_NpcRig
var _base_yaw := 0.0
var _head: Node3D


func setup(pos: Vector3, yaw: float, tint: Color, tag: String,
		pieces: Array) -> void:
	add_to_group("watcher")
	position = pos
	_base_yaw = yaw
	rotation.y = yaw
	_rig = CLS_NpcRig.new()
	_rig.build(pieces, tint, tint * 0.3, "Idle", 0.45)
	add_child(_rig)
	var label := Label3D.new()
	label.text = tag
	label.modulate = Color(0.95, 0.45, 0.35, 0.92)
	label.font_size = 34
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.position = Vector3(0, 2.15, 0)
	add_child(label)
	# the cigarette ember (a tiny warm point at hand height)
	var ember := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.1)
	m.emission_energy_multiplier = 1.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	ember.mesh = q
	ember.position = Vector3(0.24, 1.25, 0.3)
	add_child(ember)


func _process(delta: float) -> void:
	# the watch: face the hero when close, drift back to the wall
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	var want := _base_yaw
	if d < WATCH_RANGE:
		var to := (p.global_position - global_position) * Vector3(1, 0, 1)
		if to.length() > 0.1:
			want = atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 2.5, 0.0, 1.0))
