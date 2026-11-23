#!/usr/bin/env python3
"""Extract the <article> body text from a z-ai page_reader JSON dump.

Usage: python3 extract_article.py <file.json> [keyword] [chars]
Falls back to the LAST occurrence of a keyword if no <article> tag
exists (Godot class pages use <article>; tutorials may not)."""
import json
import re
import sys
import html as H


def load_html(path):
    raw = open(path, encoding="utf-8", errors="ignore").read()
    # page_reader prints SDK banners before the JSON and may append
    # trailing junk; pull the "html" field out by scanning (O(n))
    m = re.search(r'"html":\s*"', raw)
    if not m:
        return ""
    s = m.end()
    i, out = s, []
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            out.append(raw[i:i + 2])
            i += 2
            continue
        if c == '"':
            break
        out.append(c)
        i += 1
    return "".join(out).encode().decode("unicode_escape", errors="ignore")


def to_text(h):
    return H.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", h)))


def main():
    path = sys.argv[1]
    keyword = sys.argv[2] if len(sys.argv) > 2 else ""
    chars = int(sys.argv[3]) if len(sys.argv) > 3 else 3000
    h = load_html(path)
    m = re.search(r"<article[\s\S]*?</article>", h)
    if m:
        text = to_text(m.group(0))
        print(f"[article tag] {len(text)} chars")
        print(text[:chars])
        return
    text = to_text(h)
    if keyword:
        k = text.rfind(keyword)
        print(f"[keyword '{keyword}' at {k}]")
        print(text[k:k + chars] if k >= 0 else text[:chars])
    else:
        print(text[:chars])


if __name__ == "__main__":
    main()
