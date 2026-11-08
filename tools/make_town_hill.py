#!/usr/bin/env python3
# python3 tools/make_town_hill.py
# The grassy bank under the guild hall's terrace (owner 2026-11-09: "밑 풀밭을 언덕처럼", "살짝 어두워지기보다는 조명을
# 먹여야겠는데"): the face of the slope down to the lower street, in the lawn's own colours, lit by the town's ground
# light (shaders/ground_lit.gdshader: the hall's shadow, the sun, the lamps at night) rather than painted darker.
# Round clumps of grass over it, each with a lit cap, its body, and a cell of its own shade under it (row 4 ramp);
# tileable, 2-px cells. Out: assets/town/k_hill.png (512 x 256 px).
import math, random
import numpy as np
from PIL import Image

W, H = 256, 128                                   # cells
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
L = [tuple(P[4, i]) for i in range(8)]
BASE, CAP, SHADE, DEEP = L[4], L[5], L[3], L[2]
img = np.zeros((H, W, 3), np.uint8)
img[:] = BASE
r = random.Random(9)
yy, xx = np.mgrid[0:H, 0:W]
clumps = sorted([(r.uniform(0, W), r.uniform(0, H), r.uniform(5, 11), r.uniform(3, 6)) for _ in range(120)], key=lambda c: c[1])
for cx, cy, rx, ry in clumps:
    for ox in (-W, 0, W):
        for oy in (-H, 0, H):
            dx = (xx - cx - ox) / rx
            dy = (yy - cy - oy) / ry
            body = dx * dx + dy * dy <= 1.0
            under = (dx * dx + ((yy - cy - oy - 1.5) / ry) ** 2 <= 1.0) & ~body & (yy > cy + oy)
            img[under] = SHADE
            img[body] = BASE
            cap = body & (dx * dx + ((yy - cy - oy + ry * 0.45) / (ry * 0.6)) ** 2 <= 0.75)
            img[cap] = CAP
# a few deep gaps between clumps (the bank's own creases), one cell
gap = (np.roll(img, 1, 0) == np.array(SHADE)).all(2) & (img == np.array(BASE)).all(2) & (((xx * 7 + yy * 3) % 11) == 0)
img[gap] = DEEP
Image.fromarray(img).resize((W * 2, H * 2), Image.NEAREST).save("assets/town/k_hill.png")
print("hill", W * 2, H * 2)
