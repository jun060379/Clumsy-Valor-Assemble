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
    a = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    h, w = a.shape[:2]
    leaf = leafmask(a)
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    lit = leaf & (g > 92) & (g > b + 15)
    lit = ndimage.binary_opening(lit, iterations=1)
    lab, n = ndimage.label(lit)
    sizes = ndimage.sum(lit, lab, range(1, n + 1))
    seeds = [ndimage.center_of_mass(lit, lab, i + 1) for i in range(n) if sizes[i] >= 25]
    seeds = np.array(seeds)                                   # (y, x)
    # balls grown from the lit clumps over the luminance: the cuts fall in the dark crevices between clumps
    from skimage.segmentation import watershed
    mk = np.zeros((h, w), int)
    for i, (sy, sx) in enumerate(seeds): mk[int(sy), int(sx)] = i + 1
    ws = watershed(-(r + g + b), mk, mask=leaf)
    ys, xs = np.where(leaf)
    own = ws[ys, xs] - 1
    # backdrop: the tree with every leaf pixel in the canopy's darkest leaf colour, seen only in the 1-px seams
    lum = (r + g + b)[leaf]
    dark = a[leaf][lum.argmin()]
    base = a.copy()
    # (the seams read as lines in dark; the untouched tree shows through them instead)
    # back (dark) balls first, lit front balls last
    order = sorted(range(len(seeds)), key=lambda i: (r + g + b)[ys[own == i], xs[own == i]].mean() if (own == i).any() else 0)
    rng = np.random.default_rng(len(seeds))
    phase = [seeds[i][1] / w * 2.4 + seeds[i][0] / h * 1.2 + rng.uniform(0, 1.6) for i in range(len(seeds))]
    amp = [1.0 + 1.2 * (1.0 - seeds[i][0] / h) + rng.uniform(0, 0.5) for i in range(len(seeds))]   # tops swing most
    # each ball's body: the colour most of it has (one flat fill where it has stepped away)
    body = {}
    for i in range(len(seeds)):
        sel = own == i
        if not sel.any(): continue
        # its shaded body (the most used of its darker half): the place it leaves reads as the shade under it, not
        # as a lit stripe along a branch
        px_ = a[ys[sel], xs[sel]]
        lm = px_[:, :3].astype(int).sum(-1)
        dk = px_[lm <= np.percentile(lm, 15)]
        cols, cnt = np.unique(dk, axis=0, return_counts=True)
        body[i] = cols[cnt.argmax()]
    op0 = a[..., 3] > 0
    rim = leaf & ndimage.binary_dilation(~op0, structure=np.ones((5, 5)))   # the crown's outer two px
    rows = (NF + COLS - 1) // COLS
    out = np.zeros((h * rows, w * COLS, 4), np.uint8)
    for f in range(NF):
        o = base.copy()
        # a ball that steps away leaves its old place; filled with its own body colour (owner 2026-11-07: "뒤에
        # 텍스쳐 남고" -- the drawn tree under it read as a ghost of the leaves); moved balls then land on top
        for i in order:
            sel = own == i
            if sel.any(): o[ys[sel], xs[sel]] = body[i]
        o[rim] = 0                          # on the crown's outline the place left is open air, not a lit rim
        for i in order:
            sel = own == i
            if not sel.any(): continue
            th = 2 * np.pi * f / NF - phase[i]   # each ball rides its own small loop, the wave across the crown
            # moves in whole 2-px steps: the town's pixel (owner 2026-11-06, the 2-px grid)
            dx = 2 * int(round(amp[i] * 0.6 * np.sin(th)))
            dy = 2 * int(round(amp[i] * 0.3 * np.sin(2 * th)))
            py, px = ys[sel] + dy, xs[sel] + dx
            ok = (py >= 0) & (py < h) & (px >= 0) & (px < w)
            o[py[ok], px[ok]] = a[ys[sel][ok], xs[sel][ok]]
        cy, cx = divmod(f, COLS)
        out[cy * h:(cy + 1) * h, cx * w:(cx + 1) * w] = o
    # trunk and branches on top, unmoved: a leaf ball stepping over a branch must not carry or cover its edge
    tm = trunkmask(a)
    for f in range(NF):
        cy, cx = divmod(f, COLS)
        fr = out[cy * h:(cy + 1) * h, cx * w:(cx + 1) * w]
        fr[tm] = a[tm]
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, len(seeds), "balls")

for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall"]):
    bake(nm)
