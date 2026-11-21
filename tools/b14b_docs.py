#!/usr/bin/env python3
"""B14b docs: the witness-pin fix, recorded in TESTING/CHANGELOG/STATE."""
import json

BASE = "/home/z/my-project/"

# --- TESTING.md: the pin lesson, appended to the B14 section
s = open(BASE + "TESTING.md").read()
old = (
    "  lessons: a picker built like _scheme_picker needs its own\n"
    "  trailing _refresh() or the glow never lands; `var t :=\n"
    "  TUNING[kind][2]` on an untyped array needs an explicit float."
)
assert s.count(old) == 1, "testing anchor"
add = (
    "\n- **B14b the witness pin**: the B14 battery caught smoke_backroom\n"
    "  and smoke_jobs red - every heat gain landed at x0.6. Cause (not\n"
    "  B14): Heat.add() scales gains by who is watching (bible 4I\n"
    "  crowds-are-witnesses, B12): 0 wanderers near the player =\n"
    "  alley_mult 0.6, 1 = x1.0, 2+ = witness_mult 1.5 - and wanderers\n"
    "  ROAM, so the eye count at assertion time was a dice roll every\n"
    "  heat-asserting suite was silently riding on (the exact-value\n"
    "  1.08 violence check in smoke_economy was the same dice, green by\n"
    "  luck every run). Fix: Heat.test_pin_eyes (default -1 = live scan,\n"
    "  the game untouched); the eight heat-asserting suites pin 1 - the\n"
    "  x1.0 band - so every existing expected number stands exactly as\n"
    "  written. smoke_reactive is NOT pinned: it ARRANGES the eyes\n"
    "  itself (the empty alley x0.6 and the two witnesses x1.5 are the\n"
    "  test). Battery re-run green after the pin."
)
s = s.replace(old, old + add)
open(BASE + "TESTING.md", "w").write(s)
print("TESTING pin note added")

# --- CHANGELOG.md
s = open(BASE + "CHANGELOG.md").read()
old = (
    "- smoke_difficulty: 22 green. Battery 29 green, 0 script errors.\n"
    "  Docs: STATE/TESTING/CHANGELOG."
)
assert s.count(old) == 1, "changelog anchor"
add = (
    "- The witness dice, pinned: Heat.add() scales gains by who is\n"
    "  watching (x0.6 empty alley / x1.0 one pair / x1.5 witnesses)\n"
    "  and wanderers roam - the eye count under any assertion was a\n"
    "  dice roll. Heat.test_pin_eyes freezes it for the eight\n"
    "  heat-asserting suites (the x1.0 band, every old expected number\n"
    "  stands); smoke_reactive keeps the live scan because it ARRANGES\n"
    "  the eyes. Found by the battery going red on two green-in-B13\n"
    "  suites - the game was never wrong, the assertions were riding\n"
    "  luck.\n"
)
s = s.replace(old, add + old)
open(BASE + "CHANGELOG.md", "w").write(s)
print("CHANGELOG pin note added")

# --- STATE.json
d = json.load(open(BASE + "STATE.json"))
d["current_batch"] = (
    "Batch 14 (difficulty knobs + WOW sweep + witness pin) CLOSE-OUT: "
    "final battery running after Heat.test_pin_eyes; next: the vertical "
    "slice review against the bible"
)
d["completed"][-1] += (
    " (B14b post-battery fix: Heat.add's crowds-are-witnesses multiplier "
    "(0 wanderers near = alley_mult x0.6, 1 = x1.0, 2+ = witness_mult "
    "x1.5, wanderers ROAM) made every heat assertion a dice roll - the "
    "B14 battery caught smoke_backroom + smoke_jobs red at x0.6 with all "
    "B13 greens having ridden luck. Fix: Heat.test_pin_eyes (default -1 "
    "= live scan, game untouched); eight heat-asserting suites pin 1 = "
    "the x1.0 band so every existing expected number stands unchanged; "
    "smoke_reactive deliberately unpinned because it ARRANGES the eyes "
    "itself - the empty alley and the two witnesses ARE its test. "
    "Pin-first lesson for future suites: any absolute heat assertion "
    "must pin or arrange the eyes.)"
)
d["next_step"] = (
    "Final battery green -> commit + push + zip bare-hands-batch14.zip, "
    "then THE VERTICAL SLICE REVIEW: walk PROJECT_BIBLE.md top to bottom "
    "against the shipped game (identity/pillars/loops/ethical rules/"
    "combat/borrowing/phone/trust/web of leverage/missions/economy/"
    "kidnap/reactive city/emergence/district/controls/tech standards/"
    "self-testing/scope tiers/balance/batch order), write "
    "docs/SLICE_REVIEW.md with per-section verdicts (SHIPPED / THIN / "
    "MISSING / STRETCH-PENDING) and an honest gap list ranked by player "
    "impact for the owner; fix what fits in a batch before the review "
    "ships."
)
json.dump(d, open(BASE + "STATE.json", "w"), indent=2, ensure_ascii=False)
print("STATE updated")
