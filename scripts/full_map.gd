extends CanvasLayer
const CLS_MapData := preload("res://scripts/map_data.gd")

## LEVERAGE B18 (Part 6B): the full map. Opens from a tap on the radar,
## the pause menu's MAP button and the PHONE's Map app (the device
## report counts each entry point). Draws all three blocks from
## MapData's world data through one 2D world-to-map transform - no
## second 3D camera, no SubViewport. Pan with one finger, zoom with a
## pinch (or the mouse wheel), tap to place or remove a waypoint
## (Set/Clear buttons too), the route line follows the streets, fog of
## war hides undiscovered interiors and the underpass, and layer
## toggles sit at the bottom. No fast travel - the streets are the
## travel.

const WORLD_MIN := Vector2(-34.0, -30.0)
const WORLD_MAX := Vector2(548.0, 30.0)

var _panel: Control
var _hint: Label
var _bottom: Label
var _legend: PanelContainer
var _cam_world := Vector2(257.0, 0.0)   # world point at screen centre
var _scale := 1.6                        # px per metre (world-to-map)
var _fit_scale := 1.6
var _pan := Vector2.ZERO
var _touch_cam := -1
var _touches: Dictionary = {}            # index -> position (pinch)
var _pinch_dist := 0.0
var _drag_last := Vector2.ZERO
var _dragged := 0.0
var _acc := 0.0
var _was_locked := false
var _route: PackedVector2Array = PackedVector2Array()
var _layers := {"jobs": true, "control": false, "heat": false,
		"friends": true, "damage": false}

# entry-point counters the device report reads
static var opened_radar := 0
static var opened_pause := 0
static var opened_phone := 0


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("full_map")
	_build()


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_map)
	add_child(_panel)

	_hint = Label.new()
	_hint.text = "drag to pan - pinch to zoom - tap the map to pin a waypoint"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_bottom = 26.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hint)

	_bottom = Label.new()
	_bottom.add_theme_font_size_override("font_size", 14)
	_bottom.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 0.95))
	_bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom.offset_top = -108.0
	_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_bottom)

	_build_buttons()
	_build_legend()


func _build_buttons() -> void:
	var safe := _safe_rect()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(safe.position.x + 10.0, safe.end.y - 56.0)
	_panel.add_child(row)
	_btn(row, "CLOSE", func(): close())
	_btn(row, "RECENTER", func(): _recentre())
	_btn(row, "SET WP HERE", func(): _set_wp_centre())
	_btn(row, "CLEAR WP", func():
		CLS_MapData.clear_waypoint()
		_refresh_route())
	_btn(row, "LEGEND", func(): _toggle_legend())
	for key in ["jobs", "control", "heat", "friends", "damage"]:
		var k: String = key
		_btn(row, k.to_upper(), func():
			_layers[k] = not _layers[k]
			_panel.queue_redraw())


func _btn(row: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.9)
	sb.border_color = Color(1, 0.58, 0.13, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(cb)
	row.add_child(b)


func _build_legend() -> void:
	_legend = PanelContainer.new()
	_legend.visible = false
	_legend.anchor_left = 1.0
	_legend.anchor_right = 1.0
	_legend.position = Vector2(-300.0, 60.0)
	_legend.custom_minimum_size = Vector2(290.0, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	sb.border_color = Color(0.2, 0.75, 0.7, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	_legend.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_legend)
	var col := VBoxContainer.new()
	_legend.add_child(col)
	var lines := [
		["green ring", "the objective (guide colour)"],
		["magenta pin", "your waypoint (tap to place/remove)"],
		["green line", "the guide's route along the streets"],
		["blue dot", "a friend"],
		["red dot", "an enemy that is standing"],
		["grey dot", "a shop or service"],
		["dashed line", "the underpass (found only)"],
		["dark blue", "the water at the docks"],
		["dim block", "a block you have not walked"],
	]
	for l in lines:
		var lab := Label.new()
		lab.text = "%s  -  %s" % [l[0], l[1]]
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.9))
		col.add_child(lab)


func _toggle_legend() -> void:
	_legend.visible = not _legend.visible


# --- open / close ---------------------------------------------------------------


func open(from: String) -> void:
	visible = true
	match from:
		"radar":
			opened_radar += 1
		"pause":
			opened_pause += 1
		"phone":
			opened_phone += 1
	# restore exactly what was there before, never force-unlock someone
	# else's lock (the phone call, a cutscene)
	_was_locked = InputBus.locked
	if not _was_locked and not get_tree().paused:
		InputBus.locked = true
	_recentre()
	_refresh_route()
	_refresh_bottom()


func close() -> void:
	visible = false
	_legend.visible = false
	if not _was_locked and not get_tree().paused:
		InputBus.locked = false


func _recentre() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		_cam_world = Vector2(p.global_position.x, p.global_position.z)
	else:
		_cam_world = (WORLD_MIN + WORLD_MAX) * 0.5
	var vr := _panel.size
	_fit_scale = minf((vr.x - 80.0) / (WORLD_MAX.x - WORLD_MIN.x),
			(vr.y - 160.0) / (WORLD_MAX.y - WORLD_MIN.y))
	_scale = maxf(_fit_scale, 1.2)
	_pan = Vector2.ZERO


func _set_wp_centre() -> void:
	CLS_MapData.set_waypoint(_cam_world)
	_refresh_route()
	_refresh_bottom()


# --- input: pan, pinch, tap-to-pin ----------------------------------------------


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_touch_cam = event.index
				_drag_last = event.position
				_dragged = 0.0
			elif _touches.size() == 2:
				var pts := _touches.values()
				_pinch_dist = (pts[0] as Vector2).distance_to(pts[1])
		else:
			_touches.erase(event.index)
			if event.index == _touch_cam:
				if _dragged < 12.0 and _touch_cam > -1:
					_tap(event.position)
				_touch_cam = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_cam and _touches.size() == 1:
			_pan += event.position - _drag_last
			_drag_last = event.position
			_dragged += event.relative.length()
			_panel.queue_redraw()
		if _touches.has(event.index):
			_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts := _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 1.0:
				_zoom_by(d / _pinch_dist)
			_pinch_dist = d
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_cam = 99
				_drag_last = event.position
				_dragged = 0.0
			else:
				if _dragged < 12.0:
					_tap(event.position)
				_touch_cam = -1
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.15)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(0.87)


func _zoom_by(factor: float) -> void:
	_scale = clampf(_scale * factor, _fit_scale * 0.6, _fit_scale * 8.0)
	_panel.queue_redraw()


## A clean tap on the map: place a waypoint there, or remove it if the
## pin itself was tapped.
func _tap(screen_pos: Vector2) -> void:
	if _over_button(screen_pos):
		return
	var world := _map_to_world(screen_pos)
	if CLS_MapData.has_waypoint() \
			and world.distance_to(CLS_MapData.waypoint()) < 12.0 / _scale:
		CLS_MapData.clear_waypoint()
	else:
		CLS_MapData.set_waypoint(world)
	_refresh_route()
	_refresh_bottom()
	_panel.queue_redraw()


func _over_button(p: Vector2) -> bool:
	for c in _panel.get_children():
		if c is BoxContainer and Rect2((c as Control).position,
				(c as Control).size).grow(8.0).has_point(p):
			return true
	return false


# --- the draw pass ----------------------------------------------------------------


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		_refresh_route()
		_refresh_bottom()
		_panel.queue_redraw()


func _refresh_route() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var nav: Dictionary = CLS_MapData.nav_target()
	if p == null or nav.is_empty():
		_route = PackedVector2Array()
		return
	_route = CLS_MapData.route(Vector2(p.global_position.x, p.global_position.z),
			nav["pos"])


func _refresh_bottom() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		_bottom.text = "no objective - pin a waypoint, the route draws itself"
		return
	var text: String = str(nav.get("text", ""))
	var dist := 0.0
	if p:
		dist = (nav["pos"] as Vector2).distance_to(
				Vector2(p.global_position.x, p.global_position.z))
	_bottom.text = "%s  -  %d m  (%s)" % [text, int(round(dist)),
			str(nav.get("phase", "")).to_lower()]


func _world_to_map(v: Vector2) -> Vector2:
	return _panel.size * 0.5 + (v - _cam_world) * _scale + _pan


func _map_to_world(p: Vector2) -> Vector2:
	return (p - _panel.size * 0.5 - _pan) / _scale + _cam_world


func _draw_map() -> void:
	var d: Control = _panel
	var font := d.get_theme_default_font()
	# the dim: drawn by the panel itself so it sits under the map
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Color(0.005, 0.01, 0.02, 0.96))
	# blocks
	for block in CLS_MapData.BLOCK_RECTS:
		var rect: Rect2 = CLS_MapData.BLOCK_RECTS[block]
		var a := _world_to_map(rect.position)
		var b := _world_to_map(rect.end)
		var r := Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x),
				absf(b.y - a.y))
		var seen := CLS_MapData.block_seen(block)
		var info: Dictionary = City.BLOCK_INFO.get(block, {})
		var fill := Color(0.05, 0.06, 0.09, 0.85 if seen else 0.35)
		var edge := Color(0.4, 0.55, 0.7, 0.8 if seen else 0.3)
		if _layers["control"]:
			# district mood colours the fill (faction control arrives with
			# the story batch; the street's memory is real today)
			match City.mood_of(block):
				"hostile", "turning hostile":
					fill = Color(0.25, 0.05, 0.05, 0.85)
				"wary":
					fill = Color(0.2, 0.15, 0.05, 0.85)
				"friendly", "your street":
					fill = Color(0.05, 0.18, 0.1, 0.85)
		if _layers["heat"] and City.district_now() == block and Heat.heat >= 1.0:
			fill = fill.lerp(Color(0.4, 0.1, 0.05, 0.9),
					clampf(Heat.heat / 5.0, 0.2, 0.7))
		d.draw_rect(r, fill)
		d.draw_rect(r, edge, false, 2.0)
		d.draw_string(font, r.position + Vector2(6, 20),
				str(info.get("name", block)).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.85, 1.0, 0.9))
		if not seen:
			d.draw_string(font, r.position + r.size * 0.5 + Vector2(-30, 0),
					"not walked", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.5, 0.55, 0.6, 0.8))
	# the main streets + names
	for s in CLS_MapData.STREET_NAMES:
		var sa := _world_to_map(s["from"])
		var sb := _world_to_map(s["to"])
		d.draw_line(sa, sb, Color(0.55, 0.6, 0.7, 0.7), 5.0, true)
		d.draw_string(font, (sa + sb) * 0.5 + Vector2(0, -8), s["text"],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.6, 0.65, 0.75, 0.8))
	# the underpass (once found)
	if CLS_MapData.is_discovered("underpass_w") \
			or CLS_MapData.is_discovered("underpass_e"):
		var ua := _world_to_map(CLS_MapData.UNDERPASS["a"])
		var ub := _world_to_map(CLS_MapData.UNDERPASS["b"])
		var n := 14
		for i in range(n):
			var t0 := float(i) / float(n)
			var t1 := t0 + 0.5 / float(n)
			d.draw_line(ua.lerp(ub, t0), ua.lerp(ub, t1),
					Color(0.5, 0.55, 0.65, 0.8), 3.0, true)
		d.draw_string(font, (ua + ub) * 0.5 + Vector2(0, -6), "UNDERPASS",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.65, 0.7, 0.8, 0.9))
	# the water
	var wa := _world_to_map(CLS_MapData.WATER_RECT.position)
	var wb := _world_to_map(CLS_MapData.WATER_RECT.end)
	d.draw_rect(Rect2(minf(wa.x, wb.x), minf(wa.y, wb.y),
			absf(wb.x - wa.x), absf(wb.y - wa.y)), Color(0.1, 0.22, 0.45, 0.7))
	d.draw_string(font, wa + Vector2(6, 20), "THE WATER",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.6, 0.85, 0.9))
	# POIs: interiors only when discovered
	for poi in CLS_MapData.poi_list():
		if poi.get("interior", false) and not CLS_MapData.is_discovered(poi["id"]):
			continue
		var p := _world_to_map(poi["pos"])
		var col := Color(0.65, 0.7, 0.8, 0.85)
		var glyph := "o"
		match poi["kind"]:
			"noodle":
				col = Color(1.0, 0.75, 0.3, 0.95); glyph = "N"
			"door", "safehouse":
				col = Color(0.5, 0.9, 0.7, 0.95); glyph = "S"
			"gym":
				col = Color(0.95, 0.65, 0.1, 0.95); glyph = "G"
			"garage":
				col = Color(0.45, 0.8, 0.95, 0.95); glyph = "M"
			"club":
				col = Color(0.85, 0.3, 0.6, 0.95); glyph = "C"
			"warehouse":
				col = Color(0.7, 0.25, 0.2, 0.95); glyph = "W"
			"underpass":
				col = Color(0.6, 0.65, 0.75, 0.9); glyph = "U"
			"shop":
				col = Color(0.6, 0.65, 0.75, 0.85); glyph = "$"
		d.draw_circle(p, 6.0, Color(0.02, 0.03, 0.05, 0.9))
		d.draw_arc(p, 6.0, 0.0, TAU, 20, col, 2.0, true)
		d.draw_string(font, p + Vector2(-4, 4), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		if _scale > _fit_scale * 2.0:
			d.draw_string(font, p + Vector2(10, 4), poi["label"],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.75, 0.8, 0.85, 0.85))
	# friends layer: the cast, live
	if _layers["friends"]:
		for n in get_tree().get_nodes_in_group("cast_npc"):
			if n is Node3D:
				var pf := _world_to_map(Vector2((n as Node3D).global_position.x,
						(n as Node3D).global_position.z))
				d.draw_circle(pf, 4.0, Color(0.3, 0.6, 1.0, 0.95))
	# damage layer: scorch marks + memorials (the city remembers; the
	# points are block-LOCAL, so add the block origin back)
	if _layers["damage"]:
		for block in CLS_MapData.BLOCK_RECTS:
			var bx: float = CLS_MapData.BLOCK_CENTRES[block].x
			for pt in City.damage_points(block):
				var pd := _world_to_map(Vector2(bx + pt.x, pt.z))
				d.draw_circle(pd, 3.0, Color(0.4, 0.1, 0.05, 0.8))
			for pt in City.death_points(block):
				var pm := _world_to_map(Vector2(bx + pt.x, pt.z))
				d.draw_circle(pm, 3.5, Color(1.0, 0.75, 0.3, 0.9))
	# the route
	if _route.size() >= 2:
		for i in range(_route.size() - 1):
			d.draw_line(_world_to_map(_route[i]), _world_to_map(_route[i + 1]),
					Color(0.25, 1.0, 0.5, 0.95), 4.0, true)
	# the objective
	var nav: Dictionary = CLS_MapData.nav_target()
	if not nav.is_empty() and _layers["jobs"]:
		var po := _world_to_map(nav["pos"])
		d.draw_arc(po, 10.0, 0.0, TAU, 32, Color(0.25, 1.0, 0.5, 1.0), 3.0, true)
		d.draw_string(font, po + Vector2(12, 4), "OBJECTIVE",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.25, 1.0, 0.5, 0.95))
	# the waypoint pin
	if CLS_MapData.has_waypoint():
		var pw := _world_to_map(CLS_MapData.waypoint())
		var pts := PackedVector2Array([pw + Vector2(0, 10), pw + Vector2(-7, -4),
				pw + Vector2(7, -4)])
		d.draw_colored_polygon(pts, Color(1.0, 0.3, 0.85, 1.0))
		d.draw_circle(pw + Vector2(0, -4), 2.5, Color(1, 1, 1, 0.85))
	# the hero arrow
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero:
		var ph := _world_to_map(Vector2(hero.global_position.x,
				hero.global_position.z))
		var f: Vector3 = -hero.global_transform.basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var pts2 := PackedVector2Array([ph + dir * 10.0,
				ph + dir.rotated(2.5) * 8.0, ph + dir.rotated(-2.5) * 8.0])
		d.draw_colored_polygon(pts2, Color(0.4, 1.0, 0.9, 1.0))


func _safe_rect() -> Rect2:
	var ft := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = ft * Rect2(DisplayServer.get_display_safe_area())
	safe = safe.intersection(get_viewport().get_visible_rect())
	if safe.size.x < 8.0 or safe.size.y < 8.0:
		return get_viewport().get_visible_rect()  # headless degenerate
	return safe
