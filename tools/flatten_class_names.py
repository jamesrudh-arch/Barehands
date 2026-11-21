#!/usr/bin/env python3
"""B17: remove EVERY class_name declaration and flatten every cross-file
reference to a const preload.

The Xogot root cause (reproduced 2026-11-21 in this sandbox): a fresh
import has no .godot/global_script_class_cache.cfg, so any script that
references a class_name identifier fails to parse. Autoload scripts
that did this (music.gd referenced Enemy/Player; heat, city, tactics,
combo_input, progression, visual, friend_help, world_sim, jobs...)
failed with "does not inherit from 'Node'" and registered as NULL
singletons -> fight_score.gd:38 'state' on Nil every frame, no hero
script, no touch controls, B16's SafeBoot a grey screen.

The transform (all four mechanics VERIFIED against Godot 4.7.2 before
writing this):
  class_name Enemy            ->  (line deleted)
  var e: Enemy = ...          ->  var e: CLS_Enemy = ...
  x as Enemy                  ->  x as CLS_Enemy
  x is Enemy                  ->  x is CLS_Enemy
  Enemy.new() / Enemy.KIND    ->  CLS_Enemy.new() / CLS_Enemy.KIND
  + const CLS_Enemy := preload("res://scripts/enemy.gd") after extends

Self-references use a self-preload (verified working). Comments and
strings are never touched (a small GDScript lexer splits segments).

Usage: python3 tools/flatten_class_names.py   (from the repo root)
"""
import re
import sys
import glob

DRY = "--check" in sys.argv


def lex_segments(src: str):
    """Yield (kind, start, end) segments: 'code', 'comment', 'string'.
    Handles # comments, "..." and '...' with escapes, and triple
    quotes. Anything not string/comment is code."""
    out = []
    i, n = 0, len(src)
    code_start = 0

    def emit_code(upto):
        nonlocal code_start
        if upto > code_start:
            out.append(("code", code_start, upto))

    while i < n:
        c = src[i]
        if c == "#":
            emit_code(i)
            j = src.find("\n", i)
            j = n if j == -1 else j
            out.append(("comment", i, j))
            i = code_start = j
        elif c == '"' or c == "'":
            triple = src[i:i + 3] == c * 3
            emit_code(i)
            q = c * 3 if triple else c
            j = i + len(q)
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if not triple and src[j] == "\n":
                    break  # unterminated single-line string: stop at EOL
                if src.startswith(q, j):
                    j += len(q)
                    break
                j += 1
            out.append(("string", i, j))
            i = code_start = j
        else:
            i += 1
    emit_code(n)
    return out


# 1. discover declarations
names = {}  # class name -> res:// path
files = sorted(glob.glob("scripts/*.gd") + glob.glob("tests/*.gd"))
for f in files:
    head = open(f, errors="replace").read(400)
    m = re.match(r"class_name (\w+)", head)
    if m:
        names[m.group(1)] = "res://" + f
print("declared class names:", len(names))
if sorted(names) != sorted(set(names)):
    sys.exit("duplicate class names - abort")

word = re.compile(r"\b(%s)\b" % "|".join(sorted(names, key=len, reverse=True)))
changed = 0
for f in files:
    src = open(f, errors="replace").read()
    m = re.match(r"class_name (\w+)\n", src)
    decl = m.group(1) if m else None
    # drop the declaration line
    body = src[m.end():] if m else src
    # collect code-segment matches (right-to-left replacement)
    spans = []  # (start, end, name)
    for kind, a, b in lex_segments(body):
        if kind != "code":
            continue
        for mm in word.finditer(body, a, b):
            spans.append((mm.start(), mm.end(), mm.group(1)))
    if decl is None and not spans:
        continue
    used = sorted(set(s[2] for s in spans))
    for st, en, nm in reversed(spans):
        body = body[:st] + "CLS_" + nm + body[en:]
    # insert preload consts after the extends line (or at top)
    consts = "".join(
        'const CLS_%s := preload("%s")\n' % (u, names[u]) for u in used)
    lines = body.split("\n")
    idx = 0
    for k, ln in enumerate(lines[:6]):
        if ln.startswith("extends ") or ln.startswith("@"):
            idx = k + 1
    # keep the const block after extends but before the doc comment
    lines.insert(idx, consts.rstrip("\n"))
    body = "\n".join(lines)
    if body == src:
        continue
    changed += 1
    if not DRY:
        open(f, "w").write(body)
    print("%-34s %s" % (f, ("declared " + decl + ", ") if decl else ""
                        + ("refs: " + ", ".join(used) if used else "no refs")))

print("files changed:", changed)
if DRY:
    print("(dry run)")
