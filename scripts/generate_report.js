// LEVERAGE audit report — content + assembly.
const L = require("./report_lib.js");
const {
  Document, Packer, Paragraph, TextRun, PageBreak, Header, Footer, PageNumber,
  NumberFormat, AlignmentType, TableOfContents,
  buildCoverR1, h1, h2, p, b, t, bullet, caption, table, tcap, img, P, EN, ENH, fs,
} = L;

const SHOTS = "/home/z/my-project/download/overhaul_audit/shots";
const OUT = "/home/z/my-project/download/LEVERAGE_Full_Game_Audit_and_Upgrade_Roadmap.docx";

const body = [];

// ============================================================ 1. EXEC SUMMARY
body.push(h1("1. Executive Summary"));
body.push(p([
  t("LEVERAGE is a connected third-person open-world crime-action drama for iPhone (Godot 4.7, Mobile renderer, Xogot pipeline), built as a compact six-area city rather than an empty vast one. This audit closes out the Stage 5 overhaul: every declared system was re-verified at the final repository state, all fifteen smoke suites pass (314 checks), and the four outstanding visual gates were captured and judged by a vision model. The headline is that the game's CORE tier from the master design is functionally complete: the world sim (beats, weather, rain), the beat-driven economy, the eight-app phone with taxi travel and the Web of Leverage, five learnable combat disciplines, twenty-one chained missions ending in a two-sided moral choice, a reactive city surface, and all six areas including the airport and the Second City."),
]));
body.push(p([
  t("The audit also found and fixed real defects today: rain particles that emitted but never rendered (silently broken on the Compatibility path), a phone body that could push THE CHOICE's buttons below the screen fold on a real device, a touch-UI pill row that clipped its sixth button off-screen, and a calls tab that let an incoming call hide behind whichever app was open. Each fix was proven by probe or suite before it landed. What remains open is honest and specific: no music yet, no measured on-device performance report, a handful of cosmetic defects, and a FULL tier of content systems (hangouts, NG+, localization, accessibility) that the master design schedules after this point."),
]));
body.push(p([
  t("The second half of this document is the upgrade roadmap. It is deliberately built from fresh web research rather than from habit: six primary sources were read in full and are cited with URLs, covering rain rendering technique (a Dontnod Remember Me case study), combat depth design (a Sifu deep-dive), Godot 4 renderer and light budgets (official docs and a GDQuest optimization guide), and the mobile market's monetization research (an arXiv study of 40 top-grossing games plus a 2025 industry outlook). Every recommendation is tied to one of these sources and to a concrete verification step inside the project's existing suite battery."),
]));

// ============================================================ 2. METHOD
body.push(h1("2. Audit Method"));
body.push(p([
  t("Three instruments were used. First, the smoke battery: fifteen suites (world, economy, phone, skills, jobs, leverage, surface, city, story, areas, life, hero, combat, pistol, police) were re-run at the final repository state under the same headless Godot 4.7.2 build as the development sessions, with the asset import cache refreshed first. The battery totals 314 passing checks; every failure encountered during this pass was either fixed in code or, where the engine was proven correct by a dedicated probe, fixed in the suite's own assumptions (documented below)."),
]));
body.push(p([
  t("Second, visual gates: four gameplay frames (rain on the lit street, the MAP app, the BOARD app, and THE CHOICE call screen) were captured at 1280x720 from real gameplay and judged by a vision language model with a fixed rubric. Pixel-truth analysis (luminance histograms and frame differencing) was used wherever the VLM's judgment was uncertain; that combination is what exposed the invisible-rain defect. Third, desk research: six sources were read in full and are listed with URLs in Section 9; nothing in the roadmap is recommended on prior belief alone."),
]));

// ============================================================ 3. INVENTORY
body.push(h1("3. The Game Today — Inventory"));
body.push(p([
  t("The build stands at 56 GDScript files (~13,300 lines) plus 21 data-driven mission resources and 5 combat style resources. The table below is the audited inventory of what actually exists and is verified by suites, not what is planned."),
]));
body.push(tcap("Table 1 — Verified inventory at commit 7c65c8c + today's fixes"));
body.push(table(
  ["System", "Extent", "Evidence"],
  [
    ["Areas", "6 (warehouse, neighbourhood, club district, docks, airport, second city), all travel-connected", "smoke_areas 32, smoke_city 15"],
    ["Missions", "21 chained: m0-m6 story, j1-j10 core jobs, k1-k4 kidnap arc with a two-sided ending", "smoke_story 29, smoke_jobs 27"],
    ["Phone", "8 apps: CALLS (typewriter, voicemail), MAP (taxi), LEDGER, BOARD, MESSAGES, NOTES, CONTACTS+trust, SETTINGS", "smoke_phone2 17, smoke_leverage 17"],
    ["Combat", "5 styles, learned-from-people gating; pistol with debt-ticking bullets; vehicles drivable", "smoke_skills 18, smoke_combat_r 28, smoke_pistol 10, smoke_hero 30"],
    ["World sim", "3 beats/day, day/night phase curves, weather with rain, radio recap", "smoke_world 15"],
    ["Economy", "clean/dirty pools, per-beat interest, laundering windows with drifting caps, midnight premium, hot-block tax", "smoke_economy 34"],
    ["City surface", "NPC schedules, scorch + memorial persistence, boarded shops, crowd thinning, gossip distortion", "smoke_surface 11"],
    ["Police / heat", "scanner heat, THE COPY escalation, the fence scrub, collectors", "smoke_police 14"],
    ["City life", "named locals with schedules, pedestrians with flee, lane traffic, taxi + flight", "smoke_life 21, smoke_city 15"],
    ["Audio", "68-clip bank (procedural + Kenney CC0), 6 buses, ambience bed retuned by weather", "sound audit in every boot log"],
    ["Save", "one slot, world state + area checkpoint, autosave on landing", "save_game.gd, battery green"],
    ["Battery total", "15 suites, 314 checks, all green at final state", "Section 2"],
  ],
  [22, 45, 33]
));
body.push(p([
  t("One caveat belongs in the inventory itself: none of this has been measured on physical iPhone hardware. The suites run under a software-GL compatibility path on Linux, which is exactly why this report treats an on-device DEVICE REPORT (frame rate, thermals, touch feel, load times) as the single highest-priority next action in the roadmap."),
]));

// ============================================================ 4. COVERAGE
body.push(h1("4. Coverage Against the Master Design"));
body.push(p([
  t("The authoritative spec is docs/rebuild/02_MASTER_DESIGN.md. The table rates each of its sixteen sections: COMPLETE means built and suite-verified; PARTIAL means the core is live with named gaps; DEFERRED means the design itself schedules it later (the FULL tier)."),
]));
body.push(tcap("Table 2 — Design-section coverage"));
body.push(table(
  ["Design section", "Status", "Notes"],
  [
    ["1 Identity / pillars", "COMPLETE", "coercion pillar now live via the Web of Leverage; reactive city via the surface"],
    ["2 Loops (2 min / 30 min / 20 h)", "PARTIAL", "2-min fight loop and 30-min Ledger loop live; the 20 h estimate needs content beyond 21 missions"],
    ["3 The six areas", "COMPLETE", "all six built and connected; interior depth (hotel lobby, plane cabin) still shallow"],
    ["4 Cast", "PARTIAL", "hero + 6 named locals + enemies; 40-look parametric pedestrians and voice settings not built"],
    ["5-6 Factions / borrowing", "PARTIAL", "debt pools + interest + escalations live; faction backup calls in-fight not built"],
    ["7 Combat", "PARTIAL", "five styles, tokens, posture, hitstop; grappling teacher, dirty tactics (wall-grab), injuries missing"],
    ["8 Vehicles", "PARTIAL", "drivable sedans + traffic; 8-type roster, damage, entry animation, bus/pickup not built"],
    ["9 Missions (the spine)", "COMPLETE", "21 missions on five templates, choice with permanent consequences"],
    ["10 Phone / Ledger / Leverage", "COMPLETE", "8 apps; BOARD is the game's signature app and is live"],
    ["11 Controls", "COMPLETE", "full touch map + controller mapping; left-handed mirror is a settings stub"],
    ["12 UI / design system", "PARTIAL", "HUD + phone in palette; full pan/pinch map, radar route line, fog-of-war not built"],
    ["13 Audio", "PARTIAL", "68 clips, buses, ambience; no adaptive music score, no TTS narrator"],
    ["14 Onboarding", "COMPLETE", "first ten minutes scripted (m0) and skippable"],
    ["15 Performance / platform rules", "NOT MEASURED", "budgets defined (60/30 fps, 400/250 draw calls) but no device report exists"],
    ["16 Start sequence", "PARTIAL", "title + studio card live; light sweep polish and full cinematic pass pending"],
    ["Ethical hard rules", "COMPLETE", "no energy timers, no pay-to-win, no loot boxes, no daily rewards anywhere in the build"],
  ],
  [28, 19, 53]
));

// ============================================================ 5. VISUAL FINDINGS
body.push(h1("5. Visual Quality Findings (The Four Gates)"));
body.push(p([
  t("Each gate was captured from real gameplay at 1280x720 and judged by a vision model on a fixed rubric. The first pass failed one gate outright and exposed three engine defects; the fixes were made and the gates re-run. The final scores are rain 7/10, MAP 6/10, BOARD 8/10, and CHOICE 7/10, with remaining notes recorded in the defect ledger."),
]));
body.push(h2("5.1 The rain defect and fix"));
body.push(p([
  t("The first rain gate scored 3/10 with 'no rain streaks visible'. A frame-difference probe (dry frame vs rain frame from an identical camera) measured only 0.05% of pixels changing while the particle system reported emitting=true with 340 particles: the rain existed in the scene tree and rendered nothing. Two causes were established. First, the original GPUParticles3D column drew zero pixels on the Compatibility render path used by the test rig. Second, the streak mesh (1.4 cm wide) was sub-pixel thin at street distance, which would have made it invisible even where GPU particles do render. The rain was rebuilt on CPUParticles3D (guaranteed on every renderer including WebGL) with readability-law sizing (5 cm x 90 cm streaks, 600-particle column), and the re-probe measured 8.93% of the street frame changing and 34.4% when looking up into the column. The corrected gate then scored 7/10 with rain streaks, lamps, and HUD all read correctly."),
]));
body.push(img(SHOTS + "/gate_rain.jpg", 500));
body.push(caption("Figure 1 — The rain gate after the fix: streaks read on the lit street (VLM 7/10)."));
body.push(h2("5.2 The choice-below-the-fold defect and fix"));
body.push(p([
  t("THE CHOICE is the game's final beat, and its first gate scored 4/10 with 'no selectable option visible'. The cause was structural: the phone body was a fixed-height column with no ScrollContainer, so a three-line call pushed the SAVE THEM / TAKE THE PAYOFF buttons below the visible panel. On a phone this is a soft-lock of the ending. Three fixes landed: the body now scrolls, answering a ring now forces the CALLS tab forward regardless of the open app, and the panel gained an opaque noir style so world labels stop bleeding through the text. The re-gated screen reads both options with their sub-text at 7/10."),
]));
body.push(img(SHOTS + "/gate_choice.jpg", 500));
body.push(caption("Figure 2 — THE CHOICE after the scroll + tab fix: both options on-screen (VLM 7/10)."));
body.push(h2("5.3 The remaining two gates"));
body.push(p([
  t("The BOARD gate passed at 8/10, reading clue cards, LINKED status, and the hint line cleanly. The MAP gate passed at 6/10 with one real finding: node labels clip at the diagram's right edge (THE AIRPO..., THE DOCKS...), and the taxi buttons truncated their labels before a short-label fix landed mid-pass. The map's core function (six nodes, links, HERE ring, taxi fares) reads correctly. Two cross-cutting notes appeared on every gate: the LOCK touch pill clipped off the right edge of the screen (fixed by anchoring the pill row's end to the safe margin; the sixth pill had been off-screen since the GUN pill joined the row), and the top-right cash readouts crowd the debug tag. Both are in the ledger with severities."),
]));
body.push(img(SHOTS + "/gate_map.jpg", 500));
body.push(caption("Figure 3 — The MAP gate: city diagram + taxi row (VLM 6/10, label clipping open)."));

// ============================================================ 6. DEFECT LEDGER
body.push(h1("6. Open Defect Ledger"));
body.push(p([
  t("Everything the audit found that is not yet fixed, ordered by severity. Severity P0 means blocks a player on real hardware; P1 means visibly wrong or a balance risk; P2 means polish. None of the P0 items is in the shipped interaction path today, but items 1 and 2 are unmeasured rather than proven safe."),
]));
body.push(tcap("Table 3 — Open defects"));
body.push(table(
  ["#", "Sev", "Defect", "Where", "Fix sketch"],
  [
    ["1", "P0", "No on-device performance report; 60/30 fps and 400/250 draw-call budgets unmeasured", "whole build", "Xogot run on iPhone 13 mini + 16, capture fps/draws per area, then budget fixes"],
    ["2", "P0", "Mobile-renderer path never exercised (rig is Compatibility); light-count-per-mesh unknown on device", "rendering", "device report includes light stats; cap per-area omni lights (docs: 8/mesh on Mobile)"],
    ["3", "P1", "MAP diagram labels clip at right edge; taxi row clipped labels pre-fix", "phone MAP", "shrink label font, inset labels, or widen draw rect"],
    ["4", "P1", "No music: Music bus exists, no adaptive score; second city has no own music", "audio", "composer or procedural score layers keyed to tension/area"],
    ["5", "P1", "Grappling discipline has no teacher (last of five styles locked out of reach)", "skills", "the Collector teach mission, same pattern as M2/M3"],
    ["6", "P1", "Combat suite revealed a swallowed style-cycle press once (input-frame flake)", "input", "input buffering (~200 ms) per design section 7 fixes the class"],
    ["7", "P2", "BRAWLER style text low contrast; DODGE hint truncated under B pill", "HUD", "label contrast pass + label truncation fix"],
    ["8", "P2", "Top-right cash readout crowds the debug build tag; DIRTY $0 clips at edge", "HUD", "HUD spacing pass; hide debug tag in release builds"],
    ["9", "P2", "Choice screen could auto-scroll to buttons after typing", "phone", "scroll_to bottom on reveal timer"],
    ["10", "P2", "Flee-gate suite flake (walker choice non-deterministic) was made deterministic, but flee wall-block can still occur in play", "NPCs", "flee direction sampling that avoids the street bounds"],
  ],
  [4, 7, 40, 17, 32]
));

// ============================================================ 7. RESEARCH
body.push(h1("7. Research Findings (Sources Read In Full)"));
body.push(p([
  t("The roadmap below is grounded in six sources read during this audit. Each is summarized here with its actionable finding; URLs are in Section 9. Where a source contradicted an assumption in the project, that is called out."),
]));

body.push(h2("7.1 Rain rendering — the Remember Me case study (fxguide)"));
body.push(p([
  t("Dontnod's Remember Me shipped rain as four scrolling pre-blurred sheets on a half-cylinder around the camera (following Flight Simulator 2004), with per-drop virtual positions so the depth buffer occludes rain behind geometry and rain disappears when looking at the ground. Splashes were decoupled from drops entirely and spawned from a 256x256 depth map shot from above, so splash placement respects cover; crown meshes plus droplet sprites read better than physically-modeled splashes. The whole system cost a constant ~1.7 ms regardless of rain intensity, and wetness was explicitly deferred to a material pass: 'a world wet after it has stopped raining' handled by tweaking BRDF parameters on dry materials rather than new lighting models."),
]));
body.push(p([
  t("For LEVERAGE this reframes the current single-particle-column rain as a three-layer system: the column for near-field parallax, a cheap camera-locked sheet layer for mid-range density that costs the same at any intensity, and ground splash rings that respect the existing scorch/memorial placement code. The BRDF note also matches the current wet-smear decals: a proper wet pass would modulate material roughness/metallic on the street materials when rain is on, which Godot does per-material at no extra draw cost."),
]));

body.push(h2("7.2 Combat depth — the Sifu deep-dive (Steventus)"));
body.push(p([
  t("The Sifu analysis frames depth as a staple/specific split on both offense and defense: a generous omnidirectional dodge is the staple (the 'no single defensive option works against everything' rule), while specific tools carry traits (pushing for crowd control, tripping for knockdowns and weapon drops, superarmor as pseudo-counters). Its enemy discipline rule matches LEVERAGE's design almost exactly: 'never more than 2 enemies attacking at the same time', with cornered players facing hyper-aggression to push environmental awareness. Two lessons stand out: enemy posture should regenerate much more slowly than player posture to reward focused one-target offense, and rewards should be paid inside the encounter (health on takedown) rather than after it, because heal items and end-of-fight grades encourage retreat and grinding."),
]));
body.push(p([
  t("Applied here: the five styles should be audited against the staple/specific split (Brawler as the staple kit; Kickboxing reach, Drunken counters, Grappling control, Weapon power as specifics), the token system should be verified to enforce the 2-attacker cap in practice, and health-on-takedown should be evaluated against the current post-fight noodle-bowl heal, which currently forces a walk back to Old Dee."),
]));

body.push(h2("7.3 Rendering budgets — Godot docs + GDQuest"));
body.push(p([
  t("The official Godot renderer overview confirms the project's Mobile-renderer choice for iPhone (Mobile is the recommended mobile renderer; Forward+ is explicitly 'poorly optimized' there) and states the light caps: omni/spot lights are capped at 8 per mesh on Mobile and Compatibility, with Mobile allowing 256 per view. Decals, particle trails, and SDF particle collision are unavailable on Compatibility; compute shaders work on Mobile with a performance penalty on older devices. GDQuest's optimization guide adds the practical budgets: shadowed omni/spot lights cost 4 extra draw calls per light per object, MultiMesh instances collapse repeated geometry into single draw calls, Godot does no occlusion culling (design levels so whole hidden sections can be visibility-toggled), and consistent 30 fps beats a bouncing 35-50 fps, so the 13 mini's 30 fps lock is the right call if it can be held."),
]));
body.push(p([
  t("One project assumption needs checking against these numbers: the neighbourhood street builds 15 lamp posts with 4 real OmniLights plus hot emissive heads, the club adds 4 avenue lights, and the airport adds 2 floodlights. That is within the per-view budgets, but the per-mesh light cap means any single mesh lit by more than 8 lights silently drops the rest; a device report should print light counts per area, and MultiMesh is the direct upgrade for lamp posts, fence posts, and window bands, which are currently individual MeshInstances."),
]));

body.push(h2("7.4 Ethical monetization — the arXiv 'Playing to Pay' study"));
body.push(p([
  t("A 2025 study of the 40 top-grossing Korean Google Play games found 95% using daily login rewards, 92.5% gacha, 77.5% battle passes, and 62.5% conflict-driven design, with retention and monetization deliberately mutually reinforcing through loss aversion (daily-reward skipping) and sunk cost (first-purchase bonuses that decay to 13%). The paper's ethical core is probability opacity: players cannot verify stated odds, and the authors call for auditable disclosure and consumer protection, warning that pay-to-win pressure 'blurs the line between voluntary spending and compulsion'."),
]));
body.push(p([
  t("LEVERAGE's design hard-rules already refuse every one of these mechanics, and this research converts that refusal from taste to positioning: a premium, one-time-purchase crime drama with mastery-driven retention is a defensible counter-position precisely because the top-grossing chart is saturated with the patterns the study documents. The roadmap keeps it that way explicitly: any future 'engagement' feature must pass the paper's test of not exploiting loss aversion or unverifiable odds."),
]));

body.push(h2("7.5 Market context — GameRefinery 2025 outlook"));
body.push(p([
  t("GameRefinery's 2025 outlook reports genre hybridization as the strongest trend, mobile shooters as the possible breakout category, IP-driven titles growing, and LiveOps 'busy seasons' (multiple simultaneous interconnected events with unified currencies and in-game event calendars) as the standard retention practice. It also notes the uncomfortable fact that incumbent games keep absorbing new features, so 'the room for new mobile games to step in is increasingly difficult'."),
]));
body.push(p([
  t("For a narrative crime game, the honest translation is not to bolt on a battle pass: it is to ship the complete premium experience, then let the game's existing in-fiction systems (radio recap, gossip, the BOARD, new jobs as data files) deliver 'seasons' as free content updates that generate the same return-visit effect without any of the studied dark patterns. The compact-city density (the design's answer to the genre's acreage problem) is the differentiator; the audit's coverage table shows the density systems are exactly the ones now complete."),
]));

body.push(h2("7.6 Compact-city design — Yakuza references"));
body.push(p([
  t("Search-level reading on Yakuza's district design (Kamurocho's walkable density, substories as street-level discovery, style ranks) aligned with the master design's own cited influences (Yakuza 0, The Warriors, Sifu, Better Call Saul) and is reflected in Section 8's content recommendations, but no full article could be opened (paywalled/403), so no specific claim in this report rests on those sources. The combat and density recommendations instead rest on the Sifu and GameRefinery pieces above, which were read in full."),
]));

// ============================================================ 8. ROADMAP
body.push(h1("8. Research-Backed Upgrade Roadmap"));
body.push(p([
  t("Priorities: P0 first (ship-blocking), then P1 (quality and depth), then P2 (polish and the design's FULL tier). Each item names its source and its verification step, so progress on this roadmap stays inside the project's suite-and-gate discipline rather than becoming unmeasured feature work."),
]));
body.push(tcap("Table 4 — The roadmap"));
body.push(table(
  ["P", "Upgrade", "Grounded in", "Verification"],
  [
    ["P0", "DEVICE REPORT: Xogot run on iPhone 13 mini + iPhone 16; capture fps, draw calls, light counts, load and travel times per area; hold 30/60 or cut", "Godot docs (renderer choice, light caps); GDQuest (consistency over peaks)", "report committed as docs/rebuild/08_DEVICE_REPORT.md; budgets enforced in CI where possible"],
    ["P0", "Light + draw-call pass: MultiMesh for lamp posts, fence posts, window bands; verify no mesh exceeds 8 lights on Mobile; visibility-toggle hidden sections", "GDQuest (MultiMesh, 8-light cap, no occlusion culling)", "draw-call count in device report drops; smoke_areas stays 32/32"],
    ["P1", "RAIN v2: three layers (near column + camera-locked sheet + ground splash rings respecting cover), wet-BRDF roughness/metallic modulation on street materials", "fxguide Remember Me (layered rain, splash decoupling, wet BRDF, constant cost)", "frame-diff probe shows rain in all 3 depth bands; VLM rain gate >= 8/10; constant cost verified at two intensities"],
    ["P1", "COMBAT staple/specific audit: verify 2-attacker token cap; slow enemy posture regen vs player; evaluate health-on-takedown vs the bowl", "Sifu deep-dive (staple/specific, enemy posture pacing, in-encounter rewards)", "smoke_combat_r extended with token-cap and posture-regen checks"],
    ["P1", "ADAPTIVE SCORE: tension/area-keyed music layers onto the existing Music bus; the Second City gets its own palette per the design", "design section 13; market context (production value as differentiator)", "audio audit logs layer switches; a smoke_audio suite gates crossfades"],
    ["P1", "GRAPPLING teacher + the fifth style's real identity (control/throws), completing the five-discipline promise", "Sifu (specific tools carry traits)", "smoke_skills extended to 5/5 learned styles"],
    ["P1", "MAP polish: unclip labels, pinch/zoom world map with the fog-of-war layer from the design", "VLM gate 6/10 findings", "re-gate MAP at >= 8/10"],
    ["P2", "SEASONS-as-content: free job/BOARD content packs shipped as data files (missions are .tres already), announced in-fiction via radio + gossip", "GameRefinery (event calendars) minus the studied dark patterns; arXiv (refuse loss-aversion loops)", "jobs suite green per pack; no monetization hooks added"],
    ["P2", "HUD polish pass: contrast fixes, truncation, debug tag hidden in release, cash readout spacing", "gate findings 7-8", "full-screen VLM sweep of HUD states"],
    ["P2", "FULL tier per the design: hangouts (trust economy), NG+ Carried Debt, parametric pedestrian looks (40), localization-ready strings, accessibility (left-hand mirror, sizes, color-blind modes)", "master design sections 4, 11, 12, 2", "each lands with its own suite per the project's law"],
  ],
  [5, 47, 26, 22]
));
body.push(p([
  t("Two recommendations sit above the roadmap because they are decisions rather than work items. First, keep the CPUParticles rain: the research says the layered system's win is constant cost, and CPU particles guarantee identical behavior on Mobile, Compatibility, and WebGL, which removes an entire class of device-specific rain bugs. Second, do not add any retention mechanic that the Playing to Pay study documents as dark-pattern adjacent; the premium positioning is worth more to this game than any engagement chart."),
]));

// ============================================================ 9. REFERENCES
body.push(h1("9. References"));
const refs = [
  ["[1] GDQuest, 'Optimizing a 3D Godot scene' (draw calls, light budgets, MultiMesh, culling, fill rate)", "https://gdquest.com/tutorial/godot/3d/optimization-3d"],
  ["[2] Godot Engine documentation, 'Overview of renderers' (Forward+ / Mobile / Compatibility tradeoffs and light caps)", "https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html"],
  ["[3] fxguide, 'Game environments Part B: rain' (Dontnod Remember Me rain rendering case study)", "https://www.fxguide.com/fxfeatured/game-environments-partb"],
  ["[4] Steventus, 'Deep Design Dive: Sifu' (staple/specific combat design, posture pacing, enemy discipline)", "https://steventus.substack.com/p/deep-design-dive-sifu"],
  ["[5] 'Playing to Pay: Interplay of Monetization and Retention' (arXiv 2504.10714, 2025)", "https://arxiv.org/html/2504.10714v1"],
  ["[6] GameRefinery, 'What to Expect From the Mobile Gaming Industry in 2025'", "https://www.gamerefinery.com/what-to-expect-from-the-mobile-gaming-industry-in-2025"],
];
for (const [label, url] of refs) {
  body.push(new Paragraph({
    alignment: AlignmentType.LEFT, spacing: { after: 100, line: 312 },
    children: [
      new TextRun({ text: label + " — ", size: 22, font: EN, color: "000000" }),
      new TextRun({ text: url, size: 22, font: EN, color: "1B6CA8", underline: {} }),
    ],
  }));
}
body.push(p([
  t("Repository state audited: commit 7c65c8c plus this session's fixes (CPU rain, phone scroll, CALLS tab pull, pill-row anchoring, panel style, taxi labels). Battery: 15 suites, 314 checks green. Gate captures and this report are stored under download/ in the project."),
]));

// ============================================================ ASSEMBLE
const header = new Header({
  children: [new Paragraph({
    alignment: AlignmentType.RIGHT,
    border: { bottom: { style: 1, size: 2, color: P.accent, space: 4 } },
    children: [new TextRun({ text: "LEVERAGE — Full Game Audit & Upgrade Roadmap", size: 16, color: P.secondary, font: ENH })],
  })],
});
const footer = new Footer({
  children: [new Paragraph({
    alignment: AlignmentType.RIGHT,
    children: [new TextRun({ children: [PageNumber.CURRENT], size: 18, color: P.secondary, font: ENH })],
  })],
});

const tocHint = new Paragraph({
  spacing: { before: 120, after: 60, line: 312 },
  children: [new TextRun({ text: "Right-click the table of contents and choose 'Update Field' to refresh page numbers.", italics: true, size: 18, color: "8A8A9A", font: EN })],
});

const doc = new Document({
  styles: {
    default: {
      document: { run: { font: EN, size: 24, color: "000000" }, paragraph: { spacing: { line: 312 } } },
      heading1: { run: { font: ENH, size: 32, bold: true, color: "0A1628" } },
      heading2: { run: { font: ENH, size: 28, bold: true, color: "0A1628" } },
    },
  },
  sections: [
    { // cover
      properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 0, bottom: 0, left: 0, right: 0 } } },
      children: buildCoverR1({
        title: "LEVERAGE — Full Game Audit and Upgrade Roadmap",
        subtitle: "Everyone has leverage on you.",
        englishLabel: "DYOUNGS GAMES",
        metaLines: [
          "Stage 5 overhaul close-out audit",
          "15 suites, 314 checks green at final state",
          "Four visual gates captured and judged",
          "Six primary research sources, cited",
          "Date: 2026-11-24",
        ],
        footerLeft: "D'YOUNGS GAMES",
        footerRight: "Cinder City build 7c65c8c+",
        palette: P,
      }),
    },
    { // TOC (roman)
      properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, bottom: 1440, left: 1701, right: 1417 }, pageNumbers: { start: 1, formatType: NumberFormat.LOWER_ROMAN } } },
      children: [
        new Paragraph({ spacing: { after: 200 }, children: [new TextRun({ text: "Contents", bold: true, size: 32, font: ENH, color: "0A1628" })] }),
        new TableOfContents("Contents", { hyperlink: true, headingStyleRange: "1-2" }),
        tocHint,
        new Paragraph({ children: [new PageBreak()] }),
      ],
    },
    { // body (arabic from 1)
      properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, bottom: 1440, left: 1701, right: 1417 }, pageNumbers: { start: 1, formatType: NumberFormat.DECIMAL } } },
      headers: { default: header },
      footers: { default: footer },
      children: body,
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(OUT, buf);
  console.log("WROTE", OUT, buf.length, "bytes");
});
