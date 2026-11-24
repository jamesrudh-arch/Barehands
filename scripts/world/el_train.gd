class_name ElTrain
extends Node3D

## THE ELEVATED TRAIN (S5.18): the noir image - lit cars crossing
## the neighbourhood's sky on an overhead line, rails on pylons
## above the north side of the street. Every ~35 s a 4-car train
## sweeps the avenue at 11 m/s with a low rumble. Mobile-honest:
## static rail geometry + one moving group, emissive window
## quads, no lights, no shadow casters.

const RAIL_Y := 8.6
const RAIL_Z := -7.5          # over the north sidewalk edge
const RAIL_X0 := -72.0
const RAIL_X1 := 48.0
const CAR_LEN := 5.6
const CAR_GAP := 0.7
const CARS := 4
const SPEED := 11.0           # m/s - a streetcar's amble
const CADENCE_S := 35.0

var _train: Node3D
var _t_until := 6.0           # first pass comes quick (the hook)
var _running := false
var _dir := 1.0


static func build(parent: Node3D) -> Node3D:
	var t := preload("res://scripts/world/el_train.gd").new()
	t.name = "ElTrain"
	parent.add_child(t)
	t._build_line()
	return t


func _build_line() -> void:
	# THE PYLONS: dark steel columns every 12 m, a cross-beam at
	# the top - the line reads even with no train on it
	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.16, 0.17, 0.2)
	pylon_mat.roughness = 0.85
	for x in range(int(RAIL_X0), int(RAIL_X1), 12):
		var col := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, RAIL_Y - 0.3, 0.55)
		bm.material = pylon_mat
		col.mesh = bm
		col.position = Vector3(x, (RAIL_Y - 0.3) * 0.5, RAIL_Z)
		add_child(col)
		var beam := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(1.8, 0.3, 0.9)
		bb.material = pylon_mat
		beam.mesh = bb
		beam.position = Vector3(x, RAIL_Y - 0.25, RAIL_Z)
		add_child(beam)
	# THE RAILS: two long dark runners the full span
	for dz in [-0.5, 0.5]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(RAIL_X1 - RAIL_X0, 0.16, 0.22)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.22, 0.23, 0.26)
		rmat.metallic = 0.6
		rmat.roughness = 0.4
		rm.material = rmat
		rail.mesh = rm
		rail.position = Vector3((RAIL_X0 + RAIL_X1) * 0.5,
				RAIL_Y, RAIL_Z + dz)
		add_child(rail)
	# THE TRAIN: built dark, windowed, parked off-frame until its
	# cadence calls it
	_train = Node3D.new()
	_train.name = "TrainSet"
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.1, 0.11, 0.13)
	body_mat.metallic = 0.25
	body_mat.roughness = 0.6
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.0, 0.0, 0.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.82, 0.55)
	glow_mat.emission_energy_multiplier = 4.5
	# the flanks must render from BOTH sides - an off-axis viewer
	# (any street vantage) has one flank backfaced and the other
	# hidden behind the body. This was the invisible-train bug.
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in CARS:
		var car := Node3D.new()
		car.name = "Car%d" % i
		var body := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(CAR_LEN, 2.1, 2.0)
		cb.material = body_mat
		body.mesh = cb
		body.position = Vector3(-i * (CAR_LEN + CAR_GAP), 0, 0)
		car.add_child(body)
		# THE WINDOWS: emissive quads along both flanks - the lit
		# cars are the whole image at night
		for side in [-1.03, 1.03]:
			for w in 5:
				var win := MeshInstance3D.new()
				var wm := QuadMesh.new()
				wm.size = Vector2(1.0, 0.8)
				var mat: StandardMaterial3D = \
						glow_mat.duplicate() as StandardMaterial3D
				mat.emission = Color(1.0, 0.82, 0.55) \
						if (i + w) % 3 != 0 else Color(0.6, 0.75, 0.9)
				wm.material = mat
				win.mesh = wm
				win.rotation.y = PI / 2.0 if side < 0 else -PI / 2.0
				win.position = Vector3(
						body.position.x - 2.1 + w * 1.05,
						0.18, side)
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				car.add_child(win)
		# THE STRIP: a full-length warm bar under each car's window
		# line - the car reads as ONE lit shape, not five dots
		for side in [-1.05, 1.05]:
			var strip := MeshInstance3D.new()
			var sm := QuadMesh.new()
			sm.size = Vector2(CAR_LEN - 0.6, 0.16)
			var stmat: StandardMaterial3D = \
					glow_mat.duplicate() as StandardMaterial3D
			stmat.emission_energy_multiplier = 3.0
			sm.material = stmat
			strip.mesh = sm
			strip.rotation.y = PI / 2.0 if side < 0 else -PI / 2.0
			# x follows the body's in-car offset - the strip rides
			# its OWN car, not the train origin
			strip.position = Vector3(body.position.x, -0.28, side)
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			car.add_child(strip)
		car.position = Vector3(0, RAIL_Y + 1.25, RAIL_Z)
		_train.add_child(car)
	add_child(_train)
	_train.visible = false


func _process(delta: float) -> void:
	if _running:
		_train.position.x += SPEED * _dir * delta
		var lead := _train.position.x if _dir > 0.0 \
				else _train.position.x - CARS * (CAR_LEN + CAR_GAP)
		if _dir > 0.0 and lead > RAIL_X1 + 2.0:
			_running = false
			_train.visible = false
			_t_until = CADENCE_S
			_dir = -1.0 if randf() < 0.5 else 1.0
		elif _dir < 0.0 and lead < RAIL_X0 - 2.0:
			_running = false
			_train.visible = false
			_t_until = CADENCE_S
			_dir = -1.0 if randf() < 0.5 else 1.0
	else:
		_t_until -= delta
		if _t_until <= 0.0:
			_depart()


func _depart() -> void:
	_running = true
	_train.visible = true
	_train.position.x = RAIL_X0 if _dir > 0.0 else RAIL_X1
	# the rumble: the hum bed pitched low and quiet - the street
	# HEARS the line before it sees the cars
	Sound.play("hum", -16.0, 0.55, 0.02)
	Log.info("City: the elevated train crosses the avenue")
