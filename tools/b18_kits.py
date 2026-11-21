#!/usr/bin/env python3
"""B18.4: fetch the curated Kenney CC0 3D kits into assets/kits/.

Sources (all CC0 1.0, Kenney - kenney.nl):
  - kenney-city-kit-commercial / kenney-city-kit-roads / kenney-car-kit
    from the GitHub mirror series-ai/jam-ready-assets (the repo stores the
    GLBs as git-LFS pointers; media.githubusercontent.com/media serves the
    real bytes - the same route tools/download_sfx.py used for the audio).
  - building-small-a..d, building-garage, pavement from
    KenneyNL/Starter-Kit-City-Builder (plain files, local clone at
    /tmp/kenney-city; assets CC0, repo code MIT).

Each GLB references Textures/colormap.png relative to itself, so every
kit subdir carries its own Textures/ copy. Saved for inspection under
downloads_check first, then curated into assets/kits/ by this script.
"""
import pathlib
import shutil
import sys
import urllib.parse
import urllib.request

MEDIA = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/"
QUARANTINE = pathlib.Path("/home/z/my-project/downloads_check/kits")
OUT = pathlib.Path("/home/z/my-project/assets/kits")

# (kit subdir, mirror path prefix, file names)
MIRROR_KITS = [
    ("kenney_cars", "kenney-car-kit/3D/vehicles-racing/Models/GLB format/",
     ["sedan.glb", "taxi.glb"]),
    ("kenney_roads", "kenney-city-kit-roads/3D/city/Models/GLB format/",
     ["road-straight.glb", "road-intersection.glb", "road-bend.glb",
      "road-bend-sidewalk.glb", "road-curve-pavement.glb",
      "light-curved-double.glb", "light-square.glb",
      "construction-barrier.glb", "construction-cone.glb",
      "construction-light.glb"]),
    ("kenney_commercial", "kenney-city-kit-commercial/3D/city/Models/GLB format/",
     ["building-b.glb", "building-c.glb", "building-d.glb", "building-e.glb",
      "building-f.glb", "building-g.glb", "building-skyscraper-b.glb",
      "detail-awning.glb", "detail-overhang.glb"]),
]
# from the local clone of KenneyNL/Starter-Kit-City-Builder (assets CC0)
STARTER_DIR = pathlib.Path("/tmp/kenney-city/models")
STARTER_FILES = ["building-small-a.glb", "building-small-b.glb",
                 "building-small-c.glb", "building-small-d.glb",
                 "building-garage.glb", "pavement.glb"]

KENNEY_CC0 = (
    "Kenney assets (kenney.nl) - License: Creative Commons Zero (CC0 1.0)\n"
    "https://creativecommons.org/publicdomain/zero/1.0/\n\n"
    "Sources:\n"
    "- Car Kit, City Kit Commercial, City Kit Roads via the GitHub mirror\n"
    "  series-ai/jam-ready-assets\n"
    "  https://github.com/series-ai/jam-ready-assets\n"
    "- City Kit buildings/pavement via KenneyNL/Starter-Kit-City-Builder\n"
    "  https://github.com/KenneyNL/Starter-Kit-City-Builder\n"
    "  (repo code MIT, included 3D models and sprites are CC0 - see its README)\n"
)


def fetch(url: str, dest: pathlib.Path) -> bool:
    try:
        with urllib.request.urlopen(urllib.request.Request(
                url, headers={"User-Agent": "curl/8"}), timeout=60) as r:
            data = r.read()
    except Exception as e:  # noqa: BLE001 - report and continue
        print(f"FAIL {dest.name}: {e}")
        return False
    is_glb = dest.suffix == ".glb"
    if len(data) < 100 or (is_glb and data[:4] != b"glTF"):
        print(f"BAD  {dest.name}: {len(data)} bytes" +
              (", not a GLB" if is_glb else ""))
        return False
    dest.write_bytes(data)
    print(f"ok   {dest.name} ({len(data)} bytes)")
    return True


def main() -> int:
    QUARANTINE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bad = 0
    for sub, prefix, files in MIRROR_KITS:
        qdir = QUARANTINE / sub
        qdir.mkdir(parents=True, exist_ok=True)
        for f in files:
            url = MEDIA + urllib.parse.quote(prefix + f)
            if not fetch(url, qdir / f):
                bad += 1
        # the colormap each GLB references as Textures/colormap.png
        fetch(MEDIA + urllib.parse.quote(prefix + "Textures/colormap.png"),
              qdir / "colormap.png")
    # starter kit: plain local copies
    sdir = QUARANTINE / "kenney_city"
    sdir.mkdir(parents=True, exist_ok=True)
    for f in STARTER_FILES:
        src = STARTER_DIR / f
        if src.exists():
            shutil.copyfile(src, sdir / f)
            print(f"ok   {f} (starter kit clone)")
        else:
            print(f"MISS {f} (starter kit clone not present)")
            bad += 1
    shutil.copyfile(STARTER_DIR / "Textures" / "colormap.png",
                    sdir / "colormap.png")

    if bad:
        print(f"{bad} files failed - kits NOT installed into assets/")
        return 1
    # curate into the game: each kit in its own dir with its Textures/
    for sub, _, files in MIRROR_KITS:
        (OUT / sub).mkdir(parents=True, exist_ok=True)
        (OUT / sub / "Textures").mkdir(exist_ok=True)
        for f in files:
            shutil.copyfile(QUARANTINE / sub / f, OUT / sub / f)
        shutil.copyfile(QUARANTINE / sub / "colormap.png",
                        OUT / sub / "Textures" / "colormap.png")
    (OUT / "kenney_city").mkdir(parents=True, exist_ok=True)
    (OUT / "kenney_city" / "Textures").mkdir(exist_ok=True)
    for f in STARTER_FILES:
        shutil.copyfile(QUARANTINE / "kenney_city" / f,
                        OUT / "kenney_city" / f)
    shutil.copyfile(QUARANTINE / "kenney_city" / "colormap.png",
                    OUT / "kenney_city" / "Textures" / "colormap.png")
    (OUT / "LICENSE-Kenney-CC0.txt").write_text(KENNEY_CC0)
    print(f"installed into {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
