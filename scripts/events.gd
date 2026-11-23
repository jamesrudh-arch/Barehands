extends Node
const CLS_Wanderer := preload("res://scripts/wanderer.gd")
## B27: THE STREET HAPPENS TO ITSELF (mandate Section 16 - world
## events the city answers). One event at a time, spaced by quiet
## minutes, picked for the block the hero stands in:
##   DISPUTE - two citizens square up (angry faces, alternating
##     shouts, palm shoves); the pavement collects to watch, and the
##     story enters the city's memory the radio and smalltalk read.
##   BENDER  - two traffic cars kiss nose-to-tail on the lane; both
##     stand with hazards pulsing, the street looks, the lane waits.
##   SWEEP   - heat draws a cruiser: a slow police roll with beacons
##     trading halves; anyone ON the road clears it, the pavement
##     watches it pass, the city remembers it came.
## Every event writes itself into City.witnessed (the one memory the
## radio recap, the gossip chain and the smalltalk all read), so the
## street's story grows from what actually happened - the B23 world-
## memory law, extended to events nobody caused.
## Autoloaded as "Events". force(kind) is the shared director/suite
## hook; end_now() closes whatever is running.

signal event_began(kind: String)
signal event_ended(kind: String)

const DISPUTE_LEN := 16.0
const BENDER_LEN := 13.0
const SWEEP_LEN := 20.0
const FIRST_AT := 45.0        # quiet opening before the first event
const GAP_MIN := 55.0        # quiet seconds between events
const GAP_JITTER := 45.0

var _t := 0.0
var _active := ""
var _until := 0.0
var _next_at := FIRST_AT
var _shoo_t := 0.0
var _pair_a: Node3D = null
var _pair_b: Node3D = null
var _bend_a: Node3D = null
var _bend_b: Node3D = null
var _sweep: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## What the street is doing right now ("" = quiet).
func active() -> String:
	return _active


func _process(delta: float) -> void:
	# the game ships with the street live; suites that assert quiet-
	# street behaviours set "dynamic_events" false and OWN that
	# assumption (smoke_events runs the live street)
	if not bool(Settings.value("dynamic_events")):
		if _active != "":
			end_now()
		return
	_t += delta
	if _active != "":
		if _t < _until:
			_tick_active(delta)
		else:
			end_now()
		return
	# quiet street: the next event ripens (a small chance per second
	# past its mark - the director, not a metronome)
	if _t >= _next_at and randf() < delta * 0.08:
		fire_random()


func fire_random() -> bool:
	var kinds := ["dispute", "bender"]
	# the cruiser only rolls when the district actually runs hot
	if Heat != null and Heat.heat >= 2.0:
		kinds.append("sweep")
	kinds.shuffle()
	for k in kinds:
		if force(k):
			return true
	return false


## Start a specific event now (the director and the suite share it).
func force(kind: String) -> bool:
	if _active != "" or not is_inside_tree():
		return false
	match kind:
		"dispute":
			return _fire_dispute()
		"bender":
			return _fire_bender()
		"sweep":
			return _fire_sweep()
	return false


## Close whatever runs - the pair resolves, the cars resume, the
## cruiser drives on. Public: the suite, the day roll and the world
## sim all use it.
func end_now() -> void:
	if _active == "":
		return
	match _active:
		"dispute":
			if _pair_a and is_instance_valid(_pair_a):
				_pair_a.call("exit_dispute")
			if _pair_b and is_instance_valid(_pair_b):
				_pair_b.call("exit_dispute")
			_pair_a = null
			_pair_b = null
		"bender":
			for c in [_bend_a, _bend_b]:
				if c and is_instance_valid(c):
					c.remove_meta("bender")
					c.remove_meta("hz_t")
			_bend_a = null
			_bend_b = null
		"sweep":
			if _sweep and is_instance_valid(_sweep):
				Traffic.call("_recycle", _sweep)
			_sweep = null
	var kind := _active
	_active = ""
	_next_at = _t + GAP_MIN + randf() * GAP_JITTER
	emit_signal("event_ended", kind)
	Log.info("Events: the %s is over - the street exhales" % kind)


func _tick_active(delta: float) -> void:
	match _active:
		"dispute":
			# passersby keep collecting while it runs: the street
			# re-observes every couple of seconds
			if _pair_a and is_instance_valid(_pair_a) and fmod(_t, 2.5) < delta:
				_tell_street((_pair_a.global_position + _pair_b.global_position) * 0.5)
		"sweep":
			# the cruiser moves people as it rolls - every 0.8 s a
			# shoo radius travels with it (freed walkers ride the group
			# for a frame after they step indoors - skip the ghosts)
			_shoo_t += delta
			if _shoo_t > 0.8 and _sweep and is_instance_valid(_sweep):
				_shoo_t = 0.0
				for w in get_tree().get_nodes_in_group("wanderer"):
					var wn := w as Node3D
					if wn == null or not is_instance_valid(wn):
						continue
					wn.call("shoo", _sweep.global_position)


# --- the events -----------------------------------------------------------------------------


func _fire_dispute() -> bool:
	var calm := _calm_wanderers()
	if calm.size() < 2:
		return false
	# the closest calm pair on this block - neighbours argue
	var a: Node3D = calm[0]
	var b: Node3D = null
	for w in calm:
		if w == a:
			continue
		if b == null or w.global_position.distance_to(a.global_position) \
				< b.global_position.distance_to(a.global_position):
			b = w
	if b == null:
		return false
	var mid := (a.global_position + b.global_position) * 0.5
	a.call("enter_dispute", b)
	b.call("enter_dispute", a)
	_pair_a = a
	_pair_b = b
	_active = "dispute"
	_until = _t + DISPUTE_LEN
	_tell_street(mid)
	var d := City.district_at(mid)
	City.remember(d, "two of them squared up on the %s block" % d)
	emit_signal("event_began", "dispute")
	Log.info("Events: a dispute flares on the %s kerb" % d)
	return true


func _fire_bender() -> bool:
	var block := Blocks.current()
	if block == "" or not Traffic.LANE_Z.has(block):
		return false
	# two cars on ONE lane, one just behind the other
	var cars: Array = []
	for v in Traffic._pool:
		if is_instance_valid(v) and str((v as Node3D).get_meta("block", "")) == block:
			cars.append(v)
	for i in cars.size():
		for j in cars.size():
			if i == j:
				continue
			var ca := cars[i] as Node3D
			var cb := cars[j] as Node3D
			if ca.get_meta("east") != cb.get_meta("east"):
				continue
			var gap := absf(ca.position.x - cb.position.x)
			if gap > 2.5 and gap < 8.0:
				ca.set_meta("bender", true)
				cb.set_meta("bender", true)
				ca.set_meta("speed", 0.0)
				cb.set_meta("speed", 0.0)
				_bend_a = ca
				_bend_b = cb
				_active = "bender"
				_until = _t + BENDER_LEN
				var mid := (ca.global_position + cb.global_position) * 0.5
				_tell_street(mid)
				City.remember(City.district_at(mid),
						"two cars kissed on the %s street" % d_short(block))
				emit_signal("event_began", "bender")
				Log.info("Events: a fender-bender holds the %s lane" % block)
				return true
	return false


func _fire_sweep() -> bool:
	var block := Blocks.current()
	if block == "":
		return false
	var car := Traffic.spawn_sweep(block) as Node3D
	if car == null:
		return false
	_sweep = car
	_active = "sweep"
	_until = _t + SWEEP_LEN
	City.remember(City.district_at(car.global_position),
			"a cruiser rolled the %s block slow" % d_short(block))
	emit_signal("event_began", "sweep")
	Log.info("Events: the sweep is on - %s, beacons rolling" % block)
	return true


# --- helpers --------------------------------------------------------------------------------


## Everyone calm within earshot turns to look (mild: no fear face -
## theatre is not a threat).
func _tell_street(pos: Vector3) -> void:
	for w in get_tree().get_nodes_in_group("wanderer"):
		var wn := w as Node3D
		if wn == null or not is_instance_valid(wn):
			continue
		wn.call("observe_mild", pos)


func _calm_wanderers() -> Array:
	var out: Array = []
	var block := Blocks.current()
	for w in get_tree().get_nodes_in_group("wanderer"):
		var wn := w as Node3D
		if wn == null or not is_instance_valid(wn):
			continue
		if str(wn.get("block")) != block:
			continue
		var st: int = wn.get("_state")
		if st in [CLS_Wanderer.State.WALK, CLS_Wanderer.State.CROSS_WAIT,
				CLS_Wanderer.State.CROSSING, CLS_Wanderer.State.BROWSE,
				CLS_Wanderer.State.PHONE]:
			out.append(wn)
	return out


func d_short(block: String) -> String:
	return str(City.BLOCK_INFO.get(block, {}).get("name", block)).to_lower()
