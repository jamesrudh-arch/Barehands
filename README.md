# Bare Hands 3D

A stylized noir, open-world crime game set in **Cinder City**.
Engine: **Godot 4.7**, 3D, **Mobile** renderer, landscape, touch-first.
The whole project is plain text (`.gd`, `.tscn`, `project.godot`) so it can be built and edited without ever opening a desktop editor.

## What's in Batch 1 (this repo, current state)

- One night street block: dark wet-look asphalt, sidewalks, crosswalk, six buildings, amber + cyan + red neon signs, dim moonlight, glow and light fog.
- A placeholder hero (capsule with a lit nose) that walks with an on-screen touch joystick.
- A smooth third-person follow camera.
- No combat, missions, shops, or sound yet — that's later batches.

Project layout:

```
bare-hands/            Godot project root
  project.godot        Mobile renderer, landscape, 1280x720 base, canvas stretch
  scenes/main.tscn     the street block, lights, camera, UI
  scenes/player.tscn   the hero capsule
  scripts/input_bus.gd shared touch-input bus (autoload "InputBus")
  scripts/joystick.gd  the touch joystick
  scripts/player.gd    hero movement
  scripts/camera_follow.gd  follow camera
  tests/smoke.gd/.tscn headless smoke test (not part of the game)
```

## Run it on your Android phone (no PC needed)

### 1. Install the Godot editor app (one time)

- Play Store: install **"Godot Engine"** by Godot Engine Foundation (package `org.godotengine.editor.v4`), version 4.7.x.
- Or download the Android editor APK from <https://godotengine.org/download/android/> and install it (allow "install unknown apps" for your browser when asked).
- Your phone needs Vulkan support (almost all phones from ~2017+) or at least OpenGL ES 3.0.
- Note: the Android editor works but is still experimental; a Bluetooth keyboard/mouse makes editing nicer, but you do **not** need them just to run the game.

### 2. Get this project onto the phone

- From GitHub: open <https://github.com/jamesrudh-arch/Barehands> in the browser or GitHub app → **Code → Download ZIP** (the repo is public, no login needed), then extract the ZIP with your file manager (e.g. Files by Google or ZArchiver).
- Or with Termux: `git clone https://github.com/jamesrudh-arch/Barehands.git`.
- You should end up with a folder that contains `bare-hands/project.godot`. A place like `Download/bare-hands` is fine. If the editor's file picker refuses a folder, copy the `bare-hands` folder into `Android/data/org.godotengine.editor.v4/files/` with a file manager and pick it from there.

### 3. Import and run

1. Open the Godot app. First launch shows the Project Manager.
2. Tap **Import** and use the file picker to select `bare-hands/project.godot` (inside the extracted folder), then **Import & Edit**.
3. The editor opens and imports the project once (it creates a `.godot/` folder; that's normal, it is not committed to git).
4. Tap the **▶ Play** button (top-right area). The game runs fullscreen in landscape.
5. Touch and drag the round pad in the bottom-left corner to walk around. Release to stop.
6. Quit with the back gesture, or stop it from the editor.

### What you should see

- A dark night street with a crosswalk and center lane dashes.
- Amber neon on the tall north building, cyan strip on the south building, red sign on the east kiosk, plus dim lit windows and a faint moon.
- The asphalt has a wet sheen (clearcoat) that catches the neon.
- The capsule hero walks, turns to face its direction, and the camera follows smoothly.
- A translucent joystick circle in the bottom-left.

### Troubleshooting

- **Portrait / sideways**: unlock auto-rotation in your phone's quick settings — the game asks for landscape.
- **Very dark screen**: it is night — walk toward the neon lights. The hero's nose glows amber so you can always spot it.
- **Import fails**: make sure you picked `bare-hands/project.godot` (not the repo root's README) and that the ZIP extracted fully.
- **Slow on an old phone**: in `bare-hands/scenes/main.tscn` you can set `glow_enabled = false` and `fog_enabled = false` in the `env_night` sub-resource with any text editor; the game still works.

## Sync this repo

The remote is <https://github.com/jamesrudh-arch/Barehands> (branch `main`). From a machine with push access:

```
git push origin main
```

To pull the next batch onto the phone: `git pull` in Termux, or re-download the ZIP and replace the `bare-hands/` folder, then reopen the project in the Godot app (it re-imports changed files automatically).

## iOS?

Not in this batch. There is no Godot editor for iOS; testing on iPhone needs a Mac with Xcode and an Apple Developer account. A build pipeline (GitHub Actions producing an APK, later maybe iOS) is a good candidate for a future batch.

## Verified / not verified

- Verified headless with Godot 4.7.2 (this sandbox): project import, all scripts compile, the smoke test (`bare-hands/tests/`) runs the scene, walks the hero ~6.7 m with stick input, camera trails ≤ 1.1 m while walking and settles to ~0.1 m once the hero stops.
- Not verified: how it actually looks and performs on your phone's screen (rendering, touch feel, framerate). Tell me what you see and Batch 2 will tune it.
