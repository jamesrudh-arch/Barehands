#!/usr/bin/env python3
"""B7.3 - wire friends into the loop.

phone.gd       redeem_promise() - the hangout's payoff; one open
               promise per friend (the call keeps its word)
phone_ui.gd    the Ledger's Trust column grows an INVITE chip per
               friend: spends a beat, closes the phone, opens the
               themed hangout. Blocked chips say why (STOPPED CALLING
               / STREET'S HOT / NO BEATS).
player.gd      the knockdown blow meets the friend save first (bible
               4D tiers): saved heroes stay up, the attacker eats the
               gold stagger; unsaved knockdowns count for hesitation.
tuning.gd      hangout_trust 15 (bible), hangout_wide_trust 8
               (first pass), hangout_sweep_s 1.2
project.godot  the FriendHelp autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: not unique/found: %r" % (path, old[:80])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


patch("scripts/phone.gd", [
    # one open promise per friend
    (
        """		"in":
			_promises.append({"caller": caller_id(), "kind": call_kind()})
			_log_entry({"caller": caller_id(), "kind": call_kind(),
				"outcome": "promised"})""",
        """		"in":
			# one open promise per friend: they will not stack asks
			if not _promises.any(func(p): return p.get("caller") == caller_id()):
				_promises.append({"caller": caller_id(), "kind": call_kind()})
			_log_entry({"caller": caller_id(), "kind": call_kind(),
				"outcome": "promised"})""",
    ),
    # the redemption
    (
        """func promises() -> Array:
	return _promises""",
        """func promises() -> Array:
	return _promises


## A hangout with them pays the promise off (bible 4D, batch 7).
## True when there was one to keep; the log records it either way.
func redeem_promise(friend: String) -> bool:
	var had := false
	for p in _promises.duplicate():
		if p.get("caller") == friend:
			_promises.erase(p)
			had = true
	if had:
		_log_entry({"caller": friend, "kind": "hangout", "outcome": "redeemed"})
	return had""",
    ),
])

patch("scripts/phone_ui.gd", [
    (
        """func _trust_column() -> VBoxContainer:
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
	return col""",
        """func _trust_column() -> VBoxContainer:
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		row.add_child(_label("%s  %d  (%s)" % [f["name"], int(v), Trust.tier(id)], 12, c))
		row.add_child(_invite_chip(id))
	return col


## The INVITE chip (bible 4D hangouts): spends a Beat, closes the
## phone, opens the themed minigame. A blocked chip names its reason.
func _invite_chip(id: String) -> Button:
	var why := Hangout.blocked(id)
	var chip := Button.new()
	if why.is_empty():
		chip.text = "INVITE - 1 BEAT"
		chip.pressed.connect(func():
			if Ledger.spend_beat("hangout: %s" % id):
				Phone.close()
				var h := Hangout.new()
				get_tree().root.add_child(h)
				h.open(id))
	else:
		chip.text = why
		chip.disabled = true
	chip.add_theme_font_size_override("font_size", 11)
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(150, 26)
	return chip""",
    ),
])

patch("scripts/player.gd", [
    (
        """	FightScore.hit_taken()
	if Composure.guard_broken():
		_offer_retry()  # the knockdown blow: a fresh start on the table""",
        """	FightScore.hit_taken()
	if Composure.guard_broken():
		# a friend may answer the knockdown blow first (bible 4D
		# tiers): saved heroes stay up, the attacker eats the gold
		# stagger, and the offer never has to show
		if FriendHelp.try_save(from, global_position):
			velocity.x = -dir.x * 2.5
			velocity.z = -dir.z * 2.5
			return "hit"
		FriendHelp.note_knockdown()
		_offer_retry()  # the knockdown blow: a fresh start on the table""",
    ),
])

patch("scripts/tuning.gd", [
    (
        """	"pay_chip": 100,  # the Ledger screen's quick-pay chip""",
        """	"pay_chip": 100,  # the Ledger screen's quick-pay chip
	"hangout_trust": 15.0,  # the bible's +15 per hangout (4D)
	"hangout_wide_trust": 8.0,  # first pass: a botched timing still counts, barely
	"hangout_sweep_s": 1.2,  # one sweep of the timing marker, seconds""",
    ),
])

patch("project.godot", [(
    '''Ledger="*res://scripts/ledger.gd"''',
    '''Ledger="*res://scripts/ledger.gd"
FriendHelp="*res://scripts/friend_help.gd"''',
)])

print("B7.3 wiring complete")
