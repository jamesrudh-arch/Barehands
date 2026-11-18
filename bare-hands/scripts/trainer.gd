class_name Trainer
extends Node3D
## The Knuckle Room trainer - PLACEHOLDER (combo pass PART 3). The real
## fight club arrives with Stage C; until then its trainer stands by the
## training dummy as a hook: walking up greets the player (a hint) and the
## hero's GRAB near the trainer opens the MOVES screen to teach/practise.
## Stage B/C wires the real dialogue through cast.gd and replaces this
## body with the Knuckle Room boss rig.

const RADIUS := 2.6

var _player: Node3D
var _hinted := false
var _figure: MeshInstance3D


func _ready() -> void:
	add_to_group("trainer")
	_build_figure()


func _build_figure() -> void:
	# a read-at-a-glance silhouette: broad coat-coloured body + hat disc
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.34
	cm.height = 1.75
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.10, 0.22)
	mat.roughness = 0.85
	cm.material = mat
	body.mesh = cm
	body.position = Vector3(0, 0.9, 0)
	add_child(body)
	_figure = body
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.05
	hm.bottom_radius = 0.24
	hm.height = 0.05
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.08, 0.07, 0.09)
	hm.material = hmat
	hat.mesh = hm
	hat.position = Vector3(0, 1.86, 0)
	add_child(hat)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	var d := global_position.distance_to(_player.global_position)
	if d < RADIUS and not _hinted:
		_hinted = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("The trainer: GRAB here to review your MOVES, then practise on the dummy", 3.5)
	elif d > RADIUS + 1.0 and _hinted:
		_hinted = false


## The hero's grab consumer calls this when the player grabs near us.
func try_train(hero: Node3D) -> bool:
	if global_position.distance_to(hero.global_position) > RADIUS:
		return false
	var moves := get_tree().get_first_node_in_group("moves")
	if moves and moves.has_method("open"):
		get_tree().paused = true
		moves.open()
		Sound.play("ui_confirm_0", -6.0)
		return true
	return false
