extends Node

## THE GAME AUTOLOAD (rebuild): the flow state machine and the one
## travel/fade owner. States: BOOT → SPLASH → TITLE → MENU → PLAY ⇄
## PAUSE, plus GAMEOVER later. Area scenes are self-contained; Game
## swaps them with a fade and tracks where the player is.
##
## Stage-0 discipline: guarded node access, no class_name
## dependencies, works even when other autoloads are missing.

signal state_changed(from_name: String, to_name: String)

enum State { BOOT, SPLASH, TITLE, MENU, PLAY, PAUSE }

## True while the cold-open cinematic owns the frame (S5.18):
## the hero's inputs go quiet; the world keeps living behind it.
var in_cinematic := false

## The six-area registry (02_MASTER_DESIGN §3). Grows as areas land.
const AREAS := {
	"warehouse": "res://scenes/areas/warehouse_shell.tscn",
	"neighbourhood": "res://scenes/areas/neighbourhood.tscn",
	"club_district": "res://scenes/areas/club_district.tscn",
	"docks": "res://scenes/areas/docks.tscn",
	"airport": "res://scenes/areas/airport.tscn",
	"second_city": "res://scenes/areas/second_city.tscn",
}

const CLS_CameraRig := preload("res://scripts/player/camera_rig.gd")
const CLS_Missions := preload("res://scripts/missions/missions.gd")
const M0_PATH := "res://data/missions/m0.tres"

const FADE_S := 0.4

var state: State = State.BOOT
var area_id := ""
var spawn_id := ""
var _fading := false
var _fade: ColorRect
var _fade_layer: CanvasLayer
var _touch_ui: CanvasLayer = null
var _missions: Node = null
var _hud: CanvasLayer = null
var _police: Node = null
var _worldsim: Node = null
var _surface: Node = null
var _leverage: Node = null
var _market: Node = null
var _phone: CanvasLayer = null
var _pause_menu: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the fade rides above everything and survives scene swaps
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.01, 0.03, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


func state_name() -> String:
	return State.keys()[state].to_lower()


func set_state(s: State) -> void:
	if s == state:
		return
	var from := state_name()
	state = s
	state_changed.emit(from, state_name())


## Splash cards done → the menu.
func go_menu() -> void:
	set_state(State.MENU)
	get_tree().change_scene_to_file("res://scenes/boot/menu.tscn")


## THE PLANE (S5.14): GRAB at the stand boards the flight - the
## fare is clean, the fade is the cutscene, the city changes.
const PLANE_SPOTS := {
	"airport": {"to": "second_city",
			"pos": Vector3(4.6, 0.05, -11.0)},
	"second_city": {"to": "airport",
			"pos": Vector3(23.6, 0.05, -8.0)},
}

func try_board(hero: Node3D) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	if not PLANE_SPOTS.has(area_id):
		return false
	var s: Dictionary = PLANE_SPOTS[area_id]
	if hero.global_position.distance_to(s["pos"]) > 4.0:
		return false
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	if mkt == null:
		return false
	var res: Dictionary = mkt.pay(float(Tuning.v("flight_fare")))
	if not bool(res.get("ok", false)):
		WorldState.push_event("vendor_no", {"who": "THE PILOT",
				"msg": "Ticket's $%d. The plane waits; your wallet doesn't." % int(
						Tuning.v("flight_fare"))})
		return true
	WorldState.set_flag("visited:" + str(s["to"]))
	WorldState.push_event("flight", {"to": str(s["to"]),
			"fare": float(Tuning.v("flight_fare"))})
	travel(str(s["to"]), "start")
	return true


func start_new_game() -> void:
	WorldState.reset()
	# THE DEBT: the story's spine (the brother's $2,000 - 02 §2)
	# the bible's five grand, split the way the story owes it
	WorldState.set_value("debt", Tuning.v("starting_debt"))
	WorldState.set_value("debt_family", Tuning.v("debt_start_family"))
	WorldState.set_value("debt_corp", Tuning.v("debt_start_corp"))
	# the disciplines are LEARNED from people: you start with your
	# fists (and the pistol you already carry); the teachers hand
	# over the rest (M2 Kickboxing, M3 Drunken, the Collector later)
	WorldState.set_value("unlocked_styles", ["brawler", "weapon"])
	await travel("warehouse", "start")
	# THE COLD OPEN (S5.18): Marla's call lands the story's grab
	# over the live loft, once ever, unless the player opted out
	if not WorldState.flag("intro_seen") \
			and not bool(Settings.value("skip_intro")):
		var co := preload(
				"res://scripts/boot/cold_open.gd").new()
		add_child(co)


## CONTINUE: the last landing, loaded back.
func continue_game() -> void:
	var d: Dictionary = SaveGame.load_data()
	if d.is_empty():
		start_new_game()
		return
	WorldState.from_save(d.get("world", {}))
	var area := str(d.get("area", "warehouse"))
	if not AREAS.has(area):
		area = "warehouse"
	await travel(area, "start")


## The one way between areas: fade out, swap the scene, land the
## player, fade in. Only the current area is ever in memory.
func travel(id: String, spawn: String = "") -> void:
	if _fading or not AREAS.has(id):
		return
	if not get_tree().paused:
		pass
	_fading = true
	area_id = id
	spawn_id = spawn
	set_state(State.PLAY)
	await fade_out(FADE_S)
	get_tree().change_scene_to_file(AREAS[id])
	# let the swap land before the fade lifts (two frames is the
	# safe margin for change_scene_to_file)
	await get_tree().process_frame
	await get_tree().process_frame
	_mount_player(spawn)
	# THE CRITTERS (S5.18): the city breathes - moths at the
	# lamps, rats at the alley bases, fish in the fountain
	Critters.spawn_for(get_tree().current_scene, id)
	# S5.19 THE WORLD PILLARS: the river, the filling station,
	# the birds - the gaps the scorecard named
	WorldPillars.spawn_for(get_tree().current_scene, id)
	_fading = false
	# the landing IS the checkpoint (and the menu's CONTINUE lights)
	if SaveGame != null:
		SaveGame.save_now()
	await fade_in(FADE_S)


func _notification(what: int) -> void:
	# S5.21 PRE-FLIGHT: suspend/close = checkpoint NOW. The area
	# landing saves survive only polite exits; Android kills the
	# process after background, taking everything since the last
	# landing. Guard: only mid-run (an area is mounted).
	if (what == MainLoop.NOTIFICATION_APPLICATION_PAUSED
			or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT
			or what == NOTIFICATION_WM_CLOSE_REQUEST) \
			and area_id != "":
		SaveGame.save_now()
		Log.info("Game: suspend/close checkpoint (area=%s)" % area_id)


## PLAY mounts the player stack exactly once per area: the hero at
## the spawn marker, the camera rig on it, and the touch UI (one
## instance for the whole session - it survives area swaps).
func _mount_player(spawn: String) -> void:
	var area := get_tree().current_scene
	if area == null:
		return
	# clear any previous hero/camera from the last area
	for old in get_tree().get_nodes_in_group("player") + \
			get_tree().get_nodes_in_group("camera_rig"):
		if old != null and is_instance_valid(old):
			old.queue_free()
	var hero: Node3D = load("res://scenes/entities/hero.tscn").instantiate()
	# "from_home" -> SpawnFromHome (capitalize() eats underscores)
	var marker_name := "Spawn" + spawn.replace("_", " ").capitalize() \
			.replace(" ", "") if spawn != "" else "SpawnStart"
	var marker := area.get_node_or_null(marker_name) as Node3D
	hero.global_position = marker.global_position \
			if marker else Vector3(0, 0.05, 0)
	area.add_child(hero)
	var rig := CLS_CameraRig.new()
	rig.global_position = hero.global_position + Vector3(0, 1.45, 0)
	area.add_child(rig)
	if _touch_ui == null or not is_instance_valid(_touch_ui):
		_touch_ui = load("res://scripts/player/touch_ui.gd").new()
		add_child(_touch_ui)
	# the mission module rides Game; a NEW GAME (WorldState was reset
	# in start_new_game) opens with M0 WAKE-UP CALL
	if _missions == null or not is_instance_valid(_missions):
		_missions = CLS_Missions.new()
		add_child(_missions)
	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)
	if _worldsim == null or not is_instance_valid(_worldsim):
		_worldsim = load("res://scripts/worldsim.gd").new()
		add_child(_worldsim)
	if _surface == null or not is_instance_valid(_surface):
		_surface = load("res://scripts/world/surface.gd").new()
		add_child(_surface)
	if _leverage == null or not is_instance_valid(_leverage):
		_leverage = load("res://scripts/leverage.gd").new()
		add_child(_leverage)
	if _market == null or not is_instance_valid(_market):
		_market = load("res://scripts/core/market.gd").new()
		add_child(_market)
	if _hud == null or not is_instance_valid(_hud):
		_hud = load("res://scripts/ui/hud.gd").new()
		add_child(_hud)
	if _phone == null or not is_instance_valid(_phone):
		_phone = load("res://scripts/ui/phone.gd").new()
		add_child(_phone)
	# the phone rides the hero's action signal (the proven pipe).
	# ONE connection per hero: every re-mount re-runs this - a bare
	# connect would stack lambdas and one press would toggle the
	# phone open+shut (the smoke_systems catch)
	if _phone.get("_wired_hero") != hero:
		var old = _phone.get("_wired_hero")
		if old and is_instance_valid(old) \
				and old.is_connected("face_action", _phone.on_hero_action):
			old.disconnect("face_action", _phone.on_hero_action)
		hero.connect("face_action", _phone.on_hero_action)
		_phone.set("_wired_hero", hero)
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = load("res://scripts/ui/pause_menu.gd").new()
		add_child(_pause_menu)
	if not WorldState.flag("first_play_done"):
		WorldState.set_flag("first_play_done")
		_missions.start(M0_PATH)


func fade_out(t := FADE_S) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	await tw.finished


func fade_in(t := FADE_S) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, t)
	await tw.finished


func pause_game() -> void:
	if state != State.PLAY:
		return
	set_state(State.PAUSE)
	get_tree().paused = true


func resume_game() -> void:
	if state != State.PAUSE:
		return
	get_tree().paused = false
	set_state(State.PLAY)
