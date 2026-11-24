class_name Critters
extends Node3D

## THE CRITTERS (S5.18): the city breathes. Moths orbit every
## lamp cone (the noir tell - life collects at the light), rats
## scurry the alley bases and flee the hero, fish glide the
## second city's fountain. One script, spawned per area from
## Game._mount_player; mobile-honest: ~40 quads, no lights, no
## physics, one _process.

const MOTH_PER_LAMP := 4
const MOTH_CAP := 44          # the whole-area budget
const RAT_COUNT := 5
const FISH_COUNT := 4

var _t := 0.0
var _moths: Array = []       # [{m, base, r, f, p, y}]
var _rats: Array = []        # [{n, dir, speed, state, t}]
var _fish: Array = []        # [{n, r, f, p}]
var _hero: Node3D


static func spawn_for(area: Node, area_id: String) -> Node3D:
	var c := preload("res://scripts/world/critters.gd").new()
	c.name = "Critters"
	area.add_child(c)
	c._build(area_id)
	return c


func _build(area_id: String) -> void:
	_build_moths()
	if area_id in ["neighbourhood", "docks", "club_district"]:
		_build_rats()
	if area_id == "second_city":
		_build_fish()


## MOTHS: tiny additive quads on lissajous orbits around each
## lamp cone's head - they collect at the light, the way night
## life does. No lights, no shadow, 2 triangles each.
func _build_moths() -> void:
	var lamps: Array = []
	for cone in get_tree().get_nodes_in_group("lamps"):
		lamps.append(cone)
	# the cones carry the lamp's head position; fall back to
	# scanning named children if the group isn't populated
	if lamps.is_empty():
		_all_cones(get_parent(), lamps)
	var budget := MOTH_CAP
	for lamp in lamps:
		if budget <= 0:
			break
		var head: Node3D = lamp
		var base := head.global_position
		for i in MOTH_PER_LAMP:
			if budget <= 0:
				break
			var m := _quad(0.05, Color(1.0, 0.97, 0.86, 0.85),
					BaseMaterial3D.BLEND_MODE_ADD, true)
			m.name = "Moth"
			add_child(m)
			_moths.append({
				"m": m,
				"base": base + Vector3(0, -0.35, 0),
				"r": randf_range(0.18, 0.5),
				"f": randf_range(2.2, 4.8),
				"p": randf() * TAU,
				"y": randf_range(0.1, 0.4),
			})
			budget -= 1


func _all_cones(n: Node, out: Array) -> void:
	if n is Node3D and str(n.name).begins_with("LampCone"):
		out.append(n)
	for c in n.get_children():
		_all_cones(c, out)


## RATS: dark low quads that scurry the building bases; they
## bolt when the hero closes inside 3 m (the city reacts to
## you even at the pest level).
func _build_rats() -> void:
	for i in RAT_COUNT:
		var n := _quad(0.22, Color(0.08, 0.07, 0.07, 1.0),
				BaseMaterial3D.BLEND_MODE_MIX, false)
		n.name = "Rat"
		var ang := randf() * TAU
		var dist := randf_range(6.0, 26.0)
		n.position = Vector3(cos(ang) * dist, 0.04,
				sin(ang) * dist)
		add_child(n)
		_rats.append({
			"n": n, "dir": randf() * TAU,
			"speed": randf_range(1.2, 2.2),
			"state": 0, "t": randf_range(0.5, 2.0),
		})


## FISH: dark gliders under the second city's fountain surface -
## circles with per-fish radius and phase, the fountain lives.
func _build_fish() -> void:
	var fountain := get_parent().find_child("Fountain", true,
			false) as Node3D
	if fountain == null:
		return
	var center := fountain.global_position
	for i in FISH_COUNT:
		var n := _quad(0.16, Color(0.06, 0.10, 0.13, 0.9),
				BaseMaterial3D.BLEND_MODE_MIX, false)
		n.name = "Fish"
		add_child(n)
		_fish.append({
			"n": n, "center": center,
			"r": randf_range(0.6, 1.4),
			"f": randf_range(0.3, 0.7) * (1.0 if i % 2 == 0 else -1.0),
			"p": randf() * TAU,
		})


func _quad(sz: float, col: Color, blend: int, unshaded: bool) \
		-> MeshInstance3D:
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = blend
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	m.mesh = qm
	return m


func _process(delta: float) -> void:
	_t += delta
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player")
	for mo in _moths:
		var m: MeshInstance3D = mo["m"]
		var ph: float = mo["p"] + _t * float(mo["f"])
		var rr: float = float(mo["r"])
		m.global_position = Vector3(
				float(mo["base"].x) + cos(ph) * rr,
				float(mo["base"].y) + sin(ph * 1.7) * float(mo["y"]),
				float(mo["base"].z) + sin(ph) * rr)
		m.rotation.z = ph * 2.0
	for ra in _rats:
		var n: Node3D = ra["n"]
		var st: int = ra["state"]
		var tt: float = ra["t"] - delta
		var flee := false
		if _hero and is_instance_valid(_hero):
			var to_h := n.global_position.distance_to(
					_hero.global_position)
			flee = to_h < 3.0
		if tt <= 0.0:
			# flip state: scurrying <-> sniffing at the wall
			st = 1 - st
			tt = randf_range(0.4, 2.0)
			if st == 0:
				ra["dir"] = randf() * TAU
		ra["state"] = st
		ra["t"] = tt
		var sp: float = float(ra["speed"]) \
				* (1.0 if st == 0 else 0.15) \
				* (2.6 if flee else 1.0)
		var dir: float = float(ra["dir"])
		if flee and _hero and is_instance_valid(_hero):
			dir = atan2(
					n.global_position.z - _hero.global_position.z,
					n.global_position.x - _hero.global_position.x)
			ra["dir"] = dir
		n.position += Vector3(cos(dir), 0, sin(dir)) * sp * delta
		n.rotation.y = -dir
	for fi in _fish:
		var fn: Node3D = fi["n"]
		var ph2: float = float(fi["p"]) + _t * float(fi["f"])
		var rr2: float = float(fi["r"])
		var c: Vector3 = fi["center"]
		fn.global_position = Vector3(
				c.x + cos(ph2) * rr2, c.y + 0.35, c.z + sin(ph2) * rr2)
		fn.rotation.y = -ph2 + (PI / 2.0 if float(fi["f"]) > 0 else -PI / 2.0)
