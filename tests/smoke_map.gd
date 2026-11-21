extends Node
const CLS_MapData := preload("res://scripts/map_data.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")

## B18 (Part 6B.7): the map + navigation suite. Boots the real street
## scene, skips the opening, then drives the MapData street graph, the
## route, the waypoint, the fog of war, the radar's blips + rotation,
## and the full map's three entry points. Headless logic + tree truth;
## the pixel-level radar look is render_check's job under Xvfb.

var _fails := 0
var _checks := 0
var _main: Node
var _radar: Control
var _map: CanvasLayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("MAP FAIL: ", what)
	else:
		print("MAP ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.0)
	_radar = get_tree().get_first_node_in_group("radar") as Control
	_map = get_tree().get_first_node_in_group("full_map") as CanvasLayer

	_graph()
	await _waypoint_and_radar()
	await _objective()
	await _map_screens()
	_fog()

	if _fails == 0:
		print("MAP PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("MAP FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


# --- the street graph + routes --------------------------------------------------


func _graph() -> void:
	var near: PackedVector2Array = CLS_MapData.route(Vector2(0, 0), Vector2(10, 5))
	_check(near.size() >= 2, "a route within one block exists (%d points)" % near.size())
	if near.size() >= 2:
		_check(near[0].distance_to(Vector2(0, 0)) < 0.1,
				"the route starts where you stand")
		_check(near[near.size() - 1].distance_to(Vector2(10, 5)) < 0.1,
				"the route ends at the target")
	var far: PackedVector2Array = CLS_MapData.route(Vector2(0, 0), Vector2(480, 0))
	_check(far.size() >= 2, "a cross-block route exists (%d points)" % far.size())
	if far.size() >= 2:
		var len := CLS_MapData.route_length(far)
		_check(len > 460.0, "the cross-block route walks the streets (%.0f m)" % len)
		var near_west_gate := false
		var near_east_gate := false
		for p in far:
			if absf(p.x - 19.0) < 1.5 and absf(p.y) < 1.5:
				near_west_gate = true
			if absf(p.x - 221.0) < 1.5 and absf(p.y) < 1.5:
				near_east_gate = true
		_check(near_west_gate, "the route passes the riverside east gate")
		_check(near_east_gate, "the route passes the market west gate")
		# street-following: intermediate points live on the grid streets
		var on_streets := true
		for i in range(1, far.size() - 1):
			if absf(far[i].y) > 9.5:
				on_streets = false
		_check(on_streets, "the route stays on the streets (z within the grid)")


# --- the waypoint, the radar, the route -----------------------------------------


func _waypoint_and_radar() -> void:
	_check(_radar != null, "the radar exists in the scene")
	if _radar == null:
		return
	_check(_radar.is_visible_in_tree(), "the radar is visible by default")
	var vr := get_viewport().get_visible_rect()
	_check(vr.encloses(_radar.get_global_rect()),
			"the radar is on screen")
	# waypoint: set, navigate to, clear
	CLS_MapData.set_waypoint(Vector2(245.0, 6.0))
	_check(CLS_MapData.has_waypoint(), "a waypoint can be set")
	var nav: Dictionary = CLS_MapData.nav_target()
	_check(str(nav.get("text", "")) == "WAYPOINT"
			and (nav["pos"] as Vector2).distance_to(Vector2(245.0, 6.0)) < 0.1,
			"the waypoint becomes the navigation target")
	await _wait_s(0.8)
	_check(_radar._route.size() >= 2,
			"the radar holds a route to the waypoint (%d nodes)" % _radar._route.size())
	# blips: the standing dummy is within range, the waypoint is a blip
	_check(_radar.blips_drawn >= 2,
			"the radar draws blips (dummy + waypoint, %d)" % _radar.blips_drawn)
	# rotation: the transform answers the camera yaw
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero:
		var hxz := Vector2(hero.global_position.x, hero.global_position.z)
		InputBus.camera_yaw = 0.0
		var n0: Vector2 = _radar._world_to_radar(hxz + Vector2(0, -10), hxz)
		InputBus.camera_yaw = PI / 2.0
		var n1: Vector2 = _radar._world_to_radar(hxz + Vector2(0, -10), hxz)
		InputBus.camera_yaw = 0.0
		_check(n0 != n1, "the radar transform rotates with the camera")
		_check(n0.y < _radar.size.y * 0.5, "north maps up on the radar")
	# off-route: walk the hero away, the route re-routes from there
	if hero:
		hero.global_position = Vector3(-14.0, 0.02, 8.0)
		await _wait_s(0.8)
		_check(_radar._route.size() >= 2
				and _radar._route[0].distance_to(Vector2(-14.0, 8.0)) < 2.5,
				"the route recalculates after the hero leaves it")
	CLS_MapData.clear_waypoint()
	_check(not CLS_MapData.has_waypoint(), "the waypoint clears")


# --- the objective (a real job drives it) -----------------------------------------


func _objective() -> void:
	if Jobs.offers.is_empty():
		_check(false, "day one puts offers on the board")
		return
	var id: String = Jobs.offers[0]
	var took := Jobs.take(id)
	_check(took, "a job can be taken (%s)" % id)
	var nav: Dictionary = CLS_MapData.nav_target()
	_check(not nav.is_empty() and str(nav.get("text", "")) != "",
			"the live job becomes the navigation target")
	var marker := get_tree().get_first_node_in_group("objective_marker")
	_check(marker != null and (marker as Node3D).visible,
			"the 3D objective marker shows for a live job")


# --- the full map ------------------------------------------------------------------


func _map_screens() -> void:
	if _map == null:
		_check(false, "the full map exists in the scene")
		return
	var before_radar: int = _map.get_script().get("opened_radar")
	_map.open("radar")
	_check(_map.visible, "the full map opens (radar tap path)")
	_check(InputBus.locked, "the open map locks gameplay input")
	_map.close()
	_check(not _map.visible and not InputBus.locked,
			"closing the map hands input back")
	# entry point 2: the pause menu's MAP button, pressed for real
	var pause := get_tree().get_first_node_in_group("pause")
	var map_btn: Button = null
	if pause:
		for b in (pause as Node).find_children("*", "Button", true, false):
			if (b as Button).text == "MAP":
				map_btn = b
	_check(map_btn != null, "the pause menu has a MAP button")
	if map_btn:
		map_btn.pressed.emit()
		_check(_map.visible, "the full map opens from the pause menu")
		_map.close()
	_map.open("phone")
	_check(_map.visible, "the full map opens from the phone app")
	_map.close()
	var counts := [int(_map.get_script().get("opened_radar")),
			int(_map.get_script().get("opened_pause")),
			int(_map.get_script().get("opened_phone"))]
	_check(counts[0] > before_radar and counts[1] >= 1 and counts[2] >= 1,
			"all three entry points counted %s" % str(counts))
	# tap-to-pin: a tap on the map places the waypoint, a tap on the pin
	# removes it
	_map.open("radar")
	var world := Vector2(245.0, -6.0)
	var screen: Vector2 = _map._world_to_map(world)
	_map._tap(screen)
	_check(CLS_MapData.has_waypoint()
			and CLS_MapData.waypoint().distance_to(world) < 1.0,
			"tapping the map pins a waypoint")
	_map._tap(_map._world_to_map(CLS_MapData.waypoint()))
	_check(not CLS_MapData.has_waypoint(), "tapping the pin removes it")
	_map.close()


# --- fog of war ----------------------------------------------------------------------


func _fog() -> void:
	_check(CLS_MapData.block_seen("riverside"), "the home block is seen")
	_check(not CLS_MapData.is_discovered("gym"),
			"the gym interior starts hidden (fog of war)")
	Settings.set_hint_done("map_poi_gym")
	CLS_MapData.load_fog()
	_check(CLS_MapData.is_discovered("gym"),
			"discovery persists through the settings hints")
	# walking past a front door discovers it
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero:
		hero.global_position = Vector3(-4.0, 0.02, 8.2)
		CLS_MapData.poll_discovery(Vector2(-4.0, 8.2))
		_check(CLS_MapData.is_discovered("noodle"),
				"standing at the noodle front discovers it")
