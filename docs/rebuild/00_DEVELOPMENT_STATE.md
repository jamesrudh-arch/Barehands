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

## NEXT ACTION (exact)

1. S5.1c polish: frame-catch the 0.18s SWING window (the burst
   probe timed out - poll state==SWING then capture 3 frames at
   0.07s), capture the thug's Hit_A/Death_A reactions in-game, and
   give the walk a counter-arm swing (the one open VLM nit).
2. S5.3 THE LIVING WORLD: pooled pedestrians (waypoint walk,
   phone idle, flee + call-police states) + spline traffic + the
   named-NPC routine table (the fixer at the club, the fence at
   the docks). THE gap between this build and the LEVERAGE
   vision's 'city that feels alive'.
3. S5.2 part 3 when convenient: per-front lit doorway geometry,
   brick on remaining code massing, club sign scale.
4. S5.4+: police heat, phone 2.0 + missions M2-M6, weapons (the
   UAL pistol set is already retargeted + baked), vehicles,
   map/GPS, rain, audio, progression - the LEVERAGE roadmap.

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
