# PROJECT_BIBLE.md — LEVERAGE (condensed from the owner's master prompt v5.0)

> **STATUS: v5.0 ARRIVED (2026-11-19).** The master prompt is now the
> complete single-prompt build command (v5.0, in
> `upload/Pasted Content_1795078874226.txt`; v4.0 kept alongside). Same
> design, plus the session protocol below. This is the working condensation
> every session re-reads first. Where the repo and the bible disagree, the
> bible wins for FUTURE work; existing shipped systems are mapped in
> STATE.json, not silently rewritten.

> **v5.0 additions (binding):**
> - **PRIORITY ZERO before any new feature**: (1) the distant T-pose fixed
>   for real with a logged diagnostic + regression test [DONE, b47a29d];
>   (2) full battery from clean isolated user dirs, never kill a suite,
>   every suite sets first_run_done [DONE this batch]; (3) Batch 0
>   completed where missing (Tuning + panel, in-game TestRunner, CI,
>   Haptics, SfxSynth, save, overlays, debug jumps) [DONE this batch,
>   Tuning wiring to scripts staged]; (4) STATE.json updated and pushed.
> - **Session protocol**: commit and push after every completed sub-step;
>   keep STATE.json current with the exact NEXT STEP; at session start
>   read this bible + STATE.json, run --import, quick smoke, resume.
>   Run batteries in chunks with a time budget; critical suites first,
>   full battery at batch boundaries. Never claim a fix that is not
>   verified by a test.
> - **Definition of complete**: CORE tier of every system done and tested,
>   then FULL, then STRETCH as time allows; the full loop end to end
>   (fight, phone, ledger, Death=Debt, friends/trust, a job, the kidnap
>   arc, both endings); budgets met on both phones; the final report
>   lists per-batch completion, tiers, ONE combined test checklist, known
>   issues, the three recommended first fixes, and the animation/audio
>   slots most needing real assets.

## Identity
- **LEVERAGE** — compact, high-density neon-noir tactical action-drama in ONE
  3-block district. Working title during Series 1-2 was "Bare Hands 3D".
- LOGLINE: "Everyone has leverage on you." The most dangerous fighter on the
  block and the poorest; power and debt grow together.
- Tone: gritty mature crime drama (The Warriors, Yakuza 0, Sifu, Better Call
  Saul). 16+. No cartoon good-vs-evil meters.
- Scope boundary (non-negotiable): 1 district, 3 interconnected blocks,
  5 enterable interiors, 16 named persistent NPCs + 25 crowd NPCs, 10 core
  jobs, 4 friends, 3 factions, 5 martial styles. No seamless open world, no
  companion AI, no XP grinding, no second city.
- Engine rules: Godot 4.7 MOBILE renderer, landscape, touch-first, iPhone 13
  mini is the floor (locked 30), iPhone 16 the hero (60).

## The three pillars
1. **Tactile, intelligent combat** — read, bait, punish. Never button-mashing.
2. **Coercion, blackmail, tactical setups** — the phone as a live pressure
   system; the Web of Leverage; open-ended operations (Recon / Setup /
   Execution).
3. **The reactive 3-block ecosystem** — the city is a permanent record of
   escalation.

## The three loops
- **2 min** — "one more fight": Style Rank D→S (variety, no damage taken,
  environment use, clean counters); S-rank pays down debt; instant arena
  retry (10 s) for optional fights; story fights are Death = Debt; replay
  clip of the best 10 s combo.
- **30 min** — the Ledger puzzle: 3 Beats/day (Dusk, Midnight, 3 AM); every
  call/job/hangout spends a Beat; pay/ignore/fight decisions; paying one
  faction early raises another's interest; skipping friends lowers trust.
- **20+ h** — story and replay: unscripted kidnap target, faction paths,
  New Game+ Carried Debt, hidden calls and secret scenes.

## Ethical hard rules
No energy timers, no pay-to-win, no loot boxes, no daily rewards, no streak
guilt. Leaderboards friends-only and optional. Engagement from discovery,
mastery, decisions, emergent situations — never grinding.

## Combat (4A)
Five styles, learned from people, never lost: Brawler (Brother), Kickboxing
(Bouncer), Grappling (Collector), Drunken (The Drunk), Weapon (Lieutenant).
Style countering is a SOFT bonus. Attack tokens: max 2-3 enemies at once.
Posture break on enemies mirrors Composure on the player. Adaptive AI tracks
last-3-moves and counters spam. Dirty Street Tactics: one per style; grab
snaps to walls/signs/car doors within 2 m. Defensive play as rewarding as
aggressive. Lingering injuries persist until treated. Adaptive difficulty
through debt, never quiet enemy weakening. Skill over damage numbers.
Feel targets: light hitstop 3-4 f, heavy 8-10 f, cancel window 150-350 ms
(lights only), parry generous with the right style, input leniency everywhere
(buffer ~200 ms, parry ~300 ms, dodge ~120 ms).
**Tech rule: SELECTIVE hitstop (pause attacker+target only) — never global
Engine.time_scale.** (The current repo uses global time_scale; migrating to
selective hitstop is on the Stage B/C list.)

## Borrowing power (4B)
Mid-fight lender gear: Corporation pistol/shock-gauntlet; every bullet ticks
a live Debt counter. Lenders: The Family (backup, but a cut + no guns in
their sight), The Corporation (tech, remote kill-switch on missed payments),
The Crew (free help, but they get hurt). Interest ticks real time;
collectors appear INSIDE fights. Heavy debt = scarred style (their moves
added, some of yours removed).

## The phone (4C)
Calls interrupt fights (answer in seconds while enemies swing). Demand vs
Invitation; one answer per ring; declining has costs. Leverage Clips
(photo/clip blackmail), countdown texts, replayable voicemails, Last Call
(once per act). The buzz is a low slow pulse — the tension sound. Opening
the phone dims and slows the world.

## Trust (4D)
Friends 0-100, start 70. -6 per Beat of unanswered calls, +15 hangout,
+10 clean setup, -10 setup that hurts them. Close ≥60 (helps in a fight
once), Drifting 30-59 (hesitates), Estranged <30 (stops calling). Act 3
kidnap target = lowest Trust, ties to highest Heat. The Ledger always shows
Trust so outcomes are earned and visible.
Friends: Brother (Brawler, family), Mechanic (garage, power-cut setup),
Club Owner (laundering, brawl-staging), The Drunk (Drunken style, lures
cops). One hangout each (Fishing/Basketball/Darts/Karaoke — same timing
minigame skeleton, instanced).

## Web of Leverage (4E)
Investigation board (apartment wall or encrypted app): clues from
interrogating stunned enemies, tailing, phone cloning, bugs, bartender
rumors. Two linked dirt pieces unlock Extortion Dialogue. Clues go stale.

## Missions (4F)
Recon / Friend Setup / Execution. Clean Hands vs Wrecking Ball (every job
beatable zero-kill). Job templates: Delivery, Rescue, Coerced, Hit, Turf —
10 core jobs. Friend setups raise their Heat; overuse gets their business
hit.

## Economy (4G)
Dirty vs Clean cash. Laundering through the Club Owner (20% cut),
back-room gambling with sleight-of-hand. DEATH = DEBT: no reload; wake up
owing whoever patched you up; default = city-wide manhunt.

## Kidnap arc (4H)
Cold Call → Investigation (no combat) → Assault (arena, waves, mini-boss) →
Choice: save them (lose the money, permanent enemy, Close forever) or take
the payoff (lose the friend, faction patron, city hollows). Both endings real.

## The reactive city (4I)
Persistent decals/scorch/boarded shops/memorials/thinning crowds. Rumors
distort over Beats. Prices rise, doors close. Radio recap. Heat tiers with
named responses (fixers, then style-copying hitmen). Crowds are witnesses;
alleys are not.

## Emergence (5)
No city simulation: ONE shared world-state table, an EVENT QUEUE,
data-driven NPC schedules, reusable behaviors and mission templates.
Player-defined reputation (identities emerge from behavior). One action →
several connected consequences. The LEVERAGE DESIGN STANDARD: every feature
answers What does the player do / what decisions exist / how does the system
respond / what changes afterward / why replay it.

## District (6)
Block 1 your neighbourhood (alley, apartment above the noodle shop, the
bar), Block 2 the club district (main street, club, gym + Mechanic's
garage), Block 3 the docks (warehouse, final choice). Underpass connects
2-3. No fast travel. Map lives in the phone app; fog of war per block;
layers (jobs, faction control, heat, friends, damage). Each block one
streamed scene; interiors separate with a fade.
**Naming note: the bible has NO "Knuckle Room"** — the fight-club space is
the Block 2 gym + underground tournaments. The existing trainer placeholder
points there now.

## Controls (7)
Layouts at first launch + Settings (floating stick default / D-pad /
custom, up to 3 presets, mirror for left-handed). Optional controller map.
Style wheel (hold, flick, release; world slows to ~30%). Soft auto-target.
Timing looser than controller. Combos: Light chains x3, Light→Heavy
finisher, per-style strings. LEVERAGE STRIKE (super): meter from perfect
parries/clean counters/style variety; hold Heavy, release at full.
Haptic language: light=short tick, heavy=long low thump, parry=sharp
double tap, phone buzz=slow low pulse, debt tick=faint repeating pulse.
Accessibility: hold-to-block toggle, button size, auto-target strength,
reduced shake.

## Tech standards (8)
MOBILE renderer only. 60 fps iPhone 16 / locked 30 iPhone 13 mini; physics
30 ticks. ETC2/ASTC. Baked occlusion, NPC LODs, imposter buildings. 2-3
dynamic lights max. Blob shadows. Shader pre-warm. CPU particles. On-screen
FPS/draw-call toggle. Visual: high-contrast neon noir, #FF007F magenta and
#00F0FF cyan accents, always night always rain, Fresnel rims, inverted-hull
outlines, ONE post pass (contrast/bloom/light CA), impact frames,
letterbox+slow-mo finishers, vertex-shader rain, wet asphalt scrolling
ripples (no SSR), height fog into pink/cyan haze. AttackData resources
(damage, hitstop_frames, knockback, shake, posture, cancel window, haptic,
audio layers). Animation-driven hitboxes on Area3D, hurtbox layer 20.
8-directional stagger (4 first). Decal ring buffer cap 150. Audio: 6-layer
impacts (build 3 first), compressor+limiter, duck rain/music -4 dB on
heavies, danger drone, phone buzz = tension.

## Self-testing (9) — largely BUILT in this repo
TestRunner-equivalent exists as the tests/ smoke suite battery + headless
runs; keep extending it every batch. CI workflow desired (GitHub Actions
headless Godot). Typed GDScript, guard everything, no unbounded arrays,
never assume a node exists. Tuning.gd / tuning.tres: ONE place for every
gameplay number + debug tuning panel with live sliders saving overrides
(the repo has TUNING constants scattered — consolidating is Stage B/C).
Adversarial self-review each batch. ANIMATION_SLOTS.md and AUDIO_SLOTS.md
list slots for later real assets. PROJECT_BIBLE.md + STATE.json =
anti-drift memory; on "continue", read STATE.json and resume.

## Scope tiers (10)
CORE first across all systems, then FULL, then STRETCH. Never cut a tier
silently; first-pass features marked in TESTING.md.

## Balance defaults (14)
Player HP 100 / Composure 100. Thug 40, Guard 70, Heavy 160, Gunman 50.
Light 6 / heavy 16 dmg, parry posture 30, posture bar 100. Hitstop 3/8 f.
Buffer 200 ms, parry 300 ms, dodge 120 ms, cancel 150-350 ms. Tokens 2-3.
Starting debt 5000; interest/day: Family 3%, Corporation 8%, Crew 0%;
3 missed payments = default. Beat costs: call/job/hangout 1 each, 3 per
day. Trust as 4D. Jobs pay 400-1500 dirty; S-rank cuts debt 5% of
principal. Death debt 800.

## Batch order (15) — mapped to repo state, see STATE.json
0 foundation, 1 the punch, 2 rank/posture, 3 styles/wheel, 4 controls,
5 phone, 6 ledger/economy, 7 friends/trust, 8 the district, 9 world sim,
10 jobs + web, 11 discoveries, 12 kidnap arc, 13 polish. Batches too large
split (4a/4b...). Never summarize instead of writing real code. Every
batch: one-line recap, which loop + pillar it serves, Definition of Done
(opens from Main, tests pass, debug menu jumps to the feature, docs
updated, nothing broken).

## Repo-specific working rules (carried from the owner's earlier briefs)
- Plain-text Godot project (`.gd`, `.tscn`, `project.godot`), small files,
  everything pushed to main. The owner tests on a phone; the agent never
  claims the game "looks/feels good" — phone-only claims wait for the owner.
- Assets CC0/free-for-commercial only, each in CREDITS.md with source and
  license. Missing assets never block a build (placeholders + slots docs).
- Docs: VISION.md (series arc), WOW_GATE.md (the wow gate), README.md
  (build/test history), STATE.json (continuation), this bible.
