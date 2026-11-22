extends Node
const CLS_Kit := preload("res://scripts/kit.gd")

## B19 batch 6: TRAFFIC (the directive, part 12). Cars actually drive:
## a lane graph per block (one lane each way, the riverside eastbound
## lane shifted out past the parked sedan), a small pool of real
## Kenney vehicles that spawn at one gate, drive the street, brake for
## whatever stands in front of them - the hero, a pedestrian on the
## crossing, a slower car - and despawn at the far gate. Headlights,
## brake lights, spinning wheels, an engine hum that follows the
## speed; pedestrians wait at the crossing for all of it (wanderer's
## side of the contract). The pool is capped (Quality tier), the
## vehicles stay on their lane lines, and the whole street keeps one
## shared OmniLight for the nearest car - the Mobile light budget is
## the law (ART_BIBLE).

const LANE_Z := {
	# eastbound (+x) / westbound (-x) lane centres, block-local z.
	# riverside's eastbound lane sits past the PARKED CAR (z -3.5..-1.7)
	"riverside": {"east": -4.2, "west": 2.4},
	"market": {"east": -2.2, "west": 2.2},
	"foundry": {"east": -2.2, "west": 2.2},
}
const VEHICLES := [
	"kenney_cars/sedan.glb",
	"kenney_cars/taxi.glb",
	"kenney_traffic/police.glb",
	"kenney_traffic/suv.glb",
	"kenney_traffic/hatchback-sports.glb",
	"kenney_traffic/van.glb",
]
const CRUISE := 6.5
const WET_CRUISE := 5.2  # heavy rain: the street slows down
const ACCEL := 3.2
const BRAKE := 9.0
const LOOKAHEAD := 7.5
const CAR_GAP := 8.0
const EDGE := 22.0

var _pool: Array[Node3D] = []
var _next_spawn := 0.0
var _light: OmniLight3D = null
var _engine: AudioStreamWAV = null
# B23: the signalised pedestrian crossing. One cycle the whole street
# shares: GREEN (cars flow) -> AMBER (brake) -> WALK (cars hold, the
# walk sign lights, pedestrians take the zebra).
const SIG_GREEN := 9.0
const SIG_AMBER := 2.5
const SIG_WALK := 6.0
var _sig_t := 0.0
var _sig_phase := "green"   # green | amber | walk
var _sig_lights_dirty := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_engine = _synth_engine()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.92, 0.75)
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	add_child(_light)


func walk_phase() -> bool:
	return _sig_phase == "walk"


func _signal_tick(delta: float) -> void:
	_sig_t += delta
	var total := SIG_GREEN + SIG_AMBER + SIG_WALK
	var t := fmod(_sig_t, total)
	var phase := "green" if t < SIG_GREEN \
			else ("amber" if t < SIG_GREEN + SIG_AMBER else "walk")
	if phase != _sig_phase:
		_sig_phase = phase
		_sig_lights_dirty = true


func _signal_lights() -> void:
	# drive every crossing-signal lamp on the active street (emissive
	# on = the lit head; the walk quad only glows during WALK)
	if not _sig_lights_dirty:
		return
	_sig_lights_dirty = false
	for n in get_tree().get_nodes_in_group("crossing_signal"):
		var red := n.get_node_or_null("Red") as MeshInstance3D
		var amber := n.get_node_or_null("Amber") as MeshInstance3D
		var green := n.get_node_or_null("Green") as MeshInstance3D
		var walk := n.get_node_or_null("WalkSign") as MeshInstance3D
		if red:
			_set_lamp(red, _sig_phase == "walk")
		if amber:
			_set_lamp(amber, _sig_phase == "amber")
		if green:
			_set_lamp(green, _sig_phase == "green")
		if walk:
			_set_lamp(walk, _sig_phase == "walk")


func _set_lamp(m: MeshInstance3D, lit: bool) -> void:
	var mat := m.get_active_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 1.8 if lit else 0.0
	mat.albedo_color = Color(1, 1, 1, 1) if lit else Color(0.25, 0.25, 0.25)


func _process(delta: float) -> void:
	var block := Blocks.current()
	if block == "" or not LANE_Z.has(block):
		return
	var max_active := 3 if Quality == null or Quality.tier != Quality.LOW else 2
	var active := 0
	for v in _pool:
		if is_instance_valid(v):
			active += 1
	_signal_tick(delta)
	_signal_lights()
	_now_tick()
	if active < max_active and _clock() > _next_spawn:
		_next_spawn = _clock() + randf_range(3.5, 8.0)
		_spawn(block)
	_drive_all(delta, block)


## One car: model + lights + engine, one lane, one direction.
func _spawn(block: String) -> void:
	var east := randf() < 0.5
	var lane_z: float = LANE_Z[block]["east" if east else "west"]
	var bx: float = Blocks.BLOCK_X.get(block, 0.0)
	var rel: String = VEHICLES[randi() % VEHICLES.size()]
	var car := Node3D.new()
	car.name = "TrafficCar"
	car.add_to_group("traffic")
	# B23 MILESTONE A: the traffic body is CODE-BUILT (the same
	# renderer-proof decision the characters got - gltf assets cannot
	# be trusted on the physical iPhone). Long axis Z, nose at +z;
	# the spawn yaw turns it into the lane
	var model := _code_car(car, rel)
	if model == null:
		car.queue_free()
		return
	car.position = Vector3(bx - EDGE if east else bx + EDGE, 0.02, lane_z)
	car.set_meta("east", east)
	car.set_meta("speed", CRUISE * randf_range(0.85, 1.15))
	car.set_meta("braking", false)
	car.set_meta("block", block)
	_build_lights(car, east, rel)
	_build_engine(car)
	get_tree().current_scene.add_child(car)
	_pool.append(car)


## The code-built car: body, cabin, glass band, four rolling wheels
## with hubs, bumpers, and the type's feature (taxi roof sign, police
## light bar, the SUV's taller stance). Nose at +z, ~4.4 m long.
const CAR_STYLES := {
	"sedan": {"body": Color(0.3, 0.31, 0.34), "roof": Color(0.26, 0.27, 0.3),
			"tall": 0.0, "sign": false, "bar": false},
	"taxi": {"body": Color(0.85, 0.68, 0.12), "roof": Color(0.8, 0.62, 0.1),
			"tall": 0.0, "sign": true, "bar": false},
	"police": {"body": Color(0.12, 0.13, 0.17), "roof": Color(0.1, 0.11, 0.14),
			"tall": 0.0, "sign": false, "bar": true},
	"suv": {"body": Color(0.22, 0.24, 0.2), "roof": Color(0.19, 0.21, 0.17),
			"tall": 0.22, "sign": false, "bar": false},
}


func _code_car(car: Node3D, rel: String) -> Node3D:
	var key := "sedan"
	for k in CAR_STYLES:
		if rel.contains(k):
			key = k
			break
	var st: Dictionary = CAR_STYLES[key]
	var body := Node3D.new()
	body.name = "CarModel"
	car.add_child(body)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = st.body
	paint.roughness = 0.35
	paint.metallic = 0.25
	var roof_m := StandardMaterial3D.new()
	roof_m.albedo_color = st.roof
	roof_m.roughness = 0.4
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.08, 0.11)
	glass.roughness = 0.15
	glass.metallic = 0.6
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.045, 0.045, 0.05)
	rubber.roughness = 0.95
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.55, 0.56, 0.6)
	chrome.roughness = 0.25
	chrome.metallic = 0.85
	var tall: float = st.tall
	# lower body + cabin (the belt line reads through the night)
	_boxm(body, Vector3(1.76, 0.56 + tall, 4.35), paint,
			Vector3(0, 0.52 + tall * 0.5, 0))
	_boxm(body, Vector3(1.64, 0.5, 2.3), roof_m,
			Vector3(0, 1.06 + tall, -0.28))
	# the glass band: a dark inset box wider than the cabin, split by
	# pillars - one glass box + roof overhang reads as windows all round
	_boxm(body, Vector3(1.67, 0.34, 2.02), glass,
			Vector3(0, 1.08 + tall, -0.26))
	# windshield + rear window slants
	var ws := _boxm(body, Vector3(1.58, 0.1, 0.72), glass,
			Vector3(0, 1.02 + tall, 0.78))
	ws.rotation.x = -0.5
	var rw := _boxm(body, Vector3(1.58, 0.1, 0.6), glass,
			Vector3(0, 1.02 + tall, -1.32))
	rw.rotation.x = 0.45
	# bumpers, grille
	_boxm(body, Vector3(1.8, 0.2, 0.22), chrome, Vector3(0, 0.42, 2.16))
	_boxm(body, Vector3(1.8, 0.2, 0.22), chrome, Vector3(0, 0.42, -2.16))
	_boxm(body, Vector3(1.2, 0.16, 0.06), rubber, Vector3(0, 0.62, 2.19))
	# wheels: named so _spin_wheels finds them; hub caps face out
	for wx in [-0.86, 0.86]:
		for wz in [-1.38, 1.42]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s%s" % ["L" if wx < 0 else "R",
					"F" if wz > 0 else "R"]
			var wm := CylinderMesh.new()
			wm.top_radius = 0.33
			wm.bottom_radius = 0.33
			wm.height = 0.24
			wm.material = rubber
			wheel.mesh = wm
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(wx, 0.33, wz)
			body.add_child(wheel)
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.14
			hm.bottom_radius = 0.14
			hm.height = 0.26
			hm.material = chrome
			hub.mesh = hm
			hub.rotation.z = PI / 2.0
			hub.position = Vector3(0, 0, 0)
			wheel.add_child(hub)
	# the type's signature
	if st.sign:
		var sign := _boxm(body, Vector3(0.62, 0.2, 0.3),
				mat_taxi_sign(), Vector3(0, 1.42, -0.2))
		sign.name = "TaxiSign"
	if st.bar:
		var bar_m := StandardMaterial3D.new()
		bar_m.albedo_color = Color(0.1, 0.1, 0.12)
		_boxm(body, Vector3(1.1, 0.1, 0.3), bar_m, Vector3(0, 1.38, -0.2))
		for bx2 in [-0.35, 0.35]:
			var lamp := _boxm(body, Vector3(0.3, 0.12, 0.26),
					mat_police_lamp(bx2), Vector3(bx2, 1.46, -0.2))
			lamp.name = "BeaconL" if bx2 < 0 else "BeaconR"
	return body


func mat_taxi_sign() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.75, 0.2)
	m.emission_enabled = true
	m.emission = Color(0.9, 0.7, 0.2)
	m.emission_energy_multiplier = 0.5
	return m


func mat_police_lamp(side: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var red := side < 0
	m.albedo_color = Color(0.7, 0.1, 0.1) if red else Color(0.1, 0.2, 0.75)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.12, 0.1) if red else Color(0.15, 0.3, 0.95)
	m.emission_energy_multiplier = 0.55
	return m


func _boxm(parent: Node3D, size: Vector3, m: Material,
		pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


## Emissive light boxes at nose and tail (the noir treatment the
## parked sedan wears), inside the 1.1 emission cap.
func _build_lights(car: Node3D, east: bool, rel: String) -> void:
	var nose := 1.95
	var tail := -1.95
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.9, 0.7)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.88, 0.65)
	head_mat.emission_energy_multiplier = 1.45
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.9, 0.12, 0.08)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.1, 0.06)
	tail_mat.emission_energy_multiplier = 1.05
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hz in [-0.55, 0.55]:
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.07, 0.16, 0.42)
		hm.material = head_mat
		head.mesh = hm
		head.position = Vector3(nose, 0.62, hz)
		car.add_child(head)
		var t := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.06, 0.1, 0.24)
		tm.material = tail_mat
		t.mesh = tm
		t.position = Vector3(tail, 0.68, hz)
		car.add_child(t)
	car.set_meta("tail_mat", tail_mat)


## A low synthesised engine loop (no asset, no licence): pitch follows
## the speed, distance attenuation is the player's audio reality.
func _build_engine(car: Node3D) -> void:
	if _engine == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _engine
	p.bus = "Ambience"
	p.unit_size = 4.0
	p.volume_db = -14.0
	p.max_db = -8.0
	p.max_distance = 55.0
	car.add_child(p)
	p.play.call_deferred()  # the CAR may not be in the tree yet - B21 boot-log fix
	car.set_meta("engine", p)


func _drive_all(delta: float, block: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var nearest: Node3D = null
	var nearest_d := 1e9
	for v in _pool.duplicate():
		if not is_instance_valid(v):
			_pool.erase(v)
			continue
		var car := v as Node3D
		if str(car.get_meta("block", "")) != block:
			_recycle(car)  # the street behind the gate empties out
			continue
		var speed: float = car.get_meta("speed")
		var east: bool = car.get_meta("east")
		var bx: float = Blocks.BLOCK_X.get(block, 0.0)
		# the road ahead: hero, pedestrians on the road, the car in
		# front, and the crossing signal (B23: a red light is a hazard
		# the same way a person is)
		var hazard := _hazard_ahead(car, east, bx, player) \
				or _signal_stops(car, east, bx)
		var front := _car_ahead(car, east)
		var cruise := CRUISE if Weather == null or Weather.intensity < 0.75 \
				else WET_CRUISE
		var want := 0.0 if hazard else cruise
		if front:
			want = mini(want, float(front.get_meta("speed")) * 0.9)
		speed = move_toward(speed, want, (BRAKE if want < speed else ACCEL) * delta)
		car.set_meta("speed", speed)
		# brake lights read whenever the car is slow on the street
		car.set_meta("braking", speed < CRUISE * 0.6)
		car.position.x += (1.0 if east else -1.0) * speed * delta
		_spin_wheels(car, speed, delta)
		_brake_lights(car)
		_engine_pitch(car, speed)
		# the far gate: gone
		if (east and car.position.x > bx + EDGE + 2.0) \
				or (not east and car.position.x < bx - EDGE - 2.0):
			_recycle(car)
			continue
		if player:
			var d := car.global_position.distance_to(player.global_position)
			if d < nearest_d:
				nearest_d = d
				nearest = car
	# ONE shared headlight pool for the nearest car (Mobile light budget)
	if nearest and nearest_d < 30.0:
		_light.light_energy = lerpf(_light.light_energy, 0.8, delta * 3.0)
		_light.global_position = nearest.global_position \
				+ Vector3(1.4 if nearest.get_meta("east") else -1.4, 1.0, 0)
	else:
		_light.light_energy = lerpf(_light.light_energy, 0.0, delta * 2.0)


## The crossing signal, from the driver's seat: WALK (red) stops
## everyone before the zebra; AMBER stops the ones close enough to
## brake in time. Far cars ride the amber through - as they do.
func _signal_stops(car: Node3D, east: bool, bx: float) -> bool:
	if _sig_phase == "green":
		return false
	var dir := 1.0 if east else -1.0
	var cross_x := bx  # the crossing sits at the block's x centre
	var ahead := (cross_x - car.position.x) * dir
	if ahead < 0.5 or ahead > LOOKAHEAD + 4.0:
		return false  # past it, or nowhere near it yet
	if _sig_phase == "walk":
		return true
	# amber: braking distance only
	return ahead < 2.0 + float(car.get_meta("speed")) * 0.8


## Anything breathing on the road in front of the car: the hero, a
## pedestrian mid-crossing. Cars are polite; nobody is run over. The
## check is PHYSICAL (who stands in the lane ahead), not state-based -
## the street doesn't care why you're in the road. Courtesy runs both
## ways: a pedestrian WAITING at the crossing kerb stops an approaching
## car (the directive: cars slow or stop for pedestrians at crossings).
func _hazard_ahead(car: Node3D, east: bool, bx: float,
		player: Node3D) -> bool:
	var dir := 1.0 if east else -1.0
	var lane_z: float = car.position.z
	var cross_x := bx  # the crossing sits at the block's x centre
	if player and absf(player.global_position.z - lane_z) < 2.2:
		var ahead := (player.global_position.x - car.position.x) * dir
		if ahead > 0.5 and ahead < LOOKAHEAD:
			return true
	for w in get_tree().get_nodes_in_group("wanderer"):
		var wn := w as Node3D
		if wn == null or not is_instance_valid(wn):
			continue
		if absf(wn.global_position.z - lane_z) < 2.2:
			var ahead := (wn.global_position.x - car.position.x) * dir
			if ahead > 0.5 and ahead < LOOKAHEAD:
				return true
	# B24 (the deadlock fix): the kerb-WAITER courtesy rule is GONE.
	# Since the B23 walk-gate, waiters gather at the kerb through the
	# whole green phase (they only cross on WALK) - the old rule then
	# held both lanes forever. The signalised crossing owns the
	# crossing now: _signal_stops holds cars on WALK, and anyone
	# actually ON the road still stops traffic via the check above.
	return false


## The car in the same lane just ahead: keep the gap, match its speed.
func _car_ahead(car: Node3D, east: bool) -> Node3D:
	var dir := 1.0 if east else -1.0
	var best: Node3D = null
	var best_gap := CAR_GAP
	for v in _pool:
		if v == car or not is_instance_valid(v) or v.get_meta("east") != east:
			continue
		if absf((v as Node3D).position.z - car.position.z) > 1.5:
			continue
		var gap := ((v as Node3D).position.x - car.position.x) * dir
		if gap > 0.5 and gap < best_gap:
			best_gap = gap
			best = v
	return best


func _spin_wheels(car: Node3D, speed: float, delta: float) -> void:
	for c in car.find_children("*", "MeshInstance3D", true, false):
		if "wheel" in (c as Node).name.to_lower():
			(c as Node3D).rotate_x((speed / 0.32) * delta)


func _brake_lights(car: Node3D) -> void:
	var m: StandardMaterial3D = car.get_meta("tail_mat")
	if m == null:
		return
	var braking: bool = car.get_meta("braking")
	m.emission_energy_multiplier = 1.1 if braking else 0.7


func _engine_pitch(car: Node3D, speed: float) -> void:
	var p: AudioStreamPlayer3D = car.get_meta("engine")
	if p:
		p.pitch_scale = clampf(0.7 + speed / CRUISE * 0.5, 0.6, 1.4)


func _recycle(car: Node3D) -> void:
	_pool.erase(car)
	car.queue_free()


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _now_tick() -> void:
	pass  # hook kept for future beats (rush hour, story roadblocks)


## 1 s of low saw + a breath of noise, looped: an engine at idle-ish
## pitch, scaled live by _engine_pitch. Built once, shared by all cars.
func _synth_engine() -> AudioStreamWAV:
	var rate := 11025
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		phase += 55.0 / rate
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var noise := (randf() - 0.5) * 0.25
		var env := 0.85 + 0.15 * sin(TAU * 3.0 * i / n)
		var s := clampf((saw * 0.55 + noise) * env * 0.5, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 16000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
