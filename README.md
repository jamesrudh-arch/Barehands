# Bare Hands 3D

A stylized noir, open-world crime game set in **Cinder City**.
Engine: **Godot 4.7**, 3D, **Mobile** renderer, landscape, touch-first.
The whole project is plain text (`.gd`, `.tscn`, `project.godot`) plus one CC0 asset pack, so it can be built and edited without a desktop editor.

## What's in Batch 2 (this repo, current state)

Everything from Batch 1 (night street block: wet-look asphalt, sidewalks, six buildings, amber/cyan/red neon, moonlight, fog, glow) plus:

- **The pack's mannequin character** replaces the capsule: scaled to 1.70 m to match the collision capsule, idle / walk / sprint / jump animations driven by the joystick.
- **Analog movement**: run speed scales with how far you push the stick (walk ~1.8 → run ~5.2 m/s), smooth acceleration and deceleration, and the model turns to face where it's going.
- **On-screen buttons**: JUMP (amber, bottom-right) and SPRINT (cyan, beside it) placed for thumbs in landscape.
- **Ledge climbing**, faked with code (the pack has no climb clip): jump into a climbable edge and the hero grabs it and pulls up.
- **Rooftops and crates** to climb: a crate→annex→annex→roof route up the east building, two garage roofs with a gap to sprint-jump and a ramp to walk up, a crate beside the neon kiosk.
- **A camera that behaves on slopes and rooftops**: it settles behind your heading while you travel, keeps you framed as you gain height, and pulls in with a ray so it never clips through walls.

No combat, missions, shops, or sound yet — later batches.

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

## Project layout

```
bare-hands/              Godot project root
  project.godot          Mobile renderer, landscape, 1280x720 base, canvas stretch
  assets/UAL1_Standard.glb   the animation pack's character + 43 clips (CC0)
  assets/License.txt         keep this with the model (CC0, by @Quaternius)
  scenes/main.tscn       street block, parkour props, camera, HUD (stick + buttons)
  scenes/player.tscn     the hero: capsule body + scaled mannequin instance
  scripts/input_bus.gd   shared touch-input bus (autoload "InputBus")
  scripts/joystick.gd    the touch joystick
  scripts/touch_buttons.gd  JUMP/SPRINT buttons -> InputBus
  scripts/player.gd      movement, jump/sprint, ledge grab + pull-up, animation driving
  scripts/camera_follow.gd  follow camera with wall pull-in
  tests/smoke.gd/.tscn   headless smoke test (not part of the game)
```

## Performance notes (iPhone 13 mini)

One skinned character (65 bones, no textures), three neon point lights plus a dim moon, no shadow maps, MSAA 2x, glow + fog as the only effects. That is far below what an A15 can do — expect a solid 60 fps. If a fresh install stutters for the first seconds, that is shader compilation, not the game.

## Troubleshooting

- **Portrait / sideways**: the game asks for landscape; unlock auto-rotation.
- **Very dark screen**: it is night — walk toward the neon.
- **Buttons or stick in the wrong spot after rotating**: they are anchored to the screen corners; re-lock landscape.
- **Grab feels unreliable**: you must be *moving into* the wall while airborne, with the ledge between 0.55 and 2.4 m above your feet. Run at it from about a metre away and jump.
- **Import fails in Xogot/Godot**: make sure you picked `bare-hands/project.godot`, not the repo root.

## Sync this repo

The remote is <https://github.com/jamesrudh-arch/Barehands> (branch `main`). From a machine with push access:

```
git push origin main
```

To pull the next batch onto the phone: re-download the ZIP and replace the `bare-hands/` folder, then reopen the project (it re-imports changed files automatically).

## Verified / not verified

- Verified headless with Godot 4.7.2 (this sandbox): project imports with no errors; the smoke test (`bare-hands/tests/`) loads the main scene, checks the mannequin stands 1.70 m in world space, full stick reaches 5.2 m/s (7.0 with sprint), half push paces at ~3.0 m/s with the Walk clip, the model turns to face travel, a jump gains ~1.38 m and plays the jump clips, a jump into the 3.4 m annex triggers the code-faked climb and ends standing on top, and the camera pulls its boom from ~6.7 m to ~0.8 m when a building wall is behind the hero.
- Not verified on a real phone (no device here): touch feel of the stick and buttons, actual framerate and thermals on the iPhone 13 mini, how the mannequin's clips read visually (walk cadence vs speed was tuned by numbers, not by eye), and Xogot's import flow on iOS. Tell me what you see and Batch 3 will tune it.
