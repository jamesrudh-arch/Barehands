extends Control
## Style meter (top-right). Mixing different moves - punches, dodges, parries,
## counters, slams, takedowns - raises the rank; repeating the same move gives
## sharply less. The rank multiplies the cash every move banks into the
## Wallet (the Bullet Ledger's money). The heat stars sit just below.

const BASE := {
	"jab": 6.0, "cross": 10.0, "dodge": 8.0, "parry": 18.0,
	"counter": 25.0, "slam": 35.0, "takedown": 15.0,
}
const RANKS := ["D", "C", "B", "A", "S"]
const MULT := [1.0, 1.2, 1.5, 2.0, 3.0]

var value := 0.0  # 0..500
var _last := ""
var _rank_shown := -1
var _repeats := 0
var _chain_until := -99.0

@onready var _rank: Label = $RankLabel
@onready var _bar: ProgressBar = $Bar
@onready var _cash: Label = $CashLabel
@onready var _heat: Label = $HeatLabel

## Cash now lives in the Wallet; the meter mirrors it for the HUD and tests.
var cash: int:
	get:
		return Wallet.cash


func _ready() -> void:
	add_to_group("style")
	Heat.changed.connect(_on_heat)
	_on_heat(Heat.heat)
	_refresh()


func _on_heat(h: float) -> void:
	if _heat:
		var stars := roundi(h)
		_heat.text = "HEAT  " + "*".repeat(stars) + "-".repeat(maxi(0, 5 - stars))


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
	Wallet.earn(int(round(gain * rank_mult())), move)
	_refresh()
	return gain


func rank() -> int:
	return int(minf(value, 499.0) / 100.0)


func rank_mult() -> float:
	return MULT[rank()]


func _refresh() -> void:
	var r := rank()
	_rank.text = "STYLE %s" % RANKS[r]
	if r != _rank_shown:  # rank pop-up: scale punch on change
		_rank_shown = r
		_rank.scale = Vector2(1.7, 1.7)
	_rank.scale = _rank.scale.lerp(Vector2.ONE, 0.2)
	_bar.value = value
	_cash.text = "$ %d   (x%.1f)" % [Wallet.cash, rank_mult()]


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0
