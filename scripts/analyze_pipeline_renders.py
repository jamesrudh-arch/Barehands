#!/usr/bin/env python3
"""Pixel-level analysis of the pipeline proof renders (rebuild step 2).

Answers, from the actual PNGs:
  - does the full-body shot contain a character-sized silhouette?
  - does the face close-up contain face-like detail (colour variety,
    warm skin tones, eyes-contrast) rather than a flat blob?
"""
import sys
from PIL import Image

def stats(path, label):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    colors = {}
    lum = []
    warm = 0
    total = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            colors[(r // 16, g // 16, b // 16)] = colors.get((r // 16, g // 16, b // 16), 0) + 1
            lum.append(0.299 * r + 0.587 * g + 0.114 * b)
            total += 1
            # warm skin-ish: red dominant over blue, mid luminance
            if r > b + 18 and 40 < (r + g + b) / 3 < 215:
                warm += 1
    lum.sort()
    print(f"{label}: {w}x{h} colors={len(colors)} "
          f"lum[min/med/max]={lum[0]:.0f}/{lum[len(lum)//2]:.0f}/{lum[-1]:.0f} "
          f"warm={100.0*warm/total:.1f}%")
    return colors, warm / total

def center_detail(path, label):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    cx0, cy0 = int(w*0.30), int(h*0.20)
    cx1, cy1 = int(w*0.70), int(h*0.80)
    px = im.load()
    lums = []
    for y in range(cy0, cy1, 2):
        for x in range(cx0, cx1, 2):
            r, g, b = px[x, y]
            lums.append(0.299*r + 0.587*g + 0.114*b)
    if not lums:
        return 0.0, 0.0
    mean = sum(lums) / len(lums)
    var = sum((v - mean) ** 2 for v in lums) / len(lums)
    spread = max(lums) - min(lums)
    print(f"{label}: centre mean={mean:.0f} stdev={var**0.5:.1f} spread={spread:.0f}")
    return var ** 0.5, spread

def main():
    base = "/tmp/render"
    body = f"{base}/pipeline_native_post_body.png"
    face = f"{base}/pipeline_native_post_face.png"
    fails = 0
    for path, label in [(body, "BODY"), (face, "FACE")]:
        colors, warm = stats(path, label)
        if label == "BODY":
            # a lit character on a dark floor: expect real colour count
            # and SOME warm (skin/leather) pixels
            ok = len(colors) >= 40
            print(f"  {'ok' if ok else 'FAIL'} {label}: colour variety >= 40 ({len(colors)})")
            fails += 0 if ok else 1
        else:
            ok = len(colors) >= 40 and warm > 0.05
            print(f"  {'ok' if ok else 'FAIL'} {label}: variety >= 40 ({len(colors)}) and warm > 5% ({100*warm:.1f}%)")
            fails += 0 if ok else 1
        sd, spread = center_detail(path, label)
        ok = sd > 8.0 and spread > 60
        print(f"  {'ok' if ok else 'FAIL'} {label}: centre detail stdev > 8 ({sd:.1f}), spread > 60 ({spread:.0f})")
        fails += 0 if ok else 1
    print("PIXEL ANALYSIS " + ("PASS" if fails == 0 else f"FAIL ({fails})"))
    sys.exit(0 if fails == 0 else 1)

if __name__ == "__main__":
    main()
