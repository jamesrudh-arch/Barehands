extends Node3D
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
## An ambient figure (bible 6): crowds with daily habits, rumors when
## you get close, and streets that thin out when the mood turns. Each
## wanderer walks a small loop around home, pauses like someone waiting
## for someone, and talks when the hero is near - one line from the
## block's rumor pool (the mood, the last thing the street remembers).

const TALK_RANGE := 3.6
const PIECES_F := ["res://assets/cast/Superhero_Female_FullBody.gltf",
	"res://assets/cast/Female_Ranger_Body.gltf"]
const PIECES_M := ["res://assets/hero/Superhero_Male_FullBody.gltf",
	"res://assets/cast/Male_Peasant_Body.gltf"]

var block := "riverside"
var home := Vector3.ZERO
var _target := Vector3.ZERO
var _pause_until := 0.0
var _bubble: Label3D = null
var _said := ""


func spawn() -> void:
	add_to_group("wanderer")
	position = home
	_pick_target()
	var rig := CLS_NpcRig.new()
	var female := randf() < 0.5
	var tint := Color(randf_range(0.3, 0.6), randf_range(0.3, 0.6),
			randf_range(0.35, 0.7))
	rig.build(PIECES_F if female else PIECES_M, tint, tint * 0.4,
			"Idle", randf_range(0.85, 1.15))
	add_child(rig)
	_bubble = Label3D.new()
	_bubble.modulate = Color(0, 0, 0, 0)
	_bubble.font_size = 30
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 8
	_bubble.position = Vector3(0, 2.3, 0)
	add_child(_bubble)


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if not p:
		return
	# the talk: close enough, one line, fading as you pass
	var d := global_position.distance_to(p.global_position)
	if d < TALK_RANGE:
		if _said.is_empty():
			_said = City.rumor_line(block)
			_bubble.text = _said
	else:
		_said = ""
	if _bubble:
		var want := clampf(1.0 - (d - TALK_RANGE) * 0.8, 0.0, 1.0) if d < TALK_RANGE + 1.5 else 0.0
		_bubble.modulate.a = lerpf(_bubble.modulate.a, want, delta * 4.0)
	# the walk: small loop, pauses between legs
	if _pause_until > 0.0:
		_pause_until -= delta
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_pick_target()
		_pause_until = randf_range(1.5, 5.0)  # window shopping
		return
	var dir := to.normalized()
	global_position += dir * delta * 1.1
	rotation.y = atan2(dir.x, dir.z)


func _pick_target() -> void:
	_target = home + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-3.0, 3.0))
	_target.x = clampf(_target.x, Blocks.BLOCK_X[block] - 16.0,
			Blocks.BLOCK_X[block] + 16.0)
	_target.z = clampf(_target.z, -8.0, 8.0)
