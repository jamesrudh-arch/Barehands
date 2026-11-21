#!/usr/bin/env python3
"""B16 docs: TESTING.md, XOGOT.md, CHANGELOG.md, STATE.json."""
import json

BASE = "/home/z/my-project/"

# --- TESTING.md
s = open(BASE + "TESTING.md").read()
anchor = "- **B10 battery regressions**"
add = '''- **B16 staleness-proofing + SafeBoot + the Music-null guards**: two
  new suites. smoke_null_watch boots the REAL main.tscn untouched and
  runs 600+ frames: any SCRIPT ERROR / Nil / null in the window fails
  it (the battery wrapper greps; in-game GDScript cannot capture
  native error output), and it asserts the end state - hero alive,
  touch controls visible, the cinematic landed, input unlocked, the
  Music singleton alive. PASSES at 995 frames / 6.9 s wall, 0 errors
  (headless ticks faster than wall clock: wait for ever_finished or
  the watchdog before judging, never a bare frame count). Gotcha:
  ProjectSettings.get_autoload_list() does not exist in 4.7 - read
  the property list and trim_prefix("autoload/"). enemy.tscn's real
  property is kind, NOT mode (main.tscn had silently been setting an
  invalid 'mode = 0' since the beginning - it only worked because
  kind's default is also 0). safe_boot_check renders the SafeBoot
  diagnostic scene with a real renderer: 27 checks PASS - base world
  (floor/env/light, real player.tscn hero, FollowCamera, real
  touch_buttons + stick_input with 9 visible buttons, Dummy), the log
  panel filled with the census, the boot-corner stamp on screen, the
  frame visibly lit, and EVERY system toggle (cinematic, city, rain,
  signs, npcs, post, music, fightscore) turned on and off cleanly.
- **B16 the Music-null root cause narrative**: fight_score.gd:38 was
  `match Music.state:` - on the device the Music singleton registers
  as Nil (sandbox cannot reproduce a device-side registration
  failure; every suite was green while the phone spammed). A null
  autoload reference ABORTS the calling function every frame:
  fight_score._process (the spam), player._retry_step +
  _accept_retry, heat._process (Music.set_heat), dialogue line
  starts (Music.duck) - that abort chain is the "no hero, no touch
  controls" symptom pattern. All four sites now null-guard with a
  ONE-TIME push_error (never spam). SafeBoot's autoload census (name
  by name, /root/<Name> null or ok) is the on-device answer to
  "which singleton died".
- **B16 build stamp + stale-build proof**: BuildInfo (generated
  const, scripts/gen_build_info.py writes it + VERSION.txt from the
  code commit hash, then a stamp commit lands above it), BuildStamp
  autoload (top-right corner label from boot + window title),
  debug-menu stamp line, SafeBoot header + log. config/name is now
  unique per batch ("LEVERAGE (Bare Hands) B16") - Xogot caches
  projects by name and an unchanged name lets a stale cached import
  masquerade as a fresh one (the prime stale-build suspect). Root
  README states the import folder (bare-hands/) at the top.

'''
assert anchor in s
s = s.replace(anchor, add + anchor, 1)
open(BASE + "TESTING.md", "w").write(s)
print("TESTING updated")

# --- XOGOT.md
s = open(BASE + "XOGOT.md").read()
anchor = "## What is verified where"
add = '''## B16 — the stale-build question + SafeBoot (READ FIRST)

The phone showed old-build symptoms after a "clean" import. Prime
suspect: Xogot caches projects by NAME, and the project name was
"Bare Hands 3D" since the beginning - a stale cached copy can load
instead of the fresh import. B16 changes that:

1. The project is now named **"LEVERAGE (Bare Hands) B16"** (unique
   per batch) - a fresh import can no longer collide with an old
   cached name. If Xogot still shows an old copy, delete the old
   project entry in Xogot first, then import `bare-hands/`.
2. **BUILD STAMP**: batch + commit + time, top-right corner from
   boot. **Read it before testing anything.** It must say `B16 <hash>`
   and match github.com/jamesrudh-arch/Barehands/commits/main (the
   top commit; VERSION.txt at the repo root documents the pairing).
   If it says anything else, or the corner is empty, you are NOT on
   B16 - stop and tell the agent what the stamp says.
3. The game now boots into **SafeBoot** (temporary main scene): a
   plain lit floor, the real hero, the real touch controls, one
   dummy, and a big diagnostic log. **COPY LOG** puts the whole log
   on your clipboard - paste it back to the agent. The log answers:
   which build, which renderer, the autoload census (was Music
   null? that is the fight_score.gd:38 spam), hero/touch/cinematic
   status, and the grey-figure identification (node "Dummy").
4. **START FULL GAME** loads the real street. If anything breaks
   there but SafeBoot is clean, the culprit is one of the eight
   toggles - turn them on ONE AT A TIME and watch the log.
5. The fight_score spam is guarded now (one-time error, not every
   frame), but the ROOT CAUSE - Music registering null on the
   device - can only be seen in your SafeBoot census. Paste it.

'''
assert anchor in s
s = s.replace(anchor, add + anchor, 1)
open(BASE + "XOGOT.md", "w").write(s)
print("XOGOT updated")

# --- CHANGELOG.md
s = open(BASE + "CHANGELOG.md").read()
old = "## B15 "
add = '''## B16 — build stamp, SafeBoot, and the Music-null guards (2026-11-21)
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

'''
assert old in s
s = s.replace(old, add + old, 1)
open(BASE + "CHANGELOG.md", "w").write(s)
print("CHANGELOG updated")

# --- STATE.json
d = json.load(open(BASE + "STATE.json"))
d["current_batch"] = (
    "Batch 16 (build stamp + SafeBoot + Music-null guards) CLOSE-OUT: "
    "battery running; then the vertical slice review"
)
d["completed"].append(
    "B16 staleness-proofing shipped: (1) BUILD STAMP - scripts/"
    "build_info.gd generated by scripts/gen_build_info.py from the code "
    "commit (batch + short hash + UTC), VERSION.txt at repo root; "
    "BuildStamp autoload shows it top-right from boot + window title + "
    "debug menu + SafeBoot; two-phase commit (code commit -> stamp -> "
    "stamp commit) so the phone shows the exact code hash. (2) config/"
    "name unique per batch (LEVERAGE (Bare Hands) B16) - Xogot caches "
    "by name, the old unchanged name let a stale copy masquerade. "
    "(3) SafeBoot.tscn the temporary main scene: floor/env/light + real "
    "player.tscn + FollowCamera + real touch_buttons.gd + stick_input.gd "
    "+ Dummy (kind=0); big log with COPY LOG (clipboard) incl. the "
    "AUTOLOAD CENSUS via ProjectSettings property list (get_autoload_"
    "list() does not exist in 4.7), renderer/GPU/window/orientation/"
    "safe area/FPS/draw calls/hero/touch/cinematic-ever-finished/"
    "OpeningShot.ever_finished static/Music+FightScore singleton state/"
    "sign material facts/grey-figure answer; 8 one-at-a-time toggles "
    "(cinematic/city/rain/signs test wall/npcs/post/music/fightscore); "
    "START FULL GAME -> main.tscn. (4) Music-null guards on the four "
    "sites (fight_score:38 the spam site, player _retry_step/"
    "_accept_retry, heat _process, dialogue) - one-time push_error, "
    "never spam; root cause: on the device the Music singleton "
    "registers Nil, every bare reference aborts its function every "
    "frame = the no-hero/no-controls chain; sandbox cannot reproduce "
    "device registration failure - SafeBoot census answers it on the "
    "phone. (5) Silent bug fixed: main.tscn Dummy set invalid 'mode' "
    "(real property 'kind'; worked by luck, both default 0). (6) New "
    "suites green: smoke_null_watch (600+ untouched frames vs "
    "main.tscn, grep-gated on Nil/null/SCRIPT ERROR, PASS 995 frames "
    "0 errors, hero/controls/cinematic/input/Music asserted) and "
    "safe_boot_check (Xvfb real render, 27 checks PASS, every toggle "
    "on/off clean, census alive, stamp on screen)."
)
d["next_step"] = (
    "Battery green -> two-phase commit (code, then gen_build_info.py "
    "B16 + stamp commit) -> push -> verify hash on origin -> zip "
    "download/Leverage_B16_2026-11-21.zip (import folder: bare-hands/) "
    "-> owner runs SafeBoot on the phone and pastes COPY LOG (the "
    "autoload census settles the Music-null root cause; the stamp "
    "settles staleness) -> then THE VERTICAL SLICE REVIEW per "
    "PROJECT_BIBLE.md (per-section SHIPPED/THIN/MISSING/STRETCH "
    "verdicts + gap list ranked by player impact -> docs/SLICE_REVIEW.md)"
)
json.dump(d, open(BASE + "STATE.json", "w"), indent=2, ensure_ascii=False)
print("STATE updated")
