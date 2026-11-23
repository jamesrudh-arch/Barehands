extends Node

## THE SAVE (rebuild step 11): one slot, JSON at user://leverage_save.
## Saved on every area landing and on quit-to-menu; CONTINUE loads
## the world state + the last area. Honest scope: the hero's hp and
## position-within-area are not per-frame saved - the area spawn is
## the checkpoint (the arcade contract, same as the death rule).

const PATH := "user://leverage_save.json"


func exists() -> bool:
	return FileAccess.file_exists(PATH)


func save_now() -> void:
	var d := {
		"version": 1,
		"world": WorldState.to_save(),
		"area": Game.area_id,
		"stamp": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write (%s)" % PATH)
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	Log.info("Save: written (area=%s)" % Game.area_id)


## The loaded dictionary, or {} when no save exists.
func load_data() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}
