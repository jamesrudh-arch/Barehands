extends Node
## The city's memory of the hero, by district (street thirds: riverside west,
## market middle, foundry east). Public violence lowers reputation, stylish
## wins raise it; at -50 a district turns hostile and sends its own muscle;
## at high reputation your nickname goes up on the walls as graffiti.
## Witnesses remember recent events; shopkeepers price by how they feel
## about you. Everything persists through the save. Autoloaded as "City".

signal changed()
signal entered_district(district: String, mood: String)

const DISTRICTS := ["riverside", "market", "foundry"]
const HOSTILE_AT := -50.0
const GRAFFITI_SPOTS := {
	"riverside": Vector3(-10.5, 1.6, -8.86),
	"market": Vector3(3.0, 1.9, -9.4),
	"foundry": Vector3(12.0, 1.5, -8.86),
}

var rep := {}  # district -> -100..100 reputation
var hostile := {}  # district -> true once brawls push it over
var witnessed := {}  # district -> array of event strings still remembered
var nickname := "The New Hands"

var _player: CharacterBody3D
var _district_now := ""
var _graffiti: Array[Label3D] = []
var _muscle: Array[CharacterBody3D] = []


func _ready() -> void:
	for d in DISTRICTS:
		rep[d] = 0.0
		hostile[d] = false
		witnessed[d] = []


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return
	var d := district_at(_player.global_position)
	if d != _district_now:
		_district_now = d
		entered_district.emit(d, mood_of(d))
	_hostile_watch()


# --- districts -------------------------------------------------------------------


## Where the hero stands right now (the phone map's YOU-ARE-HERE).
func district_now() -> String:
	return _district_now


func district_at(pos: Vector3) -> String:
	if pos.x < -6.0:
		return "riverside"
	if pos.x > 6.0:
		return "foundry"
	return "market"


func mood_of(d: String) -> String:
	if hostile.get(d, false):
		return "hostile"
	var r: float = rep.get(d, 0.0)
	if r >= 60.0:
		return "your street"
	if r >= 25.0:
		return "friendly"
	if r <= HOSTILE_AT:
		return "turning hostile"
	if r < -20.0:
		return "wary"
	return "indifferent"


# --- events ------------------------------------------------------------------------


## Violence reported from the fight (positions decide the district).
func on_violence(kind: String, pos: Vector3) -> void:
	var d := district_at(pos)
	match kind:
		"knockdown":
			add_rep(d, -8.0, "a body dropped in the " + d)
		"shot":
			add_rep(d, -4.0, "a gunshot in the " + d)
		"hit":
			add_rep(d, -0.8)
		"win":
			add_rep(d, 3.0, "someone went down swinging in the " + d)


## A body went down in a way the street respects.
func on_stylish_win(pos: Vector3, move: String) -> void:
	var d := district_at(pos)
	add_rep(d, 4.0, "the %s in the %s" % [move, d])
	on_violence("win", pos)


func add_rep(d: String, amount: float, event := "") -> void:
	rep[d] = clampf(rep.get(d, 0.0) + amount, -100.0, 100.0)
	if event != "":
		remember(d, event)
	if rep[d] <= HOSTILE_AT and not hostile.get(d, false):
		turn_hostile(d)
	if rep[d] > HOSTILE_AT + 15.0 and hostile.get(d, false):
		hostile[d] = false  # enough good will buys the district back
	changed.emit()
	_check_graffiti(d)


func remember(d: String, event: String) -> void:
	witnessed[d].append({"event": event, "time": Time.get_time_string_from_system()})
	if witnessed[d].size() > 8:
		witnessed[d] = witnessed[d].slice(witnessed[d].size() - 8)


func last_heard(d: String) -> String:
	if witnessed[d].is_empty():
		return ""
	return "They say " + witnessed[d][-1].event + "."


# --- hostility -----------------------------------------------------------------------


func turn_hostile(d: String) -> void:
	hostile[d] = true
	Log.warn("City: the %s turns hostile" % d)
	remember(d, "the %s has had enough of you" % d)


func _hostile_watch() -> void:
	# a hostile district keeps two brawlers on the street while you stand in it
	var want := 2 if hostile.get(_district_now, false) else 0
	for m in _muscle.duplicate():
		if not is_instance_valid(m) or m.state == Enemy.State.DOWN:
			_muscle.erase(m)
		elif want == 0 or district_at(m.global_position) != _district_now:
			(m as Node).queue_free()
			_muscle.erase(m)
	if _muscle.size() < want:
		var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
		e.set("kind", 1)
		e.set("max_hp", 6)
		get_tree().current_scene.add_child(e)
		var ang := randf() * TAU
		e.global_position = Vector3(
				clampf(_player.global_position.x + sin(ang) * 14.0, -17.0, 17.0), 0.02,
				clampf(_player.global_position.z + cos(ang) * 14.0, -17.0, 17.0))
		_muscle.append(e)


# --- graffiti -------------------------------------------------------------------------


func _check_graffiti(d: String) -> void:
	var r: float = rep.get(d, 0.0)
	var text := ""
	if r >= 75.0:
		text = "%s RUNS THE %s" % [nickname.to_upper(), d.to_upper()]
	elif r >= 40.0:
		text = "%s WAS HERE" % nickname.to_upper()
	elif r >= 25.0:
		text = "%s" % nickname.to_upper()
	elif hostile.get(d, false):
		text = nickname.to_upper() + " GO HOME"
	else:
		return
	for g in _graffiti:
		if g.get_meta("district", "") == d:
			g.text = text
			return
	_spawn_graffiti(d, text)


func _spawn_graffiti(d: String, text: String) -> void:
	var g := Label3D.new()
	g.text = text
	g.font_size = 96
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	g.modulate = Color(0.85, 0.2, 0.15)
	g.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	g.no_depth_test = false
	g.fixed_size = false
	g.pixel_size = 0.004
	g.position = GRAFFITI_SPOTS[d]
	g.set_meta("district", d)
	get_tree().current_scene.add_child(g)
	_graffiti.append(g)
	Log.info("City: graffiti in the %s - %s" % [d, text])


func graffiti_texts() -> Array[String]:
	var out: Array[String] = []
	for g in _graffiti:
		out.append(g.text)
	return out


# --- shopkeeping ------------------------------------------------------------------------


## How a shop prices you: reputation discounts, hostility and heat markups.
func price_mult(pos: Vector3) -> float:
	var d := district_at(pos)
	var r: float = rep.get(d, 0.0)
	var m := 1.0
	if r >= 40.0:
		m -= 0.15
	elif r <= -25.0:
		m += 0.15
	if hostile.get(d, false):
		m += 0.15
	if Heat.heat >= 4.0:
		m += 0.10
	return clampf(m, 0.8, 1.4)


func greeting(pos: Vector3) -> String:
	var d := district_at(pos)
	var r: float = rep.get(d, 0.0)
	var line := ""
	if hostile.get(d, false):
		line = "You're not wanted here. Everything costs extra."
	elif r >= 40.0:
		line = "Good to see you, friend. Friend prices."
	elif r >= 10.0:
		line = "Heard your name once or twice. Respect."
	elif r <= -25.0:
		line = "You're trouble. Trouble pays full price."
	else:
		line = "New face. Standard prices."
	var heard := last_heard(d)
	if heard != "":
		line += "  " + heard
	return line


# --- persistence ---------------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"rep": rep, "hostile": hostile, "witnessed": witnessed, "nickname": nickname}


func from_dict(d: Dictionary) -> void:
	rep = d.get("rep", {})
	hostile = d.get("hostile", {})
	witnessed = d.get("witnessed", {})
	nickname = d.get("nickname", nickname)
	for dd in DISTRICTS:
		if not rep.has(dd):
			rep[dd] = 0.0
		if not witnessed.has(dd):
			witnessed[dd] = []
		hostile[dd] = hostile.get(dd, false)
	changed.emit()
	for dd in DISTRICTS:
		_check_graffiti(dd)
