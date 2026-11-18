extends Node
## Probe: _tail_matches in isolation.

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	ComboInput._buf = [
		{"tok": "X", "dir": "", "t": 0.0},
		{"tok": "X", "dir": "", "t": 0.1},
		{"tok": "X", "dir": "", "t": 0.2},
	]
	print("PROBE buf=", ComboInput.tokens())
	for c in ComboTable.ordered():
		var m: bool = ComboInput._tail_matches(c["seq"])
		if m or (c["seq"] as Array).size() == 3:
			print("PROBE %-14s seq=%-20s match=%s" % [c["id"], str(c["seq"]), m])
	var tt := ComboTable.by_id("triple_threat")
	print("PROBE triple_threat in table: ", not tt.is_empty(), " seq=", str(tt.get("seq", [])))
	get_tree().quit()
