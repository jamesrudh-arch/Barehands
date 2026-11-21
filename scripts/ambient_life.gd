extends Node3D

## B18.3 PART 6F (BUG 15): AMBIENT LIFE. Moths orbit the street lamps
## and neon signs (a MultiMesh swarm, warm and bright against the
## dark), rats scurry along the walls near the bins and dart into
## their holes, pigeons bob on the ledges and flutter away when the
## hero comes close, a stray cat watches from the car and darts off,
## and bats circle high near the docks. Everything reacts to the hero,
## spawns only near the street, and stays under the device caps
## (40 insects + 6 creatures on a high tier, 20 + 3 on low). Steam
## already rises from the grates (street_dress).

const MOTH_CAP_HIGH := 40
const MOTH_CAP_LOW := 20

var _moths: MultiMeshInstance3D
var _moth_mm: MultiMesh
var _moth_data: Array[Dictionary] = []  # orbit params per moth
var _swarms: Array[Dictionary] = []     # {centre, scatter_t}
var _creatures: Array[Dictionary] = []  # rats, pigeons, cat
var _t := 0.0
var _react_acc := 0.0


func _ready() -> void:
	add_to_group("ambient_life")
	call_deferred("_spawn")


func insect_cap() -> int:
	return MOTH_CAP_HIGH if _high_tier() else MOTH_CAP_LOW


func creature_cap() -> int:
	return 6 if _high_tier() else 3


func _high_tier() -> bool:
	# the quality AUTO tier settles seconds after boot - the cap must
	# follow the DEVICE guess, not the not-yet-decided tier
	return not Quality._guess_low_end_device()


func insect_count() -> int:
	return _moth_data.size()


func creature_count() -> int:
	return _creatures.size()


## The nearest lamp with insects circling it (for the DEVICE REPORT).
func nearest_lit_swarm() -> Vector3:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null or _swarms.is_empty():
		return Vector3.INF
	var best := Vector3.INF
	var bd := INF
	for s in _swarms:
		var d: float = (s["centre"] as Vector3).distance_to(hero.global_position)
		if d < bd:
			bd = d
			best = s["centre"]
	return best


func _spawn() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		return
	# 1: find the street's lights (lamps, neons - any OmniLight on the
	# block, plus the sign glow positions)
	var lights: Array[Vector3] = []
	for n in parent.find_children("*", "OmniLight3D", true, false):
		# the camera fill light is not a lamp - moths do not chase it;
		# neither do they chase the hero's rim light at knee height
		if str(n.name) == "CameraFill":
			continue
		var l := (n as Node3D).global_position
		if l.y < 2.0:
			continue
		if absf(l.x) < 60.0 and absf(l.z) < 30.0:
			lights.append(l)
		if lights.size() >= 8:
			break
	if lights.is_empty():
		lights = [Vector3(6, 3.2, -4), Vector3(-8, 3.2, 4), Vector3(0, 3.4, 9)]
	# 2: the moth swarm (one MultiMesh, per-light orbits)
	var per := maxi(2, insect_cap() / mini(lights.size(), 8))
	_moths = MultiMeshInstance3D.new()
	_moth_mm = MultiMesh.new()
	_moth_mm.transform_format = MultiMesh.TRANSFORM_3D
	_moth_mm.mesh = _moth_quad()
	var total := 0
	for li in lights:
		if total >= insect_cap():
			break
		_swarms.append({"centre": li, "scatter_t": 0.0})
		for i in per:
			if total >= insect_cap():
				break
			_moth_data.append({
				"swarm": _swarms.size() - 1,
				"r": randf_range(0.25, 0.8),
				"h": randf_range(-0.5, 0.5),
				"speed": randf_range(1.6, 3.4),
				"phase": randf() * TAU,
			})
			total += 1
	_moth_mm.instance_count = total
	_moths.multimesh = _moth_mm
	parent.add_child(_moths)
	# 3: the creatures (within the cap)
	_spawn_creatures(parent)
	Log.info("Ambient: %d insects at %d lights, %d creatures" % [
			total, _swarms.size(), _creatures.size()])


func _moth_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 0.9
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	return q


func _spawn_creatures(parent: Node) -> void:
	# rats: small dark bodies scurrying near the bins and walls
	var rat_spots := [Vector3(-16.5, 0, -8.2), Vector3(15.8, 0, 8.6),
			Vector3(4.5, 0, 12.8)]
	var pigeon_spots := [Vector3(-12.0, 3.05, -8.9), Vector3(11.0, 3.05, 6.0)]
	var kinds: Array = []
	for s in rat_spots:
		kinds.append({"kind": "rat", "home": s})
	for s in pigeon_spots:
		kinds.append({"kind": "pigeon", "home": s})
	kinds.append({"kind": "cat", "home": Vector3(13.1, 1.12, -2.6)})  # the car hood
	for k in kinds:
		if _creatures.size() >= creature_cap():
			break
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		var mat := StandardMaterial3D.new()
		if k["kind"] == "rat":
			mesh.radius = 0.06
			mesh.height = 0.3
			mat.albedo_color = Color(0.16, 0.14, 0.13)
			body.rotation.z = PI / 2.0
		elif k["kind"] == "pigeon":
			mesh.radius = 0.08
			mesh.height = 0.2
			mat.albedo_color = Color(0.42, 0.4, 0.45)
		else:
			mesh.radius = 0.1
			mesh.height = 0.42
			mat.albedo_color = Color(0.5, 0.38, 0.24)
		mesh.material = mat
		body.mesh = mesh
		body.position = k["home"]
		parent.add_child(body)
		_creatures.append({
			"kind": k["kind"], "node": body, "home": k["home"],
			"state": "idle", "t": randf() * 3.0, "dir": Vector3(1, 0, 0),
			"flee_t": 0.0,
		})


func _process(delta: float) -> void:
	if _moth_mm == null:
		return
	_t += delta
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	# the moths: cheap orbits + a scatter when the hero walks through
	for i in _moth_data.size():
		var d := _moth_data[i]
		var sw: Dictionary = _swarms[d["swarm"]]
		var c: Vector3 = sw["centre"]
		if hero and sw["scatter_t"] > 0.0:
			sw["scatter_t"] -= delta
		var r: float = d["r"] * (2.6 if sw["scatter_t"] > 0.0 else 1.0)
		var a: float = d["phase"] + _t * d["speed"] \
				* (2.5 if sw["scatter_t"] > 0.0 else 1.0)
		var p := Vector3(c.x + cos(a) * r, c.y + d["h"], c.z + sin(a) * r)
		_moth_mm.set_instance_transform(i, Transform3D(Basis(), p))
	# the scatter check + the creatures react at 5 Hz (cheap)
	_react_acc += delta
	if _react_acc >= 0.2:
		_react_acc = 0.0
		if hero:
			for sw in _swarms:
				if (sw["centre"] as Vector3).distance_to(hero.global_position) < 2.0:
					sw["scatter_t"] = 1.2
			_creature_react(hero)


func _creature_react(hero: Node3D) -> void:
	for c in _creatures:
		var body: MeshInstance3D = c["node"]
		if body == null or not is_instance_valid(body):
			continue
		var dist: float = body.global_position.distance_to(hero.global_position)
		match c["kind"]:
			"rat":
				if c["state"] == "idle":
					# scurry: a small wander around home
					c["t"] -= 0.2
					if float(c["t"]) <= 0.0:
						c["t"] = randf_range(0.6, 2.2)
						c["dir"] = Vector3(randf_range(-1, 1), 0,
								randf_range(-1, 1)).normalized()
					body.global_position += (c["dir"] as Vector3) * 0.35 \
							+ Vector3(0, 0, 0)
					# stay near home
					if body.global_position.distance_to(c["home"]) > 2.2:
						body.global_position = c["home"]
					if dist < 2.2:
						c["state"] = "fleeing"
						c["flee_t"] = 1.4
						Sound.play("latch_0", -26.0, 1.8, 0.05)  # a squeak
				else:
					var away := (body.global_position - hero.global_position)
					away.y = 0
					body.global_position += away.normalized() * 0.5
					c["flee_t"] = float(c["flee_t"]) - 0.2
					if float(c["flee_t"]) <= 0.0:
						c["state"] = "idle"
			"pigeon":
				if c["state"] == "idle":
					body.position.y = (c["home"] as Vector3).y \
							+ 0.02 * sin(_t * 3.1 + float(c["t"]))
					if dist < 4.0:
						c["state"] = "flying"
						c["flee_t"] = 2.0
						Sound.play("cloth_0", -18.0, 1.6, 0.08)  # the flutter
				else:
					body.global_position += Vector3(
							0.4, 0.5, 0.3) * (float(c["flee_t"]) * 0.5)
					c["flee_t"] = float(c["flee_t"]) - 0.2
					if float(c["flee_t"]) <= 0.0:
						body.global_position = c["home"]
						c["state"] = "idle"
			"cat":
				if c["state"] == "idle":
					# watches the hero pass
					var look := (hero.global_position - body.global_position)
					body.rotation.y = atan2(-look.x, -look.z)
					if dist < 2.6:
						c["state"] = "fleeing"
						c["flee_t"] = 1.8
						Sound.play_v("glass_med", 2, -24.0, 0.6)  # a meow-ish mew
				else:
					body.global_position += Vector3(0.6, 0, 0.9) * 0.4
					c["flee_t"] = float(c["flee_t"]) - 0.2
					if float(c["flee_t"]) <= 0.0:
						body.global_position = c["home"]
						c["state"] = "idle"
