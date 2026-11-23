extends Node

## THE HEAT RESPONSE (S5.4): the design's tiered answer to crime -
## "crowds are witnesses, alleys are not" (02_MASTER_DESIGN). Every
## body that drops fires a crime event; walkers who SEE it panic and
## the street remembers (witness_mult) or it slides (alley_mult).
## At fixer_at the FIXER texts: his price is on the phone LEDGER
## economy - pay SAL THE FENCE at the fish market to scrub heat.
## At copy_at someone who studied your tape comes for you
## themselves: THE COPY (the enemy's own body, darker, harder).
## Quiet streets cool: heat bleeds away after a still beat.

const WITNESS_R := 12.0
const DECAY_DELAY_S := 45.0
const DECAY_RATE := 0.05  # heat per quiet second
const FENCE_AREA := "docks"
const FENCE_SPOT := Vector3(30.0, 0.05, -1.6)
const FENCE_R := 3.2

var _quiet_t := 0.0
var _last_heat := 0.0
var _fixer_out := false       # one offer per heat-wave
var _copy_cd_until := 0       # ticks msec; the next tape-student
var _copy: CharacterBody3D = null


func _ready() -> void:
	add_to_group("police")
	WorldState.event_fired.connect(_on_event)
	WorldState.changed.connect(_on_changed)


func _on_changed(key: String, value: Variant) -> void:
	if key != "heat":
		return
	var heat := float(value)
	if heat > _last_heat:
		_quiet_t = 0.0  # fresh crime resets the cool-down clock
	_last_heat = heat
	_tier_check()


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "crime":
		_witness_layer(data)


## The WITNESS LAYER: who saw it decides what it cost. Zero
## watchers = the alley mult (it slides); two or more = the crowd
## mult (violence in public reads worse). Seeing walkers panic.
func _witness_layer(data: Dictionary) -> void:
	var pos: Vector3 = data.get("pos", Vector3.ZERO)
	var base := float(data.get("base", 4.0))
	var watchers := 0
	for p in get_tree().get_nodes_in_group("pedestrian"):
		var n := p as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_to(pos) > WITNESS_R:
			continue
		watchers += 1
		if n.has_method("_flee_from"):
			n._flee_from(pos)  # the street saw it - RUN
	var mult := 1.0
	if watchers == 0:
		mult = Tuning.v("alley_mult")
	elif watchers >= 2:
		mult = Tuning.v("witness_mult")
	if mult != 1.0:
		# the enemy already bumped the base; apply the context
		WorldState.bump("heat", base * (mult - 1.0))
	Log.info("Police: crime at %s, %d watcher(s), mult x%.1f" % [
			str(pos), watchers, mult])


func _tier_check() -> void:
	var heat := float(WorldState.get_value("heat", 0.0))
	if heat <= 0.0:
		_fixer_out = false  # the wave is over; he'll text again
		return
	# tier 1: the fixer's text (one offer per heat-wave)
	if heat >= Tuning.v("fixer_at") and not _fixer_out:
		_fixer_out = true
		var price := fence_price(heat)
		WorldState.push_event("fixer_text", {
				"from": "VESPER",
				"msg": "Word travels. Sal can make it forget - "
						+ "$%d, fish market, tonight." % price})
		Log.info("Police: the fixer texts ($%d)" % price)
	# tier 2: the war - someone studied your tape
	if heat >= Tuning.v("copy_at") \
			and not _copy_alive() \
			and Time.get_ticks_msec() >= _copy_cd_until:
		_spawn_copy(heat)


func fence_price(heat: float) -> int:
	return int(Tuning.v("fixer_base")) \
			+ int(heat * Tuning.v("fixer_per_heat"))


## GRAB at the fence: cash scrubs heat. THE exit valve of the
## crime economy (and its money sink).
func try_fence(hero: Node3D) -> bool:
	if Game.area_id != FENCE_AREA:
		return false
	if hero == null or not is_instance_valid(hero):
		return false
	if hero.global_position.distance_to(FENCE_SPOT) > FENCE_R:
		return false
	var heat := float(WorldState.get_value("heat", 0.0))
	if heat <= 0.0:
		return false
	var price := fence_price(heat)
	var cash := float(WorldState.get_value("cash", 0.0))
	if cash < price:
		WorldState.push_event("fixer_text", {
				"from": "SAL",
				"msg": "Come back with $%d. Sal doesn't run a "
						+ "charity." % price})
		Log.info("Police: the fence declines ($%d < price)" % price)
		return true  # the verb consumed - he answered
	WorldState.set_value("cash", cash - price)
	WorldState.set_value("heat", 0.0)
	WorldState.push_event("fixer_text", {
			"from": "SAL",
			"msg": "Clean. Whatever it was - it never happened."})
	Log.info("Police: the fence scrubs heat for $%d" % price)
	return true


const CLS_Enemy := preload("res://scripts/npc/enemy.gd")


func _copy_alive() -> bool:
	# DOWNED counts as over (no_revive bodies never free) - the
	# cooldown must open on the KILL, not the queue_free
	return _copy != null and is_instance_valid(_copy) \
			and _copy.state != CLS_Enemy.State.DOWNED


## THE COPY: the enemy's own body, darker and harder - "someone
## studied your tape". It dies through the same take_hit chain; its
## body is still a body (the street saw THAT too - the war can
## escalate until you pay Sal or get quiet).
func _spawn_copy(heat: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") \
			as Node3D
	if hero == null:
		return
	# the cooldown starts at the SPAWN (probe-caught: the copy's
	# own death-crime re-entered _tier_check before _process could
	# set any cooldown - the war chained copy-to-copy instantly)
	_copy_cd_until = Time.get_ticks_msec() \
			+ int(Tuning.v("copy_cooldown_msec"))
	var cls := load("res://scripts/npc/enemy.gd") as GDScript
	var copy: CharacterBody3D = cls.new()
	copy.set_meta("npc_name", "TheCopy")
	copy.set_meta("npc_label", "THE COPY")
	# thug-class plus the study: a thug is 40 - the copy must
	# out-body the muscle it copied (the tuning key's base plus
	# the heat that summoned it)
	copy.set_meta("hp_max", 40.0 + Tuning.v("copy_hp_base")
			+ heat)
	copy.set_meta("no_revive", true)
	copy.set_meta("tint", Color(0.32, 0.28, 0.42))  # studied dark
	var ang := randf() * TAU
	copy.position = hero.global_position \
			+ Vector3(sin(ang), 0, cos(ang)) * 14.0
	get_tree().current_scene.add_child(copy)
	_copy = copy
	WorldState.push_event("fixer_text", {
			"from": "???",
			"msg": "Someone studied your tape. They move like you "
					+ "now."})
	Log.info("Police: THE COPY spawns (hp %.0f, heat %.1f)" % [
			float(copy.get_meta("hp_max")), heat])


func _process(delta: float) -> void:
	var heat := float(WorldState.get_value("heat", 0.0))
	if heat <= 0.0:
		_quiet_t = 0.0
		return
	_quiet_t += delta
	if _quiet_t >= DECAY_DELAY_S:
		WorldState.bump("heat", -DECAY_RATE * delta)
	# the copy's death opens the cooldown window (DOWNED counts -
	# no_revive bodies never free)
	if _copy != null and (not is_instance_valid(_copy)
			or _copy.state == CLS_Enemy.State.DOWNED):
		_copy = null
		_copy_cd_until = Time.get_ticks_msec() \
				+ int(Tuning.v("copy_cooldown_msec"))
