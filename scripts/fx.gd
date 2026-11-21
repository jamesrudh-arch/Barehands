extends Node
## Impact timing and effects for combat. Autoloaded as "Fx" (see project.godot).
## Layer order on every landed hit, applied by the hero: hit-stop FIRST, then
## the enemy's flash and a particle burst, and only LAST a subtle camera shake.
## Sound is not implemented yet: connect to the hit_landed signal in Series 2.

signal hit_landed(kind: String, pos: Vector3)

const STUCK_LIMIT_MSEC := 5000  # real time; a slow-mo never lasts this long

## SELECTIVE HITSTOP (bible 8, COMBAT ARCHITECTURE): hitstop pauses ONLY
## the attacker and the target - their AnimationPlayers stop, their
## physics gate on is_frozen() - while rain, particles, music and every
## other character keep running. Engine.time_scale is NEVER used for
## hitstop. slow_mo below stays a CAMERA effect on time_scale, and two
## slow-mos landing in one frame MERGE instead of fighting (the old
## collision warning was the "player.gd:366 error": a punch's hitstop
## racing the kill's slow-mo).
var _frozen: Dictionary = {}  # node -> {"players": Array, "until": msec}

var _scale_until := 0  # real-time msec when Engine.time_scale returns to 1.0
var _scale_since := 0  # real-time msec when the current scale-down started
var _mats: Dictionary = {}  # color -> ready-made burst material
var _bursts_alive := 0  # for the debug panel / stress test leak check


func _ready() -> void:
	# Restore time even while the tree is paused: a stuck hit-stop is a
	# guaranteed "mid-play stop" bug otherwise.
	process_mode = Node.PROCESS_MODE_ALWAYS


func hit_stop(frames := 4, who: Array = []) -> void:
	## Freeze the attacker and the target for `frames` logic frames
	## (60 fps): pause their AnimationPlayers and gate their physics.
	## The world keeps moving. No Engine.time_scale.
	var until := Time.get_ticks_msec() + int(frames * 1000.0 / 60.0)
	for n in who:
		if n == null or not is_instance_valid(n):
			continue
		if _frozen.has(n):
			_frozen[n]["until"] = maxi(_frozen[n]["until"], until)
			continue
		var players: Array = []
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			ap.pause()
			players.append(ap)
		_frozen[n] = {"players": players, "until": until}


## The freeze gate: player.gd and enemy.gd return early from
## _physics_process while frozen, so velocity, state timers and AI hold.
func is_frozen(node: Node) -> bool:
	return _frozen.has(node)


func _unfreeze(n: Node) -> void:
	var f: Dictionary = _frozen[n]
	_frozen.erase(n)
	# eased recovery (bible 4A): resume at 30% speed ramping back to full
	# over about four frames, so the pop back to motion reads as weight
	for ap in f["players"]:
		if is_instance_valid(ap):
			ap.speed_scale = 0.3
			ap.play()  # no-arg play() resumes a paused animation (Godot 4)
			var tw := create_tween()
			tw.tween_property(ap, "speed_scale", 1.0, 0.08)


func slow_mo(duration := 0.7, scale := 0.35) -> void:
	_apply_scale(duration, scale)


## End the current slow-mo on the next process tick (the wheel closes:
## the pick is made, the fight resumes at speed). A fresh slow_mo cannot
## do this - _apply_scale MERGES active slow-mos and would extend it.
func end_slow_mo() -> void:
	_scale_until = Time.get_ticks_msec()


## One call point for every landed impact: routes to the sound hook in Series 2.
func emit_hit(kind: String, pos: Vector3) -> void:
	hit_landed.emit(kind, pos)


func _apply_scale(duration: float, scale: float) -> void:
	if Engine.time_scale != 1.0:
		# two camera slow-mos in one frame (a multi-kill, a super into a
		# knockdown): merge - keep the STRONGER (lower) scale and the
		# LONGER end. The old warning here was misread as a crash.
		# A merge also counts as LIFE for the stuck-watchdog: the style
		# wheel keeps its world-crawl alive by re-issuing slow_mo every
		# couple of seconds, and the watchdog must not kill a slow-mo
		# that somebody is actively refreshing - it is a net for
		# slow-mos nobody tends, not a hard 5 s lifespan.
		Engine.time_scale = minf(Engine.time_scale, scale)
		_scale_since = Time.get_ticks_msec()
		_scale_until = maxi(_scale_until,
				Time.get_ticks_msec() + int(duration * 1000.0))
		return
	Engine.time_scale = scale
	_scale_since = Time.get_ticks_msec()
	_scale_until = _scale_since + int(duration * 1000.0)


func _process(_delta: float) -> void:
	# unfreeze hitstopped characters (real time, so a pause in the tree
	# can never lock a freeze on)
	for n in _frozen.keys().duplicate():
		var f: Dictionary = _frozen[n]
		if not is_instance_valid(n):
			_frozen.erase(n)
			continue
		if Time.get_ticks_msec() >= f["until"]:
			_unfreeze(n)
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
	_frozen.clear()
	_frozen.clear()


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


## B19: a one-shot SPRITE burst - dust clouds on slams, sparks on
## parries (the Kenney explosion-pack CC0 sprites). Same bounded
## one-second life as burst().
func burst_sprite(pos: Vector3, tex_path: String, color: Color,
		count := 8, size := 0.3) -> void:
	var scene := get_tree().current_scene
	if scene == null or not ResourceLoader.exists(tex_path):
		burst(pos, color)  # the fallback stays honest
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = load(tex_path)
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = mat
	p.mesh = qm
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	_bursts_alive += 1
	p.tree_exited.connect(func() -> void: _bursts_alive -= 1)
	var t := get_tree().create_timer(1.0, true, false, true)
	t.timeout.connect(p.queue_free)


func shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		# accessibility (bible 7): reduced shake scales every impact
		cam.shake(amount * clampf(float(Settings.value("shake_scale")), 0.0, 1.0))


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
