# Bare Hands 3D

A stylized noir, open-world crime game set in **Cinder City**.
Engine: **Godot 4.7**, 3D, **Mobile** renderer, landscape, touch-first.
The whole project is plain text (`.gd`, `.tscn`, `project.godot`) plus CC0 asset packs, so it can be built and edited without a desktop editor.

**SERIES 1: THE LOOK AND FEEL** — phase reports below (1 Stability · 2 Hero & Camera · 3 Wet Neon Night · 4 Punches That Hit).

## What's in the game (through Series 1 Phase 2)

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

## SERIES 1 · Phase 1 — Stability

**What was built**

- **Both load warnings fixed.** The unused `hit_landed` signal: the emits lived in player/enemy while the signal belonged to the Fx autoload, so its own class never used it — every impact now goes through `Fx.emit_hit(kind, pos)`, which emits the signal internally (still the Series 2 sound hook). The integer-as-enum warning does not fire on desktop Godot 4.7.2 at error level, so it came from Xogot's parser or an older import cache; to be safe both state machines now use **named enums** (`Player.State`, `Enemy.State`) and every raw `state == 3` literal in code and tests was replaced with the named value — the pattern that causes that warning no longer exists anywhere.
- **File logger** (autoload `Log`, `scripts/log.gd`): writes `user://barehands.log`, one fresh file per launch with a boot header (Godot version, OS, device model). `Log.info/warn/error` print and persist; the last 400 lines are kept in memory for the debug panel.
- **Debug panel** (`scripts/debug_panel.gd`, built entirely in code): tap the small **DBG** button top-left (or F3 on a keyboard) for FPS, frame time, static memory, orphan-node count, node/object/draw-call counts, each enemy's state and hp, particle bursts in flight, current time scale, and the on-device log path. It refreshes 4×/s and costs nothing when hidden.
- **Mid-play-stop audit, fixes applied**: Fx now runs with `PROCESS_MODE_ALWAYS` and carries a **watchdog** — if a hit-stop or slow-mo somehow survives 5 s it is force-restored and logged; `burst()` no longer spawns into a null scene and tracks in-flight particles; input queues (jump/punch/dodge) **expire after 0.4 s of game time**, so a jump pressed mid-air can no longer fire seconds later on landing (and slow motion no longer eats a buffered counter); every scale-down logs a warning if it interrupts another.
- **5-minute combat stress test** (`tests/stress_combat.tscn`): a bot cycles combo / parry / chaos / idle scenarios for 18,000 physics ticks (5 min at 60 fps) while watchdogs check for stuck states, stuck slow-motion, leaking particles and runaway node counts. Both smoke suites still pass unchanged.

**How to test on a phone**

1. Import and play as usual. Tap **DBG** (top-left) any time: watch FPS while idling, sprinting, and fighting; enemies list their live state; particles-in-flight should always fall back to 0 within a second of the last hit.
2. Let a parry slow-mo play out fully, then confirm the panel's `time_scale` reads 1.00.
3. The log file lives in the app sandbox: with Xogot on iOS it is inside the Xogot app's Documents folder (Files app → On My iPhone → Xogot); on an exported Android APK it is `Android/data/<package>/files/barehands.log`. The DBG panel prints the exact absolute path on your device.

**Not verified on a real phone**: the panel's readability on the 13 mini's screen, actual FPS/memory numbers (headless Linux has no GPU — the numbers below are logic-side only), and whether Xogot still shows the integer-as-enum warning after re-import (if it does, tell me the exact file:line it names).

**Added beyond the brief**: the orphan-node counter on the panel, the log-ring for the panel, and the input-queue expiry (the last one changes feel slightly: presses older than 0.4 s no longer count).

## SERIES 1 · Phase 2 — The Hero and the Camera

**What was built**

- **A real noir hero replaces the grey mannequin** (`scenes/hero.tscn` + `scripts/hero_rig.gd`): Quaternius' Universal Base Character body (head, hands, beard) dressed in the Modular Outfits ranger set (torso, sleeves, trousers, boots), plus a **code-built fedora** (crown, band, brim, tilted) and a **swinging coat skirt** (two panels hung off the pelvis that swing with your speed). Every piece shares the pack's 65-bone rig, so all 43 UAL clips drive the six pieces in lockstep — the rig grafts the mannequin's animation library onto one AnimationPlayer per piece at load. Distinct silhouette: fedora, beard, long dark coat against the neon.
- **Facing fixed and re-verified by bones**: the new pieces ship facing +Z like the mannequin did, so each carries the same 180° correction. The movement smoke still asserts `hand_l` sits west while running north, east while sprinting south, and that the climb pose faces the wall — now against the hero's skeleton.
- **A cinematic camera** (`scripts/camera_follow.gd`): slight over-the-shoulder offset (hero sits left-of-center), fast horizontal catch-up with a softer vertical lag (reads like a crane), a **field-of-view kick to 77° while sprinting**, a **gentle push-in** (6.0 → 4.6 m) whenever an enemy is within 3.5 m, **lock-on** (LOCK button above the action cluster, or L on a keyboard) that frames the hero and target together and drops when the target falls, and the existing wall pull-in and impact shake.
- **An opening shot** (`scripts/opening_shot.gd`): the camera sweeps from high over the east neon down the street and lands behind the hero's shoulder over ~7 s, with letterbox bars and a TAP TO SKIP corner label. Any tap/key skips. HUD and gameplay input are locked until it ends.
- itch.io now requires an account even for free downloads, so the CC0 packs came from GitHub mirrors (see **CREDITS.md** for exact sources and licenses). Textures were downscaled to 1024/512 px for the phone; the 4K normals were dropped for flat noir shading.

**How to test on a phone**

1. Watch the opening: it should sweep the neon and land behind the hero. Tap anywhere — it should snap to gameplay instantly.
2. Run and hold SPRINT: the view should widen slightly and snap back when you stop. Walk near the dummy: the camera should drift closer and step back out when you walk away.
3. Face the dummy and tap **LOCK** (small button above JUMP): the camera should hold a framing with both of you in it; knock the dummy down and the lock releases.
4. Run around: the coat should swing with speed; watch the fedora and beard follow the head during punches.

**Not verified on a real phone**: how the layered hero reads on a small screen (six skinned pieces ≈ 12k verts total — well within an A15's budget, but unmeasured), the opening shot's framerate on Low tier, the fedora's fit during animations (tuned headless by bone positions), and the shoulder offset's comfort in the hand.

**Added beyond the brief**: the fedora and swing coat (the brief asked for "a coat or jacket and a distinct silhouette" — the outfit pack is fantasy-only, so the long coat is code-built), the letterbox bars on the opening, and lock-on dropping automatically when the target goes down.

**Missing on purpose (tell me if you want them)**: the true *Universal Outfits* casual line (trench coat, suits) is itch-only right now. If you want a tailored trench instead of the code-built coat: download "Universal Base Characters" + "Modular Character Outfits" from https://quaternius.com (or your itch library), and upload the zip to the repo — I'll retarget the rig in the next phase.

## SERIES 1 · Phase 3 — The Wet Neon Night

**What was built**

- **Wet asphalt + puddles** (`shaders/road.gdshader`): the road is a shader now — a procedural puddle mask makes blobs mirror-smooth (metallic, roughness 0.05) while the rest stays rain-damp, with an animated ripple shimmer, and **fake neon reflections**: colored patches around each real sign's position, riding the puddles, lifted by fresnel. No screen-space reflections anywhere. Five extra mirror puddles (`street_dress.gd`) catch real specular pops from the neon lights as characters move.
- **Neon with life** (`scripts/neon.gd`): the amber sign flickers, the cyan one buzzes, the red one is broken — dark with dying strobes. Each duplicates its material so signs flicker independently. Four individually lit windows (warm/cool mix) + AC units + fire escapes (zigzag platforms, railings, stairs) + hanging wires + grates + bins, bags and a hydrant make the street read lived-in (`scripts/street_dress.gd`, all code-built, bins and hydrant have collision).
- **Atmosphere**: deeper blue fog and ambient, bloom up with a threshold, contrast/saturation grade, a **fullscreen vignette** shader (`shaders/vignette.gdshader`), three additive **light shafts** (amber kiosk, cyan window, red thug street), **steam** rising from three grates, and **rain** (`scripts/rain.gd`): 700 world-aligned streaks falling past the camera plus ground splash sparks around the hero.
- **Quality tiers** (`scripts/quality.gd`, autoload): **High** = full 3D resolution, MSAA 2x, splashes, shafts; **Low** = 0.62 resolution scale, no MSAA, no splashes, no shafts, half rain. Auto-picks after ~3 s of measured gameplay FPS (starts conservative on phones, promotes if it holds 50+), override any time in the **pause menu** (II button top-left): RESUME, Quality Auto/Low/High, live fps.

**How to test on a phone**: watch the opening — wet reflections should shimmer under the neon; walk past the amber sign and watch its color ride the puddles; the red sign should stay dark and strobe. Pause (II), switch Quality Low, watch the resolution drop and shafts/splashes vanish; switch High and they return; Auto re-measures.

**Not verified on a real phone**: everything visual — shader cost on the A15, whether the fake reflections read at 60 fps, shaft/steam/rain fill rates on Low tier, and the auto-tier threshold. This sandbox has no GPU; the tier logic is verified headless, the look is not. Tell me how it runs with DBG open.

**Added beyond the brief**: individually lit windows, AC units, the hydrant/bin collision, the II pause button styling, and rain following the camera rather than a fixed box.

## SERIES 1 · Phase 4 — Punches That Hit

**What was built**

- **Impact stack, in order** (now four layers): hit-stop (0.07–0.13 s at 5%) → enemy flash + particle spark → subtle camera shake → **new: FOV punch** (jab +1.5°, cross +3°, counter +4°, slam +6° — a fast kick-out that decays in ~0.1 s).
- **Perfect parry**: the 0.7 s slow-mo now also **zooms in** (a −6° FOV pull on top of the kick system) and fires a brief **cyan colour wash** over the screen (`vignette.flash`), so a parry reads as a moment, not just slow physics.
- **Enemies with weight**: on a kill they now **keel over ragdoll-lite** (body tilts back and drops over ~0.4 s) instead of playing the death clip standing, and counter/slam kills add a **0.4 s cinematic slow-mo beat**.
- **Rank pop-ups**: the STYLE label scale-punches (1.7→1.0) every time the rank changes.
- **Sound hooks, ready for Series 2**: every impact routes through one signal — `Fx.hit_landed(kind, pos)` with kinds `jab`, `cross`, `counter`, `slam`, `parry`, `player_hit` (plus `Fx.emit_hit` for anything new). Connect one player and the whole combat bed is done.

**How to test on a phone**: jab the dummy — small stop, small spark, small kick; cross — bigger everything; parry the thug — slow-mo + zoom + cyan wash; counter or slam — slow-mo finisher and the body topples; keep the style varied and watch the rank label pop.

**Not verified on a real phone**: whether the FOV punch frequency reads as punchy or nauseating at 60 fps, the topple's look against the death clip, and the colour wash intensity on OLED (tuned blind).

**Added beyond the brief**: the parry FOV zoom on top of the brief's camera punch, and the finisher slow-mo applying to environmental slams too.

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
  scripts/input_bus.gd   shared touch-input bus with expiring queues (autoload "InputBus")
  scripts/log.gd         file logger -> user://barehands.log (autoload "Log")
  scripts/fx.gd          hit-stop / slow-mo / particles / shake + sound hook (autoload "Fx")
  scripts/joystick.gd    the touch joystick
  scripts/touch_buttons.gd  JUMP/SPRINT/PUNCH/DODGE buttons + hint label
  scripts/style_meter.gd style rank, repetition penalty, cash points
  scripts/debug_panel.gd toggleable DBG overlay (FPS, memory, nodes, enemies, particles)
  scripts/player.gd      movement, ledge grab, punch combo, dodge/parry, counters, slams
  scripts/enemy.gd       dummy reactions, thug AI with telegraph attack, parry resolution
  scripts/camera_follow.gd  cinematic follow camera: shoulder offset, lag, FOV kick, push-in, lock-on, shake
  scripts/opening_shot.gd  the ~7 s skippable opening flyover with letterbox
  scripts/hero_rig.gd      the noir hero: 6 UAL-rigged pieces in lockstep + fedora + swing coat
  scenes/hero.tscn         hero piece composition (body, ranger outfit, beard)
  tests/smoke.tscn       headless movement+camera smoke test (not part of the game)
  tests/smoke_combat.tscn   headless combat smoke test (not part of the game)
  tests/stress_combat.tscn  5-minute self-driving combat stress test (not part of the game)
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

- Verified headless with Godot 4.7.2 (this sandbox): the project imports clean; movement+camera smoke (27 checks incl. FOV kick, push-in, lock-on, opening skip), combat smoke (17 checks incl. parry slow-mo, counter knockdown, crate slam), and the 5-minute stress test (18,000 ticks, flat node count, time_scale always recovers, 53 landed impacts) all pass after every phase. Movement (`tests/smoke.tscn`): mannequin 1.70 m, **faces its travel direction (hand bones checked against the movement vector, north and south, plus the climb pose facing the wall)**, analog speeds, sprint, jump clips, ledge climb onto the 3.4 m annex, the one-time climb hint near a grabbable edge, camera follow and wall pull-in. Combat (`tests/smoke_combat.tscn`): jab→cross lands with buffering (dummy 5→2 hp) and knockback, punch clips play, per-enemy materials don't cross-flash, repeating a move earns less, a well-timed dodge triggers slow motion and the parry counter knocks the thug down, a cross with the crate behind the dummy slams it (takedown), and `Engine.time_scale` always returns to 1.0.
- Not verified on a real phone (no device here): touch feel of the stick and the four buttons, hit-stop/slow-mo/shake actually *feeling* right (timings were tuned headless, by numbers), framerate and thermals on the iPhone 13 mini, enemy telegraph readability, and Xogot's import flow on iOS. Tell me what feels off and the next batch tunes it.
