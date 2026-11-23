extends Node
const CLS_BlockBuilder := preload("res://scripts/block_builder.gd")
const CLS_Interior := preload("res://scripts/interior.gd")
const CLS_Wanderer := preload("res://scripts/wanderer.gd")
## The district made real (bible 6): three blocks, walked - never fast-
## travelled. Block 1 (riverside) is the main scene's own street: the
## neighbourhood, the alley, the noodle shop, the bar, everyone the cast
## plays. Block 2 (market) is the club quarter: the main street, the gym,
## the Mechanic's garage. Block 3 (foundry) is the docks: the warehouse,
## the water, the door the final choice happens at (dressing only until
## the story batch). Blocks 2 and 3 are code-built far down the same
## axis; crossing a gate fades the walk between them, and the
## market<->foundry ends wear the underpass. City.entered_district
## still fires on every crossing - the phone's fog, the music and the
## moods all ride it - and City.district_at answers the LOADED block.

const BLOCK_X := {"riverside": 0.0, "market": 240.0, "foundry": 480.0}
const GATE_X := 19.0          # |x| where a gate sits inside a block
const FADE_S := 0.32
const DAMAGE_CAP := 12        # decals remembered per block

var _current := "riverside"
var _built: Dictionary = {}   # block id -> Node3D (2 and 3)
var _fading := false
var _fade: ColorRect
var _main: Node = null
var _planked: Dictionary = {} # block id -> true (boards are up)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade()
	_wire_main()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _wire_main() -> void:
	# the suites drop main.tscn in after a frame; wait for the hero.
	# USER OVERRIDES R1/R2: the street adopts only ITS OWN scene (the
	# main.tscn root "Main") or the SafeBoot diagnostic - never the
	# warehouse start room, whose player must not drag blocks, crowds
	# and gates into a one-room scene. The poll runs until the real
	# street shows up (boot begins in the warehouse now).
	while true:
		await get_tree().process_frame
		var p := get_tree().get_first_node_in_group("player")
		if p and str(p.get_parent().name) in ["Main", "SafeBoot"]:
			_main = p.get_parent()
			break
	if not _main:
		return
	gate(Vector3(GATE_X, 1.0, 0.0), "market", "west")
	var interior := CLS_Interior.new()
	_main.add_child(interior)
	_wanderers("riverside")
	_decals("riverside")
	City.set_current_district("riverside")


func current() -> String:
	return _current


## USER OVERRIDES R1/R2: the street's rules end at the street scene.
## True only when the hero currently lives under the latched street
## main - false in the warehouse start room (and while no street is
## up). The player's world fence asks this before clamping.
func hero_on_street() -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and _main.is_ancestor_of(p)


## B20 (the hot-street fix): the crowd answers the MOOD, not just the
## travel - a district that turns hostile empties while you stand in it.
var _mood_watch_t := 0.0
var _last_mood := ""


func _process(delta: float) -> void:
	_mood_watch_t += delta
	if _mood_watch_t < 1.2:
		return
	_mood_watch_t = 0.0
	if _main == null:
		return
	var m := City.mood_of(_current)
	if m != _last_mood:
		_last_mood = m
		_wanderers(_current)


func block_node(id: String) -> Node:
	return _built.get(id)


## Which block a friend calls home (the bible places them: the Brother
## and The Drunk on your block - the bar; the Mechanic's garage and the
## club in the club quarter).
const FRIEND_HOMES := {
	"brother": "riverside", "drunk": "riverside",
	"mechanic": "market", "club_owner": "market",
}


# --- the walk between blocks -------------------------------------------------


func travel(to: String, enter_from: String) -> void:
	if _fading or to == _current or not BLOCK_X.has(to):
		return
	_fading = true
	InputBus.locked = true
	InputBus.clear_queues()
	await fade_out()
	# build lazily - the block exists the first time you walk into it
	_ensure(to)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		# land well clear of the wall furniture - a depenetration shove
		# at the wall must never push the hero back INTO the gate box
		# (the enter-event would never re-fire)
		var side := -1.0 if enter_from == "west" else 1.0
		p.global_position = Vector3(
			BLOCK_X[to] + side * (GATE_X - 2.6), 0.02, 0.0)
		p.velocity = Vector3.ZERO
		snap_camera_to(p)
	_current = to
	City.set_current_district(to)
	# boards and scars arrive with you
	_decals(to)
	# B23: autosave on arrival - the phone player never loses more
	# than one block transition (a save costs one small JSON write)
	SaveGame.save_all()
	_planks_if_hostile(to)
	_wanderers(to)
	await fade_in()
	InputBus.locked = false
	_fading = false
	Log.info("Blocks: walked into %s" % to)


## Fades shared with the interiors (bible 6: separate, through a fade).
func fade_out() -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)  # a UI fade is real-time, world crawls
	tw.tween_property(_fade, "color:a", 1.0, FADE_S)
	await tw.finished


func fade_in() -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_fade, "color:a", 0.0, FADE_S)
	await tw.finished


## Park the camera behind the hero so a block walk never swoops 200m.
func snap_camera_to(p: Node3D) -> void:
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	if cam:
		cam.global_position = Vector3(p.global_position.x - 6.0, 7.0,
				p.global_position.z + 8.0)


func gate(pos: Vector3, to: String, enter_from: String) -> void:
	var a := Area3D.new()
	a.name = "GateTo_" + to
	a.position = pos
	a.add_to_group("block_gate")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 3.0, 14.0)
	col.shape = shape
	a.add_child(col)
	_main.add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player") and not _fading:
			travel(to, enter_from))


func _ensure(id: String) -> void:
	if _built.has(id) or id == "riverside":
		return
	var b := CLS_BlockBuilder.new()
	b.name = "Block_" + id
	b.block_id = id
	b.position = Vector3(BLOCK_X[id], 0.0, 0.0)
	_main.add_child(b)
	b.build_block()
	_built[id] = b
	# B19 batch 9: the market block carries its venues - the gym, the
	# bar and the club, each enterable through its street door
	if id == "market" and not _venues_built:
		_venues_built = true
		for venue_script in ["res://scripts/gym_interior.gd",
				"res://scripts/bar_interior.gd",
				"res://scripts/club_interior.gd"]:
			var venue: Node3D = (load(venue_script) as GDScript).new()
			_main.add_child(venue)


var _venues_built := false


# --- the scars a block carries (bible 6: damage layer, memorials) ----------


## Violence answers in scars: a dark scorch where bodies dropped, and
## where the hero died, a small candle cluster. Positions are LOCAL to
## the block so they survive the walk and the save.
func _decals(id: String) -> void:
	var root: Node = _main if id == "riverside" else _built.get(id)
	if not root:
		return
	# scars accumulate between visits: rebuild the dress from what the
	# city remembers, never freeze at the first one
	var old_scars := root.get_node_or_null("Scars")
	if old_scars:
		old_scars.queue_free()
	var scars := Node3D.new()
	scars.name = "Scars"
	root.add_child(scars)
	for pt in City.damage_points(id):
		_scorch(scars, pt)
	for pt in City.death_points(id):
		_memorial(scars, pt)


func _scorch(parent: Node3D, local: Vector3) -> void:
	var q := MeshInstance3D.new()
	q.add_to_group("decal")
	var m := QuadMesh.new()
	m.size = Vector2(1.6, 2.2) if randf() < 0.5 else Vector2(2.0, 1.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	q.mesh = m
	q.position = local + Vector3(0, 0.03, 0)
	q.rotation = Vector3(-PI / 2.0, 0.0, randf() * PI)
	parent.add_child(q)


func _memorial(parent: Node3D, local: Vector3) -> void:
	var g := Node3D.new()
	g.add_to_group("memorial")
	g.position = local
	parent.add_child(g)
	for i in 3:
		var c := MeshInstance3D.new()
		var m := QuadMesh.new()
		m.size = Vector2(0.08, 0.22)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.75, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.2)
		mat.emission_energy_multiplier = 2.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material = mat
		c.mesh = m
		c.position = Vector3((i - 1) * 0.16, 0.12, 0.0)
		c.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		g.add_child(c)
	var note := Label3D.new()
	note.text = "someone died here"
	note.modulate = Color(0.8, 0.75, 0.6, 0.8)
	note.font_size = 34
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position = Vector3(0, 1.1, 0)
	g.add_child(note)


## A hostile block boards its shop fronts (bible 6: damage layer);
## a hollow one closes its doors too (bible 4I: doors close).
func _planks_if_hostile(id: String) -> void:
	var root: Node = _main if id == "riverside" else _built.get(id)
	if not root or _planked.get(id, false):
		return
	var mood := City.mood_of(id)
	if not ["hostile", "turning hostile", "wary"].has(mood):
		return
	_planked[id] = true
	for shop in get_tree().get_nodes_in_group("shopfront"):
		if not shop.is_inside_tree():
			continue
		var sp: Vector3 = (shop as Node3D).global_position
		if absf(sp.x - BLOCK_X[id]) <= 22.0:
			var plank := MeshInstance3D.new()
			plank.add_to_group("plank")
			var m := BoxMesh.new()
			m.size = Vector3(2.6, 0.22, 0.06)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.35, 0.26, 0.15)
			m.material = mat
			plank.mesh = m
			# plank.position is LOCAL to the block root (which sits at
			# BLOCK_X) - shop.position is the same frame; using the
			# global here doubled the offset and threw planks a whole
			# block over on market/foundry
			plank.position = (shop as Node3D).position + shop.get_meta(
					"plank_off", Vector3(0, 0.6, 0.3))
			plank.rotation = shop.rotation
			root.add_child(plank)


# --- the crowd (thins with the mood; bible 6 + B19 living city) ------------------

## B19: district densities - the commercial street busy, the
## residential one calm, the docks working. Halved on the LOW tier;
## hostile streets empty; friendly streets gain a few.
const CROWD_DENSITY := {"riverside": 6, "market": 10, "foundry": 4}


func _wanderers(id: String) -> void:
	var root: Node = _main if id == "riverside" else _built.get(id)
	if not root:
		return
	var mood := City.mood_of(id)
	var n: int = CROWD_DENSITY.get(id, 5)
	if mood in ["your street", "friendly"]:
		n += 2
	elif mood in ["hostile", "turning hostile"]:
		n = 0  # nobody walks a hot street
	if Quality != null and Quality.tier == Quality.LOW:
		n /= 2
	var crowd := root.get_node_or_null("Crowd") as Node
	if crowd == null:
		crowd = Node3D.new()
		crowd.name = "Crowd"
		root.add_child(crowd)
	# crowds thin with the mood (bible 6): count the living, then
	# free the surplus or spawn the difference
	# a hot street empties COMPLETELY (walkers and queue alike)
	if n == 0:
		for c in crowd.get_children():
			(c as Node).queue_free()
		Log.info("Blocks: %s thins - nobody walks a hot street" % id)
		return
	var alive: Array = []
	for c in crowd.get_children():
		var slot = (c as Node).get("queue_slot")
		var in_queue: bool = slot != null and slot != Vector3.ZERO
		if not c.is_queued_for_deletion() and not in_queue:
			alive.append(c)
	while alive.size() > n:
		(alive.pop_back() as Node).queue_free()
		Log.info("Blocks: %s thins - nobody walks a hot street" % id)
	var missing := n - alive.size()
	var i := 0
	while i < missing:
		var w := CLS_Wanderer.new()
		w.block = id
		var side := -1.0 if randf() < 0.5 else 1.0
		w.home = Vector3(BLOCK_X[id] + randf_range(-16.0, 16.0), 0.0,
				side * randf_range(9.0, 10.0))
		crowd.add_child(w)
		w.spawn()
		# pairs: every third spawn walks with a partner
		if i + 1 < missing and i % 3 == 2:
			var b := CLS_Wanderer.new()
			b.block = id
			b.home = w.home + Vector3(0.9, 0.0, 0.0)
			crowd.add_child(b)
			b.spawn()
			w.partner = b
			b.partner = w
			i += 1
		i += 1
	# the market's club queue (bible 6: the VELVET ROOM front) - a short
	# line that shuffles and drifts back to the street
	if id == "market" and n > 0:
		var queued := 0
		for c in crowd.get_children():
			var slot = (c as Node).get("queue_slot")
			if not c.is_queued_for_deletion() \
					and slot != null and slot != Vector3.ZERO:
				queued += 1
		for qi in range(queued, 3):
			var q := CLS_Wanderer.new()
			q.block = id
			q.queue_slot = Vector3(BLOCK_X[id] - 12.0 + qi * 0.85, 0.0, -10.2)
			q.home = q.queue_slot
			crowd.add_child(q)
			q.spawn()
