# MOVES — the implemented control contract

This file describes the moves that are ACTUALLY implemented and wired
in the game (the in-game MOVES screen reads the same combo table).
Planned-but-unbuilt moves do not appear here. When a move changes,
this file changes with it.

## The B-button rule (one rule, everywhere)

* **During combat, B is DODGE.**
* **Outside combat, if a valid interaction is in range, B becomes that
  CONTEXT ACTION** (OPEN DOOR / PICK UP / TALK / USE — the button's
  label changes to the verb).
* **If no interaction is available outside combat, B stays DODGE.**
* **B is never KICK.**

The context verb only wins while the street is calm: with a live enemy
within 6 m, B is locked to DODGE so a fight can never accidentally
open a door or grab a pickup.

## The FIGHT scheme (default) — landscape touch layout

Right thumb, the Xbox diamond:

| Button | Action |
| --- | --- |
| **X** (left) | PUNCH — the light chain |
| **Y** (top) | HEAVY — tap for an instant heavy, hold for the charged heavy |
| **B** (right) | DODGE — or the context action outside combat (see the rule) |
| **A** (bottom) | KICK |

Secondary pills: GUARD (hold-to-block; its first moments parry),
GRAB, JUMP/VAULT, SPRINT, STYLE (hold for the style wheel), LOCK,
PHONE, OBJECTIVE, HELP. The left thumb is the floating joystick; the
right thumb steers the camera independently. Movement and a face
button work simultaneously (true multitouch).

The CLASSIC scheme keeps dedicated PUNCH / DODGE / JUMP buttons; the
FACE scheme puts light/heavy/kick/grab on A/B/X/Y. Layouts mirror
fully for left-handed play (Settings → layout picker).

## Brawler (the starting style)

Single presses:

* **PUNCH chain** — jab, cross, hook (three taps); a forward stick
  press turns the cross into a **lunge cross**.
* **HEAVY** — tap Y for the instant heavy (breaks guards); hold Y for
  the **charged heavy**.
* **KICK** — a mid-range poke; pops staggered enemies up.
* **GRAB** — seize, knee, throw (press GRAB again to throw).
* **DODGE / BLOCK / PARRY** — tap to evade (directional with the
  stick), hold to guard; a guard's first moments parry.
* **SUPER** (when the meter is full) — a slow-motion shockwave.

Chained inputs (the light chain):

* **X X X** — jab, cross, hook.
* **X X Y** — the heavy finisher.
* **X A** — punch into kick.
* **A Y** — kick into heavy.
* **B then X** — the perfect-dodge counter window.

Fight facts: the combo counter and Style Rank (D→S) score your
string; enemies telegraph strikes (the posture bar above them); at
most 2–3 attackers hold an attack token at once (2 in a ring fight);
weapons (pipe, bat, bottle, plank, chair leg) equip from pickups,
show durability on the HUD and break after their configured hits.

## The other styles

Kickboxing, Grappling, Drunken and Weapon styles are implemented in
the combo table and unlock through gameplay progression (the style
wheel: hold STYLE and flick toward a selection). Each has its own
chain table; the MOVES screen lists the unlocked set.
