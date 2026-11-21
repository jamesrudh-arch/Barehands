"""Parse a GLB file's JSON chunk and print an inventory.

Usage: python -I inspect_glb.py <file.glb>
Reads only the header + JSON chunk; never executes or loads textures/meshes.
"""
import json
import struct
import sys


def main(path: str) -> None:
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:  # "glTF"
        print(f"NOT A GLB: bad magic {magic:#x}")
        sys.exit(1)
    print(f"glTF version {version}, total length {length} ({len(data)} bytes on disk)")

    # Chunk 0 must be JSON.
    clen, ctype = struct.unpack_from("<II", data, 12)
    if ctype != 0x4E4F534A:  # "JSON"
        print("First chunk is not JSON")
        sys.exit(1)
    gltf = json.loads(data[20 : 20 + clen].decode("utf-8"))

    asset = gltf.get("asset", {})
    print(f"generator: {asset.get('generator', '?')}")

    meshes = gltf.get("meshes", [])
    print(f"meshes: {len(meshes)}")
    for m in meshes[:10]:
        prims = m.get("primitives", [])
        print(f"  - {m.get('name', '(unnamed)')} ({len(prims)} primitives)")

    images = gltf.get("images", [])
    print(f"images: {len(images)}")
    materials = gltf.get("materials", [])
    print(f"materials: {len(materials)}")

    skins = gltf.get("skins", [])
    print(f"skins: {len(skins)}")
    for s in skins:
        print(f"  - {s.get('name', '(unnamed)')}: {len(s.get('joints', []))} joints")

    nodes = gltf.get("nodes", [])
    print(f"nodes: {len(nodes)}")
    # Root nodes (not referenced as children of any node).
    referenced = set()
    for n in nodes:
        referenced.update(n.get("children", []))
    roots = [i for i in range(len(nodes)) if i not in referenced]
    names = [nodes[i].get("name", "?") for i in roots]
    print(f"root nodes: {names[:12]}")
    # Nodes that carry a mesh.
    mesh_nodes = [n.get("name", "?") for n in nodes if "mesh" in n]
    print(f"nodes with mesh: {mesh_nodes[:12]}")

    anims = gltf.get("animations", [])
    print(f"animations: {len(anims)}")
    for i, a in enumerate(anims):
        # Duration = max accessor max over channels' samplers input.
        # Accessors are usually min/max annotated; take max of maxima.
        dur = 0.0
        for ch in a.get("channels", []):
            acc = gltf["accessors"][a["samplers"][ch["sampler"]]["input"]]
            if "max" in acc:
                dur = max(dur, acc["max"][0])
        print(f"  [{i:2d}] {a.get('name', '(unnamed)')}  ~{dur:.2f}s")


if __name__ == "__main__":
    main(sys.argv[1])
