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
    """Leaf-ball wave, after Slynyrd Pixelblog 33 (owner 2026-11-07: "너무 울렁거린다; 래퍼런스 찾아" -- the bending
    field read as jelly). The reference: each ball of leaves is a rigid unit that steps up-right 1 px, down 1 px, left
    1 px, home; the balls go in sequence so ONE wave crosses the crown per loop; nothing warps. Here on the town's
    2-px cells (1 step = 1 cell = 2 px): 24 frames at 0.1 s; a ball's step lasts 2 frames and the wave reaches the
    balls left to right (with the wind), the higher balls a frame later; most of the loop a ball rests. Behind the
    balls the tree as drawn stays (no gaps); trunk and branches are drawn unmoved on top."""
    A = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    a = A[::2, ::2].copy()
    h, w = a.shape[:2]
    tm = trunkmask(a)
    leaf = leafmask(a) & ~tm
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    lum = r + g + b
    lit = ndimage.binary_opening(leaf & (lum > np.percentile(lum[leaf], 50)), iterations=1)
    lab, n = ndimage.label(lit)
    sizes = ndimage.sum(lit, lab, range(1, n + 1))
    seeds = [ndimage.center_of_mass(lit, lab, i + 1) for i in range(n) if sizes[i] >= 6]
    from skimage.segmentation import watershed
    mk = np.zeros((h, w), int)
    for i, (sy, sx) in enumerate(seeds): mk[int(sy), int(sx)] = i + 1
    ws = watershed(-lum, mk, mask=leaf)
    ys, xs = np.nonzero(leaf)
    own = ws[ys, xs] - 1
    # the balls in a few big masses that move as one (owner 2026-11-07: "존나 흐물거리잖아" -- a dozen balls each on
    # its own beat read as jelly): left, right and, on a tall crown, the top; a mass steps as a rigid unit
    sx_ = np.array([q[1] for q in seeds]); sy_ = np.array([q[0] for q in seeds])
    cxm = np.median(xs); top_cut = ys.min() + 0.33 * (ys.max() - ys.min())
    grp = np.where(sx_ < cxm, 0, 1)
    if h > w * 1.1: grp = np.where(sy_ < top_cut, 2, grp)
    order = sorted(range(len(seeds)), key=lambda i: lum[ys[own == i], xs[own == i]].mean() if (own == i).any() else 0)
    STEPS = [(1, -1), (1, 0), (0, 0)]       # up-right, down, left (home): the reference's loop
    HOLD = 3
    rows = (NF + COLS - 1) // COLS
    out = np.zeros((A.shape[0] * rows, A.shape[1] * COLS, 4), np.uint8)
    for f in range(NF):
        o = a.copy()
        for i in order:
            sel = own == i
            if not sel.any(): continue
            start = [0, 6, 3][grp[i]]                                  # left mass, then the top, then the right
            k = (f - start) % NF // HOLD
            dx, dy = STEPS[k] if k < len(STEPS) else (0, 0)
            if dx == 0 and dy == 0: continue
            py, px = ys[sel] + dy, xs[sel] + dx
            ok = (py >= 0) & (py < h) & (px >= 0) & (px < w) & ~tm[np.clip(py, 0, h - 1), np.clip(px, 0, w - 1)]
            o[py[ok], px[ok]] = a[ys[sel][ok], xs[sel][ok]]
        o[tm] = a[tm]
        big = np.repeat(np.repeat(o, 2, 0), 2, 1)[:A.shape[0], :A.shape[1]]
        cy, cx = divmod(f, COLS)
        out[cy * A.shape[0]:(cy + 1) * A.shape[0], cx * A.shape[1]:(cx + 1) * A.shape[1]] = big
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, len(seeds), "balls")


for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall", "f_bigtree"]):
    bake(nm)
