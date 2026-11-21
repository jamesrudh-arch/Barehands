# XOGOT.md — running Bare Hands 3D on Xogot (iPhone)

Xogot is the reference target: Godot 4.7, iPhone, **Mobile renderer
(Metal)**, landscape, touch-first. This file is the exact phone
procedure for the owner. The agent verifies the machine half in the
sandbox (a real opengl3 render under Xvfb/llvmpipe — the
`render_check` suite); the phone-only half (feel, Metal glow) is
always yours.

## B15 — the six visual bugs, what shipped

| Bug | Fix | Machine-verified? |
| --- | --- | --- |
| 1. Signs/doors flat white + orange halo | ACES tonemap, glow 0.5 / bloom 0.05 / HDR threshold 1.45 (was 1.05), windows 0.85 emission, neon capped at 1.8, sign text gets a dark outline | YES (render_check: white area 1.1%, orange 0.01%, caps asserted) |
| 2. Large pale square blocks | rain + splash particle materials now set BILLBOARD_PARTICLES (quads face the camera, never show broadside); ground glow + oil stains are radial gradient textures, not flat alpha quads | YES (0 flat pale 80px blocks; billboard asserted) |
| 3. Blurry grey figure | the boot-area training dummy was literally grey (0.55,0.55,0.6); re-tinted worn tan | YES (tint + on-screen saturation asserted) |
| 4. Flat teal strip, no hero | the opening cinematic hid the HUD and froze the camera until it finished; it now runs PROCESS_MODE_ALWAYS, captures its landing pose deferred, and a 12 s watchdog force-finishes | YES (hero framed x 0.49 at 6.9 m; input unlocked; HUD visible) |
| 5. Touch controls invisible | buttons exist but ignored the notch/home-bar safe area; `_apply_layout` now clamps every button inside it. Orientation locked to landscape (project setting `handheld/orientation=0`) | YES (9 buttons, all on-screen, all in safe area) |
| 6. Rain streaks too thick | streak quad 0.012×0.34 → 0.008×0.30, scale 0.6-1.1, alpha 0.26 | YES (mesh asserted) |

**XOGOT SAFE is the baked default on phones**: the `Visual` autoload
detects mobile and boots with glow off, emission ×0.6, splashes off,
shadows off (project rule: the phone starts safe; the desktop keeps
the full NIGHT look).

## Your phone procedure (15 minutes)

1. **Pull** the latest `main` (batch B15), import the project in
   Xogot, delete any previous install's data first (Xogot: remove the
   app's Godot user data or reinstall) so the first-run picker shows.
2. **Boot.** You should see: the first-run picker (4 movement cards)
   → the opening flight lands **within ~7 s** → the hero framed
   centre, street alive, rain thin. If the opening ever stalls, it
   now force-finishes by itself at 12 s.
3. **First 60 seconds, check the six:** signs read as COLOUR with
   readable text (not white blocks); no orange halo smothering shop
   fronts; no pale squares floating in the rain or on the ground; a
   tan training dummy near spawn (not a grey man); hero visible from
   boot; touch buttons clear of the notch and home bar; rain reads as
   thin streaks.
4. **Open the VISUAL DEBUG panel**: tap the DBG toggle (top-left) →
   **VISUAL DEBUG**. The overlay at the top shows renderer, window,
   safe area, orientation, FPS, draw calls, and `touch loaded: YES
   (N buttons)`. If that line ever says NO, screenshot it and send it.
5. **Isolate anything still wrong ON the phone**: flip one toggle at
   a time (Glow, Emission x, Rain, Splash, Decals, Outlines, Shadows,
   NPCs). Each applies instantly. Note which toggle makes the bug
   vanish — that name is the diagnosis.
6. **COPY SETTINGS** → select all → paste the block back to the
   agent. **SCREENSHOT PNG** saves a frame into the app's user folder
   (path is printed and appended to the settings block) — share it
   via the Files app.
7. **Try NIGHT (desktop)** for a moment, then **XOGOT SAFE** back.
   If NIGHT looks good on your iPhone now, tell the agent — the
   baked default can flip.
8. **Orientation**: the game locks landscape. If Xogot starts it in
   portrait anyway, rotate once; if it refuses to rotate, that is an
   Xogot container setting, not the project (the project requests
   landscape explicitly).

## What is verified where

- **Machine (sandbox, opengl3/llvmpipe)**: `render_check` — 26
  checks, RENDER PASS; re-run any time:
  `DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --rendering-driver opengl3 res://tests/render_check.tscn`
- **Phone (only you can say)**: Metal glow behaviour, 30+ FPS feel,
  haptics, safe-area placement on the notch, the aesthetic of the
  dimmer night. Send the COPY SETTINGS block + a screenshot and the
  agent will tune against it.
