#!/usr/bin/env python3
# python3 tools/make_town_knoll.py SRC.png OUT.png [BLOCK] [knoll|blossom|blossom7]
# The memorial knoll behind the fountain (owner 2026-11-10: "이런것들 처럼 배경 가까이 있는 근경 그림", "1번 가볼까"):
# the owner's NAI picture (a drawn, not pixel, picture with its background removed; the AI original stays out of the
# repo) brought to the town's rules:
#  - every BLOCK x BLOCK px (default 4) becomes one 2-px cell: kept where more than half covered; a cell is LINE where
#    enough of it is the drawing's dark line, else it takes its lit pixels' median;
#  - cells are sorted into materials - lawn (the mound, the moss), leaf (the canopy), trunk, stone, pale (the sword's
#    blade, petals) - and each material's colours are clustered by brightness and laid on ONE ramp of
#    assets/town/palette.png in that order (never "the nearest colour"), 4 steps each;
#  - the line is not black: each line cell takes the darkest step of the material most of its neighbours are;
#  - lone cells in a body take the colour most neighbours have.
import sys
from collections import Counter
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
BK = int(sys.argv[3]) if len(sys.argv) > 3 else 4
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
ramp = lambda r, idx: [tuple(P[r, i]) for i in idx]

a = np.array(Image.open(SRC).convert("RGBA")).astype(float)
H, W = a.shape[0] // BK, a.shape[1] // BK
a = a[:H * BK, :W * BK]
blk = a.reshape(H, BK, W, BK, 4).transpose(0, 2, 1, 3, 4).reshape(H, W, BK * BK, 4)
alpha = blk[..., 3] > 128
keep = alpha.mean(2) > 0.5
val_px = blk[..., :3].max(3) / 255.0
dark_px = (val_px < 0.36) & alpha
linec = keep & (dark_px.sum(2) / np.maximum(alpha.sum(2), 1) > 0.42)
if len(sys.argv) > 4 and sys.argv[4].startswith('blossom'): linec &= False   # a pixel picture already: no drawn line to find by coverage
c = np.zeros((H, W, 3))
for y in range(H):
    for x in range(W):
        if not keep[y, x]: continue
        m = alpha[y, x] & ~dark_px[y, x]
        if m.sum() == 0: m = alpha[y, x]
        c[y, x] = np.median(blk[y, x][m][:, :3], 0)

r, g, b = c[..., 0] / 255, c[..., 1] / 255, c[..., 2] / 255
mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
d = mx - mn + 1e-6
hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
sat, val = d / (mx + 1e-6), mx
lum = 0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2]

PRESET = sys.argv[4] if len(sys.argv) > 4 else "knoll"
LINE_V = 0.3 if PRESET.startswith("blossom") else 0.36
body = keep & ~linec
linec |= body & (val < LINE_V)
body = keep & ~linec
if PRESET.startswith("blossom"):
    # the blossom tree (owner 2026-11-10: "1 3 다 넣으면?", the tree picture): petals, the trunk and branches (a dark
    # wine brown), the bench, swing and the ledge's earth (wood), the ledge's grass
    red = (hue >= 315) | (hue < 10)
    green = body & (hue >= 42) & (hue < 95) & (sat > 0.4)
    petal = body & red & (val > 0.52)
    trunk = body & red & ~petal
    wood = body & ~green & ~petal & ~trunk
    # petals: "blossom" = the red ramp's salmon steps; "blossom7" = the violet/pink ramp (pink on violet shade)
    pr = ramp(7, [3, 4, 5]) if PRESET == "blossom7" else ramp(0, [2, 5, 6, 7])
    MATS = [("lawn", green, ramp(4, [2, 3, 4, 5])), ("petal", petal, pr), ("trunk", trunk, ramp(1, [1, 2, 3])),
            ("wood", wood, ramp(1, [3, 4, 5, 6]))]
    DARK = {"lawn": tuple(P[4, 1]), "petal": tuple(P[7, 2] if PRESET == "blossom7" else P[0, 1]), "trunk": tuple(P[1, 0]), "wood": tuple(P[1, 1])}
else:
    green = body & (hue >= 47) & (hue < 90) & (sat > 0.5)
    leaf = green & (val < 0.56)
    lawn = green & ~leaf
    pale = body & ~green & (sat < 0.36) & (val > 0.6)
    trunk = body & ~green & ~pale & (hue < 28)
    stone = body & ~green & ~pale & ~trunk
    MATS = [("lawn", lawn, ramp(4, [3, 4, 5, 6])), ("leaf", leaf, ramp(5, [1, 2, 3, 5])), ("trunk", trunk, ramp(1, [2, 3, 4, 6])),
            ("stone", stone, ramp(8, [4, 5, 6, 7])), ("pale", pale, ramp(3, [3, 5, 7]))]
    DARK = {"lawn": tuple(P[4, 1]), "leaf": tuple(P[5, 0]), "trunk": tuple(P[1, 0]), "stone": tuple(P[8, 2]), "pale": tuple(P[3, 0])}

out = np.zeros((H, W, 3), np.uint8)
mat = np.full((H, W), -1)


def lay(mask, cols):
    v = lum[mask]
    if len(v) == 0: return
    k = len(cols)
    cen = np.quantile(v, np.linspace(0.1, 0.9, k))
    for _ in range(25):
        lab = np.abs(v[:, None] - cen[None, :]).argmin(1)
        cen = np.array([v[lab == i].mean() if (lab == i).any() else cen[i] for i in range(k)])
    rank = np.empty(k, int); rank[np.argsort(cen)] = np.arange(k)
    out[mask] = np.array(cols)[rank[np.abs(v[:, None] - cen[None, :]).argmin(1)]]


for i, (n, m, cols) in enumerate(MATS):
    lay(m, cols)
    mat[m] = i

# lone cells in a body take the colour most neighbours have
o2 = out.copy()
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if not body[y, x]: continue
        nb = [tuple(out[y + j, x + i]) for j, i in ((1, 0), (-1, 0), (0, 1), (0, -1)) if body[y + j, x + i]]
        if nb and tuple(out[y, x]) not in nb:
            o2[y, x] = Counter(nb).most_common(1)[0][0]
out = o2

# a stray cell of another material inside a body (fewer than 2 of its own material in its 3 x 3) joins the body round it
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if not body[y, x]: continue
        nbm = mat[y - 1:y + 2, x - 1:x + 2].ravel()
        if (nbm == mat[y, x]).sum() - 1 < 2:
            oth = [(mat[y + j, x + i], tuple(out[y + j, x + i])) for j in (-1, 0, 1) for i in (-1, 0, 1)
                   if (i or j) and body[y + j, x + i] and mat[y + j, x + i] != mat[y, x]]
            if oth:
                mm, col = Counter(oth).most_common(1)[0][0]
                out[y, x] = col; mat[y, x] = mm

# the line: the darkest step of the material most of its 5 x 5 neighbours are
names = [m[0] for m in MATS]
for y in range(H):
    for x in range(W):
        if not linec[y, x]: continue
        nb = mat[max(0, y - 2):y + 3, max(0, x - 2):x + 3].ravel()
        nb = nb[nb >= 0]
        out[y, x] = DARK[names[Counter(nb.tolist()).most_common(1)[0][0]]] if len(nb) else DARK["trunk"]

rgba = np.dstack([out, np.where(keep, 255, 0).astype(np.uint8)])
ys, xs = np.where(keep)
rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
Image.fromarray(rgba).resize((rgba.shape[1] * 2, rgba.shape[0] * 2), Image.NEAREST).save(OUT)
print("cells", rgba.shape[1], rgba.shape[0], "px", rgba.shape[1] * 2, rgba.shape[0] * 2,
      "colours", len({tuple(p[:3]) for p in rgba.reshape(-1, 4) if p[3]}))
