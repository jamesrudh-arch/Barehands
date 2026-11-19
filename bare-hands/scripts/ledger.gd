extends Node
## The Ledger (bible 14 + 4G + the 30-min loop), autoloaded as "Ledger".
## The debt book the whole pressure economy turns on: three lenders, a
## live interest counter that never stops (real time - slow-mo does not
## save you), three Beats a day (Dusk, Midnight, 3 AM) spent by calls,
## jobs and hangouts - only the clock turns the day, so a burned day
## means waiting. A day ends with interest unpaid -> a missed payment;
## three of those ->
## DEFAULT: the whole city turns hostile and the heat pins high. Death
## adds $800 to The Family (they are the ones who patch you up), and
## every banked S-rank cuts 5% off the balance. Dirty money launders
## through the Club Owner at a 20% cut. The Ledger always shows Trust,
## so outcomes stay earned and visible (the phone's LEDGER app renders
## this book; scripts/ledger_ui.gd stays the Bullet Ledger receipt).
##
## Bible numbers: start 5000 (the 3500/1500 split is a first-pass call,
## the bible gives only the total); Family 3%/day, Corporation 8%/day,
## Crew 0%; jobs pay 400-1500 dirty (jobs batch); death debt 800.
## Deferred 4B FULL tier: lender gear (debt-ticking bullets), collectors
## inside fights, scarred style, kill-switches - see STATE.json.

signal changed()

const BEATS := ["DUSK", "MIDNIGHT", "3 AM"]

const LENDERS := {
	"family": {"name": "The Family", "color": Color(0.85, 0.35, 0.25),
		"line": "backup on call, a cut of everything, no guns in their sight"},
	"corp": {"name": "The Corporation", "color": Color(0.4, 0.75, 1.0),
		"line": "the tech money, 8% a day, a kill-switch on late payers"},
	"crew": {"name": "The Crew", "color": Color(0.9, 0.8, 0.35),
		"line": "free help that gets hurt doing it"},
}

var debt := {}            # lender id -> balance
var day := 1
var beats_left := 3
var missed_payments := 0
var defaulted := false
var debt_free_noted := false

var _interest_today := 0.0  # what today has cost so far
var _paid_today := 0.0      # what today has been paid back
var _day_acc := 0.0         # real seconds into today (3 beats = a day)
var _tick_count := 0        # test hook: faint debt-tick pulses fired


func _ready() -> void:
	_reset_debt()


func _reset_debt() -> void:
	debt = {
		"family": float(Tuning.v("debt_start_family")),
		"corp": float(Tuning.v("debt_start_corp")),
		"crew": 0.0,
	}
	day = 1
	beats_left = 3
	missed_payments = 0
	defaulted = false
	debt_free_noted = false
	_interest_today = 0.0
	_paid_today = 0.0
	_day_acc = 0.0
	changed.emit()


func _process(delta: float) -> void:
	# The debt clock is META time: phone slow-mo must not slow the
	# interest. (Hitstop never touches Engine.time_scale - only slow-mo
	# does - so dividing back out keeps this real.)
	var real := delta / maxf(Engine.time_scale, 0.01)
	if not defaulted:
		var day_seconds := float(Tuning.v("beat_real_seconds")) * 3.0
		var rates := {"family": Tuning.v("rate_family"), "corp": Tuning.v("rate_corp")}
		for id in rates:
			var grow: float = debt[id] * float(rates[id]) * real / day_seconds
			debt[id] += grow
			_interest_today += grow
		_changed_if_grown()
	# the DAY clock: actions spend beats, only time ends the day. A
	# player who burns all three beats at Dusk waits for the day to
	# actually turn - that wait IS the scarcity (bible 30-min loop).
	_day_acc += real
	if _day_acc >= float(Tuning.v("beat_real_seconds")) * 3.0:
		_day_acc = 0.0
		_day_end()
	# banked S-ranks pay down 5% of the balance each (bible 14)
	if FightScore.pending_s_ranks > 0:
		_s_rank_payoff()


# --- beats: calls, jobs, hangouts, or the clock -------------------------------


## Spending a Beat (bible: every call/job/hangout costs 1, 3 per day).
## False when the day has none left - the phone refuses the answer and
## the ring burns out into voicemail. Spending does NOT end the day:
## Dusk, Midnight and 3 AM arrive on the clock, whatever you did.
func spend_beat(what: String) -> bool:
	if beats_left <= 0 or defaulted:
		return false
	beats_left -= 1
	Log.info("Ledger: beat spent on %s (%d left)" % [what, beats_left])
	changed.emit()
	return true


func _day_end() -> void:
	# interest already accrued continuously; the day just closes the books
	if _paid_today + 0.5 < _interest_today:
		_miss_payment()
	_interest_today = 0.0
	_paid_today = 0.0
	day += 1
	beats_left = 3  # the new day's three beats (Dusk, Midnight, 3 AM)
	Phone.push_text("family",
			"The Family: \"Day %d closes. The numbers wait for no one.\"" % day)
	Haptics.fire("tick")  # the faint debt-tick pulse (bible 7)
	_tick_count += 1
	changed.emit()


func _miss_payment() -> void:
	missed_payments += 1
	Haptics.fire("tick")
	_tick_count += 1
	var lender_name := LENDERS["family"]["name"]
	Phone.push_text("corp" if missed_payments % 2 == 0 else "family",
			"MISSED PAYMENT %d of 3. Interest does not sleep." % missed_payments,
			float(Tuning.v("beat_real_seconds")))
	Log.warn("Ledger: missed payment %d/3" % missed_payments)
	if missed_payments >= 3:
		_default()


## The bible's city-wide manhunt: every block hostile, the heat pinned.
## (The full hunt escalation rides the district/world-sim batches.)
func _default() -> void:
	defaulted = true
	Heat.heat = maxf(Heat.heat, 4.0)
	for d in City.DISTRICTS:
		City.turn_hostile(d)
	Phone.push_text("family",
			"DEFAULT. Every door in this city just closed. RUN.")
	Log.error("Ledger: DEFAULT - the city hunts")
	changed.emit()


# --- money ---------------------------------------------------------------------


## Pay a lender. Draws clean cash first, then dirty (they take both).
func pay(lender: String, amount: int) -> bool:
	if not debt.has(lender) or amount <= 0:
		return false
	amount = mini(amount, int(round(debt[lender])))
	var drew := _draw_cash(amount, "debt: %s" % lender)
	if drew <= 0:
		return false
	debt[lender] = maxf(debt[lender] - drew, 0.0)
	_paid_today += drew
	Haptics.fire("tick")
	_tick_count += 1
	Log.info("Ledger: paid $%d to %s" % [drew, LENDERS[lender]["name"]])
	if total_debt() <= 0.5 and not debt_free_noted:
		debt_free_noted = true
		Phone.push_text("crew", "The Crew: \"Zero. You actually hit zero. Don't get used to it.\"")
	changed.emit()
	return true


## Clean first, then dirty - returns how much was actually drawn.
func _draw_cash(amount: int, item: String) -> int:
	var from_clean := mini(amount, Wallet.cash)
	var rest := amount - from_clean
	var from_dirty := mini(rest, Wallet.dirty)
	if from_clean + from_dirty <= 0:
		return 0
	if from_clean > 0:
		Wallet.spend(from_clean, item, "payment")
	if from_dirty > 0:
		Wallet.spend_dirty(from_dirty, item, "payment")
	return from_clean + from_dirty


## Launder dirty money through the Club Owner (bible 4G: 20% cut). They
## still take the risk for Drifting friends - only the Estranged are
## shown the door.
func launder(amount: int) -> int:
	if Trust.tier("club_owner") == "estranged":
		Log.warn("Ledger: the Club Owner will not touch your money")
		return 0
	amount = mini(amount, Wallet.dirty)
	if amount <= 0:
		return 0
	Wallet.spend_dirty(amount, "launder fee: the Club Owner", "launder")
	var clean := int(round(amount * (1.0 - float(Tuning.v("launder_cut")))))
	Wallet.earn(clean, "laundered through the Club Owner", "launder")
	Log.info("Ledger: laundered $%d -> $%d clean" % [amount, clean])
	changed.emit()
	return clean


## Death = Debt (bible 4G): no reload; whoever patched you up gets paid
## by owing them. The Family runs the neighbourhood clinic.
func death_debt() -> void:
	var add := int(Tuning.v("death_debt"))
	debt["family"] += add
	Haptics.fire("tick")
	_tick_count += 1
	Phone.push_text("family",
			"The Family: \"Patched you up. $%d on the book. We are even - for now.\"" % add)
	Log.warn("Ledger: death debt +$%d (The Family)" % add)
	changed.emit()


## Each banked S-rank cuts 5% off the balance (bible 14), split across
## lenders in proportion so nobody's book drifts unfairly.
func _s_rank_payoff() -> void:
	var ranks := FightScore.pending_s_ranks
	FightScore.pending_s_ranks = 0
	var cut := float(Tuning.v("s_rank_cut"))
	for i in ranks:
		var bal := total_debt()
		if bal <= 0.5:
			break
		var share: float = bal * cut
		for id in debt:
			debt[id] = maxf(debt[id] - share * (debt[id] / bal), 0.0)
	Log.info("Ledger: %d S-rank(s) paid 5%% of the balance" % ranks)
	changed.emit()


# --- reads ----------------------------------------------------------------------


func total_debt() -> float:
	var t := 0.0
	for id in debt:
		t += debt[id]
	return t


func rate_of(lender: String) -> float:
	match lender:
		"family":
			return float(Tuning.v("rate_family"))
		"corp":
			return float(Tuning.v("rate_corp"))
	return 0.0


## Which slot the clock is in (Dusk/Midnight/3 AM), regardless of
## what the beats were spent on.
func beat_name() -> String:
	var day_seconds := float(Tuning.v("beat_real_seconds")) * 3.0
	var slot := int(_day_acc / maxf(day_seconds / 3.0, 0.001))
	return BEATS[clampi(slot, 0, 2)]


func _changed_if_grown() -> void:
	# the live counter refreshes the book about twice a second; the log
	# stays quiet (interest posts silently, days post loudly)
	if Time.get_ticks_msec() % 500 < 18:
		changed.emit()


## Debug jump: skip to the manhunt (3 misses at once).
func debug_default() -> void:
	if defaulted:
		return
	missed_payments = 3
	_default()


func reset_for_test() -> void:
	_reset_debt()
	FightScore.pending_s_ranks = 0


func to_dict() -> Dictionary:
	return {
		"debt": debt.duplicate(),
		"day": day,
		"beats_left": beats_left,
		"missed_payments": missed_payments,
		"defaulted": defaulted,
		"interest_today": _interest_today,
		"paid_today": _paid_today,
		"day_acc": _day_acc,
	}


func from_dict(d: Dictionary) -> void:
	var saved: Dictionary = d.get("debt", {})
	for id in debt:
		if saved.has(id):
			debt[id] = maxf(float(saved[id]), 0.0)
	day = int(d.get("day", 1))
	beats_left = clampi(int(d.get("beats_left", 3)), 0, 3)
	missed_payments = int(d.get("missed_payments", 0))
	defaulted = bool(d.get("defaulted", false))
	_interest_today = float(d.get("interest_today", 0.0))
	_paid_today = float(d.get("paid_today", 0.0))
	_day_acc = float(d.get("day_acc", 0.0))
	changed.emit()
