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
    """Rustle at the crown's edge only (owner 2026-11-07: every version that moved the crown or its balls read as
    wobble, "울렁거린다"). Slynyrd Pixelblog 33, rustling leaves: one leaf at a time, moving with the wind, the next one
    a frame later. Here: the crown's outline is cut into small tufts (a stretch of outline cells, three cells deep);
    a tuft steps one cell (2 px) with the wind and back, the step running along the outline left to right like a gust
    passing. The rest of the crown, the trunk and the branches never move. 24 frames; frame 23 = the tree as drawn."""
    A = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    a = A[::2, ::2].copy()
    h, w = a.shape[:2]
    tm = trunkmask(a)
    op = a[..., 3] > 127
    canopy = op & ~tm
    canopy[int(h * 0.86):] = False
    air = ~op
    # outline cells that face the air above or to the side (the leaves the wind catches)
    edge = canopy & (ndimage.binary_dilation(air, structure=np.array([[0, 1, 0], [1, 0, 1], [0, 0, 0]])))
    band = canopy & ndimage.binary_dilation(edge, iterations=2)
    # tufts: the band cut every TW cells along x, top and sides apart
    TW = 6
    lab = np.zeros((h, w), int)
    ys, xs = np.nonzero(band)
    cyc = np.nonzero(canopy.any(1))[0]
    mid = (cyc.min() + cyc.max()) / 2
    for y, x in zip(ys, xs):
        lab[y, x] = 1 + (x // TW) * 2 + (1 if y > mid else 0)
    ids = [t for t in np.unique(lab) if t > 0]
    rng = np.random.default_rng(len(ids))
    pick = set(rng.choice(ids, size=max(1, int(len(ids) * 0.55)), replace=False).tolist())   # not every tuft every pass
    rows = (NF + COLS - 1) // COLS
    out = np.zeros((A.shape[0] * rows, A.shape[1] * COLS, 4), np.uint8)
    for f in range(NF):
        o = a.copy()
        for t in ids:
            if t not in pick: continue
            sel = lab == t
            ty, tx = np.nonzero(sel)
            start = int(round(tx.mean() / w * 16))           # the gust runs left to right
            k = f - start
            if not (0 <= k < 3): continue                       # out on frames 0-2 of its turn, home otherwise
            nx = np.clip(tx + 1, 0, w - 1)
            ok = ~tm[ty, nx]
            o[ty[ok], nx[ok]] = a[ty[ok], tx[ok]]
            # the column it left takes the leaf just inside it (no gap, no lit rim)
            lx = tx.min()
            for y in np.unique(ty):
                if canopy[y, lx] and lx - 1 >= 0 and canopy[y, lx - 1]:
                    o[y, lx] = a[y, lx - 1]
        o[tm] = a[tm]
        big = np.repeat(np.repeat(o, 2, 0), 2, 1)[:A.shape[0], :A.shape[1]]
        cy, cx = divmod(f, COLS)
        out[cy * A.shape[0]:(cy + 1) * A.shape[0], cx * A.shape[1]:(cx + 1) * A.shape[1]] = big
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, len(pick), "tufts rustle")


for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall"]):
    bake(nm)
