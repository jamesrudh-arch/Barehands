extends Node

## THE WEB OF LEVERAGE (S5.13): the game's name. Clues from three
## streets - Marla's bar rumours, interrogations after mission
## fights, tailing a walker who walks like a man with somewhere to
## be. Two linked pieces of dirt on one target unlock EXTORTION at
## their spot (the money, the trust price). Clues go STALE after
## three beats - old dirt is weak dirt.

signal clue_found(text: String, target: String)

## the rumour ladder (Marla talks, one per beat, in order)
const RUMOURS := [
	{"target": "VESPER", "kind": "the rumour",
		"text": "Vesper's books have two sets of numbers."},
	{"target": "VESPER", "kind": "the rumour",
		"text": "The Velvet Room's back room pays the Corporation's collectors."},
	{"target": "TONY", "kind": "the rumour",
		"text": "Tony's gym launders the weight in the basement."},
	{"target": "SAL", "kind": "the rumour",
		"text": "The fish market's crates aren't all fish."},
]

## the extortion spots (offset from the market's vendor spots -
## the market's grab wins at its own coordinates)
const SPOTS := {
	"VESPER": {"pos": Vector3(-41.5, 0.05, 1.0),
			"area": "club_district", "take": 200.0, "trust": -25.0},
	"TONY": {"pos": Vector3(-35.5, 0.05, 1.6),
			"area": "club_district", "take": 150.0, "trust": -20.0},
	"SAL": {"pos": Vector3(26.0, 0.05, -3.6),
			"area": "docks", "take": 150.0, "trust": -20.0},
}

var _rumour_i := 0
var _last_rumour_beat := -1
var _tail_need := 15.0  # seconds inside the tail bubble (tests tune)
var _tail_node: Node3D = null
var _tail_t := 0.0


func _ready() -> void:
	name = "Leverage"
	add_to_group("leverage")
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldState.event_fired.connect(_on_event)


func _process(delta: float) -> void:
	_tail_tick(delta)


# --- the clue pool -----------------------------------------------------

func clues() -> Array:
	return WorldState.get_value("leverage_clues", [])


func has_clue(text: String) -> bool:
	for c in clues():
		if str(c.get("text", "")) == text:
			return true
	return false


func clue_stale(c: Dictionary) -> bool:
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws == null:
		return false
	return int(ws.beat()) - int(c.get("beat", 0)) >= 3


## two non-stale clues on one target = linked dirt
func linked(target: String) -> bool:
	var n := 0
	for c in clues():
		if str(c.get("target", "")) == target and not clue_stale(c):
			n += 1
	return n >= 2


func _add_clue(target: String, kind: String, text: String) -> void:
	if has_clue(text):
		return
	var ws := get_tree().get_first_node_in_group("worldsim")
	var lst: Array = clues()
	lst.append({"target": target, "kind": kind, "text": text,
			"beat": int(ws.beat()) if ws else 0})
	WorldState.set_value("leverage_clues", lst)
	clue_found.emit(text, target)
	WorldState.push_event("clue", {"target": target,
			"kind": kind, "text": text})
	Log.info("Leverage: CLUE (%s) - %s" % [target, text])
	Haptics.fire("tick")


# --- source 1: the bar's rumours ---------------------------------------

## GRAB at the bar front: Marla talks, once a beat
const BAR_AT := Vector3(-4.6, 0.05, 5.4)

func _rumour(hero: Node3D) -> bool:
	if Game.area_id != "neighbourhood":
		return false
	if hero.global_position.distance_to(BAR_AT) > 3.4:
		return false
	var ws := get_tree().get_first_node_in_group("worldsim")
	if ws != null and int(ws.beat()) == _last_rumour_beat:
		WorldState.push_event("vendor_no", {"who": "MARLA",
				"msg": "I said what I said. Ask me tomorrow."})
		return true
	_last_rumour_beat = int(ws.beat()) if ws else 0
	if _rumour_i >= RUMOURS.size():
		WorldState.push_event("vendor_no", {"who": "MARLA",
				"msg": "That's everything I know, and more than I should."})
		return true
	var r: Dictionary = RUMOURS[_rumour_i]
	_rumour_i += 1
	WorldState.set_value("rumour_i", _rumour_i)
	_add_clue(str(r["target"]), str(r["kind"]), str(r["text"]))
	return true


# --- source 2: interrogations (the fight's yield) -----------------------

func _on_event(kind: String, _data: Dictionary) -> void:
	if str(kind) != "enemy_down":
		return
	# a mission's man talks when he's down: every mission-spawned
	# body yields intel (capped - the street only knows so much)
	var mine := false
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		if is_instance_valid(e):
			mine = true
			break
	if not mine or clues().size() >= 6:
		return
	var roll := randi() % 3
	match roll:
		0:
			_add_clue("THE COLLECTOR", "the interrogation",
					"The route runs the container gap to Warehouse 9.")
		1:
			_add_clue("THE CORPORATION", "the interrogation",
					"The pistol's serials were filed before the sale.")
		2:
			_add_clue("THE COLLECTOR", "the interrogation",
					"He collects on Fridays. He hates the rain more than you.")


# --- source 3: tailing ---------------------------------------------------

func _tail_tick(delta: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null or not is_instance_valid(hero):
		_tail_node = null
		_tail_t = 0.0
		return
	var nearest: Node3D = null
	var nd := 6.0
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if not is_instance_valid(p):
			continue
		var d: float = hero.global_position.distance_to(
				(p as Node3D).global_position)
		if d < nd:
			nd = d
			nearest = p
	if nearest != null and nearest == _tail_node:
		_tail_t += delta
		if _tail_t >= _tail_need:
			_tail_t = -3600.0  # once per walker (a long cooldown)
			_add_clue("THE COLLECTOR", "the tail",
					"The walker circles the same three blocks before the fish market.")
	elif nearest != null:
		_tail_node = nearest
		_tail_t = 0.0
	else:
		_tail_node = null
		_tail_t = 0.0


# --- the verb: GRAB feeds rumours + extortion ---------------------------

func try_grab(hero: Node3D) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	if _rumour(hero):
		return true
	return _extort(hero)


func _extort(hero: Node3D) -> bool:
	for target in SPOTS:
		var s: Dictionary = SPOTS[target]
		if Game.area_id != str(s["area"]):
			continue
		if hero.global_position.distance_to(
				s["pos"]) > 3.2:
			continue
		if WorldState.flag("extorted:" + target):
			WorldState.push_event("vendor_no", {"who": target,
					"msg": "We're square. Don't come back."})
			return true
		if not linked(target):
			# two stale clues read differently than no clues
			var any_dirt := 0
			for c in clues():
				if str(c.get("target", "")) == target:
					any_dirt += 1
			if any_dirt >= 2:
				WorldState.push_event("vendor_no", {"who": target,
						"msg": "That's old news. The street forgot. So will they."})
			else:
				WorldState.push_event("vendor_no", {"who": target,
						"msg": "You don't have enough on me. Not yet."})
			return true
		WorldState.set_flag("extorted:" + target)
		WorldState.bump("clean_cash", float(s["take"]))
		# trust floors at its 70 default (bump reads 0 - S5.13 law)
		var tkey: String = "trust:" + str(target).to_lower()
		WorldState.set_value(tkey, maxf(0.0,
				float(WorldState.get_value(tkey, 70.0))
				+ float(s["trust"])))
		WorldState.push_event("vendor_yes", {"who": target,
				"msg": "Fine. Take it. And we never had this conversation."})
		Log.info("Leverage: EXTORTED %s (+$%d clean, trust %.0f)" % [
				target, int(s["take"]), float(s["trust"])])
		return true
	return false
