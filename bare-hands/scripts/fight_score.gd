extends Node
## FightScore (Batch 2, bible 2-min loop): per-fight Style Rank D..S.
## When combat resolves it reads the fight's story - VARIETY of moves, NO
## DAMAGE taken, clean COUNTERS, ENVIRONMENT takedowns, speed - and deals
## a rank. S-rank pays down debt (5% of principal) once the Ledger batch
## lands; until then each S banks here as pending. The replay clip of the
## best 10 s combo is a STRETCH item, tracked in TESTING.md.
##
## The scoring itself is a pure function (score()) so the logic tests can
## verify the math without a fight; this autoload only tracks stats and
## shows the card. Music's state machine is the fight boundary: entering
## COMBAT from EXPLORE/RESOLVE starts a fresh fight (TENSION->COMBAT is
## the same fight); entering RESOLVE deals the rank.

signal fight_ranked(rank: int, score: float, stats: Dictionary)

const RANKS := ["D", "C", "B", "A", "S"]
const RANK_AT := [15.0, 35.0, 55.0, 75.0]  # score needed for C, B, A, S

var pending_s_ranks := 0  # the Ledger batch will pay these down
var last_rank := -1

var _tags: Dictionary = {}  # unique style tags this fight
var _counters := 0
var _env_takedowns := 0
var _takedowns := 0
var _hits_taken := 0
var _fight_start_msec := 0
var _in_fight := false
var _card: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	match Music.state:
		Music.State.COMBAT:
			if not _in_fight:
				_in_fight = true
				_fight_start_msec = Time.get_ticks_msec()
				_tags = {}
				_counters = 0
				_env_takedowns = 0
				_takedowns = 0
				_hits_taken = 0
		Music.State.RESOLVE:
			if _in_fight:
				_in_fight = false
				_resolve_fight()
		_:
			pass


## Style tags flow through StyleMeter.add - one hook covers variety,
## counters (counter/backfist_counter), environment (slam_*) and
## takedowns, from the hero AND from enemies (dodge/parry style).
func move(tag: String) -> void:
	if not _in_fight:
		return
	_tags[tag] = true
	if tag in ["counter", "backfist_counter"]:
		_counters += 1
	if tag.begins_with("slam") or tag == "slam":
		_env_takedowns += 1
	if tag in ["takedown", "finisher", "posture"]:
		_takedowns += 1


func hit_taken() -> void:
	if _in_fight:
		_hits_taken += 1


## Pure math, unit-testable: stats = {tags: int (unique), counters: int,
## env: int, takedowns: int, hits_taken: int, seconds: float}.
static func score(stats: Dictionary) -> Dictionary:
	var breakdown := {}
	breakdown["variety"] = minf(4.0 * int(stats.get("tags", 0)), 40.0)
	var hits: int = stats.get("hits_taken", 0)
	breakdown["no_hit"] = 20.0 if hits == 0 else (10.0 if hits <= 2 else 0.0)
	breakdown["counters"] = minf(5.0 * int(stats.get("counters", 0)), 15.0)
	breakdown["environment"] = minf(6.0 * int(stats.get("env", 0)), 12.0)
	breakdown["takedowns"] = minf(3.0 * int(stats.get("takedowns", 0)), 12.0)
	var secs: float = stats.get("seconds", 999.0)
	breakdown["speed"] = 6.0 if secs < 25.0 else (3.0 if secs < 45.0 else 0.0)
	var total := 0.0
	for k in breakdown:
		total += breakdown[k]
	var rank := 0
	for i in RANK_AT.size():
		if total >= RANK_AT[i]:
			rank = i + 1
	return {"total": total, "rank": rank, "breakdown": breakdown}


func _resolve_fight() -> void:
	var stats := {
		"tags": _tags.size(),
		"counters": _counters,
		"env": _env_takedowns,
		"takedowns": _takedowns,
		"hits_taken": _hits_taken,
		"seconds": (Time.get_ticks_msec() - _fight_start_msec) / 1000.0,
	}
	var result := score(stats)
	last_rank = result["rank"]
	if result["rank"] >= 4:
		pending_s_ranks += 1
	fight_ranked.emit(result["rank"], result["total"], stats)
	Log.info("FightScore: rank %s (%.0f) - %s" % [RANKS[result["rank"]],
			result["total"], stats])
	_show_card(result, stats)


## The rank card: a code-built overlay, centre screen, ~3.5 s. No assets.
func _show_card(result: Dictionary, stats: Dictionary) -> void:
	if _card != null:
		_card.queue_free()
	_card = CanvasLayer.new()
	_card.layer = 90
	add_child(_card)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	_card.add_child(vbox)
	var big := Label.new()
	var rk: int = result["rank"]
	big.text = "RANK  %s" % RANKS[rk]
	big.add_theme_font_size_override("font_size", 44 if rk < 4 else 56)
	big.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.25) if rk >= 4 else Color(0.9, 0.9, 0.92))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(big)
	if rk >= 4:
		var debt := Label.new()
		debt.text = "S-RANK - 5% of the balance, off the debt"
		debt.add_theme_font_size_override("font_size", 15)
		debt.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(debt)
	var b: Dictionary = result["breakdown"]
	var lines := [
		"variety %d moves" % stats["tags"],
		"hits taken %d" % stats["hits_taken"],
		"counters %d   env %d" % [stats["counters"], stats["env"]],
		"takedowns %d   %.0f s" % [stats["takedowns"], stats["seconds"]],
	]
	for text in lines:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(vbox, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_card.queue_free)


## Tests and the instant retry wipe the slate.
func reset() -> void:
	_tags = {}
	_counters = 0
	_env_takedowns = 0
	_takedowns = 0
	_hits_taken = 0
	_in_fight = false
	last_rank = -1
