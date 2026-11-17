extends Control
## Style meter (top-right). Mixing different moves - punches, dodges, parries,
## counters, slams, takedowns - raises the rank; repeating the same move gives
## sharply less. The rank multiplies the cash points earned by each move.
## Cash is stored as a number only for now (no shop until a later batch).

const BASE := {
	"jab": 6.0, "cross": 10.0, "dodge": 8.0, "parry": 18.0,
	"counter": 25.0, "slam": 35.0, "takedown": 15.0,
}
const RANKS := ["D", "C", "B", "A", "S"]
const MULT := [1.0, 1.2, 1.5, 2.0, 3.0]

var value := 0.0  # 0..500
var cash := 0
var _last := ""
var _repeats := 0
var _chain_until := -99.0

@onready var _rank: Label = $RankLabel
@onready var _bar: ProgressBar = $Bar
@onready var _cash: Label = $CashLabel


func _ready() -> void:
	add_to_group("style")
	_refresh()


func _process(delta: float) -> void:
	if value > 0.0:
		value = maxf(value - 10.0 * delta, 0.0)
		_refresh()


## Register a landed move; returns the points gained (for tests).
func add(move: String) -> float:
	var gain: float = BASE.get(move, 5.0)
	if move == _last:
		_repeats += 1
		gain *= 0.35 if _repeats == 1 else 0.12  # same move twice, then spam
	elif _t() < _chain_until:
		gain *= 1.2  # a varied chain earns a bonus
		_repeats = 0
	else:
		_repeats = 0
	_last = move
	_chain_until = _t() + 4.0
	value = minf(value + gain, 500.0)
	cash += int(round(gain * rank_mult()))
	_refresh()
	return gain


func rank() -> int:
	return int(minf(value, 499.0) / 100.0)


func rank_mult() -> float:
	return MULT[rank()]


func _refresh() -> void:
	_rank.text = "STYLE %s" % RANKS[rank()]
	_bar.value = value
	_cash.text = "$ %d   (x%.1f)" % [cash, rank_mult()]


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0
