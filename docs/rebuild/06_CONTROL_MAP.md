# 06 — CONTROL MAP (the one input map)

> The single authoritative input table. The touch UI is GENERATED
> from it: button letters, labels and actions can never disagree.
> Controller bindings map the same actions. Landscape layout,
> iPhone safe areas, multi-touch throughout, left-handed mirror in
> Settings. Context rules resolve conflicts (combat priority).

## On-foot actions

| Action | InputMap key | Touch | Controller (Xbox) | Notes |
| --- | --- | --- | --- | --- |
| Move | `move` | floating MOVE stick, bottom-left | left stick | camera-relative; full push = auto-sprint |
| Camera | `look` | LOOK stick above the diamond (setting: right-edge drag zone) | right stick | independent of move; never auto-rotates (optional assist) |
| Punch (light) | `punch` | **X** (diamond) | X | jab/cross/hook string |
| Heavy | `heavy` | **Y** (diamond) | Y | hold to charge; light→heavy finisher |
| Kick | `kick` | **A** (diamond) | A | front kick / roundhouse / knee |
| Dodge / Context | `dodge` | **B** (diamond) | B | dodge in combat; OPEN / PICK UP / TALK / ENTER out of combat (combat priority: an alert enemy within ~6 m keeps B = DODGE) |
| Guard / Parry | `guard` | GUARD pill above diamond | RB | hold to block, tap to parry |
| Grab / Throw | `grab` | GRAB pill | LB | grabs; snaps to walls/signs/car doors ≤2 m |
| Sprint | `sprint` | SPRINT pill | L3 | (auto at full stick too) |
| Jump / Vault | `jump` | JUMP pill, left of diamond | A→(swap: LB) | vaults low cover |
| Lock-on | `lock` | LOCK pill, top of right zone | RS click | frames target; releases off |
| Style wheel | `style` | STYLE (hold-flick) | D-pad | world slows ~30% while held |
| Leverage Strike | `super` | SUPER appears only at full meter | both sticks click | hold Heavy, release at full |
| Phone | `phone` | PHONE icon, top-right | D-up | dims/slows the world |
| Pause | `pause` | PAUSE, top edge | Menu | |

## Combat-context rules (documented in MOVES + tutorial)

1. B is DODGE whenever an alert enemy is within ~6 m or the combat
   timer runs — never opens a door by mistake.
2. Out of combat, B becomes the nearest context action; the prompt
   shows at the object AND on the button ("B: OPEN", "B: PICK UP
   PIPE", "B: TALK", "B: ENTER").
3. Tap = short actions (open, pick up); hold = long actions with the
   progress ring (search, lockpick, break-down).
4. Combos: X X X, X X Y, X A, A Y, hold-Y, perfect-dodge B→X,
   posture-break finisher. The letters stay constant; the five
   styles change the moves behind them.

## Armed actions (Weapon style and firearms)

| Action | InputMap key | Touch | Controller |
| --- | --- | --- | --- |
| Attack with weapon | `punch` / `heavy` | X / Y | X / Y |
| Aim | `aim` | AIM toggle pill (weapon-equipped only) | LT |
| Shoot | `shoot` | FIRE (appears while aiming) | RT |
| Reload | `reload` | RELOAD pill | RB→(reload) |
| Swap / Drop weapon | `swap_weapon` | weapon badge long-press / pause menu | Y long |

## Driving

| Action | InputMap key | Touch | Controller |
| --- | --- | --- | --- |
| Enter / exit vehicle | `interact` (B context) | B at the car ("B: ENTER") | Y |
| Steer | `steer` | MOVE stick (left/right) | left stick |
| Accelerate / Brake | `accelerate` / `brake` | right-side pedal pills (GAS / BRAKE) | RT / LT |
| Handbrake | `handbrake` | HANDBRAKE pill | A |
| Horn | `horn` | HORN pill | D-right |
| Camera | `look` | LOOK stick | right stick |

## UI

Radar tap → full map. Map: one finger pan, pinch zoom, tap to place
waypoint, tap pin to clear, recentre button, legend/layers. Phone:
tap apps, one answer per call ring. Menus: large touch targets, B =
back. GUIDE button recalls the green orb. MOVES screen lists every
combo from the pause menu.

## Layout (landscape, safe-area)

- bottom-left: MOVE ring
- bottom-right: X/Y/A/B diamond (X left, Y top, A bottom, B right —
  the Xbox arrangement), pills row above it (GUARD, GRAB, SPRINT),
  JUMP left of the diamond, LOCK above, weapon badge beside
- top-left: radar + district + objective; top-centre: compass arrow;
  top-right: style, health, composure, heat, money, phone, pause,
  build stamp
- subtitles bottom-centre above the buttons; input display (last
  inputs, e.g. "X X Y") just above the diamond while fighting
- nothing overlaps; every control ≥48 pt (fight buttons ≥64 pt);
  all inside the safe area; sizes/opacity/mirror in Settings.
