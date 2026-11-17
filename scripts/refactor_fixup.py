#!/usr/bin/env python3
"""Phase 1 fixup pass: remaining match labels, _enter() enum args, log.gd
FILE_APPEND (not in Godot 4.7). One-shot tool."""
import re, pathlib

ROOT = pathlib.Path("/home/z/my-project/bare-hands")

def fix(path, fn):
    p = ROOT / path
    lines = p.read_text().splitlines(keepends=True)
    lines = fn(lines)
    p.write_text("".join(lines))
    print("ok", path)

ENEMY_LABELS = {"WALK:", "TELEGRAPH:", "STRIKE:", "FLINCH:", "STAGGER:", "DOWN:"}
ENEMY_WORDS = {"IDLE", "WALK", "TELEGRAPH", "STRIKE", "RECOVER", "FLINCH", "STAGGER", "DOWN"}

def fix_enemy(lines):
    out = []
    in_match = False
    for ln in lines:
        stripped = ln.strip()
        if ln.startswith("\tmatch state:"):
            in_match = True
            out.append(ln)
            continue
        if in_match:
            if stripped in ENEMY_LABELS:
                out.append(ln.replace(stripped, "State." + stripped))
                continue
            if stripped.startswith("_") and stripped.endswith(":"):
                in_match = False  # the `_:` default arm ends the label run
        # _enter(IDLE) / _enter(STRIKE) / _enter(IDLE if mode == 0 else WALK)
        m = re.search(r"_enter\(([A-Z]+)( if mode == 0 else )([A-Z]+)\)", ln)
        if m and m.group(1) in ENEMY_WORDS and m.group(3) in ENEMY_WORDS:
            ln = re.sub(r"_enter\([A-Z]+ if mode == 0 else [A-Z]+\)",
                        "_enter(State.%s if mode == 0 else State.%s)" % (m.group(1), m.group(3)), ln)
        else:
            ln = re.sub(r"_enter\((%s)\)" % "|".join(ENEMY_WORDS),
                        lambda m: "_enter(State.%s)" % m.group(1), ln)
        out.append(ln)
    return out

def fix_player(lines):
    out = []
    for ln in lines:
        s = ln.strip()
        if s in ("PUNCH:", "DODGE:"):
            ln = ln.replace(s, "State." + s)
        out.append(ln)
    return out

def fix_log(lines):
    return [
        ln.replace(
            'var f := FileAccess.open(FILE, FileAccess.FILE_APPEND)',
            'var f := FileAccess.open(FILE, FileAccess.READ_WRITE)\n'
            '\tif f:\n'
            '\t\tf.seek_end()'
        ).replace("\tif f:\n\t\tf.seek_end()\n\t\tf.store_line(line)\n\t\tf.close()",
                  "\tif f:\n\t\tf.seek_end()\n\t\tf.store_line(line)\n\t\tf.close()")
        for ln in lines
    ]

fix("scripts/enemy.gd", fix_enemy)
fix("scripts/player.gd", fix_player)
print("done")
