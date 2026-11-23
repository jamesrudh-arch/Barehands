# 00 — DEVELOPMENT STATE (the living progress record)

> Updated after every meaningful work session and before any
> interruption. On "continue": read this file, inspect the repo, and
> resume at NEXT ACTION. This is a progress record inside the one
> project — not a backup, not a second implementation.

## Current stage

**STAGE 4 — REBUILD KICKOFF** (of the lifecycle: inspect ✅ →
research ✅ → architecture ✅ → asset sourcing (rolling) → BUILD the
systems in the 03_TECH_ARCHITECTURE.md §5 order → integrate → test →
optimise → verify → deliver).

## Done (with proof)

- **Stop + snapshot**: old plan cancelled per the owner's directive;
  R11 (last old item) committed green (smoke_doors 44/44) at
  **a08a541**; the half-finished R13 edit reverted.
- **Stage 1 Inspection** → `01_ASSESSMENT.md`: full inventory (116
  scripts, 8 scenes, 64 suites, 40 autoloads, 107 kit GLBs, 98 audio
  files; hero.tscn/enemy.tscn reference non-existent gltfs — the
  placeholder state the rebuild replaces).
- **Stage 1b Identity** → `02_MASTER_DESIGN.md`: six-area Cinder
  City, story/factions/styles/missions M0–M6, [R] reconciliations
  (open world supersedes the 3-block boundary, day/night supersedes
  always-night, full weapons, taxi fast-travel).
- **Stage 2 Research** → `04_DECISION_LOG.md` D1–D11 with official
  doc citations OPENED (retargeting BoneMap/SkeletonProfileHumanoid;
  VehicleBody3D + its realism caveat; NavigationAgent3D experimental
  + RVO; renderers overview). Sandbox facts: archive.org/poly.pizza/
  itch.io/kenney.nl blocked; docs.godotengine.org, github.com,
  media.githubusercontent.com, quaternius.com, drive.google.com
  reachable (Drive quota-blocked for the character pack — retry
  later if needed).
- **Stage 2b Assets batch 1** → `05_ASSET_REGISTER.md`: 21 MB CC0
  landed in `assets/v2/` (11 KayKit animation GLBs incl.
  CombatMelee; 9 KayKit rigged characters with faces; UAL1_Standard;
  SPDX licence files for all three sources). Batches 2–3 planned
  (city/vehicle full kits, run-series crowd packs).
- **Stage 3 Architecture** → `03_TECH_ARCHITECTURE.md` (system map,
  directory plan, data flow, 15-step teardown/build order, art
  direction) + `06_CONTROL_MAP.md` (the one input map).
- Commits: a08a541 (pre-rebuild snapshot) → **efffbc5** (stages
  1–2b). Not yet pushed (push at the next gate).

## In progress

**STAGE 4 step 1 — the skeleton + boot chain** (03 §5 step 1):
new autoloads (Game, WorldState) beside the retained infra autoloads
(Log, Tuning, Settings, Haptics, BuildStamp); the project InputMap
(the full 06_CONTROL_MAP table); the boot chain scenes/boot/
(splash → notice → title placeholder → menu: PLAY / CONTINUE /
SETTINGS / CREDITS); main_scene switches to the new chain; a new
smoke_boot suite proves card order, skip, and menu actions. The old
gameplay autoloads (InputBus, Wallet, Heat, …) stay registered but
dead until each one's replacement commit deletes them (removing them
early would break not-yet-deleted scripts that reference them; the
new boot never loads the old scenes).

## NEXT ACTION (exact)

1. Write `scripts/core/game.gd` (Game autoload: BOOT→SPLASH→TITLE→
   MENU→PLAY state machine, travel(), the fade owner).
2. Write `scripts/core/world_state.gd` (WorldState: the shared table
   + event queue, get/set/flag, serialisable).
3. Add the InputMap actions from 06_CONTROL_MAP.md to project.godot
   (move/look/punch/heavy/kick/dodge/guard/grab/sprint/jump/lock/
   style/super/phone/pause + vehicle + weapon sets).
4. `scenes/boot/splash.tscn` + `scripts/boot/splash.gd`: D'YOUNGS
   GAMES card (gold ring draw, DY monogram, serif wordmark, light
   sweep) → MATURE 16+ notice → LEVERAGE title placeholder → menu
   with the four buttons; skippable; plays once per launch.
5. `tests/smoke_boot.gd/.tscn`: cards appear in order and time out;
   tap skips; menu buttons fire; PLAY reaches the warehouse shell
   placeholder scene; CONTINUE greyed with no save.
6. Commit (step 1 of the teardown order). THEN step 2: the character
   pipeline proof (import KayKit rig + CombatMelee/GLB → retarget →
   AnimationTree → ResourceSaver native .res → render check with a
   visible face) — the gate for everything character-shaped.
7. Then 03 §5 steps 3–15 in order; asset batch 2 (city/vehicles)
   lands when the world step needs it (step 6).

## Known blockers / watch items

- Google Drive quota blocked the Quaternius character pack (52
  rigged gltf); KayKit covers the pipeline; retry Drive later only
  if the hero/NPC look needs it (asset register has the folder IDs).
- GitHub API rate-limited this hour (HTML + raw + media CDN still
  work — all asset fetches go through the media CDN, unaffected).
- No DEVICE REPORT has ever been received for any build: every
  on-device claim stays PHONE-ONLY until the owner tests.

## File / system ledger (this session)

Modified/added: docs/rebuild/{00,01,02,03,04,05,06}.md,
scripts/fetch_rebuild_assets.py, scripts/extract_article.py,
assets/v2/** (21 MB CC0). Deleted: nothing yet (deletions start at
teardown step 3: input_bus/touch_buttons/camera_follow/player).
