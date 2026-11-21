# XOGOT ON iPHONE - the device truth table (B17)

The game: Godot 4.7, Mobile renderer, GDScript only, no native
plugins. It runs in Xogot on an iPhone. This file is the exact
procedure for the phone and the line-by-line list of what is
VERIFIED in the sandbox (and how) versus what only the phone can
prove (and the exact tap that proves it).

## THE B17 ROOT CAUSE, FOUND AND REPRODUCED

Every phone failure so far traces to ONE mechanism, reproduced in
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

## THE PHONE PROCEDURE (exact)

1. Unzip `Leverage_B17_2026-11-21.zip` in the Files app. You get a
   folder with `project.godot` DIRECTLY inside it - that folder IS
   the project. (The repo root is the project now; no subfolder.)
2. Force-quit Xogot (swipe away).
3. Reopen Xogot -> Import -> pick THAT folder (the one containing
   project.godot). The project name must read **LEVERAGE B17** -
   anything else is a stale copy: delete old Xogot project entries
   and import again.
4. WAIT for the import to fully finish (spinner stopped).
5. Run once. You land on STAGE 0 (dark magenta diagnostic screen).
6. Close and run a SECOND time (the truth run).
7. Read the BUILD line on STAGE 0: `B17 <hash> (<date>)`. Compare
   with the top commit at github.com/jamesrudh-arch/Barehands/
   commits/main - it must be the code commit right under the
   "B17 build stamp" commit.

## VERIFIED vs PHONE-ONLY

Legend: VERIFIED = proven in the sandbox, with the method.
PHONE-ONLY = needs your device, with the exact tap and what to
send back.

| # | Item | Status | How / what to send |
|---|------|--------|--------------------|
| 1 | Class-cache immunity: 0 parse errors, 33/33 autoloads alive with the cache deleted | VERIFIED | class cache deleted, stage0_check + smoke_null_watch + smoke all PASS, 0 SCRIPT ERROR |
| 2 | First run before ANY import pass (clean clone, no .godot): Stage0 PASS 14 checks, SafeBoot PASS 27 checks, 0 script errors | VERIFIED | clean clone + Xvfb opengl3 render, suites stage0_check / safe_boot_check |
| 3 | Stage0 screen: magenta, stamp, 39 numbered boot stages, COPY LOG, user://boot_log.txt, 4 buttons | VERIFIED | stage0_check (14 checks) under render |
| 4 | SafeBoot: floor, real hero, real touch controls, follow camera, dummy, big log, 8 one-at-a-time toggles | VERIFIED | safe_boot_check (27 checks) under render |
| 5 | Build stamp at boot corner + debug menu + Stage0 + SafeBoot + VERSION.txt | VERIFIED | gen at commit time; stage0/safeboot checks assert it on screen |
| 6 | Music no longer Nil-able by parse failure; the four bare Music sites guarded (one-time error, no spam) | VERIFIED | reproduction log (before: Music NULL) vs post-fix census (33/33); null_watch 995 frames 0 errors |
| 7 | White-sign render test: pure-white area < 1.5%, orange halo < 10% | VERIFIED | render_check (26 checks) under render, every battery |
| 8 | Rain: code-generated streak + dot textures, billboard particles (no pale squares, no texture file to lose) | VERIFIED | rain.gd textures are runtime ImageTexture; render_check pale-block scan passes |
| 9 | Grey figure = node "Dummy", tan since B15 | VERIFIED | node named in the SafeBoot log; safe_boot_check asserts "Dummy" in the log |
| 10 | Cinematic watchdog: force-finish at 12 s | VERIFIED | opening_shot.gd (12000 ms), smoke_null_watch asserts it landed |
| 11 | Touch controls inside safe areas, incl. landscape rotation | VERIFIED | _clamp_safe_area + viewport size_changed re-clamp; smoke_controls |
| 12 | STAGE 0 draws on YOUR phone (magenta, not grey) | PHONE-ONLY | tap: run the project. Send: photo or "STAGE 0 shows magenta + BUILD line B17 <hash>" |
| 13 | The BUILD stamp matches github.com main | PHONE-ONLY | tap: read the STAGE 0 BUILD line. Send: the exact line |
| 14 | The boot stages all PASS on device | PHONE-ONLY | tap: COPY LOG on STAGE 0. Send: the whole pasted log |
| 15 | Full game: hero moves, controls visible, signs coloured, rain streaks | PHONE-ONLY | tap: LAUNCH FULL GAME, walk with the left thumb. Send: what you see (photo if wrong) |
| 16 | Xogot re-imports cleanly after deleting an old entry | PHONE-ONLY | tap: delete old "Bare Hands 3D"/"LEVERAGE B16" entries in Xogot, import fresh. Send: the project name it shows |
| 17 | GPU adapter name + renderer on device | PHONE-ONLY | tap: COPY LOG on STAGE 0 (line 2). Send: the log |
| 18 | If anything is still wrong: which system | PHONE-ONLY | tap: LAUNCH SAFEBOOT, toggle ONE system at a time. Send: which toggle breaks it + COPY LOG |

## THE VISUAL DEBUG PANEL (in-game)

Pause -> DEBUG -> VISUAL DEBUG (or the debug corner button):
glow on/off, glow intensity, bloom, HDR threshold, tonemap cycle,
sign+window emission, shadows, rain on/off, rain streak width,
ground splash, decals, outlines, NPCs, camera height, camera
distance, XOGOT SAFE preset, NIGHT (desktop) preset, COPY SETTINGS,
SCREENSHOT PNG. Every change applies live.

## WHAT I NEED FROM YOU (the 5 taps, in order)

1. Import the unzipped `Leverage_B17_2026-11-21` folder (the one
   with project.godot inside), WAIT for import, run, close, run
   again. -> Send: the STAGE 0 BUILD line (or a photo).
2. On STAGE 0: COPY LOG. -> Send: the pasted log.
3. LAUNCH FULL GAME, walk around 30 s. -> Send: "hero moves, controls
   visible, signs coloured, rain streaks" or what differs.
4. If (and only if) something is broken: LAUNCH SAFEBOOT from STAGE
   0, toggle ONE system at a time until it breaks. -> Send: which
   toggle + COPY LOG.
5. Rotate the phone to landscape in the full game. -> Send: "buttons
   stay inside the screen" or a photo.

That is everything. With (1) and (2) the on-device truth is on the
table: the stamp settles staleness, the census settles every
autoload, and the rest is a named toggle away.
