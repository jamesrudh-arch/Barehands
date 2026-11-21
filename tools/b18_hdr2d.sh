#!/bin/bash
# B18 hdr_2d experiment: render_check with hdr_2d OFF (current) vs ON,
# generous timeouts (llvmpipe is slow), then REVERT project.godot.
# Writes /tmp/b18-hdr2d.log with the white-area, luminance and wall-time
# comparison the owner asked for.
G=/tmp/godot-dl/Godot_v4.7.2-stable_linux.x86_64
cd /home/z/my-project || exit 1
OUT=/tmp/b18-hdr2d.log
: > "$OUT"

run_case() {
  local label="$1"
  rm -rf "/tmp/hdr-$label" && mkdir -p "/tmp/hdr-$label"
  local start=$(date +%s)
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME="/tmp/hdr-$label" \
      timeout 900 "$G" --path . --rendering-driver opengl3 \
      res://tests/render_check.tscn > "/tmp/hdr-$label.out" 2>&1
  local rc=$?
  local end=$(date +%s)
  echo "== $label rc=$rc wall_s=$((end-start)) ==" >> "$OUT"
  grep -E "white=|mean_lum|RENDER PASS|RENDER FAIL" "/tmp/hdr-$label.out" >> "$OUT"
}

run_case off
# toggle hdr_2d ON
grep -q "^viewport/hdr_2d=true" project.godot || \
    sed -i 's|^\[rendering\]|[rendering]\n\nviewport/hdr_2d=true|' project.godot
grep -n "hdr_2d" project.godot >> "$OUT"
run_case on
# revert
sed -i '/^viewport\/hdr_2d=true$/d' project.godot
if grep -q "hdr_2d" project.godot; then
  echo "WARNING: hdr_2d still present" >> "$OUT"
else
  echo "project.godot reverted clean" >> "$OUT"
fi
echo "HDR2D_DONE" >> "$OUT"
