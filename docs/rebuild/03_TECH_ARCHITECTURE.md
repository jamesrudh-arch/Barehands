# 03 — TECHNICAL ARCHITECTURE (the system map)

> How the rebuilt game is built: every system, its ONE authoritative
> implementation, how systems connect, and the order the old
> implementation is replaced in. Companion docs: 02_MASTER_DESIGN.md
> (what the game is), 04_DECISION_LOG.md (why it is built this way),
> 06_CONTROL_MAP.md (the input map).

## 1. Design laws

1. **One authoritative implementation per system.** When a new system
   lands, the old one it replaces is deleted in the same commit —
   including its tests, its autoload entry and its docs references.
   Transitional overlap exists only inside a commit, never at a gate.
2. **Stage 0 discipline survives** (from the old project, still good):
   a dependency-free boot path (SafeBoot) that works when autoloads
   are broken; no script relies on global class_name resolution at
   parse time (explicit load()/preload() of paths); every 3D scene
   has an active camera; guard every node access.
3. **Data-driven where the design says so**: missions, styles,
   attacks, vehicles, NPC appearances and world-state keys are
   Resources or tables, never scattered literals.
4. **The device is the judge**: sandbox suites prove INTEGRATED+TESTED;
   iPhone behaviour is verified by the owner's DEVICE REPORT.
5. **Mobile-first**: the frame budget (30/60 fps), draw-call cap,
   2–3 dynamic lights and memory budgets are constraints on the
   architecture, not late optimisations.

## 2. Directory plan (the new tree grows alongside, then replaces)

```
scenes/
  boot/      splash.tscn, title.tscn (the 3D key art), menu.tscn
  areas/     warehouse.tscn (home+yard), neighbourhood.tscn,
             club_district.tscn, docks.tscn, airport.tscn,
             second_city.tscn, interiors/*.tscn
  entities/  hero.tscn, npc.tscn, vehicle_*.tscn
  ui/        hud.tscn, phone.tscn, map_screen.tscn, pause.tscn,
             briefing.tscn, mission_result.tscn
scripts/
  core/      game.gd, save_game.gd, audio.gd, world_state.gd,
             events.gd, tuning.gd, log.gd, haptics.gd
  player/    hero.gd, camera_rig.gd, touch_ui.gd, combat.gd,
             styles/*.gd, weapons.gd
  world/     area_manager.gd, gates.gd, doors.gd, pickups.gd,
             interiors.gd, weather.gd, daynight.gd, traffic.gd,
             crowd.gd, guide.gd
  npc/       npc.gd, schedules.gd, appearance.gd, ai.gd
  missions/  missions.gd, mission.gd, stages/*.gd, givers.gd
  systems/   phone.gd, ledger.gd, heat.gd, trust.gd, economy.gd,
             kidnap.gd, dialogue.gd, narrator.gd
  ui/        hud.gd, radar.gd, full_map.gd, menu.gd...
data/       missions/*.tres, styles/*.tres, vehicles/*.tres,
            attacks/*.tres, appearances/*.tres, strings.tres
assets/v2/  (the registered packs; converted native copies under
            assets/native/ once the D3 proof lands)
tests/      (new suite per system as it lands; old suites deleted
            with the systems they tested)
```

## 3. The systems and their one implementation

### Boot & flow — `core/game.gd` (autoload `Game`)
A state machine: BOOT → SPLASH → TITLE → MENU → PLAY ⇄ PAUSE, with
GAMEOVER and CUTSCENE states. Owns the scene swap
(`travel(area_id, spawn_id)`: fade → free current area → instance the
target area scene under `Game.world` → restore player at spawn →
fade in), the start sequence (studio card → notice → 3D title →
menu), and the "one fade owner" rule. **Replaces**: the old
SafeBoot-ladder + blocks.gd lazy street + change_scene_to_file calls.
SafeBoot survives as the dependency-free diagnostic entry.

### Player — `player/hero.gd` + `player/camera_rig.gd`
CharacterBody3D with a real rigged model (KayKit-class, faces
visible), AnimationTree (locomotion blend + combat states + hit
reactions), spring-arm third-person camera with collision, soft
lock-on, face light. Movement: walk/run/sprint (stick magnitude),
jump/vault, crouch. **Replaces**: player.gd's code-built rig +
procedural anims, camera_follow.gd.

### Input — ONE InputMap + `player/touch_ui.gd`
The project InputMap is the single action table (06_CONTROL_MAP.md).
The touch UI (floating move stick, look stick, X/Y/A/B diamond,
pills) is GENERATED from the action table — labels, positions and
actions cannot disagree. Controllers bind the same actions.
**Replaces**: input_bus.gd + touch_buttons.gd + action_button.gd +
cam_stick.gd + input_strip.gd.

### Combat — `player/combat.gd` + `data/styles/*` + `data/attacks/*`
AttackData resources (damage, hitstop frames, knockback, cancel
window, haptic, audio layers — the old repo's proven .tres pattern,
rebuilt). Five styles as distinct move sets behind the same buttons
(X punch / Y heavy / A kick / B dodge-context), each with its own
stance idle, strings, defence and counters; attack tokens; posture
breaks; SELECTIVE hitstop (attacker+target only — never global
time_scale); grab/throw; improvised weapons with durability; the
firearm path (aim/shoot/reload). **Replaces**: player.gd's punch
tree, enemy.gd's fight logic, combo_*.gd, super_meter (rebuilt as
the Leverage Strike meter), fight_score (rebuilt as Style Rank).

### NPCs — `npc/npc.gd` + schedules + appearances
One NPC framework: named characters (data-driven bios, voices,
schedules, trust) and crowd pedestrians (parametric appearance
generator, ≥40 looks, palette rules), NavigationAgent3D routing over
per-area nav regions, RVO avoidance, reactions (witness, flee,
gossip), conversations. **Replaces**: cast.gd, crowd/wanderer
scripts, enemy.gd (enemies are NPCs with hostile AI).

### Vehicles — `world/traffic.gd` + `scenes/entities/vehicle_*.tscn`
Player vehicles: VehicleBody3D scenes (≥9 types) with entry/exit,
engine audio, damage. Traffic: kinematic agents on the road graph
with signals and pedestrian avoidance. **Replaces**: bike.gd,
traffic as built.

### World & areas — `world/area_manager.gd` + `scenes/areas/*`
Six area scenes, one in memory, gates signposted + taxi/plane
travel, doors (the R11 door law carried forward as the design),
pickups, interiors (≥9), per-area lighting/music/ambience/weather
profiles, day/night. **Replaces**: blocks.gd + block_builder.gd +
the old main.tscn street + interior/venue scripts (their design
knowledge — the door law, the placement contracts — is harvested
into the new implementations first).

### World state — `core/world_state.gd` (autoload `WorldState`)
ONE shared table (keys → values) + the event queue; every system
reads/writes through it; persistent consequences (broken doors,
boarded shops, trust, heat, debt, prices, who calls) live here and
nowhere else; the save file serialises it. **Replaces**: city.gd's
state + events.gd + the scattered persistence.

### Missions — `missions/missions.gd` + `data/missions/*`
Data-driven Mission resources (giver, briefing, stages with
markers/conditions/fail states, rewards, consequences, next), the
tracker UI, givers with markers, briefing/result screens,
checkpointing per stage, the M0–M6 chain first. **Replaces**:
jobs.gd, kidnap.gd's flow (the arc becomes missions + world state).

### Phone & systems — `systems/*`
The phone (calls that can interrupt fights, texts, apps), ledger
(debt/beats/interest), heat (tiers, witnesses), trust (friends),
economy (dirty/clean, shops), dialogue (subtitled, choices),
narrator (TTS + fallback). Designs carry over from the bible; the
implementations are new. **Replaces**: phone.gd, ledger*.gd,
heat.gd, trust pieces, dialogue.gd, narrator.gd.

### UI — `ui/*` + `scenes/ui/*`
HUD (radar, objective, compass, health/composure/heat/money, style
name, weapon badge), full map (pan/pinch/waypoints/layers), green
guide, pause menu, settings, phone UI, briefings, the design-system
theme (ink/panel/magenta/cyan/green, type scale, 48pt targets,
safe areas). **Replaces**: hud.gd, radar/full_map/guide as built,
first_run overlays.

### Audio — `core/audio.gd`
Six buses with limiter, the CC0 file bank first, adaptive music
state machine, layered impacts, spatial sources, TTS voices +
radio-babble fallback, captions. **Replaces**: sound.gd/music.gd/
narrator.gd wiring (the bank and the audit tool survive).

### Save — `core/save_game.gd` (autoload `SaveGame`)
Slots: world state + player (area, position, style, health, money,
inventory) + mission progress + phone history + settings. Autosave
at beat boundaries/pause. **Replaces**: save_game.gd as built.

## 4. Data flow (one picture)

```
InputMap ─→ touch_ui/controller ─→ hero.gd ─→ combat.gd ─┐
                                                          ├→ NPC/vehicle sim
Missions ─→ stages ─→ WorldState ←──── economy/heat/trust ┘
    │                        │
    │                        └→ save_game.gd (serialises the table)
    └→ guide/radar/map/objective UI (read WorldState + area data)
Audio reacts to: combat events, phone, world state, area profiles
```

## 5. Teardown and replacement order (the build sequence)

Each step lands with its own suite; the old counterpart is deleted
in the same commit. The project stays runnable at every step (the
old game keeps running until its organs are replaced).

1. **Skeleton + boot**: new autoloads (Game, Log, Tuning, Haptics,
   Audio, SaveGame, WorldState), project.godot input map, the boot
   scene chain (splash → title placeholder → menu → empty warehouse
   shell). Delete: the old autoload ladder's replaced entries.
2. **Character pipeline proof (D3/D11)**: import KayKit + UAL,
   retarget, AnimationTree, convert to native resources, render
   check with a face visible. Gate for everything character-shaped.
3. **Player + camera + touch UI**: hero moves with real animations,
   two-thumb controls live, the X/Y/A/B diamond works. Delete:
   input_bus.gd, touch_buttons.gd, camera_follow.gd, player.gd.
4. **The warehouse area**: the full home (training corner, yard,
   gate) as scenes/areas/warehouse.tscn.
5. **Combat core**: the five styles' first pass on the dummy + bag,
   AttackData, hit reactions, Style Rank.
6. **Neighbourhood area + doors + world state**: streets/buildings
   from the kits, the door law, pickups, NPCs walking, WorldState
   persistent. Delete: blocks/block_builder/doors/interiors old,
   main.tscn street.
7. **Missions M0–M1**: tracker, briefing, stages, pass/fail, the
   tutorial chain out of the warehouse. Delete: jobs.gd, old suites.
8. **UI pass 1**: HUD, radar, map, guide, phone, pause, settings.
9. **Club district + docks**: areas 3–4, venues, interiors, factions
   in the street.
10. **Vehicles + traffic**: drivable cars, traffic AI, taxi travel.
11. **Airport + second city**: areas 5–6, the plane.
12. **Systems full**: economy/debt beats, heat tiers, trust, kidnap
    arc missions, dialogue, narrator.
13. **Start sequence + 3D title**: D'YOUNGS card, notice, key art
    with the cast. Delete: old opening/first_run.
14. **Performance + quality program**: presets, LOD, pooling, the
    render quality bar per area (VLM-inspected renders).
15. **Full regression + delivery**: the complete battery, the
    traceability register closed, the verification guide.

## 6. Art direction (one look, everywhere)

- **Style**: stylized low-poly with clean colour blocks, consistent
  with the KayKit/Quaternius/Kenney CC0 families; thin rim/edge
  lighting on characters and vehicles; NO mixed art styles — every
  imported model gets the palette pass if its source colours clash.
- **Palette** (the whole game): ink #05060F, panel #0E1226, text
  #E8E8F4, magenta #FF007F, cyan #00F0FF, guide green #3DDC84,
  amber #FFB020, danger #FF4D6D, sodium-orange practicals; night is
  the signature (deep blue-black shadows, neon accents, wet streets
  with low roughness), day/night and weather run on top.
- **Lighting**: 2–3 dynamic lights per area + practicals (signs,
  lamps, windows), height fog toward magenta/cyan haze, one post
  pass (contrast/bloom/light CA), never pure black, never pure
  white, emission ≤ ~2.0.
- **Characters**: visible faces (eyes/brows/mouth contrast), normal
  proportions (~7 heads), per-faction colour coding, name tags only
  when close/locked.
- **The old ART_BIBLE.md / DESIGN_SYSTEM.md are superseded** by this
  section + 02_MASTER_DESIGN.md §12; they stay in the tree as
  history until the final cleanup pass.
