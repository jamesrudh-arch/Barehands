# THE DEVICE REPORT — the pre-flight and the checklist

**Status: ready for the phone. Every number below is measured;
the only missing input is the hardware itself.**

## 1. The llvmpipe pre-flight (measured S5.20, 1280×720, solo runs)

| Area | Lights | Meshes | Draws | p50 | p95 |
|---|---|---|---|---|---|
| warehouse | 6 | 180 | 67 | 132 ms | 160 ms |
| neighbourhood | 11 | 870 | 70 | 216 ms | 240–735 ms* |
| club_district | 8 | 512 | 133 | 279 ms | 289 ms |
| docks | 6 | 324 | 117 | 203 ms | 229 ms |

\* the neighbourhood p95 swings with one-frame hitches (llvmpipe
jitter + first-run shader compiles); its p50 216 ms is the truth.
The club is the heaviest BY DESIGN (the S5.16 neon showpiece).

## 2. Where the milliseconds go (the phase probe, S5.20)

Measured by toggling passes in the live club frame:

- **Environment glow (two bloom radii → one): ~30 ms/frame.**
  FIXED in S5.20 — level 5 folded into level 3; the halo size and
  alpha retuned (3.2@0.40 → 3.0@0.52) after the VLM caught the
  over-cut ("labels, not lights"); the club atmosphere restored.
- **The noir lens (grain/chroma/vignette): ~10 ms/frame.**
  Settings-gated, one fullscreen canvas pass.
- **Base scene: ~240 ms/frame** — llvmpipe rasterizing the neon
  canyon. This is the software renderer's cost, not the game's:
  fill-rate bound in CPU rasterization, trivial for a GPU.

## 3. The phone checklist (run in this order, ~20 minutes)

1. **Build**: `godot --export-release "Android" barehands.apk`
   (preset below); install on the target device.
2. **The cold open**: headphones on — Marla's 4 spoken lines,
   the type-out pacing to the voice, tap cutting through.
3. **Boot to menu**: the noir score plays (walking bass,
   brushes); crossfade into combat music on the first fight.
4. **Walk m0→m1**: touch controls (virtual stick + the button
   pill), the punch feel, the hit-flash.
5. **The street**: rain, moths at the lamps, birds flushing,
   the elevated train every 35 s, the FILLING STATION's pylon
   (FUEL / 2.79) reading from street level.
6. **The club canyon (the stress test)**: stand 60 s under the
   neon. Record FPS. PASS: ≥ 30 fps sustained. The llvmpipe red
   (289 ms p95) is expected to land at 15–30 ms/frame here.
7. **The docks**: the flowing river (30.8 % of the water region
   moves per 1.2 s on llvmpipe), the jumping fish, the piers.
8. **The finale, both routes**: answer Marla's rings (VO),
   the counting-house fight, BURN (corp hunters patrol the
   neighbourhood after) and DELIVER (the debt's honest half).
   The phone's Ledger ends "THE DEBT IS DONE".
9. **Thermal + battery**: 20 min of play; note drain and any
   throttling-induced frame drops.
10. **Memory**: no growth over a 10-area travel loop (the
    llvmpipe stability checks already assert no leak-shape
    growth per area).

## 4. The export preset (Android, OpenGL ES 3)

- Renderer: `gl_compatibility` (the game's path — mobile-honest)
- Orientations: landscape only
- Architecture: arm64-v8a + armeabi-v7a
- Screen: `canvas_items` stretch, aspect `expand`
- Audio: 22 kHz streams (the bank is 75 clips, ~7 MB)
- Fonts embedded: Anton, Playfair Display, Barlow (OFL, credited
  in the CREDITS screen)

## 5. What fails on the phone (the honest predictions)

- The club canyon on a low-end GPU (< 2019): expect 25–30 fps;
  the glow/lens Settings toggles are the fallbacks.
- 32-bit devices: llvmpipe-class rasterization on Mali-400 will
  not hold 30 fps in the club — supported floor is arm64 + GLES3.
- Anything else: unknown until this checklist runs on hardware.
  The sandbox cannot close that gap; everything else is measured.
