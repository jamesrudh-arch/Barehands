# Bare Hands 3D

A stylized noir, open-world crime game set in **Cinder City**.
Engine: **Godot 4.7**, 3D, **Mobile** renderer, landscape, touch-first.
The whole project is plain text (`.gd`, `.tscn`, `project.godot`) plus CC0 asset packs, so it can be built and edited without a desktop editor.

**SERIES 1: THE LOOK AND FEEL** — phase reports below (1 Stability · 2 Hero & Camera · 3 Wet Neon Night · 4 Punches That Hit).
**SERIES 2: SOUND, SOUL AND DEPTH** — reports continue below (1 Audio · 2 Music · 3 Combat · 4 Ledger · 5 Economy · 6 City · 7 Cast · 8 Opening). Design docs: docs/VISION.md, docs/WOW_GATE.md (reconstructed — originals never arrived).

## What's in the game (through Series 1 Phase 2)

Everything from Batches 1-2 (night street block with neon, the pack's mannequin hero with analog run/sprint/jump, code-faked ledge climbing, parkour roofs and crates, wall-safe camera, one-time "Jump while moving to climb" hint, forgiving ledge grab) plus **Batch 3, combat feel**:

- **PUNCH button** (red, bottom-right): a two-hit jab→cross combo with input buffering — press PUNCH again during the jab and the cross chains automatically. Punches soft-lock to the nearest enemy and lunge; at point-blank the lunge is skipped.
- **A training dummy** (standing beside the street crate, north-west of spawn): flinches (`Hit_Chest`), staggers back, and falls (`Death01`) when its hp runs out, then resets. The jab hits the chest, the cross the head.
- **Impact layers, in order**: hit-stop first (time briefly slows to 5%), then the enemy's white flash plus a small CPU particle spark, then a very subtle camera shake (a few centimetres). No sound yet — `Fx.hit_landed(kind, pos)` is the hook Batch 4 connects to.
- **Style meter** (top-right): mixing punches, dodges, parries, counters, slams and takedowns raises the rank D→C→B→A→S; repeating the same move earns 35%, then 12%. The rank multiplies the cash points each move banks (×1.0 up to ×3.0). Cash is a stored number only.
- **DODGE/PARRY button** (white, left of PUNCH): a quick evade in the stick direction (or a back-step with no stick), with invincibility frames. Press it **just before an enemy's swing lands** and it becomes a parry: a 0.7 s slow-motion window opens, the attacker staggers, and your next punch is a counter-hit that knocks them down.
- **A thug** (west end of the street) that shambles over and attacks on a clear rhythm: a pulsing red telegraph for 0.6 s, then the swing. Learn the timing on him.
- **Environmental takedown**: land a cross or a counter while a crate or wall is right behind the enemy and they get slammed into it — bigger hit-stop, bigger shake, top style points.
- Player getting hit (no parry) = knockback plus a short `Hit_Chest` stagger. No health bar for the hero yet.

No shops, missions, driving, guns or sound yet — later batches.

## SERIES 1 · Phase 1 — Stability

**What was built**

- **Both load warnings fixed.** The unused `hit_landed` signal: the emits lived in player/enemy while the signal belonged to the Fx autoload, so its own class never used it — every impact now goes through `Fx.emit_hit(kind, pos)`, which emits the signal internally (still the Series 2 sound hook). The integer-as-enum warning does not fire on desktop Godot 4.7.2 at error level, so it came from Xogot's parser or an older import cache; to be safe both state machines now use **named enums** (`Player.State`, `Enemy.State`) and every raw `state == 3` literal in code and tests was replaced with the named value — the pattern that causes that warning no longer exists anywhere.
- **File logger** (autoload `Log`, `scripts/log.gd`): writes `user://barehands.log`, one fresh file per launch with a boot header (Godot version, OS, device model). `Log.info/warn/error` print and persist; the last 400 lines are kept in memory for the debug panel.
- **Debug panel** (`scripts/debug_panel.gd`, built entirely in code): tap the small **DBG** button top-left (or F3 on a keyboard) for FPS, frame time, static memory, orphan-node count, node/object/draw-call counts, each enemy's state and hp, particle bursts in flight, current time scale, and the on-device log path. It refreshes 4×/s and costs nothing when hidden.
- **Mid-play-stop audit, fixes applied**: Fx now runs with `PROCESS_MODE_ALWAYS` and carries a **watchdog** — if a hit-stop or slow-mo somehow survives 5 s it is force-restored and logged; `burst()` no longer spawns into a null scene and tracks in-flight particles; input queues (jump/punch/dodge) **expire after 0.4 s of game time**, so a jump pressed mid-air can no longer fire seconds later on landing (and slow motion no longer eats a buffered counter); every scale-down logs a warning if it interrupts another.
- **5-minute combat stress test** (`tests/stress_combat.tscn`): a bot cycles combo / parry / chaos / idle scenarios for 18,000 physics ticks (5 min at 60 fps) while watchdogs check for stuck states, stuck slow-motion, leaking particles and runaway node counts. Both smoke suites still pass unchanged.

**How to test on a phone**

1. Import and play as usual. Tap **DBG** (top-left) any time: watch FPS while idling, sprinting, and fighting; enemies list their live state; particles-in-flight should always fall back to 0 within a second of the last hit.
2. Let a parry slow-mo play out fully, then confirm the panel's `time_scale` reads 1.00.
3. The log file lives in the app sandbox: with Xogot on iOS it is inside the Xogot app's Documents folder (Files app → On My iPhone → Xogot); on an exported Android APK it is `Android/data/<package>/files/barehands.log`. The DBG panel prints the exact absolute path on your device.

**Not verified on a real phone**: the panel's readability on the 13 mini's screen, actual FPS/memory numbers (headless Linux has no GPU — the numbers below are logic-side only), and whether Xogot still shows the integer-as-enum warning after re-import (if it does, tell me the exact file:line it names).

**Added beyond the brief**: the orphan-node counter on the panel, the log-ring for the panel, and the input-queue expiry (the last one changes feel slightly: presses older than 0.4 s no longer count).

## SERIES 1 · Phase 2 — The Hero and the Camera

**What was built**

- **A real noir hero replaces the grey mannequin** (`scenes/hero.tscn` + `scripts/hero_rig.gd`): Quaternius' Universal Base Character body (head, hands, beard) dressed in the Modular Outfits ranger set (torso, sleeves, trousers, boots), plus a **code-built fedora** (crown, band, brim, tilted) and a **swinging coat skirt** (two panels hung off the pelvis that swing with your speed). Every piece shares the pack's 65-bone rig, so all 43 UAL clips drive the six pieces in lockstep — the rig grafts the mannequin's animation library onto one AnimationPlayer per piece at load. Distinct silhouette: fedora, beard, long dark coat against the neon.
- **Facing fixed and re-verified by bones**: the new pieces ship facing +Z like the mannequin did, so each carries the same 180° correction. The movement smoke still asserts `hand_l` sits west while running north, east while sprinting south, and that the climb pose faces the wall — now against the hero's skeleton.
- **A cinematic camera** (`scripts/camera_follow.gd`): slight over-the-shoulder offset (hero sits left-of-center), fast horizontal catch-up with a softer vertical lag (reads like a crane), a **field-of-view kick to 77° while sprinting**, a **gentle push-in** (6.0 → 4.6 m) whenever an enemy is within 3.5 m, **lock-on** (LOCK button above the action cluster, or L on a keyboard) that frames the hero and target together and drops when the target falls, and the existing wall pull-in and impact shake.
- **An opening shot** (`scripts/opening_shot.gd`): the camera sweeps from high over the east neon down the street and lands behind the hero's shoulder over ~7 s, with letterbox bars and a TAP TO SKIP corner label. Any tap/key skips. HUD and gameplay input are locked until it ends.
- itch.io now requires an account even for free downloads, so the CC0 packs came from GitHub mirrors (see **CREDITS.md** for exact sources and licenses). Textures were downscaled to 1024/512 px for the phone; the 4K normals were dropped for flat noir shading.

**How to test on a phone**

1. Watch the opening: it should sweep the neon and land behind the hero. Tap anywhere — it should snap to gameplay instantly.
2. Run and hold SPRINT: the view should widen slightly and snap back when you stop. Walk near the dummy: the camera should drift closer and step back out when you walk away.
3. Face the dummy and tap **LOCK** (small button above JUMP): the camera should hold a framing with both of you in it; knock the dummy down and the lock releases.
4. Run around: the coat should swing with speed; watch the fedora and beard follow the head during punches.

**Not verified on a real phone**: how the layered hero reads on a small screen (six skinned pieces ≈ 12k verts total — well within an A15's budget, but unmeasured), the opening shot's framerate on Low tier, the fedora's fit during animations (tuned headless by bone positions), and the shoulder offset's comfort in the hand.

**Added beyond the brief**: the fedora and swing coat (the brief asked for "a coat or jacket and a distinct silhouette" — the outfit pack is fantasy-only, so the long coat is code-built), the letterbox bars on the opening, and lock-on dropping automatically when the target goes down.

**Missing on purpose (tell me if you want them)**: the true *Universal Outfits* casual line (trench coat, suits) is itch-only right now. If you want a tailored trench instead of the code-built coat: download "Universal Base Characters" + "Modular Character Outfits" from https://quaternius.com (or your itch library), and upload the zip to the repo — I'll retarget the rig in the next phase.

## SERIES 1 · Phase 3 — The Wet Neon Night

**What was built**

- **Wet asphalt + puddles** (`shaders/road.gdshader`): the road is a shader now — a procedural puddle mask makes blobs mirror-smooth (metallic, roughness 0.05) while the rest stays rain-damp, with an animated ripple shimmer, and **fake neon reflections**: colored patches around each real sign's position, riding the puddles, lifted by fresnel. No screen-space reflections anywhere. Five extra mirror puddles (`street_dress.gd`) catch real specular pops from the neon lights as characters move.
- **Neon with life** (`scripts/neon.gd`): the amber sign flickers, the cyan one buzzes, the red one is broken — dark with dying strobes. Each duplicates its material so signs flicker independently. Four individually lit windows (warm/cool mix) + AC units + fire escapes (zigzag platforms, railings, stairs) + hanging wires + grates + bins, bags and a hydrant make the street read lived-in (`scripts/street_dress.gd`, all code-built, bins and hydrant have collision).
- **Atmosphere**: deeper blue fog and ambient, bloom up with a threshold, contrast/saturation grade, a **fullscreen vignette** shader (`shaders/vignette.gdshader`), three additive **light shafts** (amber kiosk, cyan window, red thug street), **steam** rising from three grates, and **rain** (`scripts/rain.gd`): 700 world-aligned streaks falling past the camera plus ground splash sparks around the hero.
- **Quality tiers** (`scripts/quality.gd`, autoload): **High** = full 3D resolution, MSAA 2x, splashes, shafts; **Low** = 0.62 resolution scale, no MSAA, no splashes, no shafts, half rain. Auto-picks after ~3 s of measured gameplay FPS (starts conservative on phones, promotes if it holds 50+), override any time in the **pause menu** (II button top-left): RESUME, Quality Auto/Low/High, live fps.

**How to test on a phone**: watch the opening — wet reflections should shimmer under the neon; walk past the amber sign and watch its color ride the puddles; the red sign should stay dark and strobe. Pause (II), switch Quality Low, watch the resolution drop and shafts/splashes vanish; switch High and they return; Auto re-measures.

**Not verified on a real phone**: everything visual — shader cost on the A15, whether the fake reflections read at 60 fps, shaft/steam/rain fill rates on Low tier, and the auto-tier threshold. This sandbox has no GPU; the tier logic is verified headless, the look is not. Tell me how it runs with DBG open.

**Added beyond the brief**: individually lit windows, AC units, the hydrant/bin collision, the II pause button styling, and rain following the camera rather than a fixed box.

## SERIES 1 · Phase 4 — Punches That Hit

**What was built**

- **Impact stack, in order** (now four layers): hit-stop (0.07–0.13 s at 5%) → enemy flash + particle spark → subtle camera shake → **new: FOV punch** (jab +1.5°, cross +3°, counter +4°, slam +6° — a fast kick-out that decays in ~0.1 s).
- **Perfect parry**: the 0.7 s slow-mo now also **zooms in** (a −6° FOV pull on top of the kick system) and fires a brief **cyan colour wash** over the screen (`vignette.flash`), so a parry reads as a moment, not just slow physics.
- **Enemies with weight**: on a kill they now **keel over ragdoll-lite** (body tilts back and drops over ~0.4 s) instead of playing the death clip standing, and counter/slam kills add a **0.4 s cinematic slow-mo beat**.
- **Rank pop-ups**: the STYLE label scale-punches (1.7→1.0) every time the rank changes.
- **Sound hooks, ready for Series 2**: every impact routes through one signal — `Fx.hit_landed(kind, pos)` with kinds `jab`, `cross`, `counter`, `slam`, `parry`, `player_hit` (plus `Fx.emit_hit` for anything new). Connect one player and the whole combat bed is done.

**How to test on a phone**: jab the dummy — small stop, small spark, small kick; cross — bigger everything; parry the thug — slow-mo + zoom + cyan wash; counter or slam — slow-mo finisher and the body topples; keep the style varied and watch the rank label pop.

**Not verified on a real phone**: whether the FOV punch frequency reads as punchy or nauseating at 60 fps, the topple's look against the death clip, and the colour wash intensity on OLED (tuned blind).

**Added beyond the brief**: the parry FOV zoom on top of the brief's camera punch, and the finisher slow-mo applying to environmental slams too.

## SERIES 2 · Phase 1 — Audio Foundation

**What was built**

- **Five audio buses** (`default_bus_layout.tres`: Master → Music, SFX, Ambience, Voice; Master carries a limiter so layered hits never clip) with **volume sliders in the pause menu** for all five, persisted to `user://settings.cfg`.
- **63 CC0 / generated clips** in `assets/audio/`: real Kenney punch impacts (medium/heavy variations), body thuds, metal/wood/glass, cloth, doors, coins, knife slices, UI clicks — plus code-synthesized rain-on-asphalt, rain-on-metal, distant traffic, neon hum, distant sirens and puddle splashes (sources and licenses in CREDITS.md; total ~3.4 MB).
- **Layered impacts with weight** (`scripts/sound.gd`, autoload "Sound"): every `Fx.hit_landed` kind maps to a stack — jab = punch + body, cross = punch + body + sub-bass, counter adds a metal ring, finisher adds a bell, parry is metal ring + latch, player-hit is thud + cloth. Every one-shot has random pitch jitter so nothing sounds mechanical.
- **Surface footsteps**: the hero's steps are distance-driven; a downward ray reads `metadata/surface` off the ground (road = asphalt, crates = wood, annexes/garages = metal, safehouse later = carpet) and puddle proximity (the five street puddles) overrides to a splash. Metal is wood pitched down plus a metal click layer.
- **Spatial audio**: a looping neon hum sits at each of the three neon lights as a positional `AudioStreamPlayer3D` — walk past a sign and it hums by. Rain, traffic and a distant siren (random 45–110 s) run on the Ambience bus.
- **Fixed a real Series-1 bug found by this phase's test**: the wet-road shader never compiled on device (`WORLD_VERTEX_COORDS` is not a Godot 4.7 identifier — the road has been rendering with a fallback material since Phase 3 of Series 1). Replaced with a proper world-position varying; zero shader errors now.

**How to test on a phone**

1. Start the game: rain bed, traffic and hum should be there at once; walk near the amber sign — the hum should pan and fade with distance.
2. Fight the dummy: jab vs cross should clearly differ in weight (cross has the sub layer); a parry should ring.
3. Walk along the street and step into a puddle — the step should splash; climb onto a crate — the step changes to wood; onto the annex — metal.
4. Pause (II): drag the SFX slider down to 0 while walking — footsteps and hits go silent while rain stays; set Master to 0 — everything stops. Close and reopen the game: the sliders remember.

**Not verified on a real phone**: actual speaker mix and levels (tuned by construction, not by ear — I cannot hear this sandbox), hum audibility distance on a phone speaker vs headphones, and whether the puddle splash reads over the rain bed on the 13 mini's speaker.

**Added beyond the brief**: the distant-siren timer, the limiter on Master, pitch jitter on all one-shots, and settings persistence for the sliders. The road-shader fix was unscheduled but necessary.

**Numbers**: 63 clips (≈700 KB Kenney OGG + 2.7 MB generated WAV), static memory with the whole bank loaded **56.1 MB** (vs ~53 MB before audio), zero allocations per hit (player pool reuse). Headless dummy driver, so no runtime audio cost was measurable here.

**GATE (docs/WOW_GATE.md, Phase 1)**: every machine-checkable line passes — `tests/smoke_audio.tscn` verifies buses, bank, layers per kind, all five footstep surfaces, puddle/wood/asphalt detection by position, 3 spatial hums, sliders, mute, persistence. Phone-only lines (mix, weight, audibility) await your test. **GATE: PASS (headless).**

## SERIES 2 · Phase 2 — Adaptive Music

**What was built**

- **A layered music director** (`scripts/music.gd`, autoload "Music"): four synchronized loop stems on the Music bus — the quiet noir **bed**, a **tension** pulse, the **combat** layer, and the **heartbeat** — plus a one-shot **resolve** phrase. All stems are code-synthesized placeholders (D minor, 88 BPM, built by `scripts/synth_audio.py`); swap the WAVs in `assets/audio/` for recorded stems of the same names and the system is unchanged.
- **Beat-aware transitions**: the director runs an 88 BPM bar clock; layer volume targets only change on bar boundaries and fade over about one bar, so the music breathes with the scene instead of clicking. State detection scans the world every bar: an enemy within 10 m = tension; within 4 m or the hero fighting = combat; two calm bars after combat = the resolve phrase plays and the bed returns.
- **Combat rises with the style rank** (D → S maps the combat layer from −10 dB to −1 dB) and the **heartbeat speeds up with heat** (0.9× → 1.55× tempo and louder); until Phase 5 lands real heat, engaged enemies lend provisional heat.
- **Dialogue duck** (`Music.duck`) dips and restores the whole Music bus, ready for Phase 7's dialogue. `force_state` holds a state for cutscenes.

**How to test on a phone**

1. Walk the empty street: just the quiet bed and rain. Walk toward the thug: a pulse joins in. Get within swing range: the full combat layer; land a varied combo and it climbs with your rank.
2. Walk away and stay clear ~5 s: a calm resolve phrase, then the bed alone.
3. Open the pause menu mid-fight: music keeps playing while paused; the Music slider still controls it.

**What I could not verify on a real phone**: whether the synthesized stems actually *sound* noir (I generated them to spec, but I cannot hear this sandbox — the mix, the levels, and the genre feel need your ears). The **stems to replace** if you want recorded music, all 88 BPM in D minor: `music_bed.wav` (quiet pad, 10.9 s loop), `music_tension.wav` (sparse pulse, 5.5 s loop), `music_combat.wav` (drums + bass, 5.5 s loop), `music_heartbeat.wav` (single lub-dub pair, 0.85 s loop), `music_resolve.wav` (calm phrase, 6 s one-shot). Drop replacements in `bare-hands/assets/audio/` with the same names.

**Added beyond the brief**: the dialogue-duck helper, the cutscene hold on `force_state`, and rank-driven combat mixing (the brief asked for style rank to raise the layer).

**GATE (Phase 2)**: `tests/smoke_music.tscn` — 18 checks green: layers, bar-clock phase, bed/tension/combat crossfades with distinct levels per state, rank D vs S combat levels, heartbeat 1.55× at heat 5, resolve triggers and bed returns, duck dips/restores. Phone-only lines (the actual sound) await your test. **GATE: PASS (headless).**

## SERIES 2 · Phase 3 — Combat Depth

**What was built**

- **The combo tree** (`scripts/player.gd`, rewritten): tap PUNCH for the light chain **jab → cross → hook** (1/2/2 damage, buffered chaining as before). **HOLD PUNCH ≥ 0.3 s for a heavy** (3 damage, bigger stop, haptic 60 ms). The heavy is context-aware: on a **staggered/flinching enemy it launches** them (ragdoll-lite airtime, lands to a long stagger), on an enemy at **≤ 2 HP it executes a finisher** — 0.5 s slow-motion, punch-in zoom, 160 ms haptic, bell layer.
- **Block and perfect parry**: **HOLD DODGE ≥ 0.25 s** to guard (braced pose, slowed). A strike into a mature block is absorbed (pushback, blue spark, haptic 30 ms, attacker resets); a block **younger than 0.15 s is a perfect parry** — the same freeze/counter window as a perfect dodge, now reachable two ways.
- **Grab and throw**: new **GRAB** button (G key). Near an enemy: seize them for 1.2 s — **PUNCH knees** (1 damage each), **DODGE/GRAB throws**. A throw into a **tagged surface is an environmental takedown with its own kind and sound**: `slam_car` (the new parked sedan), `slam_shutter` (the new shop shutter under the amber sign), `slam_rail` (the new sidewalk railing), `slam_wall` for everything solid. All are haptic 120 ms.
- **The steel pipe**: lying by the street crates. **GRAB near it picks it up** — it rides the right hand (bone-attached), swings slower and heavier (light 2, heavy 4 damage, -8% move speed, metal impact layers). **GRAB with the pipe and no enemy in reach throws it** as a 4-damage projectile along your facing; it drops back on the street for re-use.
- **Four enemy types** (`scripts/enemy.gd`, rewritten; `kind` replaces `mode`): **brawler** (the classic thug rhythm, unchanged), **armoured bruiser** (gunmetal, 12 HP, armour 3 — damage below 3 chips HP but never staggers: heavies, the pipe, launchers and finishers are the answer), **knife attacker** (wiry, 2.6 m/s, 0.32 s orange telegraph, lunging strike with knife-slice audio), **boss** (blood-red, 1.28× scale, 30 HP, armour 4, three-hit combos with fast links, periodic green-telegraph grab that lands with slow-mo).
- **Group tactics** (`scripts/tactics.gd`, autoload): with 2+ enemies engaged, each takes a **surround slot** on a slowly rotating ring around you (constant flanking), and an **attack token** guarantees only one enemy swings at a time — the token is held through the whole swing animation. The boss ignores slots and always has the token.
- **Haptic hooks**: `Fx.haptic(ms)` fires on heavies (60), pipe heavies (60), slams (120), parries (40), finishers (160), blocks (30). It calls `Input.vibrate_handheld` — **this works on Android only; Godot 4.7 has no iOS vibration API**, so iPhone haptics need a plugin later (the hooks are all in place and tested).

**How to test on a phone**

1. On the dummy: tap-tap-tap PUNCH = jab, cross, hook. Hold PUNCH = the heavy; heavy on a staggered dummy launches them up; heavy on a ≤ 2 HP dummy executes the finisher (slow-mo + zoom + buzz).
2. Hold DODGE against the thug: strike absorbed. Try pressing the hold so the block starts just before his swing lands — parry flash and counter window.
3. GRAB the dummy: knee him twice, then throw toward the parked car east of spawn — car-door takedown. Throw into the railing north side, the shutter under the amber sign.
4. Walk to the crates east: GRAB picks up the pipe — slower, heavier swings with metal sounds. GRAB again with no one in reach hurls the pipe.
5. Spawn a street brawl (P5 adds spawning; for now the thug + any debug spawns): enemies circle instead of queueing and attack one at a time. Fight the boss at the west end: his combo chains and the green-telegraph grab hits like a truck.

**Not verified on a real phone**: haptics on iOS (needs a plugin — hooks verified headless on Android's API), the readability of the block stance (a slowed Hit_Chest pose — no dedicated guard animation exists in the UAL pack), knife-attack fairness at 60 fps, and boss difficulty (tuned by numbers, not by feel).

**Added beyond the brief**: tap-vs-hold input semantics (a quick PUNCH release is a light; the hold itself swings the heavy), the knee as a grab option, surface-specific slam kinds feeding the style meter's variety bonus, and enemies backing off while you hold one of their own.

**GATE (Phase 3)**: `tests/smoke_depth.tscn` — **30 checks green**: chain math, heavy, launcher (airborne y 1.02), finisher (slow-mo + 160 ms haptic), mature block, perfect-block parry, grab/knee/throw, pipe pickup + light (−2) + heavy (−4), bruiser armour (jab −1, no stagger; heavy staggers), knife (20-tick telegraph, 2.6 m/s), boss (armour, 84 strike hits in 4 s of chains), tactics (max 1 attacker, surround active), 3 tagged surfaces. All four existing suites still pass (one assertion updated: wall slams now record as `slam_wall`). **GATE: PASS (headless).**

## SERIES 2 · Phase 4 — The Bullet Ledger (the signature)

**What was built**

- **The Wallet** (`scripts/wallet.gd`, autoload): one source of truth for money. Every transaction — earnings, purchases, and **every single bullet fired** — appends an entry with the running balance. Bullets cost **$5 each**, spent per shot, never in batches; a shot you cannot afford does not fire.
- **The test weapon — the Ledger Iron** (`player.gd` + a steel prop on the sedan's hood): GRAB near it to take it. With the iron equipped, PUNCH fires: a 6-damage raycast shot with recoil, muzzle burst, camera kick, 50 ms haptic and the layered gunshot. **Firing visibly spends cash on screen**: the balance ticks down and a red "−$5" pops beside it (green "＋$" for earnings), plus a one-line receipt ticker for the latest entry. Broke? The gun clicks — no charge, no ledger entry.
- **The first-offer modal**: the first GRAB at the gun opens a noir panel *before* anything is owned — "THE LEDGER IRON / Every bullet you fire costs $5 of your own money / BULLET … $5" with TAKE IT / LEAVE IT. Gameplay input locks until you choose.
- **The ledger screen** (`scripts/ledger_ui.gd`): a thermal-paper receipt — header "CINDER CITY AMMUNITION", timed entries in order (earn / purchase / shot, item, amount), dashed rules, BALANCE, BULLET PRICE, and the footer "THANK YOU. NO REFUNDS." Opens with **B** or the pause menu's LEDGER button; scrolls; caps at the last 200 entries.
- Wired for the economy: one weapon slot (taking the iron drops the pipe at your feet), ownership and offer state persist via `Wallet.to_dict()` for Phase 5's save system.

**How to test on a phone**

1. Walk to the car east of spawn: a revolver sits on the hood. GRAB it — the offer appears with the bullet price before you own anything. TAKE IT.
2. Face the dummy and press PUNCH: a shot, a flash, the dummy rocks back — and **$5 leaves your balance on screen** with a red pop and a ticker line.
3. Press B (or pause → LEDGER): the receipt lists each shot with its time and the running balance.
4. Fire until under $5 (about 29 shots): the gun only clicks, nothing is charged, the receipt shows nothing new. Earnings (Phase 5's fights and shops) will refill it.

**Not verified on a real phone**: the receipt's legibility at 375 px width (built with 13–15 px type; the panel is 480 px wide, wider than a small screen — the scroll container handles it but the fit wants eyes), the feel of the shot recoil, and whether the $5 price reads as dear or cheap before the economy exists.

**Added beyond the brief**: the empty-click when broke (the brief said shots cost money; the click makes being broke its own feel), the receipt ticker on the HUD, the entry cap, and the "NO ONE IS BORN WITH A GUN" line printed on every receipt — the Phase 8 title card, foreshadowed on paper.

**GATE (Phase 4)**: `tests/smoke_ledger.tscn` — **35 checks green**: wallet math and entry order, overspend refusal with no phantom entries, the offer flow (shown once, locks input, states the price, TAKE equips and records ownership), firing spends $5 visibly (HUD label matches), shots land 6 damage, cooldown blocks double-spends, broke = click with zero ledger noise, the receipt opens with header/entries/balance/footer/earnings and closes, 200-entry cap. Depth and combat suites still green. **GATE: PASS (headless).**

## SERIES 2 · Phase 5 — Money, Shops, Heat

**What was built**

- **Fight earnings × style rank into the real Wallet**: every landed move now banks `points × rank multiplier` dollars into the Wallet (the style meter mirrors it), so the Bullet Ledger's money is the money fights earn. A varied chain earns a 1.2× bonus on top; spam still earns almost nothing.
- **Heat, 0–5 stars** (`scripts/heat.gd`, autoload): knockdowns +0.4, gunshots +0.6 (loud on a night street), landed hits +0.08. It decays only after **5 s out of sight of any hostile** — and a fixed timer bug here taught us the old version could never decay. HUD: red `HEAT *****` line under the style meter; music heartbeat follows heat. **Escalating response**: 1★ summons a brawler from a street edge; 3★ adds a knife; 5★ the armoured bruiser walks in (12 s reinforcement cooldown); when heat dies, responders leave. Training dummies witness nothing.
- **Three shops** (`scripts/shop.gd`, kiosks built by street_dress): **STITCH & SHADOW** (tailor — Midnight and Oxblood coats that recolour the hero's coat and fedora, $45–55), **IRON & LEATHER** (gear — leather gloves +1 punch damage, track boots +8% speed, padded jacket −30% hit stun), **VELVET'S COUNTER** (pawn placeholder — the per-shot bullet price explained, future stock info-only). Walk in, GRAB to browse; a noir panel with prices, live cash, LEAVE. Every purchase writes to the Bullet Ledger; insufficient funds click and write nothing.
- **The safehouse** (`scripts/safehouse.gd`): a lit door on the north face. GRAB → panel with SAVE / LOAD / status. **Save** (`scripts/save_game.gd`, atomic temp-file write) round-trips wallet + entries, heat, gear, coat look, hero position, style value, and the city-memory dictionary to `user://save.json`; **load** restores all of it and re-applies look and gear effects.

**How to test on a phone**

1. Beat the thug with varied moves at rank S — watch the cash line climb under the style meter, then open the ledger (B): the earn entries are there.
2. Fire the Ledger Iron twice near witnesses: the HEAT line jumps a star and a brawler arrives from a street corner within seconds. Break line of sight ~10 s and watch stars fade; the responder gives up.
3. Walk into the cyan-lit tailor kiosk (west side), GRAB, buy the Oxblood coat — your coat and fedora change colour, the ledger records −$55. The gear stall (north, amber) sells gloves: jabs that hit for 1 now hit for 2.
4. The safehouse door (north face, cold blue light): GRAB, SAVE. Kill the app, reopen, GRAB, LOAD — cash, heat, coat, gloves and position all come back.

**Not verified on a real phone**: shop panel fit at 375 px, whether heat decay pacing feels right in real play, and responder arrival fairness (spawn distance is clamped to the block edges — on foot that is a few seconds of walking).

**Added beyond the brief**: the varied-chain earning bonus, dummies not counting as witnesses, the atomic save write, and the pawn counter already named for Velvet (Phase 7's gun-shop owner) so the world stays consistent.

**GATE (Phase 5)**: `tests/smoke_economy.tscn` — **34 checks green**: rank D/S earning math into the Wallet, ledger earn entries, heat rise/cap/stars/HUD/music coupling, responder summon and departure, out-of-sight decay, tailor purchase (cash, look, actual coat colour on the rig), gear purchase (+1 damage verified through the damage function), insufficient funds (no charge, no entry), pawn info-only stock, and the full save/load round-trip (wallet, entries, heat, look, gear effect, position, city memory). All six suites green. **GATE: PASS (headless).**

## SERIES 2 · Phase 6 — The City Remembers You

**What was built**

- **Reputation per district** (`scripts/city.gd`, full behaviour on the Phase-5 persistence shell): the street is three districts — **riverside** (west), **market** (middle), **foundry** (east). Public violence costs the district it happens in (knockdown −8, gunshot −4, hit −0.8); a **stylish win** — counter, launcher, finisher, any slam — gives +7 back. Where you fight matters as much as how.
- **A district turns hostile** at rep −50 (and can be bought back with good will): its own two brawlers shadow you while you stand in it and stand down when you leave. The mood reads on screen: crossing a district boundary raises a toast — `RIVERSIDE — wary`, `MARKET — your street`.
- **Shopkeepers recognise you**: prices move with how the district feels — high rep **−15%** ("Good to see you, friend. Friend prices."), bad rep **+15%**, a hostile district +15% more, four-star heat adds +10% ("You're not wanted here. Everything costs extra."). Greetings quote what **witnesses remember**: "They say a body dropped in the market."
- **Witness memory**: every violent event in a district is remembered (last 8) with a timestamp, quoted by shopkeepers and stored in the save.
- **Graffiti of your nickname** goes up as reputation grows — Label3D spray-text on each district's wall: your tag at 25, `THE NEW HANDS WAS HERE` at 40, `THE NEW HANDS RUNS THE FOUNDRY` at 75 — and `THE NEW HANDS GO HOME` when a district turns hostile. All of it persists (rep, hostility, witnessed events, nickname) through the safehouse save.
- Heat and City now talk: violence reports carry positions, so a gunshot in the foundry heats the police *and* sours the foundry.

**How to test on a phone**

1. Knock the thug down repeatedly around x < −6 (riverside): watch the toast moods sour, then the district turn hostile — two locals shadow you until you leave.
2. Slam someone stylishly in the market and check the toast: the mood warms. Buy your way back into riverside with clean stylish wins.
3. Enter the tailor after being violent nearby: the greeting quotes what witnesses saw, and prices are up. Earn rep in that district and the same coat costs 15% less.
4. Get foundry rep to 40+ (stylish wins) and look at the east wall: your name is on it. Save at the safehouse, reload — the tag is still there.

**Not verified on a real phone**: graffiti legibility (Label3D at 4 px scale — size and colour want eyes on a real screen), toast pacing, and whether the hostility threshold feels fair in live play.

**Added beyond the brief**: districts buying back with good will, hostile graffiti ("GO HOME"), the district-crossing toast, and witness quotes in every greeting.

**GATE (Phase 6)**: `tests/smoke_city.tscn` — **27 checks green**: district math, rep costs per event in the right district only, stylish-win recovery, hostility threshold + muscle summoned while present + stood down when leaving + buy-back, graffiti tiers at 40/80 (real Label3D on walls), toast with district and mood, price tiers (0.85×/1.15×/heat +10%), greetings by rep with witness recall, and rep/hostility/witness/nickname persistence through save. Economy, ledger and combat suites still green (the economy suite now resets city state — its own violence was, correctly, repriced). **GATE: PASS (headless).**

## SERIES 2 · Phase 7 — Characters with Faces (IN PROGRESS, UNVERIFIED)

**Status: code pushed, wow gate NOT passed.** The session's time budget ran
out while debugging the cast smoke test. What is in this commit:

- **Four cast members** (`scripts/cast.gd` + `scripts/npc_rig.gd`), each built
  from real rigged UBC pieces recoloured to a colour identity: **Velvet**
  (crimson, at her gun counter, rep-aware lines, her talk hands off to the
  pawn counter), **Pilsner** (teal, the hacker, code-built glowing glasses),
  **Marrow** (dried-blood, the Knuckle Room boss — name is a placeholder: the
  original design notes never arrived, so anything beyond the brief's names
  is flagged), **The Duchess** (gold + circlet, watching from the annex roof).
- **The noir dialogue system** (`scripts/dialogue.gd`): portrait block with
  the speaker's colour and initial, typed text, tap to finish/advance,
  gameplay input locked, music ducked, and a **clean voice hook** per line
  (`Dialogue.line_started` + a Voice-bus player that plays
  `assets/voice/<id>_<n>.wav` when a recording exists).
- **Recordings to supply** (mono WAV 44.1 kHz, named exactly):
  `velvet_01..03.wav`, `pilsner_01..02.wav`, `marrow_01..02.wav`,
  `duchess_01..02.wav` in `bare-hands/assets/voice/`.

**Fixed in the phone-fix session** (see the next section): the frozen NPC
outfit skeletons (the visible T-pose), the GRAB-to-dialogue input race, and
the NPC players that never played. The cast suite now passes in full
(30 checks) alongside the new pose suite that proves the bones move.
**GATE: PASS (headless) — after the fix session.**

## FIX SESSION — Phone Report 1: T-pose, wet ground, polish

**Problem 1 — T-POSE (blocker). ROOT CAUSE (three faults, one symptom):**

1. **The library load was a runtime string `load()`** of
   `res://assets/UAL1_Standard.glb` in `hero_rig.gd` and `npc_rig.gd`. In an
   exported phone build that remap can be missing — the load fails, no
   AnimationPlayer ever gets a library, the character stands at rest and
   "slides around" while `is_playing()` checks still passed in the editor.
   The enemy mannequin — the one character the phone report did *not* name —
   references the same glb **statically** in its scene and was spared.
2. **NPC outfits never animated at all**: `npc_rig.play()` returned after the
   first player, so the visible clothing pieces (ranger body/legs, peasant
   top, knight armour) stayed frozen at the rest pose on top of an animating
   base body — reading as a T-posed character.
3. **Track paths used scene-unique names** (`^"Armature/Skeleton3D:pelvis"`),
   which depend on unique-name flags surviving import — fragile across
   export/import pipelines. Bone names themselves were IDENTICAL (all 65,
   verified), so no bone-map retarget was needed.

**The fix** — `scripts/ual_bind.gd`, one shared binder for every character:
the UAL scene is a **`preload`** (a compile-time dependency no exporter can
strip), the library is rebuilt **once** with every track path rewritten to
the plain relative `Armature/Skeleton3D:<bone>` form, and `play_all()` plays
on **every** piece's player in lockstep. `hero_rig` and `npc_rig` now use
it; the enemy mannequin (native binding) is untouched.

**The real pose test** (`tests/smoke_pose.gd`, replaces the old
"was playing" checks): for each character — hero (6 skeletons), enemy
mannequin, Velvet, Pilsner, Marrow, the Duchess — each clip
(Idle/Walk/Sprint/Jump/Punch_Jab) runs 60 frames while the **global poses of
shoulder, elbow, hip and knee on every skeleton** (base AND outfit pieces)
are sampled; a clip fails if the joints stay within 4 mm of rest. The hero
is driven through its real control path (velocity bands, queued jump/punch).
**90 checks PASS.** Sample numbers (max joint travel, metres):
hero Walk shoulder 0.099 / elbow 0.365 / hip 0.092 / knee 0.107 on the
base, and 0.093–0.101 / 0.349–0.367 on every outfit piece; hero Jump
0.632/0.851/0.535/0.278; Punch_Jab 0.189/0.509/0.149/0.267; enemy Punch_Jab
0.171/0.541/0.129/0.373; Duchess Sprint 0.316/0.490/0.136/0.486. (The
detector also caught a test artifact: Punch_Jab is the one non-looping clip
— 0.87 s — so the sampler now restarts it per skeleton.)

**Problem 1b — GRAB-to-dialogue.** Root cause: an input race. Cast, shops,
safehouse and the player each consumed `InputBus.take_grab()` in their own
`_physics_process`; despite `process_priority`, the player's tick won and
the grab vanished into the hero's (empty-handed) grab attempt. Fix: the hero
is now the **single consumer** — `_try_grab_action()` first offers the grab
to people (Cast), then counters (shops), then doors (safehouse), then fights.
Probe-verified: GRAB near Velvet activates dialogue.

**Problem 2 — wet ground.** The camouflage was a value-noise threshold
puddle mask; the "pixelated white blocks" were the five **mirror-puddle
quads** — perfect-metallic squares floating over the road with hard edges
(decal quads, exactly as suspected). The road shader is rewritten: smooth
dark asphalt with a fine low-contrast grain, **five explicit puddles** with
soft feathered edges and organically wobbled rims (same positions and radii
as before), a damp halo around each, **stretched neon streaks** that run
from each sign's ground point toward the camera across the water (fed by
`camera_follow` every frame), broken by a slow animated ripple shimmer, plus
a faint city glow so dark water never reads as a hole. The mirror quads are
gone — replaced by invisible markers that keep the surface-aware footstep
splash system working (audio suite verifies the puddle spots). Lane stripes
dimmed to worn-paint levels; graffiti Label3D forced to linear filtering.

**Problem 3 — polish audit vs the wow gate.** Fixed in code: the hero's coat
rebuilt from two flat slabs into a five-panel fanned skirt (sways with
speed, reads as cloth at distance). Remaining items that still read as
prototype (honest list): the block stance is a slowed Hit_Chest pose (the
UAL pack ships no guard animation); shop counters are stylized boxes with
sign slabs; Pilsner/Marrow/the Duchess stand in plain Idle (no bespoke
idle personality clips in the CC0 library); the Duchess watches from the
annex roof without an arrival/departure moment (that is Phase 8's cutscene
work). Phone-only checks from the gate: 30+ FPS on the 13 mini with DBG
open, the actual look of the new puddles/streaks, haptics (iOS still needs
a plugin), and the audio mix.

**Verification**: all TEN suites green (movement, combat, depth, ledger,
economy, city, audio, music, cast, pose) — 90 pose checks + 30 cast checks
+ the existing 200+; the 5-minute stress re-run on the new code; zero
shader errors on import. **Phase 7's gate moves to PASS (headless).**

## STAGE A — CONTROLS AND FEEL (Master Queue, session 1)

The owner's master queue (Stages A-F) begins with controls. **Missing
input**: `upload/BARE-HANDS-master-design.txt` did not survive into this
sandbox - Stage B's real names/dialogue (and the "Marrow" rename) wait for
it to be re-uploaded. Stage A does not need it.

### A1 - The analog stick
`scripts/stick_input.gd` replaces the old fixed joystick. Raw pull now goes
through **dead zone (15% default) -> rescale -> response curve (expo 1.7) ->
sensitivity -> exponential smoothing (70 ms, instant to zero on release)**,
with a larger travel radius (150 px). Drift/stuck fixes: the stick owns ONE
touch index and ignores every other finger; releasing happens on touch-up,
on `InputBus.locked` (the setter now RESETS input - cutscenes, dialogue,
shops, panels), on window focus loss, on pause, and through a **5-second
stale-finger timeout**. The camera half (right-side drag) only writes yaw
DELTAS, so an idle screen can never turn the camera. Sensitivity, dead zone
and curve are sliders in Settings (persisted in `user://settings.json`).
**`tests/smoke_stick.gd` - 31 checks PASS.** Numbers: 70 px push = 0.187
deflection (slow precise walk), 150 px = 1.000 (full speed); thumb jitter
spread 0.235 (smoothed); **10 s idle: max stick drift 0.00000, camera yaw
drift 0.00000 rad**. Second-finger, mashing, focus-loss, pause-mid-hold and
index-reuse all release clean.

### A2 - Schemes the player chooses
First-run picker (four cards, shows once) and a full Settings screen:
**floating stick / fixed stick / 8-way D-pad / drag-to-move**, right-side
camera drag with a speed slider, optional **auto-sprint at the stick edge**,
optional **8-direction snap**, stick size, HUD opacity, layout presets
(**Classic / Compact / Left-handed** - left-handed mirrors the cluster AND
flips the movement half of the screen) and a **visual layout editor** (drag
any button, +/- size, opacity slider, saved per button). Everything
persists. **`tests/smoke_controls.gd` - 32 checks PASS** (picker, settings,
presets, editor persistence across reload, scheme switching).

### A3 - Buttons you can feel
`scripts/action_button.gd`: buttons are code-built now. Fire on
**touch-DOWN**, hit areas larger than the drawn disc (visual 80% of the
rect), press animation (scale + brighten), a soft **ui_click** tick,
**per-action haptics** through the new `Haptics` autoload (light jab /
heavy / parry double-tick / long super rumble, with strength slider and
master switch - `Input.vibrate_handheld`, Android only; **iOS needs a
plugin, all hooks route through haptics.gd**), **cooldown rings** on
PUNCH/DODGE that drain as the swing completes, input buffering (the 400 ms
queues) and the dodge cancel window kept. **Measured touch-to-action
latency: 13.4 ms** (simulated at 60 Hz physics; the debug panel can show it
live via `InputBus.latency_msec`).

### A4 - Combos and super strikes
Direction + PUNCH now picks the move: **forward lunge cross** (stick
forward + tap), **backfist counter** (stick back + tap - counts as a
counter on an attacking enemy), **uppercut launcher** (stick back + hold -
charges back, then rises INTO the enemy; launches for juggles). Fist list:
jab->cross->hook chain, heavy hook, lunge, backfist, uppercut, finisher,
wall slam. Pipe list: swing, backhand, overhead slam. A soft-lock
**engage-range** fix makes every lunge close toward the nearest enemy
(even from out of punch range). On-screen **combo counter** (hits, decay,
move name). **SUPER meter**: +4 per landed hit, +14 per parry, +10 per
takedown; when full the SUPER button breathes - the strike spends the
whole bar for slow motion, a screen flash, a camera punch, a long haptic
rumble and a **2.6 m shockwave** that flattens everyone in reach.
**MOVES screen** in the pause menu (from `scripts/moves.gd`), the training
dummy is staged by the suite, and **first-time prompts** fire once per
move (persisted). **`tests/smoke_a4.gd` - 25 checks PASS.**

### A5 - Visual bugs
The white pixelated blocks were the mirror-puddle quads (removed in the
fix session). This pass audited every remaining emissive slab: **lit
windows dimmed to 55% and given a soft additive spill** (light blooming
down the wall), **kiosk signs dimmed and given a lit-awning glow**, **bloom
halos behind all three neon signs** - no hard emissive rectangle remains.
The enemies' orange glow: **not a stuck flash** - the hit-flash decays
correctly (6x/s); what glows orange-red is the *intended* attack telegraph
(pulsing during wind-up). The audit did find a real bug: the flash loop
overwrote the intended per-kind silhouette edges (gunmetal/boss), so they
never showed - now the faint edge survives (emission energy = flash +
edge). **Pose suite re-run: PASS** after every change (90 checks).

### How to test Stage A on a phone
1. First launch: the four scheme cards appear - pick one, play, force-quit,
   relaunch: the picker must NOT return (Settings > first_run_done).
2. Move: small pushes walk slowly, full edge sprints (or Settings >
   auto-sprint). Rest a thumb on the stick 10 s: zero drift, camera still.
3. Multi-touch: hold the stick, mash PUNCH/DODGE with other fingers, drop
   a second finger on the stick - no stuck movement. Open the pause menu
   or answer dialogue mid-hold: the hero must stop dead.
4. Settings: try every scheme; drag buttons in EDIT LAYOUT, resize, set
   opacity, force-quit, relaunch - the layout must persist. Left-handed
   preset flips stick and buttons.
5. Combos: forward+PUNCH lunges; back+PUNCH backfist; back+hold uppercut
   (watch the dummy fly); fill the SUPER ring and press SUPER.
6. Feel: every button ticks and buzzes (Android); cooldown rings drain;
   the MOVES screen lists everything.

### Stage A gate
All **thirteen** suites green (movement, combat, depth, ledger, economy,
city, audio, music, cast, pose, stick, controls, A4 - 88 NEW checks this
stage on top of the existing battery) plus the 5-minute stress re-run.
**GATE: PASS (headless).** Phone-only: the actual feel of the curve and
haptics, real finger latency (the 13.4 ms number is simulated at 60 Hz),
iOS vibration (needs a plugin), and whether the glows read well on OLED.

## COMBO PROGRESSION PASS (master queue interlude, before Stage B)

**Parts 1-3 shipped; PART 4 (phone-photo fixes) NOT STARTED - see below.**

### PART 1 - Face-button layout (commit 83ea5d0)
New control scheme beside Classic: the console diamond (A light punch /
B heavy punch / X kick / Y grab-throw) with smaller JUMP/DODGE/SPRINT/LOCK
beside it. Chosen in Settings and the first-run picker; captions under the
letters; SUPER appears only when the meter is full (face scheme). The
layout editor, presets and left-handed mirror cover both schemes. **The
kick is built in code** (`ual_bind.gd _kick_clip` - no CC0 kick clip
exists in the pack; thigh/calf/foot keyframes on the pack's own rig; noted
in CREDITS.md). Also fixed: a queued action pressed during a landing
settle dip is no longer silently dropped (input buffering).
`tests/smoke_face.gd` 31 checks PASS.

### PART 2 - Button-sequence combos (commit a56dcc8)
`ComboInput` autoload: presses land at FINGER time with stick direction;
0.5 s window; longest-match with pipe variants beating same-length fist
strings. `combo_table.gd` (one file, 16 combos): 13 fist combos including
the **A,B,A SUPER PUNCH**, RISING KNEE launcher, X,X,X TRIPLE THREAT kick
string, **Y,B POWERBOMB grab-to-throw** (arms while the grab closes),
SPIN BACKFIST, f+B RISING DRAGON, CYCLONE (360 AoE), BULL RUSH, LIGHTS
OUT finisher and the SIX-SHOOTER capstone, plus 3 pipe combos - each with
its own anim beats, camera punch, sound and haptic. Anti-mash: repeats
scale 1.0/0.6/0.36 (floor 0.35) within 12 s; three different combos in
10 s pay a variety style bonus. Noir input strip: last presses as chips,
landed names flash. Strings track their target so beats connect.
`tests/smoke_combos.gd` 39 checks PASS.

### PART 3 - Levels and unlocks (this commit)
`Progression` autoload: XP from hits (+1), parries (+4), takedowns (+8),
varied strings (+3), missions (+25, the Stage B/C hook). **Level 1 has NO
combos - single presses only**; first unlocks at level 2, spread through
level 15. Perks: combo cancels at level 5, a widening input window (capped
+0.2 s), a wider SUPER shockwave (capped +30%). Level-up moment: banner
with the new move's name + its sequence demoed chip-by-chip on the input
strip, a sting and a haptic. Save v3 persists level/xp (v2 saves load at
level 1). The MOVES screen is generated from the table (locked = greyed
"Unlocks at level N"; unlocked = sequence + PRACTISE which stages the
dummy and demos the input). The **Knuckle Room trainer placeholder**
stands by the dummy (a silhouette with the hook `try_train`; Stage B/C
replaces it with the real fight-club content). `tests/smoke_progression.gd`
23 checks PASS.

### PART 4 - NOT STARTED
The four phone-photo fixes (distant T-pose, white pixelated block stacks,
figures floating near the HUD, blown-out white neon) have NOT been
touched this pass - they were below Parts 1-3 in the queue order and the
session ran out of budget. Next session starts there, then the full
battery + stress re-run.

### Pass verification status
smoke_face 31, smoke_combos 39, smoke_progression 23 PASS; smoke,
smoke_combat, smoke_depth, smoke_a4, smoke_controls, smoke_stick re-run
green after each part. The FULL battery + 5-minute stress have NOT been
re-run as a complete set this pass (they were green at Stage A; the next
session must re-run them with Parts 1-3 in). Phone-only: the feel of the
diamond under real thumbs, the kick's read, the banner's legibility,
iOS haptics.

### The Universal Animation Library pack

`bare-hands/assets/` holds `UAL1_Standard.glb` (the Godot-ready, root-motion-disabled variant), the pack's `License.txt` (**CC0 1.0 / public domain, models by @Quaternius**) and its `README.txt`. The `_RM` (root-motion) variant and the Unity `.fbx` files stay in the original zip at the repo root; this game moves the character in code.

The pack contains one rigged mannequin (65 bones, 2 materials, no textures — light) and **43 clips**. Locomotion: `Idle`, `Walk`, `Walk_Formal`, `Jog_Fwd`, `Sprint`, plus crouch and swim loops. Jumps: `Jump_Start`, `Jump` (air loop), `Jump_Land`. Action: `Roll`, `Interact`, `Push`, `PickUp_Table`, `Fixing_Kneeling`, `Dance`, `Sitting_*` (3), `Driving`, `Hit_Chest`, `Hit_Head`, `Death01`. Weapons/magic (for later batches): `Pistol_*` (5), `Sword_*` (2), `Spell_Simple_*` (4), `Punch_Jab`, `Punch_Cross`, `A_TPose`.

**There is no climb, ledge-hang or mantle clip in the pack** — the grab and pull-up in this batch are faked with code (the hero plays the air pose while being pulled up, then lands).

## Run it on your phone

### iPhone 13 mini (the target device)

1. Install **Xogot — Godot for iPad & iPhone** from the App Store (free tier is enough; it is a native Godot editor showcased by godotengine.org). Xogot cannot run native-code plugins or .NET — this project uses neither, so that's fine.
2. In Safari or the GitHub app, open <https://github.com/jamesrudh-arch/Barehands> → **Code → Download ZIP**. Extract it with the Files app (tap the zip). You should end up with a folder containing `bare-hands/project.godot`.
3. Open Xogot → import/open project → pick `bare-hands/project.godot`. The first import compiles the shaders and the character (about half a minute on an A15).
4. Press **Play**. The game runs fullscreen in landscape.

If you ever have a Mac, the official route is exporting an IPA with Xcode (see Godot docs, "Exporting for iOS") — but you don't need it just to test.

### Android (unchanged from Batch 1)

Install the **Godot Engine** editor app (4.7.x) from Play Store, get the repo ZIP the same way, import `bare-hands/project.godot`, press Play.

## How to test each move on the phone

Do these in order; each takes a few seconds.

1. **Idle** — touch nothing. The mannequin breathes and shifts weight (`Idle` clip, crossfaded in 0.25 s).
2. **Walk vs run by stick distance** — push the left stick a little: a relaxed walk (~1.8 m/s). Push it all the way out: a run (~5.2 m/s) with the sprint animation. The model always turns to face the direction it moves; speed builds up and bleeds off smoothly.
3. **SPRINT** — hold the cyan SPRINT button with a full stick: ~7 m/s, arms pumping. Release the button to drop back to run.
4. **JUMP** — tap the amber JUMP button: crouch-launch (`Jump_Start`), airborne tuck (`Jump`), landing recovery (`Jump_Land`). Jump height is ~1.2 m — enough to hop straight onto the 1.1 m street crates.
5. **Ledge grab + pull-up** — stand about a body-length from the **crate at the east sidewalk** (x≈7, z≈−8), face it and jump *into* the wall while pushing the stick forward. Near the top of the jump the hero grabs the edge (short freeze, ~0.1 s), then pulls up onto it over half a second. If you jump too early you just bounce off — try again slightly closer.
6. **East rooftop route** — from that first crate: jump-grab onto the 3.4 m annex, from there onto the 5.7 m annex, then jump-grab the big building's roof edge at 8 m. Total: ground → 1.2 → 3.4 → 5.7 → 8.0 m. You can also simply drop off any roof — fall damage isn't in yet.
7. **West garage route (slope + gap)** — walk up the wooden **ramp** west of the garages (x≈−16, z≈7): the hero walks the slope and the camera keeps framing without jerking. On the first garage roof, hold SPRINT and jump the **2.5 m gap** to the second garage. Hop the AC unit on top. The camera never clips into the buildings behind you — watch it pull in when you stand with a wall at your back.
8. **Kiosk route** — at the east kiosk with the red sign (x≈14), jump-grab from the crate onto its 3.5 m roof.
9. **Camera vs walls** — run at any building and stop just short: the camera shortens its boom instead of sinking into the wall. Climb any roof and walk near the edge: you stay framed, the camera follows your height.

## How to test each combat move on the phone

The combat buttons sit in a 2×2 thumb cluster, bottom-right: **PUNCH** (red, corner), **DODGE** (white, left of it), **JUMP** (above punch), **SPRINT** (above dodge). The training dummy stands beside the street crate just north-west of spawn.

1. **Jab** — walk to the dummy and tap PUNCH: a quick `Punch_Jab`, a 0.07 s hit-stop, a white flash on the dummy, a small amber spark, a tiny camera nudge. The dummy staggers back and plays `Hit_Chest`. Watch the style meter (top-right) tick up.
2. **Jab → cross combo with buffering** — tap PUNCH, then tap PUNCH again *while the jab is still swinging*: the cross chains automatically (`Punch_Cross`, hits the head, `Hit_Head`, heavier knockback and hit-stop). You don't need frame-perfect timing — the press is buffered for 0.35 s.
3. **Style meter & repetition** — land the jab→cross, then dodge an attack, then jab again: varied chains climb D→C→B→A→S and the cash multiplier rises (×1.0→×3.0). Now jab the dummy five times in a row: the meter barely moves — repetition earns a fraction. Leave it alone and the meter decays.
4. **Parry (the big one)** — walk west to the **thug** near the ramp. Let him approach; he pulses red for ~0.6 s (telegraph), then swings. Tap **DODGE just before the swing lands** — the world drops into slow motion for 0.7 s, the thug staggers with a cyan flash. Immediately tap PUNCH: a counter-hit that knocks him flat (`Death01`). If you dodge too early he still misses you (invincibility frames) but there's no slow motion — that's the difference between a dodge and a parry.
5. **Getting hit** — stand still and let the swing land: the hero takes `Hit_Chest`, a knockback and a short stagger. Nothing permanent yet (no health system).
6. **Environmental slam** — the dummy spawns beside the street crate. Stand east of it so the crate is behind it, then land a **cross** (PUNCH, PUNCH): the dummy is slammed into the crate — longer hit-stop, orange spark, bigger shake, +35 style. Works against any wall too: corner the thug against a building and cross him. Jabs never slam — only heavy hits (cross or counter).
7. **Counter into slam** — parry the thug next to a wall or crate, then punch: the counter is also heavy, so a counter with an obstacle behind him is an instant takedown.

## Project layout

```
bare-hands/              Godot project root
  project.godot          Mobile renderer, landscape, autoloads (InputBus, Fx), punch/dodge keys
  assets/UAL1_Standard.glb   the animation pack's character + 43 clips (CC0)
  assets/License.txt         keep this with the model (CC0, by @Quaternius)
  scenes/main.tscn       street block, parkour props, dummy + thug, camera, HUD
  scenes/player.tscn     the hero: capsule body + scaled, 180-degree-fixed mannequin
  scenes/enemy.tscn      shared enemy rig (mode 0 dummy / mode 1 thug)
  scripts/input_bus.gd   shared touch-input bus with expiring queues (autoload "InputBus")
  scripts/log.gd         file logger -> user://barehands.log (autoload "Log")
  scripts/fx.gd          hit-stop / slow-mo / particles / shake + sound hook (autoload "Fx")
  scripts/joystick.gd    the touch joystick
  scripts/touch_buttons.gd  JUMP/SPRINT/PUNCH/DODGE buttons + hint label
  scripts/style_meter.gd style rank, repetition penalty, cash points
  scripts/debug_panel.gd toggleable DBG overlay (FPS, memory, nodes, enemies, particles)
  scripts/player.gd      movement, ledge grab, punch combo, dodge/parry, counters, slams
  scripts/enemy.gd       dummy reactions, thug AI with telegraph attack, parry resolution
  scripts/camera_follow.gd  cinematic follow camera: shoulder offset, lag, FOV kick, push-in, lock-on, shake
  scripts/opening_shot.gd  the ~7 s skippable opening flyover with letterbox
  scripts/hero_rig.gd      the noir hero: 6 UAL-rigged pieces in lockstep + fedora + swing coat
  scenes/hero.tscn         hero piece composition (body, ranger outfit, beard)
  tests/smoke.tscn       headless movement+camera smoke test (not part of the game)
  tests/smoke_combat.tscn   headless combat smoke test (not part of the game)
  tests/stress_combat.tscn  5-minute self-driving combat stress test (not part of the game)
```

## Performance notes (iPhone 13 mini)

Three skinned characters (the same 65-bone, textureless mannequin instanced three times), three neon point lights plus a dim moon, no shadow maps, MSAA 2x, glow + fog, and CPU particles only on hits. That is far below what an A15 can do — expect a solid 60 fps. If a fresh install stutters for the first seconds, that is shader compilation, not the game.

## Troubleshooting

- **Portrait / sideways**: the game asks for landscape; unlock auto-rotation.
- **Very dark screen**: it is night — walk toward the neon.
- **Buttons or stick in the wrong spot after rotating**: they are anchored to the screen corners; re-lock landscape.
- **Grab feels unreliable**: you must be *moving into* the wall while airborne, with the ledge between 0.45 and 2.6 m above your feet. Run at it from about a metre away and jump. A one-time hint appears the first time you stand near a climbable edge.
- **Import fails in Xogot/Godot**: make sure you picked `bare-hands/project.godot`, not the repo root.

## Sync this repo

The remote is <https://github.com/jamesrudh-arch/Barehands> (branch `main`). From a machine with push access:

```
git push origin main
```

To pull the next batch onto the phone: re-download the ZIP and replace the `bare-hands/` folder, then reopen the project (it re-imports changed files automatically).

## Verified / not verified

- Verified headless with Godot 4.7.2 (this sandbox): the project imports clean; movement+camera smoke (27 checks incl. FOV kick, push-in, lock-on, opening skip), combat smoke (17 checks incl. parry slow-mo, counter knockdown, crate slam), and the 5-minute stress test (18,000 ticks, flat node count, time_scale always recovers, 53 landed impacts) all pass after every phase. Movement (`tests/smoke.tscn`): mannequin 1.70 m, **faces its travel direction (hand bones checked against the movement vector, north and south, plus the climb pose facing the wall)**, analog speeds, sprint, jump clips, ledge climb onto the 3.4 m annex, the one-time climb hint near a grabbable edge, camera follow and wall pull-in. Combat (`tests/smoke_combat.tscn`): jab→cross lands with buffering (dummy 5→2 hp) and knockback, punch clips play, per-enemy materials don't cross-flash, repeating a move earns less, a well-timed dodge triggers slow motion and the parry counter knocks the thug down, a cross with the crate behind the dummy slams it (takedown), and `Engine.time_scale` always returns to 1.0.
- Not verified on a real phone (no device here): touch feel of the stick and the four buttons, hit-stop/slow-mo/shake actually *feeling* right (timings were tuned headless, by numbers), framerate and thermals on the iPhone 13 mini, enemy telegraph readability, and Xogot's import flow on iOS. Tell me what feels off and the next batch tunes it.
