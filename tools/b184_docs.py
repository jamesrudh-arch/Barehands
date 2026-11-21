#!/usr/bin/env python3
"""B18.4 docs stamp: update STATE.json (current batch, completed entry,
next step, battery record). Run AFTER the B18.4 code commit exists; the
VERSION.txt stamp is handled separately (needs the code commit hash)."""
import json
import pathlib

STATE = pathlib.Path("/home/z/my-project/STATE.json")

COMPLETED_ENTRY = (
    "B18.4 push + stress leak + CC0 street: (1) all 18 unpushed commits "
    "pushed to origin/main (remote verified 9e8c135, the 18th was the "
    "upload/IMG_9292.png commit 2be1f27); (2) the stress node leak found "
    "by the new STRESS_LEAK_DUMP census - Heat responders and City muscle "
    "erased DOWN fighters without freeing (enemy.gd respawned them "
    "untracked forever); both now drag downed men off after a 2s linger; "
    "stress baseline moved to tick 90 (the old 818 measured before the "
    "deferred placements landed; honest settled street = 1003), quiesce "
    "2.8s, bounds end +28<=60 / spike +68<=160, STRESS PASS; (3) the CC0 "
    "kits integrated - assets/kits/ (Kenney City Kit Commercial/Roads/"
    "Starter + Car Kit sedan, CC0, licence file + CREDITS), scripts/kit.gd "
    "(stretch placement, MultiMesh road rows, lamps with sodium light, "
    "1.1 emission cap, unique names, deferred add), the six main-street "
    "building boxes + sidewalk slabs + box car body + market buildings/"
    "dashes replaced, enemy kinds 1-4 wear Quaternius UBC characters "
    "(UAL clips in lockstep, dummy keeps its mannequin), DEVICE REPORT "
    "CC0 KITS section, LookDev shows the real sedan; measured: draws "
    "280->275, tris ~unchanged, pure-black 74.0->52.6% (hero POV); "
    "smoke_kits 44 checks; battery 36 suites - 33 green in-run, "
    "smoke_depth (stale pipe assertion from B18.3) + smoke_tpose "
    "(mannequin player left idle) fixed + re-run green, render_check "
    "53/56 (3 pre-existing: 2 llvmpipe histogram thresholds improved "
    "not crossed, 1 HUD bar crossing)"
)

CURRENT_BATCH = (
    "Batch 18.4 (PUSH + STRESS LEAK + CC0 STREET) on top of B18.3: the "
    "18-commit push to github (verified), the stress node-count leak "
    "closed with a census-named fix and honest bounds, and the Kenney "
    "CC0 kits + Quaternius UBC enemy characters replacing the "
    "placeholder boxes. Everything is pushed; the phone DEVICE REPORT "
    "is the next judge."
)

NEXT_STEP = (
    "WAIT for the owner's phone results (the DEVICE REPORT text per "
    "XOGOT.md: STAGE 0 BUILD line, CC0 KITS section, COPY LOG) before "
    "adding anything else - owner instruction item 4. On the phone, "
    "judge: the kit street at night (buildings/car/lamps/enemy "
    "characters readable, no blank slabs), the two llvmpipe histogram "
    "fails that the real GPU may already pass (pure-black <55%, "
    "mid-tones >25%), and the stress leak fix (long fights must not "
    "grow the node count). Then back to batch order: THE VERTICAL "
    "SLICE REVIEW per PROJECT_BIBLE.md -> docs/SLICE_REVIEW.md."
)

BATTERY = (
    "2026-11-21 B18.4: 36 suites (33 headless + 3 render). In-run green: "
    "33 incl. stress_combat (final enemy code) and smoke_kits 44/44; "
    "smoke_depth + smoke_tpose failed in-run, fixed in-batch, re-run "
    "green standalone; render_check 53/56 (2 llvmpipe histogram "
    "thresholds improved not crossed - phone judges; 1 pre-existing HUD "
    "bar crossing). Pattern: HOME=<fresh dir> per suite, timeout 420/"
    "600, never killed; tools/b18_battery.sh."
)


def main() -> None:
    d = json.loads(STATE.read_text())
    d["current_batch"] = CURRENT_BATCH
    comp = d.get("completed")
    if isinstance(comp, list):
        # drop any B18.4 draft entry, then append
        comp = [c for c in comp if not str(c).startswith("B18.4")]
        comp.append(COMPLETED_ENTRY)
        d["completed"] = comp
    d["next_step"] = NEXT_STEP
    d["battery_last_full_run"] = BATTERY
    STATE.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    print("STATE.json updated: current_batch, completed +1, next_step, battery")


if __name__ == "__main__":
    main()
