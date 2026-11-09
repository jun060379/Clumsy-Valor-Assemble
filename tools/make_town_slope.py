#!/usr/bin/env python3
# python3 tools/make_town_slope.py FACE.json [OUT.png]
# The hall's slope between the upper walk and the lower street, drawn for its own shape (owner 2026-11-09: "비탈이되
# 그림문제"; the processed picture before was a rectangle laid under the walk and cut wherever the walk climbs or drops:
# "옆에 오르 내리막길이라던가 막 잘림"). FACE.json from tests/dump_face.gd: per 2 px, where the face shows (top: the
# upper walk's front band ends; bot: the lower plane's back starts).
#  - a grass slope (the lawn ramp, row 4 of assets/town/palette.png), darker and lighter patches as whole shapes;
#  - ledges (owner 2026-11-09: "중간중간 흙이나 돌 단차 같은 것도 묘사"): lines at set heights above the lower street,
#    meandering a little, each a grass lip over a band of earth (row 1) with dry stones (row 8) set in it; a ledge is
#    only where the face is tall enough, and at its ends its earth band narrows to nothing so it sinks into the slope
#    (no cut);
#  - grass hanging over each lip, a few bushes (assets/town/hx/f_bush2, f_bush3, palette already) sitting on ledges,
#    small flower clusters.
# Palette colours only, 2-px cells. Out: assets/town/k_slope.png, its top-left at (x0, Y0) of the town.
import json
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = json.load(open(sys.argv[1]))
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets/town/k_slope.png")
P = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
c = lambda r, i: np.array(P[r, i], np.uint8)
Y0 = 270                                   # the image's top in town y (above the highest face top)
top = np.array(F["top"]) - Y0
bot = np.array(F["bot"]) - Y0
NC = len(top)                              # cells across (one per 2 px)
H = int(F["lowf"]) + 30 - Y0               # px down to below the lower street's floor
HC = H // 2
rng = np.random.default_rng(23)


def _hash(ix, iy, s):
    h = (ix * 374761393 + iy * 668265263 + s * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(u, v, s):
    iu, iv = np.floor(u).astype(np.int64), np.floor(v).astype(np.int64)
    fu, fv = u - iu, v - iv
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    a, b = _hash(iu, iv, s), _hash(iu + 1, iv, s)
    cc, d = _hash(iu, iv + 1, s), _hash(iu + 1, iv + 1, s)
    return (a * (1 - fu) + b * fu) * (1 - fv) + (cc * (1 - fu) + d * fu) * fv


X, Y = np.meshgrid(np.arange(NC, dtype=float), np.arange(HC, dtype=float))
tc = np.ceil(top / 2.0)[None, :]             # cell rows
bc = np.floor(bot / 2.0)[None, :]
face = (Y >= tc - 2) & (Y <= bc + 22)        # a little past both ends: the band and the plane cover the rest

# labels
DK, BODY, LT, LIP, E0, E1, E2, S0, S1, S2, J = range(11)
COL = [c(4, 3), c(4, 4), c(4, 5), c(4, 6), c(1, 3), c(1, 4), c(1, 5), c(8, 5), c(8, 6), c(8, 7), c(8, 3)]

# 1. the grass: patches, flat and wide (the slope seen face on)
n = 0.7 * vnoise(X / 40.0, Y / 9.0, 1) + 0.3 * vnoise(X / 14.0, Y / 4.0, 2)
lab = np.full((HC, NC), BODY)
lab[n < 0.3] = DK
lab[n > 0.76] = LT

# 2. the ledges: level lines (a ledge follows the hill's contour, so it runs level, not along the walks), at town y,
# each a little wavy
LEDGES = [646, 556, 466, 376]
ledge_rows = []
for k, hk in enumerate(LEDGES):
    w = (vnoise(np.arange(NC) / 40.0, np.full(NC, 3.0 + k * 7), 7 + k) - 0.5) * 10 \
        + (vnoise(np.arange(NC) / 11.0, np.full(NC, 1.0 + k), 17 + k) - 0.5) * 4
    ly = np.round((hk - Y0 + w) / 2.0).astype(int)               # the lip's cell row
    room = (ly - tc[0]) * 2.0                                    # px of slope above the lip
    below = bc[0] * 2.0 - ly * 2.0                                # px of slope under it
    exist = (room > 24) & (below > 30)
    # the earth band's depth (cells): 5..9, narrowing to 0 over 28 cells toward where the ledge stops existing
    dist = np.zeros(NC)
    run = 0
    for i in range(NC):
        run = run + 1 if exist[i] else 0
        dist[i] = run
    run = 0
    for i in range(NC - 1, -1, -1):
        run = run + 1 if exist[i] else 0
        dist[i] = min(dist[i], run)
    taper = np.clip(dist / 28.0, 0, 1)
    taper = taper * taper * (3 - 2 * taper)
    depth = np.round((8 + 5 * vnoise(np.arange(NC) / 17.0, np.full(NC, 9.0 + k), 27 + k)) * taper).astype(int)
    ledge_rows.append((ly, depth))
    for i in range(NC):
        d = depth[i]
        if d <= 0: continue
        y = ly[i]
        # the earth band under the lip, a step darker toward its foot
        for j in range(d):
            if 0 <= y + j < HC:
                lab[y + j, i] = E2 if j < 1 else (E1 if j < d - 1 else E0)
        if 0 <= y - 1 < HC: lab[y - 1, i] = LIP                     # the lip catches the light
# dry stones in the earth bands: runs where noise says; each stone 5-9 cells long, one body colour with its top a step
# lighter (the light from above) and its foot a step darker, corners rounded; a deep band takes two courses, offset
def stone(i0, L, y0, y1):
    body = S1 if rng.random() < 0.75 else S0
    for q in range(L):
        ii = i0 + q
        if ii >= NC: return
        for y in range(y0, y1):
            if not (0 <= y < HC): continue
            corner = (q == 0 or q == L - 1) and (y == y0 or y == y1 - 1)
            lab[y, ii] = J if corner else (S2 if y == y0 else (S0 if y == y1 - 1 else body))
for k, (ly, depth) in enumerate(ledge_rows):
    i = 0
    while i < NC:
        on = vnoise(np.array([i / 31.0]), np.array([5.0 + k]), 41 + k)[0] > 0.42
        L = int(rng.integers(5, 10))
        if on and depth[i:i + L].size and depth[i:i + L].min() >= 5:
            d = int(depth[i:i + L].min())
            y0 = int(ly[i]) + 1
            if d >= 10:                                   # two courses
                m = y0 + (d - 1) // 2
                stone(i, L, y0, m)
                off = L // 2
                stone(i + off, L, m + 1, y0 + d - 2)
            else:
                stone(i, L, y0, y0 + d - 2)
            i += L + 1
        else:
            i += 1

# 3. grass hanging over the lips: short fringes, a cell or two down over the earth
for ly, depth in ledge_rows:
    for i in range(NC):
        if depth[i] <= 0: continue
        h = int(_hash(np.int64(i), np.int64(ly[i]), 5) * 3.2)
        for j in range(h):
            y = ly[i] + j
            if 0 <= y < HC and lab[y, i] not in (J,):
                lab[y, i] = BODY if j < h - 1 else DK

# lone cells take the colour most neighbours have (patches stay whole shapes)
for _ in range(2):
    p = np.pad(lab, 1, mode="edge")
    nb = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
    same = (nb == lab[None]).sum(0)
    grass = (lab == DK) | (lab == BODY) | (lab == LT)
    ch = (same == 0) & grass
    vals = np.stack([(nb == k).sum(0) for k in range(len(COL))])
    lab = np.where(ch, vals.argmax(0), lab)

img = np.zeros((HC, NC, 4), np.uint8)
for k, col in enumerate(COL):
    img[lab == k, :3] = col
img[..., 3] = np.where(face, 255, 0)
big = img.repeat(2, 0).repeat(2, 1)

# 4. bushes sitting on the ledges (their foot a cell above the lip), and flower clusters on the slope
bushes = [np.array(Image.open(os.path.join(ROOT, f"assets/town/hx/{k}.png")).convert("RGBA")) for k in ("f_bush3", "f_bush2")]
x = 40
while x < NC * 2 - 140:
    k = int(rng.integers(0, len(ledge_rows)))
    ly, depth = ledge_rows[k]
    ci = x // 2
    b = bushes[int(rng.integers(0, 2))]
    bw, bh = b.shape[1], b.shape[0]
    cells = slice(ci, min(NC, ci + bw // 2))
    if depth[cells].min() >= 3:
        sc = 0.75 if rng.random() < 0.5 else 1.0
        if sc != 1.0:
            b = np.array(Image.fromarray(b).resize((int(bw * sc) // 2 * 2, int(bh * sc) // 2 * 2), Image.NEAREST))
        y = int(ly[ci]) * 2 - b.shape[0] + 6
        if y > top[ci] + 10:
            sub = big[y:y + b.shape[0], x:x + b.shape[1]]
            m = b[:sub.shape[0], :sub.shape[1], 3] > 0
            sub[m] = b[:sub.shape[0], :sub.shape[1]][m]
            sub[m, 3] = 255
    x += int(rng.integers(260, 520))
for _ in range(90):
    ci = int(rng.integers(2, NC - 2))
    lo, hi = int(tc[0, ci]) + 4, min(HC - 2, int(bc[0, ci]) - 2)
    if hi <= lo: continue
    yy = int(rng.integers(lo, hi))
    if lab[yy, ci] not in (DK, BODY, LT): continue
    col = c(7, 5) if rng.random() < 0.4 else c(3, 7)
    for dy, dx in ((-1, 0), (0, -1), (0, 1), (1, 0)):
        Y_, X_ = (yy + dy) * 2, (ci + dx) * 2
        big[Y_:Y_ + 2, X_:X_ + 2, :3] = col
    big[yy * 2:yy * 2 + 2, ci * 2:ci * 2 + 2, :3] = c(2, 5)

Image.fromarray(big).save(OUT)
print("slope", big.shape[1], big.shape[0], "Y0", Y0, "colours", len({tuple(v) for v in big[big[..., 3] > 0][:, :3]}))
