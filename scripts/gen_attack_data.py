#!/usr/bin/env python3
"""Generate one AttackData .tres per swing kind (Batch 1, prompt section 8).

Values mirror attack_data.gd's DEFAULTS so the .tres files are a complete,
editable override set: the owner can tweak any number on GitHub without
touching GDScript. Re-run after changing DEFAULTS to keep them in sync.

Writes to bare-hands/attacks/<id>.tres.
"""

import os
import re

GAME = "/home/z/my-project/bare-hands"
SRC = os.path.join(GAME, "scripts", "attack_data.gd")
OUT_DIR = os.path.join(GAME, "attacks")

FIELDS = [
    ("damage", "int"),
    ("hitstop_frames", "int"),
    ("knockback", "v3"),
    ("shake_intensity", "float"),
    ("camera_punch", "float"),
    ("posture_damage", "float"),
    ("cancel_start_ms", "float"),
    ("cancel_end_ms", "float"),
    ("haptic_pattern", "str"),
    ("audio_layers", "strarr"),
    ("style_tag", "str"),
    ("super_gain", "float"),
    ("slow_mo_seconds", "float"),
    ("slow_mo_scale", "float"),
]


def parse_defaults(text):
    """Pull the DEFAULTS dict entries out of the GDScript source."""
    defaults = {}
    body = text.split("const DEFAULTS := {", 1)[1].split("\n}", 1)[0]
    # one entry per kind: "kind": {...},  possibly spanning lines
    for m in re.finditer(r'"([a-z_0-9]+)":\s*\{([^}]*)\}', body):
        kind, fields = m.group(1), m.group(2)
        d = {}
        for fm in re.finditer(r'"([a-z_0-9]+)":\s*(Vector3\([^)]*\)|\[[^\]]*\]|[^,}]+)', fields):
            key, raw = fm.group(1), fm.group(2).strip()
            if raw.startswith('"') and raw.endswith('"'):
                raw = raw[1:-1]
            if raw.startswith("Vector3("):
                nums = [float(x) for x in raw[8:-1].split(",")]
                d[key] = "Vector3(%s, %s, %s)" % tuple(nums)
            elif raw.startswith("["):
                items = re.findall(r'"([^"]+)"', raw)
                d[key] = items
            else:
                d[key] = raw.rstrip(",")
        defaults[kind] = d
    return defaults


def prop_line(key, value, kind):
    if kind == "int":
        return "%s = %d" % (key, int(float(value)))
    if kind == "float":
        return "%s = %s" % (key, repr(float(value)))
    if kind == "str":
        return '%s = "%s"' % (key, value)
    if kind == "v3":
        return "%s = %s" % (key, value)
    if kind == "strarr":
        inner = ", ".join('"%s"' % s for s in value)
        return "%s = [%s]" % (key, inner)
    raise ValueError(kind)


def main():
    with open(SRC) as f:
        text = f.read()
    defaults = parse_defaults(text)
    os.makedirs(OUT_DIR, exist_ok=True)
    written = 0
    for kind, d in sorted(defaults.items()):
        lines = [
            "[gd_resource type=\"Resource\" script_class=\"AttackData\" load_steps=2 format=3]",
            "",
            "[ext_resource type=\"Script\" path=\"res://scripts/attack_data.gd\" id=\"1\"]",
            "",
            "[resource]",
            "script = ExtResource(\"1\")",
            'attack_name = "%s"' % kind,
        ]
        for key, kind_t in FIELDS:
            if key in d:
                lines.append(prop_line(key, d[key], kind_t))
        path = os.path.join(OUT_DIR, kind + ".tres")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        written += 1
    print("wrote %d .tres files to %s" % (written, OUT_DIR))

    # sync check: every DEFAULTS key got a file
    missing = [k for k in defaults if not os.path.exists(os.path.join(OUT_DIR, k + ".tres"))]
    if missing:
        raise SystemExit("MISSING: %s" % missing)


if __name__ == "__main__":
    main()
