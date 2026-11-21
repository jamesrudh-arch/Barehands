extends Control
const CLS_Enemy := preload("res://scripts/enemy.gd")
const CLS_MapData := preload("res://scripts/map_data.gd")
const CLS_FullMap := preload("res://scripts/full_map.gd")

## LEVERAGE B18 (Part 6B): the round radar. Top-LEFT, below the DBG and
## pause buttons, inside the safe area (bottom-left is the joystick,
## bottom-right is the attack cluster). Rotates with the camera heading
## so "up" is where you look (a setting switches to north-up), a small N
## marker rides the rim, the hero is the centre arrow, and the yellow
## route line follows the streets to the objective or the pinned
## waypoint. A tap opens the full map. Pure 2D: one Control, one draw
## pass, world-to-radar transform, markers collected at 10 Hz, the
## route recalculated at most twice a second.

const RANGE_M := 42.0          # metres across the radar's radius
const REFRESH := 0.1           # 10 Hz marker refresh
const ROUTE_REFRESH := 0.5     # route recalcs at most 2 Hz

var _hero: CharacterBody3D
var _cam: Camera3D
var _acc := 0.0
var _route_acc := 0.0
var _route: PackedVector2Array = PackedVector2Array()
var _route_target := Vector2.INF
var _blips: Array = []             # [{pos:Vector2, kind:String, dy:float}]
var _banner_t := 0.0
var _banner_text := ""
var _district_label: Label
var _obj_label: Label

# facts the device report reads (filled during the 10 Hz refresh)
var blips_drawn := 0
var last_scale := 0.0
var rotating := true


func _ready() -> void:
	add_to_group("radar")
	mouse_filter = Control.MOUSE_FILTER_STOP
	CLS_MapData.load_fog()
	City.entered_district.connect(_on_district)
	Settings.changed.connect(_on_setting)
	get_viewport().size_changed.connect(_layout)
	_build_labels()
	_layout()
	_on_setting("radar_on")
	# the hero and camera arrive with the scene; re-grab until they exist
	call_deferred("_grab_refs")


func _grab_refs() -> void:
	_hero = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_cam = get_tree().get_first_node_in_group("camera") as Camera3D


func _on_setting(key: String) -> void:
	if key == "radar_on" or key == "radar_scale":
		_layout()
		visible = bool(Settings.value("radar_on"))


func _on_district(d: String, _mood: String) -> void:
	_banner_text = City.BLOCK_INFO.get(d, {}).get("name", d.to_upper())
	_banner_t = 2.6
	CLS_MapData.mark_block_seen(d)


# --- layout ------------------------------------------------------------------


## The radar sits top-left, below the DBG/pause row, inside the safe
## area. Size: ~20% of the visible height (18-22%), adjustable.
func _layout() -> void:
	var safe := _safe_rect()
	var vr := get_viewport().get_visible_rect()
	var h: float = clampf(vr.size.y * 0.20 * float(Settings.value("radar_scale")),
			96.0, vr.size.y * 0.30)
	size = Vector2(h, h)
	position = Vector2(safe.position.x + 12.0, safe.position.y + 56.0)
	# never let the radar wander outside the safe area
	position.x = minf(position.x, safe.end.x - h)
	position.y = minf(position.y, safe.end.y - h)
	if _district_label:
		_district_label.position = Vector2(0, h + 26)
		_obj_label.position = Vector2(0, h + 46)


func _safe_rect() -> Rect2:
	var ft := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = ft * Rect2(DisplayServer.get_display_safe_area())
	safe = safe.intersection(get_viewport().get_visible_rect())
	if safe.size.x < 8.0 or safe.size.y < 8.0:
		return get_viewport().get_visible_rect()  # headless degenerate
	return safe


func _build_labels() -> void:
	_district_label = Label.new()
	_district_label.add_theme_font_size_override("font_size", 14)
	_district_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	_district_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_district_label)
	_obj_label = Label.new()
	_obj_label.add_theme_font_size_override("font_size", 12)
	_obj_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 0.95))
	_obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_obj_label)


# --- input: a tap opens the full map -------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _inside_circle(event.position):
			_open_map()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _inside_circle(event.position):
			_open_map()


func _inside_circle(p: Vector2) -> bool:
	return p.distance_to(size * 0.5) <= size.x * 0.5


func _open_map() -> void:
	if InputBus.locked and not get_tree().paused:
		return  # mid-cinematic / mid-call: the map can wait
	var map := get_tree().get_first_node_in_group("full_map")
	if map and map.has_method("open"):
		map.call("open", "radar")


# --- the 10 Hz refresh ----------------------------------------------------------


func _process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_grab_refs()
	_acc += delta
	if _acc >= REFRESH:
		_acc = 0.0
		_refresh()
	_route_acc += delta
	if _route_acc >= ROUTE_REFRESH:
		_route_acc = 0.0
		_refresh_route(false)
	if _banner_t > 0.0:
		_banner_t = maxf(0.0, _banner_t - delta)
		_district_label.text = _banner_text
		_district_label.modulate.a = clampf(_banner_t, 0.0, 1.0)
	elif not _district_label.text.is_empty():
		_district_label.text = ""
	queue_redraw()


func _refresh() -> void:
	if _hero == null:
		return
	rotating = not bool(Settings.value("radar_north_up"))
	var hero_xz := Vector2(_hero.global_position.x, _hero.global_position.z)
	CLS_MapData.poll_discovery(hero_xz)
	_blips.clear()
	# friends: the cast NPCs the phone knows (blue)
	for n in get_tree().get_nodes_in_group("cast_npc"):
		if n is Node3D:
			_blips.append({"pos": Vector2((n as Node3D).global_position.x,
					(n as Node3D).global_position.z),
					"kind": "friend", "dy": 0.0})
	# enemies: near, standing (red, only when they matter)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.get("state") != CLS_Enemy.State.DOWN:
			var ep: Vector3 = (e as Node3D).global_position
			if Vector2(ep.x, ep.z).distance_to(hero_xz) < RANGE_M:
				_blips.append({"pos": Vector2(ep.x, ep.z), "kind": "enemy",
						"dy": ep.y - _hero.global_position.y})
	# the objective + waypoint
	var nav: Dictionary = CLS_MapData.nav_target()
	if not nav.is_empty():
		_blips.append({"pos": nav["pos"], "kind": "objective", "dy": 0.0})
	if CLS_MapData.has_waypoint():
		_blips.append({"pos": CLS_MapData.waypoint(), "kind": "waypoint",
				"dy": 0.0})
	blips_drawn = _blips.size()
	# the objective line under the disc
	if not nav.is_empty():
		var d: float = (nav["pos"] as Vector2).distance_to(hero_xz)
		var text: String = str(nav.get("text", ""))
		if text.length() > 42:
			text = text.substr(0, 40) + "..."
		_obj_label.text = "%s  %d m" % [text, int(round(d))]
	else:
		_obj_label.text = "no objective - pin a waypoint on the map"


func _refresh_route(force: bool) -> void:
	if _hero == null:
		return
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		_route = PackedVector2Array()
		_route_target = Vector2.INF
		return
	var target: Vector2 = nav["pos"]
	var hero_xz := Vector2(_hero.global_position.x, _hero.global_position.z)
	var moved_target := _route_target == Vector2.INF \
			or target.distance_to(_route_target) > 1.0
	var off := not _route.is_empty() and not CLS_MapData.on_route(hero_xz, _route)
	if force or moved_target or off or _route.is_empty():
		_route = CLS_MapData.route(hero_xz, target)
		_route_target = target


# --- the draw pass --------------------------------------------------------------


func _world_to_radar(v: Vector2, hero_xz: Vector2) -> Vector2:
	var rel := v - hero_xz
	if rotating and _cam != null:
		rel = rel.rotated(InputBus.camera_yaw)
	return size * 0.5 + rel * last_scale


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	last_scale = r / RANGE_M
	if _hero == null:
		return
	var hero_xz := Vector2(_hero.global_position.x, _hero.global_position.z)
	# the dish
	draw_circle(c, r, Color(0.015, 0.02, 0.035, 0.78))
	draw_arc(c, r, 0.0, TAU, 64, Color(0.35, 0.8, 0.8, 0.55), 2.0, true)
	draw_arc(c, r * 0.55, 0.0, TAU, 48, Color(0.5, 0.8, 0.85, 0.10), 1.0, true)
	# streets + block outlines + water, clipped to the disc
	_draw_map_geo(c, r, hero_xz)
	# the route line (bright, objective-yellow)
	if _route.size() >= 2:
		for i in range(_route.size() - 1):
			var a := _world_to_radar(_route[i], hero_xz)
			var b := _world_to_radar(_route[i + 1], hero_xz)
			var seg := _clip_seg(a, b, c, r - 4.0)
			if seg.size() == 2:
				draw_line(seg[0], seg[1], Color(1.0, 0.85, 0.2, 0.9), 3.0, true)
	# POI icons (dim) - interiors only once discovered
	for poi in CLS_MapData.poi_list():
		if poi.get("interior", false) and not CLS_MapData.is_discovered(poi["id"]):
			continue
		var p := _world_to_radar(poi["pos"], hero_xz)
		var cl := _clamp_rim(p, c, r - 10.0)
		if cl == p:
			draw_circle(p, 2.6, Color(0.65, 0.8, 0.9, 0.55))
	# blips
	for b in _blips:
		_draw_blip(b, c, r, hero_xz)
	# the hero arrow: the centre, pointing where the hero faces
	var fwd := Vector2.ZERO
	if _hero is Node3D:
		var f: Vector3 = -(_hero as Node3D).global_transform.basis.z
		fwd = Vector2(f.x, f.z)
		if rotating:
			fwd = fwd.rotated(InputBus.camera_yaw)
	_draw_arrow(c, fwd.normalized() if fwd.length() > 0.01 else Vector2.UP,
			Color(0.4, 1.0, 0.9, 0.95))
	# the N marker on the rim
	var north := Vector2(0.0, -1.0)
	if rotating:
		north = Vector2(0.0, -1.0).rotated(InputBus.camera_yaw)
	var np := c + north * (r - 12.0)
	var font := get_theme_default_font()
	draw_string(font, np + Vector2(-4, 5), "N", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13, Color(0.75, 0.95, 1.0, 0.9))
	# the compass: a strip at the top-centre of the screen (the control
	# draws outside its own rect; clipping is off by default)
	var vr := get_viewport().get_visible_rect()
	_draw_compass(Vector2(vr.size.x * 0.5 - position.x, 20.0 - position.y))


func _draw_compass(c: Vector2) -> void:
	if _hero == null or not visible:
		return
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		return
	var target: Vector2 = nav["pos"]
	var hero_xz := Vector2(_hero.global_position.x, _hero.global_position.z)
	var d := Vector2(target.x - hero_xz.x, target.y - hero_xz.y)
	if rotating and _cam != null:
		d = d.rotated(InputBus.camera_yaw)
	var ang := atan2(d.x, -d.y)
	draw_circle(c, 3.0, Color(1.0, 0.85, 0.2, 0.9))
	var tip := c + Vector2(sin(ang), -cos(ang)) * 13.0
	draw_line(c, tip, Color(1.0, 0.85, 0.2, 0.9), 2.5, true)
	var font := get_theme_default_font()
	var dist: float = target.distance_to(hero_xz)
	draw_string(font, c + Vector2(14, 5), "%d m" % int(round(dist)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.45, 0.95))


func _draw_map_geo(c: Vector2, r: float, hero_xz: Vector2) -> void:
	# street + outline segments per block (only blocks near the disc)
	for block in CLS_MapData.BLOCK_RECTS:
		var rect: Rect2 = CLS_MapData.BLOCK_RECTS[block]
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
		var seen := CLS_MapData.block_seen(block)
		var edge := Color(0.45, 0.55, 0.75, 0.4 if seen else 0.18)
		for i in range(4):
			var a := _world_to_radar(corners[i], hero_xz)
			var b := _world_to_radar(corners[i + 1], hero_xz)
			var seg := _clip_seg(a, b, c, r - 2.0)
			if seg.size() == 2:
				draw_line(seg[0], seg[1], edge, 1.5, true)
		# the main street through the block
		var y: float = rect.get_center().y
		var a2 := _world_to_radar(Vector2(rect.position.x + 2.0, y), hero_xz)
		var b2 := _world_to_radar(Vector2(rect.end.x - 2.0, y), hero_xz)
		var seg2 := _clip_seg(a2, b2, c, r - 2.0)
		if seg2.size() == 2:
			draw_line(seg2[0], seg2[1], Color(0.6, 0.65, 0.75, 0.5), 4.0, true)
	# water at the docks
	var wr: Rect2 = CLS_MapData.WATER_RECT
	var wa := _world_to_radar(wr.position, hero_xz)
	var wb := _world_to_radar(wr.end, hero_xz)
	var rect2 := Rect2(minf(wa.x, wb.x), minf(wa.y, wb.y),
			absf(wb.x - wa.x), absf(wb.y - wa.y))
	rect2 = rect2.intersection(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)))
	if rect2.size.x > 2.0 and rect2.size.y > 2.0:
		draw_rect(rect2, Color(0.15, 0.3, 0.55, 0.5))


func _draw_blip(b: Dictionary, c: Vector2, r: float, hero_xz: Vector2) -> void:
	var p := _world_to_radar(b["pos"], hero_xz)
	var inside := p.distance_to(c) <= r - 10.0
	var col := Color.WHITE
	match b["kind"]:
		"friend":
			col = Color(0.3, 0.6, 1.0, 0.95)
		"enemy":
			col = Color(1.0, 0.25, 0.2, 0.95)
		"objective":
			col = Color(1.0, 0.85, 0.2, 1.0)
		"waypoint":
			col = Color(1.0, 0.3, 0.85, 1.0)
	if inside:
		if b["kind"] == "objective":
			draw_arc(p, 6.0, 0.0, TAU, 24, col, 2.5, true)
		elif b["kind"] == "waypoint":
			_draw_pin(p, col)
		else:
			draw_circle(p, 3.4, col)
			var dy: float = b.get("dy", 0.0)
			if dy > 2.0:
				_draw_tri(p + Vector2(0, -9), true, col)
			elif dy < -2.0:
				_draw_tri(p + Vector2(0, 9), false, col)
	else:
		# off-radar: clamp to the rim, chevron pointing outward
		var dir := (p - c).normalized()
		var rim := c + dir * (r - 9.0)
		draw_circle(rim, 3.2, col)
		_draw_chevron(rim, dir, col)


func _draw_pin(p: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, 6), p + Vector2(-5, -3),
			p + Vector2(5, -3)])
	draw_colored_polygon(pts, col)
	draw_circle(p + Vector2(0, -3), 2.0, Color(1, 1, 1, 0.8))


func _draw_tri(p: Vector2, up: bool, col: Color) -> void:
	var s := 4.0
	var pts: PackedVector2Array
	if up:
		pts = PackedVector2Array([p + Vector2(0, -s), p + Vector2(-s, s),
				p + Vector2(s, s)])
	else:
		pts = PackedVector2Array([p + Vector2(0, s), p + Vector2(-s, -s),
				p + Vector2(s, -s)])
	draw_colored_polygon(pts, col)


func _draw_chevron(p: Vector2, dir: Vector2, col: Color) -> void:
	var perp := Vector2(-dir.y, dir.x) * 5.0
	draw_line(p + perp, p + dir * 6.0, col, 2.5, true)
	draw_line(p - perp, p + dir * 6.0, col, 2.5, true)


func _draw_arrow(p: Vector2, dir: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([p + dir * 9.0,
			p + dir.rotated(2.4) * 7.0, p + dir.rotated(-2.4) * 7.0])
	draw_colored_polygon(pts, col)
	draw_arc(p, 11.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.35), 1.5, true)


# --- geometry helpers ------------------------------------------------------------


## Clip a segment to a disc; returns [] or the two clipped endpoints.
func _clip_seg(a: Vector2, b: Vector2, c: Vector2, r: float) -> PackedVector2Array:
	var da := a - c
	var db := b - c
	var in_a := da.length() <= r
	var in_b := db.length() <= r
	if in_a and in_b:
		return PackedVector2Array([a, b])
	if not in_a and not in_b:
		return PackedVector2Array()  # both outside: the chord test below is enough for a street map
	var hits := PackedVector2Array()
	for pair in [[a, b], [b, a]]:
		var p: Vector2 = pair[0]
		var q: Vector2 = pair[1]
		var dir := q - p
		var ql: float = dir.length()
		if ql < 0.001:
			continue
		dir /= ql
		var oc := p - c
		var bb := oc.dot(dir)
		var cc := oc.length_squared() - r * r
		var disc := bb * bb - cc
		if disc < 0.0:
			continue
		var t := -bb - sqrt(disc)
		if t >= 0.0 and t <= ql:
			hits.append(p + dir * t)
	var out := PackedVector2Array()
	if in_a:
		out.append(a)
	out.append_array(hits)
	if in_b:
		out.append(b)
	if out.size() >= 2:
		return PackedVector2Array([out[0], out[out.size() - 1]])
	return PackedVector2Array()


func _clamp_rim(p: Vector2, c: Vector2, r: float) -> Vector2:
	var d := p - c
	var l := d.length()
	if l <= r or l < 0.001:
		return p
	return c + d / l * r


## Tests reach in here: force a route recalculation now.
func debug_recalc_route() -> void:
	_refresh_route(true)
