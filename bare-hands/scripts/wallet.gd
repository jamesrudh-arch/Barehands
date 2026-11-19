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

var cash := START_CASH  # CLEAN money - laundered, spendable anywhere
var dirty := 0          # street money (bible 4G); launders at a cut
var entries: Array[Dictionary] = []
var gun_offered := false  # has the first-offer modal been shown?
var gun_owned := false


func _ready() -> void:
	Log.info("Wallet: ready, $%d" % cash)


## The HUD number: everything in both pockets.
func total() -> int:
	return cash + dirty


## Spend from clean first, then dirty - a lender takes both, so does
## the street. False (and no entry) if the pockets do not reach.
func spend(amount: int, item: String, kind := "purchase") -> bool:
	if total() < amount:
		Log.warn("Wallet: cannot spend $%d on %s (have $%d)" % [amount, item, total()])
		return false
	var from_dirty := maxi(amount - cash, 0)
	cash -= mini(amount, cash)
	dirty -= from_dirty
	_add(kind, item, -amount)
	return true


## Street earnings land in the dirty pocket (bible 4G: jobs pay dirty).
func earn_dirty(amount: int, item: String, kind := "earn") -> void:
	if amount <= 0:
		return
	dirty += amount
	_add(kind, item, amount)


func spend_dirty(amount: int, item: String, kind := "payment") -> void:
	amount = mini(amount, dirty)
	if amount <= 0:
		return
	dirty -= amount
	_add(kind, item, -amount)


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
		"balance": cash + dirty,
	}
	entries.append(entry)
	if entries.size() > 200:
		entries = entries.slice(entries.size() - 200)
	entry_added.emit(entry)
	changed.emit(cash, amount)


## For the save file (Series 2 Phase 5 persists this).
func to_dict() -> Dictionary:
	return {"cash": cash, "dirty": dirty, "gun_offered": gun_offered,
			"gun_owned": gun_owned, "entries": entries}


func from_dict(d: Dictionary) -> void:
	cash = int(d.get("cash", START_CASH))
	dirty = int(d.get("dirty", 0))
	gun_offered = bool(d.get("gun_offered", false))
	gun_owned = bool(d.get("gun_owned", false))
	entries.clear()
	for e in d.get("entries", []):
		entries.append(e)


func reset_for_test() -> void:
	cash = START_CASH
	dirty = 0
	entries.clear()
	gun_offered = false
	gun_owned = false
