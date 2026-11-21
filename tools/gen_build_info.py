#!/usr/bin/env python3
"""B16 build stamp generator.

Run AFTER the code commit, BEFORE the stamp commit:

    python3 scripts/gen_build_info.py B16

Writes scripts/build_info.gd (the in-game stamp) and
VERSION.txt at the repo root. COMMIT is the code commit just made;
the stamp itself lands in the next commit, so the phone shows the
CODE hash and VERSION.txt documents the pairing. The build stamp is
the single answer to "which build is my phone running?".
"""
import subprocess
import sys
from datetime import datetime, timezone

ROOT = "/home/z/my-project/"
BATCH = sys.argv[1] if len(sys.argv) > 1 else "B16"

commit = subprocess.run(
    ["git", "-C", ROOT, "rev-parse", "--short", "HEAD"],
    capture_output=True, text=True, check=True).stdout.strip()
built = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
stamp = "%s %s (%s)" % (BATCH, commit, built)

info = """class_name BuildInfo
## GENERATED at commit time by scripts/gen_build_info.py - never hand-edit.
## The build stamp is the single source of truth for "which build is
## this?". It is shown at boot (top-right corner, the BuildStamp
## autoload), in the debug menu, and across the whole SafeBoot log.
## COMMIT is the code commit this build was stamped from; the stamp
## commit itself lands one above it (see VERSION.txt at the repo root).
const BATCH := "%s"
const COMMIT := "%s"
const BUILT := "%s"
const STAMP := "%s"
""" % (BATCH, commit, built, stamp)
open(ROOT + "scripts/build_info.gd", "w").write(info)

version = """LEVERAGE (Bare Hands 3D) - BUILD VERSION
=======================================
batch:  %s
code commit: %s  (the game code this build runs)
built:  %s
stamp:  %s

Which folder to import: the unzipped folder itself (it contains
project.godot). The build stamp is visible in-game at the top-right
corner from boot, in the debug menu, and in the SafeBoot log
(COPY LOG).

The commit that carries this VERSION.txt is one commit ABOVE the
code commit listed here; compare the top of github.com/
jamesrudh-arch/Barehands/commits/main with the stamp on your phone.
""" % (BATCH, commit, built, stamp)
open(ROOT + "VERSION.txt", "w").write(version)

print("stamped: %s" % stamp)
print("  -> scripts/build_info.gd")
print("  -> VERSION.txt")
