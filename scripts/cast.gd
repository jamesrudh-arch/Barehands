extends Node3D
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
## The named faces of Cinder City (B22: the bible's 16-name cast).
## Each is a Node3D holding an NpcRig (real rigged UBC pieces,
## recoloured to a colour identity) and an interaction zone: GRAB near
## them to talk. The bible's scope says "16 named persistent NPCs" but
## never lists them (docs/VISION.md never arrived), so the cast is
## derived from the bible's OWN world map - the four street faces from
## the owner's brief, plus the venue keepers, the friends (trust.gd),
## the law and the docks. Two of the sixteen live outside this node on
## purpose: SAUL is the brother (phone-only, the story's engine - a
## street body would contradict the kidnap arc) and VULTURE is the
## wall-leaning watcher (scripts/watcher.gd). This node carries the
## other fourteen street rigs.

const VELVET := Color(0.75, 0.12, 0.2)      # crimson
const PILSNER := Color(0.15, 0.75, 0.65)    # hacker teal
const MARROW := Color(0.55, 0.08, 0.1)      # dried blood
const DUCHESS := Color(0.92, 0.78, 0.35)    # gold
const MAMA_SUN := Color(1.0, 0.55, 0.15)    # wok-fire orange
const LITTLE_ASH := Color(0.3, 0.85, 0.9)   # noodle-steam cyan
const TAM := Color(0.95, 0.5, 0.65)         # apron pink
const RAZ := Color(0.85, 0.65, 0.2)         # beer-glass amber
const DRUNK := Color(0.5, 0.55, 0.3)        # olive
const OKAFOR := Color(0.15, 0.25, 0.7)      # gym navy
const KESSLER := Color(0.35, 0.4, 0.55)     # badge slate
const MECHANIC := Color(0.45, 0.55, 0.6)    # garage grey-blue
const CLUB_OWNER := Color(0.6, 0.3, 0.8)    # velvet-rope purple
const YUEN := Color(0.2, 0.7, 0.45)         # docks jade

const F_PIECES := ["res://assets/cast/Superhero_Female_FullBody.gltf",
	"res://assets/cast/Female_Ranger_Body.gltf",
	"res://assets/cast/Female_Ranger_Legs.gltf"]
const M_PIECES := ["res://assets/hero/Superhero_Male_FullBody.gltf",
	"res://assets/cast/Male_Peasant_Body.gltf"]
const M_ARMOR := ["res://assets/hero/Superhero_Male_FullBody.gltf",
	"res://assets/cast/Male_Knight_Body_Armor.gltf"]

var npcs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("cast")
	_spawn("Velvet", VELVET, "velvet",
			Vector3(11.8, 0.0, 4.6), PI * 0.75, 1.0, F_PIECES,
			"Idle", 1.0, [], "velvet_lines")
	_spawn("Pilsner", PILSNER, "pilsner",
			Vector3(9.8, 0.0, -6.8), -PI * 0.35, 0.98, M_PIECES,
			"Idle_Talking", 1.0, ["glasses"], "pilsner_lines")
	_spawn("Marrow", MARROW, "marrow",
			Vector3(3.0, 0.0, -7.6), PI, 1.22, M_ARMOR,
			"Idle", 0.85, [], "marrow_lines")
	_spawn("The Duchess", DUCHESS, "duchess",
			Vector3(9.0, 3.42, -4.9), PI, 1.05, F_PIECES,
			"Idle_Talking", 0.9, ["circlet"], "duchess_lines")
	# --- B22 living city: the venue keepers, friends, the law, the docks
	_spawn("Mama Sun", MAMA_SUN, "mama_sun",
			Vector3(-5.0, 0.0, 7.2), PI, 1.02, F_PIECES,
			"Idle_Talking", 1.0, [], "mama_lines")
	_spawn("Little Ash", LITTLE_ASH, "ash",
			Vector3(-7.6, 0.0, 7.6), PI * 0.9, 0.6, M_PIECES,
			"Idle", 1.3, [], "ash_lines")
	_spawn("Tam", TAM, "tam",
			Vector3(-3.2, 0.0, 8.8), PI, 0.96, F_PIECES,
			"Idle", 1.0, [], "tam_lines")
	_spawn("Raz", RAZ, "raz",
			Vector3(6.2, 0.0, 7.4), PI, 1.04, M_PIECES,
			"Idle_Talking", 0.9, [], "raz_lines")
	_spawn("The Drunk", DRUNK, "drunk",
			Vector3(7.8, 0.0, 7.0), PI * 1.1, 0.94, M_PIECES,
			"Idle", 0.45, [], "drunk_lines")
	_spawn("Coach Okafor", OKAFOR, "okafor",
			Vector3(-1.8, 0.0, -5.2), PI * 0.9, 1.14, M_PIECES,
			"Idle", 0.7, [], "okafor_lines")
	_spawn("Officer Kessler", KESSLER, "kessler",
			Vector3(2.6, 0.0, 5.6), PI, 1.06, M_ARMOR,
			"Idle", 0.8, [], "kessler_lines")
	_spawn("The Mechanic", MECHANIC, "mechanic",
			Vector3(12.8, 0.0, 8.0), PI * 0.8, 1.0, M_PIECES,
			"Idle", 0.9, ["glasses"], "mechanic_lines")
	_spawn("The Club Owner", CLUB_OWNER, "club_owner",
			Vector3(10.4, 0.0, 6.4), PI, 1.08, M_ARMOR,
			"Idle_Talking", 0.85, [], "club_lines")
	_spawn("Yuen", YUEN, "yuen",
			Vector3(13.6, 0.0, 4.2), -PI * 0.25, 1.0, M_PIECES,
			"Idle", 0.75, [], "yuen_lines")


func _spawn(display: String, color: Color, voice_id: String, pos: Vector3,
		facing: float, scale: float, pieces: Array, idle: String,
		idle_speed: float, accessories: Array, lines_key: String) -> void:
	var npc := Node3D.new()
	npc.name = display
	npc.position = pos
	npc.rotation.y = facing
	npc.scale = Vector3(scale, scale, scale)
	add_child(npc)
	var rig := CLS_NpcRig.new()
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
		"mama_lines":
			base = [
				{"speaker": "Mama Sun", "color": MAMA_SUN, "voice_id": "mama_sun",
					"text": "You live above my noodles and you still look hungry. Sit. First bowl is on the house - the second is on your ledger."},
				{"speaker": "Mama Sun", "color": MAMA_SUN, "voice_id": "mama_sun",
					"text": "I have fed every faction in this city at two in the morning. Nobody shoots at a woman who fed them. Remember that."},
			]
			if r <= -25.0:
				base.append({"speaker": "Mama Sun", "color": MAMA_SUN, "voice_id": "mama_sun",
						"text": "The street says you break things. Eat somewhere else until it stops saying that."})
		"ash_lines":
			base = [
				{"speaker": "Little Ash", "color": LITTLE_ASH, "voice_id": "ash",
					"text": "I know every alley, every camera and every debt in this district. Costs you a soda."},
				{"speaker": "Little Ash", "color": LITTLE_ASH, "voice_id": "ash",
					"text": "The Vulture guy by the wall? He's been writing down who goes in the bar. I saw him. Twice."},
			]
		"tam_lines":
			base = [
				{"speaker": "Tam", "color": TAM, "voice_id": "tam",
					"text": "Table four's got dockworkers in tonight, so keep your fists off the furniture. Mama just varnished it."},
				{"speaker": "Tam", "color": TAM, "voice_id": "tam",
					"text": "Tips go in the jar, not your pocket. The jar remembers. Everything in this city remembers."},
			]
		"raz_lines":
			base = [
				{"speaker": "Raz", "color": RAZ, "voice_id": "raz",
					"text": "The bar opens when I say and closes when the Duchess calls. You want a tab, you want a job, or you want trouble?"},
				{"speaker": "Raz", "color": RAZ, "voice_id": "raz",
					"text": "Word of advice, neighbour: the ones who drink slow are watching somebody. Look around next time."},
			]
		"drunk_lines":
			base = [
				{"speaker": "The Drunk", "color": DRUNK, "voice_id": "drunk",
					"text": "I'm not drunk, I'm... informants drink free, that's the arrangement, don't tell Kessler..."},
				{"speaker": "The Drunk", "color": DRUNK, "voice_id": "drunk",
					"text": "You're the brother's kid, aren't you. Same shoulders. He still owes me eleven dollars and a goodbye."},
			]
		"okafor_lines":
			base = [
				{"speaker": "Coach Okafor", "color": OKAFOR, "voice_id": "okafor",
					"text": "Talent is a rumour. Habits are real. Grab the dummy, review your MOVES, and I'll grade what you can keep."},
				{"speaker": "Coach Okafor", "color": OKAFOR, "voice_id": "okafor",
					"text": "The gym takes fighters who listen. The tournament takes fighters who win. The city takes whatever's left."},
			]
		"kessler_lines":
			base = [
				{"speaker": "Officer Kessler", "color": KESSLER, "voice_id": "kessler",
					"text": "Curfew's a story we tell tourists. But heat is real - mine. Every mess you make lands in MY ledger."},
				{"speaker": "Officer Kessler", "color": KESSLER, "voice_id": "kessler",
					"text": "I don't care who runs this block. I care how loud it gets. Stay quiet and we stay friendly."},
			]
			if Heat.heat >= 4.0:
				base.append({"speaker": "Officer Kessler", "color": KESSLER, "voice_id": "kessler",
						"text": "Your name's on three reports tonight. Disappear for a while or I start collecting."})
		"mechanic_lines":
			base = [
				{"speaker": "The Mechanic", "color": MECHANIC, "voice_id": "mechanic",
					"text": "Every car on this street, I know its engine note like a voice. Useful, when somebody wants a quiet ride."},
				{"speaker": "The Mechanic", "color": MECHANIC, "voice_id": "mechanic",
					"text": "You keep showing up when I need hands. That's how friendships start - ask your ledger, not me."},
			]
		"club_lines":
			base = [
				{"speaker": "The Club Owner", "color": CLUB_OWNER, "voice_id": "club_owner",
					"text": "The queue outside my door is the city's true parliament. Everyone votes with their patience."},
				{"speaker": "The Club Owner", "color": CLUB_OWNER, "voice_id": "club_owner",
					"text": "I book the fights, I book the DJs, I book the silence afterward. Which one are you shopping for?"},
			]
		"yuen_lines":
			base = [
				{"speaker": "Yuen", "color": YUEN, "voice_id": "yuen",
					"text": "The docks sleep with one eye open. Crates move at 3 AM and nobody signs anything."},
				{"speaker": "Yuen", "color": YUEN, "voice_id": "yuen",
					"text": "When you're ready to talk about the warehouse, you won't find me. I'll find you. That's how the docks say hello."},
			]
	return base
