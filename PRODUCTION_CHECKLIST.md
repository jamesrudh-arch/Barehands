# LEVERAGE — PRODUCTION CHECKLIST

## !!! USER OVERRIDES R1-R16 — ABOVE EVERY SECTION BELOW !!!

The user's overrides (2026-11-23) beat this mandate. Full text:
`docs/USER_OVERRIDES.md` — READ IT AT EVERY SESSION START. Build order:
R1/R2 warehouse-start scene + street through a visible gate -> R3 move
stick + second camera control -> R4 X punch / Y heavy / A kick / B dodge
+ context -> DEVICE REPORT + zip, STOP for the phone result -> R11
doors -> R13+R16 -> R5 faces/bodies -> R12 missions. Track in
`docs/TRACEABILITY.md`. The source file LEVERAGE_ZAI_MASTER_PROMPT_V3.txt
is not in the sandbox; R6-R10/R13/R14/R16 text is SOURCE MISSING.


The living record of the COMPLETE OPEN-WORLD GAME PRODUCTION MANDATE.
Every section of the mandate is tracked here with its REAL status —
what is built and verified, what is partial, what is not started.
Nothing is marked done because a script exists; done means tested in
the running game (the battery) and named with the evidence.

Levels: VERIFIED (suite-proven in-game) / BUILT (works, suite
pending) / PARTIAL (some behaviour, gaps named) / MISSING.
Device column: iPhone/Xogot verification is NEVER claimed from Linux
runs — it waits on a real device report.

| # | Mandate section | Status | Evidence / gap |
|---|---|---|---|
| 1 | Fundamental directive (whole game, not demo) | ONGOING | 25 shipped builds, each playable end-to-end |
| 2 | Studio thinking (all disciplines) | ONGOING | code+art+audio+QA in one loop; battery = QA |
| 3 | Real game experience (boot→menu→story→play) | VERIFIED | live_boot suite: picker→title→PLAY→apartment→save/load |
| 4.1 | Characters: models, faces, rigs | VERIFIED | humanoid.gd code-built bodies+faces; smoke_cast/pose/tpose |
| 4.2 | Animation breadth | VERIFIED | walk/sprint/jump/punch/kick/flinch/guard/roll/grab/phone/dance/chat; smoke_pose |
| 4.3 | Environment art | VERIFIED (B29) | code facades with base courses, floor-line ledges, roofline crowns, shop awnings (render_facades 6/6: 42 riverside bands, plinth band measured 0.037 vs wall 0.516); smoke_city |
| 4.4 | Rendering & atmosphere | VERIFIED | night neon, rain, puddles, fog, wet roads; smoke_weather; llvmpipe-proven |
| 5.1 | City structure (3 blocks, roads, alleys) | VERIFIED | riverside/market/foundry + back alleys; smoke_worldsim |
| 5.2 | Accessible interiors (5) | VERIFIED | apartment, shop, foundry office, gym, safehouse; smoke_interiors |
| 5.3 | Environmental storytelling | VERIFIED | posters, signs, radio chatter, neighbourhood palettes |
| 6.1 | NPC everyday behaviour | VERIFIED | walk/cross/wait/chat/phone/shop/browse; smoke_crowd |
| 6.2 | Personality + emotional behaviour | VERIFIED (B25/B27) | fear face on witnessed panic; observable ANGER on dispute pairs; gossip retelling, street-memory smalltalk, rain umbrellas; smoke_reactive + smoke_events |
| 6.3 | Reactions & memory | VERIFIED | witness watch/record/flee + witness recall; smoke_reactive |
| 6.4 | Named characters (16) | VERIFIED | cast with names/routines/dialogue; smoke_cast |
| 7 | Player movement & interaction | VERIFIED | third-person, camera-relative, context verbs; smoke/smoke_controls |
| 8 | Vehicles & transportation | VERIFIED (B26) | the whole kerb is real metal: the sedan + a second burgundy sedan + the bicycle (hero rides IN PLAIN SIGHT, A BELL / B BRAKE, frame leans) + one drivable car per far block; traffic bodies true van/sports + noir paint palette; EVERY vehicle persists by name; smoke_bike 31/31, smoke_drive 21/21, render_wheels 11/11 |
| 9 | Combat (5 styles, crime) | VERIFIED (B30) | brawler+chains+stamina+knockdown+weapons; DRUNKEN COMPLETE: sway stance (0.054 rad), seeded slip (attacker pays the stagger), 450ms parry, spin heavy sweeps the flanks; smoke_drunk 16/16 + smoke_combat/combos |
| 10 | Police, emergency, consequences | VERIFIED | heat ladder, witnesses, fixer, radio reaction; smoke_reactive |
| 11 | Story & cinematic presentation | VERIFIED | studio card, title+tagline, 16+ notice, menu, opening, apartment wake; live_boot |
| 12 | Complete audio | VERIFIED (B28) | layered music, hits, steps, rain, ambient hum + THE RECORDED CAST: 31 real voice takes (14 characters x lines + the 3 narrator calls) wired to the existing hook with subtitle sync; recorded > TTS > babble ladder; smoke_voice 11/11 |
| 13 | Economy & progression | VERIFIED | $0 start, shops, jobs, style value, debt ledger; smoke_economy/jobs/ledger |
| 14 | Factions, relationships | VERIFIED | trust/family-corp-crew hooks via ledger+radio; smoke_friends |
| 15 | Phone & information hub | VERIFIED | contacts/calls/messages/jobs/map/notes; smoke_phone |
| 16 | World events & emergence | VERIFIED (B27) | events.gd: dispute (angry faces, crowd, memory), fender-bender (hazards pulse, lane holds), police sweep (beacons, road clears); every event into the ONE memory the radio/gossip/smalltalk read; smoke_events 22/22 x2 |
| 17 | Map, navigation, GPS | VERIFIED (B32) | live map with routes/markers; INTERIOR NAV complete: the interior card (floor plan, EXIT at the door, the way out) + street-side YOU'RE INSIDE pin; smoke_map 43/43 |
| 18 | UI & presentation | VERIFIED | menus/HUD/dialogue/subtitles; DESIGN_SYSTEM.md tokens; smoke_safe |
| 19 | Touch & controller support | VERIFIED | floating scheme, B-button law, drive cluster (B25); smoke_controls; gamepad PARTIAL |
| 20 | Save & world continuity | VERIFIED | wallet/heat/gear/city/phone/vehicle round trip; smoke_drive+save suites |
| 21 | Professional asset acquisition | ONGOING | Kenney CC0 kits integrated (cars/city/buildings); gltf path retired after device ghosting; licences in assets |
| 22 | Coherent architecture | VERIFIED | single autoload bus (InputBus/Traffic/Fx...), one battery |
| 23 | Performance & device engineering | PARTIAL | Low/Mid tiers, light budget law, pooling; device FPS UNKNOWN — needs the iPhone report |
| 24 | Depth & polish | ONGOING | cooldown rings, context verbs, haptics, subtitles; polish never "done" |
| 25 | QA & real verification | VERIFIED (B26) | the honest battery, re-proven at final code with isolated per-suite dirs: run_tests 12/12, 42 smoke suites, render_check 56, render_wheels 11, smoke_safe 16, live_boot 15, live_walk 4, live_play 12, final_audit 16 — three suites (guide/ledger/start) were first re-proven BROKEN at B25 code, then repaired (apartment wake, grab order, stale enum) |
| 26 | Prohibitions (no dummies/ghosts/fakes) | VERIFIED | DUMMY tags gone (B23), protagonist visible, cars drive (B25), the rider rides in the open (B26) |
| 27 | Execution discipline | ONGOING | this checklist + per-build STATE.json/CHANGELOG |
| 28 | Final acceptance | NOT YET | device verification outstanding; VO, dynamic events, NPC depth, visual pass above |

## The next fronts (in dependency order)

1. THE NEXT VISUAL PASSES (mandates 21/4.4): interior dressing depth,
   more street jewelry on the proven renderer law.
2. THE NEXT VISUAL PASSES (mandates 21/4.4): interior dressing on the
   proven renderer law; the street's facades dressed (B29).
3. THE DEVICE REPORT (mandate 25/28): every Linux claim above is
   honestly INTEGRATED+TESTED level only; DEVICE VERIFIED waits on a
   real Xogot/iPhone run.
