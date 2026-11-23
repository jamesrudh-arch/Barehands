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

## NEXT ACTION (exact)

1. S5.1b: UAL retarget (below) — the GDScript rest-delta math.
2. S5.2 part 3 when convenient: per-front lit doorway geometry
   (the club gate's 'pools float on a featureless street'), brick
   on any remaining code massing, club sign scale.

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
