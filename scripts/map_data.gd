extends RefCounted
const CLS_Jobs := preload("res://scripts/jobs.gd")

## LEVERAGE B18 (Part 6B): the one place the map knows the world. Static
## on purpose - NO new autoload (the boot census stays at 33 and Stage 0
## keeps its guarantees); every consumer preloads this script and calls
## the statics. Holds:
##   - the three blocks' world rectangles + names (City.BLOCK_INFO)
##   - the street graph the route runs on (AStar2D, built once)
##   - POIs (shops, clubs, gym, garage, warehouse, underpass, doors)
##   - the five interior icons and their fog-of-war state
##   - the waypoint (set from the full map, read by radar + 3D marker)
##   - ROUTE FINDING: street-following paths from any world position to
##     any other, recalculated by the caller at a low rate.
## No fast travel lives here or anywhere - the streets are the travel.

# --- the blocks (world rects; blocks 2 and 3 are code-built at BLOCK_X) ----

const BLOCK_RECTS := {
	"riverside": Rect2(-22.0, -20.0, 44.0, 40.0),
	"market": Rect2(218.0, -20.0, 44.0, 40.0),
	"foundry": Rect2(458.0, -20.0, 44.0, 40.0),
}

const BLOCK_CENTRES := {
	"riverside": Vector2(0.0, 0.0),
	"market": Vector2(240.0, 0.0),
	"foundry": Vector2(480.0, 0.0),
}

const WATER_RECT := Rect2(500.0, -30.0, 44.0, 60.0)  # the docks, east of the rail

## The underpass link the bible digs between the market and foundry ends
## (the walk is a gate + fade; the map draws the honest link line).
const UNDERPASS := {
	"a": Vector2(259.0, 0.0),
	"b": Vector2(463.5, 0.0),
}

# --- POIs: everything the radar and map draw an icon for --------------------
# kind: shop | club | gym | garage | warehouse | door | noodle | underpass
# interior: true for the five interior icons (fog-of-war hides them)

const POIS := [
	{"id": "noodle", "label": "NOODLES", "kind": "noodle", "interior": true,
		"pos": Vector2(-4.0, 8.2), "district": "riverside"},
	{"id": "safehouse", "label": "SAFEHOUSE", "kind": "door", "interior": true,
		"pos": Vector2(-2.0, 8.9), "district": "riverside"},
	{"id": "tailor", "label": "TAILOR", "kind": "shop",
		"pos": Vector2(-12.0, -8.2), "district": "riverside"},
	{"id": "gear", "label": "GEAR", "kind": "shop",
		"pos": Vector2(4.5, 8.2), "district": "riverside"},
	{"id": "pawn", "label": "PAWN", "kind": "shop",
		"pos": Vector2(12.8, 3.6), "district": "riverside"},
	{"id": "gym", "label": "IRON PALM GYM", "kind": "gym", "interior": true,
		"pos": Vector2(240.0 - 6.5, 9.6), "district": "market"},
	{"id": "mechanic", "label": "MECHANIC", "kind": "garage", "interior": true,
		"pos": Vector2(240.0 + 3.5, 9.6), "district": "market"},
	{"id": "velvet", "label": "THE VELVET ROOM", "kind": "club", "interior": true,
		"pos": Vector2(240.0 - 9.0, -9.6), "district": "market"},
	{"id": "neon9", "label": "NEON 9", "kind": "club",
		"pos": Vector2(240.0 + 0.5, -9.6), "district": "market"},
	{"id": "palace", "label": "PALACE", "kind": "club",
		"pos": Vector2(240.0 + 8.5, -9.6), "district": "market"},
	{"id": "warehouse", "label": "MERIDIAN FREIGHT", "kind": "warehouse",
		"pos": Vector2(480.0 + 2.0, -13.0), "district": "foundry"},
	{"id": "underpass_w", "label": "UNDERPASS", "kind": "underpass",
		"pos": UNDERPASS["a"], "district": "market"},
	{"id": "underpass_e", "label": "UNDERPASS", "kind": "underpass",
		"pos": UNDERPASS["b"], "district": "foundry"},
]

## Main street names for the full map (the x-axis street runs through
## all three blocks; the shop rows are the north/south walks).
const STREET_NAMES := [
	{"text": "CINDER ROW", "from": Vector2(-18.0, 0.0), "to": Vector2(18.0, 0.0)},
	{"text": "CLUB STREET", "from": Vector2(222.0, 0.0), "to": Vector2(258.0, 0.0)},
	{"text": "DOCK ROAD", "from": Vector2(462.0, 0.0), "to": Vector2(498.0, 0.0)},
]

# --- state (session; fog persists through Settings hints) --------------------

## Statics cannot rely on the autoload global names; route through the
## scene tree root so every caller context works (game, SafeBoot, tests).

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _settings() -> Node:
	var t := _tree()
	return t.root.get_node_or_null("/root/Settings") if t else null


static func _log(msg: String) -> void:
	var t := _tree()
	if t and t.root:
		var lg := t.root.get_node_or_null("/root/Log")
		if lg:
			lg.call("info", msg)


# --- B32: interior floor plans for the map's inside view ---------------------
# Local coords match each room's own node (world = room_x + local).
# door = the EXIT zone's wall position (local XZ); street = the street
# door zone (world XZ) the map pins the hero at while inside; features
# carry one glyph each. Sizes read from each room's built floor shell.
const INTERIOR_ROOMS := [
	{"id": "noodle", "room_x": 720.0, "w": 10.0, "d": 9.0,
		"door": Vector2(0.0, 3.6), "street": Vector2(-4.0, 6.4),
		"label": "MAMA SUN'S NOODLES",
		"features": [{"p": Vector2(0.0, -3.4), "g": "C"}]},  # the counter
	{"id": "safehouse", "room_x": 780.0, "w": 7.0, "d": 7.0,
		"door": Vector2(0.0, -3.2), "street": Vector2(-2.0, 8.9),
		"label": "YOUR ROOM",
		"features": [{"p": Vector2(2.2, -2.0), "g": "B"}]},  # the bed
	{"id": "gym", "room_x": 840.0, "w": 10.0, "d": 8.0,
		"door": Vector2(0.0, 3.4), "street": Vector2(233.5, 10.2),
		"label": "IRON PALM GYM",
		"features": [{"p": Vector2(0.0, -1.5), "g": "R"}]},  # the ring
	{"id": "bar", "room_x": 900.0, "w": 9.0, "d": 7.0,
		"door": Vector2(0.0, 3.4), "street": Vector2(238.8, 10.2),
		"label": "THE KNUCKLE ROOM",
		"features": [{"p": Vector2(0.0, -2.2), "g": "A"}]},  # the bar
	{"id": "velvet", "room_x": 960.0, "w": 10.0, "d": 8.0,
		"door": Vector2(0.0, 3.4), "street": Vector2(231.0, -10.2),
		"label": "THE VELVET ROOM",
		"features": [{"p": Vector2(0.0, 0.0), "g": "D"}]},  # the dance floor
]


## The room the given world X sits inside (rooms sit off the axis,
## each on its own room_x), or {} when the position is on the street.
static func inside(world_x: float) -> Dictionary:
	for room in INTERIOR_ROOMS:
		if absf(world_x - float(room["room_x"])) < float(room["w"]) * 0.5 + 2.0:
			return room
	return {}


## The player's local position inside a room (XZ, node-local).
static func local_in_room(world_pos: Vector3, room: Dictionary) -> Vector2:
	return Vector2(world_pos.x - float(room["room_x"]), world_pos.z)


## Waypoint the player pinned on the full map (world XZ); null = none.
static var _waypoint: Vector2 = Vector2.INF
## Discovered POI ids (interiors + shortcuts stay hidden until found).
static var _discovered: Dictionary = {}
## Discovered districts (block outlines show dimmed until walked).
static var _seen_blocks: Dictionary = {}

static var _astar: AStar2D = null
static var _node_ids: Dictionary = {}  # "x,z" -> point id


static func has_waypoint() -> bool:
	return _waypoint != Vector2.INF


static func waypoint() -> Vector2:
	return _waypoint


static func set_waypoint(xz: Vector2) -> void:
	_waypoint = Vector2(clampf(xz.x, -22.0, 524.0), clampf(xz.y, -20.0, 20.0))
	_log("Map: waypoint set at %s" % _waypoint)


static func clear_waypoint() -> void:
	_waypoint = Vector2.INF


static func discover(id: String) -> void:
	if not _discovered.has(id):
		_discovered[id] = true
		_log("Map: discovered %s" % id)


static func is_discovered(id: String) -> bool:
	return _discovered.has(id)


static func mark_block_seen(d: String) -> void:
	_seen_blocks[d] = true


static func block_seen(d: String) -> bool:
	return _seen_blocks.get(d, d == "riverside")


## Load the persisted fog from the settings' hint store (once, from the
## radar's _ready; hints survive restarts by design).
static func load_fog() -> void:
	for poi in POIS:
		if Settings.hint_done("map_poi_" + poi["id"]):
			_discovered[poi["id"]] = true
	for d in BLOCK_RECTS:
		if Settings.hint_done("map_block_" + d):
			_seen_blocks[d] = true
	_seen_blocks["riverside"] = true


static func _persist_poi(id: String) -> void:
	Settings.set_hint_done("map_poi_" + id)


static func _persist_block(d: String) -> void:
	Settings.set_hint_done("map_block_" + d)


## Called by the radar at 10 Hz with the hero's position: anything the
## hero stands next to (front doors, underpass mouths) counts as found.
static func poll_discovery(hero_xz: Vector2) -> void:
	for poi in POIS:
		var id: String = poi["id"]
		if _discovered.has(id):
			continue
		if (poi["pos"] as Vector2).distance_to(hero_xz) < 4.5:
			_discovered[id] = true
			_persist_poi(id)
			_log("Map: found %s" % poi["label"])
	var d := district_at_x(hero_xz.x)
	if not _seen_blocks.get(d, false):
		_seen_blocks[d] = true
		_persist_block(d)


static func district_at_x(x: float) -> String:
	if x < 120.0:
		return "riverside"
	if x < 360.0:
		return "market"
	return "foundry"


# --- the street graph + routes -----------------------------------------------


## Nodes: a 5x3 grid per block (x in {-19,-10,0,10,19} + block offset,
## z in {-9,0,9}) - street corners, not navmesh precision. Gates link
## the blocks; the underpass link is the market->foundry edge.
static func _build_graph() -> AStar2D:
	if _astar != null:
		return _astar
	var a := AStar2D.new()
	var xs := [-19.0, -10.0, 0.0, 10.0, 19.0]
	var zs := [-9.0, 0.0, 9.0]
	var next_id := 0
	for block in BLOCK_CENTRES:
		var bx: float = BLOCK_CENTRES[block].x
		for x in xs:
			for z in zs:
				var p := Vector2(bx + x, z)
				a.add_point(next_id, p)
				_node_ids["%d,%d" % [int(p.x), int(p.y)]] = next_id
				next_id += 1
	# edges: rows along x, columns along z (within one block)
	for block in BLOCK_CENTRES:
		var bx: float = BLOCK_CENTRES[block].x
		for z in zs:
			for i in range(xs.size() - 1):
				_connect(a, Vector2(bx + xs[i], z), Vector2(bx + xs[i + 1], z))
		for x in xs:
			for j in range(zs.size() - 1):
				_connect(a, Vector2(bx + x, zs[j]), Vector2(bx + x, zs[j + 1]))
	# gates: riverside -> market -> foundry (the underpass link)
	_connect(a, Vector2(19.0, 0.0), Vector2(240.0 - 19.0, 0.0))
	_connect(a, Vector2(240.0 + 19.0, 0.0), Vector2(480.0 - 19.0, 0.0))
	_astar = a
	return a


static func _connect(a: AStar2D, p: Vector2, q: Vector2) -> void:
	var ai := _node_ids.get("%d,%d" % [int(p.x), int(p.y)], -1) as int
	var bi := _node_ids.get("%d,%d" % [int(q.x), int(q.y)], -1) as int
	if ai >= 0 and bi >= 0:
		a.connect_points(ai, bi)


static func _nearest_node(a: AStar2D, p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for id in range(a.get_point_count()):
		var d: float = (a.get_point_position(id) - p).length_squared()
		if d < best_d:
			best_d = d
			best = id
	return best


## A street-following route from `from_xz` to `to_xz` (world XZ).
## Returns the path INCLUDING both endpoints; empty = no route (the
## graph failed, callers fall back to a straight line).
static func route(from_xz: Vector2, to_xz: Vector2) -> PackedVector2Array:
	var a := _build_graph()
	var s := _nearest_node(a, from_xz)
	var t := _nearest_node(a, to_xz)
	if s < 0 or t < 0:
		return PackedVector2Array()
	var ids: PackedVector2Array = a.get_point_path(s, t)
	if ids.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array()
	out.append(from_xz)
	for p in ids:
		if (p - from_xz).length() > 1.0 and (p - to_xz).length() > 1.0:
			out.append(p)
	out.append(to_xz)
	return out


## Route length in metres (for the device report).
static func route_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


## Is `xz` within ~4 m of any segment of `path`? (off-route detection)
static func on_route(xz: Vector2, path: PackedVector2Array) -> bool:
	for i in range(path.size() - 1):
		if _dist_to_seg(xz, path[i], path[i + 1]) < 4.0:
			return true
	return false


static func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t - p).length()


# --- what the radar and map ask for -------------------------------------------


## The active navigation target: the pinned waypoint first, then the
## live job objective. Returns {} or {text, pos (Vector2 XZ), district}.
static func nav_target() -> Dictionary:
	if has_waypoint():
		return {"text": "WAYPOINT", "pos": _waypoint,
			"district": district_at_x(_waypoint.x), "phase": "PIN"}
	var t := _tree()
	# the guided intro (B18 6C) outranks jobs: FIND THE DOOR and friends
	# point the radar, route, marker and sonar while it runs
	var guide: Node = t.get_first_node_in_group("guide") if t else null
	if guide and guide.has_method("current_target"):
		var gt: Dictionary = guide.call("current_target")
		if not gt.is_empty():
			return {"text": gt.get("text", ""), "pos": Vector2(
					gt["pos"].x, gt["pos"].z), "district": "", "phase": "INTRO"}
	var jobs: Node = t.root.get_node_or_null("/root/Jobs") if t else null
	if jobs and jobs.has_method("objective"):
		var o: Dictionary = jobs.call("objective")
		if not o.is_empty():
			return {"text": o.get("text", ""), "pos": Vector2(
					o["pos"].x, o["pos"].z), "district": o.get("district", ""),
			"phase": o.get("phase", "")}
	return {}


## Blips for the radar: friends (blue), enemies (red, near + not down),
## POIs (dim icons). Collected by the radar at 10 Hz.
static func poi_list() -> Array:
	return POIS
