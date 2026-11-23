extends Node3D

## USER OVERRIDES R1/R2: the WAREHOUSE - a separate small START scene.
## The street is a SEPARATE scene (main.tscn) reached through the VISIBLE
## GATE at the front wall: a half-raised roller shutter, daylight
## spilling under it, and a walk-out zone that fades you onto the docks.
## The scene mounts the REAL player, the REAL follow camera and the REAL
## touch controls exactly like SafeBoot does - no street, no blocks, no
## cast. Small on purpose: it is a room, not a world.

const STREET_SCENE := "res://scenes/main.tscn"

const GATE_EXIT := Vector3(0.0, 1.1, 7.0)      # local, in the opening
const SPAWN := Vector3(0.0, 0.1, -1.0)         # by the cot, facing home

var _busy := false
var _gate_zone: Area3D = null


func _ready() -> void:
	_build_room()
	_build_props()
	_build_gate()
	_build_hero_and_camera()
	_build_ui()
	_build_exit_zone()
	_build_fade()
	set_meta("street_path", STREET_SCENE)
	Log.info("Warehouse: start scene ready (R1/R2)")


## Concrete floor, corrugated walls; the +Z wall leaves the gate gap.
func _build_room() -> void:
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(14.0, 0.2, 16.0)
	fc.shape = fs
	floor_body.add_child(fc)
	var floor_mesh := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(14.0, 0.2, 16.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.13, 0.13, 0.14)
	fm.material = fmat
	floor_mesh.mesh = fm
	floor_mesh.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_mesh)
	# walls: N (-Z), S split around the gate gap (+Z), E, W
	for w in [[Vector3(0, 2.5, -8.0), Vector3(14.0, 5.0, 0.4)],
			[Vector3(-5.0, 2.5, 8.0), Vector3(4.0, 5.0, 0.4)],
			[Vector3(5.0, 2.5, 8.0), Vector3(4.0, 5.0, 0.4)],
			[Vector3(0, 4.25, 8.0), Vector3(6.0, 1.5, 0.4)],
			[Vector3(-7.0, 2.5, 0.0), Vector3(0.4, 5.0, 16.4)],
			[Vector3(7.0, 2.5, 0.0), Vector3(0.4, 5.0, 16.4)]]:
		var body := StaticBody3D.new()
		add_child(body)
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = w[1]
		cs.shape = s
		body.add_child(cs)
		var mesh := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = w[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.24, 0.27)
		mat.metallic = 0.35
		m.material = mat
		mesh.mesh = m
		mesh.position = w[0]
		body.add_child(mesh)
		body.position = w[0]
		mesh.position = Vector3.ZERO


## A cot, a locker, a workbench, crates, one hanging bulb. Home, cheap.
func _build_props() -> void:
	# the cot
	var cot := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.0, 0.35, 3.4)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.35, 0.2, 0.16)
	cm.material = cmat
	cot.mesh = cm
	cot.position = Vector3(-4.6, 0.3, -5.4)
	add_child(cot)
	var pillow := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.6, 0.16, 0.5)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.55, 0.55, 0.5)
	pm.material = pmat
	pillow.mesh = pm
	pillow.position = Vector3(-4.6, 0.55, -6.6)
	add_child(pillow)
	# the locker
	var locker := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.2, 2.2, 0.6)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.16, 0.3, 0.24)
	lm.material = lmat
	locker.mesh = lm
	locker.position = Vector3(-6.2, 1.1, -3.0)
	add_child(locker)
	# the workbench
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 0.9, 1.1)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.3, 0.24, 0.16)
	bm.material = bmat
	bench.mesh = bm
	bench.position = Vector3(5.4, 0.45, -6.4)
	add_child(bench)
	# crates
	for c in [[4.8, 0.45, 3.2], [6.0, 0.45, 4.2], [5.4, 1.3, 3.7]]:
		var crate := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.9, 0.9, 0.9)
		var kmat := StandardMaterial3D.new()
		kmat.albedo_color = Color(0.32, 0.26, 0.17)
		km.material = kmat
		crate.mesh = km
		crate.position = Vector3(c[0], c[1], c[2])
		add_child(crate)
	# the hanging bulb + its light
	var wire := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.03, 1.4, 0.03)
	wire.mesh = wm
	wire.position = Vector3(0, 4.3, 0)
	add_child(wire)
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0, 3.5, 0)
	bulb.light_color = Color(1.0, 0.85, 0.6)
	bulb.omni_range = 9.0
	bulb.light_energy = 1.1
	add_child(bulb)


## THE VISIBLE GATE (R2): a half-raised roller shutter on the +Z wall -
## stacked slats above a two-metre gap, warm light spilling under it,
## chains at the sides and the sign that says where it goes. You SEE the
## way out from anywhere in the room.
func _build_gate() -> void:
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.add_to_group("warehouse_gate")
	add_child(gate)
	# the slats: stacked above the opening, half-raised
	for i in 6:
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(6.0, 0.28, 0.22)
		var svm := StandardMaterial3D.new()
		svm.albedo_color = Color(0.38, 0.4, 0.44)
		svm.metallic = 0.6
		sm.material = svm
		slat.mesh = sm
		slat.position = Vector3(0, 2.6 + i * 0.3, 7.9)
		gate.add_child(slat)
	# the light under the gate: warm, from the street side
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.6, 7.2)
	glow.light_color = Color(1.0, 0.72, 0.4)
	glow.omni_range = 7.0
	glow.light_energy = 1.3
	gate.add_child(glow)
	# the spill quad on the floor
	var spill := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(5.0, 2.4)
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color(1.0, 0.75, 0.45, 0.16)
	qmat.emission_enabled = true
	qmat.emission = Color(1.0, 0.7, 0.4)
	qmat.emission_energy_multiplier = 0.35
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = qmat
	spill.mesh = qm
	spill.rotation = Vector3(-PI / 2.0, 0, 0)
	spill.position = Vector3(0, 0.02, 5.9)
	gate.add_child(spill)
	# the sign above the gap - where the gate goes
	var sign := Label3D.new()
	sign.text = "THE STREET"
	sign.modulate = Color(1.0, 0.8, 0.45)
	sign.font_size = 44
	sign.position = Vector3(0, 2.35, 7.8)
	gate.add_child(sign)
	var arrow := Label3D.new()
	arrow.text = "walk out"
	arrow.modulate = Color(0.7, 0.75, 0.8)
	arrow.font_size = 26
	arrow.position = Vector3(0, 0.9, 7.8)
	gate.add_child(arrow)
	# home marks the way back in
	var home := Label3D.new()
	home.text = "HOME"
	home.modulate = Color(0.5, 0.9, 0.7)
	home.font_size = 30
	home.position = Vector3(0, 4.6, -7.8)
	gate.add_child(home)


func _build_hero_and_camera() -> void:
	# where you wake: fresh run by the cot, or back from the street
	var arrived: Variant = Settings.value("arrived_from")
	var from_street := arrived != null and str(arrived) == "street"
	var hero: Node = load("res://scenes/player.tscn").instantiate()
	hero.name = "Player"
	hero.position = SPAWN if not from_street else Vector3(0.0, 0.1, 5.6)
	hero.rotation.y = PI if not from_street else 0.0
	add_child(hero)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 70.0
	cam.script = load("res://scripts/camera_follow.gd")
	add_child(cam)


## The REAL touch controls, mounted exactly like main.tscn mounts them.
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.script = load("res://scripts/touch_buttons.gd")
	ui.add_to_group("hud")
	add_child(ui)
	var stick := Control.new()
	stick.name = "Joystick"
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.script = load("res://scripts/stick_input.gd")
	ui.add_child(stick)
	# R3: the second camera control - the visible pad, right side
	var pad: Control = load("res://scripts/cam_stick.gd").new()
	pad.name = "CamPad"
	ui.add_child(pad)


## The walk-out zone, in the gap under the shutter.
func _build_exit_zone() -> void:
	_gate_zone = Area3D.new()
	_gate_zone.position = GATE_EXIT
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 2.2, 1.2)
	col.shape = shape
	_gate_zone.add_child(col)
	add_child(_gate_zone)
	_gate_zone.body_entered.connect(func(b):
		if b.is_in_group("player") and not _busy:
			_goto_street())


func _goto_street() -> void:
	_busy = true
	set_meta("went_to_street", true)
	Log.info("Warehouse: out the gate, to the street")
	await _fade_out()
	Settings.set_value("arrived_from", "warehouse")
	get_tree().change_scene_to_file(STREET_SCENE)


## One fade, reused by the exit.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 90
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Black"
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


func _fade_out() -> void:
	var rect := get_node_or_null("Fade/Black") as ColorRect
	if rect == null:
		return
	var dur := float(Settings.value("fade_s"))
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, dur)
	await tw.finished
