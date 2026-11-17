#!/usr/bin/env python3
"""Phase 2: download CC0 Quaternius character assets from GitHub mirrors
(Xeiliex/Tactics-Bell-Web- for UBC, slopwarefactory/terra for the fantasy
outfits). Saved to quarantine for inspection, NOT directly into the game."""
import pathlib, urllib.parse, urllib.request, sys

OUT = pathlib.Path("/home/z/my-project/downloads_check/ubc")
RAWS = {
    "tactics": "https://raw.githubusercontent.com/Xeiliex/Tactics-Bell-Web-/main/",
    "terra": None,  # filled after branch lookup
}

TACTICS_FILES = [
    "Assets/universal-base-characters/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf",
    "Assets/universal-base-characters/Base Characters/Godot - UE/Superhero_Male_FullBody.bin",
    "Assets/universal-base-characters/Base Characters/Godot - UE/T_Superhero_Male_Dark.png",
    "Assets/universal-base-characters/Base Characters/Godot - UE/T_Superhero_Male_Normal.png",
    "Assets/universal-base-characters/Base Characters/Godot - UE/T_Superhero_Male_Roughness.png",
    "Assets/universal-base-characters/Base Characters/Godot - UE/T_Eye_Brown.png",
    "Assets/universal-base-characters/Base Characters/Godot - UE/T_Eye_Normal.png",
    "Assets/universal-base-characters/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Beard.gltf",
    "Assets/universal-base-characters/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Beard.bin",
    "Assets/universal-base-characters/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf",
    "Assets/universal-base-characters/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.bin",
    "Assets/universal-base-characters/Base Characters/Textures/T_Hair_1_BaseColor.png",
    "Assets/universal-base-characters/Base Characters/Textures/Normals Unity - Godot/T_Hair_1_Normal.png",
    "Assets/universal-base-characters/License_Standard.txt",
    "Assets/universal-base-characters/Preview.png",
]

TERRA_PREFIX = "art/characters/quaternius/modular-outfits-fantasy/"
TERRA_FILES = [
    "Male_Ranger_Arms.gltf", "Male_Ranger_Arms.bin",
    "Male_Ranger_Body.gltf", "Male_Ranger_Body.bin",
    "Male_Ranger_Legs.gltf", "Male_Ranger_Legs.bin",
    "Male_Ranger_Feet_Boots.gltf", "Male_Ranger_Feet_Boots.bin",
    "License_Source.txt",
]


def fetch(url: str, dest: pathlib.Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
        with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
            f.write(r.read())
        return dest.stat().st_size > 100
    except Exception as e:
        print("FAIL", dest.name, e)
        return False


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ok = 0
    for p in TACTICS_FILES:
        url = RAWS["tactics"] + urllib.parse.quote(p)
        dest = OUT / p.rsplit("/", 1)[-1]
        ok += fetch(url, dest)
    # terra default branch (main, confirmed via API; avoids a rate-limited call)
    branch = "main"
    for name in TERRA_FILES:
        url = f"https://raw.githubusercontent.com/slopwarefactory/terra/{branch}/{TERRA_PREFIX}{urllib.parse.quote(name)}"
        dest = OUT / name
        ok += fetch(url, dest)
    print(f"downloaded {ok}/{len(TACTICS_FILES) + len(TERRA_FILES)}")


if __name__ == "__main__":
    sys.exit(0 if main() is not None else 1)
