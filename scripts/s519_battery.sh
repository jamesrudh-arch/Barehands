#!/bin/bash
# S5.19: the FULL battery - every smoke_* suite, isolated HOMEs
cd /home/z/my-project
SUITES="smoke_story smoke_combat_r smoke_world smoke_city smoke_life smoke_areas smoke_phone2 smoke_boot smoke_economy smoke_hero smoke_home smoke_hud smoke_jobs smoke_leverage smoke_missions smoke_perf smoke_pistol smoke_police smoke_skills smoke_street smoke_surface smoke_systems smoke_title smoke_vehicle"
mkdir -p /tmp/battery
for t in $SUITES; do
  rm -rf /tmp/battery/$t && mkdir -p /tmp/battery/$t
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 HOME=/tmp/battery/$t \
    timeout 480 /tmp/godot-dl/Godot_v4.7.2-stable_linux.x86_64 \
    --path . --rendering-driver opengl3 res://tests/$t.tscn \
    > /tmp/battery/$t.log 2>&1
  rc=$?
  res=$(grep -E "RESULT pass|PASS \(" /tmp/battery/$t.log | tail -1)
  echo "$t rc=$rc $res" >> /tmp/battery/LEDGER.txt
done
echo "BATTERY DONE" >> /tmp/battery/LEDGER.txt
