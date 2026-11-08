#!/usr/bin/env python3
# python3 tools/make_near_grass.py
# The near grass along the bottom of the screen (owner 2026-11-09, sketch 5: "이런 느낌 좋았는데"; "근경은 기본 기조를
# 풀로"): a low band of lawn running across in front of everything, its top a fringe of blades of mixed height, in
# the lawn's darker greens (row 5 of assets/town/palette.png: body, a step lighter for the front blades, one lit cell
# at the tips), no outline, on the 2-px grid. Tileable: assets/town/near_grass.png, 1200 x 48 px.
import math, random
import numpy as np
from PIL import Image, ImageDraw

W, H = 600, 24                       # cells
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
BODY, MID, TIP = tuple(P[5, 1]), tuple(P[5, 2]), tuple(P[5, 3])
r = random.Random(11)
img = np.zeros((H, W, 4), np.uint8)
BASE = 8                             # the band's body: the bottom 8 cells
img[H - BASE:] = (*BODY, 255)


def blades(n, hmin, hmax, col, wd):
    lay = Image.new("L", (W * 4, H * 4), 0)
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        x = r.uniform(0, W)
        h = r.uniform(hmin, hmax)
        lean = r.uniform(-0.45, 0.55)
        y0 = H - BASE + 2
        for dx in (-W, 0, W):                                  # wrap so the strip tiles
            pts = []
            for i in range(13):
                t = i / 12
                pts.append((x + dx + lean * t * t * h, y0 - t * h, wd * (1 - t)))
            poly = [((px - w) * 4, py * 4) for px, py, w in pts] + [((px + w) * 4, py * 4) for px, py, w in pts[::-1]]
            d.polygon(poly, fill=255)
    m = np.array(lay.resize((W, H), Image.BOX)) > 110
    return m


back = blades(260, 4, 14, BODY, 1.6)
img[back] = (*BODY, 255)
front = blades(140, 3, 9, MID, 1.5)
img[front] = (*MID, 255)
m = img[..., 3] > 0
tips = m & ~np.roll(m, 1, 0)
img[tips & (np.arange(H)[:, None] < H - BASE)] = (*TIP, 255)
Image.fromarray(img).resize((W * 2, H * 2), Image.NEAREST).save("assets/town/near_grass.png")
print("near grass", W * 2, H * 2)
