extends Area3D

## B18.3 PART 6D: a world PICKUP. Weapons (pipe, bat, bottle, plank,
## chair leg) equip through the Weapons layer on the player's pipe
## move set; items (cash, health, painkillers, key, burner phone)
## apply immediately. Every pickup glows with its class colour (white
## common, yellow cash, green health, blue keys), bobs and turns so it
## reads in the dark, and shows a floating "[B] PICK UP ..." prompt
## when the hero stands near. B (the FIGHT scheme's context button)
## and the GRAB pill both reach it through the player's grab chain.

const CLS_Weapons := preload("res://scripts/weapons.gd")

const KINDS := {
	"pipe": {"label": "LEAD PIPE", "class": "weapon",
			"glow": Color(0.9, 0.92, 0.98)},
	"bat": {"label": "BASEBALL BAT", "class": "weapon",
			"glow": Color(0.9, 0.92, 0.98)},
	"bottle": {"label": "BOTTLE", "class": "weapon",
			"glow": Color(0.9, 0.92, 0.98)},
	"plank": {"label": "WOOD PLANK", "class": "weapon",
			"glow": Color(0.9, 0.92, 0.98)},
	"chair_leg": {"label": "CHAIR LEG", "class": "weapon",
			"glow": Color(0.9, 0.92, 0.98)},
	"cash": {"label": "CASH", "class": "item",
			"glow": Color(1.0, 0.85, 0.25)},
	"health": {"label": "FIRST AID", "class": "item",
			"glow": Color(0.35, 1.0, 0.5)},
	"painkillers": {"label": "PAINKILLERS", "class": "item",
			"glow": Color(0.35, 1.0, 0.5)},
	"key": {"label": "KEY CARD", "class": "item",
			"glow": Color(0.4, 0.7, 1.0)},
	"burner": {"label": "BURNER PHONE", "class": "item",
			"glow": Color(0.4, 0.7, 1.0)},
}

var kind := "pipe"
var amount := 0
var _near := false
var _prompt: Label3D
var _spin: Node3D
var _t := 0.0
var _base_y := 0.35


func setup(k: String, amt := 0) -> void:
	kind = k
	amount = amt


func _ready() -> void:
	add_to_group("pickup")
	set_meta("verb", "PICK UP")
	set_meta("pickup_kind", kind)
	var spec: Dictionary = KINDS.get(kind, KINDS["pipe"])
	set_meta("pickup_name", spec["label"])
	_build_body(spec)
	_build_glow(spec)
	_build_prompt(spec)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	col.shape = shape
	col.position = Vector3(0, 0.4, 0)
	add_child(col)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


## The object itself, per kind (all code-built, no files).
func _build_body(spec: Dictionary) -> void:
	_spin = Node3D.new()
	_spin.position = Vector3(0, 0.35, 0)
	add_child(_spin)
	_base_y = 0.35
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.3)
	mat.roughness = 0.7
	var mesh: PrimitiveMesh
	match kind:
		"pipe":
			var c := CylinderMesh.new()
			c.top_radius = 0.03
			c.bottom_radius = 0.03
			c.height = 0.85
			mesh = c
			mat.albedo_color = Color(0.24, 0.25, 0.28)
			mat.metallic = 0.8
			mat.roughness = 0.35
		"bat":
			var c := CylinderMesh.new()
			c.top_radius = 0.022
			c.bottom_radius = 0.045
			c.height = 0.95
			mesh = c
			mat.albedo_color = Color(0.45, 0.3, 0.16)
		"bottle":
			var c := CylinderMesh.new()
			c.top_radius = 0.03
			c.bottom_radius = 0.045
			c.height = 0.3
			mesh = c
			mat.albedo_color = Color(0.25, 0.4, 0.25)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.9
		"plank":
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.04, 0.16)
			mesh = b
			mat.albedo_color = Color(0.42, 0.32, 0.2)
		"chair_leg":
			var c := CylinderMesh.new()
			c.top_radius = 0.026
			c.bottom_radius = 0.034
			c.height = 0.5
			mesh = c
			mat.albedo_color = Color(0.38, 0.28, 0.18)
		"cash":
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 0.05, 0.12)
			mesh = b
			mat.albedo_color = Color(0.3, 0.45, 0.3)
		"health":
			var b := BoxMesh.new()
			b.size = Vector3(0.28, 0.14, 0.2)
			mesh = b
			mat.albedo_color = Color(0.85, 0.88, 0.9)
		"painkillers":
			var b := BoxMesh.new()
			b.size = Vector3(0.14, 0.08, 0.1)
			mesh = b
			mat.albedo_color = Color(0.9, 0.9, 0.85)
		"key":
			var b := BoxMesh.new()
			b.size = Vector3(0.16, 0.02, 0.1)
			mesh = b
			mat.albedo_color = Color(0.75, 0.78, 0.85)
			mat.metallic = 0.7
		"burner":
			var b := BoxMesh.new()
			b.size = Vector3(0.1, 0.02, 0.18)
			mesh = b
			mat.albedo_color = Color(0.12, 0.12, 0.14)
		_:
			var s := SphereMesh.new()
			s.radius = 0.12
			s.height = 0.24
			mesh = s
	mesh.material = mat
	mi.mesh = mesh
	mi.rotation.z = PI / 2.0 if kind in ["pipe", "bat", "plank", "chair_leg"] else 0.0
	_spin.add_child(mi)


## The class-coloured glow halo + a soft emissive floor ring so the
## pickup is visible at night without a real light.
func _build_glow(spec: Dictionary) -> void:
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(spec["glow"], 0.16)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	halo.mesh = q
	_spin.add_child(halo)
	var ring := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(0.7, 0.7)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(spec["glow"], 0.3)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tq.material = rm
	ring.mesh = tq
	ring.rotation = Vector3(-PI / 2.0, 0, 0)
	ring.position = Vector3(0, 0.02, 0)
	add_child(ring)


func _build_prompt(spec: Dictionary) -> void:
	_prompt = Label3D.new()
	_prompt.text = "[B] PICK UP %s" % spec["label"]
	_prompt.modulate = Color(1.0, 0.9, 0.55)
	_prompt.font_size = 44
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.outline_size = 10
	_prompt.outline_modulate = Color(0.02, 0.02, 0.03)
	_prompt.no_depth_test = true
	_prompt.visible = false
	_prompt.position = Vector3(0, 1.1, 0)
	add_child(_prompt)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false


func is_near() -> bool:
	return _near


## The player's grab chain calls this (B in the FIGHT scheme, the GRAB
## pill in the others). Short actions fire on the tap (Part 6D.3).
func try_use(p: Node3D) -> bool:
	if not _near:
		return false
	var spec: Dictionary = KINDS.get(kind, {})
	var label := str(spec.get("label", kind))
	if spec.get("class", "") == "weapon":
		var weapons := get_tree().root.get_node_or_null("/root/Weapons")
		if weapons:
			weapons.call("equip", kind)
		if p and p.has_method("arm_weapon"):
			p.call("arm_weapon")
	else:
		_apply_item(p, label)
	Sound.play("ui_confirm_0", -6.0, 1.15)
	Haptics.fire("light")
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("Picked up: %s" % label, 2.2)
	queue_free()
	return true


func _apply_item(_p: Node3D, label: String) -> void:
	match kind:
		"cash":
			Wallet.earn(maxi(amount, 20), "found: %s" % label)
		"health":
			var p := get_tree().get_first_node_in_group("player")
			if p:
				p.set("hp", minf(float(p.get("hp")) + float(maxi(amount, 2)), 10.0))
		"painkillers":
			var p2 := get_tree().get_first_node_in_group("player")
			if p2:
				p2.set("hp", minf(float(p2.get("hp")) + 1.0, 10.0))
		"key":
			Settings.set_value("has_key_card", true)
		"burner":
			Settings.set_value("has_burner", true)


func _process(delta: float) -> void:
	# the bob + slow spin: alive, findable, never a static dark box
	_t += delta
	if _spin:
		_spin.position.y = _base_y + 0.06 * sin(_t * 2.2)
		_spin.rotation.y += delta * 0.8
