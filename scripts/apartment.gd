extends Node3D
const CLS_Kit := preload("res://scripts/kit.gd")

## LEVERAGE B18 Part 6C: the safehouse apartment - THE STARTING ROOM.
## A small code-built room off the world axis (like the noodle shop
## interior), where a first-run hero wakes up. Exactly ONE door, clearly
## marked: a glowing cyan frame, a THE STREET sign above it, an OPEN
## prompt when you stand near it, and a swing-open animation with a
## creak before the fade to the street. The door answers the hero's
## single GRAB/INTERACT consumer (group "safehouse"), so the contextual
## INTERACT button appears only when it is usable.

const ROOM_X := 780.0
const SPAWN := Vector3(0, 0.02, 1.8)          # local
const DOOR_LOCAL := Vector3(0, 0.0, -3.2)     # local; the -Z wall
const STREET_EXIT := Vector3(-2.0, 0.02, 7.6) # world, by the street door

var _near := false
var _busy := false
var _panel: MeshInstance3D
var _frame: MeshInstance3D
var _prompt: Label3D
var _pulse := 0.0


func _ready() -> void:
	add_to_group("safehouse")
	add_to_group("door_prompt")
	position = Vector3(ROOM_X, 0.0, 0.0)
	set_meta("door_name", "APARTMENT DOOR")
	set_meta("door_state", "closed")
	_build_room()
	_build_door()
	_zone()


func _build_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.13, 0.10)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.13, 0.12, 0.15)
	# floor + walls, SOLID (collision + mesh: the hero must stand on the
	# floor and not walk through walls - meshes alone let them fall)
	for spec in [
		{"pos": Vector3(0, -0.1, 0), "size": Vector3(7.0, 0.2, 7.0),
				"mat": floor_mat},
		{"pos": Vector3(-2.25, 1.5, -3.5), "size": Vector3(2.5, 3.0, 0.2),
				"mat": wall_mat},
		{"pos": Vector3(2.25, 1.5, -3.5), "size": Vector3(2.5, 3.0, 0.2),
				"mat": wall_mat},
		{"pos": Vector3(0, 2.85, -3.5), "size": Vector3(2.0, 0.3, 0.2),
				"mat": wall_mat},
		{"pos": Vector3(0, 1.5, 3.5), "size": Vector3(7.0, 3.0, 0.2),
				"mat": wall_mat},
		{"pos": Vector3(-3.5, 1.5, 0), "size": Vector3(0.2, 3.0, 7.0),
				"mat": wall_mat},
		{"pos": Vector3(3.5, 1.5, 0), "size": Vector3(0.2, 3.0, 7.0),
				"mat": wall_mat},
	]:
		_solid(spec["size"], spec["pos"], spec["mat"])
	# B19: a real home - the bed roll box gives way to furniture (the
	# Kenney CC0 kit): a bed, a side table with a lamp, a bookcase, a
	# television corner, moving boxes, a coat rack, a plant, a rug.
	# The room keeps its light and its lived-in disorder.
	CLS_Kit.place(self, "kenney_furniture/bedSingle.glb",
			Vector3(-2.2, 0.0, 2.3), PI / 2.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/sideTable.glb",
			Vector3(-2.2, 0.0, 1.2), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/lampRoundFloor.glb",
			Vector3(-3.0, 0.0, 1.2), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/bookcaseClosed.glb",
			Vector3(1.2, 0.0, -3.1), 0.0, 1.15)
	CLS_Kit.place(self, "kenney_furniture/cabinetTelevision.glb",
			Vector3(2.6, 0.0, -2.6), -PI / 2.0, 1.05)
	CLS_Kit.place(self, "kenney_furniture/televisionVintage.glb",
			Vector3(2.75, 0.42, -2.6), -PI / 2.0, 1.05)
	CLS_Kit.place(self, "kenney_furniture/rugSquare.glb",
			Vector3(0, 0.005, 0.5), 0.0, 2.2)
	CLS_Kit.place(self, "kenney_furniture/cardboardBoxClosed.glb",
			Vector3(2.6, 0.0, 2.4), 0.3, 1.25)
	CLS_Kit.place(self, "kenney_furniture/cardboardBoxOpen.glb",
			Vector3(2.6, 0.35, 2.4), 0.1, 1.25)
	CLS_Kit.place(self, "kenney_furniture/coatRackStanding.glb",
			Vector3(2.9, 0.0, 0.4), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/pottedPlant.glb",
			Vector3(-3.0, 0.0, -2.9), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/chairRounded.glb",
			Vector3(1.4, 0.0, -1.6), 2.4, 1.05)
	CLS_Kit.place(self, "kenney_food/cup-coffee.glb",
			Vector3(-2.2, 0.4, 1.2), 0.0, 1.0)
	# warm inside light - the room must never be a black hole
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 2.2
	lamp.omni_range = 12.0
	lamp.position = Vector3(0, 2.6, 0.5)
	add_child(lamp)
	# B22 (VLM inspection): the ceiling and door wall read as flat black -
	# a soft second light by the door so the exit reads as a real opening
	var door_glow := OmniLight3D.new()
	door_glow.light_color = Color(0.7, 0.95, 0.8)
	door_glow.light_energy = 0.9
	door_glow.omni_range = 5.0
	door_glow.position = Vector3(0, 1.8, -2.6)
	add_child(door_glow)


## A solid box: collision + mesh together.
func _solid(size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = pos
	add_child(body)


func _build_door() -> void:
	# the glowing frame: findable in the dark from anywhere in the room
	_frame = MeshInstance3D.new()
	_frame.name = "DoorFrame"
	var frm := BoxMesh.new()
	frm.size = Vector3(1.7, 2.5, 0.12)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.05, 0.1, 0.12)
	fmat.emission_enabled = true
	fmat.emission = Color(0.25, 0.95, 0.85)
	fmat.emission_energy_multiplier = 1.1
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frm.material = fmat
	_frame.mesh = frm
	_frame.position = DOOR_LOCAL + Vector3(0, 1.25, 0)
	add_child(_frame)
	# the dark panel that swings open
	_panel = MeshInstance3D.new()
	_panel.name = "DoorPanel"
	var pm := BoxMesh.new()
	pm.size = Vector3(1.3, 2.2, 0.08)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.09, 0.12)
	pm.material = pmat
	_panel.mesh = pm
	_panel.position = DOOR_LOCAL + Vector3(-0.65, 1.1, 0.1)
	# pivot: parent the panel to a hinge node so rotation.y swings it
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = DOOR_LOCAL + Vector3(-0.65, 0.0, 0.1)
	add_child(hinge)
	_panel.position = Vector3(0.65, 1.1, 0.0)
	hinge.add_child(_panel)
	# the handle (Part 6D.4: every door has one)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.06, 0.24, 0.06)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.72, 0.74, 0.78)
	hmat.metallic = 0.8
	hmat.roughness = 0.3
	hm.material = hmat
	handle.mesh = hm
	handle.position = Vector3(0.52, 0.0, 0.07)
	_panel.add_child(handle)
	set_meta("hinge_path", hinge.get_path())
	# the sign above the door + the OPEN prompt
	var sign := Label3D.new()
	sign.text = "THE STREET"
	sign.modulate = Color(0.55, 1.0, 0.9)
	sign.font_size = 40
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = DOOR_LOCAL + Vector3(0, 2.9, 0.2)
	add_child(sign)
	_prompt = Label3D.new()
	_prompt.text = "OPEN"
	_prompt.modulate = Color(1.0, 0.85, 0.3)
	_prompt.font_size = 56
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.outline_size = 12
	_prompt.outline_modulate = Color(0.02, 0.02, 0.03)
	_prompt.no_depth_test = true
	_prompt.visible = false
	_prompt.position = DOOR_LOCAL + Vector3(0, 1.7, 0.35)
	add_child(_prompt)


func _zone() -> void:
	var a := Area3D.new()
	a.position = DOOR_LOCAL + Vector3(0, 1.0, 0.6)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.4, 1.6)
	col.shape = shape
	a.add_child(col)
	add_child(a)
	a.body_entered.connect(_on_enter)
	a.body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false


## The player's single GRAB consumer (player._try_grab_action).
func try_use(_p: Node3D) -> bool:
	if _near and not _busy:
		_open_out()
		return true
	return false


func is_near() -> bool:
	return _near


func door_world_pos() -> Vector3:
	return global_position + DOOR_LOCAL


func _open_out() -> void:
	if _busy:
		return
	_busy = true
	set_meta("door_state", "opening")
	Sound.play("creak_0", -6.0)
	var hinge := get_node(get_meta("hinge_path")) as Node3D
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", -1.9, 0.45)
	await tw.finished
	set_meta("door_state", "open")
	await _to_street()


func _to_street() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var blocks := tree.root.get_node_or_null("/root/Blocks")
	if blocks:
		await blocks.call("fade_out")
	var p := tree.get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = STREET_EXIT
		p.velocity = Vector3.ZERO
		if blocks:
			blocks.call("snap_camera_to", p)
	if blocks:
		await blocks.call("fade_in")
	# swing the door back closed behind you
	var hinge := get_node(get_meta("hinge_path")) as Node3D
	if hinge:
		var tw := create_tween()
		tw.tween_property(hinge, "rotation:y", 0.0, 0.4)
	set_meta("door_state", "closed")
	_busy = false


## Arrive from the street (the safehouse door's GO INSIDE button):
## place the hero inside by the door.
func arrive_from_street() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player") as Node3D
	if p == null:
		return
	p.global_position = global_position + DOOR_LOCAL + Vector3(0, 0.02, 1.2)
	p.velocity = Vector3.ZERO
	var blocks := tree.root.get_node_or_null("/root/Blocks")
	if blocks:
		blocks.call("snap_camera_to", p)


func _process(delta: float) -> void:
	# the frame breathes so it reads as THE way out, even in the dark
	# (B18.3 BUG 11: the breathing stays inside the 1.15 sign cap so it
	# can never read as a white flicker on the phone)
	_pulse += delta
	if _frame:
		var e: float = 1.0 + 0.12 * (0.5 + 0.5 * sin(_pulse * 2.2))
		(_frame.mesh.material as StandardMaterial3D).emission_energy_multiplier = e
	# Gate A (the owner was stuck in this room): during the guide's
	# OPEN step the door opens ITSELF when the hero walks into it - no
	# way to be trapped, even if the prompt is missed
	if not _busy and str(get_meta("door_state", "closed")) == "closed":
		var guide := get_tree().get_first_node_in_group("guide")
		var hero := get_tree().get_first_node_in_group("player") as Node3D
		if guide and hero and int(guide.get("step")) == 1:  # STEP_OPEN
			var d := Vector2(hero.global_position.x - global_position.x,
					hero.global_position.z - (global_position.z - 3.2))
			if d.length() < 2.4:
				_open_out()
