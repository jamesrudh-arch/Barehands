extends Node

## STREET TRAFFIC (overhaul S5.3): the lanes get cars. The sedans
## are the same drivable vehicle.gd bodies the player steals (the
## noir light boxes read at night); the loop is kinematic - a slow
## translate along the lane, wrap at the map edge. Parked ones stay
## parked (the plaza sedan); these are the passing parade.
class Car extends Node:
	var body: Node3D
	var axis := Vector3(1, 0, 0)
	var speed := 7.0
	var limit := 72.0

	func _process(delta: float) -> void:
		body.global_position += axis * speed * delta
		if absf(body.global_position.x) > limit:
			var p := body.global_position
			p.x = -limit * signf(p.x)
			body.global_position = p

static func fill(parent: Node, count := 2) -> Array:
	var CLS_Vehicle := load("res://scripts/world/vehicle.gd")
	var out: Array = []
	# the road runs along X, lanes at z -+ 1.9; the vehicle's own
	# forward is +Z at yaw 0, so driving +X is yaw +PI/2 (the
	# vehicle.gd fwd law: fwd = (0,0,1).rotated(UP, yaw))
	var lanes := [
		{"z": -1.9, "dir": 1.0, "x": -40.0},
		{"z": 1.9, "dir": -1.0, "x": 22.0},
	]
	for i in mini(count, lanes.size()):
		var lane: Dictionary = lanes[i]
		var car := Car.new()
		car.name = "Traffic%d" % i
		car.axis = Vector3(lane["dir"], 0, 0)
		car.speed = 6.5 + 1.5 * float(i)
		var yaw: float = PI / 2.0 * lane["dir"]
		car.body = CLS_Vehicle.spawn(parent, "sedan",
				Vector3(lane["x"], 0.05, lane["z"]), yaw)
		if car.body == null:
			car.queue_free()
			continue
		parent.add_child(car)
		out.append(car)
	return out
