#!/usr/bin/env python3
## Pixel truth finder: where do the RAIN GLASS bands project in the
## captured frame, and what color are those pixels really?
from PIL import Image
import math

# camera (from the probe diagnostics, exact)
C = (-6.0, 2.4, 0.0)
F = (0.0, -0.041631, 0.999133)          # forward
FOV = 55.0                                # vertical, deg
W, H = 1280, 720

# scene geometry (from the inspector dump, world coords)
front = (-6.0, 0.0, 7.2)
bands = [(-8.45, 2.4, 4.28), (-3.55, 2.4, 4.28)]   # band centers
slabs = [(-9.5, 2.6, 4.2), (-3.0, 2.6, 4.2)]       # slab face centers
door = (-6.0, 2.4, 4.2)
marla = (-4.6, 1.0, 5.4)
spill = (-6.0, 0.05, 3.5)

# orthonormal basis (right-handed, y up): right = f x up
fx, fy, fz = F
up = (0.0, 1.0, 0.0)
rx = fy * up[2] - fz * up[1]
ry = fz * up[0] - fx * up[2]
rz = fx * up[1] - fy * up[0]
rl = math.sqrt(rx * rx + ry * ry + rz * rz)
rx, ry, rz = rx / rl, ry / rl, rz / rl
# true up = right x forward
ux = ry * fz - rz * fy
uy = rz * fx - rx * fz
uz = rx * fy - ry * fx

focal = (H / 2.0) / math.tan(math.radians(FOV) / 2.0)

def project(p):
    dx, dy, dz = p[0] - C[0], p[1] - C[1], p[2] - C[2]
    zc = dx * fx + dy * fy + dz * fz
    xc = dx * rx + dy * ry + dz * rz
    yc = dx * ux + dy * uy + dz * uz
    if zc <= 0.01:
        return None
    return (int(W / 2 + focal * xc / zc), int(H / 2 - focal * yc / zc))

for name, p in [("band_L", bands[0]), ("band_R", bands[1]),
                ("slab_L", slabs[0]), ("slab_R", slabs[1]),
                ("door", door), ("marla", marla), ("spill", spill)]:
    sp = project(p)
    print("%-7s -> %s" % (name, sp))

im = Image.open("/tmp/shots/door_00.png").convert("RGB")
print("frame size:", im.size)
for name, p in [("band_L", bands[0]), ("band_R", bands[1]),
                ("slab_L", slabs[0]), ("slab_R", slabs[1]),
                ("door", door), ("spill", spill)]:
    sp = project(p)
    if sp is None:
        continue
    x, y = sp
    x = max(0, min(im.size[0] - 1, x)); y = max(0, min(im.size[1] - 1, y))
    # average a small patch
    px = []
    for ox in range(-8, 9, 4):
        for oy in range(-8, 9, 4):
            xx = max(0, min(im.size[0] - 1, x + ox))
            yy = max(0, min(im.size[1] - 1, y + oy))
            px.append(im.getpixel((xx, yy)))
    avg = tuple(sum(c[i] for c in px) // len(px) for i in range(3))
    print("%-7s px=(%d,%d) avg RGB=%s %s" % (name, x, y, str(avg),
            "BRIGHT" if sum(avg) > 240 else ("mid" if sum(avg) > 90 else "dark")))
