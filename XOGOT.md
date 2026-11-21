# XOGOT ON iPHONE - the device truth table (B18 device fix)

The game: Godot 4.7, Mobile renderer, GDScript only, no native
plugins. It runs in Xogot on an iPhone. This file is the exact
procedure for the phone and the line-by-line list of what is
VERIFIED (sandbox or PHONE, and how) versus what only the phone can
still prove (and the exact tap that proves it).

## THE ONE THING TO KNOW

Xogot boots the game into **STAGE 0** - a dark magenta diagnostic
launcher, **not an error screen**. Its job is to prove which build is
running and that every system is alive before the game starts.
**The game itself starts with the LAUNCH FULL GAME button** (first
button, bottom row). A GREEN banner ("ALL STAGES GREEN") means
everything is healthy - tap LAUNCH FULL GAME and play. A YELLOW banner
appears only when a stage actually FAILED.

## THE B18 DEVICE FIX (this zip) - what changed and why

The owner's photos of the B17 full game (2026-11-21) showed seven real
bugs. Every one has a named root cause now:

1. **NO HERO / the "blurry grey figure" - ONE bug.** The hero's gltf
   pieces point at texture files that were never shipped
   (`T_Hair_1_*`, `T_Regular_Male_*` - the import log says so on
   every boot, sandbox included). The hero rendered as a stack of pale
   untextured boxes: the grey figure WAS the hero. Fixed in
   hero_rig.gd: any piece without textures gets a flat noir dress
   (the training-dummy treatment), PLUS a permanent locator: a bright
   ring under the hero and a rim light that always comes from behind
   the camera (Settings: `hero_locator`, `hero_rim`).
2. **BUNCHED, DOUBLE-LABELLED BUTTONS + THE YELLOW BAR.** The old
   layout clamped each button into the safe area INDIVIDUALLY - on the
   phone that stacked several buttons onto the same spot (two labels
   on one circle) and shoved the cluster into the middle where the
   gold composure bar crossed it. New layout engine: one right-anchored
   grid, the whole cluster fitted into the safe area as a unit, a
   pairwise no-overlap pass, a 64-pixel minimum size, LIGHT / HEAVY /
   DODGE as the big three, GRAB/INTERACT appears only when usable,
   STYLE and PHONE in their own column, the composure bar moved to
   top-centre.
3. **TOO DARK.** The old XOGOT SAFE preset switched glow OFF and
   halved emission - on the phone the street went black. The new SAFE
   preset keeps a modest glow and full emission (the sign materials
   are capped at the source instead), the ambient light is ~3x
   brighter, the moon is brighter, and the asphalt/sidewalks/facades
   reflect more. Neon contrast kept: deep blue-black shadows, cyan and
   magenta accents.
4. **THE WHITE SIGN.** Verified in the official docs: the Mobile
   renderer's colour buffer (R10G10B10A2 UNORM) has reduced precision
   and maximum values, so emission above ~1.1 clips to a flat white
   slab. The three neon signs ran energy 2.1. Now: 1.1 at the source,
   the flicker cap is 1.15, and the big amber sign got a dark frame, a
   lettering strip and a darker body so it reads as a sign, not a
   rectangle.
5. **NO MAP.** There was no radar, route, waypoint or map anywhere in
   the repo (audit: only a text list inside the phone app). B18 ships
   the GTA-standard set: a round radar top-left that rotates with the
   camera (N marker, hero arrow, friends/enemies/POI blips with rim
   chevrons, district banner, objective + distance, tap to open the
   map), a yellow street-following route (A* on a street graph of the
   three blocks, recalculated at most 2 Hz), a big 3D objective beam
   with live distance, a top-centre compass arrow, and the FULL MAP
   (pan, pinch zoom, tap to pin a waypoint, legend, layer toggles,
   fog of war per block, no fast travel) opening from the radar tap,
   the pause menu's MAP button and the phone's Map app.
6. **PORTRAIT vs LANDSCAPE (the rotation bug).** Root cause of the
   landscape pile-up: the OLD code clamped each button into the safe
   area individually; after a rotation several buttons landed on the
   same spot (DODGE/GRAB/SPRINT text on one circle) and the composure
   bar crossed them. The B18 layout engine treats the cluster as ONE
   unit and re-lays out on every size/orientation change, the project
   now locks to sensor-landscape (portrait is locked out), and a
   duplicate-button-set audit (render suite + DEVICE REPORT) proves
   only one set can exist.
7. **NEVER LOST (the starting room).** The game now STARTS in the
   safehouse apartment: a small lit room with exactly ONE door - a
   breathing cyan frame with a THE STREET sign above it and an OPEN
   prompt when you stand at it. The contextual INTERACT button appears
   only when it is usable; the door swings open with a creak and the
   fade puts you on the street (and the street's safehouse panel has a
   GO INSIDE button, so the door works from both sides). A skippable
   guided intro walks the first minutes: FIND THE DOOR -> OPEN IT ->
   REACH THE TRAINING DUMMY, with live objective text + distance at
   the top, a confirmation sound per step, and the whole guidance
   stack pointing the way: the radar, the yellow street route, the 3D
   beam over the dummy, the compass arrow, and a SONAR ping from the
   target's direction that gets faster and louder as you close in
   (Settings: sonar_on). OBJECTIVE and HELP buttons sit above the
   attack cluster: OBJECTIVE shows the goal and turns the camera
   toward it; HELP repeats the hint. If you stall 20 seconds, a hint
   appears on its own.

Also new: the **DEVICE REPORT** (DBG button -> DEVICE REPORT, and in
SafeBoot) - one selectable text block with every fact the phone can
tell us, with a COPY LOG button.

## THE PHONE PROCEDURE (exact)

1. Unzip `Leverage_B18_NeverLost_2026-11-21.zip` in the Files app.
   You get a folder with `project.godot` DIRECTLY inside it - that
   folder IS the project. (The repo root is the project; no
   subfolder. Delete old LEVERAGE entries in Xogot first.) Your
   phone's photos still show the B17 stamp - nothing in this file is
   on your phone until THIS zip is imported.
2. Force-quit Xogot (swipe away).
3. Reopen Xogot -> Import -> pick THAT folder. The project name must
   read **LEVERAGE B18** - anything else is a stale copy.
4. WAIT for the import to fully finish (spinner stopped).
5. Run once. You land on STAGE 0: read the GREEN banner and tap
   **LAUNCH FULL GAME**.
6. Close and run a SECOND time after a fresh import (the truth run).
7. Read the BUILD line on STAGE 0: `B18 <hash> (<date>)`. Compare
   with the top commit at github.com/jamesrudh-arch/Barehands/
   commits/main - it must be the code commit right under the
   "B18 build stamp" commit.

## VERIFIED vs PHONE-ONLY

Legend: VERIFIED = proven in the sandbox, with the method.
PHONE-CONFIRMED = the owner's device proved it. PHONE-ONLY = still
needs your device, with the exact tap.

| # | Item | Status | How / what to send |
|---|------|--------|--------------------|
| 1 | Class-cache immunity: 33/33 autoloads alive, cache deleted | VERIFIED | stage0_check, smoke_null_watch, full battery, clean dirs |
| 2 | Stage0 + truthful banner + LAUNCH FULL GAME first | VERIFIED | stage0_check 18 checks (cache deleted) |
| 3 | Hero renders dressed (flat noir fallback for unshipped textures) + locator ring + rim light | VERIFIED (look) / PHONE-ONLY (on-device) | render_check: hero on screen, >= 4% of frame, region lit. Tap: walk, look for the ring under the hero |
| 4 | Buttons: no two overlap, >= 64 px, inside safe area, one label each, no bar crossing them | VERIFIED | render_check (49 checks) + smoke_controls 55 + smoke_face 31 |
| 5 | GRAB/INTERACT contextual (appears only when usable) | VERIFIED | smoke_controls + code; on the phone: stand by the dummy, GRAB appears |
| 6 | Street readable: mean luminance above the floor, not one grey slab, neon alive | VERIFIED (sandbox render) / PHONE-ONLY (device) | render_check mean_lum; on the phone: judge with your eyes |
| 7 | No pure-white sign: white area < 1.5%, sign energy <= 1.15, lettering + frame on the amber sign | VERIFIED | render_check white=0.0014, cap check; PHONE-ONLY for the eye test |
| 8 | Radar: visible, safe, no overlap, rotates, N marker, blips clamp to rim | VERIFIED | render_check radar suite + smoke_map 35 |
| 9 | Route: street-following, ends at target, recalcs off-route | VERIFIED | smoke_map (route 258 m to market, gates passed) + render_check |
| 10 | Full map: opens from radar tap + pause MAP + phone app; tap-to-pin waypoint; fog of war | VERIFIED | smoke_map entry-point counters + tap-pin checks |
| 11 | Cinematic force-ends at 8 s, HUD/controls never stay hidden | VERIFIED | opening_shot.gd watchdog + guarded handback; smoke_null_watch |
| 12 | DEVICE REPORT builds with every field + COPY LOG | VERIFIED | device_report.gd; on the phone: DBG -> DEVICE REPORT -> COPY LOG |
| 13 | hdr_2d experiment (does 2D HDR stop the white signs?) | VERIFIED | measured on/off with render_check - see CHANGELOG B18; it is a 2D-canvas setting, the sign fix is the material cap; default stays OFF |
| 14 | Full game on device: hero visible + moves, controls in the right-thumb zone, street readable | **PHONE-ONLY** | tap: LAUNCH FULL GAME, walk 30 s. Send: one line in words |
| 15 | Landscape: cluster stays inside the screen, no bar crossing; portrait locked out | **PHONE-ONLY** | rotate; send one line |
| 16 | The DEVICE REPORT from the phone | **PHONE-ONLY** | DBG -> DEVICE REPORT -> COPY LOG -> paste the text |
| 17 | Orientation policy: sensor_landscape; one button set; both-orientation layout contract | VERIFIED (sandbox) / PHONE-ONLY (device) | render_check portrait pass + duplicate audit; device: rotate, look |
| 18 | The apartment tutorial: room, glowing door, OPEN prompt, contextual INTERACT, door opens to street, steps advance, hint after 20 s, sonar rate increases | VERIFIED | smoke_guide 17 checks (headless, real scene) |
| 19 | Both-side doors + ENTER prompts (noodle shop, safehouse GO INSIDE) | VERIFIED (code + suite) / PHONE-ONLY (feel) | smoke_guide + interior/safehouse wiring; device: walk in and out |

## THE DEVICE REPORT (the one diagnostic to rule them all)

In the full game: the small **DBG** button (top-left) -> **DEVICE
REPORT** -> select the text -> **COPY LOG** -> paste it back. It
contains: the build stamp, renderer/API/adapter, window + safe area,
FPS, draw calls, hdr_2d/tonemap/exposure/ambient/glow, hero + camera
truth (exists/position/visible/current/target), the cinematic state
and whether the 8 s force-end fired, the orientation policy and the
duplicate-button-set audit, every touch button's rectangle and label
count, the joystick state, the current objective + distance, the
nearest door + its state, the sonar ping interval, the autoload
census, the materials of the named suspects (the big sign, the door,
the grey figure), the radar/route/waypoint facts, and the last 10
errors or warnings.

## WHAT I NEED FROM YOU (three taps, in order)

1. **Play the opening minute.** LAUNCH FULL GAME - you wake in a small
   room. Follow the intro: walk to the glowing door, tap INTERACT,
   step outside, reach the dummy. -> Send ONE line in words: did the
   room + door + steps work, is the hero visible (ring under them),
   are LIGHT/HEAVY/DODGE big and readable bottom-right, is the street
   readable, radar top-left?
2. **Copy the report.** DBG -> DEVICE REPORT -> COPY LOG -> paste the
   text back. (Ground truth for anything that still looks wrong.)
3. **Landscape + map.** Rotate the phone (portrait should be locked
   out; buttons stay clean?); tap the radar, tap the map to pin a
   waypoint (a yellow route draws?). -> Send one line.

If something is broken, the report from (2) already tells us which
system; SafeBoot's one-at-a-time toggles remain as the deep drill.
