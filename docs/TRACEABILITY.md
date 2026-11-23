# TRACEABILITY — USER OVERRIDES R1–R16

One line per override, done or not done, with the proof. Read together
with `docs/USER_OVERRIDES.md` (the source-status note applies here too:
`LEVERAGE_ZAI_MASTER_PROMPT_V3.txt` is not in the sandbox, so only the
R lines the user stated in-session on 2026-11-23 are restated below).

| R | The override, one line | Status | Proof |
|---|---|---|---|
| R1 | My WAREHOUSE is a separate small START scene | DONE | scenes/warehouse.tscn is run/main_scene; 50 own nodes, no street systems; smoke_warehouse 28/28 |
| R2 | The street is a separate scene, reached through a VISIBLE gate | DONE | the gate: 6 slats, light spill, THE STREET sign, walk-out zone -> main.tscn; arrival lands at the foundry front (482, -4.6); the shut street front is wired home; both triggers proven in smoke_warehouse |
| R3 | Move stick plus a second camera control | DONE | move stick (4 schemes) + NEW visible camera pad (scripts/cam_stick.gd) on the right in BOTH scenes, feeding the same InputBus yaw pipe the edge drag uses; pad drag swings the camera 0.00 -> -1.76 rad in the suite |
| R4 | X punch, Y heavy, A kick, B dodge — and B is the context button outside combat | DONE (was already the default; now suite-proven) | smoke_warehouse: the fight diamond IS the default scheme, X PUNCH / Y HEAVY / A KICK / B DODGE asserted; B-context law: touch_buttons.gd:71-74; smoke_controls 55 |
| R5 | Visible faces, normal bodies | ASSESSING (queued after the phone result) | face suites exist (smoke_face 31); body-proportion review pending |
| R6 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R7 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R8 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R9 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R10 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R11 | Doors: OPEN, try, LOCKED with the reason shown, break down | NOT DONE (today's doors are walk-in fade zones) | queued after the phone result |
| R12 | Missions | ASSESSING (jobs/objective layer exists; the R12 detail text is source-missing) | queued after the phone result |
| R13 | SOURCE MISSING — named in the build order, no text | UNKNOWN | awaiting the V3 file |
| R14 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R15 | SOURCE MISSING — not stated by the user | UNKNOWN | awaiting the V3 file |
| R16 | SOURCE MISSING — named in the build order, no text | UNKNOWN | awaiting the V3 file |

## Build log

- 2026-11-23: overrides recorded; old roadmap stopped. R4 verified
  already-done against the real code. R1/R2/R3 build started.
- 2026-11-23: R1/R2/R3/R4 DONE - smoke_warehouse 28/28. Two real bugs
  the new architecture exposed, both fixed: (1) Blocks adopted ANY
  player as the street main, building the whole street into the
  warehouse start room - adoption now demands the street's own root
  (Main/SafeBoot) and polls until it shows up; (2) the player's world
  fence (player.gd district clamp) dragged the warehouse hero to x=461.5
  (foundry band) and he fell off his own floor - the fence now applies
  only while the hero really is on the street scene (Blocks.hero_on_street).
  Regression at final code: smoke_warehouse 28, smoke, controls 55,
  interiors 12, map 43, phone 40, kidnap 62, progression 23, combat,
  cast, null_watch 993/0, safe_boot_check 27, live_boot 15 - ALL GREEN.
  Device verification still PHONE-ONLY.
