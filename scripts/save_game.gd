extends Node
## Save/load. Autoloaded as "SaveGame". One JSON file, user://save.json:
## wallet, heat, gear and look, style rank value, hero position, and the
## city-memory dictionary Phase 6 fills in. Writing is atomic (temp then
## replace) so a kill mid-save cannot corrupt it.

const PATH := "user://save.json"


func save_all() -> bool:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var style := get_tree().get_first_node_in_group("style") as Control
	var d := {
		"version": 6,
		"wallet": Wallet.to_dict(),
		"heat": Heat.to_dict(),
		"gear": p.get("gear") if p else {},
		"look": p.get("look") if p else "shadow",
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z] if p else [0, 0, 0],
		"style_value": style.get("value") if style else 0.0,
		"city": City.to_dict(),
		"progression": Progression.to_dict(),
		"styles": Styles.to_dict(),
		"phone": Phone.to_dict(),
		"trust": Trust.to_dict(),
		"ledger": Ledger.to_dict(),
		"vehicle": _vehicle_dict(),
	}
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		Log.error("SaveGame: cannot write")
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH + ".tmp"),
			ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	Log.info("SaveGame: saved ($%d, heat %.1f)" % [Wallet.cash, Heat.heat])
	return true


func load_all() -> bool:
	if not FileAccess.file_exists(PATH):
		Log.warn("SaveGame: no save file")
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary or int(parsed.get("version", 0)) < 2:
		Log.warn("SaveGame: incompatible save")
		return false
	Wallet.from_dict(parsed.get("wallet", {}))
	# styles ride in save v4+; older saves predate them and start clean
	Styles.from_dict(parsed.get("styles", {}))
	# the phone and its trust ledger ride in v5+, the debt book in v6
	Phone.from_dict(parsed.get("phone", {}))
	Trust.from_dict(parsed.get("trust", {}))
	Ledger.from_dict(parsed.get("ledger", {}))
	Progression.from_dict(parsed.get("progression", {}))
	Heat.from_dict(parsed.get("heat", {}))
	City.from_dict(parsed.get("city", {}))
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p:
		var pos: Array = parsed.get("pos", [0, 0, 0])
		p.global_position = Vector3(pos[0], pos[1] + 0.02, pos[2])
		p.velocity = Vector3.ZERO
		p.apply_look(parsed.get("look", "shadow"))
		p.set("gear", parsed.get("gear", {}))
		p.reapply_gear()
	_load_vehicle(parsed.get("vehicle", []))
	var style := get_tree().get_first_node_in_group("style") as Control
	if style:
		style.set("value", float(parsed.get("style_value", 0.0)))
	Log.info("SaveGame: loaded ($%d, heat %.1f)" % [Wallet.cash, Heat.heat])
	return true


var _vehicle_cache := {}  # name -> [x, y, z, yaw], remembered from the save


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func describe() -> String:
	if not has_save():
		return "no save on file"
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else {}
	f.close()
	if d is Dictionary:
		var w: Dictionary = d.get("wallet", {})
		return "save: $%s   heat %s   %s" % [str(w.get("cash", "?")),
				str(d.get("heat", {}).get("heat", "?")), Time.get_date_string_from_system()]
	return "save unreadable"


## B25: the hero's car persists where it was left - a real vehicle is
## part of the world state, not a scene prop that resets on load.
## B26 WHEELS EVERYWHERE: the street parks several vehicles now (the
## sedan, the second car, the bicycle, one per far block) - every one
## of them persists, BY NAME, so a rebuilt block can put its own car
## back where the hero left it.
func _vehicle_dict() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v is Node3D:
			out.append({
				"n": (v as Node).name,
				"p": [(v as Node3D).global_position.x,
						(v as Node3D).global_position.y,
						(v as Node3D).global_position.z],
				"r": (v as Node3D).rotation.y,
			})
	return out


func _load_vehicle(arr: Array) -> void:
	_vehicle_cache.clear()
	if arr.size() == 4 and arr[0] is float:
		# a B25 save: one flat [x, y, z, yaw] for the one sedan
		_vehicle_cache["ParkedCar"] = [arr[0], arr[1], arr[2], arr[3]]
	else:
		for e in arr:
			if e is Dictionary and e.has("n") and e.has("p"):
				var p: Array = e["p"]
				_vehicle_cache[str(e["n"])] = [p[0], p[1], p[2],
						float(e.get("r", 0.0))]
	# every vehicle present right now (re)takes its saved spot; the
	# far blocks are not built yet and ask later via apply_saved_state
	for v in get_tree().get_nodes_in_group("vehicle"):
		_apply_saved(v)
	if not _vehicle_cache.is_empty():
		Log.info("SaveGame: %d vehicle(s) back where you left them"
				% _vehicle_cache.size())


## Applies the remembered state to one vehicle - occupied vehicles are
## skipped (the hero is aboard; the world must not move his seat).
func _apply_saved(v: Node) -> void:
	if not (v is Node3D) or not _vehicle_cache.has(v.name):
		return
	if bool(v.get("occupied")):
		return
	var a: Array = _vehicle_cache[v.name]
	(v as Node3D).global_position = Vector3(a[0], a[1], a[2])
	(v as Node3D).rotation.y = a[3]


## B26: a rebuilt block parks its own car, then asks where the save
## left it (blocks are torn down and rebuilt as the hero walks the
## city; their vehicles are new nodes every time).
func apply_saved_state(v: Node) -> void:
	_apply_saved(v)
