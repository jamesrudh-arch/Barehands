class_name Vehicle
extends CharacterBody3D
## B25 THE DRIVER: the drivable car (the master directive Section 5 -
## "vehicles must be actual usable game objects, not decorative
## models"). Arcade handling tuned for touch: the stick steers and
## throttles (up = drive, down = brake/reverse, exactly the walking
## metaphor), the drive HUD gives B HANDBRAKE / A HORN / X EXIT.
## The car's long axis is +x (the nose), matching the parked sedan's
## built shape; traffic yields to it while it is occupied, exactly as
## it yields to a person on the road.

signal horn(on: bool)

const MAX_F := 17.0      # cruise ~61 km/h
const MAX_R := -5.5
const ACC := 9.0
const BRAKE := 15.0
const DRAG := 3.4
const HAND := 22.0      # handbrake decel
const TURN := 1.85       # steering authority, rad/s at full effect

var speed := 0.0
var occupied := false
# B26 WHEELS EVERYWHERE: the drive cluster reads its labels from the
# vehicle itself - the car says HORN/HANDBRAKE, the bicycle says
# BELL/BRAKE. One cluster, every vehicle's own voice.
var hud_a := "HORN"
var hud_b := "HANDBRAKE"
var _hero: CharacterBody3D = null
var _hb := false
var _steer := 0.0
var _horn_on := false
var _exit_want := false
var _wheels: Array[Node3D] = []
var _brake_lights: Array[MeshInstance3D] = []
var _horn_player: AudioStreamPlayer3D = null
var _scanned := false


func _ready() -> void:
	add_to_group("vehicle")
	# B26 (the B25 wheel-scan gap): the builders add the wheels AFTER
	# the body enters the tree, so a _ready scan found NOTHING and the
	# B25 sedan's wheels never turned - the scan runs on the first
	# physics frame instead, when the whole body exists
	_horn_player_setup()


## The wheels and brake lights, found once the builder has finished
## adding them (first physics frame, not _ready).
func _ensure_scan() -> void:
	if _scanned:
		return
	_scanned = true
	for c in find_children("*", "MeshInstance3D", true, false):
		if "wheel" in (c as Node).name.to_lower():
			_wheels.append(c as Node3D)
		elif "tail" in (c as Node).name.to_lower():
			_brake_lights.append(c as MeshInstance3D)


## B26 (the B25 horn gap): the horn actually SOUNDs now - a short
## synthesised two-tone burst on a 3D player riding the car (the
## emitted signal stays for anything that wants to react to it)
func _horn_player_setup() -> void:
	_horn_player = AudioStreamPlayer3D.new()
	_horn_player.stream = _synth_horn()
	_horn_player.bus = "SFX"
	_horn_player.unit_size = 7.0
	_horn_player.volume_db = -7.0
	add_child(_horn_player)
	# a stopped car is still a solid body: CharacterBody3D bodies do
	# not push each other, so the sedan never gets shoved around


## The hero boards. Answers false when already occupied.
func try_enter(hero: CharacterBody3D) -> bool:
	if occupied or hero == null:
		return false
	occupied = true
	_hero = hero
	speed = 0.0
	if hero.has_method("set_driving"):
		hero.call("set_driving", true)
	# park the hero's body inside the cabin: hidden, collision off,
	# parked - the car IS the hero's collider while driving
	hero.global_position = global_position + transform.basis.x * -0.25 \
			+ Vector3.UP * 0.55
	hero.visible = false
	if hero is CollisionObject3D:
		(hero as CollisionObject3D).set_deferred(
				"collision_layer", 0)
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", self)
	Log.info("Vehicle: the hero takes the wheel (speed 0)")
	return true


## The hero steps out at the kerb side; the car stays where it is
## parked and becomes part of the world again (traffic yields to it
## only while occupied - a kerb-parked car must not freeze the lane).
func try_exit() -> void:
	if not occupied or _hero == null:
		return
	occupied = false
	var side := transform.basis.z
	var try_pos := global_position + side * 1.7 + Vector3.UP * 0.55
	_hero.global_position = try_pos
	_hero.visible = true
	if _hero is CollisionObject3D:
		(_hero as CollisionObject3D).set_deferred(
				"collision_layer", 1)
	if _hero.has_method("set_driving"):
		_hero.call("set_driving", false)
	var follow := get_tree().get_first_node_in_group("camera") as Node3D
	if follow and follow.has_method("retarget"):
		follow.call("retarget", _hero)
	speed = 0.0
	Log.info("Vehicle: the hero steps out (the car stays parked)")
	_hero = null


func handbrake(down: bool) -> void:
	_hb = down


func honk() -> void:
	# a horn is a legal requirement and a warning: two short bursts of
	# the synth tone, plus the signal for anything that listens
	if _horn_on:
		return
	_horn_on = true
	emit_signal("horn", true)
	_double_burst()
	Log.info("Vehicle: HONK")


## Two short bursts (0.16 s on, 0.1 s apart) - the legal warning shape.
## Fire and forget: the timer owns the tail, the player owns the sound.
func _double_burst() -> void:
	if _horn_player == null:
		return
	_horn_player.play()
	await get_tree().create_timer(0.16).timeout
	_horn_player.stop()
	await get_tree().create_timer(0.1).timeout
	_horn_player.play()
	await get_tree().create_timer(0.22).timeout
	_horn_player.stop()


func horn_active() -> bool:
	return _horn_on


func request_exit() -> void:
	_exit_want = true


func _physics_process(delta: float) -> void:
	_ensure_scan()
	if not occupied:
		speed = 0.0
		_set_brake_lights(true)
		return
	if _exit_want:
		_exit_want = false
		try_exit()
		return
	# the stick: up = drive, down = brake then reverse - the same
	# mental model as walking, so the thumb never relearns
	var stick := InputBus.move
	if stick == Vector2.ZERO:
		stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var throttle := -stick.y
	if throttle > 0.08:
		speed = move_toward(speed, MAX_F * clampf(throttle, 0.0, 1.0), ACC * delta)
	elif throttle < -0.08:
		var decel := BRAKE if speed > 0.05 else ACC * 0.7
		speed = move_toward(speed, MAX_R, decel * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	if _hb:
		speed = move_toward(speed, 0.0, HAND * delta)
	# steering: authority ramps with speed (no turning a parked car,
	# no twitch at full tilt) and flips in reverse like a real car
	var authority := clampf(absf(speed) / 6.0, 0.0, 1.0) * TURN
	_steer = stick.x
	rotate_y(-_steer * authority * delta * sign(speed))
	velocity = transform.basis.x * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var braking := speed > 0.05 and (throttle < -0.08 or _hb)
	_set_brake_lights(braking or speed == 0.0)
	move_and_slide()
	# walls are solid at speed: bleed it, but never full-stop on a
	# scrape (the hero keeps the fun, the city keeps its walls).
	# The FLOOR is not a wall - resting contact must not bleed speed.
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.5:
			speed *= 0.55
			break
	# rolling wheels + the engine hum follow the actual speed.
	# B26 (the wheel-axis probe): rotate_x spun the z-flipped wheel
	# about a MOVING axis - the axle itself wandered, so every wheel on
	# the street has been flopping since B19, invisible to stills. The
	# spin is about the PARENT frame's X - the true axle - so the
	# cylinder axis never leaves the lateral line: a wheel that ROLLS.
	for w in _wheels:
		w.rotate(Vector3(1, 0, 0), (speed / 0.32) * delta)
	if _horn_on and speed > 0.5:
		_horn_on = false
		emit_signal("horn", false)


func _set_brake_lights(on: bool) -> void:
	for m in _brake_lights:
		var mat := m.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.08, 0.08) * (1.6 if on else 0.35)


## A synthesised two-tone horn (no asset, no licence): the noir car's
## voice - the 440+554 city horn every sedan had. 0.5 s long, the
## burst pattern stops it early.
func _synth_horn() -> AudioStreamWAV:
	var rate := 11025
	var n := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var a := sin(TAU * 440.0 * t) * 0.55 + sin(TAU * 554.0 * t) * 0.45
		var sq := 0.45 * signf(sin(TAU * 220.0 * t))
		var env := minf(1.0, t * 180.0) * clampf((0.5 - t) * 40.0, 0.0, 1.0)
		var s := clampf((a * 0.6 + sq * 0.2) * env * 0.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 16000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
