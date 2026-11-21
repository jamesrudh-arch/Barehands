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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_engine = _synth_engine()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.92, 0.75)
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	add_child(_light)


func _process(delta: float) -> void:
	var block := Blocks.current()
	if block == "" or not LANE_Z.has(block):
		return
	var max_active := 3 if Quality == null or Quality.tier != Quality.LOW else 2
	var active := 0
	for v in _pool:
		if is_instance_valid(v):
			active += 1
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
	# the kit models' long axis is Z, nose at +z: yaw PI/2 points the
	# nose up the street (+x, eastbound), -PI/2 down it (westbound)
	var model := CLS_Kit.place(car, rel, Vector3.ZERO,
			PI / 2.0 if east else -PI / 2.0, 1.35)
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


## Emissive light boxes at nose and tail (the noir treatment the
## parked sedan wears), inside the 1.1 emission cap.
func _build_lights(car: Node3D, east: bool, rel: String) -> void:
	var nose := 1.95
	var tail := -1.95
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.9, 0.7)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.88, 0.65)
	head_mat.emission_energy_multiplier = 1.05
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.9, 0.12, 0.08)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.1, 0.06)
	tail_mat.emission_energy_multiplier = 0.7
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hz in [-0.55, 0.55]:
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.06, 0.12, 0.3)
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
	p.play()
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
		# the road ahead: hero, pedestrians on the road, the car in front
		var hazard := _hazard_ahead(car, east, bx, player)
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
		# the yield at the crossing: a waiter at the kerb stops the car
		var st = wn.get("_state")
		if st != null and int(st) == 1 \
				and absf(wn.global_position.x - cross_x) < 3.0:
			var to_cross := (cross_x - car.position.x) * dir
			if to_cross > -2.0 and to_cross < LOOKAHEAD + 4.0:
				return true
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
