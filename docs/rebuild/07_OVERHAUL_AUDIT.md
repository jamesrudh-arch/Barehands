# 07 — THE OVERHAUL AUDIT (visual quality report, from real frames)

> Written 2026-11-23 from 9 actual gameplay screenshots, each judged
> by a vision model against the GTA V / Mafia DE cinematic-realism
> bar (the frames + full verdicts: `download/overhaul_audit/shots/`).
> This is the evidence base for STAGE 5 — the visual + content
> overhaul ordered by the owner after on-phone testing.

## THE VERDICT (8/8 gameplay frames: REPLACE)

Every frame fails the bar, and the failure is not one bug — it is
the presentation layer's foundation:

| Shot | What the frame actually shows | Verdict |
| --- | --- | --- |
| 01 title menu | a flat magenta slab where the 3D backdrop should read; zero depth | REPLACE |
| 02 warehouse home | near-black room, one light pool, "glossy magenta blob" hero, a single crate | REPLACE |
| 03 street night | ~70% pure black, one grey trapezoid wall, the blob hero, debug label | REPLACE |
| 04 hero close-up | "plastic toy helmet", no face/hair/fabric readable at 0.9 m | REPLACE |
| 05 enemy close-up | same blob + grey-box wall; "Roblox-tier prototype" | REPLACE |
| 06 car close-up | the car shot framed the hero blob + a featureless grey door | REPLACE |
| 07 club avenue | "untextured black boxes", no neon read, no atmosphere | REPLACE |
| 08 docks | flat navy panels, orange strips, void beyond | REPLACE |

What the vision model credited: the mobile UI layer (button layout,
tutorials, HUD hierarchy) is competent, and camera framing is genre
correct. Everything VISUAL beneath the UI is placeholder-grade.

## THE TWO ROOT CAUSES

### 1. A REAL PIPELINE BUG: the characters lose their textures

The capture log caught it red-handed:
`Unable to open file: res://.godot/imported/Rogue_rogue_texture.png-*.ctex`
— the import cache (`.godot/imported/`, untracked by git) had lost
the character textures, so the KayKit materials fell back to the
engine's missing-texture magenta. **That magenta blob is very likely
what the owner's phone showed.** Any fresh checkout (or recycled
sandbox, or a clean CI/export) reproduces it. FIX (S5.0, applied
with this commit): the battery and every build run `--import` first;
a new suite check asserts the character materials' textures are
non-null at runtime.

### 2. The assets themselves cannot reach the bar even when textured

With textures restored, a neutral studio render of the KayKit rigs
(shot 09) reads: chibi proportions (2.5–3 heads tall), bead eyes,
mitten hands, mascot-style pelt hat, matte clay materials — "the
opposite of realistic human proportions". **KayKit is a fine stylized
kit and the wrong cast for a grounded crime game.** The city is in
the same class: flat-colour BoxMesh slabs, no surface texture, no
street detail, near-void lighting.

## THE HONEST INVENTORY (keep / basic / missing / replace)

**KEEP (proven by suites, wired to real systems):**
- The control foundation: the one InputMap (06_CONTROL_MAP), the
  touch diamond + sticks generated from it, X/Y/A/B combat verbs.
- The systems core: Game/WorldState travel + save round-trip, the
  door law, the mission engine (M0/M1 with real stage conditions),
  the vehicle physics profile (VehicleBody3D, the .tres feel knob),
  combat data (5 styles, 30 attacks, cancel windows, i-frames),
  heat/clinic/debt loop, the phone UI shell (tabs + live values),
  the boot chain (splash → menu), the battery framework.
- The engine laws banked in 04_DECISION_LOG (D1–D13) — they carry
  over to any asset set.

**BASIC (works, under-presented — rebuild the presentation, keep the
system):** the 4 areas' layouts/travel, the HUD, the title logic,
the vehicle handling, the enemy AI loop (spot/approach/telegraph/
swing/recover).

**MISSING (ordered by player impact):** phone CALLS (ringing,
answer/decline, consequences), the world map + GPS route, police +
wanted, NPC crowds + routines, weapons + armour, M2–M6, day/night +
weather, a real cutscene system, music/ambience identity, the 5th +
6th districts.

**REPLACE:** the character cast (hero, enemies, NPCs — realistic
humans with faces), vehicle meshes (detailed bodies, not slabs),
building/road/prop presentation (PBR materials, architectural
detail, street furniture), the lighting/grade strategy (cinematic
exposure, not near-black voids).

## STAGE 5 — THE OVERHAUL (the build order)

Each step ends green (suite + a fresh screenshot audited by the
vision gate) before the next begins; the battery grows with it.

- **S5.0** THE PIPELINE FIX — `--import` in the battery + builds; a
  runtime texture-present check. (Applied with this commit.)
- **S5.1** THE CAST — realistic rigged humans (hero + 4 distinct
  enemy identities); retarget UAL/KayKit clips via the D12 BoneMap;
  faces, hair, layered clothing; idle/social animations.
- **S5.2** THE MATERIAL CITY — PBR asphalt/sidewalk/brick/concrete +
  normals, wet-night sheen, the cinematic lighting strategy (few
  real lights, emissive practicals, fog, a colour grade that keeps
  colour instead of voiding to black), street detail (furniture,
  cables, signage, trash, parked cars, drainage).
- **S5.3** THE FLEET — detailed vehicle meshes + interiors, damage
  state, lights on, entry/exit animation, a motorcycle.
- **S5.4** THE LIVING WORLD — ambient NPCs (routines, reactions,
  panic, calls to police), traffic, police + wanted with witnesses
  and escalation.
- **S5.5** PHONE 2.0 — real ringing (ringtone + incoming-call screen
  + answer/decline), call state machine, story-scheduled calls,
  message threads that matter, contact profiles.
- **S5.6** THE MAP — world map UI (pan/zoom, districts, icons),
  destination pick + GPS route over the road graph, live player
  marker, objective syncing.
- **S5.7** THE STORY — M2–M6 playable end to end (investigation,
  kidnapping, betrayal arc, endings), cutscene system (camera +
  dialogue + subtitles), story consequences in the phone/world.
- **S5.8** THE ARSENAL — firearms + melee weapons, aiming/reload/
  recoil/muzzle flash/impact, armour, enemy weapon behaviour.
- **S5.9** SKY + WEATHER — day/night cycle, rain + wet roads,
  puddles, per-district air.
- **S5.10** THE SOUND — music identity (exploration/combat/story),
  ambience layers, engine/call/ringtone audio, verified by playback.
- **S5.11** CINEMATICS + POLISH — opening cinematic, character
  intros, transitions; performance pass per area (budgets enforced
  by smoke_perf); full battery; the device report (VERIFIED vs
  PHONE-ONLY) + the zip.

## NEXT ACTION (exact)

1. S5.0 commit (this one): the import fix + this audit.
2. S5.1 begins: test the realistic-human asset sources reachable
   from the sandbox (Mixamo, Quaternius, polyhaven, GitHub packs),
   land the hero replacement, retarget, screenshot-gate it.
