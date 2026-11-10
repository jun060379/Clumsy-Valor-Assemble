#!/usr/bin/env python3
# python3 tools/make_town_mound.py [OUT.png W_CELLS H_CELLS PEAK SEED]
# The grass mound behind the blossom tree (owner 2026-11-10: "뒤로 동산 같은 거 좀 넣어볼까", "동상말고 동산...",
# drawn here like the slope rather than from a generated picture: "1안해서 한번 보자").
#  - one round body, its crest left of the middle and its right side the longer, gentler one;
#  - the lawn ramp only (row 4 of assets/town/palette.png): so it does not sink into the slope behind it, the form is
#    shaded as a solid - light on the top and the side toward the sun, a step darker band by band toward its foot and
#    its far side, the bands whole shapes following the round - and its edge is a thin line of the ramp's dark step
#    with a lit rim under it;
#  - so it is not one plain green lump (owner 2026-11-11: "미묘한데" - the picture itself and its place): on its longer
#    side a bank where the earth shows (row 1) with dry stones (row 8) under a grass lip, as the slope's ledges are; a
#    few boulders; grass tufts on the body;
#  - grass standing up along the crest, a bush (assets/town/hx, palette already), a few flower clusters.
# Two of them, of different sizes, stand left and right of the tree (owner 2026-11-11: "두개 깔기").
# 2-px cells, palette colours only. Out: assets/town/k_mound.png (town.gd NEAR_BACK puts its foot behind the plaza).
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/town/k_mound.png")
P = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
c = lambda r, i: np.array(P[r, i], np.uint8)
A = sys.argv[2:]
NC, HC = (int(A[0]), int(A[1])) if len(A) > 1 else (470, 150)     # cells (2 px)
PEAK = float(A[2]) if len(A) > 2 else 0.42                        # where the crest is (share of the width)
SEED = int(A[3]) if len(A) > 3 else 31
HH = HC - 18.0                                                    # the crest's height in cells
rng = np.random.default_rng(SEED)


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


xs = np.arange(NC, dtype=float)
u = xs / (NC - 1)
t = np.where(u < PEAK, (u - PEAK) / PEAK, (u - PEAK) / (1 - PEAK))          # -1 .. 0 at the crest .. 1
prof = HH * np.cos(np.pi / 2 * np.abs(t)) ** 1.25
prof += (vnoise(xs / 46.0, np.full(NC, 2.0 + SEED), 3) - 0.5) * 9 * np.clip(prof / 30.0, 0, 1)
prof = np.clip(prof, 0, HC - 8)
topc = (HC - np.round(prof)).astype(int)                                     # the crest's cell row per column

X, Y = np.meshgrid(xs, np.arange(HC, dtype=float))
inside = Y >= topc[None, :]
v = np.clip((HC - Y) / np.maximum(prof[None, :], 1.0), 0, 1)                 # 0 at the foot, 1 on the edge
# the light: the top and the side toward the sun (upper left); wavy band edges
n = vnoise(X / 26.0, Y / 9.0 + SEED, 5) * 0.6 + vnoise(X / 9.0, Y / 4.0, 6) * 0.4
lit = 0.62 * (HC - Y) / HH - 0.30 * t[None, :] + (n - 0.5) * 0.16

D2, DK, BODY, LT, RIM, LINE, E0, E1, E2, S0, S1, S2, SJ = range(13)
COL = [c(4, 2), c(4, 3), c(4, 4), c(4, 5), c(4, 6), c(4, 1), c(1, 3), c(1, 4), c(1, 5), c(8, 5), c(8, 6), c(8, 7), c(8, 3)]
lab = np.full((HC, NC), BODY)
lab[lit < 0.20] = DK
lab[lit < 0.02] = D2
lab[lit > 0.50] = LT
# lone cells and one-cell spurs join the band round them
for _ in range(3):
    p = np.pad(lab, 1, mode="edge")
    nb = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
    ch = (nb == lab[None]).sum(0) <= 1
    vals = np.stack([(nb == k).sum(0) for k in range(len(COL))])
    lab = np.where(ch, vals.argmax(0), lab)

# grass tufts on the body: 3-5 blades from one root, a step lighter than the ground under them
for _ in range(NC * HC // 800):
    x, y = int(rng.integers(8, NC - 8)), int(rng.integers(10, HC - 6))
    if y < HC - prof[x] + 8: continue
    und = lab[y, x]
    if und not in (DK, BODY, LT): continue
    nb_ = int(rng.integers(3, 6))
    for b in range(nb_):
        off = b - nb_ // 2
        for k in range(max(1, 3 - abs(off))):
            lab[y - k, x + off] = und + 1
        lab[y + 1, x + off] = max(D2, und - 1)

# the bank on the longer side: a line that follows the round, a grass lip over earth with dry stones, narrowing to
# nothing at both ends
side = (u > PEAK + 0.04) if PEAK < 0.5 else (u < PEAK - 0.04)
by = HC - HH * 0.36 - (prof - HH * 0.6) * 0.12 + (vnoise(xs / 30.0, np.full(NC, 6.0), 23 + SEED) - 0.5) * 6
ok = side & (prof > (HC - by) + 14)
dist = np.zeros(NC); run = 0
for i in range(NC):
    run = run + 1 if ok[i] else 0; dist[i] = run
run = 0
for i in range(NC - 1, -1, -1):
    run = run + 1 if ok[i] else 0; dist[i] = min(dist[i], run)
tp = np.clip(dist / 22.0, 0, 1); tp = tp * tp * (3 - 2 * tp)
dep = np.round((8 + 5 * vnoise(xs / 15.0, np.full(NC, 4.0), 21 + SEED)) * tp).astype(int)
for i in range(NC):
    d = dep[i]
    if d <= 0: continue
    y = int(by[i])
    for j in range(d):
        lab[y + j, i] = E2 if j < 1 else (E1 if j < d - 1 else E0)
    lab[y - 1, i] = RIM
    for j in range(int(_hash(np.int64(i), np.int64(3), 29) * 3.0)): lab[y + j, i] = BODY      # grass hanging over the lip
i0, i1 = 0, NC
bank = np.isin(lab, (E0, E1, E2))
i = i0
while i < i1:
    L = int(rng.integers(5, 9))
    col = bank[:, i:i + L]
    if rng.random() < 0.55 and col.any(0).all() and col.sum(0).min() >= 5:
        y0 = int(max(np.argmax(col[:, q]) for q in range(L))) + 1
        y1 = int(min(np.argmax(col[:, q]) + col[:, q].sum() for q in range(L))) - 1
        body = S1 if rng.random() < 0.7 else S0
        for q in range(L):
            for y in range(y0, y1):
                cor = (q in (0, L - 1)) and (y in (y0, y1 - 1))
                lab[y, i + q] = SJ if cor else (S2 if y == y0 else (S0 if y == y1 - 1 else body))
        i += L + 1
    else:
        i += 2

# boulders half sunk in the grass: a rounded body, its top lit, its foot dark, grass in front of the foot
for ub, rw, rh in ((PEAK - 0.34 if PEAK > 0.5 else PEAK + 0.36, 15, 11), (PEAK + 0.14 if PEAK > 0.5 else PEAK - 0.22, 9, 7)):
    cx = int(ub * NC)
    if not (rw < cx < NC - rw): continue
    cy = int(HC - prof[cx] * 0.16)
    for y in range(cy - rh, cy + 1):
        for x in range(cx - rw, cx + rw + 1):
            q = ((x - cx) / rw) ** 2 + ((y - cy) / rh) ** 2
            if q > 1 or not (0 <= y < HC): continue
            lab[y, x] = SJ if q > 0.80 else (S2 if (y - cy) / rh < -0.45 and (x - cx) / rw < 0.4 else (S0 if (x - cx) / rw > 0.35 or y > cy - 2 else S1))
    for x in range(cx - rw - 1, cx + rw + 2):
        if _hash(np.int64(x), np.int64(cy), 37) > 0.4: lab[cy - int(_hash(np.int64(x), np.int64(1), 39) * 1.6):cy + 1, x] = BODY

# grass standing up along the crest: short blades in clumps
blade = np.zeros(NC, int)
for i in range(NC):
    if vnoise(np.array([i / 7.0]), np.array([1.0]), 11)[0] > 0.55 and prof[i] > 6:
        blade[i] = 1 + int(_hash(np.int64(i), np.int64(7), 13) * 2.6)
edge = topc - blade
alpha = Y >= edge[None, :]
# the line: the outermost cell of every column, and wherever the edge steps more than a cell the cells between
line = np.zeros((HC, NC), bool)
for i in range(NC):
    e = edge[i]
    lo = max(e, max(edge[max(0, i - 1)], edge[min(NC - 1, i + 1)]) - 1)
    line[e:max(e + 1, lo + 1), i] = True
rim = np.zeros((HC, NC), bool)
rim[1:] = line[:-1] & ~line[1:]
rim[2:] |= (line[:-2] & ~line[2:] & ~line[1:-1])
lab[rim & (t[None, :] < 0.35)] = RIM
lab[line] = LINE

img = np.zeros((HC, NC, 4), np.uint8)
for k, col in enumerate(COL):
    img[lab == k, :3] = col
img[..., 3] = np.where(alpha, 255, 0)
big = img.repeat(2, 0).repeat(2, 1)

# bushes on the mound's side, flower clusters on its lit part
for name, ux, sc in ((("f_bush3", 0.17, 1.0),) if PEAK < 0.5 else (("f_bush2", 0.66, 1.0),)):
    b = Image.open(os.path.join(ROOT, f"assets/town/hx/{name}.png")).convert("RGBA")
    if sc != 1.0: b = b.resize((int(b.width * sc) // 2 * 2, int(b.height * sc) // 2 * 2), Image.NEAREST)
    b = np.array(b)
    ci = int(ux * NC)
    y = (topc[ci] + int(prof[ci] * 0.30)) * 2 - b.shape[0]
    x = ci * 2
    sub = big[y:y + b.shape[0], x:x + b.shape[1]]
    m = b[:sub.shape[0], :sub.shape[1], 3] > 0
    sub[m] = b[:sub.shape[0], :sub.shape[1]][m]
for _ in range(16):
    ci = int(rng.integers(30, NC - 30))
    if prof[ci] < 30: continue
    yy = int(rng.integers(topc[ci] + 6, HC - 12))
    if lab[yy - 1:yy + 2, ci - 1:ci + 2].min() < BODY or lab[yy - 1:yy + 2, ci - 1:ci + 2].max() > LT: continue
    col = c(7, 5) if rng.random() < 0.4 else c(3, 7)
    for dy, dx in ((-1, 0), (0, -1), (0, 1), (1, 0)):
        big[(yy + dy) * 2:(yy + dy) * 2 + 2, (ci + dx) * 2:(ci + dx) * 2 + 2, :3] = col
    big[yy * 2:yy * 2 + 2, ci * 2:ci * 2 + 2, :3] = c(2, 5)

Image.fromarray(big).save(OUT)
print("mound", big.shape[1], big.shape[0], "colours", len({tuple(p) for p in big[big[..., 3] > 0][:, :3]}))
