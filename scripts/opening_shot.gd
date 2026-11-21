extends Node
const CLS_FollowCamera := preload("res://scripts/camera_follow.gd")
## Cinematic opening: the camera sweeps down the neon street and lands behind
## the hero over ~7 s. Any tap or key skips it. Drives the follow camera
## directly (it is frozen for the duration); the HUD and gameplay input come
## back when it ends.

const DURATION := 7.0

var _t := 0.0
var _done := false
var _tapped := false
var _camera: CLS_FollowCamera
var _hud: CanvasLayer
var _bars: CanvasLayer

# Flight path: high over the east neon, dipping down the street, landing
# behind the hero's shoulder. Control point shapes the dip.
var _start := Vector3(13.0, 10.0, -13.0)
var _ctrl := Vector3(7.0, 3.2, 2.0)
var _look_from := Vector3(9.0, 6.0, -7.8)  # the amber annex + kiosk glow
var _end := Vector3.ZERO
var _look_to := Vector3.ZERO
var _born_msec := 0

# B16: SafeBoot and smoke_null_watch read this - did the cinematic
# EVER land (skip or watchdog both count as landed)?
static var ever_finished := false
# B18: did the 8 s watchdog have to pry the game loose? (the device
# report reads this)
static var forced_end := false


func _recapture_end() -> void:
	var pivot: Vector3 = _camera._pivot()
	_end = pivot + Vector3(0.0, _camera.height, _camera.distance)
	_look_to = get_node("../Player").global_position + Vector3.UP * 1.5


func _ready() -> void:
	add_to_group("opening")
	# a cinematic must never strand the game: even if the tree is
	# paused underneath us, we keep flying and we always land
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = get_node("../Camera") as CLS_FollowCamera
	# B18: if the camera or the HUD lookup fails, the cinematic declines
	# to start - a broken reference must never hide the game for good
	if _camera == null or get_node_or_null("../UI") == null:
		_done = true
		ever_finished = true
		InputBus.locked = false
		queue_free()
		return
	_camera.set_frozen(true)
	# deferred: the follow camera's _ready places the follow pose;
	# capture it AFTER, or a node-order change strands the camera
	_end = _camera.global_position
	call_deferred("_recapture_end")
	_born_msec = Time.get_ticks_msec()
	var hero := get_node_or_null("../Player")
	_look_to = hero.global_position + Vector3.UP * 1.5 if hero \
			else Vector3.UP * 1.5
	_hud = get_node("../UI") as CanvasLayer
	_hud.visible = false
	InputBus.locked = true
	_build_letterbox()


func _input(event: InputEvent) -> void:
	if not _done and (event is InputEventScreenTouch or event is InputEventMouseButton \
			or event is InputEventKey):
		_tapped = true


func _process(delta: float) -> void:
	if _done:
		return
	# the watchdog (B18 Part 1.2): whatever stall or pause happens
	# elsewhere, the cinematic lands and hands the game back within
	# 8 s, snapping the camera to the captured pose behind the hero
	if Time.get_ticks_msec() - _born_msec > 8000:
		_finish(true)
		return
	_t += delta / DURATION
	if _t >= 1.0:
		_finish()
		return
	var e := _t * _t * (3.0 - 2.0 * _t)  # smoothstep
	_camera.global_position = _bezier(_start, _ctrl, _end, e)
	var look := _look_from.lerp(_look_to, e)
	_camera.look_at(look)
	if _tapped:
		_finish()


## Tests call this to jump straight to gameplay.
func skip() -> void:
	_finish()


func _finish(forced := false) -> void:
	if _done:
		return
	var skipped := _t < 1.0
	_done = true
	ever_finished = true
	if forced:
		forced_end = true
	_t = 1.0
	# B18: the handback is unconditional and each step guarded - one
	# broken reference can never strand the HUD, the camera or the input
	if _camera and is_instance_valid(_camera):
		_camera.global_position = _end
		_camera.set_frozen(false)
	if _hud and is_instance_valid(_hud):
		_hud.visible = true
	InputBus.locked = false
	InputBus.clear_queues()
	if _bars and is_instance_valid(_bars):
		_bars.queue_free()
	Log.info("opening shot done (skipped: %s, forced: %s)" % [skipped, forced])
	queue_free()


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


func _build_letterbox() -> void:
	_bars = CanvasLayer.new()
	_bars.layer = 20
	add_child(_bars)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		if top:
			bar.anchor_top = 0.0
			bar.anchor_bottom = 0.0
			bar.offset_bottom = 46.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -46.0
		_bars.add_child(bar)
	var skip := Label.new()
	skip.text = "TAP TO SKIP"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 1.0
	skip.anchor_bottom = 1.0
	skip.offset_left = -170.0
	skip.offset_top = -96.0
	skip.offset_right = -20.0
	skip.offset_bottom = -58.0
	skip.add_theme_font_size_override("font_size", 14)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bars.add_child(skip)
