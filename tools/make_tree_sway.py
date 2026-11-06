"""Leaf-ball sway for the town trees (owner 2026-11-06; Slynyrd Pixelblog 33 method): the canopy cut into leaf balls,
each ball walks a 1-px loop (up-right, down, left, home) in turn, so the crown ripples while trunk and branches stay.
Writes assets/town/<k>_sway.png: NF frames side by side. Usage: python3 tools/make_tree_sway.py [names...]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

NF = 8
PATH = [(1, -1), (1, 0), (0, 0)]          # steps after rest; the rest of the loop sits at (0, 0)

def leafmask(a):
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    m = (al > 0) & ~(r > g + 6) & ~((r > 190) & (g > 190) & (b > 150))
    m[int(a.shape[0] * 0.86):] = False
    return m

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
    ys, xs = np.where(leaf)
    d = (ys[:, None] - seeds[None, :, 0]) ** 2 + (xs[:, None] - seeds[None, :, 1]) ** 2
    own = d.argmin(1)
    # backdrop: the tree with every leaf pixel in the canopy's darkest leaf colour, seen only in the 1-px seams
    lum = (r + g + b)[leaf]
    dark = a[leaf][lum.argmin()]
    base = a.copy()
    # (the seams read as lines in dark; the untouched tree shows through them instead)
    # back (dark) balls first, lit front balls last
    order = sorted(range(len(seeds)), key=lambda i: (r + g + b)[ys[own == i], xs[own == i]].mean() if (own == i).any() else 0)
    out = np.zeros((h, w * NF, 4), np.uint8)
    for f in range(NF):
        o = base.copy()
        for i in order:
            sel = own == i
            if not sel.any(): continue
            k = (f - int(seeds[i][1] / w * NF * 0.75 + seeds[i][0] / h * 2)) % NF   # the wave runs across the crown
            dx, dy = PATH[k] if k < len(PATH) else (0, 0)
            py, px = ys[sel] + dy, xs[sel] + dx
            ok = (py >= 0) & (py < h) & (px >= 0) & (px < w)
            o[py[ok], px[ok]] = a[ys[sel][ok], xs[sel][ok]]
        out[:, f * w:(f + 1) * w] = o
    Image.fromarray(out).save(f"assets/town/{name}_sway.png")
    print(name, len(seeds), "balls")

for nm in (sys.argv[1:] or ["f_oak", "f_round", "f_young", "f_tall"]):
    bake(nm)
