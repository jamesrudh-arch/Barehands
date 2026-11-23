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

**STAGE 4 step 12 — title 3D** (the real key-art title scene over
the drifting street: the 3D city drift + the title lockup + menu,
replacing the plain boot menu backdrop; the menu's logic stays).

## Step 11 — DONE (the systems pass, 29/29)

smoke_systems 29/29. Everything in the earlier 28/29 record stands,
plus the phone-open bug is SOLVED. The full stack of what it was
(three layers, each fixed):
1. the signal was wired once per hero re-mount (a stacked lambda
   double-toggled open+shut after CONTINUE) -> one tracked,
   disconnectable connection;
2. the poll's release closed signal-opened phones -> open/close
   ownership split (only the poll's own opens are its closes);
3. THE LAST LAYER (the probe caught it live): the poll "adopted"
   the signal's open - it ran its own open() on the next tick
   (never checking visibility), which SET the hold flag, and the
   release then closed the phone. The poll may not open an
   already-open phone. Probe pattern banked: replay the suite's
   exact context with prints at every hop. DONE +
PROVEN by smoke_systems: the enemy AI's full honest loop (SPOT ->
APPROACH -> TELEGRAPH (the readable wind-up) -> SWING -> the hero
TAKES DAMAGE with the HUD health bar tracking it -> RECOVER; one
swing one hit after the hit-done flag), the B dodge i-frames beat
the swing (a committed 0.56 s roll, 0.50 s i-frames - the window
must outlast the telegraph read), the hero's hands put a thug DOWN
(Death_A) -> heat rises -> it gets back up at quarter health,
DEBT=DEATH (the clinic fee + respawn at the area's spawn marker,
the harbour walk-off included), the save/continue flow (every
landing writes user://leverage_save.json, CONTINUE enables with
its debt note, the world round-trips), the phone UI is BUILT and
mounted (LEDGER/MESSAGES/CONTACTS tabs reading live values).

**THE OPEN BUG: the phone never OPENS on the PHONE action in the
suite context.** Sharpened by this session's probe + two fixes:
the probe PROVED the press registers (pressed=true) and the hero's
_actions fires it (hero_last=phone) - the signal path works in
isolation. Two real bugs were found and fixed on the way (both
committed): the signal was wired once per re-mount (a stacked
lambda double-toggle: open+shut in one press after CONTINUE) and
the poll's release closed what the signal opened. After both, the
suite check STILL reads closed. REMAINING SUSPECTS, next session,
in order: (a) instrument on_hero_action directly (does it receive
"phone" in the suite's post-CONTINUE context at all?), (b) the
suite's second phone press at the end (the close-test) may be
arriving inside the same _process window and re-closing - print
open/close timestamps, (c) as a fallback, drive the open from
Input.is_action_just_pressed in the HERO's _physics_process (where
every other action provably works). The phone UI itself is proven
(its tabs fill with live data).

## Step 10 — DONE (vehicles)

## Step 10 — DONE (vehicles)

**smoke_vehicle 20/20** — the car experience is real:
- VehicleBody3D + 4 VehicleWheel3D per car, the arcade profile as
  data (data/vehicles/sedan.tres + taxi.tres: engine/brake/steer/
  handbrake/downforce/seat - the feel knob is the file);
- B at a car ENTERS (the verb reads ENTER, the hero rides hidden in
  the seat - the camera rig follows the hero node, so it follows the
  car with zero camera changes), the pills swap to GAS/BRAKE/
  HANDBRAKE/HORN, B exits beside the car;
- real physics: power, braking, steering (counter-steered test),
  the handbrake, the horn, a looping engine-hum layer pitched by
  speed (an honest synth placeholder until a CC0 engine loop);
- cars parked ALONG the street (club avenue: sedan + taxi;
  neighbourhood: sedan by the plaza); the parked body blocks the
  hero (layer 2 - pushed by the world and the hero, invisible to
  the camera arm).

Five banked laws (each cost a run to learn):
1. **The rider is not a collider**: the hero's capsule sits inside
   the body while driving - every overlap frame fires depenetration
   impulses; disable the hero's shape + mask for the ride.
2. **Spawn at wheel-rest height** (y=0, not a drop): a 0.6 m fall
   onto the suspension bounces chaotically forever after.
3. **Never do physics surgery inside the step**: zeroing velocity +
   sleeping at exit made the body fall through the world (suspension
   forces stop the moment it sleeps). The driverless car coasts to a
   halt under a RAMPING parked brake; hero-side exit work is
   call_deferred (reparenting during a physics callback).
4. **A drivable world has no voids**: the steer test steered off
   the road through a side street and the car fell for seconds
   before the suite noticed - every outdoor area now has a WORLD
   APRON (420 m, 8 m THICK: a thin plane cannot catch a fast fall -
   0.83 m/step tunnels straight through).
5. **Raycast cars need grip to turn**: friction_slip 3.5 +
   stiffness 80 or the car slides wide at speed; and an instant
   full brake on a rolling raycast car is the classic simulation
   explosion (ramp it).
6. **A riding hero must not trip the gates**: the hero stays in
   group "player" inside the car - driving through a gate zone
   would swap AREAS MID-RIDE. Gates now skip bodies carrying the
   "riding" meta (set by enter/exit). And timing-sensitive suite
   choreography steers ON THE APRON (200 m of nothing to hit), not
   between the storefronts - the first battery run's frame pacing
   turned the car 1.46 rad and ended it in a wall.


## Step 9 — DONE (areas 3-4: the club district + the docks)

**smoke_areas 32/32** — four live areas with a full travel chain:
- THE CLUB DISTRICT: the neon avenue - THE VELVET ROOM (walk-in
  club interior: booths, bar, stage glow), HOTEL AURORA (lobby),
  IRON PALM GYM (walk-in), NEON 9 (locked, breakable) and THE
  MECHANIC (steel) + the PARKING STRUCTURE (locked for the systems
  pass); the Velvet queue; the crossing; two side streets with
  silhouette massing; magenta/cyan lighting + the district haze.
- THE DOCKS: four piers over the harbour plane, two cranes (one
  floodlit), the deterministic container maze (seeded rng - same
  maze every visit), the FISH MARKET (walk-in stalls), DOCK
  WAREHOUSE 9 (story-sealed, unbreakable, Corporation tape), the
  empty lot; cold fog + sodium - the area's own air.
- The neighbourhood's east gate is now REAL travel to the club
  district; the underpass chains club <-> docks; the walk home
  verified end to end (docks -> club -> neighbourhood -> warehouse).

Suite-caught + fixed: **freed-instance typed assignments** - during
area swaps, Doors' law dicts briefly hold freed fronts; assigning
them into TYPED variables (`var n: Node3D = law["node"]`) is itself
the error ("Trying to assign invalid previously freed instance") -
read untyped, validate, then cast. All law-field reads in doors.gd
made freed-safe.


## Step 8 — DONE (the HUD pass)

**smoke_hud 21/21** — the play readouts are live: the Leverage
meter, Style Rank, combo counter, style line and cash line all read
their systems at 20 Hz (nothing decorative, nothing fake; there is
no health bar yet because nothing damages the hero - it grows with
enemies). The style wheel: hold STYLE, the world slows ~30%
(Engine.time_scale), the radial list swaps styles live, release
restores. The pause menu: PAUSE freezes the tree through
Game.pause_game, RESUME/SETTINGS/QUIT all work, QUIT returns to the
main menu. The B-context verb shows at doors (the HUD echo + the
diamond's label) and B at a door TRIES it instead of dodging.

Two fixes banked:
1. **Fx owns only the slows it sets**: the old Fx autoload reset
   Engine.time_scale to 1.0 every frame it did not own - the wheel's
   slow was being cancelled instantly. Fx now tracks _owns_scale.
2. **Synthetic single-frame presses can fall between _process
   ticks**: is_action_just_pressed() in _process missed the suite's
   one-frame pause press; the menu now uses a state-based press EDGE
   (is_action_pressed + was-pressed), which sees real and synthetic
   presses alike. Suites hold action presses ~0.2 s like real taps.


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

1. Commit + push step 11 complete (smoke_systems 29/29 + the
   battery).
2. STEP 12 — title 3D:
   a. scenes/boot/title.tscn: a 3D backdrop (the club avenue's
      geometry drifting past a slow camera, the neon doing the
      work), the title lockup + the menu over it.
   b. The menu buttons/logic port as-is (PLAY/CONTINUE/settings/
      credits + the honest notes).
   c. smoke_title: the scene loads, the camera drifts, the buttons
      all work, CONTINUE's note logic intact; render check.
3. THEN step 13 — perf (frame budget audit per area under
   llvmpipe: draw calls, lights per area, the fill on the phone
   form factor); step 14 — the final full battery + the V3-format
   device report (VERIFIED vs PHONE-ONLY rows) + the zip.


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
