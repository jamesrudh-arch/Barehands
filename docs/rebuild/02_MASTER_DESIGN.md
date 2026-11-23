# 02 — LEVERAGE: MASTER DESIGN DOCUMENT (authoritative)

> The single source of truth for WHAT the game is. Harvested from the
> owner's stop-and-rebuild directive (2026-11-23), the V3 master prompt
> (`upload/Pasted Content_1795410039835.txt`), and PROJECT_BIBLE.md
> (v5.0 condensation — retained as history). Where they conflict, the
> NEWEST instruction wins; every reconciliation is marked **[R]** and
> logged in `04_DECISION_LOG.md`.

## 1. Identity

- **Title**: LEVERAGE. **Tagline**: "Everyone has leverage on you."
- **Studio card**: D'YOUNGS GAMES (one constant, `STUDIO_NAME`).
- **Genre**: connected third-person open-world crime-action drama.
  Compact and dense, not empty-vast: a believable city of six areas.
- **World**: Cinder City — rain-soaked, neon-noir, crime-ridden.
- **Tone**: gritty mature crime drama (The Warriors, Yakuza 0, Sifu,
  Better Call Saul). 16+: stylized violence, crime, strong language.
  No sexual content, no real brands, no real people, no cartoon
  good/evil meters.
- **Platform**: Godot 4.7 Mobile renderer, Xogot, iPhone (13 mini
  floor locked 30 / iPhone 16 hero 60), landscape, touch-first.
- **[R] Scope**: the bible's "one district, three blocks, no open
  world" boundary is superseded — the game is the connected
  six-area city below. Density and craft over acreage.

## 2. Pillars and loops

**Pillars**: (1) tactile, intelligent combat — read, bait, punish,
never mash; (2) coercion, blackmail, tactical setups — the phone as a
live pressure system, the Web of Leverage; (3) the reactive city — a
permanent record of escalation.

**Loops**: 2 min "one more fight" (Style Rank D→S, arena retry,
Death=Debt story fights); 30 min the Ledger puzzle (3 Beats/day —
Dusk, Midnight, 3 AM; calls/jobs/hangouts cost Beats); 20+ h story,
faction paths, consequences, NG+ Carried Debt.

**Ethical hard rules**: no energy timers, no pay-to-win, no loot
boxes, no daily rewards, no streak guilt. Engagement from discovery,
mastery, decisions, emergent situations.

## 3. The world: Cinder City, six areas (PART W)

Each area its own scene, lighting profile, fog, sky, music, ambience
and crowd; loaded one at a time with a <3 s fade (iPhone 13 mini);
only the current area + its edge in memory.

1. **THE WAREHOUSE** (home, hideout): ~20×15 m converted warehouse —
   bed (corner loft), workbench, phone table, fridge, lamp, weapon
   rack (pipe, bat, bottles), TRAINING CORNER (punching bag, sparring
   dummy, mirror), locked big roller door, side door → private YARD
   (~15×10 m: fence, bins, crates, gate, rain, flickering lamp).
   Warm practical light. No road/traffic/crowd here. The only private
   place.
2. **THE NEIGHBOURHOOD** (Block 1, via yard gate + alley): ≥6 street
   segments, side streets, two alleys, a small plaza, ≥12 distinct
   buildings; the noodle shop, THE RAIN GLASS bar, barber, pawn shop,
   convenience store, laundromat, clinic (Death=Debt), subway
   entrance, bus stop, newsstand, vending machines.
3. **THE CLUB DISTRICT** (Block 2, via main street): main avenue, two
   side streets, THE VELVET ROOM club with a queue, IRON PALM GYM,
   the Mechanic's garage, hotel lobby, parking structure, parkour
   rooftops; densest crowds and traffic, the crossing.
4. **THE DOCKS** (Block 3, via the underpass): piers, cranes,
   container maze, a ship, fish market, **DOCK WAREHOUSE 9** (story;
   locked until the kidnap arc), the empty lot, fog and water.
5. **THE AIRPORT** (taxi from the Club District, fare + travelling
   cutscene): terminal exterior + interior (check-in hall,
   departures board, security gate, shops), tarmac, runway, a
   PARKED PLANE you can board.
6. **THE SECOND CITY** (by plane, flight cutscene): a small separate
   hub — plaza, a few streets, a bar, a mission giver; its own look
   and music; return by plane.

**Between areas**: visible, signposted gates/doors/underpass (never
hidden), or TRAVEL (taxi stand/menu, plane). Area label on arrival.
**World map** (phone + pause menu) shows all areas and connections;
unlocked areas fast-travel by taxi for a fare; adjacent areas walk.
**[R]** The bible's "no fast travel" yields to taxi fast-travel
(PART W is newer and specific). Minimap shows the current area only.
The save remembers area + position.

**Interiors** (≥9, enterable, furnished, lit, each through a real
door): warehouse, noodle shop, bar, club, gym, garage, pawn shop,
clinic, hotel lobby.

## 4. Story

- **Protagonist**: a lean fighter, short hair, a scar through one
  brow, rolled sleeves, taped hands, dark jacket. The most dangerous
  fighter on the block and the poorest; power and debt grow together.
- **Spine**: the brother who taught him to fight; the DEBT (starts
  $5,000) owed across three factions; the KIDNAPPING of the
  lowest-trust friend (ties to highest Heat); the INVESTIGATION (Web
  of Leverage); the CONSEQUENCES of every choice.
- **Intro narration** (V3 PART 13, the opening voice-over): "Cinder
  City never sleeps. It just owes. / Everyone here has a number next
  to their name. / Mine is bigger than most. / I came up with my fists
  and a brother who taught me how to use them. / Now the phone buzzes,
  and every ring is someone's hand on my collar. / You can answer one
  call. You can't answer them all. / So tonight, let's see who owns
  you."
- **Kidnap arc** (Act 3): Cold Call → Investigation (no combat) →
  Assault (arena, waves, mini-boss) → CHOICE: save them (lose the
  money, permanent enemy, Close forever) or take the payoff (lose the
  friend, faction patron, the city hollows). Both endings real.
- **Both paths**: story fights are Death = Debt (no reload: wake owing
  whoever patched you up; default = city-wide manhunt).

## 5. Characters

- **Friends (Trust 0–100, start 70)**: the **Brother** (family,
  Brawler teacher, first caller), the **Mechanic** (garage, power-cut
  setups), the **Club Owner** (laundering, brawl-staging), the **Old
  Drunk** (Drunken style, best dialogue, lures cops). Close ≥60 helps
  in a fight once; Drifting 30–59 hesitates; Estranged <30 stops
  calling. One hangout each: fishing, basketball, darts, karaoke (one
  timing skeleton, reskinned). -6 per Beat of unanswered calls, +15
  hangout, +10 clean setup, -10 setups that hurt them.
- **Style teachers**: Brother (Brawler), the Bouncer (Kickboxing),
  the Collector (Grappling), the Old Drunk (Drunken), the
  Lieutenant (Weapon).
- **Faction bosses**: the Family boss (old, warm, takes a cut), the
  Corporation executive (new, cold, owns guns and tech), the Crew
  leader (yours, fragile, loyal).
- **Others**: the noodle-shop owner, the Coach (IRON PALM GYM), named
  gang lieutenants, collectors. Each named character: one-line bio,
  voice settings, a signature line, a distinct silhouette and face.
- **Population**: distinct pedestrians with routines, conversations,
  reactions; ≥40 distinct looks from a parametric generator with
  palette rules; name tags only when close or locked on.

## 6. Factions and borrowing power

- **The Family**: backup muscle, takes a cut, no guns in their sight.
  Interest 3%/day.
- **The Corporation**: tech — pistol/shock-gauntlet mid-fight, remote
  kill-switch on missed payments. Interest 8%/day.
- **The Crew**: free help, but they get hurt. Interest 0%.
- Every borrowed bullet ticks a live Debt counter; 3 missed payments =
  default; heavy debt = scarred style (their moves added, some of
  yours removed); collectors appear INSIDE fights.

## 7. Combat

**Five disciplines, learned from people, never lost — each must PLAY
differently** (distinct stance, movement, strings, defence, counters):
Brawler (boxer's guard, bob and weave), Kickboxing (bladed stance,
hands high, light bounce), Grappling (low, wide, reaching — throws and
control), Drunken (swaying, loose — evasion and counters), Weapon
(pipe/bat/bottle + the firearm path).

- **Buttons**: X PUNCH, Y HEAVY (hold to charge), A KICK, B DODGE.
  Combos: X X X, X X Y, X A, A Y, hold Y, perfect-dodge B→X, posture-
  break finisher. Styles change the moves behind the same letters.
- **Depth**: attack tokens (2–3 enemies at once), enemy posture
  mirrors player Composure, adaptive AI counters spam (last-3-moves),
  soft style-countering bonus, dirty street tactics (one per style;
  grab snaps to walls/signs/car doors ≤2 m), defensive play as
  rewarding as aggressive, lingering injuries until treated,
  adaptive difficulty through debt (never quiet enemy weakening).
- **Feel**: hitstop 3–4 f light / 8–10 f heavy — SELECTIVE (attacker
  + target only, never global time_scale), cancel window 150–350 ms
  (lights), buffer ~200 ms, parry ~300 ms, dodge ~120 ms.
- **Weapons**: improvised (pipe, bat, bottle, plank, chair leg —
  durability, break effects, [B] PICK UP) and firearms (the
  Corporation pistol: aiming, shooting, reload, switching; every
  bullet ticks debt). Weapon style owns the armed moveset.
- **Enemies**: thug 40 HP, guard 70, heavy 160, gunman 50 (later
  waves), boxer archetype; readable tells, clear health, distinct
  silhouettes.
- **Balance defaults**: player HP 100 / Composure 100, light 6 / heavy
  16 dmg, parry posture 30, posture bar 100. Jobs pay 400–1500 dirty;
  S-rank cuts debt 5% of principal; Death debt 800.

## 8. Vehicles

At least eight types — sedan, taxi, police car (working light bar +
siren), SUV, van, bus, pickup, delivery truck, plus a sports car.
Proper models (body, glass, mirrors, lights, wheels with rims),
entry/exit animations, driving (acceleration, braking, steering,
handbrake, horn), suspension feel, camera behaviour, engine audio,
damage, persistence. **Traffic AI**: road navigation, signals,
collision reactions, pedestrian avoidance, city traffic events.
**[R] New for the rebuild** — the old game had no real driving.

## 9. Missions (the spine)

Data-driven missions as resources: id, title, giver, briefing, stages
(objective text, marker, completion/failure conditions, optional
enemies/timers), rewards, consequences (world state, trust, heat,
faction standing, debt), next missions. Five templates reskinned:
Delivery, Rescue, Coerced, Hit, Turf.

**UI**: tracker top-left under the radar (title, step, distance);
mission board + journal in the phone; start markers by giver colour;
briefing screens (giver's face, 2–4 lines, objective); stage toasts;
MISSION PASSED (rewards, consequences, style rank) and MISSION FAILED
(retry checkpoint or Death=Debt) screens.

**Flow**: starts from phone calls (calls interrupt fights), givers in
the world, or street events. Every mission: green-guide route, a
clear goal, ≥2 approaches (fight, sneak, talk, break in, blackmail).

**First missions** (built first): M0 WAKE-UP CALL (tutorial: the
Brother calls, train on bag/dummy, meet at the bar, leave via yard);
M1 THE COLLECTION (deliver to THE VELVET ROOM; alley ambush; the club
front door LOCKED — break in and fight bouncers, back door, or
bribe); M2 FIRST BLOOD (gym fight, teaches Kickboxing); M3 THE OLD
DRUNK (bar side mission, Drunken hint); M4 SHAKEDOWN (shop owner:
talk, threaten or break the door — choices change the district); M5
TURF (defend the noodle shop in waves); M6 THE CALL (Corporation
pistol offer: accept = power + debt, decline = escalation). Then the
ten core jobs and the kidnap arc.

**Consequences**: every outcome updates the world-state table —
shops, crowds, prices, doors (broken/repaired), who calls, which
missions open. Missions save per stage.

## 10. Systems

- **The phone** (hub): Calls, Texts, Map, Ledger, Contacts, Notes,
  Settings apps. Calls interrupt fights (answer in seconds while
  enemies swing); Demand vs Invitation; one answer per ring;
  declining has costs; Leverage Clips (blackmail), countdown texts,
  replayable voicemails, Last Call (once per act). The buzz = the
  tension sound. Opening the phone dims and slows the world.
- **Economy**: dirty vs clean cash; laundering via the Club Owner
  (20% cut, trust-gated); back-room hi-lo with sleight-of-hand;
  DEATH = DEBT. Starting debt $5,000. Shops: noodles (heal), clothing
  stall, street vendor; outfits (visual).
- **Heat + police**: tiers with named responses (fixers, then
  style-copying hitmen); crowds are witnesses, alleys are not.
- **Web of Leverage**: investigation board (apartment/encrypted app);
  clues from interrogations, tailing, cloning, bugs, bartender
  rumours; two linked dirt pieces unlock Extortion Dialogue; clues go
  stale.
- **World state**: ONE shared table + an EVENT QUEUE; data-driven NPC
  schedules; persistent consequences (decals, scorch, boarded shops,
  memorials, thinning crowds, price rises, radio recap, gossip that
  distorts over Beats). No whole-city simulation.
- **World sim**: day/night cycle + weather (rain frequent, the
  signature), lighting, wet surfaces, puddles, steam, fire, particles,
  environmental audio; traffic events, police activity, radio
  reports. **[R]** The bible's "always night always rain" becomes
  "the noir night is the signature look inside a full day/night and
  weather cycle".

## 11. Controls (the one input map — see 06_CONTROL_MAP.md)

Left thumb: floating MOVE stick (auto-sprint at full push). Second
camera control: LOOK stick above the right diamond (setting: edge
drag instead). Independent and simultaneous; camera never
auto-rotates while walking (optional assist). Right thumb: the X/Y/A/B
diamond (letters big, action names small). Pills: GUARD (hold block,
tap parry), GRAB, SPRINT, JUMP/VAULT; STYLE hold-and-flick wheel;
LOCK near the top of the right zone; PHONE top-right. B = context
action out of combat (OPEN/PICK UP/TALK/ENTER; combat priority keeps
B = DODGE in fights). Driving: steer/accelerate/brake/handbrake/horn;
weapons: aim/shoot/reload/switch. On-screen controls match the input
map exactly; multi-touch throughout; left-handed mirror; sizes and
opacity in Settings.

## 12. UI / design system (summary — full in DESIGN docs)

Ink #05060F, panel #0E1226, text #E8E8F4, muted #8A90B0, magenta
#FF007F, cyan #00F0FF, guide green #3DDC84, amber #FFB020, danger
#FF4D6D, studio gold #C9A24B. SystemFont scale, nothing below 11 pt;
48 pt touch targets (fight buttons ≥64 pt); landscape HUD: radar
top-left (rotating with camera, N marker, route line, blips),
objective + district top-left, compass top-centre, style/health/heat/
money top-right, subtitles bottom-centre; full map (pan/pinch/waypoint,
layers, fog of war per block); the green guide orb + destination
outlines; consistent drawn icons; haptic language; localisation-ready
strings; accessibility (left-hand mirror, sizes, hold-to-block,
reduced shake, colour-blind modes, Bluetooth controller map).

## 13. Audio

Buses: Master (compressor+limiter), Music, Ambience, SFX, Voice, UI —
sliders saved, volumes start low. Adaptive music (title, menu,
exploration, tension, combat layers, phone buzz, stingers), ambience
(rain, traffic, neon hum, sirens, crowds, room tone), layered impacts
(whoosh/cloth/impact/bone/voice/tail, pitch variation), TTS narrator +
phone voices with subtitles always, radio-voice babble fallback.
Spatial audio for signs, vehicles, footsteps, doors.

## 14. Onboarding: the first ten minutes (skippable)

Title → PLAY → warehouse (night, rain, one lamp, the phone buzzes;
the Brother calls — accept/decline both lead on; narrator: "Find the
door. Follow the green light.") → green guide to the door → [B] OPEN
→ pipe pickup → yard → alley → street → noodle shop (owner speaks;
buy noodles with the starting $150) → street life (pedestrians,
traffic, the thug on the wall) → training (bag, dummy, Brother: X, Y,
A, B, X X Y, guard/parry) → first fight (two thugs, token-limited,
first Style Rank) → first faction demand (accept/decline) → the hook
text ("We know where you live.") + marker to the bar. Every step
advances on its condition, can be skipped, never blocks.

## 15. Performance and platform rules

iPhone 16 60 fps / iPhone 13 mini stable 30; draw calls 400/250;
2–3 dynamic lights max, blob or cheap shadows, ETC2/ASTC, LOD/HLOD,
culling, pooled decals/particles/pedestrians, no per-frame
allocations; quality presets HIGH/BALANCED/BATTERY SAVER + automatic
downgrade on sustained over-budget or heat; shader pre-warm in the
loading card; app lifecycle (pause/resume/autosave); keep the project
within Xogot's size guidance (~200 MB).

## 16. Start sequence and presentation

BLACK → D'YOUNGS GAMES studio card (gold ring draws, DY monogram,
serif wordmark, light sweep, swell + chime) → content notice (MATURE
16+) → the LEVERAGE title card (night skyline, chromatic-split
wordmark, rain, tagline) — which is the real-time 3D KEY ART screen:
extruded 3D LEVERAGE logo (chrome, neon edges, chain-link motif,
rising from wet ground with reflection), the cast in layers (back:
faction bosses; middle: Brother, Bouncer, Collector, Drunk,
Lieutenant, Mechanic, Club Owner; front right: the hero in fighting
stance, face lit), magenta/cyan rim lights, slow camera drift →
loading (progress, tip, stamp) → main menu over the drifting neon
street: PLAY, CONTINUE, SETTINGS, CREDITS. Skippable cards, plays
once per launch, "Skip intro" setting.

## 17. Scope tiers (build order discipline)

CORE (the complete loop: all six areas, one mission chain M0–M6,
combat with all five styles, vehicles + traffic, phone/ledger/trust/
heat, save/load, full start sequence, HUD/map/guide, audio complete)
→ FULL (tournaments, hangouts, collectibles, outfits, radio, street
events, reputation titles, photo mode, achievements) → STRETCH
(vendettas, extended calls, NG+). Never cut a tier silently; record
what remains.
