extends Node
## Impact timing and effects for combat. Autoloaded as "Fx" (see project.godot).
## Layer order on every landed hit, applied by the hero: hit-stop FIRST, then
## the enemy's flash and a particle burst, and only LAST a subtle camera shake.
## Sound is not implemented yet: connect to the hit_landed signal in Batch 4.

signal hit_landed(kind: String, pos: Vector3)

var _scale_until := 0  # real-time msec when Engine.time_scale returns to 1.0
var _mats: Dictionary = {}  # color -> ready-made burst material


func hit_stop(duration := 0.07, scale := 0.05) -> void:
	Engine.time_scale = scale
	_scale_until = Time.get_ticks_msec() + int(duration * 1000.0)


func slow_mo(duration := 0.7, scale := 0.35) -> void:
	Engine.time_scale = scale
	_scale_until = Time.get_ticks_msec() + int(duration * 1000.0)


func _process(_delta: float) -> void:
	if Engine.time_scale != 1.0 and Time.get_ticks_msec() >= _scale_until:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## One-shot CPU particle spark at a hit point. Cheap: 10 tiny emissive boxes.
func burst(pos: Vector3, color: Color) -> void:
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
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	var t := get_tree().create_timer(1.0, true, false, true)
	t.timeout.connect(p.queue_free)


func shake(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(amount)


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
