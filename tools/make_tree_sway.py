"""Leaf-ball sway for the town trees (owner 2026-11-06; Slynyrd Pixelblog 33 method): the canopy cut into leaf balls,
each ball walks a 1-px loop (up-right, down, left, home) in turn, so the crown ripples while trunk and branches stay.
Writes assets/town/<k>_sway.png: NF frames side by side. Usage: python3 tools/make_tree_sway.py [names...]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

NF = 24                                   # frames per loop, laid out COLS wide
COLS = 6

import json
_PAL = np.array(Image.open("assets/town/palette.png").convert("RGB"))
_PJ = json.load(open("assets/town/palette.json"))
RAMP = {}
for _ri, _s in enumerate(_PJ["steps"]):
    for _c in _PAL[_ri, :_s]: RAMP.setdefault(tuple(int(v) for v in _c), _PJ["names"][_ri])


def trunkmask(a):
    """trunk and branches (owner 2026-11-07: "나뭇잎만 흔들려야 ... 나뭇가지랑 나뭇잎 분리"): the wood ramp, and the dark
    outline cells (any other ramp) that touch more wood than leaf -- the branches' own edges stay with the branches"""
    h, w = a.shape[:2]
    op = a[..., 3] > 127
    wood = np.zeros((h, w), bool); leaf = np.zeros((h, w), bool)
    for y, x in zip(*np.nonzero(op)):
        n = RAMP.get(tuple(int(v) for v in a[y, x, :3]), "")
        wood[y, x] = n == "wood"; leaf[y, x] = n in ("leaf", "green")
    k = np.ones((7, 7))
    nw = ndimage.convolve(wood.astype(float), k, mode="constant")
    nl = ndimage.convolve(leaf.astype(float), k, mode="constant")
    return wood | (op & ~wood & ~leaf & (nw >= nl))


def leafmask(a):
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    m = (al > 0) & ~(r > g + 6) & ~((r > 190) & (g > 190) & (b > 150))
    m[int(a.shape[0] * 0.86):] = False
    return m & ~trunkmask(a)

def bake(name):
    """Natural sway (owner 2026-11-07: "모션 더 자연스럽게"): the crown BENDS instead of its balls jumping. On the 2-px
    cells, every leaf cell is displaced by a smooth wind field: a slow lean of the whole crown plus a gust wave
    travelling across it, scaled by how far the cell is from the nearest trunk / branch cell (leaves at a branch hold
    on, the outer tips swing most). The frame is built by looking each cell up at (cell - displacement), so the canopy
    stretches and closes instead of opening gaps or leaving ghosts; trunk and branches are drawn unmoved on top.
    24 frames, one cell (2 px) steps."""
    A = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    a = A[::2, ::2].copy()                        # cells
    h, w = a.shape[:2]
    tm = trunkmask(a)
    lf = leafmask(a) & ~tm
    lf |= (a[..., 3] > 127) & ~tm & (np.arange(h)[:, None] < int(h * 0.86))
    dist = ndimage.distance_transform_edt(~tm)
    reach = max(8.0, np.percentile(dist[lf], 90)) if lf.any() else 8.0
    wgt = np.clip(dist / reach, 0, 1) ** 1.3
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    hh = 1.0 - yy / h                              # higher swings more
    rows = (NF + COLS - 1) // COLS
    out = np.zeros((A.shape[0] * rows, A.shape[1] * COLS, 4), np.uint8)
    region = ndimage.binary_dilation(lf, iterations=2) & ~tm
    for f in range(NF):
        t = 2 * np.pi * f / NF
        lean = 0.55 * np.sin(t) + 0.25 * np.sin(2 * t + 1.1)                   # the whole crown, slow
        gust = 0.6 * np.sin(t - xx / max(w, 1) * 2 * np.pi * 0.8 - yy / h * 1.5)  # a wave across it
        dx = np.round((lean + gust) * 1.6 * wgt * (0.5 + 0.5 * hh))
        dy = np.round(0.45 * np.sin(2 * t - xx / max(w, 1) * 4.0) * wgt * hh)
        sx = np.clip((xx - dx).astype(int), 0, w - 1); sy = np.clip((yy - dy).astype(int), 0, h - 1)
        o = a.copy()
        o[region] = 0
        take = region & lf[sy, sx]
        o[take] = a[sy[take], sx[take]]
        keep = lf & ~take                          # a leaf cell with nothing coming in keeps its own colour: no holes
        o[keep] = a[keep]
        o[tm] = a[tm]
        big = np.repeat(np.repeat(o, 2, 0), 2, 1)[:A.shape[0], :A.shape[1]]
        cy, cx = divmod(f, COLS)
        out[cy * A.shape[0]:(cy + 1) * A.shape[0], cx * A.shape[1]:(cx + 1) * A.shape[1]] = big
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, "reach", round(reach, 1), "cells")


for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall", "f_bigtree"]):
    bake(nm)
