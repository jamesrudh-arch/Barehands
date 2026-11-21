extends "res://scripts/venue.gd"
## B19 batch 9: THE RAIN GLASS - the neighbourhood bar. A real counter
## with stools, tables and chairs, a sofa corner with a television, a
## coat rack by the door, a bartender who never stops polishing.

func _init() -> void:
	venue_name = "THE RAIN GLASS"
	interior_x = 900.0
	door_street = Vector3(238.8, 1.0, 10.2)
	door_front = Vector3(238.8, 0.0, 9.8)
	street_return = Vector3(238.8, 0.02, 7.6)
	inside_spawn = Vector3(0, 0.02, 2.4)


func _build_room() -> void:
	room_shell(Vector3(9.0, 3.2, 7.0), Color(0.15, 0.11, 0.09),
			Color(0.12, 0.1, 0.09))
	# the counter: a run of kitchen bars with end caps
	furn("kenney_furniture/kitchenBarEnd.glb", Vector3(-1.8, 0, -2.4), 0.0, 1.15)
	for kx in [-1.25, -0.8, -0.35]:
		furn("kenney_furniture/kitchenBar.glb", Vector3(kx, 0, -2.4), 0.0, 1.15)
	furn("kenney_furniture/kitchenBarEnd.glb", Vector3(0.1, 0, -2.4), PI, 1.15)
	# stools along the counter
	for sx in [-1.6, -0.9, -0.2]:
		furn("kenney_furniture/stoolBar.glb", Vector3(sx, 0, -1.5), 0.0, 1.1)
	# the corner: sofa, coffee table, television
	furn("kenney_furniture/loungeSofa.glb", Vector3(2.8, 0, -1.9), -PI / 2.0, 1.1)
	furn("kenney_furniture/tableCoffee.glb", Vector3(1.8, 0, -1.7), 0.0, 1.0)
	furn("kenney_furniture/cabinetTelevision.glb", Vector3(2.9, 0, -3.0), -PI / 2.0, 1.05)
	furn("kenney_furniture/televisionModern.glb", Vector3(2.9, 0.45, -3.0), -PI / 2.0, 1.05)
	# a pair of tables with chairs on the window side
	for tx in [-2.6, -1.0]:
		furn("kenney_furniture/tableRound.glb", Vector3(tx, 0, 1.4), 0.0, 1.05)
		furn("kenney_furniture/chair.glb", Vector3(tx + 0.7, 0, 1.4), PI / 2.0, 1.05)
		furn("kenney_furniture/chair.glb", Vector3(tx - 0.7, 0, 1.4), -PI / 2.0, 1.05)
	# the door furniture + light
	furn("kenney_furniture/coatRackStanding.glb", Vector3(-3.6, 0, 2.6), 0.0, 1.0)
	furn("kenney_furniture/lampRoundFloor.glb", Vector3(3.4, 0, 2.4), 0.0, 1.0)
	furn("kenney_furniture/trashcan.glb", Vector3(-4.0, 0, -2.8), 0.0, 1.0)
	furn("kenney_food/cup-coffee.glb", Vector3(-1.0, 0.52, -2.3), 0.0, 1.0)
	furn("kenney_food/cup-coffee.glb", Vector3(-1.35, 0.52, 1.3), 0.3, 1.0)
	# the bartender, behind the counter
	person(["res://assets/cast/Female_Ranger_Body.gltf",
			"res://assets/cast/Female_Ranger_Legs.gltf"],
			Vector3(-0.9, 0, -2.9), Color(0.4, 0.3, 0.22), 0.8)
