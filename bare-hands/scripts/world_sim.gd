extends Node
## The overnight world (bible 15, batch 9 - the world sim). When the
## Ledger closes a day - the beats burnt out on their own, or slept
## away at the safehouse - the city turns over in its sleep: heat
## cools a notch, friends text or stay quiet (skipped friends drift,
## bible: the 30-minute loop), the street's rumors age out of retelling,
## and the morning report says what changed. Sleeping also saves.

const OVERNIGHT_TEXTS := {
	"brother": [
		"Brother: \"you alive? the shop's quiet without you.\"",
		"Brother: \"ma asked. i said you're working. don't make me a liar.\"",
	],
	"mechanic": [
		"The Mechanic: \"garage was open all night. oil doesn't sleep.\"",
		"The Mechanic: \"that part you wanted came in. don't dawdle.\"",
	],
	"club_owner": [
		"The Club Owner: \"the room was full, the register was light. we'll talk.\"",
		"The Club Owner: \"saw your work from the balcony. artistic.\"",
	],
	"drunk": [
		"The Drunk: \"the box at Lucky's has your name on it. so does the tab.\"",
		"The Drunk: \"i sang the one about the river again. they hated it.\"",
	],
}

var _sleeping := false
var _pending: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Ledger.day_rolled.connect(_on_day_rolled)


# --- the night --------------------------------------------------------------------


func _on_day_rolled(new_day: int, interest_charged: float, missed: bool) -> void:
	var lines: Array = []
	# the books: interest closed the day; a missed payment is a warning
	if interest_charged >= 0.5:
		lines.append("yesterday's interest: $%.0f" % interest_charged)
	if missed:
		lines.append("MISSED PAYMENT %d of 3 - the ledger does not forget"
				% Ledger.missed_payments)
	# heat: the night takes some of yesterday with it
	var cool: float = Tuning.v("overnight_heat_cool")
	if Heat.heat > 0.01 and cool > 0.0:
		var before := Heat.heat
		Heat.heat = maxf(0.0, Heat.heat - cool)
		lines.append("the night cooled %d star(s) off you" % roundi(before - Heat.heat))
	# friends: someone always texts; skipped friends drift
	lines.append_array(_friend_night(new_day))
	# the street: rumors age out of retelling
	var pruned := City.age_rumors(new_day)
	if pruned > 0:
		lines.append("the street let %d old rumor(s) go" % pruned)
	if _sleeping:
		_pending = lines
	elif _fighting():
		# a natural day-turn mid-fight: apply everything, say it short
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("DAY %d - the books closed" % new_day, 3.0)
	else:
		MorningReport.show_report(new_day, lines)


## Overnight texts: one or two friends, chosen by the day so a given
## night is the same for everyone. Estranged friends stay silent -
## they stopped calling (bible 4D).
func _friend_night(new_day: int) -> Array:
	var lines: Array = []
	var candidates: Array = []
	for id in Trust.FRIENDS:
		if Trust.tier(id) != "Estranged":
			candidates.append(id)
	if candidates.is_empty():
		lines.append("nobody texted. that's the Estranged life.")
		return lines
	var count := 1 + (new_day % 2)
	var texted: Array = []
	for i in count:
		var id: String = candidates[(new_day + i * 2) % candidates.size()]
		if id in texted:
			continue
		texted.append(id)
		var pool: Array = OVERNIGHT_TEXTS[id]
		Phone.push_text(id, pool[new_day % pool.size()])
	if not texted.is_empty():
		lines.append("%d text(s) came in overnight" % texted.size())
	# the skip drift (bible: skipping friends lowers trust)
	var drifted := Trust.day_rolled(new_day)
	if not drifted.is_empty():
		lines.append("gone quiet: %s" % ", ".join(drifted))
	return lines


## Sleep at the safehouse: forfeit the day's leftover beats (they never
## carry - the bible's budget), close the books, save, and wake to the
## report.
func sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	InputBus.locked = true
	await Blocks.fade_out()
	Ledger.end_day_early()
	SaveGame.save_all()
	await Blocks.fade_in()
	InputBus.locked = false
	_sleeping = false
	MorningReport.show_report(Ledger.day, _pending)
	_pending = []


func _fighting() -> bool:
	# an ACTIVE threat - the training dummy on your block never counts
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and (e as Enemy).kind > 0 \
				and not e.is_queued_for_deletion():
			return true
	return false
