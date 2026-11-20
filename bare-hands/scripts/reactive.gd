extends Node
## The reactive city (bible 4I). The street does not just remember -
## it answers. Heat gets names: past "marked" a FIXER offers to make
## tonight disappear for real money; at "the war" someone who studied
## your tape walks in and moves like you (kicks heavy -> the fast
## blade, punches heavy -> the counter-puncher, and he has eaten as
## many hits as you have landed). Crowds are witnesses and alleys are
## not (Heat.add carries the multiplier). Every beat spent retells a
## rumor and the story grows. And the radio recaps what actually
## happened yesterday - your real peak heat, your real style, the
## street's real version of events.

const PUNCH_KINDS := ["jab", "cross", "hook", "super"]

## The fixer works the market gate (the kidnap marker pattern: a
## column you walk to, a price you either have or don't).
const FIXER_SPOT := Vector3(240.0, 0.02, -9.0)

var punches := 0
var kicks := 0
var launchers := 0
var peak_heat := 0.0        # today's high-water mark (the radio quotes it)
var yesterday_peak := 0.0

var _fixer_live := false     # the marker stands
var _fixer_done_today := false
var _fixer_mocked := false
var _fixer_marker: MeshInstance3D
var _copy: CharacterBody3D  # the style-copier, while he stands
var _last_copy_msec := -999999
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the style ledger (bible 4I: style-copying hitmen) - no player.gd
	# edits, the signal already tells the truth
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and p.has_signal("hit_landed"):
		(p as Node).connect("hit_landed", _on_hit_landed)
	# late player (suites instantiate main after boot): watch for it
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	# groups are not always set when node_added fires - the signal is the
	# discriminator: only the player's body speaks hit_landed
	if n is CharacterBody3D and n.has_signal("hit_landed") \
			and not n.is_connected("hit_landed", _on_hit_landed):
		n.connect("hit_landed", _on_hit_landed)


func _on_hit_landed(kind: String, _damage: int) -> void:
	if PUNCH_KINDS.has(kind):
		punches += 1
	elif kind == "launcher":
		launchers += 1
	else:
		kicks += 1  # kick, roundhouse, everything the legs do


func _process(delta: float) -> void:
	_t += delta
	peak_heat = maxf(peak_heat, Heat.heat)
	# the fixer: once a day, when the heat is worth his time
	if Heat.heat >= float(Tuning.v("fixer_at")) and not _fixer_live \
			and not _fixer_done_today:
		_open_fixer()
	if _fixer_live:
		_fixer_poll()
	# the copy: at "the war", on a cooldown, only one at a time
	if Heat.heat >= float(Tuning.v("copy_at")) \
			and not is_instance_valid(_copy) \
			and Time.get_ticks_msec() - _last_copy_msec \
					> int(Tuning.v("copy_cooldown_msec")):
		_spawn_copy()
	# the war's dead go with the war (mirrors Heat's own responder
	# cleanup - a downed copy must not lie in the street forever)
	if is_instance_valid(_copy) and (_copy as Enemy).state == Enemy.State.DOWN \
			and Heat.heat < 1.0:
		(_copy as Node).queue_free()
		_copy = null


# --- the fixer -------------------------------------------------------------------------


func fixer_cost() -> int:
	return int(Tuning.v("fixer_base")) \
			+ int(Tuning.v("fixer_per_heat")) * int(Heat.heat)


func _open_fixer() -> void:
	if _fixer_live:
		return  # one marker at a time (restore races the watcher)
	_fixer_live = true
	_fixer_mocked = false
	Phone.push_text("fixer", "THE FIXER: \"$%d and tonight never happened. \
Market gate. One hour, then the price climbs.\"" % fixer_cost())
	_fixer_marker = _marker(FIXER_SPOT, Color(0.35, 0.85, 0.5), 3.0)
	Log.info("Reactive: the fixer is in ($%d at the market gate)"
			% fixer_cost())


func _fixer_poll() -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null:
		return
	# he does not wait forever: gone at day roll, or when you pay
	if p.global_position.distance_to(FIXER_SPOT) < 1.8:
		var cost := fixer_cost()
		if Wallet.spend(cost, "the fixer", "bribe"):
			Heat.heat = 0.4
			_close_fixer()
			Phone.push_text("fixer", "THE FIXER: \"Pleasure. \
The street forgets by morning. So do I.\"")
			Log.info("Reactive: paid the fixer $%d - the heat dies" % cost)
		elif not _fixer_mocked:
			_fixer_mocked = true
			Phone.push_text("fixer", "THE FIXER: \"You're hot and broke. \
Worst combination in the city. Come back with paper.\"")
			Log.info("Reactive: the fixer laughed at the empty wallet")


func _close_fixer() -> void:
	_fixer_live = false
	_fixer_done_today = true
	if is_instance_valid(_fixer_marker):
		_fixer_marker.queue_free()
	_fixer_marker = null


# --- the style-copier ----------------------------------------------------------------------


## Your mirror (bible 4I): the kind mirrors your style, the hp has
## eaten as many hits as you have landed. He arrives with a name.
func _spawn_copy() -> void:
	var kind := 3 if kicks >= punches else 1  # legs -> the blade, hands -> the counter
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	e.set("kind", kind)
	e.set("max_hp", int(Tuning.v("copy_hp_base"))
			+ mini(8, int((punches + kicks + launchers) / 5)))
	get_tree().current_scene.add_child(e)
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p:
		e.global_position = p.global_position + Vector3(
				randf_range(6.0, 9.0) * (1.0 if randf() < 0.5 else -1.0),
				0.0, randf_range(-4.0, 4.0))
	_copy = e
	_last_copy_msec = Time.get_ticks_msec()
	var how := "he leads with his legs" if kind == 3 else "he counters like a boxer"
	Phone.push_text("fixer", "UNKNOWN LISTENER: \"someone's been studying \
your tape. %s. Watch his hands.\"" % how.capitalize())
	_hint("THE COPY - someone studied your tape. He moves like you.")
	Log.warn("Reactive: THE COPY walks in (kind %d, %d hp - you've landed \
%d punches, %d kicks, %d launchers)" % [kind, e.get("max_hp"),
			punches, kicks, launchers])


## The style report (tests + the radio read it).
func style_report() -> Dictionary:
	return {"punches": punches, "kicks": kicks, "launchers": launchers}


# --- the radio -------------------------------------------------------------------------------


## The morning recap, built from what actually happened: yesterday's
## peak heat, the style the street saw, the rumor the street tells.
## High heat names you; low heat keeps you anonymous.
func radio_lines() -> Array[String]:
	var out: Array[String] = []
	if yesterday_peak >= 4.0:
		out.append("ON THE RADIO: \"...the bare-handed man AGAIN, listeners. \
Third time this week they can't hold him...\"")
	elif yesterday_peak >= 2.0:
		out.append("ON THE RADIO: \"...witnesses describe a local man, \
no weapon, no colors. Police ask the public...\"")
	elif yesterday_peak >= 1.0:
		out.append("ON THE RADIO: \"...an incident on the east side. \
No arrests. No injuries reported...\"")
	if punches + kicks + launchers >= 20:
		var heavy: String = "kicks" if kicks >= punches else "hands"
		out.append("ON THE RADIO: \"...they say he fights with his %s. \
Coaches are calling. He isn't picking up...\"" % heavy)
	var heard := City.last_heard(Blocks._current)
	if heard != "":
		out.append("ON THE RADIO: \"...and the street's version: %s\"" % heard)
	return out


# --- the clock ----------------------------------------------------------------------------------


## Beats are retellings (bible 4I: rumors distort over Beats): each
## spent beat grows one live rumor by a tell.
func on_beat_spent() -> void:
	var live: Array = []
	for d in City.DISTRICTS:
		for e in City.witnessed.get(d, []):
			live.append([d, e])
	if live.is_empty():
		return
	var pick: Array = live[randi() % live.size()]
	var entry: Dictionary = pick[1]
	entry["tells"] = int(entry.get("tells", 0)) + 1


func on_day_rolled(_new_day: int) -> void:
	yesterday_peak = peak_heat
	peak_heat = 0.0
	if _fixer_live:
		_close_fixer()
	_fixer_done_today = false


# --- helpers --------------------------------------------------------------------------------------


func _marker(pos: Vector3, color: Color, h: float) -> MeshInstance3D:
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
	m.add_to_group("fixer_marker")
	get_tree().current_scene.add_child(m)
	return m


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, 3.4)


# --- persistence -------------------------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"punches": punches, "kicks": kicks, "launchers": launchers,
		"peak_heat": peak_heat, "yesterday_peak": yesterday_peak,
		"fixer_live": _fixer_live, "fixer_done_today": _fixer_done_today}


func from_dict(d: Dictionary) -> void:
	punches = int(d.get("punches", 0))
	kicks = int(d.get("kicks", 0))
	launchers = int(d.get("launchers", 0))
	peak_heat = float(d.get("peak_heat", 0.0))
	yesterday_peak = float(d.get("yesterday_peak", 0.0))
	_fixer_done_today = bool(d.get("fixer_done_today", false))
	if bool(d.get("fixer_live", false)):
		_open_fixer()  # the marker respawns with the save


func reset_for_test() -> void:
	punches = 0
	kicks = 0
	launchers = 0
	peak_heat = 0.0
	yesterday_peak = 0.0
	_copy = null
	_last_copy_msec = -999999
	if _fixer_live:
		_close_fixer()
	_fixer_done_today = false
