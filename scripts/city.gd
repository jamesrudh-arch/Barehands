extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
## The city's memory of the hero, by district (street thirds: riverside west,
## market middle, foundry east). Public violence lowers reputation, stylish
## wins raise it; at -50 a district turns hostile and sends its own muscle;
## at high reputation your nickname goes up on the walls as graffiti.
## Witnesses remember recent events; shopkeepers price by how they feel
## about you. Everything persists through the save. Autoloaded as "City".

signal changed()
signal entered_district(district: String, mood: String)

const DISTRICTS := ["riverside", "market", "foundry"]

## What each block IS (bible 6), for the map and the rumors.
const BLOCK_INFO := {
	"riverside": {"name": "RIVERSIDE ROW",
		"blurb": "your block - the alley, the noodle shop, the bar"},
	"market": {"name": "THE CLUB QUARTER",
		"blurb": "main street, the gym, the Mechanic's garage"},
	"foundry": {"name": "THE DOCKS",
		"blurb": "the warehouse, the water, the shut door"},
}
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
	# batch 8: districts change only through the Blocks walk -
	# set_current_district is authoritative, no position scan fights it
	_hostile_watch()


# --- districts -------------------------------------------------------------------


## Where the hero stands right now (the phone map's YOU-ARE-HERE).
func district_now() -> String:
	return _district_now


func district_at(pos: Vector3) -> String:
	# batch 8: one block = one district; the walk sets _district_now
	# authoritatively and everything reads the same answer. Logic
	# suites run without a scene - before the first walk, the home
	# block answers, never an empty string.
	if _district_now.is_empty():
		return "riverside"
	return _district_now


## The walk between blocks lands here (fog, music and moods ride the
## signal). Guarded so nothing re-broadcasts the same block.
func set_current_district(d: String) -> void:
	if d == _district_now:
		return
	_district_now = d
	entered_district.emit(d, mood_of(d))
	changed.emit()


## The scars a block carries (bible 6 damage layer): where bodies
## dropped, and where the hero died. LOCAL to each block.
var _damage: Dictionary = {}   # block -> [{pos: Vector3}]
var _deaths: Dictionary = {}   # block -> [{pos: Vector3}]
const DAMAGE_CAP := 12


func note_damage(pos: Vector3, kind: String) -> void:
	note_damage_in(district_at(pos), pos, kind)


## A mark on a block you are NOT standing in (a friend's business
## eating your overuse, world events elsewhere).
func note_damage_in(d: String, pos: Vector3, kind: String) -> void:
	var local := Vector3(pos.x - Blocks.BLOCK_X[d], pos.y, pos.z)
	var list: Array = _damage.get(d, [])
	list.append({"pos": local, "kind": kind})
	while list.size() > DAMAGE_CAP:
		list.pop_front()
	_damage[d] = list
	changed.emit()


func note_death(pos: Vector3) -> void:
	var d := district_at(pos)
	var local := Vector3(pos.x - Blocks.BLOCK_X[d], pos.y, pos.z)
	var list: Array = _deaths.get(d, [])
	list.append({"pos": local})
	while list.size() > 6:
		list.pop_front()
	_deaths[d] = list
	Log.info("City: someone died in the %s - the block remembers" % d)


func damage_points(d: String) -> Array:
	var pts: Array = []
	for e in _damage.get(d, []):
		pts.append(e["pos"])
	return pts


func death_points(d: String) -> Array:
	var pts: Array = []
	for e in _deaths.get(d, []):
		pts.append(e["pos"])
	return pts


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
			note_damage(pos, "scorch")
		"shot":
			add_rep(d, -4.0, "a gunshot in the " + d)
			note_damage(pos, "scorch")
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
	witnessed[d].append({"event": event,
			"time": Time.get_time_string_from_system(), "day": Ledger.day})
	if witnessed[d].size() > 8:
		witnessed[d] = witnessed[d].slice(witnessed[d].size() - 8)


func last_heard(d: String) -> String:
	if witnessed[d].is_empty():
		return ""
	# rumors distort over retellings (bible 4I): the street grows the
	# story every time a beat is spent on it
	var e: Dictionary = witnessed[d][-1]
	var tells := int(e.get("tells", 0))
	if tells >= 3:
		return "They SWEAR " + str(e.event) + " - and the number is bigger now."
	if tells >= 1:
		return "They say " + str(e.event) + ". It grows every telling."
	return "They say " + str(e.event) + "."


## The street forgets slowly (world sim): rumors older than the
## tuning's days stop being retold. Returns how many were let go.
func age_rumors(new_day: int) -> int:
	var keep_days := int(Tuning.v("rumor_age_days"))
	var pruned := 0
	for d in DISTRICTS:
		var keep: Array = []
		for e in witnessed[d]:
			if int(e.get("day", 1)) >= new_day - keep_days:
				keep.append(e)
			else:
				pruned += 1
		witnessed[d] = keep
	return pruned


# --- hostility -----------------------------------------------------------------------


func turn_hostile(d: String) -> void:
	hostile[d] = true
	Log.warn("City: the %s turns hostile" % d)
	remember(d, "the %s has had enough of you" % d)


func _hostile_watch() -> void:
	# a hostile district keeps two brawlers on the street while you stand in it
	var want := 2 if hostile.get(_district_now, false) else 0
	for m in _muscle.duplicate():
		if not is_instance_valid(m):
			_muscle.erase(m)
		elif m.state == CLS_Enemy.State.DOWN:
			# B18.4 stress leak (same rule as Heat's responders): a downed
			# man is dragged off after a beat - never an untracked respawn
			# standing back up inside a hostile district forever.
			if float(m.get("_state_t")) > 2.0:
				(m as Node).queue_free()
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
	# a scene reload frees the labels; the autoload cache must prune,
	# and a freed object can never be erased from a typed array by value
	var alive: Array[Label3D] = []
	for g in _graffiti:
		if is_instance_valid(g):
			alive.append(g)
	_graffiti = alive
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
		if is_instance_valid(g):
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
	# a hollow block is an expensive block (bible 4I: prices rise,
	# doors close): wary shelves are thin, turning hostile they're empty
	var mood := mood_of(d)
	if mood == "wary":
		m += float(Tuning.v("hollow_wary_markup"))
	elif mood == "turning hostile":
		m += float(Tuning.v("hollow_turning_markup"))
	return clampf(m, 0.8, 1.5)


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
	var mood := mood_of(d)
	if mood == "wary" and not hostile.get(d, false):
		line = "Shelves are thinning. The prices aren't mine anymore."
	elif mood == "turning hostile":
		line = "We close early now. You know why."
	var heard := last_heard(d)
	if heard != "":
		line += "  " + heard
	return line


# --- persistence ---------------------------------------------------------------------------


## What the street whispers on a given block: the mood, the last
## thing anyone saw, and the block's own weather.
func rumor(d: String) -> Array:
	var pool: Array = []
	match mood_of(d):
		"your street":
			pool.append("this block still says your name right")
			pool.append("nobody starts anything on this street")
		"friendly":
			pool.append("good night for it, they say")
			pool.append("the %s's been quiet since you cleaned it up" % d)
		"wary":
			pool.append("people cross the road when you pass lately")
		"turning hostile":
			pool.append("stay off this block a while. just a while")
		"hostile":
			pool.append("you shouldn't be walking here")
	var heard := last_heard(d)
	if not heard.is_empty():
		pool.append("they're saying: " + heard)
	return pool if not pool.is_empty() else ["quiet night"]


## One line, for the wanderers' bubbles.
func rumor_line(d: String) -> String:
	var pool := rumor(d)
	return pool[randi() % pool.size()]


func to_dict() -> Dictionary:
	return {"rep": rep, "hostile": hostile, "witnessed": witnessed,
			"nickname": nickname, "damage": _damage, "deaths": _deaths}


func from_dict(d: Dictionary) -> void:
	rep = d.get("rep", {})
	hostile = d.get("hostile", {})
	witnessed = d.get("witnessed", {})
	nickname = d.get("nickname", nickname)
	_damage = d.get("damage", {})
	_deaths = d.get("deaths", {})
	for dd in DISTRICTS:
		if not rep.has(dd):
			rep[dd] = 0.0
		if not witnessed.has(dd):
			witnessed[dd] = []
		hostile[dd] = hostile.get(dd, false)
	changed.emit()
	for dd in DISTRICTS:
		_check_graffiti(dd)
