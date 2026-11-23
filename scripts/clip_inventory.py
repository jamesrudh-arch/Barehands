#!/usr/bin/env python3
"""Clip inventory across the KayKit animation packs (rebuild step 5)."""
import re

PAT = re.compile(rb"Melee_[A-Za-z0-9_]+|Idle_[A-Z]|Crouch[a-z]*|Sneak[a-z]*"
                 rb"|Death_[A-Z][A-Za-z_]*|Hit[A-Za-z_]*|Punch[A-Za-z_]*"
                 rb"|Kick[A-Za-z_]*|Block[A-Za-z_]*|Dodge[A-Za-z_]*"
                 rb"|Interact[A-Za-z_]*|Grab[A-Za-z_]*|Push[A-Za-z_]*|Throw[A-Za-z_]*")

for f in ["Rig_Medium_CombatMelee.glb", "Rig_Medium_General.glb",
          "Rig_Medium_CombatRanged.glb", "Rig_Medium_MovementAdvanced.glb",
          "Rig_Medium_Special.glb"]:
    try:
        data = open("assets/v2/kaykit_character_animations/" + f, "rb").read()
    except FileNotFoundError:
        print(f, ": MISSING")
        continue
    names = sorted({m.decode() for m in PAT.findall(data)})
    print(f.replace("Rig_Medium_", "").replace(".glb", ""), ":", names)
