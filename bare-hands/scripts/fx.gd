extends Node
## Impact timing and effects for combat. Autoloaded as "Fx" (see project.godot).
## Layer order on every landed hit, applied by the hero: hit-stop FIRST, then
## the enemy's flash and a particle burst, and only LAST a subtle camera shake.
## Sound is not implemented yet: connect to the hit_landed signal in Series 2.

signal hit_landed(kind: String, pos: Vector3)

const STUCK_LIMIT_MSEC := 5000  # real time; a hit-stop/slow-mo never lasts this long

var _scale_until := 0  # real-time msec when Engine.time_scale returns to 1.0
var _scale_since := 0  # real-time msec when the current scale-down started
var _mats: Dictionary = {}  # color -> ready-made burst material
var _bursts_alive := 0  # for the debug panel / stress test leak check


func _ready() -> void:
	# Restore time even while the tree is paused: a stuck hit-stop is a
	# guaranteed "mid-play stop" bug otherwise.
	process_mode = Node.PROCESS_MODE_ALWAYS


func hit_stop(duration := 0.07, scale := 0.05) -> void:
	_apply_scale(duration, scale)


func slow_mo(duration := 0.7, scale := 0.35) -> void:
	_apply_scale(duration, scale)


## One call point for every landed impact: routes to the sound hook in Series 2.
func emit_hit(kind: String, pos: Vector3) -> void:
	hit_landed.emit(kind, pos)


func _apply_scale(duration: float, scale: float) -> void:
	if Engine.time_scale != 1.0:
		Log.warn("Fx: scale %s requested while already at %s" % [scale, Engine.time_scale])
	Engine.time_scale = scale
	_scale_since = Time.get_ticks_msec()
	_scale_until = _scale_since + int(duration * 1000.0)


func _process(_delta: float) -> void:
	if Engine.time_scale != 1.0:
		var now := Time.get_ticks_msec()
		if now >= _scale_until:
			Engine.time_scale = 1.0
		elif now - _scale_since > STUCK_LIMIT_MSEC:
			# Watchdog: never leave the game frozen in slow motion.
			Engine.time_scale = 1.0
			Log.warn("Fx watchdog: force-restored a stuck time scale (was down %d ms)" % (now - _scale_since))


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## One-shot CPU particle spark at a hit point. Cheap: 10 tiny emissive boxes.
func burst(pos: Vector3, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.35
	p.mesh = _burst_mesh(color)
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -7.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	_bursts_alive += 1
	p.tree_exited.connect(func() -> void: _bursts_alive -= 1)
	var t := get_tree().create_timer(1.0, true, false, true)  # ignores time scale
	t.timeout.connect(p.queue_free)


func shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(amount)


## FOV punch in degrees (negative = zoom in). jab 1.5 / cross 3 / parry -6.
func camera_punch(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.fov_punch(amount)


var last_haptic_ms := 0  # test hook


## Haptic buzz on heavy moments. Works on Android; iOS needs a plugin (Godot
## 4.7 has no iOS vibration API) - phones only feel this once one is added.
func haptic(duration_ms: int) -> void:
	last_haptic_ms = duration_ms
	if OS.has_feature("android"):
		Input.vibrate_handheld(duration_ms)


## Brief colour wash over the screen (perfect parry).
func screen_flash(color: Color, dur := 0.35) -> void:
	var vig := get_tree().get_first_node_in_group("vignette")
	if vig:
		vig.flash(color, dur)


func _burst_mesh(color: Color) -> Mesh:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
		_mats[key] = m
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 0.06)
	box.material = _mats[key]
	return box
