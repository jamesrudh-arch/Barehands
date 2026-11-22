#!/usr/bin/env python3
"""The ONE authoritative release process (B22, directive section 3).

Usage:  python3 -I scripts/release.py B22 ["release name"] [--push]

What it does, in order, refusing to continue on any failure:
  1. Verify the tree is clean, on main, and in sync with origin.
  2. Record the exact source revision (the code commit = HEAD).
  3. Generate the build metadata: scripts/build_info.gd (batch, code
     commit, UTC build time, config, platform) via gen_build_info.py.
  4. Stamp VERSION.txt and project.godot's config/name to the batch.
  5. Create the stamp commit (identity files only).
  6. Run tools/check_build_identity.sh - the staleness gate.
  7. Build the ZIP with `git archive` from the STAMP COMMIT, so the
     zip's bytes are exactly the committed tree - no uncommitted
     modifications can ever leak into a release.
  8. Verify the ZIP: extract, compare build_info.gd, VERSION.txt and
     project.godot inside the zip against the committed ones.
  9. Write download/BUILD_MANIFEST_<batch>.json: exact code commit,
     stamp commit, zip sha256, timestamp - the provenance record.
 10. Optionally push (main + the tag leverage-<batch>).

WHY THE IN-GAME STAMP NAMES HEAD~1 (the code commit): the stamp commit
only rewrites the identity files, so the game code the player runs IS
the code commit; the stamp commit exists solely to carry its label.
The manifest records both, and check_build_identity.sh enforces that
the stamp commit touched identity files only. This is the documented
and now automated explanation of the B21 eed6a49/525b09b pair.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import datetime

ROOT = pathlib.Path(__file__).resolve().parent.parent
DL = ROOT / "download"


def sh(args: list, check: bool = True, capture: bool = True) -> str:
    r = subprocess.run(args, cwd=ROOT, capture_output=capture, text=True)
    if check and r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        sys.exit(f"release.py: step failed: {' '.join(args)}")
    return r.stdout.strip() if capture else ""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("batch")
    ap.add_argument("name", nargs="?", default="release")
    ap.add_argument("--push", action="store_true")
    a = ap.parse_args()
    batch = a.batch.upper()

    # 1. clean, on main, in sync
    if sh(["git", "rev-parse", "--abbrev-ref", "HEAD"]) != "main":
        sys.exit("release.py: not on main")
    if sh(["git", "status", "--porcelain"]):
        sys.exit("release.py: working tree is dirty - commit first")
    sh(["git", "fetch", "origin"])
    head = sh(["git", "rev-parse", "HEAD"])
    remote = sh(["git", "rev-parse", "origin/main"])
    if head != remote:
        sys.exit(f"release.py: HEAD {head[:7]} != origin/main {remote[:7]} - push/pull first")

    # 2-4. metadata: code commit, build_info, VERSION.txt, project name
    code_commit = head[:7]
    built = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    print(f"[release] batch {batch} from code commit {code_commit} at {built}")
    sh([sys.executable, "-I", "scripts/gen_build_info.py", batch, code_commit])
    vt = (ROOT / "VERSION.txt").read_text().split("\n")
    (ROOT / "VERSION.txt").write_text("\n".join(
        [f"batch:  {batch} ({a.name.upper()})" if ln.startswith("batch:")
         else f"code commit: {code_commit}  (the game code this build runs)" if ln.startswith("code commit:")
         else f"built:  {built}" if ln.startswith("built:")
         else f"stamp:  {batch} {code_commit} ({built})" if ln.startswith("stamp:")
         else ln for ln in vt]))
    import re
    pg = ROOT / "project.godot"
    pg.write_text(re.sub(r'config/name="LEVERAGE [^"]*"',
                         f'config/name="LEVERAGE {batch}"', pg.read_text()))

    # 5. stamp commit
    sh(["git", "add", "VERSION.txt", "scripts/build_info.gd", "project.godot"])
    sh(["git", "commit", "-m",
        f"{batch} build stamp: {a.name}, code commit {code_commit}"])
    stamp_commit = sh(["git", "rev-parse", "HEAD"])[:7]

    # 6. staleness gate
    r = subprocess.run(["bash", "tools/check_build_identity.sh"],
                       cwd=ROOT, capture_output=True, text=True)
    print(r.stdout.strip())
    if r.returncode != 0:
        sys.exit("release.py: identity check failed - aborting before zip")

    # 7. reproducible zip from the committed tree
    DL.mkdir(exist_ok=True)
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    zip_name = f"Leverage_{batch}_{a.name.replace(' ', '_')}_{date}.zip"
    zip_path = DL / zip_name
    sh(["git", "archive", "--format=zip", "-o", str(zip_path),
        "--prefix", f"LEVERAGE_{batch}/", stamp_commit])

    # 8. verify zip contents against the commit
    import zipfile
    with zipfile.ZipFile(zip_path) as z:
        bi = z.read(f"LEVERAGE_{batch}/scripts/build_info.gd").decode()
        assert f'const COMMIT := "{code_commit}"' in bi, "zip build_info mismatch"
        assert f'const BATCH := "{batch}"' in bi, "zip batch mismatch"
        vtz = z.read(f"LEVERAGE_{batch}/VERSION.txt").decode()
        assert f"code commit: {code_commit}" in vtz, "zip VERSION mismatch"
        pgz = z.read(f"LEVERAGE_{batch}/project.godot").decode()
        assert f'config/name="LEVERAGE {batch}"' in pgz, "zip project name mismatch"
    sha = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    n = len(zipfile.ZipFile(zip_path).namelist())

    # 9. provenance manifest
    manifest = {
        "batch": batch, "name": a.name,
        "code_commit": code_commit,       # the game code this build runs
        "stamp_commit": stamp_commit,     # carries only the label above it
        "built_utc": built, "zip": zip_name, "zip_sha256": sha,
        "zip_files": n,
        "engine": "Godot 4.7.2",
        "config": "xogot-mobile-safe (Mobile renderer, XOGOT SAFE default on iOS)",
        "platform": "iPhone via Xogot; Linux desktop dev + software-GL live tests",
        "explanation": ("The in-game stamp names the CODE commit (the game "
                        "the player runs); the stamp commit above it touched "
                        "identity files only, verified by "
                        "tools/check_build_identity.sh."),
    }
    (DL / f"BUILD_MANIFEST_{batch}.json").write_text(
        json.dumps(manifest, indent=2) + "\n")
    print(f"[release] {zip_name}: {n} files, sha256 {sha[:16]}...")
    print(f"[release] manifest: download/BUILD_MANIFEST_{batch}.json")

    # 10. optional push
    if a.push:
        sh(["git", "push", "origin", "main"])
        sh(["git", "tag", f"leverage-{batch}", stamp_commit])
        sh(["git", "push", "origin", f"leverage-{batch}"])
        print(f"[release] pushed main + tag leverage-{batch}")


if __name__ == "__main__":
    main()
