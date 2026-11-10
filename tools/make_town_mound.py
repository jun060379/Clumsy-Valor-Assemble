#!/usr/bin/env python3
# python3 tools/make_town_mound.py [OUT.png]
# The grass mound behind the blossom tree (owner 2026-11-10: "뒤로 동산 같은 거 좀 넣어볼까", "동상말고 동산...",
# drawn here like the slope rather than from a generated picture: "1안해서 한번 보자").
#  - one round body, its crest left of the middle and its right side the longer, gentler one;
#  - the lawn ramp only (row 4 of assets/town/palette.png): so it does not sink into the slope behind it, the form is
#    shaded as a solid - light on the top and the side toward the sun, a step darker band by band toward its foot and
#    its far side, the bands whole shapes following the round - and its edge is a thin line of the ramp's dark step
#    with a lit rim under it;
#  - grass standing up along the crest, two bushes (assets/town/hx, palette already), a few flower clusters.
# 2-px cells, palette colours only. Out: assets/town/k_mound.png (town.gd NEAR_BACK puts its foot behind the plaza).
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/town/k_mound.png")
P = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
c = lambda r, i: np.array(P[r, i], np.uint8)
NC, HC = 470, 150                         # cells: 940 x 300 px
PEAK, HH = 0.42, 132.0                    # where the crest is (share of the width), its height in cells
rng = np.random.default_rng(31)


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
prof += (vnoise(xs / 46.0, np.full(NC, 2.0), 3) - 0.5) * 9 * np.clip(prof / 30.0, 0, 1)
prof = np.clip(prof, 0, HC - 8)
topc = (HC - np.round(prof)).astype(int)                                     # the crest's cell row per column

X, Y = np.meshgrid(xs, np.arange(HC, dtype=float))
inside = Y >= topc[None, :]
v = np.clip((HC - Y) / np.maximum(prof[None, :], 1.0), 0, 1)                 # 0 at the foot, 1 on the edge
# the light: the top and the side toward the sun (upper left); wavy band edges
n = vnoise(X / 26.0, Y / 9.0, 5) * 0.6 + vnoise(X / 9.0, Y / 4.0, 6) * 0.4
lit = 0.62 * (HC - Y) / HH - 0.30 * t[None, :] + (n - 0.5) * 0.16

D2, DK, BODY, LT, RIM, LINE = range(6)
COL = [c(4, 2), c(4, 3), c(4, 4), c(4, 5), c(4, 6), c(4, 1)]
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
for name, ux, sc in (("f_bush3", 0.70, 1.0), ("f_bush2", 0.17, 0.75)):
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
    if lab[yy, ci] not in (BODY, LT): continue
    col = c(7, 5) if rng.random() < 0.4 else c(3, 7)
    for dy, dx in ((-1, 0), (0, -1), (0, 1), (1, 0)):
        big[(yy + dy) * 2:(yy + dy) * 2 + 2, (ci + dx) * 2:(ci + dx) * 2 + 2, :3] = col
    big[yy * 2:yy * 2 + 2, ci * 2:ci * 2 + 2, :3] = c(2, 5)

Image.fromarray(big).save(OUT)
print("mound", big.shape[1], big.shape[0], "colours", len({tuple(p) for p in big[big[..., 3] > 0][:, :3]}))
