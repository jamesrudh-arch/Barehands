# XOGOT ON iPHONE - the device truth table (B18)

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
button, bottom row since B18). A GREEN banner ("ALL STAGES GREEN")
means everything is healthy - tap LAUNCH FULL GAME and play; nothing
is importing and nothing needs waiting for. A YELLOW banner appears
only when a stage actually FAILED.

Why this section exists: B17's banner said "FIRST-RUN IMPORT IN
PROGRESS - wait for Xogot to finish importing, then tap RETRY" on
exactly that healthy state, because on Xogot the class cache NEVER
exists (see below) - so the phone showed the warning on every run
while every line said PASS, and the owner rightly read the screen as
"the game cannot launch". B18 fixed the wording; a phone photo of
B17 (2026-11-21) had already proven everything was green underneath.

## THE B17 ROOT CAUSE, FOUND, REPRODUCED - AND PHONE-CONFIRMED

Every phone failure before B17 traced to ONE mechanism, reproduced in
the sandbox on 2026-11-21 (log: delete .godot/global_script_class_
cache.cfg, run the game):

A fresh Xogot import starts with NO global class cache. Any script
that referenced a class_name identifier (there were 42 declarations
and ~180 cross-file references) failed to parse. Autoload scripts
that did this (music.gd referenced Enemy/Player; heat, city,
tactics, combo_input, progression, visual, friend_help, world_sim,
jobs, blocks too) died with "Failed to instantiate an autoload ...
does not inherit from 'Node'" and registered as NULL singletons:

- Music NULL -> fight_score.gd:38 "Invalid access to property or
  key 'state' on a base object of type 'Nil'" EVERY FRAME
- player.gd dead -> the hero capsule had no script: no hero
- touch_buttons.gd dead -> no touch controls
- block_builder's Label3D signs never built + pre-B15 glow values
  -> white signs and doors with a huge halo (stale build on top)
- B16's safe_boot.gd dead -> the grey screen (Godot's default clear
  colour, nothing drawn)
- the grey figure: node "Dummy" (enemy.tscn, kind 0 training
  dummy) - grey up to B14, worn tan since B15

B17 removes the whole class: every class_name declaration is gone
(88 files rewritten to const-preload references, mechanics verified
against 4.7.2 first), the only parse-time preload of an imported
asset (UAL1_Standard.glb) is now a guarded runtime load, unguarded
nulls found on the way (enemy mannequin, UAL attach, jobs' City
signal) are guarded, and the project sits at the REPO ROOT with a
unique name per batch so a stale cached import cannot load.

**PHONE-CONFIRMED (photo, 2026-11-21):** the owner's B17 run landed
on STAGE 0 with `class cache: MISSING` (the phone's PERMANENT state -
Xogot never writes it) and still showed all 33 autoloads PASS
including Music, SafeBoot PASS, FULL GAME PASS, 0 FAIL lines, on
BUILD B17 d209d01 - the exact pushed code commit. The condition that
killed every previous build now boots clean on the device itself.

## THE PHONE PROCEDURE (exact)

1. Unzip `Leverage_B18_2026-11-21.zip` in the Files app. You get a
   folder with `project.godot` DIRECTLY inside it - that folder IS
   the project. (The repo root is the project now; no subfolder.)
2. Force-quit Xogot (swipe away).
3. Reopen Xogot -> Import -> pick THAT folder (the one containing
   project.godot). The project name must read **LEVERAGE B18** -
   anything else is a stale copy: delete old Xogot project entries
   and import again.
4. WAIT for the import to fully finish (spinner stopped).
5. Run once. You land on STAGE 0 (dark magenta launcher): read the
   GREEN banner and tap **LAUNCH FULL GAME** (first button) to play.
6. Close and run a SECOND time after a fresh import (the truth run).
7. Read the BUILD line on STAGE 0: `B18 <hash> (<date>)`. Compare
   with the top commit at github.com/jamesrudh-arch/Barehands/
   commits/main - it must be the code commit right under the
   "B18 build stamp" commit.

## VERIFIED vs PHONE-ONLY

Legend: VERIFIED = proven in the sandbox, with the method.
PHONE-CONFIRMED = the owner's device proved it (photo/log sent).
PHONE-ONLY = still needs your device, with the exact tap.

| # | Item | Status | How / what was sent |
|---|------|--------|--------------------|
| 1 | Class-cache immunity: 0 parse errors, 33/33 autoloads alive with the cache deleted | VERIFIED | cache deleted: stage0_check 18 checks, smoke_null_watch 993 frames, smoke PASS, 0 SCRIPT ERROR |
| 2 | First run before ANY import pass (clean clone, no .godot): Stage0 + SafeBoot PASS, 0 script errors | VERIFIED | clean clone + Xvfb opengl3 render (B17); re-proven B18 with cache deleted |
| 3 | Stage0 screen: magenta, stamp, 39 numbered boot stages, truthful banner, COPY LOG, user://boot_log.txt, 4 buttons, LAUNCH FULL GAME first | VERIFIED | stage0_check 17 checks (cache present) + 18 checks (cache deleted: green banner names LAUNCH FULL GAME, colour green) |
| 4 | SafeBoot: floor, real hero, real touch controls, follow camera, dummy, big log, 8 one-at-a-time toggles | VERIFIED | safe_boot_check 27/27 (B18 re-run, cache deleted) |
| 5 | Build stamp at boot corner + debug menu + Stage0 + SafeBoot + VERSION.txt | VERIFIED | gen at commit time; the suite compares the corner label against BuildInfo.STAMP itself (never a hardcoded batch string - that went stale once) |
| 6 | Music no longer Nil-able by parse failure; the four bare Music sites guarded | VERIFIED | reproduction log (before: Music NULL) vs post-fix census; null_watch 0 errors |
| 7 | White-sign render test: pure-white area < 1.5%, orange halo < 10% | VERIFIED | render_check (26 checks) under render, every battery |
| 8 | Rain: code-generated streak + dot textures, billboard particles | VERIFIED | rain.gd runtime ImageTexture; render_check pale-block scan |
| 9 | Grey figure = node "Dummy", tan since B15 | VERIFIED | SafeBoot log; safe_boot_check asserts "Dummy" |
| 10 | Cinematic watchdog: force-finish at 12 s | VERIFIED | opening_shot.gd; smoke_null_watch asserts it landed |
| 11 | Touch controls inside safe areas, incl. landscape rotation | VERIFIED | _clamp_safe_area + viewport size_changed re-clamp; smoke_controls |
| 12 | STAGE 0 draws on the phone (magenta, not grey) | **PHONE-CONFIRMED** | photo IMG_9292 (2026-11-21): magenta screen, title, all four buttons, census log |
| 13 | The BUILD stamp matches github main | **PHONE-CONFIRMED** | photo: `B17 d209d01 (2026-11-21 09:10 UTC)` = the code commit under stamp commit 3969938 |
| 14 | The boot stages all PASS on device | **PHONE-CONFIRMED** | photo: 33/33 autoloads PASS (incl. Music), SafeBoot PASS, FULL GAME PASS, 0 FAIL lines |
| 15 | Full game: hero moves, controls visible, signs coloured, rain streaks | PHONE-ONLY | tap: LAUNCH FULL GAME, walk with the left thumb ~30 s. Send: what you see (photo if wrong) |
| 16 | Xogot re-imports cleanly after deleting an old entry | **PHONE-CONFIRMED** | fresh B17 import ran the exact pushed code (the BUILD line is the proof) |
| 17 | GPU adapter name + renderer on device | **PHONE-CONFIRMED** | photo: Godot 4.7.2-stable iOS, renderer mobile, GPU Apple A15 GPU (Apple8); also `class cache: MISSING` measured on device |
| 18 | If anything is still wrong: which system | PHONE-ONLY | tap: LAUNCH SAFEBOOT, toggle ONE system at a time. Send: which toggle breaks it + COPY LOG |
| 19 | Landscape rotation: buttons stay inside the screen | PHONE-ONLY | rotate to landscape in the full game. Send: "buttons stay inside" or a photo |

## THE VISUAL DEBUG PANEL (in-game)

Pause -> DEBUG -> VISUAL DEBUG (or the debug corner button):
glow on/off, glow intensity, bloom, HDR threshold, tonemap cycle,
sign+window emission, shadows, rain on/off, rain streak width,
ground splash, decals, outlines, NPCs, camera height, camera
distance, XOGOT SAFE preset, NIGHT (desktop) preset, COPY SETTINGS,
SCREENSHOT PNG. Every change applies live.

## WHAT I NEED FROM YOU (the remaining taps)

Your CURRENT B17 import is fine for these - the game code did not
change in B18 (only the diagnostic screen's banner wording and
button order); on B17, LAUNCH FULL GAME is the SECOND button from
the left.

1. On STAGE 0: tap **LAUNCH FULL GAME**, walk around 30 s with the
   left thumb. -> Send: "hero moves, controls visible, signs
   coloured, rain streaks" or what differs (photo if wrong).
2. Rotate the phone to landscape in the full game. -> Send:
   "buttons stay inside the screen" or a photo.
3. If (and only if) something is broken: back on STAGE 0, LAUNCH
   SAFEBOOT, toggle ONE system at a time until it breaks. -> Send:
   which toggle + COPY LOG.

The B18 zip (`Leverage_B18_2026-11-21.zip`) is there whenever you
re-import next - it shows the green truthful banner and puts
LAUNCH FULL GAME first. With (1) and (2) clean, the device-proven
boot path is fully closed and the next batch is the vertical slice
review per PROJECT_BIBLE.md.
