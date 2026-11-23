# 04 — TECHNICAL DECISION LOG

> Every architectural decision for the rebuild, with its authority:
> official documentation actually opened (URL + what it said), proof
> tests run in this repo, or in-repo device evidence. No invented APIs.
> New decisions are appended; old ones are never silently changed (a
> change gets a new dated entry saying why).

## D1 — Engine and renderer: Godot 4.7.2, Mobile renderer, Metal
**Decision**: build on the Mobile renderer (`rendering_method=mobile`),
landscape, as the project already does.
**Authority**: official "Overview of renderers"
(https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html,
opened 2026-11-23): Mobile targets mobile/desktop, requires a
RenderingDevice backend (Vulkan, Direct3D 12 or **Metal** — Xogot's
path on iOS), carries "most rendering features" vs Forward+'s "all",
with advanced features "limited by mobile hardware". Forward+ is
explicitly "poorly optimized" on mobile; Compatibility lacks advanced
features.
**Constraint adopted**: design materials/effects inside Mobile's
limits — the V3's verified findings hold: limited default HDR
precision (set `rendering/viewport/hdr_2d` deliberately), emission
energy kept ≤ ~2.0, no SSR, glow thresholds tuned for Mobile, one
post pass.

## D2 — Character animation pipeline: rigged GLB + retargeted AnimationLibrary
**Decision**: characters are real rigged glTF models; the Universal
Animation Library (UAL1_Standard, already in-repo) supplies the base
animation set, retargeted through Godot's documented BoneMap /
SkeletonProfileHumanoid system onto each character rig. Per-style and
per-character animation variations blend in an AnimationTree.
**Authority**: official "Retargeting 3D Skeletons"
(https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html,
opened 2026-11-23): animations bind to bone NodePaths + REST
transforms, so sharing requires matched bone names AND rests; the
importer's Retarget section exposes `bone_map` on Skeleton3D;
`SkeletonProfileHumanoid` auto-maps humanoid rigs (English bone names
recommended); Remove Tracks / Bone Renamer / Rest Fixer options exist
specifically for shared AnimationLibrary imports.
**Asset facts**: UAL zip contains `Unreal-Godot/UAL1_Standard.glb`
(root-motion and `_RM` variants; `License.txt` = **CC0 1.0, models by
@Quaternius**). UAL ships two files: `_RM` has root motion baked in —
use the non-RM for in-place locomotion unless root motion is wanted.
**Fallback**: if a character model fails the ASSET DEVICE TEST on
iPhone, a code-built lit fallback takes over (V3 PART 3B) — but the
goal is real assets passing.

## D3 — Device-safe asset delivery: commit NATIVE resources
**Decision**: every adopted 3D asset is converted once in the sandbox
to native Godot resources (`.res`/`.tscn` via `ResourceSaver`, meshes
+ materials + embedded textures) and committed; the phone loads them
with `load()` and needs **no import cache**. Fresh-import GLBs
previously failed to appear on iPhone (V3 PART A2 #4 — device
evidence); native resources are the documented workaround used by
this project since.
**Status**: PROOF REQUIRED — a small conversion + load test
(ResourceSaver → .res → headless load → render check) runs in the
sandbox before the character pipeline is committed to. The ASSET
DEVICE TEST (debug spawn + visible-pixel report) gates adoption on
the phone.
**Doc reference (API)**: ResourceSaver.save(), ResourceLoader.load()
— class references under
https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html.

## D4 — Vehicles: VehicleBody3D + VehicleWheel3D
**Decision**: player-drivable cars use the engine's documented raycast
vehicle system; arcade handling profiles (per-vehicle engine force,
steering speed, brake curves) as data.
**Authority**: official class reference
(https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html,
opened 2026-11-23): control via `brake`, `engine_force`, `steering`;
one `VehicleWheel3D` node per wheel; body mesh WITHOUT wheels; forward
is `Vector3.MODEL_FRONT`; keep the origin low for grounding. The docs
state: "This class has known issues and isn't designed to provide
realistic 3D vehicle physics. If you want advanced vehicle physics,
you may have to write your own physics integration using
CharacterBody3D or RigidBody3D." — accepted: the game wants readable
arcade driving, not simulation; a custom RigidBody3D integration is
the recorded escape hatch if VehicleBody3D proves unworkable.
**Traffic**: AI cars are NOT physics vehicles — they follow the
navigation graph with kinematic movement (cheaper, stable), as in
genre standard open worlds.

## D5 — NPC and crowd navigation: NavigationAgent3D on a baked navigation mesh
**Decision**: pedestrians, crowd and traffic route via
NavigationAgent3D (RVO avoidance for crowds) over per-area baked
navigation regions; the green guide reuses the same graph data for
routes (2D AStar on the street graph remains for the map screen).
**Authority**: official class reference
(https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html,
opened 2026-11-23): agent pathfinds to `target_position` avoiding
static and dynamic obstacles; RVO avoidance computed before physics;
`get_next_path_position()` must be called once every physics frame;
avoid calling path-triggering methods inside agent signal callbacks
(use `call_deferred`) — the class is flagged **Experimental**
(recorded; acceptable for this scale, isolated behind one wrapper
system so a future API change touches one file).

## D6 — Input: one InputMap + raw multi-touch UI driving the same actions
**Decision**: exactly ONE authoritative input layer: project InputMap
actions (move, camera, punch/heavy/kick/dodge, guard, grab, sprint,
jump, lock, style, phone, interact, vehicle drive set, weapon set)
fed by (a) the touch controls (floating sticks + X/Y/A/B diamond +
pills, multi-touch, safe-area aware) and (b) a Bluetooth controller
map. On-screen buttons are generated FROM the action table so labels
and actions can never disagree.
**Authority (in-repo device evidence)**: the two-thumb layout +
simultaneous stick/button multi-touch was verified working on the
owner's iPhone in B23 (V3: "B23 finally showed my hero, pedestrians,
cars and lamps"), and the X/Y/A/B diamond (OVERRIDES-R1R4 build) is
suite-asserted (smoke_controls 55 checks). Raw touch handling =
InputEventScreenTouch/ScreenDrag as the existing touch layer uses.
**Doc reference (API)**:
https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html
(touch/mouse gestures; not re-fetched — the mechanism is in-repo
proven).

## D7 — Scene/world management: six area scenes swapped with a fade
**Decision**: one PackedScene per area (warehouse+yard, neighbourhood,
club district, docks, airport, second city), instanced one at a time
under a persistent Game root that owns the player, HUD, autoload
state and the fade; travel through gates/taxi/plane triggers
`Game.travel(area_id, spawn)`. No streaming soup, no side-by-side
worlds.
**Authority (in-repo evidence)**: the R1–R4 build already boots into
warehouse.tscn and fades to main.tscn through the visible gate
(smoke_warehouse 28/28) — the fade-swap pattern is proven on device
by earlier builds; per-area scenes are the V3 PART W requirement
(only the current area in memory).

## D8 — Audio: buses + CC0 files, TTS voices with subtitle fallback
**Decision**: six buses (Master/Music/Ambience/SFX/Voice/UI) with
compressor+limiter on Master; the mastered CC0 file bank (Kenney +
offline-mastered synth, licences in assets/audio/*.txt) is the
primary source; TTS (DisplayServer.tts_*) for narrator and phone
voices with subtitles always and a radio-babble fallback.
**Authority (in-repo)**: the bank exists, is licensed, and the V3
A3 sanity pass (clipping/DC/loop-seam audit, tools/audio_audit.py)
is the gate; narrator.gd already uses the TTS API in-repo. Doc
reference: https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html
(listed in the official Audio TOC opened today).

## D9 — Art direction: stylized neon-noir, one coherent look
**Decision**: ONE art direction across characters, vehicles, city,
UI: Quaternius-style stylized humanoids (matching the UAL rig),
Kenney/Quaternius stylized kits for the city and vehicles dressed in
a unified material pass (the project palette: ink #05060F, magenta
#FF007F, cyan #00F0FF, sodium orange practicals), consistent scale,
thin rim/edge lighting, wet streets. No mixed unrelated styles; every
model re-materialed to the palette if its source colours clash.
Full detail in the ART_DIRECTION section of 03_TECH_ARCHITECTURE.md.

## D10 — Scope reconciliations (recorded, not silent)
1. Bible "one district, 3 blocks, no open world" → **superseded** by
   the stop directive's connected open-world six-area Cinder City
   (V3 PART W defines the six areas). [R]
2. Bible "always night always rain" → day/night cycle + weather; the
   neon-noir night is the signature look. [R]
3. Bible "no guns yet / Weapon style later" → full weapon handling
   (melee + the Corporation firearms path) is in scope for the
   rebuild; the five styles include Weapon. [R]
4. Bible "no fast travel" → taxi fast-travel between unlocked areas
   (V3 PART W). [R]
5. Old InputBus queued-action architecture → replaced by the one
   InputMap layer (D6); the old files are deleted when the new input
   system lands, not kept alongside.

## D11 — Open items requiring proof before commitment
- **D3 proof**: ResourceSaver native conversion + device test (the
  pipeline's first milestone; blocks the character pack adoption).
- **UAL retarget proof**: import UAL1_Standard.glb, retarget onto the
  chosen character rig via SkeletonProfileHumanoid, verify one
  animation plays headless + renders.
- **Quaternius character pack**: download + licence + quality
  inspection (in progress — see 05_ASSET_REGISTER.md).
- **City kit breadth**: on-disk Kenney kits hold ~20 building GLBs —
  insufficient for six areas; source additional CC0 modular
  building/facade packs (Kenney city kit full set, Quaternius
  modular city) and dress them in the unified palette.
