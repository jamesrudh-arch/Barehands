# DESIGN SYSTEM — LEVERAGE

The single source of truth for UI colour, type and spacing. The HUD,
menus, phone and overlays are code-built against these tokens; new UI
must use them, not ad-hoc values.

## Colour tokens

| Token | Hex | Used for |
| --- | --- | --- |
| Background | `#05060F` | full-screen dims, menu scrims, card backgrounds |
| Panel | `#0E1226` | menu panels, phone cards, dialogue boxes (with ~0.82 alpha over the world) |
| Text | `#E8E8F4` | primary text, list rows |
| Muted | `#8A90B0` | secondary text, timestamps, footers |
| Magenta | `#FF007F` | club neon, danger accents, combo flare |
| Cyan | `#00F0FF` | interactive highlights, menu borders/hover, radar rings |
| Guide green | `#3DDC84` | the guide orb, route, destination markers, waypoints — green is guidance; never white-blown |
| Warning | `#FFB020` | durability warnings, heat notices |
| Danger | `#FF4D6D` | damage numbers, hostile state |
| Studio gold | `#C9A24B` | D'YOUNGS GAMES wordmark, studio ring, credits |

Warm sodium orange (`#FFB366` area light) belongs to street lighting,
not UI. Yellow is reserved for PICKUPS only — the objective system is
green end to end.

## Type scale

- Display (title/wordmark): 84–92 px, wide-tracked serif (studio) or
  heavy condensed (LEVERAGE wordmark).
- H1 (menu buttons): 22 px, all-caps, 74 px touch height.
- Body: 16–18 px.
- Caption/muted: 11–14 px — **11 px is the minimum readable size**;
  nothing ships below it.
- Subtitles: 18 px with a dark outline, speaker name in the speaker's
  faction colour.

## Layout rules

- **Landscape only.** Every control surface is designed for landscape
  and re-laid on window-size/safe-area change (one control set,
  never duplicated).
- **Eight-point spacing grid**: separations of 8 / 16 / 24; button
  gaps 18 px in the action cluster.
- **Safe-area padding**: the action cluster sits inside the display
  safe area with a 16 px margin; the whole cluster re-fits as one
  unit when the safe area changes.
- Touch targets: face buttons 96–108 px (never below 64), menu rows
  74 px tall, pause rows 54 px.
- No overlapping buttons, no duplicate labels, no decorative filler.

## The action cluster (right thumb)

The Xbox diamond: **Y** top (HEAVY), **X** left (PUNCH), **B** right
(DODGE / context verb — see MOVES.md for the one B rule), **A** bottom
(KICK). Secondary pills (GUARD, GRAB, SPRINT, JUMP, STYLE, LOCK,
PHONE, OBJECTIVE, HELP) ring the diamond in a 4-column grid, each
individually labelled. Left thumb: the floating joystick. The radar
lives top-left; cash/heat top-right; the combo counter and style rank
centre-top.

## Accessibility (Settings → implemented)

- Left-handed layout (the whole cluster mirrors).
- Button scale (0.6–1.6) and opacity per button (layout editor).
- Hold-to-block threshold (block_hold_ms).
- Reduced camera shake; reduced flashes (high-contrast mode).
- Subtitle size; colour-blind-safe marker palette on the radar.
- Skip intro at launch; guide on/off; guide chevrons on/off;
  route-line overlay on/off.
- The hero locator ring + rim light can be toggled (hero_locator).
