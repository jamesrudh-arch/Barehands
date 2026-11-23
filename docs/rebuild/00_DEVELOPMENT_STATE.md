# 00 — DEVELOPMENT STATE (the living progress record)

> Updated after every meaningful work session and before any
> interruption. On "continue": read this file, inspect the repo, and
> resume at NEXT ACTION. This is a progress record inside the one
> project — not a backup, not a second implementation.

## Current stage

**STAGE 5 — THE OVERHAUL** (the owner's directive after on-phone
testing: cinematic realism, the complete game - the audit + plan:
`07_OVERHAUL_AUDIT.md`).

## S5.1 progress (the cast) - hero LIVE

The hero is now the Ready Player Me avatar (Mixamo skeleton family,
realistic proportions, 9 textured materials, bundled native
`assets/native/hero_rpm.tscn`). smoke_hero 30/30, smoke_home 26/26
on the new rig. TWO probe-caught laws banked in mixamo_lib.gd:
1. Mixamo clips drive bone POSITION tracks (not just the hips) -
   replayed on another rig they teleport the skeleton (head z=104 m
   probe-caught); cross-rig share is ROTATION-ONLY.
2. Pose-hash suites must hash the rotation BASIS (positions never
   change under rotation-only clips).
The VLM gate confirms the hero reads as a visible, animated human
(marginal on realism - the dim void lighting is S5.2's job). Combat
swings still fire without bespoke clips (combat._play_clip no-ops
missing clips); the UAL retarget (S5.1b) brings Punch_Cross/Jab,
Hit_Chest/Head, Death01, Roll + the full pistol set (43 CC0 clips
on Unreal naming - the retarget math is the next session's opener).
The enemy cast is still KayKit Barbarian (S5.1b too).

## S5.2 progress (the material city) - part 1 LIVE

The neighbourhood street is now a LIT NIGHT STREET (VLM gate:
"unmistakably night, classic empty city at 2 AM mood", 6/10 from
the audit's 1/10 black void): Polyhaven CC0 PBR set (asphalt +
normal / concrete / brick / corrugated / container) in
assets/v2/pbr with mat_lib.gd (per-surface UV scale, triplanar,
the night albedo lift 1.45 - Polyhaven maps photograph mid-grey
and read as void at night); the road + walks + apron wired;
the NightAir environment (filmic tonemap, ambient, fog); sodium
lamps: 15 posts, 4 REAL OmniLights (energy 3.0), hot emissive
heads + pool decals. smoke_street 33/33, smoke_hero 30/30,
smoke_home 26/26.

THREE banked laws from the probe war (each one cost a run):
1. **camera_rig._process calls make_current() EVERY FRAME** - any
   other camera is silently overridden; every "composed" capture
   was the rig's view until the audit tool sets rig.set_process(
   false). Pixel-proof caught it: under-lamp 32.7 (rig view) vs
   142.7 (real top-down view).
2. **Duplicate sibling names become @ClassName@N in 4.7** - the
   lamp probe matched "LampPost" exactly and saw 1 of 15. Name
   generated nodes by position (LampPost_-44_1), count by
   substring.
3. **The old lit-set keys (-46/-12/22/54) matched NO post grid
   position** - the four "real lights" never existed until this
   pass (floats compared with is_equal_approx now).

## S5.2 part 2 — DONE (the whole city is a lit night city)

All four areas now read as lit night locations (VLM: street 6/10,
club 6/10 from 3, docks 6/10 from 4): docks ground=concrete +
container maze textured + 2 sodium maze lamps WITH visible poles +
hot heads + the docks air lifted (filmic); club: 4 avenue lights
(2.2-2.6 energy) + hot window bands (1.6) + magenta/cyan pools +
wet smears down the line + air lifted; warehouse: concrete floor +
corrugated walls; neighbourhood: the wet-smear decals under its
lamps. Regression: areas 32/32, home 26/26, street 33/33 (the
first run's 3 failures were the RECYCLED import cache again —
S5.0's law: import before ANY suite run, not just the battery).
The gate's remaining wants (per-front lit doorway geometry, facade
depth, club sign scale) are later content passes.

## S5.1b — the UAL retarget: framework landed, visual gate pending

ual_lib.gd retargets the UAL pack's 43 CC0 mocap clips (Unreal bone
names, 65 bones) onto the RPM hero: full bone map incl. finger
chains, rotation-only, clips renamed to the Melee_* names
build_style_data expects. FOUR probe-caught laws banked:
(1) Godot's glTF importer STRIPS a trailing "_Loop" from looping
clips (Pistol_Idle_Loop imports as Pistol_Idle) - compare through
trim_suffix("_Loop");
(2) 4.x Animation key API is the generic track_get/set_key_value
(no track_get_key_rotation / track_get_num_keys - those are 3.x);
(3) UAL's rests are UE-axis-convention (pelvis rest 104 deg X off
RPM's) - both naive local carries (rest*delta, delta*rest) are
FALSIFIED: the first flips the body upside-down, the second bends
it horizontal;
(4) the global-rest conjugation (mode 2: q_dst = PRE * q * SUF
with PRE/SUF from both skeletons' bone_global_rest) is
NUMERICALLY correct - upright + stable through the clip (hips
1.02 / head 1.59 / feet 0.21, matching the source's own-skeleton
truth 0.83/1.46/0.10 scaled) - BUT the visual punch gate still
fails: RPM's rest is A-pose while the UAL clips are authored from
a guard stance, so arm/leg motion lands skewed (VLM: 'arms
tucked, rear leg disjointed'). That is the classic
reference-pose retargeting problem - no local formula fixes it.
INSTALL_COMBAT=false gates the combat/ambient installs off (the
raw ual(43) library stays for probes); smoke_hero 30/30.

NEXT for S5.1b: EITHER Godot's native BoneMap retarget at import
(SkeletonProfileHumanoid + the UAL .import options) OR a
reference-pose alignment pass (UAL ships an A_TPose clip - build
a per-bone correction from it). Then the visual punch gate, then
wire Hit_Chest/Hit_Head/Death01/Roll into enemies + the enemy
RPM swap.

## S5.1c — DONE (the enemy is a real human; 74c66be)

Michelle (realistic textured Mixamo rig from the three.js cast)
replaces the KayKit chibi as the thug: bundled native
cast_michelle.tscn (clean bone names + 65/65 skin rebinds), her own
ual_baked_michelle.res (the baker + THE ARMATURE COMPENSATION law:
D = ARM^-1 * S - Mixamo GLBs carry the 90-deg glTF axis fix on an
Armature NODE; the hero's ARM is identity), ual_lib.install
parameterized (baked_path + per-cast alias map), enemy.gd rewired
(the KayKit-era clip names alias onto UAL clips). Gates: idle/walk/
jab all read correctly (the walk verdict flipped once the camera
moved to a SIDE view - fore/aft stride is invisible from the
front), combat_r 28/28 + areas 32/32. Evidence:
download/overhaul_audit/shots/s51c_*.jpg.

## S5.3 — THE LIVING WORLD, PARTS 1+2 DONE (df5342d + this)

All three open-air districts are alive. The street (part 1): 5
tinted walkers, 2 lane sedans, MARLA + OLD DEE. Part 2: the club
strip gets the same (5 walkers, 2 sedans, VESPER at THE VELVET
ROOM + TONY at IRON PALM GYM) and the docks yard gets 3 walkers
along the harbour band + SAL THE FENCE at the fish market (no
lane parade there - working ground). SpawnStart markers added to
club + docks (the default 'start' travel law from part 1).
smoke_life 19/19 across all three areas (walkers walk - the club
run moved 5/5 - clips mounted, locals placed, cars drive, spawns
sane); areas regression 32/32. VLM composite: docks NPCs visibly
walk toward the player; the club shot shows figures moving + two
cars in the lane (its spawn view faces the venue wall - turn the
hero down-street for action views; the 'sparse' note is S5.2p3
lookdev, not the life systems).

## S5.2 part 3 (lookdev) — DONE

The code-built fronts get the real shopfront treatment, street and
club both. Per open front: TWO amber panes with dark casings +
mullion crosses PROUD of the facade face, a recessed dark doorway
(jambs + lintel + a dim warm interior-glow panel at the slot back),
a warm spill quad on the pavement (emissive, zero lights), BRICK on
all code massing via MatLib.surface_box (per-axis UV tiling - the
floor convention gives walls giant bricks). The club strip: same
doorways + a seeded SKYLINE of tenement silhouettes with sparse lit
windows behind the strip + real tinted queue-goers at the Velvet
Room curb (local.gd gained tints + label-less background bodies).
QUEUE BUG FIXED: the VelvetQueue stood across the street on the
gym's block. VLM gates: street storefront = windows flank the
doorway YES, brick YES, 'a plausible noir bar storefront' YES;
club = lit doorway + figures + backdrop YES. Suites: areas 32,
street 33, life 21 all green.
PROBE LAWS (expensive - four were new):
1. THE Z-AXIS FLIP: 'in front of the facade' is TOWARD THE STREET
   (rel -Z on the street's north fronts, rel +Z on the club's) -
   the first pane placement was 8cm INSIDE the wall slab and
   rendered as nothing for five captures (byte-stable pixels were
   the buried panes, not a frozen renderer).
2. A full-slot pale glow panel reads as 'one flat rectangle' - the
   interior glimpse must be dimmer and lower than the panes.
3. The composed-camera graveyard (continued): a traffic sedan can
   park 0.7m from the lens; the south front row sits at z=-7.2;
   verify capture coordinates against the area layout FIRST.
4. The interior RoomLight lamps render ~2m IN FRONT of the facade
   (pre-existing quirk that doubles as a free street wash).
5. Capture-time camera assertions belong INSIDE the capture loop.
Open nit: the doorway interior is a flat glow panel (no depth
gradient) - the interior dressing is occluded by it.

## S5.4 — THE PISTOL (first system of the roadmap)

Draw, aim stance, fire, auto-reload, holster - the UAL pistol set
on the hero's own bake. gun.gd rides the hero: the 'draw' action
(G key / pad 10 / the GUN touch pill) toggles; while drawn the
locomotion tree's idle/walk/run nodes swap to combat/Pistol_Idle
(the aimed shuffle, movement x0.55), the punch button fires and
the heavy button reloads. A code-built noir hand-cannon (~1.6x
scale, the readability law) bolts to the RightHand bone via
BoneAttachment3D - BUILT IN HAND SPACE (probe-measured at the aim
pose: hand +X points at the target, +Z is up; the first build ran
along +Z and pointed at the sky). The shot: a cone hitscan
(reach 34, arc 0.22 - sniper-tight 0.15 lost circling enemies),
closest target takes 26 + knockback through the SAME take_hit the
punches use (proven Hit_A/Hit_B reactions); dry shots roll
straight into the reload; 12+24 ammo, HUD 'PISTOL n / n' top-
right. The muzzle flash: an emissive box + a MOMENTARY OmniLight
(energy 5, 0.13s) - LUMINANCE-PROVEN (scene mean 47.5 -> 68.7 on
the shot frame, bright pixels x3) though a LOCALIZED burst needs
real-hardware bloom (the door-glow emission law again).
smoke_pistol 10/10; combat_r 28, hero 30 green.
TWO NEW PROBE LAWS:
1. 'parameters/<node>/animation' on an AnimationTree is a SILENT
   NO-OP for AnimationNodeAnimation - the blend tree's own node
   (.animation, a StringName) is the only writable target; this
   no-op had also hidden the pedestrian's flee sprint swap (fixed
   the same way - the flee speed came from velocity, the clip
   never swapped).
2. Freeze a circling enemy for staged captures (set_physics_process
   off) - it rotates the hero out of any fixed camera.
Open nits: the localized muzzle-burst read (bloom), the enemy
flinch capture timing (the reaction itself is the proven take_hit
chain), no aim reticle yet, no holster-slot UI.

## S5.5 — THE ECONOMY (dirty money has a route and a price)

market.gd rides Game: the pools (stash_cash = DIRTY from crime and
missions; clean_cash = laundered), THE VENDORS on the cast that
already stands at its doors (GRAB at Old Dee's = the bowl that
heals, Tony's gym counter = a box of twelve for the pistol,
Vesper's curb = LAUNDERING: 20% cut, capped at the drifting rate
per window - a timer stand-in for the day until the cycle lands),
THE SURCHARGE (any shop's dirty portion costs +25%), THE DEBT
(starts at the bible's tuned five grand, split family 3500 /
corp 1500) which EATS CLEAN ONLY - the phone LEDGER's quick-pay
chip (pay_chip 100) is the exit, and that is the loop's teeth:
you cannot hand the Corporation alley money. THE OVERNIGHT
PRESSURE (timer stand-in): interest ticks 0.5%, and a pocket
over the burn minimum gets noticed (+heat). Also fixed: the
fence now pays from the DIRTY pool it always meant to (it read a
nonexistent "cash" key - probe-caught by its own suite's
regression). HUD: DIRTY/CLEAN at a glance top-right; phone
LEDGER: the full split + the PAY chip. smoke_economy 27/27;
smoke_police 14/14 (the pool fix); VLM: the LEDGER reads DIRTY
$850 / CLEAN $480 / THE DEBT $4900 / PAY DEBT $100 all YES (nit
fixed: the launder hint's contrast). Regressions combat_r 28,
hero 30, pistol 10/10, areas 32, life 21 green. LAWS: the club's
area id is "club_district" (the suite's "club" travel silently
no-oped - a wrong id in travel() fails QUIET, always print the
arrival); when a system's pool key changes, its SUITE's set AND
check reads must both move (the police suite set stash but read
the dead "cash" key - the check failed while the log showed the
right numbers).
Open nits: laundering cap is the base "drifting" rate (no trust
system yet), the overnight pressure is a timer not the day/night
beat, the hi-lo back-room minigame (palm/sleight/suspicion keys
wait in the tuning table), no clothing stall, no price
variation by district.

## S5.6 — THE STORY SPINE: M2-M6 + PHONE 2.0 CALLS

The spine runs m0 through m6 on the real world. THE ENGINE grew
four conditions (at_area, reach, defeat counting enemy_down
events, area_clear, any_flag for choices), stage SPAWNS (in-area
stages spawn on enter; cross-area stages wait for the travel to
land - the landed-only path never fired M3's bottle or M5's
waves), GRAB choice spots behind police + market in the hero's
chain, the punch-at-the-door break (M4's grille: +2 heat, the
door_broken flag), and reward_clean (M5's Old Dee pays from the
till - the first clean reward). THE MISSIONS: M2 FIRST BLOOD
(Tony's gym, two muscle men), M3 THE OLD DRUNK (Marla's ask,
Dee's bottle, the delivery), M4 SHAKEDOWN (THE PAWN DESK: talk
the owner down or put a fist through the grille - both answers
verified), M5 TURF (stand with Dee, two waves of three, the
street must clear - the alley watcher counts), M6 THE CALL (the
Corporation rings: TAKE THE OFFER = their ammo line at half +
$1000 debt, REFUSE = harder men at x1.25 hp - both wired into
market + the spawner). PHONE 2.0: the CALLS app - the ring
banner counts down over the living street (the world keeps
moving), answer/decline, the offer's choice buttons, and a
MISSED ring pays what a decline pays. smoke_story 29/29;
regressions all green (econ 27, combat 28, hero 30, pistol 10,
police 14, areas 32, life 21). VLM: the ring banner + the call
screen read clean (tabs, lines, both buttons, no overlap). FOUR
LAWS: (1) a lambda's `var x := i` over a Variant loop var cannot
infer - the parse error KILLED THE WHOLE PHONE SCRIPT LOAD and
Game._phone went null with every phone behavior silently dead
(--check-only missed it; the runtime load caught it); (2) a
PanelContainer stretches EVERY child to its rect - tabs and body
as siblings drew on top of each other since the phone was born
(the call screen's third line made it loud; fix = one wrapper
VBox); (3) an every-frame _fill with queue_free ghosts a frame
of dying labels - refill only on change (dirty flag); (4) a
downed man's KO lands after his stun beat - defeat counts crawl
in over seconds; suites must wait for the cascade, not the
frame. WORKFLOW LAW: .gitignore had `download/` - every previous
session's evidence JPGs were never committed and the workspace
recycle destroyed them (the old commit messages name files that
no longer exist). The audit subtree is now un-ignored; evidence
lives in git from S5.6 on. Also this session: /tmp (Godot
binary, Xvfb) was recycled mid-project - re-download Godot
4.7.2 and restart Xvfb :99 when that happens.
Open nits: M2 teaches no Kickboxing yet (the skills pass), M4's
third way (pay his debt) unwired, call lines are instant (no
typewriter), no voicemail replay, CONTACTS still static, phone
MAP app unbuilt.

## S5.7-S5.14 — THE REMAINDER, IN ONE PASS (all six areas live)

**S5.7 THE WORLD SIM**: the beat clock (DUSK/MIDNIGHT/3 AM, a day
counter, save-carried), phase curves over every area's authored
air, THE RAIN MACHINE (a streak column riding the hero, the
ambience bed ducking forward, fog thickening, weather rolls with
rain frequent), the radio recap. smoke_world 15/15.
**S5.8**: the economy rides the beat - interest + the noticed
pocket per beat, laundering windows with a re-rolled drifting cap,
the midnight premium (+10% after MIDNIGHT). smoke_economy 34/34.
**S5.9 THE PHONE COMPLETE**: eight apps - CALLS, MAP (the drawn
six-area city + TAXI fast-travel at a clean fare), LEDGER, BOARD,
MESSAGES, NOTES (the journal), CONTACTS (the cast the story
introduced, with trust), SETTINGS (real audio buses + haptics);
the typewriter call lines + voicemail replay. smoke_phone2 17/17.
**S5.10 THE SKILLS**: learned from people, never given - set_style
refuses a locked discipline; M2's Tony teaches KICKBOXING (worn on
learn), M3's Dee teaches the DRUNKEN hint; M4's third answer
clears the owner's book ($300 clean) and THE PAWN DESK grille
opens; THE STALL sells real-material jackets. smoke_skills 18/18.
**S5.11 THE JOBS + THE KIDNAP ARC**: ten core jobs on the five
templates (Delivery/Rescue/Coerced/Hit/Turf), then the arc - COLD
CALL, THE INVESTIGATION (no combat), THE ASSAULT (the unlock_door
key unseals DOCK WAREHOUSE 9; the Lieutenant at 200 hp), THE
CHOICE: SAVE THEM (both pools zeroed, corp_enemy escalates the
spawner forever) or TAKE THE PAYOFF (+$2000 clean). m6 chains into
j1. smoke_jobs 27/27, smoke_story 29/29.
**S5.12 THE CITY SURFACE**: schedules move the cast by beat,
scorch + memorials persist where blood landed, the pawn desk boards
up (broken, unpaid), crowds thin under heat, the hot block taxes
sales (+10% over the premium), gossip distorts over beats.
smoke_surface 11/11.
**S5.13 THE WEB OF LEVERAGE**: the game's name - Marla's rumour
ladder (one a beat), interrogations (a mission's man talks when
he's down), the tail (follow one walker); two fresh pieces on one
name LINK; the squeeze is a GRAB ($150-200 clean, their trust pays
- floors at 70); clues go STALE after three beats. The BOARD app.
smoke_leverage 17/17.
**S5.14 THE LAST AREAS**: THE AIRPORT (terminal, departures board,
the parked plane, the pilot, cold floodlights) + THE SECOND CITY
(terracotta + amber, THE ANCHOR bar, the giver, a running fountain
- warmer than Cinder City ever allowed); the flight is a $100
clean GRAB at the plane (broke = the pilot says no), the return
flight stands at the plaza's east end; the map unlocks the
airport. smoke_city 15/15. Vehicles were ALREADY drivable
(vehicle.gd: enter/exit/steer/horn) - verified live, no new work
needed.

**LAWS this pass**: the inference law took five more scalps (every
Dictionary read needs an explicit type - a parse error still kills
the WHOLE SCRIPT LOAD silently); AABB takes Vector3s; the worldsim
AND the missions track the scene INSTANCE (a same-area travel
rebuilds under the same path - the re-place branches never fired);
patch scripts must be idempotent (re-runs half-applied the tuning
dict into duplicate keys and took the autoload chain down twice);
patch hunks are written against the REAL file text, never memory;
pay() returns ok, not invented keys; bump() reads a 0 default
(trust needed the 70 floor explicitly); the locals' meta is "who";
heat 10 spawns THE COPY into any wait; prices LAYER (midnight x
hot block) and expectations must compound honestly.

## NEXT ACTION (exact)

1. The FULL final battery: story/jobs/hero/combat_r/pistol/
police/areas/life have NOT been re-run since S5.12-S5.14 (world/
econ/phone2/skills/leverage/surface/city all green at the final
state; skills 18/18 after the heat-tax expectation fix). Run the
remaining eight, expect green, fix what isn't.
2. VLM gates outstanding: the rain in motion, the MAP app, the
BOARD app, THE CHOICE screen. Patterns proven in earlier gates.
3. Open nits: no music (the second city "its own music" is
unbuilt), no hangouts/fishing/darts (trust moves only through the
story + extortion), Grappling still teacherless (the Collector,
later), the map's second city shows "by plane only" - the airport
taxi is the route, NG+ Carried Debt unbuilt, no photo mode /
tournaments / collectibles (FULL tier per 02 §17).
4. Then: the FULL tier list in 02_MASTER_DEPMENT §17, or the
first on-device DEVICE REPORT (none has ever been received).

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
