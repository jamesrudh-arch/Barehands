#!/usr/bin/env python3
"""B19: fetch the new curated Kenney CC0 kits (the full-game directive).

Extends tools/b18_kits.py with the industrial / suburban / traffic /
furniture / food kits and the explosion-pack particle sprites. All via
the git-lfs media CDN route (the sparse clone holds 131-byte pointers).
Everything CC0 (Kenney). Curated per docs/B19_PLAN.md - no bulk dumps.
"""
import pathlib
import shutil
import sys
import urllib.parse
import urllib.request

MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"
OUT = pathlib.Path("/home/z/my-project/assets/kits")
FX = pathlib.Path("/home/z/my-project/assets/fx")

# (kit subdir, mirror path prefix, [files])
GLB_KITS = [
    ("kenney_industrial", "kenney-city-kit-industrial/3D/city/Models/GLB format/",
     ["building-a.glb", "building-b.glb", "building-c.glb", "building-d.glb",
      "building-e.glb", "building-f.glb", "building-g.glb", "building-h.glb",
      "building-i.glb", "building-j.glb", "building-k.glb", "building-l.glb",
      "building-m.glb", "building-n.glb", "building-o.glb", "building-p.glb",
      "building-q.glb", "building-r.glb", "building-s.glb", "building-t.glb",
      "chimney-basic.glb", "chimney-large.glb", "chimney-medium.glb",
      "chimney-small.glb", "detail-tank.glb"]),
    ("kenney_suburban", "kenney-city-kit-suburban/3D/city/Models/GLB format/",
     ["building-type-a.glb", "building-type-b.glb", "building-type-c.glb",
      "building-type-d.glb", "fence-2x2.glb"]),
    ("kenney_traffic", "kenney-car-kit/3D/vehicles-racing/Models/GLB format/",
     ["police.glb", "suv.glb", "hatchback-sports.glb", "van.glb",
      "truck.glb", "box.glb"]),
    ("kenney_furniture", "kenney-furniture-kit/3D/interior-furniture/Models/GLTF format/",
     ["bedSingle.glb", "bedDouble.glb", "sideTable.glb", "sideTableDrawers.glb",
      "chairDesk.glb", "chair.glb", "chairRounded.glb", "stoolBar.glb",
      "stoolBarSquare.glb", "table.glb", "tableRound.glb", "tableCloth.glb",
      "tableCross.glb", "kitchenBar.glb", "kitchenBarEnd.glb",
      "bookcaseClosed.glb", "bookcaseOpen.glb", "televisionModern.glb",
      "televisionVintage.glb", "cabinetTelevision.glb", "loungeSofa.glb",
      "loungeSofaLong.glb", "lampSquareFloor.glb", "lampRoundFloor.glb",
      "lampWall.glb", "pottedPlant.glb", "plantSmall1.glb",
      "cardboardBoxClosed.glb", "cardboardBoxOpen.glb", "trashcan.glb",
      "desk.glb", "coatRackStanding.glb", "rugSquare.glb",
      "tableCoffee.glb", "wallDoorway.glb", "wallWindow.glb"]),
    ("kenney_food", "kenney-food-kit/3D/food/Models/GLB format/",
     ["skewer.glb", "cup-coffee.glb", "pan-stew.glb", "frying-pan-lid.glb",
      "pot-lid.glb", "bottle-ketchup.glb", "cabbage.glb", "loaf-round.glb"]),
]

# particle sprites (fire/smoke/dust) - 2D pack, PNG magic check
SPRITES = [
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "greyCloud1.png", "smoke_1.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "greyCloud2.png", "smoke_2.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "greyCloud3.png", "smoke_3.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "greyCloud4.png", "smoke_4.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "orangeCloud1.png", "fire_1.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "orangeCloud2.png", "fire_2.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "orangeCloud3.png", "fire_3.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "orangeCloud4.png", "fire_4.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "yellowCloud1.png", "fire_core_1.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "yellowCloud2.png", "fire_core_2.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "burst.png", "spark_burst.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "regularExplosion00.png", "impact_1.png"),
    ("kenney-explosion-pack/2D/misc/PNG/Particles/", "regularExplosion04.png", "impact_2.png"),
]

KENNEY_CC0_EXTRA = (
    "Additional Kenney packs (B19, all CC0 1.0 - kenney.nl):\n"
    "- City Kit Industrial (buildings, chimneys, tank) - the docks block\n"
    "- City Kit Suburban (residential buildings, fence) - background depth\n"
    "- Car Kit (police, suv, hatchback, van, truck, cargo box) - traffic\n"
    "- Furniture Kit (beds, sofas, tables, kitchen, lamps, plants) - interiors\n"
    "- Food Kit (skewers, pans, coffee) - the noodle shop\n"
    "- Explosion Pack (smoke/fire cloud sprites, burst) - particle textures\n"
    "Via https://github.com/series-ai/jam-ready-assets (git-lfs media CDN)\n"
)


def fetch(url: str, dest: pathlib.Path, magic: bytes) -> bool:
    try:
        with urllib.request.urlopen(urllib.request.Request(
                url, headers={"User-Agent": "curl/8"}), timeout=60) as r:
            data = r.read()
    except Exception as e:  # noqa: BLE001
        print(f"FAIL {dest.name}: {e}")
        return False
    if len(data) < 100 or data[: len(magic)] != magic:
        print(f"BAD  {dest.name}: {len(data)} bytes")
        return False
    dest.write_bytes(data)
    return True


def main() -> int:
    bad = 0
    for sub, prefix, files in GLB_KITS:
        d = OUT / sub
        (d / "Textures").mkdir(parents=True, exist_ok=True)
        for f in files:
            if not fetch(MEDIA + urllib.parse.quote(prefix + f), d / f, b"glTF"):
                bad += 1
        # every GLB references Textures/colormap.png relative to itself
        if not fetch(MEDIA + urllib.parse.quote(prefix + "Textures/colormap.png"),
                     d / "Textures" / "colormap.png", b"\x89PNG"):
            # some kits carry per-material textures instead - keep going
            print(f"note: {sub} has no shared colormap (per-model textures)")
        print(f"kit {sub}: {len(files)} models")
    FX.mkdir(parents=True, exist_ok=True)
    for prefix, name, out_name in SPRITES:
        if not fetch(MEDIA + urllib.parse.quote(prefix + name),
                     FX / out_name, b"\x89PNG"):
            bad += 1
    (FX / "LICENSE-Kenney-CC0.txt").write_text(KENNEY_CC0_EXTRA)
    if bad:
        print(f"{bad} downloads failed")
        return 1
    print(f"installed: {sum(len(k[2]) for k in GLB_KITS)} models + "
          f"{len(SPRITES)} fx sprites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
