#!/bin/bash
# Build-identity staleness check (B22, directive section 3). Fails when
# the project's identity surfaces disagree with each other or with git,
# so a build can never ship claiming to be the wrong revision.
# Surfaces checked: scripts/build_info.gd (the in-game stamp source),
# VERSION.txt, project.godot's config/name, and the git history.
# Exit 0 = consistent; exit 1 = stale or inconsistent (message printed).
cd "$(dirname "$0")/.." || exit 1

fail() { echo "BUILD-IDENTITY FAIL: $1"; exit 1; }

# 1. build_info.gd parses and carries the constants
BATCH=$(sed -n 's/^const BATCH := "\(.*\)"/\1/p' scripts/build_info.gd)
COMMIT=$(sed -n 's/^const COMMIT := "\(.*\)"/\1/p' scripts/build_info.gd)
BUILT=$(sed -n 's/^const BUILT := "\(.*\)"/\1/p' scripts/build_info.gd)
[ -n "$BATCH" ] && [ -n "$COMMIT" ] && [ -n "$BUILT" ] \
  || fail "scripts/build_info.gd is missing BATCH/COMMIT/BUILT constants"

# 2. VERSION.txt agrees
grep -q "^code commit: $COMMIT" VERSION.txt \
  || fail "VERSION.txt code commit is not $COMMIT"
grep -q "^stamp:  $BATCH $COMMIT" VERSION.txt \
  || fail "VERSION.txt stamp line is not '$BATCH $COMMIT'"

# 3. the project name agrees
grep -q "config/name=\"LEVERAGE $BATCH\"" project.godot \
  || fail "project.godot does not name LEVERAGE $BATCH"

# 4. the code commit exists and is HEAD or exactly one commit below it
git cat-file -e "$COMMIT" 2>/dev/null || fail "commit $COMMIT not in git"
HEAD=$(git rev-parse --short HEAD)
if [ "$COMMIT" != "$HEAD" ]; then
  # allowed only when HEAD is the stamp commit directly above it, and
  # that stamp touched identity files only
  [ "$(git rev-parse --short HEAD^)" = "$COMMIT" ] \
    || fail "COMMIT $COMMIT is neither HEAD nor HEAD's parent"
  while read -r f; do
    case "$f" in
      VERSION.txt|scripts/build_info.gd|project.godot) ;;
      *) fail "HEAD is above $COMMIT but touched non-identity file: $f" ;;
    esac
  done < <(git diff --name-only HEAD^ HEAD)
fi

# 5. no code changes after the code commit (the tree IS the stamp)
if [ "$(git status --porcelain | wc -l)" -ne 0 ]; then
  # a dirty tree is fine DURING development, but the release script
  # refuses to run then; only warn here so the battery still can
  echo "BUILD-IDENTITY note: working tree is dirty (uncommitted work)"
fi

echo "BUILD-IDENTITY OK: $BATCH $COMMIT (built $BUILT) across" \
     "build_info.gd, VERSION.txt, project.godot and git"
exit 0
