# CHANGELOG.md — batch history (newest first)

## B25 — THE DRIVER + THE EMOTION LAW (2026-11-22, the production mandate Sections 5, 2, 27)

- **THE DRIVER (Section 5 - no decorative vehicles)**: the noir sedan
  is now a real drivable car. `scripts/vehicle.gd` (new): arcade
  handling tuned for touch - the stick steers and throttles (the
  walking metaphor, up = drive), BRAKE then REVERSE below zero,
  handbrake bite, horn, wall-scrape bleeds speed (wall-normal only -
  resting floor contact never bleeds), wheels roll with speed, brake
  lights burn on decel. Boarding: context verb ENTER beside the car
  (last grab target, doors/people still win), the hero is seated
  (hidden, collision off), the camera retargets the car; the FIGHT
  diamond becomes the DRIVE cluster (X EXIT / A HORN / B HANDBRAKE
  hold; foot pills stand down, phone and map stay usable from the
  driver's seat). Traffic yields to the OCCUPIED car like any road
  user; an exited kerb-parked car never freezes a lane (the B23/B24
  lesson kept). The car persists through save/load wherever it was
  left.
- **THE EMOTION LAW (Section 2 - an emotion is not implemented until
  it can be observed)**: humanoid `face()` grows fear - brows lift
  and pinch, the mouth drops open - wired to the wanderer's witness
  states: watch, phone-recording, flee and the catch-your-breath
  browse all WEAR fear while the alarm holds, and the face calms
  when the street settles. Verified in-suite: mouth scale 3.4x,
  brows at 0.115 while panicking, back to 1.0 when calm.
- **PRODUCTION_CHECKLIST.md** (new, Section 27): every section of
  the production mandate with its REAL status and named evidence;
  the next fronts in dependency order (bicycles, voice, dynamic
  world events, drunken style, and the still-open DEVICE REPORT).
- **Two real bugs the new physics exposed**: (1) the parked sedan
  had overlapped BuildingF's collider since B18 - invisible while
  it was decorative, lethal the moment it could drive; it now parks
  west-facing in line with the westbound lane; (2) speed bled
  through floor contact in the scrape rule - now wall-normal only.
- **smoke_drive** (new, 21 checks): enter/occupy/camera retarget,
  accelerate 10.7 m/s, steering, brake-to-reverse, handbrake shed,
  horn, occupied-car traffic yield, no-lane-freeze when parked,
  exit restores the hero, save/load round trip.

Verified: smoke_drive 21/21, smoke_reactive 42/42 (new fear-face
checks), smoke_crowd 12/12, targeted regressions green (smoke,
smoke_safe, smoke_controls, smoke_kits, smoke_traffic, smoke_worldsim
+ face/pose/cast/drive/reactive/combat at release) on Linux/llvmpipe.
iPhone physical verification remains PHONE-ONLY - the device report
is the standing open item.

## B24 — THE B-BUTTON RULE + GATE-A COMPLIANCE (2026-11-22, the master production directive)

The master directive's Gate-A pass against the B23 reconstruction:

- **THE B-BUTTON RULE (Section 5.2/5.3)**: the FIGHT scheme's diamond
  now follows the Xbox rule exactly - **B is DODGE** (and the context
  action outside combat: the button relabels OPEN DOOR / PICK UP /
  TALK when the street is calm), **A is KICK**. B was KICK and A was
  DODGE through B23 - the exact inversion the directive prohibits.
  Spec labels/colours, down/up routing, cooldown rings, the picker
  card, the device-report text and the live context verb all follow.
- **MOVES.md** (new): the implemented control contract - the one B
  rule, the diamond, the Brawler chains (X X X, X X Y, X A, A Y,
  B-then-X), grab/super/parry, the styles and unlock path. Written
  from the live combo table, not from plans.
- **DESIGN_SYSTEM.md** (new): the colour tokens (#05060F/#0E1226/
  #E8E8F4/#8A90B0/#FF007F/#00F0FF/#3DDC84/#FFB020/#FF4D6D/#C9A24B),
  type scale (11 px floor), 8-point grid, safe-area rules, the action
  cluster layout, and the implemented accessibility list.
- **Gate-A spec verification**: studio card (D'YOUNGS GAMES), MATURE
  THEMES 16+ notice, title card (tagline + production line + 3D key
  art), menu PLAY/CONTINUE(disabled without save)/SETTINGS/CREDITS,
  skip-intro setting, hero locator ring setting, and the 2-3 attacker
  token budget were all checked against the directive - already in
  place from B21-B23; no dead entries invented.

Verified: sandbox suites (the battery) + live_boot 15/15 on Linux +
llvmpipe. iPhone physical verification remains PHONE-ONLY.

## B21 — THE FORENSIC AUDIT BUILD (2026-11-22, the ultimate directive)

Batch 1-4 of the master engineering directive: audit, build identity,
regression facts, gameplay diagnostics, and the first LIVE-PLAY
verification.

- **THE BUILD-IDENTITY BUG (root cause of "which build is my phone
  running?")**: scripts/build_info.gd said "B18 e1dfde3" through B19
  and B20 - the file's header names scripts/gen_build_info.py, which
  DID NOT EXIST in the repository, so every stamp after B18 updated
  only VERSION.txt and the in-game stamp (HUD corner, debug menu,
  Stage 0, DEVICE REPORT) kept claiming B18. The generator now exists
  (batch, exact code commit, build time, config, target platform);
  BuildStamp.block() carries the full identity; project.godot imports
  as "LEVERAGE B21" (distinct from every stale entry); README import
  steps rewritten for B21.
- **THE STALE-AUDIO-IMPORT BUG**: after the Gate A re-master, the four
  music stems still fell back to runtime synth on every fresh import
  (stale .import sidecars vs the new WAV hashes - "Music: music_bed
  synthesized in code (file missing)" in the boot log). A full re-import
  fixes the cache; the phone re-imports on install, so the mastered
  stems play there.
- **LIVE-PLAY VERIFICATION (Phase 16)**: tests/live_walk.gd (4 checks:
  the apartment renders, the door OPENS ITSELF on walk-in through the
  real stick pipeline, the hero walks OUT, the street renders) and
  tests/live_play.gd (11 checks: street render, hero on screen,
  pedestrians, frame-to-frame movement, the nearest car moves, the
  noodle shop interior with 13+ rigs, the dummy fight staged, the
  VULTURE watcher) - both PASS on the software-GL renderer; evidence
  PNGs in download/live_shots_b21/. HONESTY: Linux + llvmpipe, NOT an
  iPhone; the harness drives the stick's _target (the variable a
  finger drag produces); punch-landing needs full-rate physics and is
  proven headless (smoke_combos 61 checks).
- **MOVEMENT DIAGNOSTICS (Batch 4)**: the DBG panel shows the live
  chain - input lock, stick vector, velocity, position, camera yaw,
  movement state, active scheme. Found and fixed a real QA-harness
  lesson on the way: the follow camera only re-centres while the hero
  walks AWAY from it, so a wrong initial yaw walks into a wall.
- **DEVICE REPORT (Phase 18)**: build line, renderer, scene, camera
  active state, weather, spawned-vs-animated NPC census (npc_rig group
  added to every rig), hero velocity + movement state.
- **Traffic debug fix**: the car engine AudioStreamPlayer played
  before add_child (boot-log error) - guarded.

## B20 — GATE A: SEE, HEAR, MOVE (2026-11-22, the final master prompt)

The owner's iPhone shows a black world, harsh crackling audio and a
stuck hero. Gate A of the master prompt (PRIORITY 0) is the only work:
make the game visible, audible and walkable, then STOP for the DEVICE
REPORT. Every visual/audio claim is PHONE-ONLY until that report.

- **A1 FULLBRIGHT SAFE MODE** (visual.gd): the XOGOT SAFE profile now
  carries a warm sun + a camera-attached fill light + raised ambient,
  all scaled by a live brightness dial (0.5-2.0) with BRIGHT / NORMAL
  / MOODY presets in the Visual Debug panel; NIGHT removes the safe
  lights again.
- **A3 SANE AUDIO - the crackle is DIAGNOSED AND FIXED**: every
  project-owned loop had a loop-seam click, hot unfiltered noise beds
  and DC (facts: tools/audio_audit.py). All 13 re-mastered offline
  (tools/master_audio.py: 44.1 kHz, periodic/crossfaded seamless
  loops, band-limited beds, RMS targets -20..-30 dBFS, peak -3 dB).
  Music targets lowered throughout (bed -14 dB, combat -6 dB max).
  The runtime audit (Sound.audit_stream) now checks GENERATED streams
  (files are mastered offline and trusted); anything failing is muted
  and logged. The DEVICE REPORT prints the verdicts.
- **A4 MOVE + LEAVE THE ROOM**: the apartment door opens itself
  during the guide's OPEN step when the hero is within 2.4 m (no way
  to be trapped); GO OUTSIDE / GO INSIDE buttons in the debug menu.
- **A5 PEOPLE**: two customers at the noodle-shop table + the VULTURE
  thug leaning on the alley wall, watching you (scripts/watcher.gd).
- **A6 THE GUIDE ALWAYS STARTS**: the intro runs whenever the hero is
  home (not only on the true first run), and a standing objective
  (the trainer) keeps the radar/route/objective alive forever - the
  phone's "no objective" is dead.
- **A7 CONTROLS**: the FIGHTING scheme (X PUNCH / Y HEAVY / B KICK /
  A DODGE) is now the DEFAULT (the phone showed the classic word
  buttons because an unset setting fell through to "classic"); the
  input strip moved to top-centre, clear of the buttons (the "yellow
  bar crossing the screen" was this strip's chips flashing over the
  cluster).
- **A8 DEVICE REPORT**: a GATE A section first (safe profile,
  brightness, people census, hero position, input lock, door state,
  guide step, button scheme) + an honest PHONE-ONLY tail listing the
  five things only the owner's eyes and ears can confirm.
- tests/smoke_safe.gd: 16 checks, all green (safe mode, brightness
  dial + presets, X/Y/B/A defaults, strip clear, audio bank sane,
  music low, door auto-open, street landing, people, standing
  objective).

## B19 — the full-game directive (2026-11-21)

The owner's 25-part directive (upload/Pasted Content_1795296041873.txt):
research first, purge placeholders, build the living city. Research +
audit + plan: docs/B19_PLAN.md. Batches in order:

- **1+2 (assets + placeholders)**: 80 new Kenney CC0 models + 10
  explosion-pack sprites (industrial, suburban, traffic pool,
  140-model furniture, food); the MERIDIAN warehouse box -> two
  industrial sheds (collision/door/signs kept), dock containers ->
  tinted textured crates + a working dock (chimney, tank, truck,
  cargo), alley annexes/garages -> real outbuildings, suburban back
  row, the jobs hostage / trainer / whole title cast -> real UBC
  characters, the hero textured (native import + per-mesh rebind);
  smoke_kits 70 checks.
- **5 (living city)**: wanderer.gd rewritten as a real pedestrian -
  pavement graph, crossings with two-way traffic courtesy, browsing,
  phones, pairs, club queue, fight reactions (watch/record/flee),
  district densities + clothing tints; smoke_crowd 12.
- **6 (traffic)**: a Traffic autoload - lane graph per block, a pool
  of six real vehicles, braking for hero/pedestrians/cars, head and
  brake lights, spinning wheels, one shared light, a synthesised
  engine hum; also fixes the parked sedan's sideways body; smoke_traffic 9.
- **7 (weather)**: a Weather autoload - four states with slow drift,
  wind, rain amount/tilt/splash answering the sky, puddle ripple
  rings, rain audio follows, traffic slows, walkers hurry; smoke_weather 10.
- **8 (fire)**: a Fire autoload - layered flames (core/outer/embers,
  CC0 sprites), wind-drifted smoke, steam-on-rain, burn barrels as
  slam_fire surfaces, scorch decals from a recycled pool of 8, at
  most 2 flicker lights, synthesised crackle; the noodle grill;
  dust/spark sprite bursts on takedowns and parries; smoke_fire 10.
- **9 (interiors)**: five furnished rooms - the apartment and noodle
  shop dressed from the kits, plus three NEW venues on the market
  block (IRON PALM GYM with swinging bags, THE RAIN GLASS bar, THE
  VELVET ROOM club with dancers on the UAL Dance clip); the street
  fence exempts them all; smoke_interiors 12.
- **10 (lighting)**: the de-blue pass - neutral charcoal ambient/fog/
  background, a desaturated moon, neutral asphalt/sidewalk/facade
  colours (Part 15); the phone judges the final read.
- **3+4 (verified)**: controls/combos/stick/map suites green; the
  Part 8 animation map audited (guard = braced pose by design,
  combos drive cross/hook, dodge = Roll, grab = Push).
- **11 (validation)**: tests/final_audit.gd - the final-content
  validator (placeholder hunt, blank-surface report, hero texture,
  the living systems alive, five doors, emission law, world bounds):
  16/16 PASS; smoke_pose fixed for the dressed enemy (all players in
  lockstep); the battery grows to 42 suites.

## B18.4 — push, the stress leak, and the CC0 street (2026-11-21)

Three jobs from the owner, in order:

- **the push**: all 18 unpushed commits (B18 through the B18.3 docs
  stamp; the 18th the owner had not counted was 2be1f27, the
  upload/IMG_9292.png photo commit) pushed to
  github.com/jamesrudh-arch/Barehands main; remote verified at
  9e8c135 = local HEAD, 0 ahead. Credential stored inside .git/ only
  (never tracked).
- **a (the stress node leak, owner item 2)**: the stress census
  (STRESS_LEAK_DUMP=1, new in tests/stress_combat.gd) named the leak:
  Heat's responders and City's district muscle erased DOWN fighters
  from their tracking arrays WITHOUT freeing them - enemy.gd's own
  respawn then stood each one back up as an UNTRACKED node tree that
  lived forever (one per fight). Both spawners now drag their downed
  men off after a 2 s linger, mirroring the jobs/kidnap rule. The test
  itself was measuring placement timing, not leaks: the old baseline
  (818) was taken BEFORE the deferred placement contract, ambience
  players and crowd landed (+209 of "leak" was those). Baseline now
  settles at tick 90 (1003), quiesce waits 2.8 s so mid-carry bodies
  are not counted, and two honest bounds hold: end +28 <= 60 (what
  still stands at quiesce is the hostile district's 2 muscle + crew
  re-staffing) and combat spike +68 <= 160. STRESS PASS.
- **b (the CC0 street, owner item 3)**: the Kenney City Kit / Car Kit
  and the Quaternius UBC characters replace the placeholder boxes -
  assets/kits/ (32 files, licence file inside, credits in CREDITS.md),
  scripts/kit.gd (placement with per-axis stretch, MultiMesh road rows
  = one draw call per street, lamp posts with warm sodium light the
  moths adopt, 1.1 emission cap, unique node names, deferred add so a
  mid-setup parent never drops a kit). Replaced: the six main-street
  building boxes (commercial buildings on their plots, front faces on
  the building line), both sidewalk slabs (kit pavement), the box car
  body (the Kenney sedan carries the noir head/tail/strip lights), the
  market block's five building boxes + dashes (kit buildings, marked
  road lane, awnings, roadworks, a fog skyscraper), the foundry's
  roadworks, and the plain mannequins on enemy kinds 1-4 (MUSCLE =
  peasant, COLLECTOR = knight armour, CREW = ranger, BOSS = superhero
  female - all driven by the UAL clips in lockstep with the hidden
  mannequin player; the training dummy keeps its mannequin). Kept
  code-built on purpose: the warehouse + dock containers (honest
  industrial volumes, story-wired), the wet asphalt (the reflection
  shader surface), neon signs, lit windows. DEVICE REPORT gains a
  CC0 KITS section; LookDev judges the real sedan now. Measured on
  the sandbox renderer (kit_probe, hero POV, 120-frame sample): draw
  calls 280 -> 275, triangles 100,841 -> 101,379 (+15 kit models at
  no measured cost - the hidden box meshes and mannequins paid for
  them), the frame's pure-black share 74.0% -> 52.6% and the
  render_check fixed-camera histogram pure-black 74.0% -> 67.2%,
  mid-tones 8.8% -> 19.8% (the flat dark boxes became textured
  mid-tones). smoke_kits (44 checks) pins the whole contract.
- **test repairs found by the full battery**: smoke_depth's "pipe prop
  waits" asserted the pre-B18.3 loose prop (stale since the pipe
  unification; the suite's own phase-5 pickup check is the real
  contract - now recorded and asserted at finish); smoke_tpose caught
  that dressed enemies left the hidden mannequin player idle (the
  player now stays in the lockstep group); render_check.gd had a
  parse-breaking ":= load(...).instantiate()" chain (untyped on 4.7)
  and would not even load. battery (36 suites, clean HOME per suite):
  33 green in the run incl. stress_combat with the final enemy code;
  smoke_depth and smoke_tpose failed mid-run and are fixed + re-run
  green standalone in this batch; render_check 53/56 - the 3 known
  items are pre-existing (2 llvmpipe histogram thresholds, improved
  but not crossed: the phone judges those; 1 HUD bar crossing).

## B18.3 — the full package (2026-11-21)

From the expanded prompt (photos 9296/9297 were still B17). Nine
committed chunks:

- **a (audio, BUG 13)**: Narrator autoload (TTS verified against the
  4.7 docs: audio/general/text_to_speech + tts_get_voices_for_language
  + tts_speak; iOS libs default-on; empty-voice + delay caveats),
  subtitles ALWAYS, radio-babble fallback, the 8-line intro script +
  3 call scripts; TEST SOUND (a tone on every bus, debug + settings);
  AUDIO section in the DEVICE REPORT; UI bus + Master compressor +
  limiter; music stems SYNTHESIZED IN CODE when files are missing;
  generated mission stingers + guide chime + phone buzz.
- **b (start sequence, BUG 14)**: studio card D'YOUNGS GAMES (gold
  self-drawing ring, DY monogram, serif wordmark, sweep, swell +
  chime), content notice, LEVERAGE title card over the live street,
  loading card, MAIN MENU (PLAY/CONTINUE-greyed/SETTINGS/CREDITS,
  menu music, Kenney credit). Gated to Stage 0 LAUNCH FULL GAME so
  every suite boots clean. smoke_start 11.
- **c+d (fight controls + pickups/weapons, BUG 8 + 12)**: the FIGHT
  scheme default (X punch, Y heavy tap/hold-charge, B kick with the
  context swap + the 6 m combat-priority rule, A dodge, GUARD/GRAB/
  SPRINT pills, SUPER centre, STYLE wheel), new combos ONE-TWO-THREE
  (A A A) + STEP KICK (A X); pickups (pipe/bat/bottle/plank/chair-leg
  + cash/health/painkillers/key/burner) with glow + bob + [B] prompts
  and the placement contract; the Weapons autoload (durability per
  landed hit, break, HUD chip); the legacy street pipe unified.
  smoke_pickups 24.
- **e (the green guide, BUG 9)**: the follow-me orb (lead 4-6 m, wait
  + pulse, re-route, arrival bounce, trail, chevrons, edge arrow),
  the route + beam + map legend in guide green (cyan alt), the orb
  dot on the radar, recall on OBJECTIVE. smoke_guide 23.
- **f (everything visible, BUG 10 + 11)**: the CHARACTER + VEHICLE
  CENSUS in the DEVICE REPORT, the lit red fallback figure when an
  enemy GLB fails, name tags over heads, the camera fill light, the
  parked car readable (brighter paint + headlights + tails + cyan
  edges + spill), the apartment door breathing capped inside 1.15.
- **g (ambient life, BUG 15)**: the moth swarm (MultiMesh orbits at
  lamp-height lights, scatters when you walk through, caps 40/20 by
  the device guess), rats + pigeons + the stray cat reacting with
  sounds, the AMBIENT section in the report. smoke_ambient 12.
- **h (the art bar, BUG 16)**: ART_BIBLE.md (palette, the 1.1 Mobile
  emission cap rule, materials, presets, the CC0 roadmap stated as
  NOT integrated), the LookDev gallery from the debug menu,
  histogram gates in render_check (white < 1.5%, black < 55%,
  mid-tones > 25%), graphics facts in the report. smoke_lookdev 6.
- **i (the 3D title, BUG 17)**: the extruded TextMesh LEVERAGE rising
  from the wet ground with a mirrored fake reflection, the cast in
  layers (bosses in fog, crew row, hero front-right with lit eyes),
  magenta/cyan rims, dolly + light sweep, behind the title card AND
  the menu; the 2D chromatic wordmark is the logged fallback.

Suites green this pass: run_tests, smoke, smoke_guide 23,
smoke_pickups 24, smoke_ambient 12, smoke_start 11, smoke_lookdev 6,
smoke_map 35, smoke_controls 55, smoke_face 31, smoke_stick 31,
smoke_audio, smoke_null_watch, smoke_city, smoke_combat, smoke_combos
61, stage0_check (+ the full battery re-run from clean dirs; two
suite-contract fixes along the way: the picker now offers three
schemes, the worldsim street-door selection). The push is STILL
credential-blocked (.git-auth missing since the sandbox recycle); a
bundle carries all commits. hdr_2d was measured B18.2 (identical white
share both ways - stays OFF per the verified docs).

## B18.2 — never lost + orientation lock (2026-11-21)

The second B18 drop, from the expanded prompt (photos IMG_9296/9297:
both still the B17 build - portrait clean, landscape stacked, which
confirmed the rotation diagnosis):

- **BUG 6 (portrait/landscape overlap)**: the orientation policy is
  now LOCKED - `display/window/handheld/orientation = 4`
  (sensor_landscape; portrait locked out). The layout engine already
  re-lays out as one unit on every size/orientation change; a
  duplicate-button-set audit (exactly one ActionButton per name,
  ever) was added to render_check AND the DEVICE REPORT, plus a full
  PORTRAIT pass in render_check (resize -> relayout -> one label per
  button, no overlaps, on-screen, radar clear -> restore landscape).
- **BUG 7 (lost in a room) - the NEVER LOST system**: new
  apartment.gd (the starting room: solid collision, lit, bed + crate,
  ONE door - breathing cyan frame, THE STREET sign, OPEN prompt near,
  swing animation + creak, fade to the street; the street safehouse
  panel gained GO INSIDE so the door works both ways; Interior's
  is_inside_interior now covers the apartment so the street fence
  cannot reach in). New guide.gd: on the TRUE first run
  (first_run_done false - every suite sets it true, so the street
  boot is untouched) the hero wakes in the apartment and a skippable
  intro walks FIND THE DOOR -> OPEN IT -> REACH THE TRAINING DUMMY,
  feeding MapData.nav_target so radar/route/beam/compass all point
  at the live step. Permanent layer after the intro: a stereo-panned
  SONAR ping (generated WAV, no files) that speeds up and gets louder
  near the target (Settings sonar_on), a top objective label, 20-second
  no-progress hints, and OBJECTIVE + HELP buttons in both touch
  schemes (OBJECTIVE toasts the goal and turns the camera; HELP
  repeats the hint). camera_follow gained face_point(). The noodle
  front shows a floating ENTER prompt.
- **DEVICE REPORT** grew: orientation policy + window + visible rect +
  duplicate-set audit; a GUIDE section (objective + distance, sonar
  state + live ping interval, nearest door + its state).
- Tests: NEW smoke_guide (17 checks: room spawn, step advance, door
  prompt + contextual INTERACT, door opens to the street, street path
  to the noodle shop exists, sonar rate increases, hint fires,
  intro persists, no duplicate buttons). Bugs found and fixed on the
  way: apartment needed collision (meshes alone let the hero fall),
  the street bound (BOUND=18.5) clamped the off-axis apartment into
  a gate ping-pong (interiors are now exempt for the apartment too),
  FORMAT_16_BITS_STEREO does not exist (stereo is a flag), and
  nav_target positions are Vector2 (three typed reads were Vector3).
- Suites at this drop: smoke_guide 17, smoke, smoke_map 35,
  smoke_controls 55, smoke_face 31, smoke_stick 31 + the battery
  re-run. The push is still blocked by the missing .git-auth
  credential in this sandbox; a bundle carries the commits.

## B18 — the device fix (2026-11-21)

The owner's in-game phone photos (portrait + landscape) named five
bugs. All five now have root causes, fixes, and regression gates:

- **BUG 1 + the grey figure were ONE bug**: the hero's gltf pieces
  point at never-shipped textures (`T_Hair_1_*`, `T_Regular_Male_*`
  — visible in every import log). The hero rendered as a stack of
  pale untextured boxes; that grey figure WAS the hero. Fix:
  hero_rig `_dress_fallback` (flat noir materials on untextured
  pieces) + a permanent hero locator (ground ring + camera-relative
  rim light; Settings hero_locator/hero_rim). The opening force-ends
  at 8 s with a guarded handback; the camera gained a null-target
  failsafe and make_current.
- **BUG 2 (bunched/doubled buttons + the yellow bar)**: the old
  per-button safe-area clamp stacked buttons on one spot. New layout
  engine: right-anchored grid, whole-cluster safe-area fit, pairwise
  no-overlap, 64-px floor; LIGHT/HEAVY/DODGE big; GRAB contextual
  (GRAB/INTERACT/TALK/THROW via player.context_action at 10 Hz);
  STYLE/PHONE separated; composure bar to top-centre; the doubled $
  labels separated; the stick shows a faint home ring and ignores
  radar taps.
- **BUG 3 (too dark)**: the B15 XOGOT SAFE preset (glow off, emission
  x0.6) was the cause. New SAFE: glow 0.38 @ threshold 1.02, full
  emission, tonemap white 4; ambient 0.045→0.17-blue, moon 0.25→0.8,
  brighter asphalt/sidewalks/facades. render_check's luminance floor
  is the gate.
- **BUG 4 (white sign)**: docs-verified - the Mobile renderer's
  R10G10B10A2 buffer clips bright emission to white. Sign slabs
  2.1→1.1, neon flicker cap 1.8→1.15, SignAmber gets a dark frame +
  lettering + body (mesh_sign_body/text). `rendering/viewport/hdr_2d`
  measured on/off with the render check (a 2D-canvas setting; no
  effect on the 3D signs): stays OFF.
- **BUG 5 (no map)**: the audit found nothing to hide - no radar,
  route, waypoint or drawn map existed. New: map_data.gd (blocks,
  POIs, 5 interiors, street graph, A* routes, waypoint, fog),
  radar.gd (round, camera-rotating, N marker, hero arrow, blips with
  rim chevrons + level triangles, district banner, objective +
  distance, tap→map), full_map.gd (pan/pinch/tap-to-pin, legend,
  layers, fog of war, three entry points: radar/pause/phone),
  objective_marker.gd (3D beam + chevron + distance, optional ground
  ribbon OFF by default), and the DEVICE REPORT (device_report.gd;
  DBG→DEVICE REPORT and in SafeBoot; every fact, COPY LOG).
- Tests: NEW smoke_map (35 checks) + render_check grown to 49
  (button min-size/no-overlap/single-label, no HUD bar crossing,
  hero ≥4% of frame, the whole radar suite, WorldEnvironment in both
  arenas); smoke_controls 55 + smoke_face 31 updated to the new
  layout contract without weakening (the hardcoded 116 became the
  live default size). Battery from clean dirs: run_tests, smoke,
  smoke_a4 25, smoke_audio, smoke_backroom 42, smoke_cast, smoke_city,
  smoke_combat green before the session cut the run; smoke_map 35,
  smoke_controls 55, smoke_face 31, smoke_stick 31 verified in full
  earlier the same day; the remaining suites re-run next session.
  render_check verified 49 checks earlier in the session (one
  WorldEnvironment test bug fixed after that run; its green re-run
  was cut off by the sandbox CPU throttle - both render suites now
  need ~2x the timeout under llvmpipe).
- Housekeeping: upload/ untracked + ignored (the owner's photos are
  not game content), tmp probe files removed.

## B18 — the truthful banner (2026-11-21)
- The B17 phone photo settled the boot question - and exposed a UX
  bug: the screen was 100% green (33/33 autoloads including Music,
  SafeBoot, FULL GAME, stamp `B17 d209d01` = the exact pushed code)
  yet its own banner said "FIRST-RUN IMPORT IN PROGRESS - wait, then
  tap RETRY", because on Xogot the class cache never exists. The
  owner read it (fairly) as "the game cannot launch".
- The banner now reports the census OUTCOME: green "ALL STAGES
  GREEN - nothing is importing ... tap LAUNCH FULL GAME" when
  everything passed without the cache (the phone's permanent state),
  yellow retry guidance only on real FAILs, silence when the cache
  exists. LAUNCH FULL GAME is now the first button.
- stage0_check grew to 17/18 checks (banner truth, colour, button
  order). safe_boot_check's stale hardcoded "B16" stamp assertion -
  a latent FAIL on HEAD since the B17 stamp bump - now compares
  against BuildInfo.STAMP itself.
- Proofs with the class cache deleted: stage0_check 18/18,
  safe_boot_check 27/27, smoke_null_watch 993 frames, smoke - all
  green, 0 script errors. Phone: XOGOT.md items 12/13/14/16/17
  CONFIRMED by the owner's photo; remaining taps are the 30-second
  full-game walk and the landscape check.

## B17 — the class-cache fix, Stage 0, and a device-proven boot path (2026-11-21)
- The B16 grey screen closed the loop: the phone's every failure was
  ONE mechanism, now REPRODUCED in the sandbox. A fresh Xogot import
  has no global class cache; scripts referencing class_name
  identifiers fail to parse; autoload scripts that did (music.gd,
  heat, city, tactics, combo_input, progression, visual, friend_help,
  world_sim, jobs, blocks) register as NULL - Music's null was the
  fight_score.gd:38 'state' on Nil spam, and the dead player/
  touch_buttons scripts were the missing hero and controls.
- THE FIX (all verified before shipping): every class_name
  declaration removed (42 of them; 88 files rewritten to
  const-preload references by tools/flatten_class_names.py), the
  UAL GLB preload converted to a guarded runtime load (a second
  first-run killer: it took player/enemy/npc_rig down with it
  before the import pass), enemy.gd mannequin nulls and jobs.gd's
  City signal guarded. With the class cache deleted: 33/33 autoloads
  alive, 0 parse errors; from a clean clone with NO .godot at all,
  Stage0 and SafeBoot render and pass before any import pass.
- STAGE 0 (the new main scene): a zero-dependency boot screen -
  dark magenta (also the new default clear colour, distinct from
  Godot's grey), build stamp from res://VERSION.txt, Godot version,
  renderer, GPU, window, orientation, safe area, time, class-cache
  state, a first-run "wait then RETRY" banner, a 39-step numbered
  boot census (every autoload PASS/FAIL, SafeBoot, the full game -
  each step guarded, nothing can crash), user://boot_log.txt, and
  LAUNCH SAFEBOOT / LAUNCH FULL GAME / COPY LOG / RETRY.
- IDENTITY: the project is now at the REPO ROOT (project.godot
  top-level, git mv, CI updated); config/name is "LEVERAGE B17"
  (unique per push); zip Leverage_B17_2026-11-21.zip (import the
  unzipped folder itself); README leads with the exact Xogot steps;
  the build stamp shows at the boot corner, the debug menu, Stage 0,
  SafeBoot, and VERSION.txt.
- SafeBoot gains the last-10-errors section (read from this run's
  user://logs/godot.log); the visual debug panel already carries the
  full B15 toggle set plus XOGOT SAFE and COPY SETTINGS; rain drops
  are now code-generated streak/dot textures (no imported texture
  to lose, no pale squares); a failsafe camera appears if a 3D scene
  ever has meshes but no current camera; touch buttons re-clamp to
  the safe area on rotation/resize.
- New suites: stage0_check (14 checks) and the extended
  smoke_null_watch (dynamic 33-autoload census in the first 600
  frames). The whole battery ran with the class cache DELETED - the
  exact fresh-import condition.

## B16 — build stamp, SafeBoot, and the Music-null guards (2026-11-21)
- The phone still showed an old build (white signs, grey figure, no
  hero, no controls) with fight_score.gd:38 spamming 'state' on Nil
  every frame while every sandbox suite was green. B16 makes
  staleness impossible to miss and device-side failures legible:
- BUILD STAMP: generated from the repo at commit time (batch,
  commit hash, UTC time) - shown at boot (top-right corner), in the
  debug menu, in SafeBoot, and in VERSION.txt at the repo root.
  The project is renamed uniquely per batch ("LEVERAGE (Bare Hands)
  B16") so Xogot cannot load a stale cached copy under the old name.
  Root README says exactly which folder to import (bare-hands/).
- SafeBoot (temporary main scene, scenes/safe_boot.tscn): the
  diagnostic path. Plain lit floor, the real hero (player.tscn), the
  real touch controls (touch_buttons + stick_input), a FollowCamera,
  one dummy - and a big log with COPY LOG: build stamp, renderer,
  GPU, window, orientation, safe area, FPS, draw calls, the
  AUTOLOAD CENSUS (name by name - a NULL there is the root cause of
  the fight_score spam), hero/touch/cinematic status, sign material
  facts, and the grey-figure answer (node 'Dummy', tan since B15).
  Eight one-at-a-time system toggles: cinematic, city, rain, signs
  (a live material test wall), npcs, post-process, music, fight
  score. START FULL GAME loads the real street.
- The Music-null guards: fight_score._process (the :38 site),
  player._retry_step/_accept_retry, heat._process, dialogue - all
  null-guarded with a one-time push_error (never spam). Root cause
  narrative in TESTING.md: a null singleton aborts the calling
  function every frame; that abort chain is the no-hero/no-controls
  symptom pattern. Fixed the silent main.tscn bug found on the way:
  the Dummy's property is kind, not mode.
- New suites: smoke_null_watch (600+ untouched frames against
  main.tscn, any Nil/null script error fails it - PASS, 995 frames,
  0 errors) and safe_boot_check (real-render proof of SafeBoot, 27
  checks PASS, every toggle on/off clean).

## B15 — the Xogot visual pass: six bugs, a debug panel, render truth (2026-11-21)
- The game runs on Xogot (Godot 4.7 / iPhone / Mobile-Metal) and the
  phone showed six visual bugs the number-only fixes missed. All six
  fixed at the source and MACHINE-PROVEN by render_check - a real
  opengl3 render under Xvfb/llvmpipe that judges the frame (26
  checks, RENDER PASS): blown-white signs + orange halo (bloom
  threshold was 1.05 with windows at 1.4 emission - now ACES, glow
  0.5/0.05, HDR 1.45, windows 0.85, neon capped 1.8), pale square
  blocks (particle quads now BILLBOARD_PARTICLES; ground quads are
  radial gradients), the grey figure (the spawn dummy was literally
  grey - worn tan now), the flat-teal no-hero spawn (the opening
  hid the HUD and froze the camera - watchdog + deferred landing +
  ALWAYS processing), touch controls (safe-area clamping; landscape
  lock confirmed), thick rain (0.008 m streaks).
- VISUAL DEBUG panel in the debug menu: live glow/tonemap/emission/
  rain/decals/shadows/NPC/camera controls, XOGOT SAFE preset (the
  baked mobile default), COPY SETTINGS (paste the values back to the
  agent), SCREENSHOT PNG, and an overlay with renderer, resolution,
  orientation, FPS, draw calls and touch-loaded status. Phone
  procedure in XOGOT.md.
- Battery: 30 suites (29 headless green + render_check green under
  Xvfb), 0 script errors. Docs: XOGOT.md (new), TESTING, CHANGELOG,
  STATE.

## B14 — the difficulty knobs + the WOW sweep (2026-11-20)
- Three streets to walk, one Setting: STREET (the night as written -
  bible 14, every existing number untouched), HARD and BRUTAL. The
  screws the player can feel: enemies take more sticks to drop
  (x1.5 / x2), their tells come faster (x0.85 / x0.7 telegraph), and
  hits drain more Composure (x1.25 / x1.5). All numbers flat in
  tuning (run_tests' non-negative rule holds); Settings.diff_mult()
  is the single choke point.
- The SETTINGS screen gains a THE FIGHT picker: three buttons, the
  active street glows, tooltips carry the noir. Persists with
  everything else.
- The WOW gate sweep: every machine-checkable line of
  docs/WOW_GATE.md mapped to its proving suite (or marked as the
  owner's phone test) in TESTING.md. The four suspected thin spots
  turned out to be long-built: puddle footsteps, haptics wiring,
  gear-driven look changes, nickname graffiti walls.
- The witness dice, pinned: Heat.add() scales gains by who is
  watching (x0.6 empty alley / x1.0 one pair / x1.5 witnesses)
  and wanderers roam - the eye count under any assertion was a
  dice roll. Heat.test_pin_eyes freezes it for the eight
  heat-asserting suites (the x1.0 band, every old expected number
  stands); smoke_reactive keeps the live scan because it ARRANGES
  the eyes. Found by the battery going red on two green-in-B13
  suites - the game was never wrong, the assertions were riding
  luck.
- smoke_difficulty: 22 green. Battery 29 green, 0 script errors.
  Docs: STATE/TESTING/CHANGELOG.

## B13 — dirty money (2026-11-20)
- The Velvet Room's back room opens (bible 4G). Walk to the door in
  the club quarter and the lamp-lit table is waiting.
- LAUNDER: the club owner takes 20% to make street paper clean -
  if he knows you. Win his darts first; at "drifting" he moves $600
  a day, at "close" whatever you're carrying. The books reset at
  midnight.
- STAKES: hi-lo dice at $50/$200/$500, and a choice every roll -
  palm the die in the timing window (the roll bends yours, but the
  pit boss counts hands; four and you're out for the day, hot) or
  play it straight and lose honest.
- Winning big gets you watched: $400 and the pit boss asks your
  name. $1000 and the club doesn't like being beaten - the room
  closes, the heat climbs, the quarter remembers.
- Dirty money burns a hole: spend it where cash runs short and the
  dirty part pays 25% extra ("he charges for not asking"). Sleep on
  $1000+ of it and the street sees the shape of it through your
  coat by morning.
- smoke_backroom: 42 green. Docs: STATE/TESTING/CHANGELOG.

## B12 — the reactive city (2026-11-20)
- The street answers (bible 4I). Heat gets names - quiet, talked
  about, marked, hunted, THE WAR - on the cash panel and in the
  world's mouth.
- At "marked" THE FIXER texts his price ($150 + $100 a point of
  heat) and waits at the market gate. Pay and tonight never
  happened; show up broke and he laughs at you. Once a day.
- At "the war" someone who studied your tape walks in. Kick-heavy,
  he leads with the blade; punch-heavy, he counters like a boxer -
  and his health has eaten as many hits as you've landed. The
  radio warned you first.
- Crowds are witnesses (violence in front of two-plus people costs
  half again), alleys are not (an empty street lets it slide).
- The radio recaps what actually happened: yesterday's real peak
  heat (hot enough and you're "the bare-handed man AGAIN"), your
  real style, the street's live version of events.
- Every beat spent retells a rumor, and rumors grow with the
  retellings: "they say" becomes "it grows every telling" becomes
  "they SWEAR - and the number is bigger now."
- Hollow blocks charge for their thin shelves (+8% wary, +12%
  turning hostile) and the shopkeepers tell you why; wary blocks
  board up their windows now too. Also fixed a real B6 bug the
  suite caught: market and foundry planks rendered a whole block
  over (a global/local frame mixup that riverside's origin
  position hid).
- smoke_reactive: 38 green. Docs: STATE/TESTING/CHANGELOG.

## B11 — the kidnap arc (2026-11-20)
- The story spine (bible 4H). From day 3, if someone matters enough
  (trust 40+), an UNKNOWN NUMBER calls: they took the one you trust
  most. Pay $1200 and they walk home. Refuse and you get three days.
- The investigation is feet and eyes - no combat until you earn it:
  three signs on three blocks (drag marks by the water, a van witness
  at the market, a burner phone in the foundry). Three signs point at
  the old press hall.
- The assault: three waves, then the boss alone - the kind-4 combo
  machine. When he falls, the phone rings with the choice.
- Both endings are real. CUT THEM DOWN: no money, a permanent enemy
  (the heat never fully cools again), and the bond locks Close
  forever - nothing decays it. TAKE THE MONEY: $3000 dirty, their
  patron, the friend is gone for good (the calls stop, the number
  dies), and every block's rep drops - the city hollows with you.
- The clock is real too: three days of anything else and they stop
  feeding them. No enemy, no money, just the loss. The morning report
  carries the arc every day it runs.
- The kidnapper redials while you dodge them; a ring queued behind a
  friend call still comes. The phone now names non-friend callers
  (UNKNOWN NUMBER) on the ring banner and the call screen. Trust
  learned two permanent states: locked (Close forever, floor 60) and
  gone (the dead do not drift).
- smoke_kidnap: 62 green. Docs: STATE/TESTING/CHANGELOG.

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
