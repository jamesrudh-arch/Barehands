extends Node
## Levels and unlocks (combo pass PART 3), autoloaded as "Progression".
## XP comes from landed hits, parries, takedowns, varied strings and (the
## Stage B/C hook) missions. Combos unlock from level 2 upward - a new
## player has NO combos, only single presses. Levels also buy perks:
## combo cancels (5), a wider combo window (every level, capped), and a
## wider super shockwave. Level and xp persist in the save (v3).

signal levelled(new_level: int, unlocked_ids: Array)

var level := 1
var xp := 0.0
var _pending_banner: Array = []


func _ready() -> void:
	# wire the XP sources that live on scene nodes as they appear
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Player:
		(node as Player).hit_landed.connect(func(_k: String, _d: int) -> void:
			add_xp(1.0, "hit"))


## XP needed to clear level n.
func xp_needed(n: int) -> float:
	return 20.0 + float(n - 1) * 12.0


func add_xp(amount: float, _why: String = "") -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		var unlocked: Array = []
		for c in ComboTable.ALL:
			if int(c["level"]) == level:
				unlocked.append(c["id"])
		Log.info("Progression: level %d (unlocked: %s)" % [level, str(unlocked)])
		levelled.emit(level, unlocked)
		_notify_level(unlocked)


## Missions (Stage B/C) pay out here.
func mission_complete() -> void:
	add_xp(25.0, "mission")


func _notify_level(unlocked: Array) -> void:
	var bar := get_tree().get_first_node_in_group("level_bar")
	if bar:
		# in-game: the banner carries the unlocked move demos
		bar.level_up(level, unlocked)
	else:
		_pending_banner = unlocked


## The bar calls this on ready if a level-up happened before it existed.
func take_pending() -> Array:
	var p := _pending_banner
	_pending_banner = []
	return p


# --- the gates ------------------------------------------------------------------


## May this combo fire? (Level 1: nothing - single presses only.)
func combo_unlocked(id: String) -> bool:
	var def := ComboTable.by_id(id)
	if def.is_empty():
		return false
	return int(def["level"]) <= level


## Combos unlock level by level; every unlocked combo's level.
func unlock_level(id: String) -> int:
	var def := ComboTable.by_id(id)
	return int(def.get("level", 99))


## Perk (level 5): dodge can cancel a combo string.
func combo_cancel_unlocked() -> bool:
	return level >= 5


## Perk: each level widens the combo input window a touch (capped +0.2 s).
func combo_window_bonus() -> float:
	return minf(0.2, 0.02 * float(level - 1))


## Perk: each level widens the SUPER shockwave (capped +30%).
func super_radius_mult() -> float:
	return minf(1.3, 1.0 + 0.03 * float(level - 1))


# --- persistence ------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp}


func from_dict(d: Dictionary) -> void:
	level = maxi(1, int(d.get("level", 1)))
	xp = maxf(0.0, float(d.get("xp", 0.0)))
	Log.info("Progression: level %d, %.0f/%.0f xp" % [level, xp, xp_needed(level)])


func reset_for_test() -> void:
	level = 1
	xp = 0.0
	_pending_banner = []
