# 01 — EXISTING PROJECT ASSESSMENT (the rebuild reference)

> Written 2026-11-23, immediately after the owner's stop-and-rebuild
> directive. This is the inspection record the reconstruction works
> from: what exists, what state it is in, what gets replaced, what is
> retained. It is documentation of the one project — not a backup, not
> a second implementation. The rebuild happens in this same tree.
> Pre-rebuild snapshot commit: **a08a541** (last old-implementation
> commit; everything after it is the rebuild).

## 1. Repository identity

- Remote: `github.com/jamesrudh-arch/Barehands.git`, branch `main`.
- Engine: Godot **4.7.2** (stable), `rendering_method=mobile`,
  landscape (orientation 4), 1280×720 base viewport, stretch
  `canvas_items/expand`.
- Target: **Xogot on iPhone** (Metal; iPhone 13 mini floor at locked
  30, iPhone 16 hero at 60). The sandbox verifies with headless +
  Xvfb/llvmpipe runs; **the device is the judge** — sandbox results
  never prove iPhone behaviour.
- Size: ~222 MB working tree (57 MB `assets/`, 1.8 MB `scripts/`,
  64 test suites, 46 tools scripts). Untracked-in-git bulk must be
  re-checked against Xogot's ~200 MB guidance (PART 12).

## 2. Structure inventory

| Path | Contents |
| --- | --- |
| `scenes/` | 8 scenes: `main.tscn` (street), `warehouse.tscn` (start room), `hero.tscn`, `enemy.tscn`, `player.tscn`, `safe_boot.tscn`, `stage0.tscn`, `lookdev.tscn` |
| `scripts/` | 116 GDScript files (~1.8 MB), 40 registered autoloads |
| `tests/` | 64 smoke/regression suites + render checks (battery runner `tools/b18_battery.sh`) |
| `assets/` | 108 `.glb` (Kenney kits: city, commercial, industrial, suburban, roads, cars, furniture, food, traffic), ~50 `.ogg` + 48 `.wav` (mastered CC0 bank), 48 png, `cast/`, `voice/` |
| `attacks/` | 15 `.tres` AttackData resources (jab…finisher, pipe, shot) |
| `shaders/`, `skills/`, `docs/`, `tools/` | rain/wet/outline shaders, skill defs, planning docs, build/test infra |
| root docs | PROJECT_BIBLE, ART_BIBLE, DESIGN_SYSTEM, MOVES, TESTING, CHANGELOG, README, XOGOT, CREDITS, PRODUCTION_CHECKLIST, STATE.json, VERSION.txt |
| `Universal Animation Library[Standard].zip` | 15.9 MB animation library (UAL1_Standard FBX/GLB + licence). `scenes/enemy.tscn` references its GLB at `res://assets/UAL1_Standard.glb` — **the file was never extracted, the reference is broken** |

## 3. What the old implementation actually is

A code-built-everything game: every building, prop, humanoid, car and
effect is generated from GDScript primitives at runtime (BoxMesh /
CapsuleMesh / QuadMesh + Label3D). The asset kits on disk are used
only opportunistically via `kit.gd` (which itself falls back to
code-built meshes when an import is missing — the log shows it doing
exactly that for furniture).

**Broken by design:** `hero.tscn` references six non-existent
`assets/hero/*.gltf` files; `enemy.tscn` references the never-extracted
`UAL1_Standard.glb`. Both scenes parse-fail their ext_resources and
fall back to code-built rigs. This is the "placeholder" state the
directive orders replaced.

### Systems present (all to be REPLACED unless listed in §6)

- **Boot**: SafeBoot + Stage 0 (dependency-free boot diagnostics),
  build stamp, VERSION.txt. Current main scene: the warehouse start
  room (R1), fading to `main.tscn` (the street).
- **Player/camera/input**: `player.gd` (~1500 lines,
  CharacterBody3D + code-built rig + procedural attack anims),
  `camera_follow.gd`, `input_bus.gd` (queued action pipe),
  `touch_buttons.gd` + `action_button.gd` + `cam_stick.gd` (the X/Y/A/B
  diamond, two-thumb controls).
- **Combat**: 5 enemy kinds, punch tree with stages, combos
  (`combo_input/counter/table`), super meter, posture/composure, fight
  score/style rank, grab/throw, dirty tactics, hitstop via `fx.gd`,
  15 AttackData resources. Five styles exist as data + stat modifiers
  with largely shared moves.
- **World**: `blocks.gd` lazy 3-block street (riverside / market /
  foundry) built by `block_builder.gd` (~700 lines) from primitives;
  district gates (only ONE physical gate existed — riverside→market —
  the R13 audit found three of four directions missing); five
  interiors (noodle, apartment, gym, bar, club) + venues + backroom +
  apartment; `doors.gd` (R11 door law, shipped green 44/44);
  pickups, decals/scars, events, fire, weather, traffic, crowd.
- **Simulation/economy**: heat, wallet, ledger/debt beats, trust,
  jobs (10 templates), kidnap arc, progression, cast (16 named NPCs),
  phone (calls/texts/map/ledger), dialogue, narrator (TTS).
- **Presentation**: HUD, radar + full map (B32 interior cards),
  green guide orb, music (adaptive stems), sound bank + synth
  fallback, haptics, lookdev.

### Test state at stop

64 suites; the last full battery before the snapshot was green
(smoke_warehouse 28, smoke 55 controls, interiors 12, map 43, phone
40, kidnap 62, progression 23, null_watch 993/0, safe_boot 27,
live_boot 15, doors 44 …). These suites verify the OLD
implementation; they are replaced system-by-system during the rebuild
(a suite is deleted in the same commit that deletes the system it
tested).

### Known defects (owner's device evidence, V3 + session reports)

- On-device (B17/B18 era): near-black world, one harsh crackling
  music loop, invisible bodies, stuck-in-room, doubled button labels,
  yellow bar, "no objective", duplicated/overlapping sign text,
  box cars, mannequin pedestrians, one empty road. Fixes were
  sandbox-verified but **no DEVICE REPORT was ever received** for
  the R1–R4 build — every on-device claim is PHONE-ONLY.
- Asset pipeline: fresh-import GLBs previously failed to appear on
  the iPhone (V3 PART A2 #4); the old workaround was code-built
  everything. The rebuild's answer is native-resource conversion
  (ResourceSaver → .res/.tscn, committed) + the ASSET DEVICE TEST.

## 4. Why it is being replaced (the directive)

The owner's order: professional production standards, proper assets
(no primitive-shape or placeholder models when real ones exist), one
authoritative implementation per system, a complete connected
open-world experience (six areas, vehicles, weapons, missions,
story), documented technical decisions, and a cohesive art direction.
The code-built approach hit its ceiling (the owner's words: people
and cars look "poor, floppy and AI-looking"; "the city is totally
incomplete").

## 5. What is REPLACED (removed as their successors land)

All gameplay systems and their scripts/scenes/tests: the code-built
player rig, enemy rigs, block builder street, interiors as built,
InputBus+touch layer (a new one-input-map system lands), HUD, combat
implementation, phone/map/guide UI as built, the 3-block world
architecture (superseded by the six-area world), the old planning
docs' authority (PROJECT_BIBLE stays as history; the new
`docs/rebuild/02_MASTER_DESIGN.md` is authoritative).

## 6. What is RETAINED

- Repository configuration: `.git/`, remote, `.gitignore`,
  `.github/`, `project.godot` (edited in place, not preserved as-is).
- Build/test infrastructure: the Xvfb + headless Godot harness
  convention, clean-user-dir battery pattern (`tools/*battery*`,
  check_build_identity), the Godot 4.7.2 binary cache in `.cache/`.
- **Asset kits already on disk** (Kenney city/commercial/industrial/
  suburban/roads/cars/furniture/food/traffic GLBs) — re-verified,
  re-imported properly and actually USED this time.
- The mastered CC0 audio bank (`assets/audio/*.ogg|wav`, licences in
  CREDITS.md).
- The UAL animation library zip (licence to verify in §05 register).
- The game identity: see `02_MASTER_DESIGN.md` (harvested from
  PROJECT_BIBLE.md, the V3 master prompt in
  `upload/Pasted Content_1795410039835.txt`, and the stop directive).
- The device-honesty discipline: VERIFIED vs PHONE-ONLY, the device
  report pattern, XOGOT.md instructions.

## 7. Development state at the stop point

- Last released: OVERRIDES-R1R4 build (f563337/stamp 511227c): boots
  into the warehouse, visible gate to the street, two-thumb controls,
  X/Y/A/B law; device report + zip delivered; **no phone result
  received**.
- Last code landed: R11 doors (this snapshot, a08a541).
- Abandoned mid-flight (per the stop order): R13 area-gate build
  (reverted), R5/R12/R16 (never started).
- The full old plan (docs/USER_OVERRIDES.md R1–R16) is superseded by
  this rebuild; those requirements that still describe the intended
  game (doors, missions, areas, controls, faces, signs) are carried
  into the new traceability register, re-scoped to the rebuild.
