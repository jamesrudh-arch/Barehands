extends Object

## The move list (Stage A4) - one table shared by the pause-menu MOVES
## screen and the first-time prompts. Inputs are described for touch.

const FISTS := [
	["Jab -> Cross -> Hook", "tap PUNCH x3", "The light chain. Each press during a swing queues the next hit."],
	["Heavy hook", "hold PUNCH", "A slower, heavier swing that breaks guards."],
	["Lunge cross", "stick forward + tap PUNCH", "Covers ground fast; the opening move of a chase."],
	["Backfist counter", "stick back + tap PUNCH", "A quick back-step strike. Counts as a counter on an attacking enemy."],
	["Uppercut launcher", "stick back + hold PUNCH", "Pops a staggered enemy into the air for a juggle."],
	["Kick", "X (Face buttons) / tap KICK", "A mid-range poke; on a staggered enemy it pops them up for a juggle."],
	["Finisher", "hold PUNCH on a nearly-down enemy", "A slow-mo execution with the biggest style points."],
	["Wall slam", "heavy near a wall or crate", "The environment is a weapon: cross or heavy with something solid behind them."],
]

const PIPE := [
	["Pipe swing", "tap PUNCH", "Heavier than a fist; breaks lighter guards."],
	["Pipe backhand", "tap PUNCH x2", "The second swing comes around wide."],
	["Overhead slam", "hold PUNCH", "Slow, huge damage, great for finishers."],
]

const SUPER := [
	["SUPER strike", "SUPER button when the meter is full", "Slow motion, a screen flash, and a shockwave that flattens everyone around you. The meter fills from hits, parries and takedowns."],
	["Dodge cancel", "DODGE during any swing", "Every swing can be cancelled into a dodge."],
	["Parry", "DODGE just before a hit lands", "A slow-mo window opens; your next punch counters."],
]
