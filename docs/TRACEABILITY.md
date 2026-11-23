# TRACEABILITY — USER OVERRIDES R1–R16

One line per override, done or not done, with the proof. Read together
with `docs/USER_OVERRIDES.md` (the source-status note applies here too:
`LEVERAGE_ZAI_MASTER_PROMPT_V3.txt` is not in the sandbox, so only the
R lines the user stated in-session on 2026-11-23 are restated below).

| R | The override, one line | Status | Proof |
|---|---|---|---|
| R1 | My WAREHOUSE is a separate small START scene | NOT DONE (building now) | — |
| R2 | The street is a separate scene, reached through a VISIBLE gate | NOT DONE (building now) | — |
| R3 | Move stick plus a second camera control | PARTIAL → building the missing half: the move stick exists (4 schemes), right-edge drag turns the camera, a visible second camera control does not exist | `stick_input.gd` schemes; `camera_follow.gd:149` drag |
| R4 | X punch, Y heavy, A kick, B dodge — and B is the context button outside combat | DONE BEFORE OVERRIDES (default scheme "fight" = the console diamond; B is DODGE in combat, wears the context verb outside; B is never kick) | `touch_buttons.gd:128` (default), `:71-74` (the diamond + B rule); smoke_controls |
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
