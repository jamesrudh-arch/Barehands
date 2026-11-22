extends Node3D
const CLS_Apartment := preload("res://scripts/apartment.gd")
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
const CLS_Kit := preload("res://scripts/kit.gd")
## Interiors are separate, reached through a fade (bible 6). This is
## the noodle shop - the anchor of your block: the pot's always on, the
## owner talks, and the stairs by the counter climb to the rooms above
## (the apartment the safehouse door opens into, on its other face).
## The node sits far off the world axis so the room never collides with
## the blocks; only the street front and its walk-in zone live on the
## block, placed by this script into the main root.

const INTERIOR_X := 720.0
const DOOR_STREET := Vector3(-4.0, 1.0, 6.4)    # walk-in zone (street)
const SHOP_FRONT := Vector3(-4.0, 0.0, 8.2)     # the front itself
const INSIDE_SPAWN := Vector3(0, 0.02, 1.6)     # local to this node
const STREET_RETURN := Vector3(-4.0, 0.02, 5.4) # where you step back out

var _busy := false
var _near := false
var _front_prompt: Label3D = null
var _owner_bubble: Label3D = null
var _world: Node = null  # the main root: owns the street-side pieces


func _ready() -> void:
	_world = get_parent()
	position = Vector3(INTERIOR_X, 0.0, 0.0)
	# the door answers GRAB like the safehouse door does (bible 6:
	# interiors are separate, reached through a fade - never a stumble)
	add_to_group("safehouse")
	add_to_group("interior")
	# B18 6C: the door facts the DEVICE REPORT reads
	add_to_group("door_prompt")
	set_meta("door_name", "NOODLE SHOP DOOR")
	set_meta("door_state", "enter/exit")
	_build_front()
	_build_room()


## GRAB at the street door (the player's single grab consumer).
func try_use(_p: Node3D) -> bool:
	if _near and not _busy:
		enter()
		return true
	return false


static func is_inside_interior(p: Node3D) -> bool:
	# B18 6C: the apartment (the starting room) is an interior world
	# too - the street fence must not reach in there either.
	# B19: the three market venues (gym, bar, club) join the exemption
	# list - their rooms sit off the axis like the shop's does.
	if p == null:
		return false
	for room_x in [INTERIOR_X, CLS_Apartment.ROOM_X] + VENUE_ROOM_XS:
		if absf(p.global_position.x - room_x) < 12.0:
			return true
	return false


const VENUE_ROOM_XS := [840.0, 900.0, 960.0]


## Fade to the room and back. One fade at a time.
func enter() -> void:
	if _busy:
		return
	_busy = true
	await Blocks.fade_out()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = global_position + INSIDE_SPAWN
		p.rotation.y = PI
		Blocks.snap_camera_to(p)
	await Blocks.fade_in()
	_busy = false
	Log.info("Interior: into the noodle shop")


func exit_to_street() -> void:
	if _busy:
		return
	_busy = true
	await Blocks.fade_out()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = STREET_RETURN
		p.rotation.y = 0.0
		Blocks.snap_camera_to(p)
	await Blocks.fade_in()
	_busy = false


func _zone(parent: Node, pos: Vector3, on_body: Callable) -> void:
	var a := Area3D.new()
	a.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.2, 1.4)
	col.shape = shape
	a.add_child(col)
	parent.add_child(a)
	a.body_entered.connect(on_body)


# --- the street front (lives on the block) ---------------------------------


func _build_front() -> void:
	var g := Node3D.new()
	g.name = "NoodleShopFront"
	g.add_to_group("shopfront")
	g.set_meta("plank_off", Vector3(0, 0.5, -0.34))
	g.position = SHOP_FRONT
	g.rotation.y = PI
	_world.add_child(g)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.4, 3.2, 0.3)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.07, 0.05)
	pm.material = pmat
	panel.mesh = pm
	panel.position = Vector3(0, 1.6, 0)
	g.add_child(panel)
	var sign := Label3D.new()
	sign.text = "GOLDEN LUCK NOODLES"
	sign.modulate = Color(1.0, 0.75, 0.3)
	sign.font_size = 52
	sign.position = Vector3(0, 3.6, 0)
	g.add_child(sign)
	var glow := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(3.6, 1.6)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.6, 0.2, 0.13)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.material = gmat
	glow.mesh = gm
	glow.position = Vector3(0, 0.05, -1.3)
	glow.rotation = Vector3(-PI / 2.0, 0, 0)
	g.add_child(glow)
	var rooms := Label3D.new()
	rooms.text = "rooms upstairs"
	rooms.modulate = Color(0.65, 0.6, 0.5)
	rooms.font_size = 28
	rooms.position = Vector3(2.6, 2.6, -0.1)
	g.add_child(rooms)
	# B18 6C: a floating ENTER prompt at the door, shown when near
	_front_prompt = Label3D.new()
	_front_prompt.text = "ENTER"
	_front_prompt.modulate = Color(1.0, 0.8, 0.35)
	_front_prompt.font_size = 44
	_front_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_front_prompt.outline_size = 10
	_front_prompt.outline_modulate = Color(0.02, 0.02, 0.03)
	_front_prompt.no_depth_test = true
	_front_prompt.visible = false
	_front_prompt.position = Vector3(0, 2.1, -0.7)
	g.add_child(_front_prompt)
	# the door zone only WATCHES: GRAB steps through
	var a := Area3D.new()
	a.position = DOOR_STREET
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.2, 1.6)
	col.shape = shape
	a.add_child(col)
	_world.add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_near = true
			_front_prompt.visible = true
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_hint"):
				hud.show_hint("GRAB to step inside", 3.0))
	a.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_near = false
			_front_prompt.visible = false)


# --- the room (local, far off the axis) ---------------------------------------


func _build_room() -> void:
	# floor + collision
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(10, 1, 9)
	fc.shape = fs
	fc.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fc)
	var floor_mesh := MeshInstance3D.new()
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.1, 0.07)
	var fm := BoxMesh.new()
	fm.size = Vector3(10, 0.2, 9)
	fm.material = fmat
	floor_mesh.mesh = fm
	floor_mesh.position = Vector3(0, -0.1, 0)
	add_child(floor_mesh)
	# walls (north = counter wall; south wall leaves the door gap)
	for w in [[Vector3(0, 1.8, -4.4), Vector3(10, 3.6, 0.4)],
			[Vector3(-5.0, 1.8, 0), Vector3(0.4, 3.6, 9)],
			[Vector3(5.0, 1.8, 0), Vector3(0.4, 3.6, 9)],
			[Vector3(-3.2, 1.8, 4.4), Vector3(3.6, 3.6, 0.4)],
			[Vector3(3.2, 1.8, 4.4), Vector3(3.6, 3.6, 0.4)]]:
		var wall := StaticBody3D.new()
		wall.position = w[0]
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = w[1]
		col.shape = cs
		wall.add_child(col)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = w[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.08, 0.06)
		bm.material = mat
		mesh.mesh = bm
		wall.add_child(mesh)
		add_child(wall)
	# the counter + stools
	var counter := StaticBody3D.new()
	counter.position = Vector3(0, 0.55, -2.2)
	var cc := CollisionShape3D.new()
	var ccs := BoxShape3D.new()
	ccs.size = Vector3(7.0, 1.1, 1.0)
	cc.shape = ccs
	counter.add_child(cc)
	var cmesh := MeshInstance3D.new()
	var cmm := BoxMesh.new()
	cmm.size = Vector3(7.0, 1.1, 1.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.25, 0.15, 0.08)
	cmm.material = cmat
	cmesh.mesh = cmm
	counter.add_child(cmesh)
	add_child(counter)
	for sx in [-2.4, -0.8, 0.8, 2.4]:
		var stool := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.3
		sm.bottom_radius = 0.24
		sm.height = 0.7
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.4, 0.12, 0.1)
		sm.material = smat
		stool.mesh = sm
		stool.position = Vector3(sx, 0.35, -0.8)
		add_child(stool)
	# the pot: always on, warm without a dynamic light
	var pot := MeshInstance3D.new()
	var pm2 := CylinderMesh.new()
	pm2.top_radius = 0.35
	pm2.bottom_radius = 0.3
	pm2.height = 0.5
	var pmat2 := StandardMaterial3D.new()
	pmat2.albedo_color = Color(0.5, 0.2, 0.08)
	pmat2.emission_enabled = true
	pmat2.emission = Color(1.0, 0.45, 0.1)
	pmat2.emission_energy_multiplier = 0.8
	pm2.material = pmat2
	pot.mesh = pm2
	pot.position = Vector3(1.8, 1.35, -2.2)
	add_child(pot)
	# a window quad with the street's neon in it
	var window := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(1.6, 1.0)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.7, 0.15, 0.45, 0.5)
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.material = wmat
	window.mesh = wm
	window.position = Vector3(-4.78, 1.9, -1.5)
	window.rotation = Vector3(0, PI / 2.0, 0)
	add_child(window)
	# the stairs up (dressing: the rooms above the shop)
	var stair := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(1.4, 0.2, 2.6)
	var stmat := StandardMaterial3D.new()
	stmat.albedo_color = Color(0.2, 0.13, 0.08)
	stm.material = stmat
	stair.mesh = stm
	stair.position = Vector3(4.0, 0.35, -3.0)
	add_child(stair)
	var up := Label3D.new()
	up.text = "rooms"
	up.modulate = Color(0.6, 0.55, 0.45)
	up.font_size = 28
	up.position = Vector3(4.0, 1.4, -3.0)
	add_child(up)
	# B19: the shop dresses like a business - the back bar, the food on
	# the counter, a dining table, the clutter of a working kitchen
	for kx in [-3.4, -2.95, -2.5]:
		CLS_Kit.place(self, "kenney_furniture/kitchenBar.glb",
				Vector3(kx, 0.0, -3.6), 0.0, 1.15)
	CLS_Kit.place(self, "kenney_food/pan-stew.glb", Vector3(-2.0, 1.12, -2.15), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_food/pot-lid.glb", Vector3(1.8, 1.6, -2.2), 0.0, 1.2)
	CLS_Kit.place(self, "kenney_food/skewer.glb", Vector3(-0.6, 1.14, -2.3), 0.4, 1.0)
	CLS_Kit.place(self, "kenney_food/skewer.glb", Vector3(-0.2, 1.14, -2.1), 0.1, 1.0)
	CLS_Kit.place(self, "kenney_food/cabbage.glb", Vector3(2.6, 1.16, -2.0), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_food/loaf-round.glb", Vector3(3.1, 1.15, -2.4), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/tableRound.glb", Vector3(-2.2, 0.0, 1.6), 0.0, 1.05)
	CLS_Kit.place(self, "kenney_furniture/chair.glb", Vector3(-1.5, 0.0, 1.6), -PI / 2.0, 1.05)
	CLS_Kit.place(self, "kenney_furniture/chair.glb", Vector3(-2.9, 0.0, 1.6), PI / 2.0, 1.05)
	CLS_Kit.place(self, "kenney_furniture/pottedPlant.glb", Vector3(-4.3, 0.0, 3.6), 0.0, 1.0)
	CLS_Kit.place(self, "kenney_furniture/trashcan.glb", Vector3(4.3, 0.0, 3.6), 0.0, 1.0)
	# Gate A: the shop has CUSTOMERS - two at the table (a crouched
	# idle reads as sitting at its height), different builds, a bowl each
	for cust in [
			[Vector3(-2.85, 0.0, 1.6), Color(0.35, 0.3, 0.4),
					"res://assets/cast/Male_Peasant_Body.gltf"],
			[Vector3(-1.5, 0.0, 1.65), Color(0.3, 0.38, 0.32),
					"res://assets/cast/Female_Ranger_Body.gltf"]]:
		var cr := CLS_NpcRig.new()
		cr.build([cust[2]], cust[1], cust[1] * 0.35, "Crouch_Idle", 0.55)
		cr.position = cust[0]
		cr.rotation.y = PI + randf_range(-0.4, 0.4)
		add_child(cr)
		var bowl := MeshInstance3D.new()
		var bwm := CylinderMesh.new()
		bwm.top_radius = 0.09
		bwm.bottom_radius = 0.07
		bwm.height = 0.06
		var bwmat := StandardMaterial3D.new()
		bwmat.albedo_color = Color(0.85, 0.8, 0.7)
		bwm.material = bwmat
		bowl.mesh = bwm
		bowl.position = cust[0] + Vector3(0.28, 0.42, 0.05)
		add_child(bowl)
	# the owner behind the counter
	var owner := Node3D.new()
	owner.add_to_group("shop_owner")
	owner.position = Vector3(0.2, 0, -3.1)
	owner.rotation.y = PI
	add_child(owner)
	var rig := CLS_NpcRig.new()
	rig.build(["res://assets/cast/Superhero_Female_FullBody.gltf",
			"res://assets/cast/Female_Ranger_Body.gltf"],
			Color(0.75, 0.45, 0.2), Color(0.3, 0.15, 0.05),
			"Idle_Talking", 0.95)
	owner.add_child(rig)
	_owner_bubble = Label3D.new()
	_owner_bubble.modulate = Color(0, 0, 0, 0)
	_owner_bubble.font_size = 30
	_owner_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_owner_bubble.outline_size = 8
	_owner_bubble.position = Vector3(0, 2.3, 0)
	owner.add_child(_owner_bubble)
	# the exit, back onto the street
	_zone(self, Vector3(0, 1.0, 3.6), func(b):
		if b.is_in_group("player"):
			exit_to_street())


const OWNER_LINES := [
	"sit, eat - the pot's been on since the fire",
	"your brother ate here tuesday. he didn't pay either",
	"the clubs east of here go all night now",
	"somebody spray-painted the pawn shop again",
	"the underpass to the docks? walk it fast, that's all",
]


func _process(delta: float) -> void:
	if not _owner_bubble:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if not p or not is_inside_interior(p):
		return
	var d := p.global_position.distance_to(
			global_position + Vector3(0.2, 0.0, -3.1))
	var want := clampf(1.0 - (d - 2.0) * 0.7, 0.0, 1.0)
	if want > 0.0 and _owner_bubble.text.is_empty():
		_owner_bubble.text = OWNER_LINES[randi() % OWNER_LINES.size()]
	elif want <= 0.0:
		_owner_bubble.text = ""
	_owner_bubble.modulate.a = lerpf(_owner_bubble.modulate.a, want, delta * 4.0)
