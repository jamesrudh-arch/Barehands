# LEVERAGE — PRODUCTION CHECKLIST

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
| 1 | Fundamental directive (whole game, not demo) | ONGOING | 24 shipped builds, each playable end-to-end |
| 2 | Studio thinking (all disciplines) | ONGOING | code+art+audio+QA in one loop; battery = QA |
| 3 | Real game experience (boot→menu→story→play) | VERIFIED | live_boot suite: picker→title→PLAY→apartment→save/load |
| 4.1 | Characters: models, faces, rigs | VERIFIED | humanoid.gd code-built bodies+faces; smoke_cast/pose/tpose |
| 4.2 | Animation breadth | VERIFIED | walk/sprint/jump/punch/kick/flinch/guard/roll/grab/phone/dance/chat; smoke_pose |
| 4.3 | Environment art | VERIFIED | code facades, 5-paint palettes, window grids, signs, lamps; smoke_city |
| 4.4 | Rendering & atmosphere | VERIFIED | night neon, rain, puddles, fog, wet roads; smoke_weather; llvmpipe-proven |
| 5.1 | City structure (3 blocks, roads, alleys) | VERIFIED | riverside/market/foundry + back alleys; smoke_worldsim |
| 5.2 | Accessible interiors (5) | VERIFIED | apartment, shop, foundry office, gym, safehouse; smoke_interiors |
| 5.3 | Environmental storytelling | VERIFIED | posters, signs, radio chatter, neighbourhood palettes |
| 6.1 | NPC everyday behaviour | VERIFIED | walk/cross/wait/chat/phone/shop/browse; smoke_crowd |
| 6.2 | Personality + emotional behaviour | VERIFIED (B25) | fear face on witnessed panic (mouth 3.4x, brows lift); smoke_reactive |
| 6.3 | Reactions & memory | VERIFIED | witness watch/record/flee + witness recall; smoke_reactive |
| 6.4 | Named characters (16) | VERIFIED | cast with names/routines/dialogue; smoke_cast |
| 7 | Player movement & interaction | VERIFIED | third-person, camera-relative, context verbs; smoke/smoke_controls |
| 8 | Vehicles & transportation | VERIFIED (B25) | sedan drivable: enter/steer/throttle/handbrake/horn/exit/traffic-yield/persistence; smoke_drive 21/21. BICYCLES: MISSING — first item of B26 |
| 9 | Combat (5 styles, crime) | VERIFIED | brawler+chains+stamina+knockdown+weapons; smoke_combat/combos; drunken style PARTIAL (chain subset) |
| 10 | Police, emergency, consequences | VERIFIED | heat ladder, witnesses, fixer, radio reaction; smoke_reactive |
| 11 | Story & cinematic presentation | VERIFIED | studio card, title+tagline, 16+ notice, menu, opening, apartment wake; live_boot |
| 12 | Complete audio | PARTIAL | layered music, hits, steps, rain, ambient traffic hum; VOICE ACTING MISSING — B26 candidates |
| 13 | Economy & progression | VERIFIED | $0 start, shops, jobs, style value, debt ledger; smoke_economy/jobs/ledger |
| 14 | Factions, relationships | VERIFIED | trust/family-corp-crew hooks via ledger+radio; smoke_friends |
| 15 | Phone & information hub | VERIFIED | contacts/calls/messages/jobs/map/notes; smoke_phone |
| 16 | World events & emergence | PARTIAL | traffic+crossing+chat+weather systems; scripted dynamic events (accidents, disputes) MISSING |
| 17 | Map, navigation, GPS | VERIFIED | live map with routes/markers; smoke_map; interior nav PARTIAL |
| 18 | UI & presentation | VERIFIED | menus/HUD/dialogue/subtitles; DESIGN_SYSTEM.md tokens; smoke_safe |
| 19 | Touch & controller support | VERIFIED | floating scheme, B-button law, drive cluster (B25); smoke_controls; gamepad PARTIAL |
| 20 | Save & world continuity | VERIFIED | wallet/heat/gear/city/phone/vehicle round trip; smoke_drive+save suites |
| 21 | Professional asset acquisition | ONGOING | Kenney CC0 kits integrated (cars/city/buildings); gltf path retired after device ghosting; licences in assets |
| 22 | Coherent architecture | VERIFIED | single autoload bus (InputBus/Traffic/Fx...), one battery |
| 23 | Performance & device engineering | PARTIAL | Low/Mid tiers, light budget law, pooling; device FPS UNKNOWN — needs the iPhone report |
| 24 | Depth & polish | ONGOING | cooldown rings, context verbs, haptics, subtitles; polish never "done" |
| 25 | QA & real verification | VERIFIED | 48-suite battery incl. live_play (played live end-to-end) |
| 26 | Prohibitions (no dummies/ghosts/fakes) | VERIFIED | DUMMY tags gone (B23), protagonist visible, cars drive (B25) |
| 27 | Execution discipline | ONGOING | this checklist + per-build STATE.json/CHANGELOG |
| 28 | Final acceptance | NOT YET | device verification outstanding; bicycles, VO, dynamic events above |

## The next fronts (in dependency order)

1. BICYCLES — mount/ride (mandate 8): the last non-interactive
   vehicle class; reuse the B25 vehicle controller.
2. VOICE + dialogue delivery (mandate 12): real voice lines for the
   brother call, the fixer, shopkeeper; subtitles already sync.
3. DYNAMIC WORLD EVENTS (mandate 16): street disputes, crashes,
   police sweeps that NPCs and the radio react to.
4. DRUNKEN STYLE full chain + parry (mandate 9).
5. THE DEVICE REPORT (mandate 25/28): every Linux claim above is
   honestly INTEGRATED+TESTED level only; DEVICE VERIFIED waits on a
   real Xogot/iPhone run.
