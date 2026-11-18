extends Node
## Group tactics for enemies. Autoloaded as "Tactics" (see project.godot).
## When two or more enemies are engaged, each takes a surround slot around
## the hero (slots slowly drift so the ring flanks instead of queuing), and
## an attack token ensures only one enemy swings at a time. The boss always
## has priority and ignores slots.

var _attacker: CharacterBody3D = null
var _drift := 0.0
var _engaged: Array = []


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null:
		_engaged.clear()
		_attacker = null
		return
	_drift += delta * 0.35  # the ring keeps rotating: constant flanking
	var alive: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state in [Enemy.State.DOWN, Enemy.State.GRABBED, Enemy.State.LAUNCHED]:
			continue
		if e.kind == 0:
			continue  # dummies do not fight
		if e.global_position.distance_to(p.global_position) < 10.0:
			alive.append(e)
	_engaged = alive
	if _attacker != null and (not is_instance_valid(_attacker) or
			_attacker.state in [Enemy.State.DOWN, Enemy.State.STAGGER,
					Enemy.State.FLINCH, Enemy.State.GRABBED, Enemy.State.LAUNCHED]):
		_attacker = null


## Slots are only worth using when the hero has company.
func slots_active(p: CharacterBody3D) -> bool:
	return _engaged.size() >= 2


## A point on the ring around the hero, unique per enemy, drifting.
func slot_for(e: CharacterBody3D, p: CharacterBody3D) -> Vector3:
	var h := float(e.get_instance_id() % 360)
	var ang := deg_to_rad(h) + _drift
	return p.global_position + Vector3(sin(ang), 0.0, cos(ang)) * 1.55


## Only one enemy may telegraph/strike at a time.
func can_attack(e: CharacterBody3D) -> bool:
	if e.kind == 4:
		return true  # the boss takes what it wants
	return _attacker == null or _attacker == e


func attack(e: CharacterBody3D) -> void:
	if _attacker == null or _attacker == e or e.kind == 4:
		_attacker = e


func release(e: CharacterBody3D) -> void:
	if _attacker == e:
		_attacker = null


func attacker() -> CharacterBody3D:
	return _attacker


func engaged_count() -> int:
	return _engaged.size()
