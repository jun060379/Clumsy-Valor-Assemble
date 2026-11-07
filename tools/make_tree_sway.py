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
    """The crown sways as ONE mass (owner 2026-11-07, after the per-ball versions: gaps, ghosts, jelly): the canopy
    layer (every leaf cell) is cut from the trunk and branches, which stay still; the canopy moves in whole 2-px cells,
    the top band first and the band below it a beat later, never more than one cell, easing in and out with holds at
    the ends. Nothing is cut inside the canopy, so no gap or ghost can open; where it leans off a branch, the branch
    shows (it is behind it); at its edge, the sky. 24 frames; frame 23 is the tree as drawn (at rest)."""
    A = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    a = A[::2, ::2].copy()
    h, w = a.shape[:2]
    tm = trunkmask(a)
    op = a[..., 3] > 127
    canopy = op & ~tm
    canopy[int(h * 0.86):] = False                          # the grass at the foot stays
    rows_c = np.nonzero(canopy.any(1))[0]
    top, bot = rows_c.min(), rows_c.max()
    # band per row: 2 = the top third (leads), 1 = the middle (follows), 0 = the lowest leaves (hold on)
    band = np.zeros(h, int)
    span = max(1, bot - top)
    for y in range(top, bot + 1):
        u = (y - top) / span
        band[y] = 2 if u < 0.38 else (1 if u < 0.72 else 0)
    # the lean, one cell at most: rest, ease out to +1 (with the wind), hold, back, rest; the follow band 2 frames later
    lean = [0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0]
    rows = (NF + COLS - 1) // COLS
    out = np.zeros((A.shape[0] * rows, A.shape[1] * COLS, 4), np.uint8)
    base = a.copy()
    base[canopy] = 0
    for f in range(NF):
        o = base.copy()
        for y in range(top, bot + 1):
            sel = canopy[y]
            if not sel.any(): continue
            b = band[y]
            d = 0 if b == 0 else lean[(f - (0 if b == 2 else 2)) % NF]
            xs = np.nonzero(sel)[0]
            nx = np.clip(xs + d, 0, w - 1)
            keep = ~tm[y, nx] | (d == 0)
            o[y, nx[keep]] = a[y, xs[keep]]
        # a cell the crown left beside a branch (the branch held the leaves behind it) is not open air: it keeps
        # its leaves; only the crown's trailing outer edge opens to the sky
        empty = canopy & (o[..., 3] == 0)
        left = np.zeros_like(op); left[:, 1:] = op[:, :-1]
        o[empty & left] = a[empty & left]
        # a one-cell notch where a band steps over the one below: closed with the leaves as drawn
        t = o[..., 3] == 0
        lt = np.zeros_like(t); rt = np.zeros_like(t); lt[:, 1:] = ~t[:, :-1]; rt[:, :-1] = ~t[:, 1:]
        notch = canopy & t & lt & rt
        o[notch] = a[notch]
        o[tm] = a[tm]
        big = np.repeat(np.repeat(o, 2, 0), 2, 1)[:A.shape[0], :A.shape[1]]
        cy, cx = divmod(f, COLS)
        out[cy * A.shape[0]:(cy + 1) * A.shape[0], cx * A.shape[1]:(cx + 1) * A.shape[1]] = big
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, "canopy rows", top, bot)


for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall"]):
    bake(nm)
