#!/usr/bin/env python3
"""B13 wiring: dirty money (bible 4G) goes live.

wallet.gd    spending that dips into dirty money pays a 25% surcharge
             ("he charges for not asking") - only when cash falls
             short, so clean-handed play is unaffected
world_sim.gd the day roll resets the back room, burns a full pocket
             (heat + a morning line)
tuning.gd    the laundering / stakes / suspicion numbers
project.godot the Backroom autoload
"""
P = "/home/z/my-project/bare-hands/"


def patch(path, pairs):
    s = open(P + path).read()
    for old, new in pairs:
        if old not in s:
            assert new in s, "%s: not found: %r" % (path, old[:70])
            continue  # already applied (idempotent)
        assert s.count(old) == 1, "%s: not unique: %r" % (path, old[:70])
        s = s.replace(old, new)
    open(P + path, "w").write(s)
    print("patched", path)


# 1. wallet: dirty money spends at a markup (bible 4G: it burns a hole)
patch("scripts/wallet.gd", [(
    '''func spend(amount: int, item: String, kind := "purchase") -> bool:
	if total() < amount:
		Log.warn("Wallet: cannot spend $%d on %s (have $%d)" % [amount, item, total()])
		return false
	var from_dirty := maxi(amount - cash, 0)
	cash -= mini(amount, cash)
	dirty -= from_dirty
	_add(kind, item, -amount)
	return true''',
    '''func spend(amount: int, item: String, kind := "purchase") -> bool:
	var from_dirty := maxi(amount - cash, 0)
	# dirty money burns a hole (bible 4G): a shop that takes street
	# paper charges for not asking - 25% on the dirty part only
	var surcharge := 0
	if from_dirty > 0:
		surcharge = int(ceil(from_dirty * float(Tuning.v("dirty_spend_surcharge"))))
		amount += surcharge
	if total() < amount:
		Log.warn("Wallet: cannot spend $%d on %s (have $%d)" % [amount, item, total()])
		return false
	if from_dirty > 0 and surcharge > 0:
		Log.info("Wallet: $%d of that was dirty - $%d surcharge for not asking"
				% [from_dirty, surcharge])
	from_dirty = maxi(amount - cash, 0)
	cash -= mini(amount, cash)
	dirty -= from_dirty
	_add(kind, item, -amount)
	return true''',
)])

# 2. world_sim: the day roll resets the room and burns the pocket
patch("scripts/world_sim.gd", [(
    '''	Reactive.on_day_rolled(new_day)''',
    '''	Reactive.on_day_rolled(new_day)
	Backroom.on_day_rolled(new_day)
	var pocket: String = Backroom.dirty_pocket_line()
	if pocket != "":
		lines.append(pocket)''',
)])

# 3. tuning: the numbers
patch("scripts/tuning.gd", [(
    '''	"hollow_wary_markup": 0.08,  # wary shelves are thin''',
    '''	"hollow_wary_markup": 0.08,  # wary shelves are thin
	"launder_cut": 0.2,  # the club owner's 20% (bible 4G)
	"launder_daily_drifting": 600,  # at trust "drifting" he moves this a day
	"palm_perfect_shift": 2,  # a clean palm bends the die this much
	"palm_good_shift": 1,  # a sloppy palm, half the bend
	"sleight_sweep_s": 1.4,  # the sleight window's sweep time
	"suspicion_ban": 4,  # the pit boss's count before the door shuts
	"suspicion_heat": 1.0,  # getting caught costs this much heat
	"watched_at_1": 400,  # winnings where the pit boss asks your name
	"watched_at_2": 1000,  # winnings where the room closes on you
	"watched_heat_1": 0.5,  # being asked about costs this
	"watched_heat_2": 1.5,  # being known costs more
	"watched_rep_cost": 10.0,  # the club doesn't like being beaten
	"dirty_spend_surcharge": 0.25,  # shops charge this on the dirty part
	"dirty_burn_min": 1000,  # a pocket this full gets noticed overnight
	"dirty_burn_heat": 0.3,  # ...and this hot by morning''',
)])

# 4. the autoload
patch("project.godot", [(
    '''Reactive="*res://scripts/reactive.gd"''',
    '''Reactive="*res://scripts/reactive.gd"
Backroom="*res://scripts/backroom.gd"''',
)])

print("B13 wiring complete")
