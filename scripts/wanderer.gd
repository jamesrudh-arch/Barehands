extends Node3D
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
## B19: a real ambient citizen (the living-city directive, part 11).
## Each pedestrian walks the PAVEMENT graph of their block - along the
## sidewalk, crossing only at the crossing - with a day's small
## purposes: browsing shopfronts, waiting, talking on the phone,
## queueing at the club. A fight nearby splits the street: some watch,
## some hold up a phone, most give it distance and hurry on. Densities,
## clothing tints and walking speed come from the block, so the
## commercial street reads busier than the residential one and the
## docks read as workers. The old B18 loop-around-home walk is gone;
## the "wanderer" group and the rumor bubble stay (heat's witnesses
## and the mood-thinning count on them).

const TALK_RANGE := 3.6
const REACT_RANGE := 14.0
const CALM_AFTER := 6.0
const CROSSING_X := 0.0

## the walk line per block (sidewalk centre, block-local z)
const WALK_Z := {"riverside": 8.0, "market": 10.0, "foundry": 10.0}
## clothing tints per block - workers on the docks, shoppers in town
const TINTS := {
	"riverside": [Color(0.32, 0.30, 0.34), Color(0.26, 0.22, 0.2),
			Color(0.3, 0.24, 0.22), Color(0.22, 0.26, 0.3)],
	"market": [Color(0.45, 0.2, 0.3), Color(0.2, 0.35, 0.45),
			Color(0.5, 0.4, 0.18), Color(0.28, 0.3, 0.42),
			Color(0.4, 0.28, 0.2)],
	"foundry": [Color(0.75, 0.55, 0.15), Color(0.7, 0.5, 0.12),
			Color(0.35, 0.3, 0.25), Color(0.6, 0.45, 0.14)],
}
const BODIES_F := [
	["res://assets/cast/Superhero_Female_FullBody.gltf"],
	["res://assets/cast/Female_Ranger_Body.gltf",
			"res://assets/cast/Female_Ranger_Legs.gltf"],
]
const BODIES_M := [
	["res://assets/cast/Male_Peasant_Body.gltf"],
	["res://assets/hero/Superhero_Male_FullBody.gltf"],
	["res://assets/cast/Male_Knight_Body_Armor.gltf"],
]

enum State { WALK, CROSS_WAIT, CROSSING, BROWSE, PHONE, QUEUE, WATCH,
	FLEE, CHAT, ARGUE }

var block := "riverside"
var home := Vector3.ZERO
var queue_slot := Vector3.ZERO  # set for club-queue spawns
var partner: Node3D = null  # pairs walk together (blocks assigns)

var _state: State = State.WALK
var _target := Vector3.ZERO
# B23: pairs sometimes stop and TALK - two citizens, two bubbles, then
# they walk on. _chat_lead decides who speaks first.
var _chat_until := 0.0
var _chat_cooldown := 0.0
var _chat_started := 0.0
var _chat_lead := false
var _chat_line := ""
# B27: the argument state (events.gd picks the pair) - angry faces, an
# alternating exchange and a shove pose; the street stops to watch
var _dispute_with: Node3D = null
var _dispute_line := 0
var _dispute_next := 0.0
# B27: gossip - a witness TELLS the calm street; the listener keeps
# the story a minute and retells it as you pass
var _told_event := ""
var _told_until := 0.0
var _umbrella: MeshInstance3D = null

const CHAT_LINES := [
	"You see the club queue last night? Round the block.",
	"Kessler's collecting twice a month now. Twice.",
	"Three jobs on the board and none of them clean.",
	"Mama Sun raised the price of the big bowl. Scandal.",
	"The Mechanic says the grey sedan's been parked a week.",
	"Somebody put the Vulture's name in the ledger. Bold.",
	"I'm not paying the Duchess interest on interest. I'm not.",
	"Rain again. My shoes have opinions about rain.",
]
# B27: what a squared-up pair shouts across the kerb
const DISPUTE_LINES := [
	"You parked ON my case, friend. On it.",
	"Say it again. Say it to my face this time.",
	"Who do you think signs for your boxes, huh?",
	"The whole block heard you the first time. So did I.",
	"Walk away. Last courtesy tonight.",
]
# B27: how the street retells what it was told
const TOLD_PREFIX := [
	"You hear about it? %s",
	"Word is %s",
	"It's all over the street - %s",
]
var _target_side := 1.0
var _side := 1.0
var _pause_until := 0.0
var _alarm_until := 0.0
var _panic_from := Vector3.ZERO
var _react_kind := 0  # 0-3 watch, 4 record, 5+ flee
var _fear_face := false  # B25: the panic is on the face, not in a var
var _speed := 1.1
var _bubble: Label3D = null
var _said := ""
var _phone: MeshInstance3D = null
var _rig: CLS_NpcRig
var _lod_phase := 0
var _entered := false


func spawn() -> void:
	add_to_group("wanderer")
	position = home
	_side = signf(home.z) if absf(home.z) > 0.5 else 1.0
	_speed = randf_range(0.85, 1.3)
	_lod_phase = randi() % 4
	var female := randf() < 0.5
	var pieces: Array = BODIES_F[randi() % BODIES_F.size()] if female \
			else BODIES_M[randi() % BODIES_M.size()]
	var tints: Array = TINTS.get(block, TINTS["riverside"])
	var tint: Color = tints[randi() % tints.size()]
	_rig = CLS_NpcRig.new()
	_rig.build(pieces, tint, tint * 0.35, "Idle", _speed / 1.1)
	add_child(_rig)
	_bubble = Label3D.new()
	_bubble.modulate = Color(0, 0, 0, 0)
	_bubble.font_size = 30
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 8
	_bubble.position = Vector3(0, 2.3, 0)
	add_child(_bubble)
	if not Fx.hit_landed.is_connected(_on_hit_landed):
		Fx.hit_landed.connect(_on_hit_landed)
	if queue_slot != Vector3.ZERO:
		_state = State.QUEUE
		_pause_until = _now() + randf_range(25.0, 60.0)
	else:
		_pick_target()


func _exit_tree() -> void:
	if Fx != null and Fx.hit_landed.is_connected(_on_hit_landed):
		Fx.hit_landed.disconnect(_on_hit_landed)


## Fights are public: everyone within earshot picks a reaction and
## holds it a few seconds past the last blow.
func _on_hit_landed(_kind: String, pos: Vector3) -> void:
	if not is_inside_tree() or _entered:
		return
	if global_position.distance_to(pos) >= REACT_RANGE:
		return
	_alarm_until = _now() + CALM_AFTER
	_panic_from = pos
	if _state in [State.WATCH, State.FLEE] or _state == State.PHONE and _react_kind == 4:
		return  # already reacting
	_react_kind = randi() % 10
	if _react_kind <= 3:
		_state = State.WATCH
		_pause_until = _alarm_until
	elif _react_kind == 4:
		_state = State.PHONE  # the phone goes up: this is going online
		_pause_until = _alarm_until
	else:
		_state = State.FLEE
		_pick_flee_target()
	# B27 GOSSIP: the witness TELLS the calm street - a story travels
	# two kerbs before the city's own memory does. The runner doesn't
	# stop to chat; the watchers and the camera do.
	if _react_kind <= 4:
		var what := "somebody went down in the " + block
		for w in get_tree().get_nodes_in_group("wanderer"):
			var wn := w as Node3D
			if wn == null or wn == self or not is_instance_valid(wn):
				continue
			if wn.global_position.distance_to(global_position) < 6.0:
				wn.call("hear_gossip", what, pos)


## B27: a listener takes a story from a witness - no panic, just the
## retelling. The listener wasn't there; a minute later they still
## talk like they almost were.
func hear_gossip(event: String, _from: Vector3) -> void:
	if event.is_empty() or _state == State.FLEE:
		return
	_told_event = event
	_told_until = _now() + 75.0


## B27: events.gd squares two citizens up. The pair wears the angry
## face (the emotion law), trades lines across the kerb and shoves a
## palm every few beats. The street collects.
func enter_dispute(other: Node3D) -> void:
	if other == null or other == self:
		return
	_dispute_with = other
	_state = State.ARGUE
	_dispute_line = randi() % DISPUTE_LINES.size()
	_dispute_next = _now() + randf_range(0.9, 1.6)
	_bubble.modulate.a = 0.0
	_said = ""
	_rig.play("Idle", 0.2)
	_rig.face("angry")


## B27: the argument resolves (or events.gd calls time) - cooldown so
## the same pair doesn't snap straight back into it.
func exit_dispute() -> void:
	if _state == State.ARGUE:
		_rig.face("")
	_dispute_with = null
	if _state == State.ARGUE:
		_chat_cooldown = _now() + randf_range(14.0, 24.0)
		_pick_target()


## B27: a mild street alarm - a dispute across the way, a fender-bender,
## a cruiser rolling past. The street LOOKS (every time - a turning
## head is free), nobody runs, and no fear face: theatre is not a
## threat, and the emotion law stays honest.
func observe_mild(pos: Vector3) -> void:
	if not is_inside_tree() or _entered:
		return
	if global_position.distance_to(pos) > 14.0:
		return
	if _state in [State.FLEE, State.ARGUE, State.WATCH, State.PHONE,
			State.CHAT, State.QUEUE]:
		return
	_alarm_until = maxf(_alarm_until, _now() + 4.0)
	_panic_from = pos
	_react_kind = 6  # mild: no fear face (the gate keys on kinds 0-4)
	_state = State.WATCH
	_pause_until = _alarm_until


## B27: the cruiser moves people - anyone on the ROAD gets off it,
## the pavement just watches it pass.
func shoo(pos: Vector3) -> void:
	if not is_inside_tree() or _entered:
		return
	if _state in [State.FLEE, State.ARGUE]:
		return
	var d := global_position.distance_to(pos)
	if d > 8.0:
		return
	if absf(global_position.z) < 4.0:
		_alarm_until = maxf(_alarm_until, _now() + 3.0)
		_panic_from = pos
		_react_kind = 6
		_state = State.FLEE
		_pick_flee_target()
	else:
		observe_mild(pos)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	# the talk: close enough, one line, fading as you pass
	var d := global_position.distance_to(p.global_position)
	if d < TALK_RANGE:
		if _said.is_empty():
			# B27: a told story outranks the canned rumor while it is
			# fresh - the street retells what it was told
			if _now() < _told_until and not _told_event.is_empty():
				_said = TOLD_PREFIX[randi() % TOLD_PREFIX.size()] \
						% _told_event
				_said += "."
			else:
				_said = City.rumor_line(block)
			_bubble.text = _said
	else:
		_said = ""
	if _bubble:
		var want := clampf(1.0 - (d - TALK_RANGE) * 0.8, 0.0, 1.0) if d < TALK_RANGE + 1.5 else 0.0
		_bubble.modulate.a = lerpf(_bubble.modulate.a, want, delta * 4.0)
	# LOD: far citizens think every 4th frame (they are 40 m away)
	var far := d > 40.0
	if far and (Engine.get_physics_frames() + _lod_phase) % 4 != 0:
		return
	var step := delta * (4.0 if far else 1.0)
	# B25 the emotion law: while the alarm holds, the reacting states
	# WEAR fear (brows up, mouth open); when the street settles, the
	# face comes back down. The recorder filming it stays afraid - a
	# witness holds the look longer than the runner.
	# B27: _react_kind 6 is the MILD alarm (street theatre: a dispute,
	# a bender, a cruiser) - theatre is not a threat, no fear face.
	if _alarm_until > _now() and _react_kind != 6 \
			and _state in [State.WATCH, State.FLEE,
				State.PHONE, State.BROWSE]:
		if not _fear_face:
			_fear_face = true
			_rig.face("fear")
	elif _fear_face:
		_fear_face = false
		_rig.face("")
	match _state:
		State.WALK, State.CROSSING:
			_walk_step(step)
		State.CROSS_WAIT:
			_face(Vector3(_bx() + CROSSING_X, 0.0, -_side * _walk_z()), step)
			# B23: the walk sign decides - cars hold on WALK, so the
			# zebra is genuinely safe (a clear road with a red man is a
			# red man; this city has manners AND lights)
			if Traffic.walk_phase() and _crossing_clear():
				_target = Vector3(_bx() + CROSSING_X, 0.0, -_side * _walk_z())
				_state = State.CROSSING
		State.FLEE:
			_face(_target, step)
			global_position += _flat(_target - global_position).normalized() \
					* step * 3.4
			_clamp_to_block()
			if _flat(_target - global_position).length() < 0.5:
				_after_flee()
		State.CHAT:
			# face the buddy; the lead speaker holds the first half of
			# the exchange, the answer lands after - readable as you pass
			if partner != null and is_instance_valid(partner):
				_face(partner.global_position, step)
				var lead_talking := _now() < _chat_started \
						+ (_chat_until - _chat_started) * 0.5
				var show := (_chat_lead and lead_talking) \
						or (not _chat_lead and not lead_talking)
				if d < TALK_RANGE + 4.0 and show and not _chat_line.is_empty():
					_bubble.text = _chat_line
					_said = _chat_line  # keep the player-pass fade logic
				if _now() > _chat_until:
					_pick_target()
		State.ARGUE:
			# B27: the dispute - angry face, alternating shouts, a palm
			# shove every few beats. events.gd owns the clock.
			if _dispute_with == null or not is_instance_valid(_dispute_with):
				exit_dispute()
			else:
				_face(_dispute_with.global_position, step)
				if _now() > _dispute_next:
					_dispute_next = _now() + randf_range(1.6, 2.6)
					_dispute_line = (_dispute_line + 1) % DISPUTE_LINES.size()
					_rig.play("Push", 0.12, 0.9)  # the shove
				if d < TALK_RANGE + 4.0:
					_bubble.text = DISPUTE_LINES[_dispute_line]
					_said = DISPUTE_LINES[_dispute_line]
		State.BROWSE, State.PHONE, State.QUEUE, State.WATCH:
			if _state == State.QUEUE:
				_face(Vector3(queue_slot.x, 0.0, queue_slot.z - 2.0), step)
			elif _state == State.WATCH:
				_face(_panic_from, step)
			else:
				_face(global_position + Vector3(0, 0, _side), step)
			if _now() > _pause_until:
				if _state == State.QUEUE:
					_leave_queue()
				else:
					_pick_target()
	_settle_animations()


func _walk_step(step: float) -> void:
	var to := _flat(_target - global_position)
	if to.length() < 0.4:
		_arrive()
		return
	var dir := to.normalized()
	# a storm hurries the street (nobody window-shops in a downpour)
	var weather_k := 1.15 if Weather != null and Weather.intensity > 0.85 else 1.0
	global_position += dir * step * _speed * weather_k
	rotation.y = atan2(dir.x, dir.z)
	_clamp_to_block()


func _arrive() -> void:
	if _state == State.CROSSING:
		# the far kerb: back to the routine on the new side
		_side = -_side
		_pick_target()
		return
	if _target_side != _side:
		# a destination across the street: hold at the crossing first
		_state = State.CROSS_WAIT
		return
	# a same-side destination: a small life moment, maybe a shop door
	_side = _target_side
	if randf() < 0.12:
		_enter_building()
		return
	_state = State.BROWSE if randf() < 0.55 else State.PHONE
	_pause_until = _now() + randf_range(2.0, 7.0)


func _pick_target() -> void:
	# B23: some walks end in a conversation - a pair that is together
	# and off cooldown may stop and talk instead of walking on
	if partner != null and is_instance_valid(partner) \
			and global_position.distance_to(partner.global_position) < 3.2 \
			and _now() > _chat_cooldown \
			and partner.get("_state") in [State.WALK, State.CROSS_WAIT] \
			and randf() < 0.22:
		var dur := randf_range(4.5, 7.0)
		_chat_lead = true
		_chat_started = _now()
		_chat_until = _now() + dur
		_chat_cooldown = _chat_until + randf_range(18.0, 40.0)
		_chat_line = _street_line()
		_state = State.CHAT
		partner.set("_chat_lead", false)
		partner.set("_chat_started", _now())
		partner.set("_chat_until", _now() + dur)
		partner.set("_chat_cooldown", _chat_until + randf_range(18.0, 40.0))
		partner.set("_chat_line", CHAT_LINES[randi() % CHAT_LINES.size()])
		partner.set("_state", State.CHAT)
		return
	_state = State.WALK
	_target_side = -_side if randf() < 0.3 else _side
	# pairs keep each other's company most of the time
	if partner != null and is_instance_valid(partner) \
			and partner.get("_state") == State.WALK and randf() < 0.7:
		_target = (partner.get("_target") as Vector3) + Vector3(0.9, 0, 0)
		_target_side = partner.get("_target_side")
		return
	var dest_x := _bx() + (CROSSING_X if _target_side != _side
			else randf_range(-17.0, 17.0))
	_target = Vector3(dest_x, 0.0, _side * _walk_z())


func _pick_flee_target() -> void:
	var away := _flat(global_position - _panic_from)
	if away.length() < 0.05:
		away = Vector3(1, 0, 0)
	_target = Vector3(
			clampf(global_position.x + away.x * 14.0, _bx() - 18.0, _bx() + 18.0),
			0.0, _side * _walk_z())


func _after_flee() -> void:
	if _react_kind == 4:
		_state = State.PHONE  # the recorder keeps filming
		_pause_until = _alarm_until
	else:
		_state = State.BROWSE  # catch a breath, then back to the day
		_pause_until = _now() + randf_range(1.5, 4.0)


func _crossing_clear() -> bool:
	# nothing with wheels MOVING within 12 m of the crossing - a car
	# that has STOPPED is yielding to us (the courtesy runs both ways)
	for v in get_tree().get_nodes_in_group("traffic"):
		var vn := v as Node3D
		if vn == null or not is_instance_valid(vn):
			continue
		var sp = v.get_meta("speed")
		if sp != null and float(sp) < 1.5:
			continue  # stopped: it is letting us cross
		if absf(vn.global_position.x - (_bx() + CROSSING_X)) < 12.0:
			return false
	return true


func _clamp_to_block() -> void:
	global_position.x = clampf(global_position.x, _bx() - 19.0, _bx() + 19.0)
	var wz := _walk_z()
	if _state == State.CROSSING:
		# hold the crossing line while on the road
		global_position.x = lerpf(global_position.x, _bx() + CROSSING_X, 0.6)
	elif absf(global_position.z) < wz * 0.5 and _state == State.WALK:
		# never drift into the road outside the crossing
		global_position.z = _side * wz


func _enter_building() -> void:
	# a citizen steps into a shop and is gone; blocks re-staffs on its
	# poll, so the street keeps its numbers
	_entered = true
	if _bubble:
		_bubble.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(queue_free)


func _leave_queue() -> void:
	_pick_target()


func _face(at: Vector3, step: float) -> void:
	var to := _flat(at - global_position)
	if to.length() < 0.05:
		return
	var want := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(step * 4.0, 0.0, 1.0))


func _settle_animations() -> void:
	if _state in [State.WALK, State.CROSSING]:
		if _rig.current() != "Walk":
			_rig.play("Walk", 0.2, _speed / 1.1)
	elif _state == State.FLEE:
		if _rig.current() != "Walk":
			_rig.play("Walk", 0.1, 2.0)
	elif _state == State.ARGUE:
		pass  # B27: the dispute owns the rig - Idle stance, angry face,
		      # and the shove transients land and decay on their own
	elif _rig.current() != "Idle":
		_rig.play("Idle", 0.25)
	# the phone in the hand while phoning or recording - a real prop
	# riding the humanoid's hand joint, with the phone-hold pose
	var phone_up := _state == State.PHONE
	if phone_up and _phone == null:
		_phone = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.13)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.22, 0.28)
		m.emission_enabled = true
		m.emission = Color(0.55, 0.65, 0.8)
		m.emission_energy_multiplier = 0.35
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material = m
		_phone.mesh = q
		var hand: Node3D = _rig.call("hand", "r") if _rig and _rig.has_method("hand") else null
		if hand:
			hand.add_child(_phone)
			_phone.position = Vector3(0, -0.06, 0.06)
			_phone.rotation = Vector3(-1.3, 0, 0)
		else:
			add_child(_phone)
			_phone.position = Vector3(0.22, 1.15, 0.32)
		_rig.play("Phone", 0.2)
	elif not phone_up and _phone != null:
		_phone.queue_free()
		_phone = null
	# B27: the street answers heavy rain - a dark canopy snaps open
	# above the head and the walk hurries (the hurry is already the
	# storm's; the canopy is the new umbrella law). Dry air folds it.
	var canopy_ok := Weather != null and Weather.intensity > 0.75 \
			and not _entered \
			and _state in [State.WALK, State.CROSSING, State.CHAT,
				State.QUEUE, State.CROSS_WAIT, State.BROWSE, State.ARGUE]
	if canopy_ok and _umbrella == null:
		_umbrella = MeshInstance3D.new()
		_umbrella.name = "Umbrella"
		_umbrella.add_to_group("umbrella")
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.62
		cone.height = 0.15
		var m := StandardMaterial3D.new()
		# deep vinyl tones - a colour per soul, night-readable
		var picks := [Color(0.07, 0.08, 0.1), Color(0.16, 0.05, 0.06),
				Color(0.05, 0.1, 0.12)]
		m.albedo_color = picks[randi() % picks.size()]
		m.roughness = 0.85
		cone.material = m
		_umbrella.mesh = cone
		_umbrella.position = Vector3(0, 2.08, 0.06)
		add_child(_umbrella)
	elif not canopy_ok and _umbrella != null:
		_umbrella.queue_free()
		_umbrella = null


## B27: smalltalk tastes like the street it stands on - four lines in
## ten pull the newest thing the city actually remembers (a witnessed
## fight, a dispute, whatever happened), so conversations reference
## the real world instead of the canned eight.
func _street_line() -> String:
	var mem: Array = City.witnessed.get(block, [])
	if not mem.is_empty() and randf() < 0.4:
		var idx := maxi(0, mem.size() - 1 - randi() % mini(3, mem.size()))
		var e: Dictionary = mem[idx]
		var ev := str(e.get("event", ""))
		if not ev.is_empty():
			return "It's going around - %s." % ev
	return CHAT_LINES[randi() % CHAT_LINES.size()]


func _walk_z() -> float:
	return WALK_Z.get(block, 8.0)


func _bx() -> float:
	return Blocks.BLOCK_X.get(block, 0.0)


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v
