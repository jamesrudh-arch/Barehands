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

## The six-area registry (02_MASTER_DESIGN §3). Grows as areas land.
const AREAS := {
	"warehouse": "res://scenes/areas/warehouse_shell.tscn",
}

const FADE_S := 0.4

var state: State = State.BOOT
var area_id := ""
var spawn_id := ""
var _fading := false
var _fade: ColorRect
var _fade_layer: CanvasLayer


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


func start_new_game() -> void:
	WorldState.reset()
	await travel("warehouse", "start")


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
	_fading = false
	await fade_in(FADE_S)


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
