extends Node
## The kidnap arc (bible 4H): the story spine. Someone takes the
## friend you trust most, an unknown number calls with a number, and
## the city gives you three days. The investigation is feet and eyes -
## three signs on three blocks, no combat until you find the site.
## The assault is the arena: three waves and the boss. Then the
## choice, on the phone, from them: cut them down (no money, a
## permanent enemy, the friend is yours forever) or take the payoff
## (the money, their patron, the friend gone and the city hollows).
## Both endings are real. So is doing nothing: the clock does not care.

signal changed()

const STATES := ["NONE", "HUNTING", "SITE", "ASSAULT", "CHOICE",
	"SAVED", "PAID", "LAPSED", "RANSOMED"]

## Authored signs (bible: authored voice, not signage): the friend's
## block front, the market gate, the foundry corner. The site is the
## old press hall in the foundry.
const CLUES := [
	{"district": "riverside", "pos": Vector3(-12.0, 0.02, -7.0),
		"text": "drag marks by the water. Two sets of boot heels."},
	{"district": "market", "pos": Vector3(252.0, 0.02, -7.0),
		"text": "a market witness: a van, water-stained, foundry plates."},
	{"district": "foundry", "pos": Vector3(470.0, 0.02, -7.0),
		"text": "a dropped burner phone. Last call: the old press hall."},
]
const SITE := Vector3(486.0, 0.02, -7.0)

## wave kinds (bible 4H: arena, waves, mini-boss). kind 4 = the boss.
const WAVES := [[1, 1], [1, 3], [1, 1, 3], [4]]

const TOUCH := 1.8

var state := "NONE"
var victim := ""
var days_left := 0
var clues: Array = [false, false, false]
var permanent_enemy := false
var patron := false

var _markers: Array = []    # live clue markers
var _site_marker: MeshInstance3D
var _spawned: Array = []
var _wave := -1
var _poll := 0.0
var _hud: Label
var _counted: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	changed.connect(_refresh_hud)


func _process(delta: float) -> void:
	# the kidnapper redials while you dodge them (bible 4C pressure)
	if state == "CALLED" and Phone.state == Phone.State.IDLE:
		Phone.ring("kidnapper", "cold")
	elif state == "CHOICE" and Phone.state == Phone.State.IDLE:
		Phone.ring("kidnapper", "payoff")
	if not ["HUNTING", "SITE", "ASSAULT"].has(state):
		return
	_poll += delta
	if _poll < 0.4:
		return
	_poll = 0.0
	# clue and site checks run while walking there; the assault logic
	# only once it starts
	_assault_poll_clues()
	_touch_site()
	if state == "ASSAULT":
		_assault_wave_poll()


# --- the trigger ------------------------------------------------------------------


## Eligible once the loop has teeth (day >= 3) and someone matters
## enough to take (trust >= 40). The world sim calls this on the day
## roll; the arc takes the friend you trust MOST - that is the point.
func maybe_begin() -> void:
	if state != "NONE":
		return
	if Ledger.day < int(Tuning.v("kidnap_min_day")):
		return
	var best := ""
	var best_v := -1.0
	for f in Trust.FRIENDS:
		if Trust.is_gone(f):
			continue
		if Trust.value(f) > best_v:
			best_v = Trust.value(f)
			best = f
	if best == "" or best_v < float(Tuning.v("kidnap_min_trust")):
		return
	victim = best
	days_left = int(Tuning.v("kidnap_days"))
	Phone.ring("kidnapper", "cold")  # queued behind a friend call: it still comes
	state = "CALLED"
	Log.info("Kidnap: cold call - they took %s (trust %.0f)"
			% [Trust.FRIENDS[victim]["name"], best_v])
	changed.emit()


## The phone hands the kidnapper's choices here (phone.choose wires it).
func on_call_choice(kind: String, option: String) -> void:
	if kind == "cold":
		match option:
			"pay_ransom":
				var price := int(Tuning.v("kidnap_ransom"))
				if Wallet.spend(price, "ransom: %s" % victim, "ransom"):
					state = "RANSOMED"
					Trust.add(victim, 15.0, "paid the ransom")
					Phone.push_text("kidnapper",
							"UNKNOWN NUMBER: \"Smart. %s is on a corner near you. \
We never met.\"" % Trust.FRIENDS[victim]["name"])
					Log.info("Kidnap: ransom paid ($%d) - %s walks home"
							% [price, victim])
					changed.emit()
				else:
					# empty pockets buy nothing: the hunt starts anyway
					Phone.push_text("kidnapper",
							"UNKNOWN NUMBER: \"You're broke. Then you hunt. \
Three days.\"")
					_begin_hunt()
			"trace":
				Phone.push_text("kidnapper",
						"UNKNOWN NUMBER: \"No cops. Cute. Three days, \
then we stop feeding them.\"")
				_begin_hunt()
	elif kind == "payoff" and state == "CHOICE":
		match option:
			"save":
				_save_them()
			"take":
				_take_the_money()


func _begin_hunt() -> void:
	state = "HUNTING"
	clues = [false, false, false]
	_spawn_clues()
	Phone.push_text("kidnapper", "UNKNOWN NUMBER: \"The street talks. \
Walk it. Signs are everywhere if you know how to read.\"")
	_hint("%s IS TAKEN - read the street (signs on three blocks)"
			% Trust.FRIENDS[victim]["name"].to_upper())
	Log.info("Kidnap: the hunt begins - three signs, %d days" % days_left)
	changed.emit()


# --- the investigation (no combat) --------------------------------------------------


func _spawn_clues() -> void:
	_clear_markers()
	for i in CLUES.size():
		if clues[i]:
			continue  # found signs stay found
		_markers.append(_marker(CLUES[i]["pos"], Color(0.85, 0.7, 0.3), 3.0,
				"clue_marker"))


func _marker(pos: Vector3, color: Color, h: float, group: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = h
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	m.material_override = mat
	m.position = pos + Vector3(0, h * 0.5, 0)
	m.add_to_group(group)
	get_tree().current_scene.add_child(m)
	return m


func _assault_poll_clues() -> void:
	if state != "HUNTING":
		return
	var p := _player()
	if p == null:
		return
	for i in CLUES.size():
		if clues[i]:
			continue
		if p.global_position.distance_to(CLUES[i]["pos"]) < TOUCH:
			clues[i] = true
			Phone.push_text("kidnapper", "THE SIGN: %s" % CLUES[i]["text"])
			_hint("SIGN %d/3 - %s" % [clues.count(true), CLUES[i]["text"]])
			Log.info("Kidnap: sign %d/3 found (%s)" % [clues.count(true),
					CLUES[i]["district"]])
			if clues.count(true) >= CLUES.size():
				_reveal_site()
			else:
				_spawn_clues()  # the found sign's marker comes down
			changed.emit()


func _reveal_site() -> void:
	state = "SITE"
	_clear_markers()  # the signs come down when they've said their piece
	_site_marker = _marker(SITE, Color(0.9, 0.3, 0.3), 5.0, "site_marker")
	Phone.push_text("kidnapper", "UNKNOWN NUMBER: \"The old press hall. \
Come alone. Come angry.\"")
	_hint("THE SITE - the old press hall, in the foundry")
	Log.info("Kidnap: the site is revealed - the press hall")
	changed.emit()


func _touch_site() -> void:
	if state != "SITE":
		return
	var p := _player()
	if p == null:
		return
	if p.global_position.distance_to(SITE) < TOUCH:
		state = "ASSAULT"
		_wave = -1
		_push_wave()
		_hint("THE ASSAULT - waves first, then the boss")
		Log.info("Kidnap: the assault begins")
		changed.emit()


# --- the assault --------------------------------------------------------------------


func _push_wave() -> void:
	_wave += 1
	if _wave >= WAVES.size():
		return  # handled by the poll
	for k in WAVES[_wave]:
		var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
		e.set("kind", k)
		get_tree().current_scene.add_child(e)
		e.global_position = Vector3(SITE.x + randf_range(-4.0, 4.0), 0.02,
				SITE.z + randf_range(-4.0, 4.0))
		_spawned.append(e)
	Log.info("Kidnap: wave %d/%d (%s)" % [_wave + 1, WAVES.size(),
			str(WAVES[_wave])])


func _assault_wave_poll() -> void:
	var alive := 0
	for e in _spawned.duplicate():
		if not is_instance_valid(e):
			_spawned.erase(e)
		elif (e as Enemy).state == Enemy.State.DOWN:
			if not _counted.has(e):
				_counted.append(e)
				# dragged off - a respawn must never join the next wave
				(e as Node).queue_free()
		else:
			alive += 1
	if alive == 0:
		if _wave >= WAVES.size() - 1:
			_the_choice()
		else:
			_push_wave()


func _the_choice() -> void:
	state = "CHOICE"
	_clear_entities()
	Phone.ring("kidnapper", "payoff")
	_hint("THE CHOICE - they're on the phone")
	Log.info("Kidnap: the boss is down - the payoff call comes in")
	changed.emit()


# --- the endings (both real) ---------------------------------------------------------


## Save them: no money, a permanent enemy, the friend is yours forever
## (bond locked Close - it cannot decay).
func _save_them() -> void:
	state = "SAVED"
	permanent_enemy = true
	Trust.add(victim, 30.0, "you cut them down")
	Trust.lock(victim)
	Phone.push_text("kidnapper", "UNKNOWN NUMBER: \"You take them, \
we take your city. Every door. Every day.\"")
	_hint("SAVED - %s is yours forever. So is the enemy."
			% Trust.FRIENDS[victim]["name"])
	Log.warn("Kidnap: SAVED - %s walks, the enemy is permanent" % victim)
	changed.emit()


## Take the money: the payoff, their patron, the friend gone, the
## city hollows (every block's rep drops - the streets feel sold).
func _take_the_money() -> void:
	state = "PAID"
	patron = true
	var pay := int(Tuning.v("kidnap_payoff"))
	Wallet.earn_dirty(pay, "kidnap payoff: %s" % victim)
	Trust.lose(victim)
	for d in City.DISTRICTS:
		City.add_rep(d, -15.0, "the payoff hollowed the block")
	Phone.push_text("kidnapper", "UNKNOWN NUMBER: \"Pleasure doing \
business. The %s's name is on your ledger now.\"" % victim)
	_hint("THE MONEY - $%d dirty. The %s is gone. The city knows."
			% [pay, Trust.FRIENDS[victim]["name"]])
	Log.warn("Kidnap: PAID - $%d, %s is gone, the city hollows" % [pay, victim])
	changed.emit()


## The clock (world sim day roll): three days, then they stop feeding
## them. Doing nothing is a decision too.
func on_day_rolled(_new_day: int) -> void:
	match state:
		"CALLED":
			# never answered: the hunt starts under them
			_begin_hunt()
			days_left = int(Tuning.v("kidnap_days")) - 1
		"HUNTING", "SITE", "ASSAULT", "CHOICE":
			days_left -= 1
			if days_left <= 0:
				_lapse()
			else:
				_hint("THE CLOCK - %d day(s) left" % days_left)
		"NONE":
			maybe_begin()
	changed.emit()


func _lapse() -> void:
	state = "LAPSED"
	Trust.lose(victim)
	_clear_entities()
	_clear_markers()
	Phone.push_text("kidnapper", "UNKNOWN NUMBER: \"You waited. \
They didn't.\"")
	Log.warn("Kidnap: LAPSED - %s is gone (the clock ran out)" % victim)
	changed.emit()


func morning_lines() -> Array[String]:
	var out: Array[String] = []
	match state:
		"HUNTING", "SITE":
			out.append("%s is still taken - %d day(s) on the clock"
					% [Trust.FRIENDS[victim]["name"], days_left])
		"ASSAULT":
			out.append("the press hall waits - %d day(s) on the clock" % days_left)
		"CHOICE":
			out.append("the phone knows the choice - %d day(s) left" % days_left)
		"LAPSED":
			out.append("%s is gone. The clock ran out."
					% Trust.FRIENDS[victim]["name"])
		"SAVED":
			out.append("%s walks free. So does your enemy."
					% Trust.FRIENDS[victim]["name"])
		"PAID":
			out.append("the payoff sits dirty in your pocket")
	return out


# --- helpers ---------------------------------------------------------------------------


func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_markers = []
	if is_instance_valid(_site_marker):
		_site_marker.queue_free()
	_site_marker = null


func _clear_entities() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_spawned = []
	_counted = []


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, 3.4)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_hud = Label.new()
	_hud.name = "ArcLine"
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	_hud.position = Vector2(14, 84)
	_hud.visible = false
	_hud.add_to_group("kidnap_hud")
	layer.add_child(_hud)


func _refresh_hud() -> void:
	var text := ""
	match state:
		"HUNTING":
			text = "TAKEN - %s - signs %d/3 (%d days)"
			text = text % [Trust.FRIENDS[victim]["name"], clues.count(true), days_left]
		"SITE":
			text = "TAKEN - the site is found (%d days)" % days_left
		"ASSAULT":
			text = "THE ASSAULT - wave %d/%d" % [_wave + 1, WAVES.size()]
		"CHOICE":
			text = "THE CHOICE - answer the phone"
	_hud.text = text
	_hud.visible = not text.is_empty()


# --- persistence ------------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"state": state, "victim": victim, "days_left": days_left,
		"clues": clues.duplicate(), "permanent_enemy": permanent_enemy,
		"patron": patron}


func from_dict(d: Dictionary) -> void:
	state = str(d.get("state", "NONE"))
	victim = str(d.get("victim", ""))
	days_left = int(d.get("days_left", 0))
	clues = d.get("clues", [false, false, false])
	permanent_enemy = bool(d.get("permanent_enemy", false))
	patron = bool(d.get("patron", false))
	if state == "HUNTING":
		_spawn_clues()
	elif state == "SITE":
		_site_marker = _marker(SITE, Color(0.9, 0.3, 0.3), 5.0, "site_marker")
	_refresh_hud()
	changed.emit()


func reset_for_test() -> void:
	_clear_entities()
	_clear_markers()
	state = "NONE"
	victim = ""
	days_left = 0
	clues = [false, false, false]
	permanent_enemy = false
	patron = false
	_refresh_hud()
	changed.emit()
