#!/usr/bin/env python3
"""Rebuild asset fetcher: pulls curated CC0 packs from the
series-ai/jam-ready-assets mirror (GitHub LFS media CDN) into the
new assets/v2 structure for the LEVERAGE ground-up rebuild.

Batch 1 = the character animation pipeline:
  - kaykit-character-animations (Rig_Medium + Rig_Large GLBs)
  - kaykit-adventurers (9 rigged characters, Rig_Medium-compatible)
  - quaternius-universal-animation-library (UAL1_Standard.glb)
All licences land next to the files they cover.
Usage: python3 scripts/fetch_rebuild_assets.py [batch]
"""
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"
RAW = "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/"
OUT = pathlib.Path("/home/z/my-project/assets/v2")

# (pack, remote path, local subfolder)
BATCH1 = [
    # KayKit animations - the melee combat + movement sets (CC0, Kay Lousberg)
    ("kaykit_character_animations",
     "kaykit-character-animations/3D/characters/Animations/gltf/Rig_Medium/",
     ["Rig_Medium_CombatMelee.glb", "Rig_Medium_CombatRanged.glb",
      "Rig_Medium_General.glb", "Rig_Medium_MovementAdvanced.glb",
      "Rig_Medium_MovementBasic.glb", "Rig_Medium_Simulation.glb",
      "Rig_Medium_Special.glb", "Rig_Medium_Tools.glb"]),
    ("kaykit_character_animations",
     "kaykit-character-animations/3D/characters/Animations/gltf/Rig_Large/",
     ["Rig_Large_CombatMelee.glb", "Rig_Large_General.glb",
      "Rig_Large_MovementBasic.glb"]),
    ("kaykit_character_animations",
     "kaykit-character-animations/3D/characters/",
     ["License.txt", "LICENSE-kaykit.txt"]),
    # KayKit adventurers - 9 rigged stylized characters with faces
    ("kaykit_adventurers",
     "kaykit-adventurers/3D/characters/Characters/gltf/",
     ["Barbarian.glb", "Barbarian_Large.glb", "Druid.glb", "Engineer.glb",
      "Knight.glb", "Mage.glb", "Ranger.glb", "Rogue.glb", "Rogue_Hooded.glb"]),
    ("kaykit_adventurers",
     "kaykit-adventurers/3D/characters/Characters/",
     ["License.txt", "LICENSE-kaykit.txt"]),
    # Quaternius Universal Animation Library (CC0) - the retarget library
    ("quaternius_ual",
     "quaternius-universal-animation-library/3D/characters/",
     ["UAL1_Standard.glb", "License.txt", "README.md"]),
]


def fetch(batch: str) -> int:
    jobs = {"1": BATCH1}.get(batch)
    if jobs is None:
        print(f"unknown batch {batch}; have: {sorted({'1': BATCH1})}")
        return 2
    ok = fail = 0
    for pack, remote, files in jobs:
        dest = OUT / pack
        dest.mkdir(parents=True, exist_ok=True)
        for name in files:
            url = MEDIA + urllib.parse.quote(remote + name)
            target = dest / name
            if target.exists() and target.stat().st_size > 400:
                print(f"  skip (have) {pack}/{name}")
                ok += 1
                continue
            try:
                data = None
                # binaries ride the LFS media CDN; plain text files sit
                # in the git tree and are served by raw.githubusercontent
                for base in (MEDIA, RAW):
                    url = base + urllib.parse.quote(remote + name)
                    try:
                        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                        with urllib.request.urlopen(req, timeout=120) as r:
                            data = r.read()
                        break
                    except urllib.error.HTTPError as e:
                        if e.code != 404:
                            raise
                if data is None:
                    raise ValueError("404 on both CDN and raw")
                # the raw.githubusercontent route would give 131-byte LFS
                # pointers for binaries; refuse pointers and tiny payloads.
                if len(data) < 400 or data.startswith(b"version https://git-lfs"):
                    raise ValueError(f"unexpected payload ({len(data)} bytes)")
                target.write_bytes(data)
                print(f"  got {pack}/{name} ({len(data)//1024} KB)")
                ok += 1
            except Exception as e:
                print(f"  FAIL {pack}/{name}: {e}")
                fail += 1
    print(f"batch {batch}: {ok} ok, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(fetch(sys.argv[1] if len(sys.argv) > 1 else "1"))
