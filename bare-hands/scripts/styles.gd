extends Node
## The five styles (Batch 3, bible 4A): "Five styles, learned from people,
## never lost: Brawler (Brother), Kickboxing (Bouncer), Grappling
## (Collector), Drunken (The Drunk), Weapon (Lieutenant)."
##
## A style is a MOVE LIST: the hero's fundamentals (jab/cross/hook chain,
## heavy, kick, grab, dodge, block, parry) are common to every style, and
## the combo STRINGS plus one Dirty Street Tactic belong to a style. The
## style is learned from a person and never lost; switching (the wheel)
## makes that move list live. Style countering stays a SOFT bonus (4A):
## fighting the enemy kind your style reads best gives extra STYLE POINTS,
## never extra damage.
##
## The teachers are story people who have not arrived as NPCs yet (the cast
## today is Velvet, Pilsner, Marrow, the Duchess) - until their story beats
## land, styles unlock by level and the banner credits the teacher by name.

signal style_changed(id: String)
signal style_learned(id: String)

const STYLES := [
	{
		"id": "brawler", "name": "BRAWLER", "teacher": "Brother",
		"unlock_level": 1, "color": Color(0.85, 0.55, 0.25),
		"counters_kind": 1,
		"desc": "Fists first, questions never. The street-fundamental style - the one your brother drilled into you.",
	},
	{
		"id": "kickboxing", "name": "KICKBOXING", "teacher": "the Bouncer",
		"unlock_level": 3, "color": Color(0.3, 0.75, 0.55),
		"counters_kind": 3,
		"desc": "Range is a weapon. Snapping kicks that keep the knives honest, taught by a man paid to stand in doorways.",
	},
	{
		"id": "grappling", "name": "GRAPPLING", "teacher": "the Collector",
		"unlock_level": 5, "color": Color(0.55, 0.45, 0.8),
		"counters_kind": 2,
		"desc": "The style of people who collect debts with their hands. Grabs, throws, and the pavement as a weapon.",
	},
	{
		"id": "drunken", "name": "DRUNKEN BOXING", "teacher": "the Drunk",
		"unlock_level": 7, "color": Color(0.85, 0.75, 0.3),
		"counters_kind": 4,
		"desc": "Looks like falling, fights like a prophecy. Sways, spins and counters nobody can read twice.",
	},
	{
		"id": "weapon", "name": "WEAPON", "teacher": "the Lieutenant",
		"unlock_level": 9, "color": Color(0.8, 0.3, 0.3),
		"counters_kind": -1,
		"desc": "The Lieutenant's answer to everything: pick something up. The pipe is a style; so is whatever comes next.",
	},
]

var current := "brawler"
var _learned: Array = ["brawler"]  # learned is forever (bible: never lost)


func _ready() -> void:
	# level-ups can teach styles; the wheel/menu can switch
	var p := get_node_or_null("/root/Progression")
	if p:
		p.levelled.connect(_on_level)


func _on_level(new_level: int, _unlocked: Array) -> void:
	for s in STYLES:
		if int(s["unlock_level"]) <= new_level and not _learned.has(s["id"]):
			_learned.append(s["id"])
			style_learned.emit(s["id"])
			Log.info("Styles: learned %s from %s" % [s["name"], s["teacher"]])
			# auto-equip a freshly learned style the first time: the player
			# should FEEL the new move list immediately
			switch_to(s["id"])


## May the hero switch to this style? (Learned is forever.)
func can_switch(id: String) -> bool:
	return _learned.has(id)


func switch_to(id: String) -> bool:
	if not can_switch(id) or id == current:
		return false
	current = id
	style_changed.emit(id)
	Log.info("Styles: now fighting %s" % def(id)["name"])
	return true


func def(id: String) -> Dictionary:
	for s in STYLES:
		if s["id"] == id:
			return s
	return {}


func current_def() -> Dictionary:
	return def(current)


func learned() -> Array:
	return _learned.duplicate()


## --- the soft style counter (bible 4A: SOFT bonus, style points only) ----

## True when the CURRENT style reads this enemy kind - landed hits bank
## bonus style points, never bonus damage.
func counters_kind(kind: int) -> bool:
	return int(current_def().get("counters_kind", -1)) == kind


## The soft bonus multiplier on style points vs a countered kind.
func counter_style_mult(kind: int) -> float:
	return 1.3 if counters_kind(kind) else 1.0


## --- persistence --------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"current": current, "learned": _learned.duplicate()}


func from_dict(d: Dictionary) -> void:
	current = "brawler"
	_learned = ["brawler"]
	var l: Array = d.get("learned", [])
	for id in l:
		if def(id) != {} and not _learned.has(id):
			_learned.append(id)
	var c: String = d.get("current", "brawler")
	if _learned.has(c):
		current = c


func reset_for_test() -> void:
	current = "brawler"
	_learned = ["brawler"]


func unlock_all_for_test() -> void:
	for s in STYLES:
		if not _learned.has(s["id"]):
			_learned.append(s["id"])
