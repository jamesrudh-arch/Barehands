extends SceneTree
## B26 probe: does rotate_x() roll a z-flipped wheel about its axle,
## or yaw it about the vertical? Empirical answer for the wheel-spin
## pattern traffic.gd (B19) and vehicle.gd (B25) ship with.

func _init() -> void:
	var n := Node3D.new()
	n.rotation.z = PI / 2.0
	var axle := n.basis * Vector3(0, 1, 0)
	print("PROBE cylinder axis in parent space: ", axle)
	n.rotate_x(PI / 2.0)
	var spin_axis := n.basis * Vector3(1, 0, 0)
	print("PROBE axis rotate_x actually spins around: ", spin_axis)
	print("PROBE basis after rotate_x(pi/2):")
	for r in 3:
		print("PROBE   row", r, ": ", n.basis[r])
	quit()
