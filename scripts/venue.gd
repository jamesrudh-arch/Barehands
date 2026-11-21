extends Node3D
const CLS_Kit := preload("res://scripts/kit.gd")
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")

## B19 batch 9: the shared mechanics of an enterable venue (the
## noodle shop's pattern, made reusable): a street door that answers
## GRAB, a fade into an off-axis room, a fade back out, a walk-in
## zone, the door-facts the DEVICE REPORT reads. The room itself -
## every stick of furniture - is the subclass's _build_room().

@export var venue_name := "VENUE"
@export var interior_x := 840.0
@export var door_street := Vector3.ZERO       # world position of the door zone
@export var inside_spawn := Vector3(0, 0.02, 1.6)
@export var street_return := Vector3.ZERO     # where you step back out
@export var door_front := Vector3.ZERO        # the sign's spot on the street

## Every venue room's off-axis X (the street fence exempts them all -
## interior.gd's is_inside_interior reads this list).
const ROOM_XS := [840.0, 900.0, 960.0]

var _busy := false
var _near := false
var _prompt: Label3D = null


func _ready() -> void:
	_world = get_parent()
	position = Vector3(interior_x, 0.0, 0.0)
	add_to_group("safehouse")
	add_to_group("interior")
	add_to_group("door_prompt")
	set_meta("door_name", venue_name + " DOOR")
	set_meta("door_state", "enter/exit")
	_place_front()
	_place_door_zone()
	_build_room()
	_build_exit_zone()


## Subclasses build the room here (furniture, light, life).
func _build_room() -> void:
	pass


# --- the street side (placed into the main root) -----------------------------

var _world: Node = null


func _place_front() -> void:
	if _world == null:
		return
	var sign := Label3D.new()
	sign.text = venue_name
	sign.modulate = Color(0.95, 0.75, 0.4)
	sign.font_size = 44
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.outline_size = 8
	sign.position = door_front + Vector3(0, 3.1, 0)
	_world.add_child(sign)


func _place_door_zone() -> void:
	if _world == null:
		return
	var a := Area3D.new()
	a.position = door_street
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.2, 1.6)
	col.shape = shape
	a.add_child(col)
	_world.add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_near = true
			_show_prompt(true))
	a.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_near = false
			_show_prompt(false))


func _build_exit_zone() -> void:
	# inside the room, at the DOOR WALL: walking into it fades you out.
	# The spawn sits deeper in the room, so arriving never trips it
	# (the B19 lesson: a spawn inside the exit zone bounces you straight
	# back to the street).
	var a := Area3D.new()
	a.position = Vector3(0, 1.2, 3.4)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.4, 1.2)
	col.shape = shape
	a.add_child(col)
	add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player") and not _busy:
			exit_to_street())


func _show_prompt(on: bool) -> void:
	if on and _prompt == null and _world != null:
		_prompt = Label3D.new()
		_prompt.text = "[B] ENTER " + venue_name
		_prompt.modulate = Color(0.95, 0.85, 0.6, 0.9)
		_prompt.font_size = 34
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.outline_size = 8
		_prompt.position = door_street + Vector3(0, 2.2, 0)
		_world.add_child(_prompt)
	elif _prompt:
		_prompt.queue_free()
		_prompt = null


## GRAB at the street door (the player's single grab consumer).
func try_use(_p: Node3D) -> bool:
	if _near and not _busy:
		enter()
		return true
	return false


## Fade to the room and back. One fade at a time.
func enter() -> void:
	if _busy:
		return
	_busy = true
	await Blocks.fade_out()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = global_position + inside_spawn
		p.rotation.y = PI
		Blocks.snap_camera_to(p)
	await Blocks.fade_in()
	_busy = false
	Log.info("Venue: into %s" % venue_name)


func exit_to_street() -> void:
	if _busy:
		return
	_busy = true
	await Blocks.fade_out()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = street_return
		p.rotation.y = 0.0
		Blocks.snap_camera_to(p)
	await Blocks.fade_in()
	_busy = false
	Log.info("Venue: back out of %s" % venue_name)


# --- shared room kit helpers (subclass convenience) --------------------------


## Floor + walls + ceiling: a warm room box with collision, the size
## of the venue. Everything is a real surface, lit and collidable.
func room_shell(size := Vector3(9.0, 3.2, 7.0), floor_c := Color(0.16, 0.13, 0.1),
		wall_c := Color(0.13, 0.12, 0.15)) -> void:
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = floor_c
	floor_m.roughness = 0.85
	var _floor := _solid_box(size.x, 0.2, size.z,
			Vector3(0, -0.1, 0), floor_m)
	var wall_m := StandardMaterial3D.new()
	wall_m.albedo_color = wall_c
	wall_m.roughness = 0.9
	for w in [[size.x, 3.2, 0.2, Vector3(0, 1.6, size.z / 2.0)],
			[size.x, 3.2, 0.2, Vector3(0, 1.6, -size.z / 2.0)],
			[0.2, 3.2, size.z, Vector3(size.x / 2.0, 1.6, 0)],
			[0.2, 3.2, size.z, Vector3(-size.x / 2.0, 1.6, 0)]]:
		_solid_box(w[0], w[1], w[2], w[3], wall_m)
	var ceil_m := StandardMaterial3D.new()
	ceil_m.albedo_color = Color(0.07, 0.07, 0.09)
	_solid_box(size.x, 0.2, size.z, Vector3(0, 3.3, 0), ceil_m)
	# the warm practical: one OmniLight, always inside the budget
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.1
	light.omni_range = 9.0
	light.position = Vector3(0, 2.8, 0)
	add_child(light)


func _solid_box(w: float, h: float, d: float, pos: Vector3,
		mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(w, h, d)
	col.shape = cs
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = pos
	add_child(body)
	return body


## Place a piece of real furniture (the CC0 kit).
func furn(rel: String, pos: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	return CLS_Kit.place(self, rel, pos, yaw, s)


## A standing character (a bartender, a trainer, a dancer) - typed so
## callers can drive its clips directly.
func person(pieces: Array, pos: Vector3, tint: Color,
		idle_speed := 0.9) -> CLS_NpcRig:
	var rig := CLS_NpcRig.new()
	rig.build(pieces, tint, tint * 0.35, "Idle", idle_speed)
	rig.position = pos
	add_child(rig)
	return rig
