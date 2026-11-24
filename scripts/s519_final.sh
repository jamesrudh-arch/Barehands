#!/bin/bash
cd /home/z/my-project
for t in smoke_story smoke_areas smoke_life smoke_perf; do
  rm -rf /tmp/final-$t && mkdir -p /tmp/final-$t
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME=/tmp/final-$t \
    timeout 480 /tmp/godot-dl/Godot_v4.7.2-stable_linux.x86_64 \
    --path . --rendering-driver opengl3 res://tests/$t.tscn \
    > /tmp/final-$t.log 2>&1
  rc=$?
  res=$(grep -E "RESULT pass|PASS \(" /tmp/final-$t.log | tail -1)
  echo "$t rc=$rc $res" >> /tmp/final/LEDGER.txt
done
echo "FINAL DONE" >> /tmp/final/LEDGER.txt
