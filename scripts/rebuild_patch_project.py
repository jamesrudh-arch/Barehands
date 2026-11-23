#!/usr/bin/env python3
"""Rebuild step 1: patch project.godot for the new skeleton.

- registers the Game + WorldState autoloads (at the top of the
  section, ahead of everything that may use them)
- switches run/main_scene to the new boot chain (splash)
The InputMap is added by tools/rebuild_set_inputs.gd (the engine
serialises input events correctly only through InputMap + save).
"""
import re
import sys

P = "/home/z/my-project/project.godot"
NEW_AUTOLOADS = [
    ('Game', 'res://scripts/core/game.gd'),
    ('WorldState', 'res://scripts/core/world_state.gd'),
]
MAIN_SCENE = "res://scenes/boot/splash.tscn"


def main() -> int:
    src = open(P, encoding="utf-8").read()
    out = src
    # 1. autoloads: insert right after the [autoload] header
    m = re.search(r"^\[autoload\]\n", out, re.M)
    if not m:
        print("no [autoload] section")
        return 1
    block = ""
    for name, path in NEW_AUTOLOADS:
        if re.search(rf"^{name}=\"\*?{re.escape(path)}\"$", out, re.M):
            print(f"autoload {name} already present")
            continue
        block += f"{name}=\"*{path}\"\n"
    if block:
        out = out[:m.end()] + block + out[m.end():]
    # 2. main scene
    out, n = re.subn(r'run/main_scene="[^"]*"',
                     f'run/main_scene="{MAIN_SCENE}"', out)
    if n != 1:
        print(f"main_scene substitutions: {n} (expected 1)")
        return 1
    if out == src:
        print("nothing changed")
        return 0
    open(P, "w", encoding="utf-8").write(out)
    print("patched: autoloads + main_scene ->", MAIN_SCENE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
