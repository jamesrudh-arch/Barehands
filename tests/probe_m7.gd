extends SceneTree
func _init():
	var m = load("res://data/missions/m7.tres")
	if m == null:
		print("M7 NULL")
	else:
		print("M7 OK id=%s stages=%d next=[%s]" % [m.id, m.stages.size(), m.next])
		print("stage0 ring from=%s" % str(m.stages[0].get("ring", {}).get("from", "?")))
		print("stage2 spawn n=%d armored=%s" % [m.stages[2].get("spawn", []).size(), str(m.stages[2].get("spawn", [])[0].get("armored", false))])
	quit(0)
