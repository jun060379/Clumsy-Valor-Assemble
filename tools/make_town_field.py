#!/usr/bin/env python3
# python3 tools/make_town_field.py [OUTDIR]
# The ground in front of the walk, drawn for that place (owner 2026-11-09: "하단 확장 타일들 기존 거 복붙복붙만 하지말고
# 전용으로 따로 만들어"). Before, the tile's plane rows were stacked again and again (bands that repeat); now:
#  - the lawn (owner 2026-11-08: "풀 타일부터 근경까지 풀로 이어지게 할거임"): one body colour of the lawn ramp (row 4 of
#    assets/town/palette.png, the plane's own front colour) with darker and lighter patches as whole shapes (no
#    speckle: lone cells and one-cell spurs taken out), the patches flat and wide far off and larger, rounder and a
#    little more often dark toward the camera; grass tufts and a few flower clusters, bigger the nearer they are;
#  - the paving (owner 2026-11-09: "하단 길은 바닥 타일이 돌이니까 풀이 아니라 돌 타일로 확장해야지"): cobbles of the
#    paving's stone ramp (row 8) in courses that grow toward the camera, each stone one body colour with its lower edge
#    a step darker and its corners cut round, dark joints, a little moss in the joints.
# Everything on the 2-px cell grid, palette colours only. Out: k_field_0..3.png, k_field_stone_0..3.png (2400-px pieces).
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/town")
P = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
c = lambda r, i: tuple(int(v) for v in P[r, i])
W, H = 4800, 231                    # cells (2 px): 9600 x 462 px; town.gd puts row 0 under the plane's last row
rng = np.random.default_rng(11)

# ---------- value noise at any (u, v) ----------
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

ys = np.arange(H, dtype=float)
sc = 1.0 + ys / H * 1.6                       # how big things are at a row: 1 at the walk's edge, 2.6 nearest
vrow = np.cumsum(1.0 / sc)                    # depth measured in "far" cells, so features grow toward the camera
asp = 4.0 - ys / H * 2.0                      # patches flat far off (4 : 1), rounder near (2 : 1)
X, Y = np.meshgrid(np.arange(W, dtype=float), ys)
V = vrow[:, None] * np.ones((1, W))
S_, A_ = sc[:, None], asp[:, None]


def clean(lab, keep=()):
    # a cell that no 4-neighbour shares takes the label most neighbours have; a one-cell spur (only one neighbour the
    # same) too: patches stay whole shapes
    for _ in range(3):
        p = np.pad(lab, 1, mode="edge")
        nb = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        same = (nb == lab[None]).sum(0)
        ch = same <= 1
        for k in keep: ch &= lab != k
        if not ch.any(): break
        vals = np.stack([(nb == k).sum(0) for k in range(lab.max() + 1)])
        lab = np.where(ch, vals.argmax(0), lab)
    return lab


def to_png(lab, cols, name):
    rgb = np.zeros((H, W, 4), np.uint8)
    for k, col in enumerate(cols):
        rgb[lab == k, :3] = col
    rgb[..., 3] = 255
    big = rgb.repeat(2, 0).repeat(2, 1)
    for i in range(4):
        Image.fromarray(big[:, i * 2400:(i + 1) * 2400]).save(os.path.join(OUT, f"{name}_{i}.png"))
    return len({tuple(v) for v in rgb[..., :3].reshape(-1, 3)})


# ---------- the lawn ----------
DARK, BODY, LIGHT, TIP, ROOT_, PINK, WHITE, YEL = range(8)
LAWN = [c(4, 3), c(4, 4), c(4, 5), c(4, 6), c(4, 2), c(7, 5), c(3, 7), c(2, 5)]
u = X / (14.0 * A_ * S_)
v = V / 9.0
n = 0.6 * vnoise(u, v, 1) + 0.3 * vnoise(u * 2.1, v * 2.1, 2) + 0.1 * vnoise(u * 4.3, v * 4.3, 3)
fade = np.clip(ys / 10.0, 0, 1)[:, None]                  # the first rows stay the plane's body colour
t_dark = 0.30 + 0.12 * (ys / H)[:, None]                  # a little more often dark toward the camera
t_light = 0.74 + 0.0 * Y
lab = np.full((H, W), BODY)
lab[(n < t_dark) & (np.abs(n - 0.5) * fade > 0.0) & (n < t_dark - (1 - fade) * 0.4)] = DARK
lab[(n > t_light + (1 - fade) * 0.4)] = LIGHT
lab = clean(lab)

def tuft(x, y, s, under):
    # a tuft: 3-5 blades fanning from one root, the middle ones tallest; blades one step lighter than the ground they
    # stand on, their tips another; the root a cell of the dark under them
    nb = int(rng.integers(3, 6))
    hmax = max(2, int(round(2.0 * s + rng.random())))
    lit = LIGHT if under != LIGHT else TIP
    for b in range(nb):
        off = b - nb // 2
        h = max(1, hmax - abs(off) - int(rng.integers(0, 2)))
        lean = np.sign(off) if abs(off) >= 1 else 0
        for k in range(h):
            xx = x + off + (lean if k >= h - 1 and h > 2 else 0)
            yy = y - k
            if 0 <= yy < H and 0 <= xx < W:
                lab[yy, xx] = TIP if (k == h - 1 and h >= 3) else lit
    if 0 <= y + 1 < H:
        for b in range(nb):
            xx = x + b - nb // 2
            if 0 <= xx < W and lab[y + 1, xx] != DARK: lab[y + 1, xx] = DARK

placed = []
for y in range(6, H):
    s = sc[y]
    rate = 0.0035 / s                                      # the same share of the ground: fewer, bigger, near
    for x in np.nonzero(rng.random(W) < rate)[0]:
        tuft(int(x), y, s, lab[y, x])
# flowers: a few small daisies (petals round a yellow heart), only where they are big enough to read, never single dots
for _ in range(45):
    x, y = int(rng.integers(2, W - 2)), int(rng.integers(H // 3, H - 2))
    col = PINK if rng.random() < 0.4 else WHITE
    for dy, dx in ((-1, 0), (0, -1), (0, 1), (1, 0)):
        lab[y + dy, x + dx] = col
    lab[y, x] = YEL
print("lawn colours", to_png(lab, LAWN, "k_field"))

# ---------- the paving ----------
J, MOSS, EDGE, B0, B1 = range(5)
STONE = [c(8, 3), c(4, 3), c(8, 5), c(8, 7), c(8, 6)]
# the flagstones: the stones of a cobbled floor seen from the walk, laid out where the floor would be flat (x shrunk
# and depth measured by how big things are at each row, so the stones grow toward the camera), each stone the cells
# nearest one seed; seeds in loose courses, the stones a little wider than deep
from scipy.spatial import cKDTree
QX, QV = 2.2, 1.0                     # a stone's width : depth
STEP = 4.6                            # a course's depth in "far" cells (about 9 px at the curb)
seeds, kinds, ranks = [], [], []
# courses down the screen, each as deep as the row's size says; seeds along it spaced to match
yc = -STEP * 0.5
while yc < H + STEP * 3:
    s_ = 1.0 + max(0.0, yc) / H * 1.6
    xx = -rng.random() * STEP * QX * s_
    while xx < W + STEP * QX * 3:
        seeds.append((xx / QX, yc + (rng.random() - 0.5) * STEP * s_ * 0.35))
        kinds.append(B1 if rng.random() < 0.22 else B0)
        ranks.append(1 + int(rng.random() * 254))
        xx += STEP * QX * s_ * (0.75 + rng.random() * 0.7)
    yc += STEP * s_
tree = cKDTree(np.array(seeds))
pts = np.stack([(X / QX).ravel(), Y.ravel()], 1)
_, near = tree.query(pts)
sid = near.reshape(H, W)
joint = np.zeros((H, W), bool)
joint[:, :-1] |= sid[:, :-1] != sid[:, 1:]
joint[:-1, :] |= sid[:-1, :] != sid[1:, :]
lab = np.array(kinds)[sid]
low = np.zeros((H, W), bool)
low[:-1] = joint[1:] & ~joint[:-1]                   # a stone's lower edge: the cell above a joint
lab[low] = EDGE
# the corners cut round: a stone cell with joints on two sides that meet (above or below, and left or right)
jp = np.pad(joint, 1)
corner = (jp[:-2, 1:-1] | jp[2:, 1:-1]) & (jp[1:-1, :-2] | jp[1:-1, 2:])
joint |= corner
lab[joint] = J
# a little moss in the joints, in short runs
jy, jx = np.nonzero(lab == J)
pick = rng.random(len(jy)) < 0.006
for yy, xx in zip(jy[pick], jx[pick]):
    for k in range(int(rng.integers(2, 4))):
        if xx + k < W and lab[yy, xx + k] == J: lab[yy, xx + k] = MOSS
print("paving colours", to_png(lab, STONE, "k_field_stone"))
# each stone's rank (1..255, 0 in the joints), one pixel a cell: where the paving meets the lawn, town.gd keeps the
# stones whose rank is over a threshold that rises toward the lawn, so the paving ends in loose stones in the grass
# (owner 2026-11-09: "돌타일, 흙타일과 풀 타일이 맞닿는 부분의 연결타일 더자연스럽게 다듬어서 넣기")
rk = np.where(lab == J, 0, np.where(lab == MOSS, 0, np.array(ranks)[sid])).astype(np.uint8)
Image.fromarray(np.stack([rk, rk, rk, np.full_like(rk, 255)], -1)).save(os.path.join(OUT, "k_field_rank.png"))
