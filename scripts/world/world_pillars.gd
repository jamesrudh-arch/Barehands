class_name WorldPillars
extends Node3D

## THE WORLD PILLARS (S5.19): the honest gaps, closed. THE
## RIVER - the docks' harbour gets a flowing water shader, fish
## that glide with visible wakes and occasionally JUMP, and a
## stone bank at the near edge. THE FILLING STATION - a canopy,
## two pump islands with lit price panels, a kiosk and under-
## canopy glow at the neighbourhood's east approach. THE BIRDS -
## grey shapes on strung wires that bob, and flush when the hero
## closes. One script, spawned per area from Game.travel.

const CLS_NightLook := preload(
		"res://scripts/world/night_look.gd")

const FISH_COUNT := 6
const BIRD_WIRES := 3
const FLUSH_R := 6.5

var _t := 0.0
var _hero: Node3D
var _fish: Array = []      # [{n, wake, center, r, f, p, jump}]
var _birds: Array = []     # [{n, wire_x, y, state, vx, vy}]
var _wires: Array = []     # [{a: Vector3, b: Vector3}]
var _water_mat: ShaderMaterial
var _station_glow: Array = []


static func spawn_for(area: Node, area_id: String) -> Node3D:
	var p := preload("res://scripts/world/world_pillars.gd").new()
	p.name = "WorldPillars"
	area.add_child(p)
	p._build(area_id)
	return p


func _build(area_id: String) -> void:
	if area_id == "docks":
		_river()
	if area_id == "neighbourhood":
		_filling_station()
		_wires_and_birds()
		# S5.20 THE AFTERMATH: burn the ledger and the Corporation
		# remembers - plate men pace your street for keeps
		if WorldState.flag("m7_burned"):
			_corp_hunters()
	elif area_id == "second_city":
		_wires_and_birds()   # the club's neon load carries no birds


# ============================================================
# THE RIVER: the harbour plane becomes water that MOVES - a
# two-wave scrolling shader keeps the surface alive under the
# lamps, the fish glide with wakes, and one jumps now and then.
# ============================================================
func _river() -> void:
	var water := get_parent().find_child("Harbour", true,
			false) as MeshInstance3D
	if water == null:
		return
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 albedo_col : source_color = vec3(0.03, 0.07, 0.12);
uniform float flow_speed = 0.35;
void fragment() {
	vec2 uv = UV * vec2(46.0, 26.0);
	float w1 = sin(uv.x * 1.3 + uv.y * 0.7 + TIME * flow_speed);
	float w2 = sin(uv.x * 0.6 - uv.y * 1.7 - TIME * flow_speed * 0.6);
	float w3 = sin((uv.x + uv.y) * 2.3 + TIME * flow_speed * 1.4);
	float ripple = w1 * 0.45 + w2 * 0.35 + w3 * 0.2;
	ALBEDO = albedo_col + vec3(ripple * 0.05);
	METALLIC = 0.3;
	ROUGHNESS = 0.05 + abs(ripple) * 0.06;
	EMISSION = (vec3(0.02, 0.03, 0.045) + vec3(0.01, 0.012, 0.02)
			* ripple) * (1.0 + ripple * 0.5);
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = sh
	water.material_override = _water_mat
	# THE BANK: dark stones along the near edge - the water ENDS
	# somewhere legible now
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.14, 0.13, 0.13)
	stone_mat.roughness = 0.9
	for i in 14:
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.5, 1.3)
		bm.size = Vector3(s, s * 0.5, s * 0.8)
		bm.material = stone_mat
		st.mesh = bm
		st.position = Vector3(-64.0 + i * 9.5 + randf_range(-3, 3),
				-0.22, -13.2 + randf_range(-0.8, 0.6))
		st.rotation.y = randf() * TAU
		add_child(st)
	# THE FISH: dark gliders under the surface, each with a pale
	# wake quad trailing at its speed - the river is FISHED
	for i in FISH_COUNT:
		var n := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.34, 0.1)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.03, 0.06, 0.08, 0.75)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = m
		n.mesh = qm
		n.name = "Fish"
		add_child(n)
		var wake := MeshInstance3D.new()
		var wm := QuadMesh.new()
		wm.size = Vector2(0.7, 0.07)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.5, 0.62, 0.7, 0.28)
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.material = wmat
		wake.mesh = wm
		wake.name = "Wake"
		add_child(wake)
		_fish.append({
			"n": n, "wake": wake,
			"center": Vector3(-30.0 + i * 12.0, -0.28, -24.0
					- randf() * 10.0),
			"r": randf_range(2.0, 5.0),
			"f": (0.25 + randf() * 0.35)
					* (1.0 if i % 2 == 0 else -1.0),
			"p": randf() * TAU,
			"jump_t": randf_range(6.0, 16.0),
		})


# ============================================================
# THE FILLING STATION: the east approach's lit landmark - four
# columns, a flat canopy, two pump islands with emissive price
# panels, a kiosk, and glow tubes under the roof.
# ============================================================
func _filling_station() -> void:
	var root := Node3D.new()
	root.name = "FillingStation"
	root.position = Vector3(34.0, 0, 9.0)
	add_child(root)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.21, 0.24)
	steel.metallic = 0.4
	steel.roughness = 0.5
	# THE CANOPY: four columns + the deck
	for c in [Vector3(-4, 0, -2.5), Vector3(4, 0, -2.5),
			Vector3(-4, 0, 2.5), Vector3(4, 0, 2.5)]:
		var col := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.35, 4.4, 0.35)
		cm.material = steel
		col.mesh = cm
		col.position = Vector3(c.x, 2.2, c.z)
		root.add_child(col)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(11.0, 0.4, 7.0)
	dm.material = steel
	deck.mesh = dm
	deck.position = Vector3(0, 4.6, 0)
	root.add_child(deck)
	# THE GLOW: two warm tubes under the canopy - the station
	# reads from down the street
	for tx in [-3.0, 3.0]:
		var tube := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(6.0, 0.1, 0.25)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0, 0, 0)
		tmat.emission_enabled = true
		tmat.emission = Color(1.0, 0.78, 0.45)
		tmat.emission_energy_multiplier = 3.2
		tm.material = tmat
		tube.mesh = tm
		tube.position = Vector3(0, 4.32, tx)
		root.add_child(tube)
		_station_glow.append(tube)
	# THE PUMPS: two islands, lit price panels facing the street
	for px in [-2.2, 2.2]:
		var island := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(1.6, 0.25, 2.6)
		im.material = steel
		island.mesh = im
		island.position = Vector3(px, 0.12, 0)
		root.add_child(island)
		var pump := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 1.6, 1.0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.62, 0.2, 0.16)
		pmat.roughness = 0.4
		pmat.emission_enabled = true
		pmat.emission = Color(0.25, 0.06, 0.04)
		pmat.emission_energy_multiplier = 1.2
		pm.material = pmat
		pump.mesh = pm
		pump.position = Vector3(px, 1.05, 0)
		root.add_child(pump)
		# the white service band - the silhouette reads at 40 m
		var band := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.84, 0.5, 1.04)
		var bmat2 := StandardMaterial3D.new()
		bmat2.albedo_color = Color(0.93, 0.91, 0.87)
		bmat2.roughness = 0.45
		bm2.material = bmat2
		band.mesh = bm2
		band.position = Vector3(px, 1.0, 0)
		root.add_child(band)
		# the panel: BIG and hot - the station's beacon
		var panel := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 0.5)
		var qmat := StandardMaterial3D.new()
		qmat.albedo_color = Color(0, 0, 0)
		qmat.emission_enabled = true
		qmat.emission = Color(0.6, 1.0, 0.65)
		qmat.emission_energy_multiplier = 4.2
		qm.material = qmat
		panel.mesh = qm
		panel.position = Vector3(px, 1.45, 0.53)
		root.add_child(panel)
		_station_glow.append(panel)
	# THE KIOSK: a lit box at the back, a human works here
	var kiosk := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(3.2, 2.6, 2.2)
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color(0.25, 0.22, 0.2)
	kmat.roughness = 0.7
	km.material = kmat
	kiosk.mesh = km
	kiosk.position = Vector3(0, 1.3, 4.6)
	root.add_child(kiosk)
	var kwin := MeshInstance3D.new()
	var kwm := QuadMesh.new()
	kwm.size = Vector2(2.2, 1.0)
	var kwmat := StandardMaterial3D.new()
	kwmat.albedo_color = Color(0, 0, 0)
	kwmat.emission_enabled = true
	kwmat.emission = Color(1.0, 0.88, 0.66)
	kwmat.emission_energy_multiplier = 3.4
	kwm.material = kwmat
	kwin.mesh = kwm
	kwin.position = Vector3(0, 1.5, 3.48)
	root.add_child(kwin)
	_station_glow.append(kwin)
	# THE SPILL: the canopy's light pools on the asphalt - the
	# ground under it reads LIT from down the street
	var spill := MeshInstance3D.new()
	var spm := QuadMesh.new()
	spm.size = Vector2(10.5, 6.5)
	var spmat := StandardMaterial3D.new()
	spmat.albedo_color = Color(1.0, 0.82, 0.55, 0.10)
	spmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spm.material = spmat
	spill.mesh = spm
	spill.rotation.x = -PI / 2.0
	spill.position = Vector3(0, 0.06, 0)
	root.add_child(spill)
	# THE PYLON: the street-side price totem - the station's icon
	# anchor, readable at 50 m (the club signs' proven tube read)
	var py := MeshInstance3D.new()
	var pym := BoxMesh.new()
	pym.size = Vector3(0.45, 5.6, 0.45)
	pym.material = steel
	py.mesh = pym
	py.position = Vector3(-6.2, 2.8, -1.0)
	root.add_child(py)
	CLS_NightLook.sign(root, "FUEL",
			Vector3(-6.2, 4.6, -1.0), PI,
			Color(0.45, 0.9, 1.0), 110, false)
	CLS_NightLook.sign(root, "2.79",
			Vector3(-6.2, 3.5, -1.0), PI,
			Color(1.0, 0.62, 0.25), 96, false)
	# THE SIGN: FUEL, emissive, on the canopy's street edge
	var sign := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.8, 0.5, 0.12)
	var signmat := StandardMaterial3D.new()
	signmat.albedo_color = Color(0, 0, 0)
	signmat.emission_enabled = true
	signmat.emission = Color(0.4, 0.9, 1.0)
	signmat.emission_energy_multiplier = 2.8
	sm.material = signmat
	sign.mesh = sm
	sign.position = Vector3(0, 5.2, -3.4)
	root.add_child(sign)
	_station_glow.append(sign)


func _corp_hunters() -> void:
	## the burned route's price: two plated collectors, pacing
	## the east approach - not a mission, just the world's memory
	var enemy_script := preload("res://scripts/npc/enemy.gd")
	for i in 2:
		var e: CharacterBody3D = enemy_script.new()
		e.position = Vector3(24.0 + i * 7.0, 0.05, 1.5)
		e.rotation.y = PI if i % 2 == 0 else 0.0
		e.set("hp", 130.0)
		e.set_meta("armored", true)
		e.add_to_group("corp_hunter")
		add_child(e)
	Log.info("WorldPillars: corp hunters patrol (the burn's price)")


# ============================================================
# THE BIRDS: wires strung between the lamp heads, grey shapes
# that bob on them - and flush as a flock when the hero closes.
# ============================================================
func _wires_and_birds() -> void:
	var lamps: Array = []
	_all_cones(get_parent(), lamps)
	lamps.sort_custom(func(a, b):
		return a.global_position.x < b.global_position.x)
	# string wires between NEARBY lamp pairs on the same row
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.05, 0.05, 0.06)
	var bird_mat := StandardMaterial3D.new()
	bird_mat.albedo_color = Color(0.35, 0.36, 0.4, 1.0)
	bird_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var made := 0
	for i in range(lamps.size() - 1):
		if made >= BIRD_WIRES:
			break
		var a: Node3D = lamps[i]
		var b: Node3D = lamps[i + 1]
		var pa := a.global_position
		var pb := b.global_position
		if absf(pa.x - pb.x) > 26.0 or absf(pa.z - pb.z) > 1.5:
			continue
		var mid := (pa + pb) * 0.5
		mid.y -= 0.25
		var len := pa.distance_to(pb)
		var wire := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(len, 0.03, 0.03)
		wm.material = wire_mat
		wire.mesh = wm
		wire.position = mid
		wire.look_at(pb, Vector3.UP)
		add_child(wire)
		_wires.append({"a": pa, "b": pb, "y": mid.y})
		# the flock: 3-4 per wire
		for j in 3 + (i % 2):
			var bird := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.14, 0.11)
			qm.material = bird_mat
			bird.mesh = qm
			bird.name = "Bird"
			var f := randf()
			bird.position = Vector3(
					lerpf(pa.x, pb.x, f), mid.y + 0.09,
					lerpf(pa.z, pb.z, f))
			add_child(bird)
			_birds.append({
				"n": bird, "state": 0,
				"vx": 0.0, "vy": 0.0, "t": randf() * TAU,
			})
		made += 1


func _all_cones(n: Node, out: Array) -> void:
	if n is Node3D and str(n.name).begins_with("LampCone"):
		out.append(n)
	for c in n.get_children():
		_all_cones(c, out)


func _process(delta: float) -> void:
	_t += delta
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player")
	# THE FISH glide; one jumps on its own clock
	for fi in _fish:
		var n: Node3D = fi["n"]
		var wake: Node3D = fi["wake"]
		var ph: float = float(fi["p"]) + _t * float(fi["f"])
		var r: float = float(fi["r"])
		var c: Vector3 = fi["center"]
		var pos := Vector3(c.x + cos(ph) * r, c.y, c.z + sin(ph) * r)
		var jt: float = float(fi["jump_t"]) - delta
		if jt <= 0.0:
			jt = randf_range(8.0, 18.0)
			fi["jumping"] = 1.2   # seconds of air
		fi["jump_t"] = jt
		if float(fi.get("jumping", 0.0)) > 0.0:
			fi["jumping"] = float(fi["jumping"]) - delta
			var jf: float = float(fi["jumping"]) / 1.2
			# the arc: up over the surface, a pale splash at crest
			pos.y = c.y + sin(PI * jf) * 0.55
			wake.visible = false
		else:
			wake.visible = true
			wake.position = Vector3(
					pos.x - cos(ph) * 0.5, pos.y + 0.03, pos.z)
		n.global_position = pos
		n.rotation.y = -ph + (PI / 2.0 if float(fi["f"]) > 0 else -PI / 2.0)
		wake.scale.x = 0.8 + absf(sin(_t * 3.0)) * 0.5
	# THE BIRDS: bob at rest, flush when the hero closes, land
	# again once far
	for b in _birds:
		var n: Node3D = b["n"]
		var st: int = b["state"]
		b["t"] = float(b["t"]) + delta
		if st == 0:
			n.position.y += sin(float(b["t"]) * 2.2) * 0.004
			if _hero and is_instance_valid(_hero) \
					and n.global_position.distance_to(
					_hero.global_position) < FLUSH_R:
				# FLUSH: up and away from the hero
				st = 1
				var away := (n.global_position
						- _hero.global_position).normalized()
				b["vx"] = away.x * randf_range(3.0, 5.0)
				b["vy"] = randf_range(2.2, 3.4)
				b["home"] = n.position
				b["gone"] = 0.0
		elif st == 1:
			b["vy"] = float(b["vy"]) - 6.0 * delta
			n.position += Vector3(float(b["vx"]), float(b["vy"]),
					0.0) * delta
			# the flap: the shape pulses wide/narrow
			n.scale = Vector3(1.3, 0.6, 1.0) \
					if fmod(_t * 9.0, 2.0) < 1.0 \
					else Vector3(0.7, 1.0, 1.0)
			b["gone"] = float(b["gone"]) + delta
			if float(b["gone"]) > 4.0:
				st = 2   # circle back
				b["ret"] = 3.0
		else:
			var home: Vector3 = b.get("home", n.position)
			n.position = n.position.lerp(home, delta * 0.8)
			n.scale = Vector3.ONE
			b["ret"] = float(b["ret"]) - delta
			if float(b["ret"]) <= 0.0 \
					or n.position.distance_to(home) < 0.05:
				st = 0
				b["t"] = randf() * TAU
		b["state"] = st
