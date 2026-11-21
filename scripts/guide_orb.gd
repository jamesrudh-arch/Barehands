extends Node3D
const CLS_MapData := preload("res://scripts/map_data.gd")
const CLS_Interior := preload("res://scripts/interior.gd")

## B18.3 PART 6C.4 (BUG 9): the GREEN GUIDE - the follow-me orb. A
## bright green light floats about 1.5 m up, AHEAD of the hero along
## the street route to the live objective (radar + waypoint + tutorial
## steps all feed MapData.nav_target). It keeps a 4-6 m lead, waits
## and pulses when you stop or fall behind, speeds up when you run,
## re-routes when you turn away, passes through doors, and bounces
## over the destination when you arrive. Chevrons mark the ground
## behind it (on during the tutorial); a screen-edge arrow points to
## it when it leaves the frame. Green by default; the setting
## "guide_colour" switches it to cyan (accessibility). The same colour
## drives the radar route and the destination beam.

const LEAD_MIN := 4.0
const LEAD_MAX := 6.0
const WAIT_DIST := 8.0
const ARRIVE_DIST := 3.0

enum State { LEADING, WAITING, ARRIVED }

var state := State.LEADING

var _route: PackedVector2Array = []
var _route_t := 0.0
var _progress := 0.0
var _hero_progress := 0.0
var _stop_t := 0.0
var _t := 0.0
var _orb: MeshInstance3D
var _glow: MeshInstance3D
var _trail: MultiMeshInstance3D
var _trail_mm: MultiMesh
var _trail_hist: Array[Vector3] = []
var _chev: MultiMeshInstance3D
var _chev_mm: MultiMesh
var _canvas: CanvasLayer
var _arrow: ArrowDraw


func colour() -> Color:
	return Color(0.3, 0.95, 1.0) if str(Settings.value("guide_colour")) == "cyan" \
			else Color(0.25, 1.0, 0.5)


func _ready() -> void:
	add_to_group("guide_orb")
	_orb = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	var m := StandardMaterial3D.new()
	m.albedo_color = colour()
	m.emission_enabled = true
	m.emission = colour()
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = m
	_orb.mesh = s
	add_child(_orb)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.85, 0.85)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(colour(), 0.25)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = gm
	_glow.mesh = q
	add_child(_glow)
	# the fading trail (8 billboard quads, cheap)
	_trail = MultiMeshInstance3D.new()
	_trail_mm = MultiMesh.new()
	_trail_mm.transform_format = MultiMesh.TRANSFORM_3D
	_trail_mm.use_colors = true
	_trail_mm.instance_count = 8
	var tq := QuadMesh.new()
	tq.size = Vector2(0.3, 0.3)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color.WHITE
	tm.vertex_color_use_as_albedo = true
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tq.material = tm
	_trail.multimesh = _trail_mm
	_trail_mm.mesh = tq
	add_child(_trail)
	# the ground chevrons along the route ahead
	_chev = MultiMeshInstance3D.new()
	_chev_mm = MultiMesh.new()
	_chev_mm.transform_format = MultiMesh.TRANSFORM_3D
	_chev_mm.use_colors = true
	_chev_mm.instance_count = 10
	var cq := QuadMesh.new()
	cq.size = Vector2(0.55, 0.55)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color.WHITE
	cm.vertex_color_use_as_albedo = true
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cq.material = cm
	_chev.multimesh = _chev_mm
	_chev_mm.mesh = cq
	add_child(_chev)
	# the screen-edge arrow
	_canvas = CanvasLayer.new()
	_canvas.layer = 6
	add_child(_canvas)
	_arrow = ArrowDraw.new()
	_arrow.colour = colour()
	_arrow.visible = false
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_arrow)


func _physics_process(delta: float) -> void:
	if not bool(Settings.value("guide_on")):
		_orb.visible = false
		_glow.visible = false
		_trail.visible = false
		_chev.visible = false
		if _arrow:
			_arrow.visible = false
		return
	_orb.visible = true
	_glow.visible = true
	_trail.visible = true
	_chev.visible = bool(Settings.value("guide_chevrons"))
	_t += delta
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		return
	var nav: Dictionary = CLS_MapData.nav_target()
	if nav.is_empty():
		_hide_all()
		return
	_route_t += delta
	if _route_t >= 0.5:
		_refresh_route(hero, nav)
	if _route.size() < 2:
		_hide_all()
		return
	var hero_xz := Vector2(hero.global_position.x, hero.global_position.z)
	_hero_progress = _project(hero_xz)
	var end_d := hero_xz.distance_to(_route[_route.size() - 1])
	var target: Vector2 = nav["pos"]
	# arrival: hover over the destination and bounce
	if end_d < ARRIVE_DIST or hero.global_position.distance_to(
			Vector3(target.x, hero.global_position.y, target.y)) < ARRIVE_DIST:
		state = State.ARRIVED
		global_position = Vector3(target.x, 0.0, target.y) \
				+ Vector3(0, 1.2 + 0.25 * absf(sin(_t * 3.0)), 0)
		_update_visuals(hero)
		return
	# waiting: stopped, or more than WAIT_DIST behind the orb
	var behind := global_position.distance_to(hero.global_position)
	var speed: float = (hero as CharacterBody3D).velocity.length()
	if speed < 0.4:
		_stop_t += delta
	else:
		_stop_t = 0.0
	if behind > WAIT_DIST or _stop_t > 1.2:
		state = State.WAITING
	else:
		state = State.LEADING
	if state == State.LEADING:
		var lead: float = lerpf(LEAD_MIN, LEAD_MAX, clampf(speed / 6.0, 0.0, 1.0))
		var want: float = clampf(_hero_progress + lead, 0.0, _length() - 0.8)
		var pace: float = clampf(speed * 1.25 + 1.5, 2.4, 7.5)
		_progress = move_toward(_progress, want, pace * delta)
	# WAITING: hold position (the bob + pulse below)
	var p := _point_at(_progress)
	global_position = p + Vector3(0,
			1.5 + 0.12 * sin(_t * 2.4), 0)
	_update_visuals(hero)


func _hide_all() -> void:
	if _arrow:
		_arrow.visible = false


func _refresh_route(hero: Node3D, nav: Dictionary) -> void:
	_route_t = 0.0
	var target: Vector2 = nav["pos"]
	var hero_xz := Vector2(hero.global_position.x, hero.global_position.z)
	var tgt := Vector2(target.x, target.y)
	if CLS_Interior.is_inside_interior(hero):
		# indoors there are no streets: a straight line to the target
		_route = PackedVector2Array([hero_xz, tgt])
	else:
		_route = CLS_MapData.route(hero_xz, tgt)
	_progress = clampf(_progress, 0.0, maxf(0.0, _length() - 0.8))


func _length() -> float:
	var total := 0.0
	for i in range(_route.size() - 1):
		total += _route[i].distance_to(_route[i + 1])
	return total


func _point_at(dist: float) -> Vector3:
	var left := dist
	for i in range(_route.size() - 1):
		var seg: float = _route[i].distance_to(_route[i + 1])
		if left <= seg:
			var f := left / maxf(seg, 0.001)
			var p := _route[i].lerp(_route[i + 1], f)
			return Vector3(p.x, 0.0, p.y)
		left -= seg
	var p := _route[_route.size() - 1]
	return Vector3(p.x, 0.0, p.y)


func _project(xz: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var acc := 0.0
	for i in range(_route.size() - 1):
		var a := _route[i]
		var b := _route[i + 1]
		var seg := a.distance_to(b)
		var f := clampf((xz - a).dot(b - a) / maxf(seg * seg, 0.001), 0.0, 1.0)
		var proj := a.lerp(b, f)
		var d := xz.distance_to(proj)
		if d < best_d:
			best_d = d
			best = acc + f * seg
		acc += seg
	return best


func _update_visuals(hero: Node3D) -> void:
	# the pulse (waiting) / calm bob (leading)
	var pulse: float = 1.0 + (0.35 * absf(sin(_t * 4.0))
			if state != State.LEADING else 0.08 * sin(_t * 3.0))
	_orb.scale = Vector3.ONE * pulse
	_glow.scale = Vector3.ONE * pulse
	(_glow.mesh.material as StandardMaterial3D).albedo_color = Color(colour(), 0.25)
	(_orb.mesh.material as StandardMaterial3D).albedo_color = colour()
	# trail: recent positions, fading
	_trail_hist.push_front(global_position)
	if _trail_hist.size() > 8:
		_trail_hist.pop_back()
	for i in 8:
		var t := Transform3D(Basis(), _trail_hist[i] if i < _trail_hist.size()
				else global_position)
		_trail_mm.set_instance_transform(i, t)
		var a := 0.55 * (1.0 - float(i) / 8.0)
		_trail_mm.set_instance_color(i, Color(colour(), a))
	# chevrons along the route ahead of the hero
	if _chev.visible:
		for i in 10:
			var d := _hero_progress + 1.2 + float(i) * 1.2
			var cp := _point_at(minf(d, _length()))
			var t2 := Transform3D(Basis(Vector3(0, 1, 0), _t * 0.0), cp + Vector3(0, 0.06, 0))
			_chev_mm.set_instance_transform(i, t2)
			var ca := 0.5 * (1.0 - float(i) / 10.0)
			_chev_mm.set_instance_color(i, Color(colour(), ca))
	# the screen-edge arrow when the orb is off-screen
	if _arrow:
		var cam := get_tree().get_first_node_in_group("camera") as Camera3D
		if cam:
			var vp := cam.unproject_position(global_position)
			var vis := cam.is_position_behind(global_position)
			var rect := Rect2(Vector2.ZERO, _canvas.get_viewport().get_visible_rect().size)
			if not vis and rect.has_point(vp):
				_arrow.visible = false
			else:
				_arrow.visible = true
				var centre := rect.size * 0.5
				var dir := (vp - centre) if not vis else (centre - vp) * -1.0
				if dir.length() < 1.0:
					dir = Vector2(0, -1)
				dir = dir.normalized()
				var edge := centre + dir * (rect.size * 0.42)
				_arrow.position = edge - Vector2(28, 28)
				_arrow.angle = dir.angle()


## The OBJECTIVE button calls this: the orb returns to the hero.
func recall() -> void:
	_progress = _hero_progress
	_stop_t = 0.0


## Test hook: how far ahead of the hero the orb currently rides.
func lead_now() -> float:
	return _progress - _hero_progress


## A code-drawn screen-edge arrow (no unicode, no files).
class ArrowDraw extends Control:
	var colour := Color(0.25, 1.0, 0.5)
	var angle := 0.0
	var _pts := PackedVector2Array([Vector2(28, 4), Vector2(52, 28),
			Vector2(28, 52), Vector2(36, 28)])

	func _draw() -> void:
		var pts := PackedVector2Array()
		for p in _pts:
			pts.append(p.rotated(angle - PI * 0.5) )
		draw_colored_polygon(pts, colour)
		draw_circle(Vector2(28, 28), 4.0, Color(1, 1, 1, 0.6))
