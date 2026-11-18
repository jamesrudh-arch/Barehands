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
		"version": 2,
		"wallet": Wallet.to_dict(),
		"heat": Heat.to_dict(),
		"gear": p.get("gear") if p else {},
		"look": p.get("look") if p else "shadow",
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z] if p else [0, 0, 0],
		"style_value": style.get("value") if style else 0.0,
		"city": City.to_dict(),
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
	if parsed is not Dictionary or int(parsed.get("version", 0)) != 2:
		Log.warn("SaveGame: incompatible save")
		return false
	Wallet.from_dict(parsed.get("wallet", {}))
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
	var style := get_tree().get_first_node_in_group("style") as Control
	if style:
		style.set("value", float(parsed.get("style_value", 0.0)))
	Log.info("SaveGame: loaded ($%d, heat %.1f)" % [Wallet.cash, Heat.heat])
	return true


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
