extends Node
## The phone (bible 4C), autoloaded as "Phone". The device the whole
## pressure loop runs through: calls interrupt fights - the RING never
## pauses combat (answer in seconds while enemies swing; that is the
## tension), one answer per ring, declining has costs. Answering or
## opening the phone dims and slows the world (the style-wheel slow-mo
## pattern: re-issued, never dangling - the B4.0 watchdog lesson).
## Missed rings become replayable voicemails; friends pay for silence
## with Trust. Last Call redials once per run (once per act when acts
## exist). The map lives here too: fog of war per block, heat tinted.
##
## Leverage Clips (photo/clip blackmail) are NOT here: they ride on the
## job/ledger systems and stay a data slot until those batches land.
##
## The player is NOT invulnerable while the phone is open - same rule
## as the style wheel: the world crawls, exposure is the cost of use.

signal state_changed()  # the UI rebuilds everything on this
signal log_changed()

enum State { IDLE, RINGING, ON_CALL, OPEN }

const RING_BUZZ_EVERY_MSEC := 1400.0  # the slow low pulse (bible 4C)
const SLOW_KEEP_MSEC := 2500.0        # re-issue the slow-mo, watchdog-safe

## First-pass voice for the four friends (bible 4D roster); the lines
## are authored, not templated - they read like people, not signage.
const CALLS := {
	"brother": {
		"demand": {
			"lines": [
				"Brother: \"You alive? Good. The noodle shop rent came up short again.\"",
				"Brother: \"Landlord's kid brought friends. Forty buys him off this week.\"",
			],
			"choice": {"pay": "TRANSFER $40", "refuse": "NOT THIS WEEK"},
		},
		"invitation": {
			"lines": [
				"Brother: \"Rooftop. Tonight. Two hoops, no betting this time.\"",
				"Brother: \"You still remember which one's yours?\"",
			],
			"choice": {"in": "I'M IN", "out": "CAN'T TONIGHT"},
		},
	},
	"mechanic": {
		"demand": {
			"lines": [
				"The Mechanic: \"Parts don't shoplift themselves. Forty, tonight.\"",
			],
			"choice": {"pay": "TRANSFER $40", "refuse": "NOT THIS WEEK"},
		},
		"invitation": {
			"lines": [
				"The Mechanic: \"Bike's running. Docks loop, midnight, no cops.\"",
			],
			"choice": {"in": "I'M IN", "out": "CAN'T TONIGHT"},
		},
	},
	"club_owner": {
		"demand": {
			"lines": [
				"The Club Owner: \"The books have a hole shaped like you.\"",
				"The Club Owner: \"Forty. Or the hole gets a name.\"",
			],
			"choice": {"pay": "TRANSFER $40", "refuse": "NOT THIS WEEK"},
		},
		"invitation": {
			"lines": [
				"The Club Owner: " + "\"Slow night, good booth. Come drink where the lights can't read your face.\"",
			],
			"choice": {"in": "I'M IN", "out": "CAN'T TONIGHT"},
		},
	},
	"drunk": {
		"demand": {
			"lines": [
				"The Drunk: \"The bar tab remembers what I forget. Forty?\"",
			],
			"choice": {"pay": "TRANSFER $40", "refuse": "NOT THIS WEEK"},
		},
		"invitation": {
			"lines": [
				"The Drunk: \"The river remembers every promise. Come break bottles with me.\"",
			],
			"choice": {"in": "I'M IN", "out": "CAN'T TONIGHT"},
		},
	},
}

var state: State = State.IDLE
var _ring_caller := ""
var _ring_kind := ""  # "demand" | "invitation"
var _ring_deadline_msec := 0
var _ring_total_msec := 0
var _queued: Array = []  # at most one waiting ring: [caller, kind]
var _call_line_i := 0
var _call_logged := false  # choose() logs; hang_up() logs the plain answer
var _last_caller := ""
var _last_kind := ""
var _last_call_used := false  # once per run; per act when acts exist
var _log: Array = []  # newest first, capped
var _promises: Array = []  # accepted invitations, batch 7 redeems them
var _visited: Dictionary = {}  # district -> true (fog of war)
var _buzz_count := 0  # test hook: how many buzz pulses have fired

## The Ledger's lenders text too (bible 4G): the pressure reaches the
## pocket. Merged with friends by sender_id().
const LEDGER_SENDERS := {
	"family": {"name": "The Family", "color": Color(0.85, 0.35, 0.25)},
	"corp": {"name": "The Corporation", "color": Color(0.4, 0.75, 1.0)},
	"crew": {"name": "The Crew", "color": Color(0.9, 0.8, 0.35)},
}


## One lookup for every sender a text can come from.
func sender(id: String) -> Dictionary:
	if Trust.FRIENDS.has(id):
		return Trust.FRIENDS[id]
	return LEDGER_SENDERS.get(id, {})


func beats_left() -> int:
	return Ledger.beats_left
var _next_buzz_msec := 0
var _slow_next_msec := 0
var _ambient_acc := 0.0


func _ready() -> void:
	City.entered_district.connect(_on_district)
	# the UI builds itself onto a canvas layer; no scene wiring needed
	var ui: CanvasLayer = load("res://scripts/phone_ui.gd").new()
	ui.name = "PhoneUI"
	add_child(ui)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	match state:
		State.RINGING:
			if now >= _next_buzz_msec:
				Haptics.fire("buzz")  # the tension sound (bible 4C)
				_buzz_count += 1
				_next_buzz_msec = now + RING_BUZZ_EVERY_MSEC
			if now >= _ring_deadline_msec:
				_miss_ring()
		State.ON_CALL, State.OPEN:
			if now >= _slow_next_msec:
				Fx.slow_mo(3.5, 0.25)  # re-issued; the world crawls
				_slow_next_msec = now + SLOW_KEEP_MSEC
		State.IDLE:
			_ambient(delta)


# --- the ring -----------------------------------------------------------------


## Ring a friend. A ring while busy waits (one slot); Estranged friends
## do not get through at all (bible 4D: they stop calling).
func ring(caller: String, kind := "demand") -> bool:
	if not Trust.FRIENDS.has(caller):
		Log.warn("Phone: unknown caller '%s'" % caller)
		return false
	if Trust.tier(caller) == "estranged":
		Log.info("Phone: %s is estranged - no ring" % Trust.FRIENDS[caller]["name"])
		return false
	if state != State.IDLE:
		if _queued.size() == 0:
			_queued = [caller, kind]
		return false
	_ring_caller = caller
	_ring_kind = kind
	_ring_total_msec = int(Tuning.v("phone_ring_seconds") * 1000.0)
	_ring_deadline_msec = Time.get_ticks_msec() + _ring_total_msec
	_next_buzz_msec = 0  # the first buzz lands this frame
	_set_state(State.RINGING)
	Log.info("Phone: RING - %s (%s)" % [Trust.FRIENDS[caller]["name"], kind])
	return true


## The answer window as 0..1 (the banner's shrinking bar).
func ring_progress() -> float:
	if state != State.RINGING:
		return 0.0
	var left := _ring_deadline_msec - Time.get_ticks_msec()
	return clampf(float(left) / float(_ring_total_msec), 0.0, 1.0)


## One answer per ring (bible 4C): answering consumes the ring AND
## spends a Beat (bible, 30-min loop: every call/job/hangout costs 1).
## No beats left -> the answer is refused; the ring burns out alone.
func answer() -> bool:
	if state != State.RINGING:
		return false
	if not Ledger.spend_beat("call: %s" % _ring_caller):
		Log.info("Phone: no beats left - the call waits in voicemail")
		return false
	_last_caller = _ring_caller
	_last_kind = _ring_kind
	_ring_caller = ""
	_call_line_i = 0
	_call_logged = false
	_set_state(State.ON_CALL)
	InputBus.locked = true
	_slow_next_msec = 0  # the first slow-mo lands this frame
	return true


## Declining the ring costs the friendship (bible 4D: -6).
func decline() -> void:
	if state != State.RINGING:
		return
	Trust.add(_ring_caller, Trust.DECLINED_CALL, "declined the call")
	_log_entry({"caller": _ring_caller, "kind": _ring_kind, "outcome": "declined"})
	_ring_caller = ""
	_end_ring()


## The ring expired: a voicemail they will pay for (bible 4D: -6).
func _miss_ring() -> void:
	Trust.add(_ring_caller, Trust.MISSED_CALL, "missed the call")
	_log_entry({"caller": _ring_caller, "kind": _ring_kind, "outcome": "missed",
		"voicemail": _lines(_ring_caller, _ring_kind)})
	_ring_caller = ""
	_end_ring()


func _end_ring() -> void:
	if _queued.is_empty():
		_set_state(State.IDLE)
	else:
		var q: Array = _queued
		_queued = []
		_set_state(State.IDLE)
		ring(q[0], q[1])


# --- the call -----------------------------------------------------------------


func caller_id() -> String:
	return _ring_caller if state == State.RINGING else _last_caller


func call_kind() -> String:
	return _ring_kind if state == State.RINGING else _last_kind


func call_lines() -> Array:
	return _lines(caller_id(), call_kind())


func _lines(caller: String, kind: String) -> Array:
	if CALLS.has(caller) and CALLS[caller].has(kind):
		return (CALLS[caller][kind]["lines"] as Array).duplicate()
	return ["%s: \"...\"" % Trust.FRIENDS[caller]["name"]]


func call_line_i() -> int:
	return _call_line_i


func advance_line() -> bool:
	if state != State.ON_CALL:
		return false
	if _call_line_i < call_lines().size() - 1:
		_call_line_i += 1
		state_changed.emit()
		return true
	return false


func at_last_line() -> bool:
	return _call_line_i >= call_lines().size() - 1


func call_choice() -> Dictionary:
	if state != State.ON_CALL or not at_last_line():
		return {}
	var c: Dictionary = CALLS.get(caller_id(), {}).get(call_kind(), {})
	return c.get("choice", {})


## The on-call choice: "pay"/"refuse" for demands, "in"/"out" for
## invitations. Paying spends real money; refusing the ask costs less
## than declining the ring (they at least talked). Accepting an
## invitation is a promise the batch-7 hangouts redeem.
func choose(option: String) -> void:
	if state != State.ON_CALL or call_choice().is_empty():
		return
	_call_logged = true  # the choice outcome is this call's log entry
	match option:
		"pay":
			if Wallet.spend(int(Tuning.v("phone_demand_cost")), "phone: %s" % caller_id(), "demand"):
				_log_entry({"caller": caller_id(), "kind": call_kind(),
					"outcome": "paid", "amount": int(Tuning.v("phone_demand_cost"))})
			else:
				# empty wallet: the refusal is honest, not a dodge
				Trust.add(caller_id(), Trust.REFUSED_DEMAND, "could not pay")
				_log_entry({"caller": caller_id(), "kind": call_kind(),
					"outcome": "broke"})
		"refuse":
			Trust.add(caller_id(), Trust.REFUSED_DEMAND, "refused the ask")
			_log_entry({"caller": caller_id(), "kind": call_kind(),
				"outcome": "refused"})
		"in":
			_promises.append({"caller": caller_id(), "kind": call_kind()})
			_log_entry({"caller": caller_id(), "kind": call_kind(),
				"outcome": "promised"})
		"out":
			Trust.add(caller_id(), Trust.REFUSED_DEMAND, "backed out")
			_log_entry({"caller": caller_id(), "kind": call_kind(),
				"outcome": "backed out"})
	hang_up()


func hang_up() -> void:
	if state != State.ON_CALL:
		return
	# every answered call leaves a trace: the choice logged, or this
	if not _call_logged:
		_log_entry({"caller": caller_id(), "kind": call_kind(),
			"outcome": "answered"})
	_unlock()
	_set_state(State.IDLE)


# --- the apps -----------------------------------------------------------------


func open() -> void:
	if state == State.RINGING or state == State.ON_CALL:
		return
	InputBus.locked = true
	_slow_next_msec = 0
	_set_state(State.OPEN)


func close() -> void:
	if state != State.OPEN:
		return
	_unlock()
	_set_state(State.IDLE)


func toggle_open() -> void:
	if state == State.OPEN:
		close()
	else:
		open()


## Last Call (bible 4C): redial the last number, once. Per act when the
## act system exists; per run until then.
func last_call_redial() -> bool:
	if _last_call_used or _last_caller == "":
		return false
	_last_call_used = true
	Log.info("Phone: LAST CALL -> %s" % _last_caller)
	return ring(_last_caller, _last_kind)


func last_call_ready() -> bool:
	return not _last_call_used and _last_caller != ""


## Countdown texts and every future ledger pressure ride this pipe: the
## log renders them; nothing fakes entries that do not exist.
func push_text(caller: String, text: String, countdown_s := 0.0) -> void:
	if sender(caller).is_empty():
		Log.warn("Phone: text from unknown '%s'" % caller)
		return
	_log_entry({"caller": caller, "kind": "text", "outcome": "text",
		"text": text, "countdown": countdown_s})


func log_entries() -> Array:
	return _log


func promises() -> Array:
	return _promises


func has_visited(district: String) -> bool:
	return _visited.get(district, false)


func _on_district(district: String, _mood: String) -> void:
	# (district, mood): the signal carries both; the fog only needs the name
	if not _visited.get(district, false):
		_visited[district] = true
		Log.info("Phone: map unfogged - %s" % district)
		log_changed.emit()


# --- ambient rings ---------------------------------------------------------------
## A friend calls now and then (the pressure loop, bible 4C). Only when
## calm: mid-fight rings come from the story, not the scheduler.


func _ambient(delta: float) -> void:
	if _last_caller == "":
		return  # nobody has your number until the story gives it out
	_ambient_acc += delta
	if _ambient_acc < Tuning.v("phone_ambient_s"):
		return
	_ambient_acc = 0.0
	var p := get_tree().get_first_node_in_group("player")
	if p == null or p.state != 0:  # 0 = State.GROUND on the player
		return
	if Heat.heat >= 1.5:
		return
	var options := Trust.callers()
	if options.is_empty():
		return
	if randf() < 0.35:
		ring(options[randi() % options.size()], "demand" if randf() < 0.5 else "invitation")


# --- plumbing ------------------------------------------------------------------


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit()


func _unlock() -> void:
	InputBus.locked = false
	Fx.end_slow_mo()


func _log_entry(entry: Dictionary) -> void:
	entry["t"] = Time.get_unix_time_from_system()
	_log.push_front(entry)
	if _log.size() > 20:
		_log.resize(20)
	log_changed.emit()


func to_dict() -> Dictionary:
	var log_out: Array = []
	for e in _log.slice(0, 12):
		log_out.append(e)
	return {
		"log": log_out,
		"visited": _visited.duplicate(),
		"last_caller": _last_caller,
		"last_kind": _last_kind,
		"last_call_used": _last_call_used,
		"promises": _promises.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	_log = (d.get("log", []) as Array).duplicate()
	_visited = (d.get("visited", {}) as Dictionary).duplicate()
	_last_caller = str(d.get("last_caller", ""))
	_last_kind = str(d.get("last_kind", "demand"))
	_last_call_used = bool(d.get("last_call_used", false))
	_promises = (d.get("promises", []) as Array).duplicate()
	log_changed.emit()


func reset_for_test() -> void:
	if state != State.IDLE:
		_ring_caller = ""
		_queued = []
		_unlock()
	state = State.IDLE
	_log = []
	_promises = []
	# _visited SURVIVES: the walked map is ground truth about the city,
	# not phone state - CLEAR PHONE forgets calls, not streets
	_last_caller = ""
	_last_kind = ""
	_last_call_used = false
	_buzz_count = 0
	_ambient_acc = 0.0
	Trust.reset_for_test()
	log_changed.emit()
	state_changed.emit()
