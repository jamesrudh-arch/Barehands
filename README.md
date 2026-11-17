# Bare Hands 3D

A stylized noir, open-world crime game set in **Cinder City**.
Engine: **Godot 4.7**, 3D, **Mobile** renderer, landscape, touch-first.
The whole project is plain text (`.gd`, `.tscn`, `project.godot`) plus one CC0 asset pack, so it can be built and edited without a desktop editor.

## What's in the game (Batch 3, current state)

Everything from Batches 1-2 (night street block with neon, the pack's mannequin hero with analog run/sprint/jump, code-faked ledge climbing, parkour roofs and crates, wall-safe camera, one-time "Jump while moving to climb" hint, forgiving ledge grab) plus **Batch 3, combat feel**:

- **PUNCH button** (red, bottom-right): a two-hit jab→cross combo with input buffering — press PUNCH again during the jab and the cross chains automatically. Punches soft-lock to the nearest enemy and lunge; at point-blank the lunge is skipped.
- **A training dummy** (standing beside the street crate, north-west of spawn): flinches (`Hit_Chest`), staggers back, and falls (`Death01`) when its hp runs out, then resets. The jab hits the chest, the cross the head.
- **Impact layers, in order**: hit-stop first (time briefly slows to 5%), then the enemy's white flash plus a small CPU particle spark, then a very subtle camera shake (a few centimetres). No sound yet — `Fx.hit_landed(kind, pos)` is the hook Batch 4 connects to.
- **Style meter** (top-right): mixing punches, dodges, parries, counters, slams and takedowns raises the rank D→C→B→A→S; repeating the same move earns 35%, then 12%. The rank multiplies the cash points each move banks (×1.0 up to ×3.0). Cash is a stored number only.
- **DODGE/PARRY button** (white, left of PUNCH): a quick evade in the stick direction (or a back-step with no stick), with invincibility frames. Press it **just before an enemy's swing lands** and it becomes a parry: a 0.7 s slow-motion window opens, the attacker staggers, and your next punch is a counter-hit that knocks them down.
- **A thug** (west end of the street) that shambles over and attacks on a clear rhythm: a pulsing red telegraph for 0.6 s, then the swing. Learn the timing on him.
- **Environmental takedown**: land a cross or a counter while a crate or wall is right behind the enemy and they get slammed into it — bigger hit-stop, bigger shake, top style points.
- Player getting hit (no parry) = knockback plus a short `Hit_Chest` stagger. No health bar for the hero yet.

No shops, missions, driving, guns or sound yet — later batches.

### The Universal Animation Library pack

`bare-hands/assets/` holds `UAL1_Standard.glb` (the Godot-ready, root-motion-disabled variant), the pack's `License.txt` (**CC0 1.0 / public domain, models by @Quaternius**) and its `README.txt`. The `_RM` (root-motion) variant and the Unity `.fbx` files stay in the original zip at the repo root; this game moves the character in code.

The pack contains one rigged mannequin (65 bones, 2 materials, no textures — light) and **43 clips**. Locomotion: `Idle`, `Walk`, `Walk_Formal`, `Jog_Fwd`, `Sprint`, plus crouch and swim loops. Jumps: `Jump_Start`, `Jump` (air loop), `Jump_Land`. Action: `Roll`, `Interact`, `Push`, `PickUp_Table`, `Fixing_Kneeling`, `Dance`, `Sitting_*` (3), `Driving`, `Hit_Chest`, `Hit_Head`, `Death01`. Weapons/magic (for later batches): `Pistol_*` (5), `Sword_*` (2), `Spell_Simple_*` (4), `Punch_Jab`, `Punch_Cross`, `A_TPose`.

**There is no climb, ledge-hang or mantle clip in the pack** — the grab and pull-up in this batch are faked with code (the hero plays the air pose while being pulled up, then lands).

## Run it on your phone

### iPhone 13 mini (the target device)

1. Install **Xogot — Godot for iPad & iPhone** from the App Store (free tier is enough; it is a native Godot editor showcased by godotengine.org). Xogot cannot run native-code plugins or .NET — this project uses neither, so that's fine.
2. In Safari or the GitHub app, open <https://github.com/jamesrudh-arch/Barehands> → **Code → Download ZIP**. Extract it with the Files app (tap the zip). You should end up with a folder containing `bare-hands/project.godot`.
3. Open Xogot → import/open project → pick `bare-hands/project.godot`. The first import compiles the shaders and the character (about half a minute on an A15).
4. Press **Play**. The game runs fullscreen in landscape.

If you ever have a Mac, the official route is exporting an IPA with Xcode (see Godot docs, "Exporting for iOS") — but you don't need it just to test.

### Android (unchanged from Batch 1)

Install the **Godot Engine** editor app (4.7.x) from Play Store, get the repo ZIP the same way, import `bare-hands/project.godot`, press Play.

## How to test each move on the phone

Do these in order; each takes a few seconds.

1. **Idle** — touch nothing. The mannequin breathes and shifts weight (`Idle` clip, crossfaded in 0.25 s).
2. **Walk vs run by stick distance** — push the left stick a little: a relaxed walk (~1.8 m/s). Push it all the way out: a run (~5.2 m/s) with the sprint animation. The model always turns to face the direction it moves; speed builds up and bleeds off smoothly.
3. **SPRINT** — hold the cyan SPRINT button with a full stick: ~7 m/s, arms pumping. Release the button to drop back to run.
4. **JUMP** — tap the amber JUMP button: crouch-launch (`Jump_Start`), airborne tuck (`Jump`), landing recovery (`Jump_Land`). Jump height is ~1.2 m — enough to hop straight onto the 1.1 m street crates.
5. **Ledge grab + pull-up** — stand about a body-length from the **crate at the east sidewalk** (x≈7, z≈−8), face it and jump *into* the wall while pushing the stick forward. Near the top of the jump the hero grabs the edge (short freeze, ~0.1 s), then pulls up onto it over half a second. If you jump too early you just bounce off — try again slightly closer.
6. **East rooftop route** — from that first crate: jump-grab onto the 3.4 m annex, from there onto the 5.7 m annex, then jump-grab the big building's roof edge at 8 m. Total: ground → 1.2 → 3.4 → 5.7 → 8.0 m. You can also simply drop off any roof — fall damage isn't in yet.
7. **West garage route (slope + gap)** — walk up the wooden **ramp** west of the garages (x≈−16, z≈7): the hero walks the slope and the camera keeps framing without jerking. On the first garage roof, hold SPRINT and jump the **2.5 m gap** to the second garage. Hop the AC unit on top. The camera never clips into the buildings behind you — watch it pull in when you stand with a wall at your back.
8. **Kiosk route** — at the east kiosk with the red sign (x≈14), jump-grab from the crate onto its 3.5 m roof.
9. **Camera vs walls** — run at any building and stop just short: the camera shortens its boom instead of sinking into the wall. Climb any roof and walk near the edge: you stay framed, the camera follows your height.

## How to test each combat move on the phone

The combat buttons sit in a 2×2 thumb cluster, bottom-right: **PUNCH** (red, corner), **DODGE** (white, left of it), **JUMP** (above punch), **SPRINT** (above dodge). The training dummy stands beside the street crate just north-west of spawn.

1. **Jab** — walk to the dummy and tap PUNCH: a quick `Punch_Jab`, a 0.07 s hit-stop, a white flash on the dummy, a small amber spark, a tiny camera nudge. The dummy staggers back and plays `Hit_Chest`. Watch the style meter (top-right) tick up.
2. **Jab → cross combo with buffering** — tap PUNCH, then tap PUNCH again *while the jab is still swinging*: the cross chains automatically (`Punch_Cross`, hits the head, `Hit_Head`, heavier knockback and hit-stop). You don't need frame-perfect timing — the press is buffered for 0.35 s.
3. **Style meter & repetition** — land the jab→cross, then dodge an attack, then jab again: varied chains climb D→C→B→A→S and the cash multiplier rises (×1.0→×3.0). Now jab the dummy five times in a row: the meter barely moves — repetition earns a fraction. Leave it alone and the meter decays.
4. **Parry (the big one)** — walk west to the **thug** near the ramp. Let him approach; he pulses red for ~0.6 s (telegraph), then swings. Tap **DODGE just before the swing lands** — the world drops into slow motion for 0.7 s, the thug staggers with a cyan flash. Immediately tap PUNCH: a counter-hit that knocks him flat (`Death01`). If you dodge too early he still misses you (invincibility frames) but there's no slow motion — that's the difference between a dodge and a parry.
5. **Getting hit** — stand still and let the swing land: the hero takes `Hit_Chest`, a knockback and a short stagger. Nothing permanent yet (no health system).
6. **Environmental slam** — the dummy spawns beside the street crate. Stand east of it so the crate is behind it, then land a **cross** (PUNCH, PUNCH): the dummy is slammed into the crate — longer hit-stop, orange spark, bigger shake, +35 style. Works against any wall too: corner the thug against a building and cross him. Jabs never slam — only heavy hits (cross or counter).
7. **Counter into slam** — parry the thug next to a wall or crate, then punch: the counter is also heavy, so a counter with an obstacle behind him is an instant takedown.

## Project layout

```
bare-hands/              Godot project root
  project.godot          Mobile renderer, landscape, autoloads (InputBus, Fx), punch/dodge keys
  assets/UAL1_Standard.glb   the animation pack's character + 43 clips (CC0)
  assets/License.txt         keep this with the model (CC0, by @Quaternius)
  scenes/main.tscn       street block, parkour props, dummy + thug, camera, HUD
  scenes/player.tscn     the hero: capsule body + scaled, 180-degree-fixed mannequin
  scenes/enemy.tscn      shared enemy rig (mode 0 dummy / mode 1 thug)
  scripts/input_bus.gd   shared touch-input bus (autoload "InputBus")
  scripts/fx.gd          hit-stop / slow-mo / particles / shake + sound hook (autoload "Fx")
  scripts/joystick.gd    the touch joystick
  scripts/touch_buttons.gd  JUMP/SPRINT/PUNCH/DODGE buttons + hint label
  scripts/style_meter.gd style rank, repetition penalty, cash points
  scripts/player.gd      movement, ledge grab, punch combo, dodge/parry, counters, slams
  scripts/enemy.gd       dummy reactions, thug AI with telegraph attack, parry resolution
  scripts/camera_follow.gd  follow camera with wall pull-in + impact shake
  tests/smoke.tscn       headless movement smoke test (not part of the game)
  tests/smoke_combat.tscn   headless combat smoke test (not part of the game)
```

## Performance notes (iPhone 13 mini)

Three skinned characters (the same 65-bone, textureless mannequin instanced three times), three neon point lights plus a dim moon, no shadow maps, MSAA 2x, glow + fog, and CPU particles only on hits. That is far below what an A15 can do — expect a solid 60 fps. If a fresh install stutters for the first seconds, that is shader compilation, not the game.

## Troubleshooting

- **Portrait / sideways**: the game asks for landscape; unlock auto-rotation.
- **Very dark screen**: it is night — walk toward the neon.
- **Buttons or stick in the wrong spot after rotating**: they are anchored to the screen corners; re-lock landscape.
- **Grab feels unreliable**: you must be *moving into* the wall while airborne, with the ledge between 0.45 and 2.6 m above your feet. Run at it from about a metre away and jump. A one-time hint appears the first time you stand near a climbable edge.
- **Import fails in Xogot/Godot**: make sure you picked `bare-hands/project.godot`, not the repo root.

## Sync this repo

The remote is <https://github.com/jamesrudh-arch/Barehands> (branch `main`). From a machine with push access:

```
git push origin main
```

To pull the next batch onto the phone: re-download the ZIP and replace the `bare-hands/` folder, then reopen the project (it re-imports changed files automatically).

## Verified / not verified

- Verified headless with Godot 4.7.2 (this sandbox): the project imports with no errors and both smoke suites pass. Movement (`tests/smoke.tscn`): mannequin 1.70 m, **faces its travel direction (hand bones checked against the movement vector, north and south, plus the climb pose facing the wall)**, analog speeds, sprint, jump clips, ledge climb onto the 3.4 m annex, the one-time climb hint near a grabbable edge, camera follow and wall pull-in. Combat (`tests/smoke_combat.tscn`): jab→cross lands with buffering (dummy 5→2 hp) and knockback, punch clips play, per-enemy materials don't cross-flash, repeating a move earns less, a well-timed dodge triggers slow motion and the parry counter knocks the thug down, a cross with the crate behind the dummy slams it (takedown), and `Engine.time_scale` always returns to 1.0.
- Not verified on a real phone (no device here): touch feel of the stick and the four buttons, hit-stop/slow-mo/shake actually *feeling* right (timings were tuned headless, by numbers), framerate and thermals on the iPhone 13 mini, enemy telegraph readability, and Xogot's import flow on iOS. Tell me what feels off and the next batch tunes it.
