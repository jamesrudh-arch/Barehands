extends VehicleBody3D

## A DRIVEABLE VEHICLE (rebuild step 10): VehicleBody3D physics with
## an arcade profile from data/vehicles/*.tres (D4 - the engine's own
## raycast vehicle system, tuned for touch: no gear shifts, no
## stall-outs). The B context enters/exits ("B: ENTER" at the door);
## while driving, the hero rides hidden in the seat (the camera rig
## follows the hero node, so it follows the car for free), steer is
## the move stick and GAS/BRAKE/HANDBRAKE/HORN are the pills.
## Engine audio v1: a pitched synth hum layer (metal_ring pitched
## low) that rises with speed - an honest placeholder until a CC0
## engine loop lands with the audio pass.

const CLS_Kit := preload("res://scripts/kit.gd")

signal entered(hero: Node)
signal exited(hero: Node)

var profile: Resource = null
var driver: Node3D = null

var _steer := 0.0
var _engine_hum: AudioStreamPlayer3D
var _idle_pitch := 0.55
var _park_brake := 0.0


static func spawn(parent: Node, kind: String, pos: Vector3,
		yaw := 0.0) -> Node3D:
	var profile: Resource = load("res://data/vehicles/%s.tres" % kind)
	if profile == null:
		push_error("Vehicle: no profile '%s'" % kind)
		return null
	var script := load("res://scripts/world/vehicle.gd") as GDScript
	var v: VehicleBody3D = script.new()
	v.profile = profile
	v.position = pos
	v.rotation.y = yaw
	parent.add_child(v)
	return v


func _ready() -> void:
	add_to_group("vehicle")
	if profile == null:
		profile = load("res://data/vehicles/sedan.tres")
	mass = float(profile.mass_kg)
	# layer 2: the world pushes the car and the hero cannot walk
	# through it, but the camera rig's spring arm (mask 1) never
	# snags on the body the hero rides inside
	collision_layer = 2
	collision_mask = 1
	# a low centre of mass keeps the arcade car planted
	var com := Node3D.new()
	com.name = "CentreOfMass"
	com.position = Vector3(0, -0.45, 0)
	add_child(com)
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	# the body collider
	var col := CollisionShape3D.new()
	col.name = "BodyShape"
	var shape := BoxShape3D.new()
	shape.size = profile.body_size
	col.shape = shape
	col.position = Vector3(0, profile.body_size.y * 0.5 + 0.25, 0)
	add_child(col)
	# the wheels: front steer, rear drive
	var hx := float(profile.track) / 2.0
	var hz := float(profile.wheel_base) / 2.0
	var wy := float(profile.wheel_r)
	for spec in [["FL", -hx, -hz, true, false], ["FR", hx, -hz, true, false],
			["RL", -hx, hz, false, true], ["RR", hx, hz, false, true]]:
		var w := VehicleWheel3D.new()
		w.name = "Wheel_" + spec[0]
		w.position = Vector3(spec[1], wy, spec[2])
		w.use_as_steering = spec[3]
		w.use_as_traction = spec[4]
		w.wheel_radius = float(profile.wheel_r)
		w.suspension_travel = 0.12
		w.suspension_stiffness = 80.0
		w.wheel_friction_slip = 3.5
		w.damping_compression = 4.6
		w.damping_relaxation = 5.4
		add_child(w)
	# the visual body from the kit, scaled to real proportions
	var visual := CLS_Kit.place(self, str(profile.model), Vector3.ZERO)
	if visual:
		visual.name = "Body"
		visual.scale = Vector3.ONE * float(profile.model_scale)
		visual.position = Vector3(0, 0.32, 0)
	# the light read: emissive quads front + rear (no real lights -
	# mobile budget)
	_lights()
	_engine_hum = AudioStreamPlayer3D.new()
	_engine_hum.name = "EngineHum"
	var hum_stream: AudioStreamOggVorbis = load(
			"res://assets/audio/metal_ring_1.ogg")
	if hum_stream:
		hum_stream.loop = true
	_engine_hum.stream = hum_stream
	_engine_hum.volume_db = -26.0
	_engine_hum.pitch_scale = _idle_pitch
	_engine_hum.max_distance = 26.0
	add_child(_engine_hum)
	_engine_hum.play()


func _lights() -> void:
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.1, 0.16, 0.06)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.95, 0.92, 0.8)
	fmat.emission_enabled = true
	fmat.emission = Color(0.9, 0.88, 0.7)
	fmat.emission_energy_multiplier = 1.1
	fm.material = fmat
	front.mesh = fm
	front.position = Vector3(0, 0.75, -profile.body_size.z / 2.0 - 0.03)
	front.name = "Headlights"
	add_child(front)
	var rear := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(1.1, 0.14, 0.06)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.9, 0.1, 0.1)
	rmat.emission_enabled = true
	rmat.emission = Color(0.85, 0.06, 0.06)
	rmat.emission_energy_multiplier = 0.9
	rm.material = rmat
	rear.mesh = rm
	rear.position = Vector3(0, 0.75, profile.body_size.z / 2.0 + 0.03)
	rear.name = "Taillights"
	add_child(rear)


func _physics_process(delta: float) -> void:
	# the car owns its own inputs while driven: B exits, the horn
	# honks (the hero's physics loop is parked in the seat)
	if driver != null:
		if Input.is_action_just_pressed("dodge"):
			_exit_car(driver)
			return
		if Input.is_action_just_pressed("horn"):
			Sound.play("bell_heavy_0", -8.0)
			Haptics.fire("ui")
	# planted: soft downforce grows with speed
	var speed := linear_velocity.length()
	apply_central_force(Vector3.DOWN * float(profile.downforce) * (
			1.0 + speed * 0.06))
	if driver == null:
		engine_force = 0.0
		# the parked brake RAMPS in: an instant full brake on a
		# rolling raycast car is the classic simulation explosion
		_park_brake = minf(_park_brake + delta * 900.0,
				float(profile.brake_force) * 0.6)
		brake = _park_brake
		steering = move_toward(steering, 0.0, delta * 5.0)
		_hum(0.0)
		return
	# steer on the move stick (keyboard: move_left/right)
	var steer_in := Input.get_axis("move_left", "move_right")
	if steer_in == 0.0 and driver != null:
		# the touch UI writes the hero's stick directly
		var v = driver.get("move_stick")
		if v != null:
			steer_in = (v as Vector2).x
	var max_steer := deg_to_rad(float(profile.max_steer_deg))
	var want := -steer_in * max_steer
	# the wheel steadies at speed (an arcade courtesy)
	want *= clampf(1.15 - speed * 0.035, 0.45, 1.0)
	_steer = move_toward(_steer, want,
			float(profile.steer_speed) * delta)
	steering = _steer
	# pedals
	var gas := Input.get_action_strength("accelerate") \
			- Input.get_action_strength("brake")
	engine_force = gas * float(profile.engine_force)
	brake = 0.0
	if Input.is_action_pressed("handbrake"):
		brake = float(profile.handbrake_force)
		engine_force *= 0.25
	_hum(speed)


## The engine hum layer: pitch rises with speed (v1 synth - the
## honest placeholder).
func _hum(speed: float) -> void:
	if _engine_hum == null:
		return
	var target := _idle_pitch + clampf(speed * 0.035, 0.0, 0.85)
	_engine_hum.pitch_scale = lerpf(_engine_hum.pitch_scale,
			target, 0.1)
	_engine_hum.volume_db = -26.0 if speed < 0.5 else -20.0


## The B-context answers.
func verb_for(hero: Node3D) -> String:
	return "EXIT" if driver != null else "ENTER"


func try_use(hero: Node3D) -> bool:
	if driver != null:
		_exit_car(hero)
	else:
		_enter_car(hero)
	return true


func _enter_car(hero: Node3D) -> void:
	driver = hero
	_park_brake = 0.0
	# the hero rides hidden in the seat - the camera rig follows the
	# hero node, so it follows the car with zero camera changes
	hero.set_physics_process(false)
	hero.visible = false
	# CRITICAL: the hero's capsule sits INSIDE the body collider while
	# driving - every frame of overlap fires depenetration impulses
	# that launch the car at random. The rider is not a collider.
	var shape := hero.get_node_or_null("BodyShape") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", true)
	hero.set_collision_mask(0)
	hero.set_meta("riding", true)
	hero.reparent(self)
	hero.position = profile.seat_offset
	hero.rotation = Vector3.ZERO
	hero.velocity = Vector3.ZERO
	engine_force = 0.0
	Sound.play("door_close_0", -8.0)
	Haptics.fire("ui")
	_ui_driving(true)
	entered.emit(hero)
	Log.info("Vehicle: %s entered" % profile.id)


## The touch UI swaps its pills for the driving set.
func _ui_driving(on: bool) -> void:
	var ui := get_node_or_null("/root/Game/TouchUI")
	if ui and ui.has_method("set_driving"):
		ui.call("set_driving", on)


func _exit_car(hero: Node3D) -> void:
	driver = null
	engine_force = 0.0
	# the driverless car coasts to a halt under the ramping parked
	# brake. The hero-side work is DEFERRED: reparenting a node from
	# inside a physics callback is what launched the car skyward
	_ui_driving(false)
	exited.emit(hero)
	_finish_exit.call_deferred(hero)
	Log.info("Vehicle: exiting the %s" % profile.id)


func _finish_exit(hero: Node3D) -> void:
	if not is_instance_valid(hero):
		return
	# step out to the driver's side, clear of the body
	var side := global_transform.basis.x.normalized()
	var out := global_position + side * 2.2 + Vector3(0, 0.05, 0)
	hero.reparent(get_tree().current_scene)
	hero.global_position = out
	hero.velocity = Vector3.ZERO
	hero.visible = true
	hero.set_physics_process(true)
	var shape := hero.get_node_or_null("BodyShape") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", false)
	hero.set_collision_mask(3)
	hero.set_meta("riding", false)
	Sound.play("door_close_0", -6.0, 0.85)
	Haptics.fire("ui")
