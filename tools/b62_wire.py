#!/usr/bin/env python3
"""B6.2 - wire the Ledger (the debt book) into everything that ships.

wallet.gd       the dirty pool: street money launders into clean;
                spending draws clean first, then dirty
phone.gd        lender senders for texts; ANSWERING COSTS A BEAT
phone_ui.gd     the LEDGER app tile + the book screen (lenders, beats,
                cash, trust column, default banner); the banner shows
                the beat cost and refuses with no beats left
retry_offer.gd  a lapsed offer = Death = Debt (+800, The Family)
fight_score.gd  the S-rank card names the live payoff
style_meter.gd  street show money pays DIRTY (bible 4G)
cash_hud.gd     the HUD total includes dirty money
tuning.gd       the eight debt keys
debug_panel.gd  DEBT +500 / DAY END / DEFAULT jumps
save_game.gd    v6 carries the Ledger
haptics.gd      the "tick": the faint debt-tick pulse (bible 7)
project.godot   the Ledger autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:80])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# --- wallet: two pools -------------------------------------------------------

patch("scripts/wallet.gd", [
    (
        """const START_CASH := 150
const BULLET_COST := 5

var cash := START_CASH""",
        """const START_CASH := 150
const BULLET_COST := 5

var cash := START_CASH  # CLEAN money - laundered, spendable anywhere
var dirty := 0          # street money (bible 4G); launders at a cut"""
    ),
    (
        """## Try to spend; false (and no entry) if there is not enough.
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
	_add(kind, item, amount)""",
        """## The HUD number: everything in both pockets.
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
	_add(kind, item, amount)"""
    ),
    (
        """		"balance": cash,""",
        """		"balance": cash + dirty,"""
    ),
    (
        """	return {"cash": cash, "gun_offered": gun_offered, "gun_owned": gun_owned,
			"entries": entries}""",
        """	return {"cash": cash, "dirty": dirty, "gun_offered": gun_offered,
			"gun_owned": gun_owned, "entries": entries}"""
    ),
    (
        """	cash = int(d.get("cash", START_CASH))
	gun_offered = bool(d.get("gun_offered", false))""",
        """	cash = int(d.get("cash", START_CASH))
	dirty = int(d.get("dirty", 0))
	gun_offered = bool(d.get("gun_offered", false))"""
    ),
    (
        """func reset_for_test() -> void:
	cash = START_CASH
	entries.clear()""",
        """func reset_for_test() -> void:
	cash = START_CASH
	dirty = 0
	entries.clear()"""
    ),
])

# --- phone: lender senders + the beat cost of answering ------------------------

patch("scripts/phone.gd", [
    (
        """var _buzz_count := 0  # test hook: how many buzz pulses have fired""",
        """var _buzz_count := 0  # test hook: how many buzz pulses have fired

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
	return Ledger.beats_left"""
    ),
    (
        """## One answer per ring (bible 4C): answering consumes the ring.
func answer() -> bool:
	if state != State.RINGING:
		return false
	_last_caller = _ring_caller""",
        """## One answer per ring (bible 4C): answering consumes the ring AND
## spends a Beat (bible, 30-min loop: every call/job/hangout costs 1).
## No beats left -> the answer is refused; the ring burns out alone.
func answer() -> bool:
	if state != State.RINGING:
		return false
	if not Ledger.spend_beat("call: %s" % _ring_caller):
		Log.info("Phone: no beats left - the call waits in voicemail")
		return false
	_last_caller = _ring_caller"""
    ),
    (
        """	if not Trust.FRIENDS.has(caller):
		Log.warn("Phone: text from unknown '%s'" % caller)
		return
	_log_entry({"caller": caller, "kind": "text", "outcome": "text",""",
        """	if sender(caller).is_empty():
		Log.warn("Phone: text from unknown '%s'" % caller)
		return
	_log_entry({"caller": caller, "kind": "text", "outcome": "text","""
    ),
])

# --- phone UI: the LEDGER app + the beat-aware banner ---------------------------

patch("scripts/phone_ui.gd", [
    (
        """	var log_b := _app_button("CALLS", "voicemails, texts, promises",
			Color(0.75, 0.6, 0.9), func(): _open_log())
	log_b.name = "LogBtn"
	grid.add_child(log_b)""",
        """	var log_b := _app_button("CALLS", "voicemails, texts, promises",
			Color(0.75, 0.6, 0.9), func(): _open_log())
	log_b.name = "LogBtn"
	grid.add_child(log_b)

	var ledger_b := _app_button("LEDGER", "the debt book - live interest",
			Color(0.85, 0.45, 0.3), func(): _open_ledger())
	ledger_b.name = "LedgerBtn"
	grid.add_child(ledger_b)"""
    ),
    (
        """	buttons.add_child(_btn("ANSWER", CYAN, func(): Phone.answer()))
	buttons.add_child(_btn("DECLINE", MAGENTA, func(): Phone.decline()))""",
        """	var answer_b := _btn("ANSWER", CYAN, func(): Phone.answer())
	answer_b.name = "AnswerBtn"
	buttons.add_child(answer_b)
	buttons.add_child(_btn("DECLINE", MAGENTA, func(): Phone.decline()))"""
    ),
    (
        """	_banner_kind.text = Phone.call_kind().to_upper() + " CALL"
		_screen.visible = false
		return""",
        """	_banner_kind.text = Phone.call_kind().to_upper() + " CALL"
		var answer_b := _banner.get_node("VBoxContainer/HBoxContainer2/AnswerBtn") as Button
		if answer_b == null:
			for row in _banner.get_children():
				if row is HBoxContainer and row.get_node_or_null("AnswerBtn"):
					answer_b = row.get_node("AnswerBtn") as Button
		if answer_b:
			# answering spends a Beat (the 30-min loop): say so, and go
			# dark when the day has none left
			if Phone.beats_left() > 0:
				answer_b.text = "ANSWER - 1 BEAT"
				answer_b.disabled = false
			else:
				answer_b.text = "NO BEATS LEFT"
				answer_b.disabled = true
		_screen.visible = false
		return"""
    ),
    (
        """func _show_voicemail(entry: Dictionary) -> void:""",
        """## The debt book (bible 4G + the 30-min loop): lenders with live
## balances, the day/beat strip, both pockets, laundering, and the
## Trust column - "The Ledger always shows Trust" (bible line 106).
func _open_ledger() -> void:
	_show_app("LEDGER")
	for child in _app_body.get_children():
		child.queue_free()

	var strip := _label("DAY %d  -  %s  -  %d BEAT(S) LEFT" % [Ledger.day,
			Ledger.beat_name(), Ledger.beats_left], 14, Color(0.9, 0.8, 0.5))
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_app_body.add_child(strip)

	if Ledger.defaulted:
		var d := _label("DEFAULT - THE CITY HUNTS", 20, MAGENTA)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_app_body.add_child(d)
	elif Ledger.missed_payments > 0:
		var m := _label("MISSED PAYMENTS: %d of 3" % Ledger.missed_payments, 13, MAGENTA)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_app_body.add_child(m)

	for id in ["family", "corp", "crew"]:
		_app_body.add_child(_lender_row(id))

	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 14)
	cash_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_app_body.add_child(cash_row)
	cash_row.add_child(_label("CLEAN $%d   DIRTY $%d" % [Wallet.cash, Wallet.dirty],
			15, Color(0.7, 0.85, 0.75)))
	var launder_b := _btn("LAUNDER DIRTY (-20%%)", CYAN, func():
		Ledger.launder(Wallet.dirty)
		_open_ledger())
	launder_b.custom_minimum_size = Vector2(230, 40)
	cash_row.add_child(launder_b)

	_app_body.add_child(_trust_column())
	_app_body.add_child(_btn("BACK", Color(0.6, 0.6, 0.65), func(): _show_grid()))


func _lender_row(id: String) -> PanelContainer:
	var who: Dictionary = Ledger.LENDERS[id]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.9)
	sb.border_color = who["color"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_label(who["name"], 15, who["color"]))
	var rate := "0%" if Ledger.rate_of(id) == 0.0 else "%d%%/day" % int(round(Ledger.rate_of(id) * 100.0))
	row.add_child(_label("$%d  (%s)" % [int(round(Ledger.debt[id])), rate], 15,
			Color(0.92, 0.93, 0.95)))
	row.add_child(_label(who["line"], 10, Color(0.5, 0.52, 0.58)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if Ledger.debt[id] > 0.5:
		var chip := int(Tuning.v("pay_chip"))
		row.add_child(_btn("PAY $%d" % chip, CYAN, func():
			Ledger.pay(id, chip)
			_open_ledger()))
		row.add_child(_btn("PAY ALL", MAGENTA, func():
			Ledger.pay(id, int(Ledger.debt[id]) + 1)
			_open_ledger()))
	return card


func _trust_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(_label("TRUST", 12, Color(0.6, 0.65, 0.7)))
	for id in Trust.FRIENDS:
		var f: Dictionary = Trust.FRIENDS[id]
		var v := Trust.value(id)
		var c := Color(0.4, 0.75, 0.5)
		if v < 60.0:
			c = Color(0.9, 0.75, 0.35)
		if v < 30.0:
			c = MAGENTA
		col.add_child(_label("%s  %d  (%s)" % [f["name"], int(v), Trust.tier(id)], 12, c))
	return col


func _show_voicemail(entry: Dictionary) -> void:"""
    ),
    (
        """		var who: Dictionary = Trust.FRIENDS.get(e.get("caller", ""), {})""",
        """		var who: Dictionary = Phone.sender(str(e.get("caller", "")))"""
    ),
])

# --- death = debt ---------------------------------------------------------------

patch("scripts/retry_offer.gd", [
    (
        """signal accepted

var _t := 0.0""",
        """signal accepted

var _t := 0.0
var _lapsed := false"""
    ),
    (
        """	# the accept input: PUNCH while the offer is live
	if _t > 0.0 and InputBus.take_punch():
		accepted.emit()""",
        """	# the accept input: PUNCH while the offer is live
	if _t > 0.0 and InputBus.take_punch():
		accepted.emit()
	# the lapse is Death = Debt (bible 4G): no reload - the hero gets
	# up owing whoever patched them up. The Family runs the clinic.
	if _t <= 0.0 and not _lapsed:
		_lapsed = true
		Ledger.death_debt()"""
    ),
])

# --- the S-rank card names the live payoff ---------------------------------------

patch("scripts/fight_score.gd", [
    (
        """		debt.text = "S-RANK - 5% off principal (Ledger pending)\"""",
        """		debt.text = "S-RANK - 5% of the balance, off the debt\""""
    ),
])

# --- street money is dirty -------------------------------------------------------

patch("scripts/style_meter.gd", [
    (
        """	Wallet.earn(int(round(gain * rank_mult())), move)""",
        """	Wallet.earn_dirty(int(round(gain * rank_mult())), move)  # street cash"""
    ),
])

# --- the HUD shows both pockets --------------------------------------------------

patch("scripts/cash_hud.gd", [
    (
        """	_label.text = "$ %d" % Wallet.cash""",
        """	_label.text = "$ %d" % Wallet.total()"""
    ),
    (
        """	_label.text = "$ %d" % cash""",
        """	_label.text = "$ %d" % Wallet.total()"""
    ),
])

# --- tuning: the eight debt keys -------------------------------------------------

patch("scripts/tuning.gd", [
    (
        """	"phone_ambient_s": 180.0,  # calm-time minutes between ambient rings""",
        """	"phone_ambient_s": 180.0,  # calm-time minutes between ambient rings
	"debt_start_family": 3500.0,  # first-pass split of the bible's 5000
	"debt_start_corp": 1500.0,  # the Corporation's slice at boot
	"rate_family": 0.03,  # Family interest per day (bible 14)
	"rate_corp": 0.08,  # Corporation interest per day
	"beat_real_seconds": 360.0,  # real minutes a beat lasts if nothing spends it
	"death_debt": 800.0,  # Death = Debt (bible 14)
	"s_rank_cut": 0.05,  # each banked S-rank cuts 5% of the balance
	"launder_cut": 0.20,  # the Club Owner's take (bible 4G)
	"pay_chip": 100,  # the Ledger screen's quick-pay chip"""
    ),
])

# --- debug jumps ------------------------------------------------------------------

patch("scripts/debug_panel.gd", [(
    '''	var clr := Button.new()
	clr.text = "CLEAR PHONE"
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func(): Phone.reset_for_test())
	jumps.add_child(clr)''',
    '''	var clr := Button.new()
	clr.text = "CLEAR PHONE"
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func(): Phone.reset_for_test())
	jumps.add_child(clr)
	# Batch 6: jump straight into the debt book's pressure
	var debt_b := Button.new()
	debt_b.text = "DEBT +500"
	debt_b.focus_mode = Control.FOCUS_NONE
	debt_b.pressed.connect(func():
		Ledger.debt["family"] += 500.0
		Ledger.changed.emit())
	jumps.add_child(debt_b)
	var day_b := Button.new()
	day_b.text = "DAY END"
	day_b.focus_mode = Control.FOCUS_NONE
	day_b.pressed.connect(func():
		while Ledger.beats_left > 0:
			Ledger.spend_beat("debug"))
	jumps.add_child(day_b)
	var def_b := Button.new()
	def_b.text = "DEFAULT NOW"
	def_b.focus_mode = Control.FOCUS_NONE
	def_b.pressed.connect(func(): Ledger.debug_default())
	jumps.add_child(def_b)'''
)])

# --- save v6 ---------------------------------------------------------------------

patch("scripts/save_game.gd", [
    (
        """	var d := {
		"version": 5,""",
        """	var d := {
		"version": 6,"""
    ),
    (
        """		"phone": Phone.to_dict(),
		"trust": Trust.to_dict(),
	}""",
        """		"phone": Phone.to_dict(),
		"trust": Trust.to_dict(),
		"ledger": Ledger.to_dict(),
	}"""
    ),
    (
        """	# the phone and its trust ledger ride in v5+; older saves start fresh
	Phone.from_dict(parsed.get("phone", {}))
	Trust.from_dict(parsed.get("trust", {}))""",
        """	# the phone and its trust ledger ride in v5+, the debt book in v6
	Phone.from_dict(parsed.get("phone", {}))
	Trust.from_dict(parsed.get("trust", {}))
	Ledger.from_dict(parsed.get("ledger", {}))"""
    ),
])

# --- the faint debt-tick pulse -----------------------------------------------------

patch("scripts/haptics.gd", [(
    '''	"buzz": [150, 110, 150], # a call: slow low pulse-pause-pulse (4C)''',
    '''	"buzz": [150, 110, 150], # a call: slow low pulse-pause-pulse (4C)
	"tick": [6, 70, 6],  # a debt tick: faint repeating pulse (bible 7)'''
)])

# --- the autoload -------------------------------------------------------------------

patch("project.godot", [(
    '''Phone="*res://scripts/phone.gd"''',
    '''Phone="*res://scripts/phone.gd"
Ledger="*res://scripts/ledger.gd"'''
)])

print("B6.2 wiring complete")
