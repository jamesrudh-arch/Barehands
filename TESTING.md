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

- **B11 kidnap arc**: smoke_kidnap (62 checks) - eligibility (day,
  trust, the one you trust most), the cold call both paths (ransom
  paid exactly / broke-hunts-anyway), the three-sign no-combat
  investigation, the site reveal, waves + boss, both endings checked
  for what they cost (lock floor, permanent heat floor, dirty payoff,
  gone-forever friend, the city hollowing rep drops), the 3-day clock,
  persistence with marker respawn. Suite lessons: ANSWERS COST BEATS -
  top up beats per call; a ring while the phone is busy queues
  silently - wait for THE RIGHT ring and decline friend rings (the
  kidnapper redials); calling an async helper (_at) without await
  teleports fine but returns immediately - the check then reads stale
  state (Godot 4 does not warn); clue markers need spots clear of
  street furniture (depenetration shoves the player out of touch
  range).

- **B12 reactive city**: smoke_reactive (38 checks) - the tier
  ladder names, the style ledger (via hit_landed signals), crowd
  witnesses vs empty alleys, the fixer (marker, exact price, broke
  mockery, once-a-day, pay resets heat), the style-copier (kind
  mirrors your style, hp eats your landed hits, cooldown), hollow
  prices and greetings, wary-block planks, beat-driven rumor
  distortion, the radio recap quoting real state, persistence.
  Found a real B6 bug: planks placed at shop.global_position as a
  LOCAL offset - market/foundry boards rendered a whole block over;
  now anchored to the block frame. Suite lessons: node_added fires
  before scene groups apply (connect by signal presence);
  district_at follows the feet (travel before price checks);
  cross-block teleports race the leash; downed bodies stay valid
  instances; heat decays during long waits (loose tolerances); wire
  scripts must be idempotent AND insertion-safe.

- **B13 dirty money**: smoke_backroom (42 checks) - the
  laundering gate (strangers refused), the cut and the drifting
  daily cap ($600, close = unlimited), overnight book reset,
  seeded-dice determinism (seed() replay), palm shifts (none/
  perfect/good/wide bend the roll and cost 0/1/2/3 hands), the
  four-hand ban with heat, the watched thresholds ($400 asked-about,
  $1000 room-closed with rep hit), the 25% dirty surcharge (only on
  the dirty part; clean-covered spends untouched), the overnight
  pocket burn, book/ban roundtrip, the door marker and the room
  opening (walk-away closes it). Suite lessons: a backslash line
  continuation followed by a lone leading % parses as node-path
  syntax - keep format expressions on the string's line; overlay
  panels must not pause the tree (timer deadlock in suites, and
  walking away is a better leave); Phone texts live in _log via
  log_entries() with caller/text keys; check tuning for dormant
  keys before adding (launder_cut existed since B6); assertions
  crossed by thresholds should sit above them, not at 999.

- **B14 difficulty + WOW sweep**: smoke_difficulty (22 checks) -
  the three streets' multipliers (street 1.0 baseline; hard/brutal
  read their screws from tuning), enemy HP scaling per tier
  (bruiser 12/18/24, boss 30/60), telegraph scaling ratios, the
  composure drain scaling (18 / 22.5 / 27), the SETTINGS picker
  (three buttons, the active street glows, tapping HARD flips both
  the glow and the lever), persistence across a settings reload,
  and street-mode regression (every old number untouched). Suite
  lessons: a picker built like _scheme_picker needs its own
  trailing _refresh() or the glow never lands; `var t :=
  TUNING[kind][2]` on an untyped array needs an explicit float.
- **B14b the witness pin**: the B14 battery caught smoke_backroom
  and smoke_jobs red - every heat gain landed at x0.6. Cause (not
  B14): Heat.add() scales gains by who is watching (bible 4I
  crowds-are-witnesses, B12): 0 wanderers near the player =
  alley_mult 0.6, 1 = x1.0, 2+ = witness_mult 1.5 - and wanderers
  ROAM, so the eye count at assertion time was a dice roll every
  heat-asserting suite was silently riding on (the exact-value
  1.08 violence check in smoke_economy was the same dice, green by
  luck every run). Fix: Heat.test_pin_eyes (default -1 = live scan,
  the game untouched); the eight heat-asserting suites pin 1 - the
  x1.0 band - so every existing expected number stands exactly as
  written. smoke_reactive is NOT pinned: it ARRANGES the eyes
  itself (the empty alley x0.6 and the two witnesses x1.5 are the
  test). Battery re-run green after the pin.

**B14 WOW gate sweep** (docs/WOW_GATE.md, the machine-checkable
half; the agent never marks phone-only lines verified):

| Gate line | Machine proof | Phone (owner) |
| --- | --- | --- |
| 30+ FPS iPhone 13 mini, DBG open | - | YES |
| memory flat over 5 min | stress_combat node counts | spot check |
| no mid-play stops | stress_combat green | feel pass |
| nothing placeholder-looking | suite battery + face checks | YES |
| layered hit sounds | smoke_audio | feel |
| puddle footstep change | Sound surface raycast (smoke_audio) | YES |
| pause volume sliders | settings_ui _slider + smoke_controls | feel |
| mute all = silence | Sound mute paths (smoke_audio) | YES |
| music layers, no click | smoke_music | YES |
| heat heartbeat tempo | smoke_music | YES |
| combat resolve phrase | smoke_music | feel |
| chains/block/last-frame parry | smoke_combat, smoke_combos | feel |
| pipe changes swing weight | smoke_combat (weapon data) | feel |
| enemies flank, not queue | smoke_depth token pool | YES |
| wall slam reads as takedown | smoke_combat (slam resolve) | feel |
| heavy hits buzz the phone | Haptics + haptic_pattern wiring | YES |
| bullet price shown first | smoke_ledger | YES |
| firing prints money spent | smoke_ledger | YES |
| receipt totals match cash | smoke_economy, smoke_ledger | YES |
| cash scales with style rank | smoke_progression, smoke_face | feel |
| heat stars climb and cool | smoke (city heat), smoke_city | YES |
| shops change look + stats | gear wiring, smoke_economy | YES |
| save/reload everything back | smoke_progression, smoke_worldsim | YES |
| prices/greetings shift with rep | smoke_city | YES |
| district turns hostile | smoke_city | YES |
| nickname on a wall | smoke_city (graffiti) | YES |
| witness event recalled | smoke_reactive | YES |
| four cast read as four people | smoke_cast | YES |
| dialogue types, portraits, subs | smoke_face, smoke_phone | YES |
| voice hooks visible and empty | cast slots | YES |
| opening plays, title card | opening scene (smoke phases) | YES |
| menus clean, settings persist | smoke_difficulty persistence | YES |
| stress test reports numbers | stress_combat report | YES |

- **B15 the Xogot visual pass + render truth**: render_check (26
  checks, RUNS WITH A REAL RENDERER - opengl3 under Xvfb/llvmpipe in
  the sandbox, `--rendering-driver opengl3`; under --headless it
  prints RENDER SKIP and quits 0 so it can sit in the battery). It
  boots main.tscn, skips the opening, waits for the rain to settle,
  saves the frame to /tmp/render_boot.png and judges the six Xogot
  bugs: baked safe environment (ACES, hdr 1.45, glow 0.5/0.05,
  windows 0.85, neon capped 1.8), pure-white area < 1.5%, orange
  bloom < 10%, ZERO flat pale 80 px blocks (the pale-square
  detector: bright + washed + near-zero variance), rain/splash
  billboarded thin streaks, the dummy worn tan AND its on-screen
  region lit (mean saturation 0.772, not a grey slab), touch
  controls: 9 ActionButtons all on-screen and inside the safe area,
  the hero framed (nx 0.49, 6.9 m), input unlocked + HUD visible
  after the opening, and the frame-level life checks (neon lives >
  0.5% colorful, not one grey slab, mean luminance 0.041 in the
  0.04-0.6 band). Suite lessons: count ActionButtons as children of
  the hud layer (they join no group); unproject_position returns
  PIXELS (normalize by the visible rect); Color has no get_hsv() in
  Godot 4 (use .s/.v); the enum is BILLBOARD_PARTICLES (with an S);
  local callable variables need .call(); local callable variables
  need Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, not a
  RenderingServer enum. Post-battery fix:
  Label3D has outline_modulate, NOT outline_color - the parse was
  fine, the RUNTIME assignment error aborted _front() mid-build so
  doors/glow never spawned (that is what actually failed
  smoke_district; backroom/jobs/kidnap passed with 5 errors each -
  a PASS-with-errors always means a rebuild, never ship it). All
  four rerun green, 0 errors.
- **B15 the six fixes**: (1) environment ACES + glow 0.5/0.05 + HDR
  1.45 (was Filmic 0.7/0.1/1.05 - every window at emission 1.4 sat
  above the 1.05 threshold and bloomed orange), windows 0.85 with
  base_energy metadata in group emissive_window, neon capped 1.8 and
  scaled by the Visual profile, sign text outlined; (2) rain +
  splash materials now set BILLBOARD_PARTICLES (un-billboarded
  custom-material quads can show broadside on Mobile = the pale
  squares), ground glow pools + oil stains are radial
  GradientTexture2D, group decal; (3) the boot-area Dummy was
  literally Color(0.55,0.55,0.6) - a grey man - now worn tan
  (0.62,0.50,0.36); (4) the opening hid the HUD and froze the camera
  until _finish - now PROCESS_MODE_ALWAYS, _end captured deferred
  after the camera's own _ready, 12 s watchdog force-finish; (5)
  touch buttons clamp inside DisplayServer.get_display_safe_area()
  (canvas coords via the inverse final transform); (6) rain quad
  0.008x0.30, scale 0.6-1.1, alpha 0.26.
- **B15 the VISUAL DEBUG panel** (debug menu -> VISUAL DEBUG, layer
  22, everything live through the Visual autoload): glow on/off +
  intensity + bloom + HDR threshold sliders, tonemap cycle, sign +
  window emission multiplier, shadows, rain on/off + streak width,
  ground splash, decals, enemy outlines, NPCs + crowd, camera height
  + distance, XOGOT SAFE preset (glow off, emission x0.6, splash
  off, shadows off - the baked boot default on mobile via
  OS.has_feature), NIGHT preset, COPY SETTINGS (selectable text of
  every value incl. renderer/adapter/safe area/quality), SCREENSHOT
  PNG (user:// + printed absolute path), and a live overlay
  (renderer, window, safe area, orientation, FPS, draw calls, touch
  loaded YES/NO). Phone procedure: XOGOT.md.

- **B10 battery regressions**: (1) the map grew TAKE buttons - the
  B8 'one button only' assertion kept its intent (no fast travel) and
  now allows TAKE+BACK. (2) stress_combat died once and a buffered
  punch ACCEPTED the retry offer - reload_current_scene() restarted
  the whole suite from _ready mid-run, doubling its runtime into the
  timeout while the freed scene left stale autoload caches: city's
  graffiti array (Cannot call get_meta on freed) and heat's typed
  responder array (erasing a freed object from a TypedArray fails
  silently and repeats every frame). Both are REAL-GAME bugs - the
  retry reload is a shipping path and autoloads survive it. Fixed by
  rebuilding the arrays (filter valid, never erase-by-freed-value)
  and the suite now never punches while the offer is up (let it
  lapse: Death = Debt, no reload).

- **B10 jobs**: smoke_jobs (65 checks) - the board, the beat cost, the
  recon-by-walk (wrong block teaches nothing; taking on the block
  skips it), all five templates end-to-end, clean vs wrecking trust
  math, overuse marks the friend's home, the day-roll cold job + fresh
  board, persistence with entity respawn, the map board UI + JOBS
  chips. Suite lessons: raw cross-block teleports are LEASHED back to
  the built block and walked through a gate - travel via Blocks.travel
  and only teleport inside the current block; a raw state=DOWN
  bypasses _enter (stale _state_t means instant respawn) - enter
  states through _enter; queue_free is deferred - a group count right
  after clearing still sees the old node; capture test baselines
  BEFORE the actions that produce the effect.

- **B9 world sim**: smoke_worldsim (25 checks) - a mid-fight day-turn
  is a toast, a calm turn (and sleep) shows the report card; interest
  closes the books, a day closed with interest unpaid is a missed
  payment, heat cools a star, friends text (Estranged silent),
  skipped friends drift while contact exempts, rumors age out of
  retelling, scars survive the night, the sleep path runs through the
  real panel button and saves. Suite lessons: an early day close MUST
  reset the day accumulator or the timer double-rolls the day (the
  arithmetic caught it: heat cooled twice); lazily-created UI nodes
  cannot be cached at boot (fetch the group each time); the training
  dummy is in the enemy group - a 'fighting' check must filter kind,
  or every day turns into a toast.

- **B9 regressions caught by the battery**: (1) logic suites run
  without a scene - district_at returned an empty district before the
  first walk and BLOCK_X[""] crashed every violence report (37 errors
  in smoke_economy that still PASSED); the home block is the default
  answer. (2) The tuning sanity test requires every knob >= 0 -
  deltas are stored as magnitudes, the sign lives in code.
  (3) stress_combat exposed a latent heat.gd bug: passing a FREED
  responder to a typed function errors at parameter binding, the
  erase inside never runs, and the dead entry errors every physics
  frame forever (15k errors, suite timeout) - freed objects are
  erased inline, never handed to typed signatures.

- **B8 the district (6)**: smoke_district (44 checks)
  - boot fog (home never fogged, others fogged), the full walk
    1->2->3->2->1 through gates with fades and arrival-spot checks,
    block landmarks (gym, garage, warehouse, water, underpass),
    crowds by mood (2 on an indifferent street), the noodle shop
    GRAB-in/walk-out through fades, scars + memorials + the save
    roundtrip, the map's layers and its no-fast-travel single button,
    and a hostile block boarding up + emptying. Suite lessons: a
    depenetration shove at a wall can push the hero INTO a gate box -
    Area enter-events never re-fire; land arrivals clear of furniture
    (gate - 2.6). The single-street fence (BOUND 18.5) clamps every
    physics frame - after a block walk it snapped the hero 204m home
    one frame later; the fence now follows the loaded block and skips
    interiors. Travel fades must set_ignore_time_scale(true) or a
    just-closed phone's slow-mo stretches them 4x. smoke_city adapted:
    district_at answers the loaded block, set_current_district
    replaces x-band crossings.

- **B7 friends/trust (4D)**: smoke_friends (30 checks)
  - the invite flow end-to-end (Ledger chip -> phone closes -> beat
    spent -> hangout overlay), the three timing grades pay 15/15/8,
    all four themes open, the promise path (bank -> dedup to one open
    ask -> redeem + '(a promise kept)'), the three blocked chips
    (STOPPED CALLING / STREET'S HOT / NO BEATS), the tier rules
    (Close saves the knockdown once, Drifting hesitates through the
    first, Estranged never), the player hook driven by a real
    guard-broken take_hit (saved = no offer; spent = offer shows),
    and the calm reset after 8s. Suite lessons: hand-set enemy states
    bounce back to IDLE (freeze physics first); Trust 30 is the
    Drifting floor, not Estranged; the player's knockdown evidence is
    the retry offer, not the state enum.

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
