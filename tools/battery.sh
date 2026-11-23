#!/bin/bash
# REBUILD BATTERY (stage 4+): the six live suites, each from its own
# clean user dir, sequential, never killed. Render suites run under
# the manually started Xvfb :99 with llvmpipe. Exit 1 if any fails.
G=/tmp/godot-dl/Godot_v4.7.2-stable_linux.x86_64
cd /home/z/my-project || exit 1
OUT=/tmp/battery.log
: > "$OUT"
FAIL=0
HEADLESS="smoke_boot"
RENDER="pipeline_probe smoke_hero smoke_home smoke_combat_r smoke_street"
for t in $HEADLESS; do
  rm -rf "/tmp/bat-$t" && mkdir -p "/tmp/bat-$t"
  echo "=== $t ($(date +%H:%M:%S)) ===" >> "$OUT"
  HOME="/tmp/bat-$t" timeout 420 "$G" --headless --path . "res://tests/$t.tscn" >> "$OUT" 2>&1
  rc=$?
  line=$(grep -E "(PASS|FAIL) \(" "$OUT" | tail -1)
  echo "SUMMARY $t rc=$rc $line" >> "$OUT"
  if [ $rc -ne 0 ]; then FAIL=1; echo ">>> $t FAILED (rc=$rc)"; fi
done
for t in $RENDER; do
  rm -rf "/tmp/bat-$t" && mkdir -p "/tmp/bat-$t" /tmp/render
  echo "=== $t ($(date +%H:%M:%S)) ===" >> "$OUT"
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME="/tmp/bat-$t" timeout 600 "$G" \
      --path . --rendering-driver opengl3 "res://tests/$t.tscn" >> "$OUT" 2>&1
  rc=$?
  line=$(grep -E "(PASS|FAIL) \(" "$OUT" | tail -1)
  echo "SUMMARY $t rc=$rc $line" >> "$OUT"
  if [ $rc -ne 0 ]; then FAIL=1; echo ">>> $t FAILED (rc=$rc)"; fi
done
echo "BATTERY $([ $FAIL -eq 0 ] && echo GREEN || echo RED) (log: $OUT)"
exit $FAIL
