#!/bin/bash
# B18 full battery: every suite from its own clean user dir, sequential,
# never killed. Render suites run under the manually started Xvfb :99
# with llvmpipe. Writes /tmp/b18-battery.log + a one-line-per-suite
# summary; exit code 1 if any suite fails.
G=/tmp/godot-dl/Godot_v4.7.2-stable_linux.x86_64
cd /home/z/my-project || exit 1
OUT=/tmp/b18-battery.log
: > "$OUT"
FAIL=0
# step 0 (B22): the build-identity staleness gate - the battery must
# not certify a build whose identity surfaces disagree
bash tools/check_build_identity.sh || FAIL=1
HEADLESS="run_tests smoke smoke_safe smoke_a4 smoke_audio smoke_backroom smoke_cast smoke_city smoke_combat smoke_crowd smoke_combos smoke_controls smoke_debt smoke_depth smoke_difficulty smoke_district smoke_economy smoke_face smoke_friends smoke_jobs smoke_kidnap smoke_kits smoke_interiors smoke_ledger smoke_map smoke_music smoke_null_watch smoke_phone smoke_pose smoke_progression smoke_reactive smoke_stick smoke_tpose smoke_worldsim stage0_check stress_combat smoke_traffic smoke_weather smoke_fire final_audit"
RENDER="render_check safe_boot_check kit_probe"
LIVE="live_walk live_play"
for t in $HEADLESS; do
  [ -f "tests/$t.tscn" ] || { echo "$t MISSING_TSCN" >> "$OUT"; continue; }
  rm -rf "/tmp/bat-$t" && mkdir -p "/tmp/bat-$t"
  echo "=== $t ($(date +%H:%M:%S)) ===" >> "$OUT"
  HOME="/tmp/bat-$t" timeout 420 "$G" --headless --path . "res://tests/$t.tscn" >> "$OUT" 2>&1
  rc=$?
  line=$(grep -E "(PASS|FAIL) \(" "$OUT" | tail -1)
  echo "SUMMARY $t rc=$rc $line" >> "$OUT"
  if [ $rc -ne 0 ]; then FAIL=1; echo ">>> $t FAILED (rc=$rc)"; fi
done
for t in $RENDER; do
  rm -rf "/tmp/bat-$t" && mkdir -p "/tmp/bat-$t"
  echo "=== $t ($(date +%H:%H:%M)) ===" >> "$OUT"
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME="/tmp/bat-$t" timeout 600 "$G" \
      --path . --rendering-driver opengl3 "res://tests/$t.tscn" >> "$OUT" 2>&1
  rc=$?
  line=$(grep -E "(PASS|FAIL) \(" "$OUT" | tail -1)
  echo "SUMMARY $t rc=$rc $line" >> "$OUT"
  if [ $rc -ne 0 ]; then FAIL=1; echo ">>> $t FAILED (rc=$rc)"; fi
done
# B22: the LIVE-PLAY evidence suites (the software GL needs the low
# resolution to hold a workable frame rate)
for t in $LIVE; do
  rm -rf "/tmp/bat-$t" && mkdir -p "/tmp/bat-$t"
  echo "=== $t ($(date +%H:%M:%S)) ===" >> "$OUT"
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME="/tmp/bat-$t" timeout 600 "$G" \
      --path . --resolution 640x360 --rendering-driver opengl3 \
      "res://tests/$t.tscn" >> "$OUT" 2>&1
  rc=$?
  line=$(grep -E "(PASS|FAIL) \(" "$OUT" | tail -1)
  echo "SUMMARY $t rc=$rc $line" >> "$OUT"
  if [ $rc -ne 0 ]; then FAIL=1; echo ">>> $t FAILED (rc=$rc)"; fi
done
echo "BATTERY_EXIT=$FAIL" >> "$OUT"
echo "BATTERY_EXIT=$FAIL"
exit $FAIL
