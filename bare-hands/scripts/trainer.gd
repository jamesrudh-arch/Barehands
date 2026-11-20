class_name Trainer
extends Node3D
## The fight-club trainer - PLACEHOLDER (combo pass PART 3). The owner's
## LEVERAGE bible (PROJECT_BIBLE.md) names no "Knuckle Room": the fight
## club is the Block 2 gym + the underground tournaments. Until that batch
## lands, the trainer stands by the training dummy as a hook: walking up
## greets the player (a hint) and the hero's GRAB near the trainer opens
## the MOVES screen to teach and practise. The real gym is in the club
## quarter (walk east through the gate; bible 6 places the fight club
## there with the underground tournaments) - the tournament batch wires
## its door and replaces this silhouette.

const RADIUS := 1.4  # close enough that a combat grab near enemies is never hijacked

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
## Guards: close, facing us, and no active fight nearby - a grab thrown in
## combat must never open a menu instead of seizing the enemy.
func try_train(hero: Node3D) -> bool:
	if global_position.distance_to(hero.global_position) > RADIUS:
		return false
	var fwd := -(hero as Node3D).global_transform.basis.z
	var to_us := (global_position - hero.global_position).normalized()
	if fwd.dot(to_us) < 0.4:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Enemy
		if enemy and enemy.state not in [Enemy.State.DOWN, Enemy.State.IDLE] \
				and hero.global_position.distance_to(enemy.global_position) < 5.0:
			return false
	var moves := get_tree().get_first_node_in_group("moves")
	if moves and moves.has_method("open"):
		get_tree().paused = true
		moves.open()
		Sound.play("ui_confirm_0", -6.0)
		return true
	return false
