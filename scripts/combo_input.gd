extends Node
const CLS_ComboTable := preload("res://scripts/combo_table.gd")
const CLS_Player := preload("res://scripts/player.gd")
## The combo input buffer (combo pass PART 2), autoloaded as "ComboInput".
## Every logical face press (A/B/X/Y, emitted by the hero the moment the
## action fires) lands here with the stick direction of that beat. Presses
## expire after WINDOW seconds (0.5 s, widened by the level perk in PART 3).
## When the tail of the buffer matches an unlocked combo's sequence - with
## direction prefixes like "f+B" honoured - the combo fires on the player.
##
## Anti-mash: repeating one combo within SPAM_TRACK seconds scales its
## damage down (spam_factor); landing three DIFFERENT combos inside
## VARIETY_WINDOW pays a style bonus.

signal matched(combo_id: String)
signal variety_bonus(combo_ids: Array)

const WINDOW := 0.5          # seconds between presses (tunable)
const SPAM_TRACK := 12.0     # a combo's recent uses age out after this
const SPAM_MIN := 0.35       # damage floor for a spammed combo
const SPAM_STEP := 0.6       # each repeat multiplies by this
const VARIETY_WINDOW := 10.0
const VARIETY_NEEDED := 3

var _buf: Array = []          # [{tok, dir, t}]
var _uses: Dictionary = {}    # id -> [timestamps]
var _recent: Array = []       # [{id, t}] for the variety bonus
var _time := 0.0


func _ready() -> void:
	InputBus.face_pressed.connect(_on_face)
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	_prune()  # expired entries drop out even with no new press


## The current window, including the PART 3 level perk.
func window() -> float:
	var w := WINDOW
	var p := get_node_or_null("/root/Progression")
	if p and p.has_method("combo_window_bonus"):
		w += p.combo_window_bonus()
	return w


func _on_face(tok: String, dir: String) -> void:
	if InputBus.locked:
		return
	_buf.append({"tok": tok, "dir": dir, "t": _time})
	_prune()
	_match()


func _prune() -> void:
	var cutoff := _time - window()
	_buf = _buf.filter(func(e: Dictionary) -> bool: return e["t"] >= cutoff)


func tokens() -> Array:
	return _buf.map(func(e: Dictionary) -> String: return e["tok"])


func _match() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for c in CLS_ComboTable.ordered():
		if not _unlocked(c, player):
			continue
		if _tail_matches(c["seq"]):
			_consume((c["seq"] as Array).size())
			_record(c["id"])
			matched.emit(c["id"])
			return


func _unlocked(c: Dictionary, player: Node) -> bool:
	if c.get("requires_grab", false) \
			and player.get("state") != CLS_Player.State.GRAB \
			and not InputBus.grab_pending():
		return false
	if c.get("pipe", false) and not player.has_pipe:
		return false
	# the style gate (Batch 3): a combo fires only in the style that owns
	# it - the fundamentals (single presses) stay common to every style
	var st := get_node_or_null("/root/Styles")
	if st and c.has("style") and st.get("current") != c["style"]:
		return false
	var p := get_node_or_null("/root/Progression")
	if p and p.has_method("combo_unlocked"):
		return p.combo_unlocked(c["id"])
	return true


## Does the buffer's tail equal this sequence? Direction-prefixed entries
## ("f+A") must match both token and direction.
func _tail_matches(seq: Array) -> bool:
	if seq.size() > _buf.size():
		return false
	var start := _buf.size() - seq.size()
	for i in seq.size():
		var want: String = seq[i]
		var got: Dictionary = _buf[start + i]
		if "+" in want:
			var parts := want.split("+")
			if got["tok"] != parts[1] or got["dir"] != parts[0]:
				return false
		elif got["tok"] != want:
			return false
	return true


func _consume(n: int) -> void:
	_buf = _buf.slice(0, _buf.size() - n)


func _record(id: String) -> void:
	var now := _time
	if not _uses.has(id):
		_uses[id] = []
	(_uses[id] as Array).append(now)
	_uses[id] = (_uses[id] as Array).filter(func(t: float) -> bool: return now - t <= SPAM_TRACK)
	_recent.append({"id": id, "t": now})
	_recent = _recent.filter(func(e: Dictionary) -> bool: return now - e["t"] <= VARIETY_WINDOW)
	var distinct: Array = []
	for e in _recent:
		if not distinct.has(e["id"]):
			distinct.append(e["id"])
	if distinct.size() >= VARIETY_NEEDED:
		variety_bonus.emit(distinct)
		_recent.clear()  # one bonus per burst


## Damage scaling for a spammed combo: 1.0, 0.6, 0.36, then the floor.
func spam_factor(id: String) -> float:
	var now := _time
	var uses := 0
	if _uses.has(id):
		for t in _uses[id]:
			if now - t <= SPAM_TRACK:
				uses += 1
	return maxf(SPAM_MIN, pow(SPAM_STEP, uses - 1)) if uses > 0 else 1.0


func reset_for_test() -> void:
	_buf.clear()
	_uses.clear()
	_recent.clear()
