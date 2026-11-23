extends Node3D

## A STASH (rebuild step 6): the cash behind a broken door. Glows on
## the floor, one touch collects it into the WorldState ledger count
## (the wallet UI arrives with the economy step), a prompt line says
## how much, then it is gone.

var amount := 0
var label := ""

var _prompt: Label3D
var _spin: Node3D


func _ready() -> void:
	add_to_group("stash")
	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)
	var pile := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.34, 0.16, 0.22)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.4)
	mat.emission_energy_multiplier = 0.8
	m.material = mat
	pile.mesh = m
	pile.position = Vector3(0, 0.08, 0)
	pile.name = "Cash"
	_spin.add_child(pile)
	for i in 3:
		var note := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(0.22, 0.01, 0.12)
		nm.material = mat
		note.mesh = nm
		note.position = Vector3(randf_range(-0.2, 0.2),
				0.16 + i * 0.02, randf_range(-0.15, 0.15))
		note.rotation.y = randf_range(-0.8, 0.8)
		_spin.add_child(note)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.9, 0.5)
	light.light_energy = 0.5
	light.omni_range = 2.2
	light.position = Vector3(0, 0.5, 0)
	add_child(light)
	_prompt = Label3D.new()
	_prompt.text = "$%d" % amount
	_prompt.modulate = Color(0.5, 1.0, 0.7)
	_prompt.font_size = 34
	_prompt.outline_size = 10
	_prompt.outline_modulate = Color(0.01, 0.02, 0.03)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0, 0.75, 0)
	add_child(_prompt)
	# the collection zone
	var zone := Area3D.new()
	zone.name = "TakeZone"
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	col.shape = shape
	zone.add_child(col)
	add_child(zone)
	zone.body_entered.connect(_on_take)


func _process(delta: float) -> void:
	if _spin:
		_spin.rotate_y(delta * 1.6)


func _on_take(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	WorldState.bump("stash_cash", float(amount))
	WorldState.push_event("stash_taken", {"door": label,
			"amount": amount})
	Sound.play("cloth_2", -8.0, 1.4)
	Haptics.fire("ui")
	if _prompt:
		_prompt.text = "+$%d" % amount
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)
	set_process(false)
