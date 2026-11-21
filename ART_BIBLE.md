# ART_BIBLE.md — LEVERAGE: the one cohesive look (B18.3)

The goal (BUG 16): a strong, cohesive, premium STYLIZED neon-noir look
on the Mobile renderer. Not photorealism. Plain boxes, flat black
areas and blown-out white shapes are BUGS.

## The palette

| Role | Colour | Where |
| --- | --- | --- |
| Shadows (the base) | deep blue-black `#05070C` | asphalt, night sky, clear colour |
| Mid-tones | cool greys `#1A1E28`..`#2E3440` | facades, sidewalks, car paint |
| Accent A | magenta `#FF2ABF` | neon signs, the title split |
| Accent B | cyan `#2EF2E5` | neon signs, radar, the guide alt |
| Practical lights | warm sodium orange `#FFB35C` | lamps, window spills, headlights |
| Danger / blood | red `#E03A2E` | enemy rims, boss tint, taillights |
| Guide | green `#40FF80` | the orb, the route, the destination |
| Gold (brand) | `#C9A24B` / `#E8D9A8` | D'YOUNGS GAMES card, UI accents |

Rule: accents are SMALL and COLOURED, never large and white. The
darkest areas still show shape; mid-tones carry the scene.

## Light rules (the Mobile renderer reality)

- Every 3D scene has a WorldEnvironment with an Environment resource:
  tonemap ACES, white 4.0, ambient `#2A3344` at the SAFE brightness,
  glow ON at threshold 1.02 / intensity 0.38.
- The Mobile renderer's R10G10B10A2 colour buffer clips emission
  above ~1.1 to flat white (verified against the internal rendering
  architecture docs). EVERY emissive material is capped at 1.1; sign
  flicker caps at 1.15; the apartment door breathes 0.88..1.12.
  Nothing animates emission above the cap - that was BUG 11.
- Characters are never fully dark: the camera carries a soft fill
  light (energy 0.32, range 16), the hero has the locator ring + rim
  light, enemies have per-kind emissive edges, the fallback figure is
  a LIT red capsule, vehicles carry their own lamps.
- Practical lights read as GLOW QUADS (the ShaftShader additive
  spill), not just bare emissive slabs.

## Material rules

- Stylized low-poly with clean materials: albedo carries the colour,
  roughness 0.3..0.8, metallic only for the car paint, pipe, shutters.
- Wet streets: the road shader stretches reflections toward the
  camera; puddle quads mirror the neon.
- Signs: a dark frame + lettering strip + darker body around the
  emissive face so they read as SIGNS, not rectangles.
- Characters: distinct silhouette + tint per faction (enemy LOOK
  table), emissive edge 0.06..0.10 (boss 0.10 red), name tags above
  heads at distance.
- Pickups glow by class: white weapons, yellow cash, green health,
  blue keys - and bob so they never read as static debris.

## UI rules

One HUD style: crisp SystemFont stacks, safe-area anchored, single
labels, the gold/cyan accents, no doubled text, minimum 64 px touch
targets, the radar top-left, the guide always green.

## Quality presets

`Quality` autoload: Auto (default) samples the frame rate and picks
HIGH or LOW (the auto-downgrade the logs show as "quality: tier Low");
override from Settings. HIGH: full moths (40), all creatures (6),
glow on. LOW (iPhone 13 mini class): 20 insects, 3 creatures, the
same materials (the cap keeps the frame budget without changing the
look). The frame budget: 60 fps iPhone 16, stable 30 fps 13 mini
(PHONE-ONLY - the sandbox renderer cannot measure device fps).

## CC0 assets (integrated in B18.4)

The street wears real CC0 models now: Kenney City Kit Commercial /
Roads / Starter buildings and the Car Kit sedan (assets/kits/, licences
in assets/kits/LICENSE-Kenney-CC0.txt and CREDITS.md) replace the
placeholder boxes - buildings onto their plots, kit pavement on the
sidewalks, marked road lanes as one MultiMesh per street, lamp posts
with warm sodium light at the curb, roadworks props, and the parked
sedan carrying the noir light boxes. The four fighting enemy kinds wear
Quaternius Universal Base Characters (assets/cast/) driven by the UAL
clip library; the training dummy keeps its mannequin. Every placement
degrades to the code-built box when a kit is not imported yet
(scripts/kit.gd), so a fresh import never aborts the street. What
stayed code-built on purpose: the warehouse and dock containers (honest
industrial volumes, story-wired), the wet asphalt base (the reflection
shader surface), neon signs and lit windows.

## LookDev

`scenes/lookdev.tscn` (debug menu -> LOOKDEV): the cast, the car, a
sign, a door and every pickup under the final lighting, in one strip
- where asset quality is judged quickly.
