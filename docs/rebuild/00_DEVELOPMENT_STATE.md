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

**STAGE 4 step 8 — the HUD pass (03 §5 step 8)**: health/meter/
rank readouts, the style wheel UI (hold-flick), the objective
banner's real styling, the B-context verb label wiring, the pause
menu (resume/settings/quit), safe-area polish - all reading the
live systems (Combat.meter/rank, WorldState, Missions).

## Step 7 — DONE (the mission system + M0/M1)

**smoke_missions 20/20 + the full battery GREEN (7 suites, 202
checks)**: MissionData .tres (m0, m1), the missions module hosted
by Game (no new autoloads) with the objective banner + the green
marker pulse, stages that complete on REAL conditions (move
distance, camera yaw, a landed punch on the bag via Combat's
hit signal, the door-tried WorldState event, the area change,
walk-up package pickup, area-gated proximity delivery), M0 WAKE-UP
CALL chains into M1 THE COLLECTION, rewards land in WorldState
(+$120), done-flags survive a save round trip, and M0 fires on
every NEW GAME (WorldState reset clears first_play_done).

Bugs caught (all suite-driven, all banked): MissionData class_name
does not resolve at parse time on a fresh tree (the global class
cache is editor-built - type as Resource + load by path, the
stage-0 rule), the module's marker/package must re-place when the
area changes BUT ONLY after the new scene lands (Game.area_id
flips during the fade - placing then writes into the dying scene),
the doors registry lazily purges laws whose fronts died with a
scene (and reads nodes UNTYPED before is_instance_valid - a typed
assign of a freed instance is itself an error), and marker
proximity checks must gate on the stage's AREA (raw distances
across scene spaces "delivered" M1 from the warehouse workbench,
2.06 m from the street marker).

## Step 6 — DONE (the neighbourhood + THE TEARDOWN)

**smoke_street 33/33 + the full battery GREEN after the teardown**
(smoke_boot 42, pipeline_probe 23, smoke_hero 30, smoke_home 26,
smoke_combat_r 28, smoke_street 33 = 182 checks):
- The street (area 2): 12 registered fronts (3 OPEN with real
  walk-in interiors: the noodle shop, THE RAIN GLASS, the corner
  store - each dressed from the Kenney kit), housing south, two
  alleys, the plaza, the subway mouth (honest sign), vending
  machines, sodium-and-neon night on the mobile light budget (few
  real lights + emissive practicals + pools).
- THE DOOR LAW (scripts/world/doors.gd, the new one-authoritative
  implementation): approach verb, TRY with the reason, B-shoulders +
  A-kicks break (2 breakable fronts), the stash drops BESIDE the
  doorway (lateral - dead-centre auto-collected at 0.1 m, the suite
  caught it), steel refuses; broken doors persist through
  WorldState flags across home<->street round trips.
- Gates both ways: the yard gate is live (walk out, fade, the
  street), the west street gate walks home.
- **THE TEARDOWN**: the old world is GONE - 60+ old scripts
  (blocks/block_builder/street/interiors/old doors/map, the old
  player cluster, old enemy/crowd/traffic/weather/music/economy/
  phone systems), the old scenes (main.tscn, warehouse.tscn,
  player.tscn, enemy.tscn), 40+ old suites, and 32 dead autoloads
  removed (InputBus, Heat, City, Music, ...). Retained infra:
  BuildStamp, Tuning, Settings, Haptics, Log, Sound, Fx + the new
  Game/WorldState/Doors. tools/battery.sh is the new runner.
- Suite-caught bugs (all fixed, all worth remembering): Game's
  spawn-name lookup vs underscored ids, the falling-velocity
  teleport tunnel (zero it on every suite placement), THE ROAD HAD
  NO COLLIDERS (mesh-only street = a hole; the DBG hero y=-5.35
  line caught it), the gate posts standing IN the sidewalk lane,
  the stash auto-collect, the chain cadence vs p2's cancel window.

## Step 5 — DONE (the combat core)

**smoke_combat_r 28/28 + smoke_hero 30/30 + smoke_home 26/26** —
the five styles are live and PLAY DIFFERENTLY (distinct data +
clips + stances behind the constant X/Y/A/B): the data layer (30
AttackData + 5 StyleData .tres, built by
scripts/player/build_style_data.gd), combat.gd (startup/active/
recover with cancel windows, punch chain p1->p2->p3 with reset,
dodge with i-frames, guard, finisher spending the Leverage meter,
Style Rank decay, selective hitstop on the attacker only),
train_target.gd (bag sway, dummy posture-break + recovery), the
hero integration (movement lock while swinging, style cycling).

The landing bug was a SUITE bug, caught by instrumentation in one
run: the suite stood the hero 1.4 m SOUTH of the dummy - the
training corner sits at the hall's south edge, so z=7.6 was past
the floor and inside the south wall: the hero fell out of the world
(distances 4 -> 38 -> 103 in the trace). Approaching from the
north (yaw 0, the model's authored +Z forward) fixed it. Also
fixed: the posture test now uses the heavy (2.5 posture damage -
p1's 1.0 could never break from 2.0 with the 0.8/s heal), and the
finisher test resets the dummy's hp (the suite itself had chewed
it to 0, hiding the 18-damage delta).

## Step 4 — DONE (the warehouse home)

**smoke_home 26/26 + smoke_hero 30/30** — area 1 is the real home:
the corner loft bed (Kenney kit on a code loft), the workbench
(Kenney desk), the phone table + phone prop, the fridge, the floor
lamp, the weapon rack (pipe, bat, two bottles), the TRAINING CORNER
(punching bag on its chain, the sparring dummy, the wall mirror),
the LOCKED big roller door (slats + lock + its honest sign), the
side door — a REAL 1.5 m doorway through the east wall — into the
private YARD (fence with the matching doorway gap, bins, crates,
the signposted gate for the step-6 street, the flickering sodium
lamp). Lighting: warm main + bed practical + door spill + the
flickering yard lamp + city fill. Kit placements carry stand-in
box colliders (_kit_aabb merges GLB child meshes). Bugs caught by
the suite: Label3D uses outline_modulate (not outline_color) in
4.7, sibling name collisions @-rename (unique bottle names), and
the yard fence originally sealed the doorway - the walk test
caught it.

## Step 3 — DONE (the player stack)

**smoke_hero 30/30 + smoke_boot 42/42 + pipeline_probe 23/23 (with
the strengthened pose check) + old smoke PASS** — the live hero
exists: `player/hero.gd` on the native KayKit rig (61 shared clips:
locomotion/ambient/posture/combat), the locomotion AnimationTree
(idle/walk/run/crouch blends, proven by pose hashes), the spring-arm
camera rig with look control + face light, and the touch UI
generated from the control table (X/Y/A/B diamond + pills, sticks,
the InputMap is the single truth). Game.travel mounts hero + rig +
touch UI per area; the shell gained real collision + the spawn
marker. Three pipeline corrections banked in D13 (connect_node
order, root_node-relative track paths, root-motion tracks dropped).
Transitional null-safety in music/combo_input/traffic keeps the old
game runnable until its teardown steps.

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

1. Commit + push step 7 (missions green, battery 7 suites).
2. STEP 8 — the HUD pass:
   a. `scripts/ui/hud.gd` (+ CanvasLayer mounted by Game at PLAY):
      health bar, the Leverage meter, the Style Rank pips, the
      combo counter, the cash line (stash_cash), all reading the
      live systems; nothing decorative, nothing fake.
   b. The style wheel: hold STYLE slows time ~30% (Engine
      time_scale - carefully: pause-safe), a radial picker over the
      five styles, flick/press to swap.
   c. The pause menu (PAUSE action -> Game.pause_game, a real menu:
      resume/settings/quit-to-menu), the B-context verb label on
      the diamond (hero.context_verb wired through touch_ui).
   d. `tests/smoke_hud.gd`: bars track real values (meter rises on
      hits, cash updates, rank pips), the style wheel swaps styles
      live, pause freezes the world and its buttons work.
3. THEN step 9 — areas 3-4 (the club district, the docks) on the
   area-scene pattern + asset batch 2/3 for their dressing.


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
