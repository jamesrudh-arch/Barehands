#!/usr/bin/env python3
"""B15 docs: TESTING.md section, CHANGELOG entry, STATE.json update."""
import json

BASE = "/home/z/my-project/"

# --- TESTING.md
s = open(BASE + "TESTING.md").read()
anchor = "- **B10 battery regressions**"
add = '''- **B15 the Xogot visual pass + render truth**: render_check (26
  checks, RUNS WITH A REAL RENDERER - opengl3 under Xvfb/llvmpipe in
  the sandbox, `--rendering-driver opengl3`; under --headless it
  prints RENDER SKIP and quits 0 so it can sit in the battery). It
  boots main.tscn, skips the opening, waits for the rain to settle,
  saves the frame to /tmp/render_boot.png and judges the six Xogot
  bugs: baked safe environment (ACES, hdr 1.45, glow 0.5/0.05,
  windows 0.85, neon capped 1.8), pure-white area < 1.5%, orange
  bloom < 10%, ZERO flat pale 80 px blocks (the pale-square
  detector: bright + washed + near-zero variance), rain/splash
  billboarded thin streaks, the dummy worn tan AND its on-screen
  region lit (mean saturation 0.772, not a grey slab), touch
  controls: 9 ActionButtons all on-screen and inside the safe area,
  the hero framed (nx 0.49, 6.9 m), input unlocked + HUD visible
  after the opening, and the frame-level life checks (neon lives >
  0.5% colorful, not one grey slab, mean luminance 0.041 in the
  0.04-0.6 band). Suite lessons: count ActionButtons as children of
  the hud layer (they join no group); unproject_position returns
  PIXELS (normalize by the visible rect); Color has no get_hsv() in
  Godot 4 (use .s/.v); the enum is BILLBOARD_PARTICLES (with an S);
  local callable variables need .call(); local callable variables
  need Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, not a
  RenderingServer enum.
- **B15 the six fixes**: (1) environment ACES + glow 0.5/0.05 + HDR
  1.45 (was Filmic 0.7/0.1/1.05 - every window at emission 1.4 sat
  above the 1.05 threshold and bloomed orange), windows 0.85 with
  base_energy metadata in group emissive_window, neon capped 1.8 and
  scaled by the Visual profile, sign text outlined; (2) rain +
  splash materials now set BILLBOARD_PARTICLES (un-billboarded
  custom-material quads can show broadside on Mobile = the pale
  squares), ground glow pools + oil stains are radial
  GradientTexture2D, group decal; (3) the boot-area Dummy was
  literally Color(0.55,0.55,0.6) - a grey man - now worn tan
  (0.62,0.50,0.36); (4) the opening hid the HUD and froze the camera
  until _finish - now PROCESS_MODE_ALWAYS, _end captured deferred
  after the camera's own _ready, 12 s watchdog force-finish; (5)
  touch buttons clamp inside DisplayServer.get_display_safe_area()
  (canvas coords via the inverse final transform); (6) rain quad
  0.008x0.30, scale 0.6-1.1, alpha 0.26.
- **B15 the VISUAL DEBUG panel** (debug menu -> VISUAL DEBUG, layer
  22, everything live through the Visual autoload): glow on/off +
  intensity + bloom + HDR threshold sliders, tonemap cycle, sign +
  window emission multiplier, shadows, rain on/off + streak width,
  ground splash, decals, enemy outlines, NPCs + crowd, camera height
  + distance, XOGOT SAFE preset (glow off, emission x0.6, splash
  off, shadows off - the baked boot default on mobile via
  OS.has_feature), NIGHT preset, COPY SETTINGS (selectable text of
  every value incl. renderer/adapter/safe area/quality), SCREENSHOT
  PNG (user:// + printed absolute path), and a live overlay
  (renderer, window, safe area, orientation, FPS, draw calls, touch
  loaded YES/NO). Phone procedure: XOGOT.md.

'''
assert anchor in s
s = s.replace(anchor, add + anchor, 1)
open(BASE + "TESTING.md", "w").write(s)
print("TESTING updated")

# --- CHANGELOG.md
s = open(BASE + "CHANGELOG.md").read()
old = "## B14 "
add = '''## B15 — the Xogot visual pass: six bugs, a debug panel, render truth (2026-11-21)
- The game runs on Xogot (Godot 4.7 / iPhone / Mobile-Metal) and the
  phone showed six visual bugs the number-only fixes missed. All six
  fixed at the source and MACHINE-PROVEN by render_check - a real
  opengl3 render under Xvfb/llvmpipe that judges the frame (26
  checks, RENDER PASS): blown-white signs + orange halo (bloom
  threshold was 1.05 with windows at 1.4 emission - now ACES, glow
  0.5/0.05, HDR 1.45, windows 0.85, neon capped 1.8), pale square
  blocks (particle quads now BILLBOARD_PARTICLES; ground quads are
  radial gradients), the grey figure (the spawn dummy was literally
  grey - worn tan now), the flat-teal no-hero spawn (the opening
  hid the HUD and froze the camera - watchdog + deferred landing +
  ALWAYS processing), touch controls (safe-area clamping; landscape
  lock confirmed), thick rain (0.008 m streaks).
- VISUAL DEBUG panel in the debug menu: live glow/tonemap/emission/
  rain/decals/shadows/NPC/camera controls, XOGOT SAFE preset (the
  baked mobile default), COPY SETTINGS (paste the values back to the
  agent), SCREENSHOT PNG, and an overlay with renderer, resolution,
  orientation, FPS, draw calls and touch-loaded status. Phone
  procedure in XOGOT.md.
- Battery: 30 suites (29 headless green + render_check green under
  Xvfb), 0 script errors. Docs: XOGOT.md (new), TESTING, CHANGELOG,
  STATE.

'''
assert old in s
s = s.replace(old, add + old, 1)
open(BASE + "CHANGELOG.md", "w").write(s)
print("CHANGELOG updated")

# --- STATE.json
d = json.load(open(BASE + "STATE.json"))
d["current_batch"] = (
    "Batch 15 (Xogot visual pass: six bugs + VISUAL DEBUG panel + "
    "render_check render-truth suite) CLOSE-OUT: battery running; "
    "next: vertical slice review per bible"
)
d["completed"].append(
    "B15 Xogot visual pass shipped: (1) SIX BUGS FIXED at the source - "
    "env ACES/glow 0.5/bloom 0.05/hdr 1.45 + windows 0.85 (group "
    "emissive_window + base_energy meta) + neon cap 1.8 x Visual "
    "profile + sign outline; rain/splash BILLBOARD_PARTICLES + ground "
    "glow/oil radial GradientTexture2D (group decal); Dummy worn tan "
    "(was Color(0.55,0.55,0.6) - the literal grey man); OpeningShot "
    "PROCESS_MODE_ALWAYS + deferred _end capture + 12s watchdog "
    "(it hid the HUD and froze the camera until _finish); touch "
    "buttons clamped into DisplayServer safe area (canvas coords via "
    "inverse final transform); rain quad 0.008x0.30 scale 0.6-1.1 "
    "alpha 0.26. (2) Visual autoload (NIGHT / XOGOT SAFE profiles, "
    "mobile boots SAFE: glow off, emission x0.6, splash off, shadows "
    "off) wired into neon/windows/rain/enemy-edges/decals/lights/"
    "camera. (3) visual_debug.gd panel on the debug menu: live "
    "sliders/toggles for every system, XOGOT SAFE + NIGHT presets, "
    "COPY SETTINGS selectable dump, SCREENSHOT PNG (user:// + printed "
    "abs path), overlay with renderer/adapter/window/safe area/"
    "orientation/FPS/draw calls/touch-loaded. (4) render_check suite: "
    "REAL renderer (opengl3 via Xvfb + LIBGL_ALWAYS_SOFTWARE=1 "
    "llvmpipe; RENDER SKIP under headless), 26 checks RENDER PASS "
    "incl. the pale-square 80px-block detector, dummy-region "
    "saturation, ActionButton children count of the hud layer, safe "
    "area enclosure, hero framing, opening unlock. Gotchas learned: "
    "BILLBOARD_PARTICLES (plural), Color .s/.v not get_hsv(), "
    "unproject returns pixels, local Callables need .call(), "
    "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, Label3D+Glow needs "
    "the threshold above window energy or everything blooms orange. "
    "(5) XOGOT.md: the owner's 15-minute phone procedure + the "
    "verified/phone-only split table."
)
d["next_step"] = (
    "Battery green -> commit + push + zip bare-hands-batch15.zip, "
    "then back to the queued batch order: THE VERTICAL SLICE REVIEW - "
    "walk PROJECT_BIBLE.md top to bottom against the shipped game, "
    "write docs/SLICE_REVIEW.md with per-section verdicts (SHIPPED / "
    "THIN / MISSING / STRETCH-PENDING) and an honest gap list ranked "
    "by player impact; ALSO fold in the owner's Xogot feedback when "
    "the COPY SETTINGS block arrives (phone values may want baking)."
)
json.dump(d, open(BASE + "STATE.json", "w"), indent=2, ensure_ascii=False)
print("STATE updated")
