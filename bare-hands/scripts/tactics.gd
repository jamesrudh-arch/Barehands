extends Node
## Group tactics for enemies. Autoloaded as "Tactics" (see project.godot).
## When two or more enemies are engaged, each takes a surround slot around
## the hero (slots slowly drift so the ring flanks instead of queuing), and
## an ATTACK TOKEN pool keeps concurrent attackers inside the bible 4A
## budget (max 2-3 at once): a two-man ring stays readable with one
## attacker, 3-4 engaged allow two, and a crowd of five or more allows
## three. The boss always has priority and ignores slots.
##
## Batch 2 adds the adaptive memory: the hero's last three moves are on
## record here (one home for the whole ring), and enemies read it to
## punish spam - a hero mashing lights meets faster telegraphs, a hero
## dodging on repeat meets strikes timed to catch the roll.

const MEMORY_LEN := 3

var _attackers: Array = []  # current token holders
var _drift := 0.0
var _engaged: Array = []
var _memory: Array = []  # last MEMORY_LEN player moves, oldest first


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null:
		_engaged.clear()
		_attackers.clear()
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
	for e in _attackers.duplicate():
		if not is_instance_valid(e) or e.state in [Enemy.State.DOWN, Enemy.State.STAGGER,
				Enemy.State.FLINCH, Enemy.State.GRABBED, Enemy.State.LAUNCHED]:
			_attackers.erase(e)


## The bible's token budget (4A rule 2 / balance defaults 14): 2-3
## concurrent attackers at most. A two-man ring reads best with one.
func token_cap() -> int:
	if _engaged.size() >= 5:
		return int(Tuning.v("attack_tokens_crowd"))  # 3
	if _engaged.size() >= 3:
		return int(Tuning.v("attack_tokens_ring"))  # 2
	return 1


## Slots are only worth using when the hero has company.
func slots_active(p: CharacterBody3D) -> bool:
	return _engaged.size() >= 2


## A point on the ring around the hero, unique per enemy, drifting.
func slot_for(e: CharacterBody3D, p: CharacterBody3D) -> Vector3:
	var h := float(e.get_instance_id() % 360)
	var ang := deg_to_rad(h) + _drift
	return p.global_position + Vector3(sin(ang), 0.0, cos(ang)) * 1.55


func can_attack(e: CharacterBody3D) -> bool:
	if e.kind == 4:
		return true  # the boss takes what it wants
	if _attackers.has(e):
		return true
	return _attackers.size() < token_cap()


func attack(e: CharacterBody3D) -> void:
	if _attackers.has(e):
		return
	if e.kind == 4 or _attackers.size() < token_cap():
		_attackers.append(e)


func release(e: CharacterBody3D) -> void:
	_attackers.erase(e)


func attacker() -> CharacterBody3D:
	return _attackers[0] if not _attackers.is_empty() else null


func engaged_count() -> int:
	return _engaged.size()


## --- adaptive memory (bible 4A: tracks last-3-moves and counters spam) -------

## The hero records every move here: "punch_light", "punch_heavy", "dodge",
## "block", "parry", "grab", "super". One home for the whole ring.
func record_player_move(kind: String) -> void:
	_memory.append(kind)
	while _memory.size() > MEMORY_LEN:
		_memory.pop_front()


## True when the hero's last three moves were all `kind` - the definition
## of spam the bible wants punished.
func player_spams(kind: String) -> bool:
	if _memory.size() < MEMORY_LEN:
		return false
	for m in _memory:
		if m != kind:
			return false
	return true


func last_moves() -> Array:
	return _memory.duplicate()
