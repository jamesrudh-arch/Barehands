# CHANGELOG.md — batch history (newest first)

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
