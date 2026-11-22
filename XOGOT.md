# XOGOT ON iPHONE — the device truth table (B18.3)

Godot 4.7, Mobile renderer, Metal 4 on supported iPhones. This file is
the exact phone procedure plus the text storyboards of every new
screen, so you can compare what you SEE with what was built.

## B23 — THE RECONSTRUCTION BUILD (read this first)

Your iPhone screenshots were the ground truth: ghost/translucent
figures, DUMMY labels, a missing hero, primitive boxes, a flat world.
The B23 response is a VISUAL RECONSTRUCTION on one principle:

**Every character, car, building and lamp the player must SEE is now
built from code at runtime - no gltf, no textures, no import step.**

- THE PEOPLE: a full humanoid framework (scripts/humanoid.gd) - real
  joint hierarchy, body meshes with a FACE (brows, eye whites, nose,
  mouth), six hair styles, layered clothing, skirts, jackets with
  collars. The hero, the sixteen named cast, every pedestrian and
  every enemy wear it. Procedural animation: stride-matched walk and
  sprint cycles, idle breathing with weight shift, jump/land, punches,
  kicks, flinches, guard, rolls, phone-hold, dance. The floating
  DUMMY/MUSCLE/CREW name tags are GONE.
- THE TRAFFIC: code-built sedans, taxis, police cruisers and SUVs
  (body, cabin, glass band, wheels that roll, bumpers, taxi roof
  sign, police beacons) on the existing engine - plus the signalised
  crossing: red/amber/walk cycle, cars hold on red, pedestrians take
  the zebra on the walk phase.
- THE CITY: every street plot now carries a code facade - five-paint
  palette, full window grids per floor (lit/dark/gaps), parapets,
  water towers, AC boxes, noir blade signs. Streetlamps are code-built
  dark poles (the old pale glb arm read as a white bar across your
  screen). The kit glb buildings no longer take street plots.
- THE BOOT: the game boots STRAIGHT INTO gameplay (Stage 0 was a
  diagnostic trap; it is now under PAUSE -> DIAGNOSTICS). Fresh
  installs get the title sequence once (studio card -> title -> menu).
- AUTOSAVE on every block gate and interior exit.

What this means for you: import the B23 zip the same way, and the
people/cars/buildings you saw as ghosts should now be THERE - not
because a Linux test said so, but because nothing about them depends
on the asset pipeline anymore. If anything still ghosts on the phone,
it is NOT the gltf problem class - paste me the DEVICE REPORT and say
what you see.

Verified HERE (Linux + llvmpipe at 640x360, honestly NOT an iPhone):
boot-to-gameplay drive 15/15 (picker, title, PLAY, opening skip,
walk/sprint/jump, camera, save/load roundtrip, layout mirroring,
gate travel), the full 47-suite battery, and three rounds of VLM
screenshot inspection ending "PASS - looks like an actual
third-person open-world game at phone resolution".

## B21 — THE AUDIT BUILD (what changed and what to check)

The B21 build fixes the BUILD IDENTITY LIE: through B19/B20 the in-game
stamp said "B18 e1dfde3" because scripts/build_info.gd was never
regenerated (the generator named in its header did not exist in the
repo). B21 ships scripts/gen_build_info.py; the stamp, the debug menu,
Stage 0 and the DEVICE REPORT all read ONE identity now, and the
project imports as "LEVERAGE B21" - a DIFFERENT name from every stale
entry, on purpose.

Also in B21: the DBG panel shows the live movement chain (input lock,
stick vector, velocity, position, camera yaw, state, scheme), the
DEVICE REPORT gained engine/scene/camera/weather/NPC-census fields,
the npc_rig census group exists, and two LIVE-PLAY suites drive the
real stick pipeline on a rendered frame (apartment walk-out, street,
traffic, shop, combat - evidence PNGs in download/live_shots_b21/).

Phone checks (same as Gate A): world visible, audio clean, walk out,
guide leads, then DBG -> DEVICE REPORT -> copy -> paste back.

## GATE A (B20) — WHAT TO EXPECT ON THE PHONE

The B20 build (the GATE A zip) exists to answer ONE question: can you
SEE the world, HEAR clean audio, and WALK OUT of the apartment?

1. Import the new zip (the folder with `project.godot`). The project
   name reads LEVERAGE B18; the stamp on screen reads B20 <hash>.
2. On boot the safe lights are ON (XOGOT SAFE is the mobile default):
   the street and the rooms are lit by a warm sun + a camera light -
   nothing should be a black void. If it still reads dark: DBG ->
   VISUAL DEBUG -> BRIGHT (or the Brightness slider up to 2.0).
3. Walk out: the guide starts by itself (FIND THE DOOR -> the frame
   glows). Walk into the door - it OPENS BY ITSELF during the guide -
   then you land on the street. If you are ever stuck: DBG -> GO
   OUTSIDE.
4. Listen: the music is a soft warm pad (quiet), the rain is soft. If
   anything crackles, note WHEN (always / on hits / on the loop).
5. The buttons are the FIGHTING diamond now: X PUNCH, Y HEAVY,
   B KICK, A DODGE (letters big, action names small). The amber chip
   strip now sits top-centre - nothing crosses the buttons.
6. THEN: DBG -> DEVICE REPORT -> select all, copy, and paste the text
   back. That report (plus what you see/hear) decides everything next.

## THE OLD PHONE PROCEDURE (kept for reference)

## THE PHONE PROCEDURE (exact)

1. Unzip `Leverage_B18_3_FullPackage_2026-11-21.zip` in Files. The
   folder with `project.godot` IS the project. Delete old LEVERAGE
   entries in Xogot first. Your phone still runs B17 — nothing here
   exists on it until THIS zip is imported.
2. Force-quit Xogot. Reopen → Import → pick THAT folder. The project
   name must read LEVERAGE B18.
3. WAIT for the import (spinner stopped). Run once, close, run again.
4. STAGE 0: green banner → LAUNCH FULL GAME (the start sequence plays
   only on this path).
5. The stamp must read B18 <hash>. NOTE: the push is still
   credential-blocked in the sandbox; a bundle carries the commits.

## THE START SEQUENCE (BUG 14) — card by card

1. BLACK 0.3 s.
2. STUDIO CARD (~3.2 s): a thin GOLD RING draws itself around a
   fainter inner ring; the DY serif monogram fades in; D ' Y O U N G S
   in gold serif capitals; G A M E S smaller; a gold line draws
   beneath; one light sweep. Sound: low swell + soft chime.
3. CONTENT NOTICE (~2 s): MATURE THEMES 16+ / Stylized violence,
   crime, strong language.
4. TITLE CARD (~4.2 s): the 3D EXTRUDED LEVERAGE rises out of the wet
   ground (chrome body + a dark mirrored reflection), the cast behind
   it (three bosses in the back fog, six crew mid-row, the HERO
   front-right in a fighting stance with lit eyes), magenta rim left,
   cyan right, a light sweep every 8 s. The narrator speaks the intro
   (subtitles always). If the 3D ever fails, the flat chromatic
   wordmark draws instead — one of the two is ALWAYS there.
5. LOADING (~1.4 s): thin cyan bar + one tip + the stamp.
6. MAIN MENU over the 3D art: PLAY / CONTINUE (greyed without a save)
   / SETTINGS / CREDITS, lower-left. Tap anywhere skips the cards.

## THE FIGHT CONTROLS (BUG 8) — FIGHT scheme (default)

                      [STYLE] [PHONE]
          [OBJ] [GUARD] [GRAB] [SPRINT] [HELP]
                      [Y HEAVY]
        [JUMP]  [X PUNCH]  (SUPER)  [B KICK]
                      [A DODGE]

X punch (X X X = ONE-TWO-THREE, X X Y = RISING KNEE, X B = STEP KICK),
Y heavy (tap instant, hold charged), B kick (B Y = HAMSTRING; near a
door/pickup OUT of combat B becomes OPEN/ENTER/PICK UP — it stays KICK
within 6 m of a live enemy), A dodge, GUARD hold-to-block (the first
moments parry), GRAB only when usable, SUPER in the diamond centre
when full. The input strip shows your last taps; MOVES is in pause.

## THE GUIDE (BUG 9)

A GREEN ORB floats 1.5 m up, 4-6 m AHEAD along the route (trail +
ground chevrons + an edge arrow when off-screen). It waits and pulses
when you stop, speeds up when you run, re-routes, bounces at the
destination. The radar route, the destination beam and the map route
are the same green (cyan alt in Settings). OBJECTIVE recalls it and
turns the camera; HELP repeats the hint; the sonar quickens nearby.

## THE FIRST MINUTES (BUG 7 + 12)

The apartment: lit, bed, crate, lamp, window, a bottle BY THE BED, ONE
breathing cyan door (THE STREET sign, OPEN prompt, handle, creak +
swing). B opens it. FIND THE DOOR → OPEN IT → REACH THE DUMMY, with
narrator lines. Weapons glow around the street (pipe at its old spot,
alley bat, crates plank, noodle-front bottles) with [B] PICK UP
prompts; the HUD chip shows weapon + durability; weapons break. Cash
yellow / first-aid green / keys blue.

## NOT BUILT THIS PASS (plainly)

- The CC0 model kits (Kenney, Quaternius) are documented in
  ART_BIBLE.md but NOT integrated — the asset pipeline needs its own
  verified session; the code-built street is the working placeholder.
- Locked doors + hold-to-do long actions: no content exists for them.
- Frame budgets (60 fps iPhone 16 / 30 fps 13 mini): PHONE-ONLY.

## WHAT I NEED FROM YOU (three taps)

1. Import + play 2 minutes: cards → PLAY → follow the green orb out →
   pick up the pipe → punch the dummy. ONE line in words.
2. DBG → DEVICE REPORT → COPY LOG → paste the text back (it carries
   AUDIO, CHARACTERS + VEHICLES, AMBIENT LIFE, GUIDE, quality).
3. Rotate + tap the radar → tap the map to pin a waypoint. ONE line.
