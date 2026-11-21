extends "res://scripts/venue.gd"
## B19 batch 9: IRON PALM GYM (the bible's fight club). Punching bags
## that swing from chains, mat flooring, a reception desk, storage
## boxes, a coach by the bags. Enter from the market street front.

func _init() -> void:
	venue_name = "IRON PALM GYM"
	interior_x = 840.0
	door_street = Vector3(233.5, 1.0, 10.2)
	door_front = Vector3(233.5, 0.0, 9.8)
	street_return = Vector3(233.5, 0.02, 7.6)
	inside_spawn = Vector3(0, 0.02, 2.4)


func _build_room() -> void:
	room_shell(Vector3(10.0, 3.4, 8.0), Color(0.13, 0.12, 0.13),
			Color(0.14, 0.12, 0.11))
	# the mats: real rubber squares wall to wall on the working half
	for m in [[-2.5, 0.005, -1.0], [0.5, 0.005, -1.0], [3.5, 0.005, -1.0]]:
		furn("kenney_furniture/rugSquare.glb", Vector3(m[0], m[1], m[2]),
				0.0, 2.6)
	# three heavy bags on chains (cylinders - the honest shape, and
	# they SWING: a code pendulum, not a static prop)
	for bx in [-3.2, -1.2, 0.8]:
		_hanging_bag(Vector3(bx, 0, -2.6))
	# reception: a desk, storage, a bin, a plant
	furn("kenney_furniture/desk.glb", Vector3(3.2, 0, 2.6), -PI / 2.0, 1.1)
	furn("kenney_furniture/cardboardBoxClosed.glb", Vector3(4.2, 0, 1.4), 0.4, 1.2)
	furn("kenney_furniture/cardboardBoxOpen.glb", Vector3(4.4, 0, 0.4), 0.1, 1.2)
	furn("kenney_furniture/trashcan.glb", Vector3(4.4, 0, -2.8), 0.0, 1.0)
	furn("kenney_furniture/pottedPlant.glb", Vector3(-4.2, 0, 3.2), 0.0, 1.0)
	# the coach, watching the bags
	person(["res://assets/cast/Male_Knight_Body_Armor.gltf"],
			Vector3(-2.2, 0, -1.2), Color(0.55, 0.35, 0.1), 0.7)


## A heavy bag: chain link + capsule bag, hung from the ceiling, with a
## slow code pendulum so it never reads as a static prop.
func _hanging_bag(pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(pos.x, 3.2, pos.z)
	add_child(pivot)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 1.1
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.2, 0.22)
	steel.metallic = 0.8
	steel.roughness = 0.4
	cm.material = steel
	chain.mesh = cm
	chain.position = Vector3(0, -0.55, 0)
	pivot.add_child(chain)
	var bag := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.24
	bm.height = 1.05
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.28, 0.14, 0.1)
	leather.roughness = 0.7
	bm.material = leather
	bag.mesh = bm
	bag.position = Vector3(0, -1.68, 0)
	pivot.add_child(bag)
	var swing := pivot.create_tween().set_loops()
	swing.set_trans(Tween.TRANS_SINE)
	swing.tween_property(pivot, "rotation:z", 0.16, 2.2)
	swing.tween_property(pivot, "rotation:z", -0.16, 2.2)
