extends Node
## Heat: 0 to 5 stars of police attention. Public violence raises it -
## knockdowns, gunshots above all - and it decays only while the hero is out
## of sight and out of trouble. Higher heat summons escalating street
## response (brawlers, then a knife, then a bruiser) that hunts the hero;
## they walk away when the heat dies. Autoloaded as "Heat".

signal changed(heat: float)

const MAX := 5.0
const DECAY_DELAY := 5.0
const DECAY_RATE := 0.15
const SIGHT_RANGE := 12.0
const RESPONSE_COOLDOWN := 12.0

var heat := 0.0
var _calm_since := 0.0
var _t := 0.0
var _responders: Array[CharacterBody3D] = []
var _last_response := -99.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null:
		return
	# out of sight and no fight for a while -> the street forgets
	var seen := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.kind == 0:
			continue  # a training dummy witnesses nothing
		if e.state != Enemy.State.DOWN and \
				e.global_position.distance_to(p.global_position) < SIGHT_RANGE:
			seen = true
			break
	if seen:
		_calm_since = _t + DECAY_DELAY  # violence seen: the timer restarts
	elif _t >= _calm_since:
		add(-DECAY_RATE * delta)  # out of sight and calm: the street forgets
	_enemy_floor()  # the permanent enemy never lets it fully cool
	Music.set_heat(heat)
	_response(delta, p)


## Public violence feeds the meter. Loud things cost more.
## The kidnap arc's permanent enemy (bible 4H): the heat never fully
## cools while they own the streets' fear.
func _enemy_floor() -> void:
	if Kidnap.permanent_enemy and heat < float(Tuning.v("kidnap_enemy_floor")):
		heat = float(Tuning.v("kidnap_enemy_floor"))


## The named ladder (bible 4I): the HUD and the radio read it.
func tier_name() -> String:
	if heat >= Tuning.v("copy_at"):
		return "the war"
	if heat >= 4.0:
		return "hunted"
	if heat >= 2.0:
		return "marked"
	if heat >= 1.0:
		return "talked about"
	return "quiet"


var test_pin_eyes := -1  # suites pin this (>= 0) to freeze the witness count


func add(amount: float) -> void:
	var was := heat
	# crowds are witnesses, alleys are not (bible 4I): a street with
	# eyes pays you back, an empty one lets it slide. Suites pin
	# test_pin_eyes (the x1.0 single-witness band) so heat arithmetic
	# is deterministic - wanderers roam, and a roaming witness is a
	# dice roll no assertion should ride on.
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and amount > 0.0:
		var eyes := test_pin_eyes
		if eyes < 0:
			eyes = 0
			for w in get_tree().get_nodes_in_group("wanderer"):
				if (w as Node3D).global_position.distance_to(
						p.global_position) < 10.0:
					eyes += 1
		if eyes >= 2:
			amount *= float(Tuning.v("witness_mult"))
		elif eyes == 0:
			amount *= float(Tuning.v("alley_mult"))
	heat = clampf(heat + amount, 0.0, MAX)
	if not is_equal_approx(heat, was):
		changed.emit(heat)


func stars() -> int:
	return roundi(heat)


## Enemy knockdowns and gunshots report in here - to the meter and the city.
func on_violence(kind: String, pos: Vector3 = Vector3.ZERO) -> void:
	City.on_violence(kind, pos)
	match kind:
		"knockdown":
			add(0.4)
		"shot":
			add(0.6)  # a gunshot on a night street travels
		"hit":
			add(0.08)


func _response(_delta: float, p: CharacterBody3D) -> void:
	# the response only stands while the heat stands
	# freed responders can't be erased from a typed array by value -
	# filter the array instead, or the dead entry errors every frame
	var valid: Array[CharacterBody3D] = []
	for r in _responders:
		if is_instance_valid(r):
			valid.append(r)
	_responders = valid
	for r in _responders.duplicate():
		if r.state == Enemy.State.DOWN:
			_responder_gone(r)
		elif heat < 1.0:
			(r as Node).queue_free()
			_responder_gone(r)
	var want := 0
	if heat >= 4.0:
		want = 4
	elif heat >= 3.0:
		want = 3
	elif heat >= 2.0:
		want = 2
	elif heat >= 1.0:
		want = 1
	# reinforce up to the wanted count, on a cooldown
	if _responders.size() < want and _t - _last_response > RESPONSE_COOLDOWN:
		_last_response = _t
		var kind := 1
		if _responders.size() >= 2 and heat >= 3.0:
			kind = 3  # a knife joins late
		if heat >= 5.0 and _responders.size() >= 3:
			kind = 2  # at five stars, the bruiser walks in
		_spawn_responder(kind, p)


func _spawn_responder(kind: int, p: CharacterBody3D) -> void:
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	e.set("kind", kind)
	e.set("max_hp", 5 if kind != 2 else 12)
	get_tree().current_scene.add_child(e)
	# arrive from a street edge, toward the player
	var ang := randf() * TAU
	e.global_position = Vector3(
			clampf(p.global_position.x + sin(ang) * 16.0, -17.0, 17.0), 0.02,
			clampf(p.global_position.z + cos(ang) * 16.0, -17.0, 17.0))
	_responders.append(e)
	Log.info("Heat: responder kind %d arrives (heat %.1f)" % [kind, heat])


func _responder_gone(r: CharacterBody3D) -> void:
	_responders.erase(r)


func responders() -> Array[CharacterBody3D]:
	return _responders


func to_dict() -> Dictionary:
	return {"heat": heat}


func from_dict(d: Dictionary) -> void:
	heat = clampf(float(d.get("heat", 0.0)), 0.0, MAX)
	changed.emit(heat)
