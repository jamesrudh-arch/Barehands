extends Node3D
const CLS_Pickup := preload("res://scripts/pickup.gd")

## B18.3 PART 6D.7: the PLACEMENT CONTRACT. The starting room holds a
## bottle by the door (plus the bed, the lamp and the window that
## apartment.gd builds); the street holds the weapons and items the
## first minutes need. The old loose street pipe (street_dress) is
## replaced by the Weapons-tracked pickup pipe at the same spot.

const PLACEMENTS := [
	# the start room: a bottle BY THE BED (never at the door - the door
	# must own the context when the tutorial says OPEN)
	{"kind": "bottle", "pos": Vector3(780.0, 0.0, 2.3)},
	# the street: the pipe where it always lay, a bat in the alley,
	# a plank by the crates near the car, a chair leg by the gym mats
	{"kind": "pipe", "pos": Vector3(6.3, 0.0, -7.6)},
	{"kind": "bat", "pos": Vector3(-12.5, 0.0, -6.4)},
	{"kind": "plank", "pos": Vector3(10.8, 0.0, -3.5)},
	{"kind": "chair_leg", "pos": Vector3(13.6, 0.0, 4.2)},
	# bottles by the noodle front (the local bar stand-in)
	{"kind": "bottle", "pos": Vector3(-5.9, 0.0, 8.1)},
	# items: found cash, a first aid tin, painkillers, a key card, a burner
	{"kind": "cash", "pos": Vector3(-13.2, 0.0, 7.4), "amount": 40},
	{"kind": "health", "pos": Vector3(16.8, 0.0, 7.8), "amount": 3},
	{"kind": "painkillers", "pos": Vector3(2.4, 0.0, 12.6)},
	{"kind": "key", "pos": Vector3(12.9, 0.0, 12.2)},
	{"kind": "burner", "pos": Vector3(-9.8, 0.0, -9.4)},
]


func _ready() -> void:
	# the street must exist first (street_dress builds its props in its
	# own ready pass) - spawn one frame later
	call_deferred("_spawn")


func _spawn() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	for spec in PLACEMENTS:
		var p := CLS_Pickup.new()
		p.setup(str(spec["kind"]), int(spec.get("amount", 0)))
		p.position = spec["pos"]
		parent.add_child(p)
	Log.info("Pickups: %d placed (the placement contract)" % PLACEMENTS.size())
