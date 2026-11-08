#!/usr/bin/env python3
# python3 tools/make_town_hill_nai.py SRC.png OUT.png
# The hall's slope from the owner's NAI picture (owner 2026-11-09: "Nai로 뽑았으니 중간중간 컵 같은 거 없애고 픽셀원칙
# 및 색상 제한 작업"). The source (not kept in the repo: AI original) is drawn on an 8-px grid; each of its pixels
# becomes one 2-px cell of the town. Then:
#  - the cups (small glass jars on the grass) are taken out and the grass closed over them;
#  - every cell is sorted into its material - lawn, bush leaves, wall earth, wall stone, wall line, flower, berry -
#    and each material's colours are clustered by brightness and laid on ONE ramp of assets/town/palette.png in that
#    order (never "the nearest colour"), 3-5 steps each;
#  - lone cells left in a material's body (no neighbour of the same colour) take the colour most neighbours have.
import sys
from collections import Counter
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
ramp = lambda r, idx: [tuple(P[r, i]) for i in idx]

# 1. the source's 8-px pixels -> cells (the mode of each block's middle 6 x 6)
a = np.array(Image.open(SRC).convert("RGB")).astype(int)
g = a.mean(2)
dx, dy = np.abs(np.diff(g, axis=1)).sum(0), np.abs(np.diff(g, axis=0)).sum(1)
off = lambda d: max((d[(np.arange(len(d)) % 8) == o].sum(), o) for o in range(8))[1] + 1
ox, oy = off(dx) % 8, off(dy) % 8
H, W = (a.shape[0] - oy) // 8, (a.shape[1] - ox) // 8
c = np.zeros((H, W, 3), int)
for y in range(H):
    for x in range(W):
        blk = a[oy + y * 8 + 1:oy + y * 8 + 7, ox + x * 8 + 1:ox + x * 8 + 7].reshape(-1, 3)
        c[y, x] = Counter(map(tuple, blk)).most_common(1)[0][0]

r, gg, b = c[..., 0] / 255, c[..., 1] / 255, c[..., 2] / 255
mx, mn = np.maximum(np.maximum(r, gg), b), np.minimum(np.minimum(r, gg), b)
d = mx - mn + 1e-6
hue = np.where(mx == r, ((gg - b) / d) % 6, np.where(mx == gg, (b - r) / d + 2, (r - gg) / d + 4)) * 60
sat, val = d / (mx + 1e-6), mx
lum = 0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2]

# 2. materials
green = (hue > 55) & (hue < 160) & (sat > 0.25)
lawn = green & (val > 0.55) & (lum > 120)
leaf = green & ~lawn
white = (sat < 0.2) & (val > 0.82)
yellow = (hue > 38) & (hue <= 62) & (sat > 0.45) & (val > 0.8) & ~green
near_leaf = np.zeros((H, W), bool)
_lf = green & ~((val > 0.55) & (lum > 120))
for j in range(-2, 3):
    for i in range(-2, 3):
        near_leaf |= np.roll(np.roll(_lf, j, 0), i, 1)
berry = ((hue < 38) | (hue > 330)) & (sat > 0.45) & (val > 0.7) & near_leaf     # on the bushes only
blue = (hue > 180) & (hue < 300) & (sat > 0.25)
rest = ~(lawn | leaf | white | yellow | berry | blue)
line = rest & (val < 0.38)
stone = rest & ~line & (sat < 0.28)
earth = rest & ~line & ~stone

# the cups: light grey or white clusters of 3+ cells (flowers are 1-2 cells) with a dark rim, on the lawn
cup = np.zeros((H, W), bool)
seen = np.zeros((H, W), bool)
light = (white | ((sat < 0.3) & (val > 0.6))) & ~lawn
for y in range(H):
    for x in range(W):
        if not light[y, x] or seen[y, x]: continue
        st, comp = [(y, x)], []
        seen[y, x] = True
        while st:
            p = st.pop(); comp.append(p)
            for q in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                if 0 <= q[0] < H and 0 <= q[1] < W and light[q] and not seen[q]:
                    seen[q] = True; st.append(q)
        if len(comp) >= 4:
            ys, xs = zip(*comp)
            y0, y1, x0, x1 = max(0, min(ys) - 2), min(H, max(ys) + 3), max(0, min(xs) - 2), min(W, max(xs) + 3)
            box = np.zeros((H, W), bool); box[y0:y1, x0:x1] = True
            # only where lawn surrounds it (the wall's light stones are not cups)
            if lawn[max(0, y0 - 2):y1 + 2, max(0, x0 - 2):x1 + 2].mean() > 0.5:
                cup |= box & ~lawn
for m in (lawn, leaf, white, yellow, berry, blue, line, stone, earth):
    m &= ~cup
lawn |= cup | blue                                         # the cups' place and the blue specks become lawn

out = np.zeros((H, W, 3), np.uint8)


def lay(mask, cols, src_lum):
    v = src_lum[mask]
    if len(v) == 0: return
    k = len(cols)
    # 1-D k-means on brightness, clusters sorted dark -> light, laid on the ramp in that order
    cen = np.quantile(v, np.linspace(0.1, 0.9, k))
    for _ in range(25):
        lab = np.abs(v[:, None] - cen[None, :]).argmin(1)
        cen = np.array([v[lab == i].mean() if (lab == i).any() else cen[i] for i in range(k)])
    order = np.argsort(cen)
    lab = np.abs(v[:, None] - cen[None, :]).argmin(1)
    rank = np.empty(k, int); rank[order] = np.arange(k)
    out[mask] = np.array(cols)[rank[lab]]


lum_lawn = np.where(cup, np.median(lum[lawn & ~cup]), lum)
lay(lawn, ramp(4, [3, 4, 5, 6]), lum_lawn)                  # the lawn
lay(leaf, ramp(5, [1, 2, 3, 5]), lum)                       # bush leaves and the grass's shade
lay(earth, ramp(1, [3, 4, 5, 6]), lum)                      # the wall's brown stones
lay(stone, ramp(8, [5, 6, 7]), lum)                         # the wall's grey stones
lay(line, ramp(1, [0, 1]), lum)                             # the wall's dark joints
out[white] = P[3, 7]
out[yellow] = P[2, 5]
lay(berry, ramp(0, [4, 6]), lum)                            # the berries on the bushes

# the wall: its stones in larger pieces - each wall cell takes the colour most of its 3 x 3 has (twice), so the
# AI's speckle inside a stone goes and the stones and joints stay (once; the joints are left as they are)
wall = earth | stone | line
for _ in range(1):
    o3 = out.copy()
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if not wall[y, x] or line[y, x]: continue
            nb = [tuple(out[y + j, x + i]) for j in (-1, 0, 1) for i in (-1, 0, 1) if wall[y + j, x + i]]
            o3[y, x] = Counter(nb).most_common(1)[0][0]
    out = o3

# 3. lone cells in a body take the colour most neighbours have (flowers and berries keep theirs)
keep_acc = white | yellow | berry
o2 = out.copy()
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if keep_acc[y, x]: continue
        me = tuple(out[y, x])
        nb = [tuple(out[y + j, x + i]) for j, i in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if me not in nb:
            o2[y, x] = Counter(nb).most_common(1)[0][0]
Image.fromarray(o2).resize((W * 2, H * 2), Image.NEAREST).save(OUT)
print("cells", W, H, "colours", len({tuple(p) for p in o2.reshape(-1, 3)}), "cups", int(cup.sum()))
