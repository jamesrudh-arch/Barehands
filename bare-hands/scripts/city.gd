extends Node
## The city's memory of the hero, by district. Autoloaded as "City".
## Phase 5 ships the persistence shell (the save file round-trips it);
## Phase 6 fills it with behaviour: reputation prices, hostile districts,
## graffiti, witnesses.

signal changed()

const DISTRICTS := ["riverside", "market", "foundry"]

var rep := {}  # district -> -100..100 reputation
var hostile := {}  # district -> true once brawls push it over
var witnessed := {}  # district -> array of event strings still remembered
var nickname := "The New Hands"


func _ready() -> void:
	for d in DISTRICTS:
		rep[d] = rep.get(d, 0)
		hostile[d] = hostile.get(d, false)
		witnessed[d] = witnessed.get(d, [])


## Which district a world position belongs to (thirds of the street block).
func district_at(pos: Vector3) -> String:
	if pos.x < -6.0:
		return "riverside"
	if pos.x > 6.0:
		return "foundry"
	return "market"


func add_rep(pos: Vector3, amount: int, event := "") -> void:
	var d := district_at(pos)
	rep[d] = clampi(rep.get(d, 0) + amount, -100, 100)
	if event != "":
		remember(d, event)
	changed.emit()


func remember(district: String, event: String) -> void:
	witnessed[district].append({"event": event, "time": Time.get_time_string_from_system()})
	if witnessed[district].size() > 8:
		witnessed[district] = witnessed[district].slice(witnessed[district].size() - 8)


func to_dict() -> Dictionary:
	return {"rep": rep, "hostile": hostile, "witnessed": witnessed, "nickname": nickname}


func from_dict(d: Dictionary) -> void:
	rep = d.get("rep", {})
	hostile = d.get("hostile", {})
	witnessed = d.get("witnessed", {})
	nickname = d.get("nickname", nickname)
	for dd in DISTRICTS:
		if not rep.has(dd):
			rep[dd] = 0
		if not witnessed.has(dd):
			witnessed[dd] = []
		hostile[dd] = hostile.get(dd, false)
	changed.emit()
