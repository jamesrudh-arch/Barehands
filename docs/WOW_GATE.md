# Bare Hands 3D — The Wow Gate

> **STATUS: RECONSTRUCTED.** This file was written by the agent because
> `docs/WOW_GATE.md` did not exist in the repo when Series 2 began. Upload
> the original to `upload/` to replace it.

## What "wow" means here

A player picking up the phone thinks, within the first sixty seconds:
*"this is a real game"* — not a tech demo. Concretely, the gate is passed
when all of the lines below are true **on a real phone**, verified by the
owner. The agent works headless and can only prove the machine-level half;
the human verifies the feel.

## The universal gate (checked every phase)

1. The game runs at **30+ FPS on iPhone 13 mini (Low tier)** with DBG open.
2. Memory does not grow during play (debug panel: static memory and node
   counts flat across a 5-minute session).
3. **No mid-play stops**: no stuck slow-motion, no frozen input, no
   crashes. The stress test passes.
4. Nothing placeholder-looking ships in the street scene: no missing-texture
   purple, no raw menu, no dead UI on a 375 px-wide screen.

## Per-phase gates (Series 2)

- **Phase 1 — Audio.** Every landed hit has a layered sound (thud + detail
  + air). Footsteps change when stepping into a puddle. The pause menu has
  working volume sliders. Mute all → silence.
- **Phase 2 — Music.** Walking alone is quiet; enemies appearing adds a
  layer without a click; combat rank pushes it up; heat drives a heartbeat
  you can *feel* the tempo of; combat ends in a resolve phrase.
- **Phase 3 — Combat.** Light/light/heavy chains. Blocking works; a
  last-frame block parries with a freeze. A pipe changes the swing weight.
  Enemies flank instead of queuing. A wall slam reads as a takedown. Heavy
  hits buzz the phone (haptics).
- **Phase 4 — Bullet Ledger.** The first gun offer shows the price per
  bullet before anything is bought. Firing prints money spent on screen.
  The ledger reads like a thermal receipt, entries in order, totals match
  the cash actually gone.
- **Phase 5 — Economy.** Cash from a fight scales with style rank. Heat
  stars climb when brawling in the open and cool when out of sight. Shops
  change the hero's look (visible) and stats (felt). Save at the safehouse,
  kill the app, reload: everything is back.
- **Phase 6 — The city.** Shopkeeper prices/greetings shift with
  reputation. Brawl repeatedly in one district → it turns hostile. Your
  nickname appears on a wall. A witness event is recalled later.
- **Phase 7 — Cast.** Four named characters read as four different people
  (silhouette + colour + voice style in text). Dialogue types out, portraits
  show, subtitles work. Voice hooks are visible and empty.
- **Phase 8 — Opening.** The ~5-minute opening plays: scripted loss, title
  card "No one is born with a gun.", first mission (fists, parkour, shop,
  ledger). Menus are clean; settings persist; the stress test reports
  numbers.

## Scoring

Each phase report ends with a gate result of one of:

- **GATE: PASS (headless)** — every machine-checkable line is verified by
  tests; phone-only lines are listed for the owner.
- **GATE: CONDITIONAL** — something partial, exactly what and why.
- **GATE: FAIL** — the phase does not ship its promise; work stops and the
  owner is told precisely what is wrong.

The agent never marks a phone-only line as verified. Those wait for the
owner's test.
