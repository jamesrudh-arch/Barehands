# TESTING.md — what is tested, where, and how to run it

## The three test layers

1. **Headless suite battery** (this repo's main safety net; ~25 min full):
   every suite is a standalone scene under `bare-hands/tests/` that boots
   the real game headless, drives it, and exits 0 on PASS / 1 on FAIL.
   Run each with its OWN fresh user dir so no suite inherits another's
   state (a shared dir once let the first-run picker lock input and
   cascade failures across six suites):
   ```bash
   mkdir -p /tmp/ud-smoke
   HOME=/tmp/ud-smoke godot --headless --path bare-hands res://tests/smoke.tscn
   ```
   Never kill a running suite (it corrupts shared test state); the
   per-suite timeout is safe because the user dir is thrown away.

2. **In-game TEST RUNNER** (the phone-side layer, prompt 9A): debug menu →
   TEST RUNNER → RUN ALL TESTS. Runs the LOGIC tests in-process (tuning
   validation, animation library, combo table, progression math, wallet,
   save round-trip, settings), shows PASS/FAIL with one-line reasons, and
   saves a copyable report to `user://test_report.txt`. The heavy scene
   suites cannot run inside the running game (they reboot the scene
   tree) — that is what CI and the headless battery are for.

3. **CI** (`.github/workflows/godot-check.yml`): on every push, downloads
   Godot 4.7.2 headless, imports the project, runs `run_tests.tscn` plus
   the fast scene suites, and uploads every report as an artifact.

## Suite inventory (18 scenes)

| Suite | Covers | Status |
|---|---|---|
| smoke | boot, movement, stick zones, jump, ledge, camera, lock-on | green |
| smoke_pose | every character × 5 clips drives real bone motion | green (90 checks) |
| smoke_tpose | every AnimationPlayer in the tree must be playing (T-pose regression) | green (20 players) |
| smoke_cast | the four cast NPCs: animation, silhouettes, dialogue, portraits | see battery |
| smoke_audio | layered impact sounds, footsteps, volume sliders, mute | see battery |
| smoke_music | adaptive stems, combat layers, heat heartbeat, resolve | see battery |
| smoke_stick | floating stick, dead zone, drift, half-push pacing | see battery |
| smoke_controls | button schemes, editor, presets, left-handed mirror | see battery |
| smoke_face | face-button layout + classic scheme, context buttons | see battery |
| smoke_combat | chains, block/parry, pipe, flanking, wall slams, haptics | see battery |
| smoke_depth | juggle arcs, launch landings, aerials, reach | see battery |
| smoke_a4 | Stage A pass: super meter, style rank, move list, prompts | green (25) |
| smoke_city | reputation prices/greetings, district hostility, graffiti | see battery |
| smoke_ledger | Bullet Ledger offer, per-bullet spend, receipt | see battery |
| smoke_economy | style-scaled cash, heat stars, shop stats, safehouse save | see battery |
| smoke_combos | the 16-combo table end to end (buffer, windows, scaling) | green (39) |
| smoke_progression | XP, levels L2-L15, unlocks, perks, save v3, MOVES | green (23) |
| stress_combat | 6 thugs + 300 hits: stability, memory, latency | green |

The current full-battery result is recorded in STATE.json after every
batch boundary.

## First-pass markers (prompt section 10: never cut a tier silently)

- **Tuning.gd**: the table and live panel exist and the logic tests
  validate it. Wired so far: the combo input buffer
  (`input_buffer_ms`, shipped value 350 ms). Remaining systems (enemy
  walk speeds, economy prices) migrate per batch — see STATE.json.
- **AttackData**: every swing ships as `res://attacks/<kind>.tres`
  (23 resources) and the TestRunner validates fields, ranges and audio
  slots; enemy reaction identity (anim/flash/launches) still lives in
  `enemy.take_hit` by design — only the numbers moved.
- **B5 the phone (4C) + Trust counters (4D)**: smoke_phone (41 checks)
  - the ring under fire (input NEVER locks; a punch lands mid-ring),
    the buzz pulse, one answer per ring, answer -> dim + slow (0.25,
    the wheel's re-issued slow-mo) + input lock, decline -6 Trust,
    expiry -> missed -> replayable voicemail + -6, demand PAY
  $40/REFUSE -4, invitation promise (batch 7 redeems), Last Call once
  per run, fog of war (spawn block lifts, unwalked stays ???, heat
  tints), the HUD PhoneBtn open/close restores lock + time scale,
  estranged friends blocked, countdown texts via push_text, save v5
  round-trip (log/fog/trust). Signal gotcha found by the suite:
  City.entered_district carries (district, MOOD) - handlers must take
  both.
- **B6 the Ledger (4G + 14 + the 30-min loop)**: smoke_debt (36 checks)
  - the 5000 split (Family 3500 / Corp 1500, first-pass), live
    interest in real time (slow-mo does not dodge it), S-rank payoffs
    compound per banked rank (5% each, proportional), Death = Debt on
    a lapsed offer (+800, The Family), the beat budget (answering
    spends one; NO BEATS LEFT refuses and disables the banner), the
    day clock (only time turns the day; beats refill at Dusk), missed
    payments as phone texts + faint tick pulses, paid days pass,
    clean-then-dirty draw order, laundering at the 20% cut (Estranged
    refused), DEFAULT = all districts hostile + heat pinned >= 4 +
    interest frozen + no beats, save v6 round-trip. Suite lesson: the
    book's live counter means capture-then-compare needs tolerance
    (interest keeps accruing under the assertion).
- **smoke_economy re-greened**: style purses pay the DIRTY pool now
  (bible 4G street money); the style-meter mirror reads the total.

- **B4.2 accessibility four (bible 7)**: block_hold_ms (Tuning) is the
  hold-DODGE->block threshold and the input bus's tap-vs-hold split
  reads the same key (they can never disagree); autotarget_mult
  (Tuning) scales the soft auto-target reach; button_scale (Settings
  slider, live rebuild + left-handed re-mirror) sizes every button;
  shake_scale (Settings slider) attenuates every impact shake.
  smoke_controls 55 (+8 checks). LEVERAGE STRIKE keeps the SuperBtn tap
  at full meter (hold-Heavy charge flow deferred, phone ergonomics).
- **B4.1 feel targets (the bible 4A numbers, wired)**: parry window
  300 ms (Tuning; DRUNKEN 1.5x), dodge leniency 120 ms (a too-early tap
  is held under its original stamp - it fires the first free frame and
  never extends the 400 ms queue life), the light-cancel window 150-350
  ms lights-only (AttackData cancel fields finally read: dodge
  interrupts a light swing only inside the window; heavies/kick/super
  commit - their taps lapse after the queue life), and the buffered
  chain flows at max(window, impact) with target tracking so knockback
  does not eat the next link. Unbuffered swings keep the full lock (the
  first draft cut single punches to 200 ms and broke the A4
  lunge/backfist - the buffered gate fixed it). smoke_controls 47 (+12):
  leniency hold/fire/drop, pre-window wait + window cancel, heavy
  commitment, chain 10 frames vs ~25 at the old lock, 200 ms parry,
  drunken 350 ms parry.
- **B4.0 hotfix (the wheel crawl)**: the style wheel's world-crawl
  refresh beat ran on the scaled delta (2.8 s of beat time = 9.3 s real
  at 0.3 speed), so the crawl lapsed at its 3.5 s expiry (world-speed
  flicker) and the accumulated age crossed Fx's 5 s watchdog, whose
  merge path never refreshed _scale_since - force-restores + warn spam
  the phone read as errors. The beat now runs on the real clock and a
  merge counts as life for the watchdog (a net for untended slow-mos,
  not a hard 5 s lifespan). Regression: smoke_combos holds the wheel
  open 6.5 s real - the crawl must hold, no flicker, no watchdog line;
  negative-proofed on the pre-fix code (FAIL).
- **Batch 3 systems (all first-pass, phone verification pending)**:
  the five styles (registry in styles.gd; fundamentals common, combo
  strings per-style via the ComboInput gate), the five Dirty Street
  Tactics, the style wheel (STYLE button both schemes + debug menu
  jump; sector picks tested via _pick - the phone's touch-arc feel
  needs the owner's hands), and the soft style-counter bonus (style
  points only, never damage). Styles persist in save v4; older saves
  start clean on brawler. Teachers are LEVEL GATES (1/3/5/7/9) until
  the story batches bring Brother/Bouncer/Collector/Drunk/Lieutenant
  as NPCs - the log credits the teacher by name on learning.
- **Batch 2 systems (all first-pass, phone verification pending)**:
  posture break (billboard gold bar, 2.8 s finisher window, regen 20/s
  after 2.5 s calm), player Composure (bottom-centre bar; guard break
  at zero), FightScore D..S (rank card at combat resolve; S banks
  `pending_s_ranks` for the Ledger batch - the debt payoff and
  story-fight Death=Debt are NOT in yet), the instant retry (offer on
  a knockdown blow; accept resets + reloads - the accept path is a
  scene reload and only phone play exercises it fully), and the
  adaptive memory (Tactics ring buffer; mash -> faster telegraphs,
  dodge spam -> held strikes). Attack tokens: tiered pool 1/2/3 by
  ring size (bible's 2-3 budget; a 2-man ring keeps the classic
  single attacker for readability).
- **Selective hitstop**: attacker+target freeze via paused
  AnimationPlayers and a physics gate; `slow_mo` remains a camera
  effect on Engine.time_scale by design (hitstop never touches it).
- **TestRunner in-game**: logic tests only (8 of them); the scene suites
  stay headless/CI by design.
- **CI**: fast suite set only (smoke, pose, tpose, progression, combos);
  the full battery runs at batch boundaries locally.

## Adding a test

New systems get a row in the table above and, if pure logic, a test in
`scripts/test_runner.gd` too. Every new suite sets
`Settings.set_value("first_run_done", true)` first so the first-run
picker can never lock its input.
