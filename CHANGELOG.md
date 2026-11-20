# CHANGELOG.md — batch history (newest first)

## B10 — the jobs (2026-11-20)
- The board is open. Ten core jobs across the three blocks, two per
  template: DELIVERY walks a case to a glowing drop (hard drops
  ambush you - the case lands only once the drop is clear), RESCUE
  clears guards off a held body, COERCED leans on a shopkeeper
  (words on a calm block; a hot one gets you a guard), HIT marks a
  named target, TURF holds a corner through three waves. Pay is
  400-1500 dirty.
- Every job costs a Beat. Recon is the walk: the marker sharpens
  from a block to a spot once you've stood on it. The day is the
  deadline - sleep with a job live and it goes cold on the friend
  whose name set it up, and the morning report says so.
- Clean Hands vs Wrecking Ball: finish without dropping anyone and
  the friend's trust rises; leave bodies and it burns them and heats
  the block. Run three setups through one friend and their business
  eats it - a scorch mark on their home block and a warning text.
- The phone's map grows THE BOARD (today's offers, the live job) and
  a JOBS chip per block; the HUD carries a small objective line.
  S-ranks in a job's fights cut the debt through the Ledger's own
  banked-rank system.
- Real bugs the suite caught on the way: the down-counter crashed on
  first access (nobody ever counted); a finished job blocked the
  next take forever; the ambush and the hot-block guard both failed
  to block completion; the offer rotation could cycle forever
  without covering the pool; downed job enemies now get dragged off
  so they never stand back up into the next wave.
- smoke_jobs: 65 green. Docs: STATE/TESTING/CHANGELOG.

## B9 — the world sim (2026-11-20)
- The day turns and the city answers. When the Ledger closes a day -
  the beats burnt out, or slept away - heat cools a notch, one or two
  friends text overnight (the Estranged stay silent; they stopped
  calling), friends you keep skipping drift a little further, and the
  street's rumors age out of retelling. The morning report says what
  changed: yesterday's interest, missed-payment warnings, the stars
  the night took off you, who texted, who went quiet, what the street
  let go.
- Sleep at the safehouse: the panel's new SLEEP button forfeits the
  day's leftover beats (they never carry over - the bible's budget),
  closes the books, saves, and wakes you to the report.
- A day that turns mid-fight applies everything but stays a short
  toast - the report never traps you in a menu. The training dummy
  never counts as a fight.
- Under the hood: the Ledger broadcasts day_rolled(day, interest,
  missed); an answered call or a hangout marks a friend as seen;
  rumor memories carry the day they were made; the trust save carries
  the days too (old saves still load). Fixed for real: an early day
  close left the day accumulator running, so the timer rolled the
  day twice - interest, missed payments and heat all double-counted.
- smoke_worldsim: 25 green. Docs: STATE/TESTING/CHANGELOG.

## B8 — the district (2026-11-20)
- Three blocks, walked: Riverside Row (your block), the Club Quarter
  (club fronts, the IRON PALM gym, the Mechanic's garage), the Docks
  (the Meridian Freight warehouse and its shut final-choice door,
  containers, the water, the crane). Gates fade the walk between
  them; the quarter and the docks wear the underpass at their ends.
  No fast travel - the map says so and has no button to prove it
  wrong. Fog lifts only where your feet have been; each card reads
  name, blurb, and the live layers: MOOD, HEAT, FRIENDS (who lives
  where), DAMAGE.
- The blocks remember: knockdowns and gunshots scorch their spots,
  the hero's deaths leave candle memorials, a hostile block boards
  its shopfronts and empties its street (crowds thin with the mood,
  wanderers talk - the mood, and what the street last saw). All of it
  rides the save.
- The noodle shop: GRAB at the Golden Luck front, fade, and you are
  inside - the counter, the pot that's been on since the fire, the
  owner who talks, the stairs to the rooms above. The first real
  interior, the pattern the rest will follow.
- Under the hood: the street fence follows the loaded block (the old
  single-street clamp snapped the hero home mid-walk), interiors keep
  themselves in with walls, travel fades ignore the world's time
  scale. smoke_district: 44 green. Deferred, marked: the gym door
  waits for the tournament batch, the warehouse door for the story,
  the jobs map layer for the jobs batch.

## B7 — friends who show up (2026-11-20)
- Trust stops being a number: hangouts and saves. One hangout per
  friend on one timing skeleton wearing four skins - Fishing with the
  Brother, Basketball at the Mechanic's hoop, Darts in the Club
  Owner's back room, Karaoke in The Drunk's box. A beat buys in, the
  marker sweeps, PUNCH locks it; PERFECT/GOOD pay the bible's +15,
  WIDE +8 (first pass). Invites ride the Ledger's Trust column; a
  blocked chip names its reason (STOPPED CALLING / STREET'S HOT / NO
  BEATS). An open promise from a call is redeemed by the hangout, and
  friends will not stack asks.
- The tier effects land at the knockdown blow: a Close friend spends
  a once-per-fight save - the attacker eats the full gold stagger and
  the hero never sees the retry offer; a Drifting friend hesitates
  through the first knockdown and answers the second; an Estranged
  friend never answers. Fights reset the counters after 8s of calm.
  smoke_friends: 30 green. Deferred, marked: setup payoffs are 4F
  (jobs batch), the kidnap pick is 4H (story batches).

## B6 — the Ledger, Death = Debt (2026-11-19)
- The debt book the 30-minute loop turns on: three lenders with a live
  interest counter that never stops (slow-mo does not save you), a day
  of three beats where ACTIONS spend the budget and only TIME turns
  the day, missed-payment texts with the faint tick pulse, DEFAULT at
  three misses (the whole city hostile, heat pinned, interest frozen),
  Death = Debt on a lapsed offer (+800, The Family, no reload), S-rank
  payoffs cutting 5% per banked rank, dirty/clean money with style
  purses paying dirty and laundering through the Club Owner at 20%,
  and the phone's LEDGER app showing it all - including the Trust
  column the bible demands. Answering a call now spends a beat: burn
  your three at Dusk and the phone refuses the answer until the day
  turns. smoke_debt 36 green; economy re-greened for dirty purses.
  First-pass calls marked: the 3500/1500 split of the bible's 5000,
  the missed-payment rule. Deferred, marked: 4B FULL (lender gear,
  in-fight collectors, scarred style) and gambling.

## B5 — the phone + Trust (2026-11-19)
- The device the pressure loop runs through (bible 4C): calls interrupt
  fights - the ring never locks input, answer in seconds while enemies
  swing, one answer per ring; answering dims and slows the world (the
  wheel's slow-mo pattern); declining costs -6 Trust, a missed ring
  leaves a replayable voicemail and -6; demand calls ask real money
  (PAY $40 / REFUSE -4); invitations take promises (batch 7 redeems);
  Last Call redials once; countdown texts ride push_text; the buzz is
  a slow low haptic pulse. The map app: three blocks, fog of war until
  walked, heat tint, no fast travel. Trust autoload: the four friends
  0-100 from 70, tiers, estranged stop calling, save v5. HUD PhoneBtn
  on both schemes; debug RING NOW / CLEAR PHONE. smoke_phone 41 green.
  Leverage Clips deliberately unshipped (they ride the job/ledger
  batches). The lines are first-pass voice - the owner's ear decides.

## B4.2 — the accessibility four (2026-11-19)
- block_hold_ms (Tuning, live): hold-DODGE->block threshold; the dodge
  tap-vs-hold split reads the same key. autotarget_mult (Tuning): the
  soft auto-target reach (1.5 sticky / 0.5 aim). button_scale
  (Settings, 0.7-1.5): every button's size, rebuilt live, left-handed
  layouts re-mirror. shake_scale (Settings, 0-1): reduced shake on
  every impact. Two new comfort sliders beside HUD opacity. LEVERAGE
  STRIKE keeps the full-meter SuperBtn tap (hold-Heavy charge deferred).

## B4.1 — the 4A feel targets, wired (2026-11-19)
- The audit found every feel number registered in Tuning but unwired,
  and AttackData's cancel fields unread. Now live: parry window 300 ms
  (DRUNKEN 1.5x - the style reads punches), dodge leniency 120 ms (a
  tap a beat too early is held, not eaten; fires the first free frame,
  never extends the buffer), light-cancel window 150-350 ms lights-only
  (heavies commit - re-tap after the swing), and the buffered light
  chain flows at the cancel window instead of the full lock, with
  target tracking so the cross's knockback does not eat the hook.
  Unbuffered punches keep their full lock and lunge. All four numbers
  slide live on the TUNING PANEL. smoke_controls 47 (+12 checks).

## B4.0 hotfix — the style-wheel crawl (2026-11-19)
- The owner's phone log ("errors" at player.gd:366, round 2) was the
  style wheel's world-crawl fighting Fx: the refresh beat ran on the
  scaled delta (fired at 9.3 s real instead of 2.8 s), the crawl lapsed
  at 3.5 s (world-speed flicker mid-browse), and the watchdog's merge
  path never refreshed its age - warn spam past 5 s. Beat now on the
  real clock; merges count as life for the watchdog. Regression-tested
  (6.5 s hold, negative-proofed).

## Batch 3 — Styles & the Wheel (2026-11-19)
- **The five styles (4A)**: Brawler, Kickboxing, Grappling, Drunken,
  Weapon - learned from people (level gates until the teachers arrive
  as NPCs), never lost. Fundamentals stay common; the 16 combo strings
  are the styles' move lists, enforced by a gate in ComboInput.
- **Dirty Street Tactics**: one signature special per style - Glass
  Jaw, Chin Check, Collector's Toss, Liquor Legs, Full Swing - each
  built on a real AttackData kind so knockback/hitstop/posture/style
  just work.
- **The wheel**: a radial style switch with the world in slow crawl;
  a locked pick is refused, the fight resumes at speed on close
  (needed a real Fx.end_slow_mo - a fresh slow_mo merges and extends).
- **Soft style countering**: the school that reads a kind banks extra
  style points on it - never damage.

## Batch 2 — Rank & Posture (2026-11-19)
- **Attack token pool (4A rule 2)**: 1/2/3 concurrent attackers by ring
  size, inside the bible's 2-3 budget; boss keeps priority. Also fixed
  a real Batch 1 bug: `AnimationPlayer.resume()` does not exist in
  Godot 4 — the selective-hitstop unfreeze errored silently on every
  hit (no-arg `play()` is the documented resume).
- **Posture break + finisher opener**: enemies carry a posture bar
  (AttackData `.tres` per swing, parries +30); the break is a long gold
  stagger that opens the finisher — a heavy on a broken enemy executes.
- **Player Composure (the mirror)**: hits drain, blocks chip, parries
  are free; at zero the guard breaks (block dead 4 s). Bottom-centre
  bar, gold→red, GUARD BROKEN flash.
- **Per-fight Style Rank D..S (FightScore)**: variety / no-hit /
  counters / environment / takedowns / speed, pure logic-tested math,
  rank card at combat resolve. S banks for the Ledger's debt payoff.
- **Instant arena retry**: a strike on a broken guard offers a 10 s
  TAP-PUNCH retry that resets and reloads the fight; lapse fights on.
- **Adaptive memory (4A)**: the ring tracks the hero's last three
  moves — mashed lights meet 25% faster telegraphs, dodge spam meets
  strikes held to catch the roll.

## Batch 1 — The Punch (2026-11-19)
- **The "player.gd:366 error" solved**: it was the `Fx: scale requested
  while already at` WARNING carrying a stack trace — a punch's hitstop
  (time_scale 0.05) colliding with the kill's slow-mo (0.45) in the same
  frame. Reproduced 16× in a clean stress run; never a crash.
- **Selective hitstop (bible 8)**: hitstop now pauses ONLY the attacker
  and target (AnimationPlayers paused, physics gated, velocity held;
  eased 4-frame recovery). Engine.time_scale is never used for hitstop;
  colliding slow-mos merge instead of warning. Enemy strikes that clip
  the hero now hitstop both — they never did before.
- **AttackData resources**: one .tres per swing (23) — damage, hitstop
  frames, knockback, shake, camera, posture, cancel window, haptic,
  audio layers — validated by the in-game TestRunner; missing files fall
  back to built-in defaults.
- **Tuning wiring begins**: combo input buffer →
  `Tuning.v("input_buffer_ms")` (350 ms shipped default).
- Also fixed: tests/run_tests.tscn pointed at the pre-rename
  test_runner_headless.gd (CI would have failed).

## Priority Zero (v5.0 master prompt, 2026-11-19)
- **P0.1 T-pose (b47a29d)**: ROOT CAUSE — enemies spawning beyond the
  10 m think radius never had play() called (their far-branch only plays
  Idle when transitioning from Walk), so distant mannequins stood in the
  glb rest pose. Every enemy now plays Idle from _ready. Regression
  suite smoke_tpose walks every AnimationPlayer in the tree (hero pieces,
  cast bases + outfits, dummy, thug, distant muscle) and fails if any is
  not playing. Also corrected the previous wrong fix: the runtime library
  uses SHORT clip names (Idle, Walk, Idle_Talking); cast/NpcRig/UalBind
  reverted to them, warn-on-miss kept.
- **P0.3 Batch 0 gaps (this commit)**: Tuning.gd autoload (one table for
  every gameplay number + user://tuning_overrides.json persistence), the
  debug TUNING PANEL (live sliders, instant save, reset), the in-game
  TEST RUNNER (RUN ALL TESTS, 8 logic tests, copyable report at
  user://test_report.txt, debug-menu jump), GitHub Actions workflow
  godot-check.yml (import + logic tests + fast suites + report artifacts),
  TESTING.md and CHANGELOG.md created. Existing Batch 0 items audited as
  already present: Haptics.gd, save system (save_game.gd), synthesized
  sound bank (sound.gd, 63 clips), FPS/draw/node debug overlay.
- **P0.2**: the 18-suite battery re-run from clean isolated per-suite user
  dirs (result recorded in STATE.json); every suite now sets
  first_run_done explicitly.

## Combo progression pass (2026-11-18/19)
- **Part 4 (c33bb4c + 6775be4 + ae73e53)**: phone-photo fixes — white
  pixelated window-pane stacks dimmed and softened (0.30x emission,
  smaller glow quads), launched enemies fall at 1.35x gravity with the
  launcher slow-mo halved (no more hovering figures), neon signs 2.1
  emission + dimmer omnis + HDR threshold 1.05 (colour, not white slabs);
  trainer grab hijack guarded (1.4 m, facing, no active fight within 5 m);
  MOVES screen regained Lunge cross and SUPER strike rows; LEVERAGE bible
  arrived (PROJECT_BIBLE.md, STATE.json, VISION.md reconciled). T-pose
  root cause honestly re-opened after the missing-clip diagnosis proved
  wrong — closed for real in P0.1 above.
- **Part 3 (d9d9b09)**: Progression XP/levels L2-L15, unlocks, perks,
  level bar + banner, save v3, MOVES screen, trainer placeholder.
- **Part 2 (a56dcc8)**: input buffer fix, 16-combo table, input strip,
  spam scaling, variety bonus (smoke_combos 39).
- **Part 1 (83ea5d0)**: face-button layout, code-built Kick_Code
  (smoke_face 31).

## Stage A — controls and feel master queue (2026-11-17/18)
Stick schemes (floating/dpad/fixed), super meter, style meter with rank
decay, move list, visual pass, photo-fix session. smoke_a4 25 checks.

## Series 2 (2026-11-16/17)
- Phase 8: opening (scripted loss, title card, first mission, settings
  persist), stress numbers. Phase 7: cast of 4, typewriter dialogue,
  portraits, subtitles. Phase 6: city life (reputation prices, district
  hostility, graffiti nickname, witness recall). Phase 5: economy
  (style-scaled cash, heat stars, shops, safehouse save/load). Phase 4:
  Bullet Ledger (price-first gun offer, per-bullet spend, receipt).
  Phase 3: combat depth (chains, block/parry, pipe, flanking, wall slams,
  haptics). Phase 2: adaptive music stems. Phase 1: layered audio,
  footsteps, volume sliders.

## Series 1 (2026-11-15/16)
Look and feel: stability pass, hero + cinematic camera, wet neon night
street, punches that connect, pose/stress suites, the night block.
