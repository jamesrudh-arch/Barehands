# 05 — ASSET REGISTER (source of truth for every imported asset)

> Every asset USED by the rebuilt game: what it is, where it came
> from, its licence, and where it lives. Assets are only "registered"
> when they are on disk; they are only "implemented" when a scene
> instantiates them (the IMPLEMENTED column moves when the pipeline
> proof lands). Licences are kept next to the files AND summarised
> here. All sources are CC0 (commercial-safe, no attribution
> required — credited anyway).

## Delivery source

`series-ai/jam-ready-assets` (GitHub) — a curated CC0 asset mirror
serving binaries via the LFS media CDN. Fetched by
`scripts/fetch_rebuild_assets.py`. Licence text on the mirror is
SPDX-tagged (`SPDX-License-Identifier: CC0-1.0`) with the creator's
source URL recorded.

## Batch 1 — the character animation pipeline (LANDED 2026-11-23)

`assets/v2/kaykit_character_animations/` — **CC0, Kay Lousberg**
(kaylousberg.com). KayKit Character Animations, Rig_Medium + Rig_Large:
- `Rig_Medium_CombatMelee.glb` (975 KB) — the melee fight set
- `Rig_Medium_CombatRanged.glb`, `_General.glb`, `_MovementBasic.glb`,
  `_MovementAdvanced.glb`, `_Simulation.glb`, `_Special.glb`,
  `_Tools.glb`
- `Rig_Large_CombatMelee.glb`, `_General.glb`, `_MovementBasic.glb`
- `License.txt` (SPDX CC0-1.0, creator licence text included)

`assets/v2/kaykit_adventurers/` — **CC0, Kay Lousberg**. 9 rigged
stylized characters with faces (share the KayKit rigs, so the
animation GLBs above drive them):
- Barbarian, Barbarian_Large, Druid, Engineer, Knight, Mage, Ranger,
  Rogue, Rogue_Hooded (`.glb`, 333–670 KB each)
- `License.txt` (SPDX CC0-1.0)

`assets/v2/quaternius_ual/` — **CC0, Quaternius** (quaternius.com).
- `UAL1_Standard.glb` (7.4 MB) — the Universal Animation Library rig
  + full animation set (in-place variant; the repo also holds the
  original zip with the root-motion `_RM` variant)
- `License.txt` (CC0 1.0)

**Status: downloaded + licence-verified; NOT yet imported/used.**
Next: the D3 proof (import → retarget → AnimationTree → native
resource commit → render check), then implemented status.

## Batch 2 — city and vehicles (PLANNED, same mirror)

- `kenney-city-kit-commercial|industrial|suburban` FULL GLB sets (the
  on-disk `assets/kits/` copies are curated subsets: 20 buildings)
- `kenney-modular-buildings`, `kenney-building-kit` (facades with
  depth), `kenney-retro-urban-kit` (neon signage style)
- `kenney-car-kit` FULL set (sedan/taxi/police/van/truck/bus…) — the
  on-disk copy has only 6; the design wants ≥9 vehicle types
- `kaykit-city-builder` (KayKit buildings, furniture-adjacent style)
- All CC0 (Kenney / Kay Lousberg); licences land with the batch.

## Batch 3 — crowd variety + props (PLANNED, same mirror)

- `run-*` stylised character packs (Heist Crew, Time Travellers,
  Farmhands… several rigged animated humanoids each, CC0) — the
  parametric crowd's base bodies
- `kenney-animated-characters-bundle` (blocky but animated — extras)
- `quaternius-ultimate-guns` + `kenney-weapon-pack` + melee props
  (bottles/bats from furniture/food kits already on disk)

## Already on disk (from the old implementation — re-verified CC0)

`assets/kits/kenney_*` (9 kits, 107 GLBs, Kenney CC0),
`assets/audio/*` (mastered bank: Kenney CC0 + project synth,
`KENNEY_AUDIO_LICENSE.txt` + `SYNTH_LICENSE.txt`),
`assets/fx/*` (particle sprites). These carry over into the rebuild
under the same licences; see 01_ASSESSMENT.md §6.

## Rejected / blocked sources (recorded honestly)

- Quaternius "Ultimate Animated Character Pack" (52 rigged gltf on
  Google Drive): **Drive quota-blocked** at fetch time (2026-11-23).
  The pack page (quaternius.com/packs/ultimatedanimatedcharacter.html)
  and folder were reachable; download links saved in
  /tmp/research (ephemeral). Retry later if KayKit characters prove
  insufficient — KayKit + UAL cover the pipeline meanwhile.
- archive.org, poly.pizza, itch.io, kenney.nl direct: unreachable or
  blocked from this sandbox (recorded 2026-11-23); the GitHub mirror
  serves the same CC0 content.
