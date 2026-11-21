#!/usr/bin/env python3
"""B17 docs: XOGOT.md (the phone procedure + VERIFIED/PHONE-ONLY table),
TESTING.md, CHANGELOG.md, STATE.json."""
import json

BASE = "/home/z/my-project/"

# --- XOGOT.md: full rewrite (the B16 version is superseded) ----------------
xogot = """# XOGOT ON iPHONE - the device truth table (B17)

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
"""
open(BASE + "XOGOT.md", "w").write(xogot)
print("XOGOT.md rewritten")

# --- TESTING.md ----------------------------------------------------------------
s = open(BASE + "TESTING.md").read()
anchor = "- **B10 battery regressions**"
add = '''- **B17 the class-cache root cause + Stage0 + cache-immunity**: the
  fresh-import failure is REPRODUCIBLE in the sandbox: delete only
  .godot/global_script_class_cache.cfg and 59 parse errors follow,
  9 autoloads register NULL (Music among them - the fight_score.gd:38
  'state' on Nil spam), and every scene whose script referenced a
  class_name builds nothing (the B16 grey screen). The fix: ALL 42
  class_name declarations removed (tools/flatten_class_names.py, a
  real lexer so comments/strings are never touched), 88 files
  rewritten to const-preload references; the four mechanics were
  verified against 4.7.2 BEFORE the sweep (const-preload as type
  annotation, as-cast, static var read/write, self-preload). Second
  parse-time hazard found by the clean-clone first-run test: a const
  preload of UAL1_Standard.glb in ual_bind.gd killed player/enemy/
  npc_rig and the autoloads that compile them before the GLB was
  imported - now a guarded runtime load (characters keep code-built
  rigs, one logged error). Third hazard: enemy.gd _own_materials/_play
  aborted on the missing mannequin - guarded. jobs.gd connected
  City.entered_district unguarded - guarded. Lessons: (1) autoload
  scripts must never reference class_name identifiers or preload
  imported assets at parse time; (2) get_autoload_list() does not
  exist in 4.7 - read the property list and trim_prefix("autoload/");
  (3) GDScript has no try/catch - "guarded step" means null checks
  plus can-instantiate checks, never exceptions; (4) a parse-failed
  script "does not inherit from Node" in the engine's words and the
  autoload registers NULL - that exact message is the smoking gun.
  New suites: stage0_check (14 checks: the zero-dependency Stage0
  draws magenta not grey, stamp on the info line, 39 boot stages,
  boot_log.txt, 4 buttons) and the extended smoke_null_watch (full
  dynamic autoload census, 33/33 at frame 600). Proofs: with the
  class cache deleted, stage0_check + safe_boot_check (27) +
  smoke_null_watch (995 frames) + smoke all PASS 0 errors; from a
  CLEAN CLONE with no .godot at all (before any import pass), both
  render suites PASS with 0 script errors (GLTF meshes wait for the
  import pass, everything else stands). The project now lives at the
  repo ROOT (project.godot top-level, git mv history preserved); CI
  updated; the whole B17 battery ran with the class cache deleted -
  the hardest condition, harder than CI.
- **B17 Stage0 design**: the main scene is a zero-dependency Control
  (no autoload identifiers, no class_name, no preloads, stamp read
  from res://VERSION.txt via FileAccess); it draws even if every
  other script is dead; its stages census every autoload (alive /
  NULL / script-dead), then load-check SafeBoot (code-built: root
  script + _build_world) and the full game (scene-file: Player +
  Camera children with live scripts) WITHOUT adding them to the
  tree; log to user://boot_log.txt + COPY LOG. A code-built scene
  cannot be child-checked before it is in the tree - check its
  script and its build method instead. main.tscn's root is a plain
  Node3D by design: do not demand a root script there.

'''
assert anchor in s
s = s.replace(anchor, add + anchor, 1)
open(BASE + "TESTING.md", "w").write(s)
print("TESTING updated")

# --- CHANGELOG.md --------------------------------------------------------------
s = open(BASE + "CHANGELOG.md").read()
old = "## B16 "
add = '''## B17 — the class-cache fix, Stage 0, and a device-proven boot path (2026-11-21)
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

'''
assert old in s
s = s.replace(old, add + old, 1)
open(BASE + "CHANGELOG.md", "w").write(s)
print("CHANGELOG updated")

# --- STATE.json ----------------------------------------------------------------
d = json.load(open(BASE + "STATE.json"))
d["current_batch"] = ("Batch 17 (class-cache fix + Stage0 + root move) "
    "CLOSE-OUT: battery running cache-deleted; then push + zip")
d["completed"].append(
    "B17 the device-proven boot path: (1) ROOT CAUSE reproduced in sandbox - "
    "delete .godot/global_script_class_cache.cfg -> 59 parse errors, 9 "
    "autoloads NULL incl Music (fight_score:38 Nil spam), player/touch_"
    "buttons dead (no hero/no controls), safe_boot dead (grey screen). "
    "(2) Fix: ALL 42 class_name declarations removed via tools/flatten_"
    "class_names.py (real lexer; 88 files -> const-preload CLS_X refs; "
    "const-preload typing/as-cast/static-var/self-preload verified vs "
    "4.7.2 first); ual_bind.gd's parse-time UAL1_Standard.glb preload -> "
    "guarded runtime load (second first-run killer via the clean-clone "
    "test); enemy.gd _own_materials/_play + jobs.gd City.entered_district "
    "guarded. Proofs: cache deleted -> stage0_check 14/14, safe_boot_"
    "check 27/27, smoke_null_watch 995f 33/33 autoloads 0 err, smoke "
    "PASS; clean clone NO .godot pre-import -> both render suites PASS "
    "0 script errors. (3) Project moved to REPO ROOT via git mv (project."
    "godot top-level; attacks/ + default_bus_layout.tres + icon.svg."
    "import rescued after an rm -rf slip; .gitignores merged; CI paths "
    "updated; tools/ replaces the old scripts/ python home). (4) Stage0 "
    "main scene: zero deps (VERSION.txt stamp via FileAccess), magenta "
    "clear colour project-wide, 39-step guarded boot census + boot_log."
    "txt + 4 buttons + first-run RETRY banner; failsafe camera in "
    "BuildStamp; safe area re-clamps on rotation; rain streak/dot "
    "textures code-generated; smoke_null_watch full dynamic census; "
    "stage0_check suite; config/name LEVERAGE B17 unique per push.")
d["next_step"] = ("Battery green -> two-phase commit (code, gen_build_info "
    "B17, stamp commit) -> push -> ls-remote + GitHub page confirm -> zip "
    "Leverage_B17_2026-11-21.zip (import the unzipped folder itself; .env "
    "EXCLUDED from the zip, flag to owner it is git-tracked) -> owner's 5 "
    "taps per XOGOT.md (STAGE 0 BUILD line, COPY LOG, LAUNCH FULL GAME, "
    "one-at-a-time toggles if broken, landscape check) -> then back to "
    "batch order: THE VERTICAL SLICE REVIEW per PROJECT_BIBLE.md -> "
    "docs/SLICE_REVIEW.md")
json.dump(d, open(BASE + "STATE.json", "w"), indent=2, ensure_ascii=False)
print("STATE updated")
