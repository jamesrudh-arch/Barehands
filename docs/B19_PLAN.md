# B19 — RESEARCH + AUDIT + PLAN (the full-game directive)

Owner directive: upload/Pasted Content_1795296041873.txt (25 parts).
This is the Part 2 research report and the Part 4/5 audit, then the
batch plan. Working name: batch B19 on top of B18.4 (3d250a9).

## 1. Godot 4.7 technical research (verified this session)

- **Decals on Mobile**: supported in Forward+ and Mobile only
  (not Compatibility); Mobile caps at **8 decals per mesh resource,
  64 per frame** (Godot docs "Decal"; antzGames/Godot-Compatibility-
  Decal-Node README states the same limits). DESIGN: scorch pool of
  8 recycled Decal nodes, never more.
- **Particles**: Mobile renderer supports GPUParticles (compute), but
  CPUParticles3D is the project standard (rain, steam, bursts already
  CPU) and is renderer-independent. DESIGN: all fire/smoke/rain layers
  stay CPUParticles3D, budgets per emitter (fire ~90, smoke ~40,
  embers ~24), Quality tier scales amounts.
- **Traffic/pedestrian navigation**: NavigationAgent3D needs a baked
  NavigationRegion3D per block; runtime baking headless is possible
  but heavyweight and hard to assert. The directive itself allows
  "a road graph or waypoint system" (Part 12). DESIGN: hand-authored
  lane graph (traffic) + pavement waypoint graph (pedestrians) -
  deterministic, testable, zero bake cost, Mobile-safe.
- **Emission cap**: Mobile R10G10B10A2 buffer clips >~1.1 (verified
  B18.3) - all new emissive materials capped (fire sprites are
  UNSHADED additive, not HDR).
- **Dynamic lights**: Mobile per-frame light budget is small; the
  project already runs Moon + ~8 practicals. DESIGN: fire adds AT
  MOST 2 flickering OmniLights (nearest 2 fires), everything else is
  emissive + glow quads.

## 2. Asset research (all CC0, mirror: series-ai/jam-ready-assets)

Already integrated (B18.4, in-repo): Kenney commercial buildings,
roads, pavement, sedan, lamps, construction props; Quaternius UBC
characters. NEW this batch (curated, not bulk):

| Kit | Files | Used for |
| --- | --- | --- |
| kenney-city-kit-industrial | industrial buildings, chimneys, tank | the foundry warehouse + dock dressing |
| kenney-car-kit | police, suv, hatchback-sports, van, truck, box | traffic pool + dock loading + containers |
| kenney-furniture-kit | beds, sofas, tables, stools, kitchen, bookcases, lamps, plants, cardboard boxes, trashcan | all five interiors |
| kenney-food-kit | skewers, coffee, pans, stew | the noodle shop |
| kenney-explosion-pack | grey/orange/red/yellow cloud sprites, burst | fire/smoke/dust particle textures |
| kenney-city-kit-suburban | 3 residential buildings | riverside background depth |

Rejected: kaykit-city-builder (second city kit, redundant - the
directive forbids asset sprawl), kenney factory-kit (empty of models),
Kenney animated characters (different rig - would break the UAL
animation lockstep the whole cast shares).

## 3. Placeholder audit (Part 5) - full scan results

Scanned: all 7 .tscn scenes + 140 scripts for BoxMesh/CapsuleMesh/
QuadMesh primitives, fallback materials, untextured models.

TO REPLACE (visible placeholder in the finished game):
1. Foundry warehouse: 26x10x12 flat box -> industrial kit building
   (MERIDIAN FREIGHT signs + door group preserved).
2. Foundry containers: plain boxes -> car-kit cargo box (textured)
   scaled to container volume + stencil labels.
3. Main-street alley: annex1/annex2/garage boxes -> kit buildings;
   crates -> furniture-kit cardboard boxes.
4. jobs.gd hostage: capsule -> real UBC character + tag.
5. trainer.gd figure: capsule+hat -> UBC character + code hat.
6. title_stage cast: capsules -> real cast models (fog silhouettes).
7. Hero body pieces: flat noir dress (textures never shipped) ->
   rebind to the shipped T_Ranger/T_Superhero textures.
8. Interior furniture (apartment/interior/backroom): code boxes ->
   furniture-kit models (batch 9).
9. Enemy fallback capsule: stays as IMPORT-RACE GUARD ONLY (never
   visible in a finished import; the final audit asserts 0 fallback
   figures at runtime).

INTENTIONAL (kept, with reasons): collision shapes (invisible),
glow/light quads (the noir light language), pipe/bat/bottle pickups
(correct shapes for their objects), AC units + ramp + parkour crates
(real objects / gameplay), rats+pigeons capsules (0.06-0.3 m ambient
creatures), glasses bridge on npc_rig, the training dummy mannequin
(owner directive: purposeful gameplay object).

## 4. Batch plan (directive Part 22 order, one commit per batch)

1. Assets + placeholder replacement (this doc's table).
2. World: warehouse dock, parking bay, alley, crossings, signage.
3. Player/controls verification + hero texture rebind test.
4. District: map<->geometry verification, routes, destinations.
5. Living city: pedestrian graph, behaviours, densities, reactions.
6. Traffic: lane graph, vehicle pool, crossings, audio, lights.
7. Weather: intensity states, wind, puddle ripples, audio follow.
8. Fire/smoke/steam + scorch decals + impact effects + fire barrel
   slam surface.
9. Interiors furnished (furniture + food kits).
10. Lighting de-blue pass (Part 15) + audio bus verification.
11. Final validation suite + full battery + docs + push.

Every batch: tests green (its smoke suite + battery), STATE.json +
CHANGELOG.md + README/CREDITS updated, commit, push.
