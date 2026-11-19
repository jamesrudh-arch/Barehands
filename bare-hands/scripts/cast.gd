class_name Cast
extends Node3D
## The four faces of Cinder City. Each is a Node3D holding an NpcRig (real
## rigged UBC pieces, recoloured to a colour identity) and an interaction
## zone: GRAB near them to talk. Velvet's talk opens her gun counter after
## the lines. Names and personalities come from the owner's brief; the
## original design notes (docs/VISION.md) never arrived, so anything beyond
## the brief - Marrow's name, the exact lines - is marked as placeholder.

const VELVET := Color(0.75, 0.12, 0.2)      # crimson
const PILSNER := Color(0.15, 0.75, 0.65)    # hacker teal
const MARROW := Color(0.55, 0.08, 0.1)      # dried blood
const DUCHESS := Color(0.92, 0.78, 0.35)    # gold

var npcs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("cast")
	_spawn("Velvet", VELVET, "velvet",
			Vector3(11.8, 0.0, 4.6), PI * 0.75, 1.0,
			["res://assets/cast/Superhero_Female_FullBody.gltf",
			 "res://assets/cast/Female_Ranger_Body.gltf",
			 "res://assets/cast/Female_Ranger_Legs.gltf"],
			"Idle_Loop", 1.0, [], "velvet_lines")
	_spawn("Pilsner", PILSNER, "pilsner",
			Vector3(9.8, 0.0, -6.8), -PI * 0.35, 0.98,
			["res://assets/hero/Superhero_Male_FullBody.gltf",
			 "res://assets/cast/Male_Peasant_Body.gltf"],
			"Idle_Talking_Loop", 1.0, ["glasses"], "pilsner_lines")
	_spawn("Marrow", MARROW, "marrow",
			Vector3(3.0, 0.0, -7.6), PI, 1.22,
			["res://assets/hero/Superhero_Male_FullBody.gltf",
			 "res://assets/cast/Male_Knight_Body_Armor.gltf"],
			"Idle_Loop", 0.85, [], "marrow_lines")
	_spawn("The Duchess", DUCHESS, "duchess",
			Vector3(9.0, 3.42, -4.9), PI, 1.05,
			["res://assets/cast/Superhero_Female_FullBody.gltf",
			 "res://assets/cast/Female_Ranger_Body.gltf",
			 "res://assets/cast/Female_Ranger_Legs.gltf"],
			"Idle_Talking_Loop", 0.9, ["circlet"], "duchess_lines")


func _spawn(display: String, color: Color, voice_id: String, pos: Vector3,
		facing: float, scale: float, pieces: Array, idle: String,
		idle_speed: float, accessories: Array, lines_key: String) -> void:
	var npc := Node3D.new()
	npc.name = display
	npc.position = pos
	npc.rotation.y = facing
	npc.scale = Vector3(scale, scale, scale)
	add_child(npc)
	var rig := NpcRig.new()
	rig.name = "Rig"
	npc.add_child(rig)
	rig.build(pieces, color, color * 0.5, idle, idle_speed)
	if accessories.has("glasses"):
		rig.add_glasses(color)
	if accessories.has("circlet"):
		rig.add_circlet()
	# interaction zone
	var zone := Area3D.new()
	zone.name = "Zone"
	npc.add_child(zone)
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(2.4, 2.2, 2.4)
	shape.shape = cs
	shape.position = Vector3.UP * 1.1
	zone.add_child(shape)
	npcs.append({"node": npc, "zone": zone, "name": display, "color": color,
			"voice_id": voice_id, "lines_key": lines_key, "inside": false})
	zone.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_set_inside(display, true))
	zone.body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_set_inside(display, false))


func _set_inside(display: String, inside: bool) -> void:
	for n in npcs:
		if n.name == display:
			n.inside = inside


## The player asks: is there someone here to talk to? (single GRAB consumer)
func try_talk(player: Node3D) -> bool:
	if Dialogue.is_active():
		return true
	for n in npcs:
		if n.inside and player.global_position.distance_to(
				(n.node as Node3D).global_position) < 2.6:
			_talk(n)
			return true
	return false


func _talk(n: Dictionary) -> void:
	var lines := _lines_for(n)
	Dialogue.run(lines)
	if n.name == "Velvet":
		# her counter opens when the talk ends
		Dialogue.finished.connect(func() -> void:
			for s in get_tree().get_nodes_in_group("pawn_counter"):
				if s.has_method("_open") and s._panel == null:
					s._open()
		, CONNECT_ONE_SHOT)


func _lines_for(n: Dictionary) -> Array:
	var d := City.district_at((n.node as Node3D).global_position)
	var r: float = City.rep.get(d, 0.0)
	var base: Array = []
	match n.lines_key:
		"velvet_lines":
			base = [
				{"speaker": "Velvet", "color": VELVET, "voice_id": "velvet",
					"text": "You're the one burning through my neighbourhood. Bullets aren't sold, they're rented - from your wallet."},
				{"speaker": "Velvet", "color": VELVET, "voice_id": "velvet",
					"text": "Five dollars leaves you the moment the hammer drops. The ledger keeps the receipts. Browse."},
			]
			if r >= 40.0:
				base.append({"speaker": "Velvet", "color": VELVET, "voice_id": "velvet",
						"text": "The street likes you. So do I, a little. Prices stay honest."})
			elif r <= -25.0:
				base.append({"speaker": "Velvet", "color": VELVET, "voice_id": "velvet",
						"text": "The street doesn't like you. That makes my counters costlier. Business is business."})
		"pilsner_lines":
			base = [
				{"speaker": "Pilsner", "color": PILSNER, "voice_id": "pilsner",
					"text": "Every camera on this block is mine. Even the ones that aren't."},
				{"speaker": "Pilsner", "color": PILSNER, "voice_id": "pilsner",
					"text": "Heat's just information with a siren on it. Stay out of sight and even the police forget."},
			]
		"marrow_lines":
			base = [
				{"speaker": "Marrow", "color": MARROW, "voice_id": "marrow",
					"text": "The Knuckle Room runs on one rule: whoever's left standing set the price."},
				{"speaker": "Marrow", "color": MARROW, "voice_id": "marrow",
					"text": "You've got hands. Good. Irons come later - and they never come cheap."},
			]
		"duchess_lines":
			base = [
				{"speaker": "The Duchess", "color": DUCHESS, "voice_id": "duchess",
					"text": "No one is born with a gun, little shadow. Some of us are born holding the ledger."},
				{"speaker": "The Duchess", "color": DUCHESS, "voice_id": "duchess",
					"text": "Spend carefully. Every dollar you fire is a dollar I own a little less of."},
			]
	return base
