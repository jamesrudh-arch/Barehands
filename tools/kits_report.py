#!/usr/bin/env python3
"""B18.4: report each kit GLB's local AABB and triangle count.

Parses the GLB JSON chunk only (same safe approach as inspect_glb.py).
The node transform chain is ignored (Kenney kit models are single-node,
unscaled), so accessor min/max IS the usable footprint.
Usage: python3 -I tools/kits_report.py
"""
import json
import pathlib
import struct
import sys

KIT_ROOT = pathlib.Path("/home/z/my-project/assets/kits")


def glb_json(data: bytes) -> dict:
    magic, _, _ = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        return {}
    clen, ctype = struct.unpack_from("<II", data, 12)
    if ctype != 0x4E4F534A:
        return {}
    return json.loads(data[20 : 20 + clen])


def main() -> None:
    print(f"{'file':38} {'size (x,y,z)':>24} {'tris':>7}  meshes")
    total = 0
    for f in sorted(KIT_ROOT.rglob("*.glb")):
        g = glb_json(f.read_bytes())
        if not g:
            print(f"{f.relative_to(KIT_ROOT)}: NOT A GLB")
            continue
        mins = [1e9] * 3
        maxs = [-1e9] * 3
        tris = 0
        for m in g.get("meshes", []):
            for p in m.get("primitives", []):
                pos = g["accessors"][p["attributes"]["POSITION"]]
                mn, mx = pos.get("min"), pos.get("max")
                if mn and mx:
                    for i in range(3):
                        mins[i] = min(mins[i], mn[i])
                        maxs[i] = max(maxs[i], mx[i])
                if "indices" in p:
                    tris += g["accessors"][p["indices"]]["count"] // 3
                else:
                    tris += pos["count"] // 3
        size = tuple(round(maxs[i] - mins[i], 2) for i in range(3))
        print(f"{str(f.relative_to(KIT_ROOT)):38} "
              f"{str(size):>24} {tris:>7}  {len(g.get('meshes', []))}")
        total += tris
    print(f"total kit triangles: {total}")


if __name__ == "__main__":
    sys.exit(main())
