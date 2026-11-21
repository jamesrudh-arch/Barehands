# XOGOT ON iPHONE — the device truth table (B18.3)

Godot 4.7, Mobile renderer, Metal 4 on supported iPhones. This file is
the exact phone procedure plus the text storyboards of every new
screen, so you can compare what you SEE with what was built.

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
