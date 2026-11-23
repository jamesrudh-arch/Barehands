extends Node

## THE WORLD-STATE AUTOLOAD (rebuild): ONE shared table + a bounded
## event queue (02_MASTER_DESIGN §10: no whole-city simulation —
## one table, an event queue, data-driven schedules). Everything
## persistent (broken doors, trust, heat, debt, prices, who calls,
## mission flags) lives HERE and nowhere else; the save file
## serialises this table verbatim.
##
## Stage-0 discipline: no dependencies on other autoloads.

signal changed(key: String, value: Variant)
signal event_fired(kind: String, data: Dictionary)

const MAX_EVENT_LOG := 64

var _table: Dictionary = {}
var _event_log: Array[Dictionary] = []


func _ready() -> void:
	reset()


func reset() -> void:
	_table.clear()
	_event_log.clear()


# --- the table --------------------------------------------------------------


func get_value(key: String, default: Variant = null) -> Variant:
	return _table.get(key, default)


func has(key: String) -> bool:
	return _table.has(key)


func set_value(key: String, value: Variant) -> void:
	if _table.get(key) == value:
		return
	_table[key] = value
	changed.emit(key, value)


func flag(key: String) -> bool:
	return bool(_table.get(key, false))


func set_flag(key: String, on := true) -> void:
	set_value(key, on)


## A numeric counter (heat ticks, debt paid, fights won...).
func bump(key: String, amount: float = 1.0) -> float:
	var v := float(_table.get(key, 0.0)) + amount
	set_value(key, v)
	return v


# --- the event queue --------------------------------------------------------


## Fire a world event: consumers subscribe to `event_fired`; the log
## keeps the last few for the save and the device report.
func push_event(kind: String, data: Dictionary = {}) -> void:
	var ev := {"kind": kind, "data": data, "t": Time.get_ticks_msec()}
	_event_log.append(ev)
	while _event_log.size() > MAX_EVENT_LOG:
		_event_log.pop_front()
	event_fired.emit(kind, data)


func event_log() -> Array[Dictionary]:
	return _event_log


# --- persistence -------------------------------------------------------------


func to_save() -> Dictionary:
	return {"table": _table.duplicate(true),
		"events": _event_log.duplicate(true)}


func from_save(d: Dictionary) -> void:
	reset()
	if d.has("table"):
		_table = d["table"]
	if d.has("events"):
		# JSON hands back a plain Array; rebuild the typed log
		# element-wise (a direct assign is a typed-array error)
		for e in d["events"]:
			if e is Dictionary:
				_event_log.append(e)
