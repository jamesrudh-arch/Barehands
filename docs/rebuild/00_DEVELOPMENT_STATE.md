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

**STAGE 4 step 3 — player + camera + touch UI (03 §5 step 3)**:
`player/hero.gd` on the proven KayKit rig (locomotion blend from the
shared library, jump/vault/crouch hooks), `player/camera_rig.gd`
(spring-arm third-person, collision, face light), `player/touch_ui.gd`
GENERATED from the InputMap (floating move stick, look stick, the
X/Y/A/B diamond, pills). Delete on landing: input_bus.gd,
touch_buttons.gd, action_button.gd, cam_stick.gd, input_strip.gd,
camera_follow.gd, player.gd (+ their suites).

## Step 2 — DONE (the character pipeline proof, D12)

**pipeline_probe 23/23 + PIXEL ANALYSIS PASS** — the gate for
everything character-shaped is open:
- KayKit Rogue: 23 humanoid bones (lowercase `.l/.r` convention — the
  BoneMap table for UAL is recorded in D12);
- 33 KayKit animations shared onto the rig (no retarget needed
  inside the KayKit family — matched names + RESTs);
- AnimationTree blends idle→walk live; CombatMelee clips installed;
- **native delivery proven**: `assets/native/hero_kaykit_rogue.tscn`
  (504 KB, FLAG_BUNDLE_RESOURCES: meshes+skeleton+texture embedded,
  0 external refs, loads headless with no import cache);
- renders lit (key + warm face-fill): body 450 colours, face 548
  colours / 26% warm skin tones.

Engine facts banked in D12: the `--import` pass requirement for GLB
trees, `connect_node`'s 3-arg 4.7 signature, `Image.convert()` void +
no histogram (count by hand), skinned AABBs through global xform.

## Step 1 — DONE (commit fb5265f)

The skeleton + boot chain is GREEN: **smoke_boot 42/42**. Landed:
`Game` + `WorldState` autoloads (scripts/core/), the full InputMap
from 06_CONTROL_MAP.md in project.godot, `scenes/boot/splash.tscn`
(D'YOUNGS gold-ring studio card → MATURE 16+ notice → chromatic-split
LEVERAGE title → menu; wall-clock card timing; tap-skip), the menu
(PLAY / CONTINUE-disabled-honestly / SETTINGS / CREDITS with the CC0
sources), the warehouse shell area, main_scene → the new chain.

Four bugs found and fixed on the way to green, all worth remembering:
1. **add_child to the root from inside _ready silently fails**
   ("parent is busy setting up children") — suites must let the tree
   finish setup, and hand `current_scene` to the node the flow will
   swap, so the suite survives change_scene_to_file.
2. **Iteration-count card timers stretch under low fps** (each 0.05 s
   timer waits a whole frame) — wall-clock (`Time.get_ticks_msec`)
   is the only honest card clock; a loaded phone would have seen it.
3. **`bool(null)` is a constructor error in Godot 4** — Settings.value
   answers null for unset keys; compare (`== true`), never cast.
4. **Runtime add_child nodes get `@Class@id` names** (no readable
   name) — name every node a suite or scene must find; and the
   BuildStamp B17 failsafe camera was RETIRED (it fought area scenes
   for `current`; every rebuilt scene owns its camera and its suite
   proves it — the smoke_boot check now asserts the viewport's active
   camera belongs to the shell).

## NEXT ACTION (exact)

1. Commit step 2 (pipeline proof + native asset + docs).
2. STEP 3 — player + camera + touch UI:
   a. `scripts/player/hero.gd`: CharacterBody3D that instantiates
      `assets/native/hero_kaykit_rogue.tscn`'s rig under itself, runs
      the shared library through an AnimationTree (idle/walk/run by
      stick magnitude), InputMap-driven (move/jump/sprint/crouch).
   b. `scripts/player/camera_rig.gd`: SpringArm3D third-person with
      collision + the `look` action; soft face light on the hero.
   c. `scripts/player/touch_ui.gd`: generated FROM InputMap — move
      stick, look stick, X/Y/A/B diamond (letters from the control
      map), pills (GUARD/GRAB/SPRINT/JUMP/LOCK), context verb on B.
   d. `tests/smoke_hero.gd`: boot the shell, move the hero via
      Input.action_press, camera turns, animations actually change
      (skeleton pose differs between idle and run), every diamond
      button maps to its action; render check with the moving hero.
   e. DELETE the replaced input/camera/player old files + suites
      (input_bus, touch_buttons, action_button, cam_stick,
      input_strip, camera_follow, player.gd) — one commit.
3. THEN step 4 (the full warehouse home) per 03 §5.


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
