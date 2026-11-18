extends Node
## The player's money. Autoloaded as "Wallet" (see project.godot). Every
## transaction - earning from fights, buying, and every single bullet fired -
## is appended to the ledger with the running balance. The Bullet Ledger
## screen (scripts/ledger_ui.gd) prints this as a thermal receipt. This is
## the signature system: every bullet costs real money.

signal changed(cash: int, delta: int)
signal entry_added(entry: Dictionary)

const START_CASH := 150
const BULLET_COST := 5

var cash := START_CASH
var entries: Array[Dictionary] = []
var gun_offered := false  # has the first-offer modal been shown?
var gun_owned := false


func _ready() -> void:
	Log.info("Wallet: ready, $%d" % cash)


## Try to spend; false (and no entry) if there is not enough.
func spend(amount: int, item: String, kind := "purchase") -> bool:
	if cash < amount:
		Log.warn("Wallet: cannot spend $%d on %s (have $%d)" % [amount, item, cash])
		return false
	cash -= amount
	_add(kind, item, -amount)
	return true


func earn(amount: int, item: String, kind := "earn") -> void:
	if amount <= 0:
		return
	cash += amount
	_add(kind, item, amount)


## A bullet is not bought in batches: every shot spends, visibly.
func pay_for_shot() -> bool:
	return spend(BULLET_COST, ".38 round", "shot")


func bullet_cost() -> int:
	return BULLET_COST


func _add(kind: String, item: String, amount: int) -> void:
	var entry := {
		"time": Time.get_time_string_from_system().replace(" ", ""),
		"kind": kind,
		"item": item,
		"amount": amount,
		"balance": cash,
	}
	entries.append(entry)
	if entries.size() > 200:
		entries = entries.slice(entries.size() - 200)
	entry_added.emit(entry)
	changed.emit(cash, amount)


## For the save file (Series 2 Phase 5 persists this).
func to_dict() -> Dictionary:
	return {"cash": cash, "gun_offered": gun_offered, "gun_owned": gun_owned,
			"entries": entries}


func from_dict(d: Dictionary) -> void:
	cash = int(d.get("cash", START_CASH))
	gun_offered = bool(d.get("gun_offered", false))
	gun_owned = bool(d.get("gun_owned", false))
	entries.clear()
	for e in d.get("entries", []):
		entries.append(e)


func reset_for_test() -> void:
	cash = START_CASH
	entries.clear()
	gun_offered = false
	gun_owned = false
