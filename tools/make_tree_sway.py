"""Leaf sway for the town trees: ONLY THE LEAVES MOVE (owner 2026-11-07: "나뭇잎만 흔들려야 ... 나뭇가지랑 나뭇잎 분리").
The tree is split by its palette ramps (assets/town/palette.png): wood = trunk and branches, leaf / green = leaves; the
dark outline cells (stone ramp) go with whichever of the two they touch more. Each frame is built in layers:
  1. the canopy's backdrop: every leaf cell in the canopy's darkest leaf colour (what shows when a ball steps aside)
  2. trunk and branches, as drawn, never moved
  3. the leaf balls (the canopy cut along its dark crevices), each on its own small loop in whole 2-px steps, the
     darker (farther) balls first
Before 2026-11-07 the balls were cut from a mask that took the branches' dark outlines as leaf and were pasted over the
tree as drawn, so branch edges rode with the leaves and the old leaves ghosted under the moved ones.
Writes assets/town/<k>_sway.png: NF frames, COLS wide.  python3 tools/make_tree_sway.py [names...]
  --check: how many trunk / branch cells change between frames (must be 0)"""
import json
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
from skimage.segmentation import watershed

NF = 24
COLS = 6
PAL = np.array(Image.open("assets/town/palette.png").convert("RGB"))
PJ = json.load(open("assets/town/palette.json"))
RAMP = {}
for ri, s in enumerate(PJ["steps"]):
    for c in PAL[ri, :s]: RAMP.setdefault(tuple(int(v) for v in c), PJ["names"][ri])


def split(a):
    """-> trunk mask, leaf mask (pixels)"""
    h, w = a.shape[:2]
    op = a[..., 3] > 127
    name = np.full((h, w), "", object)
    for y, x in zip(*np.nonzero(op)): name[y, x] = RAMP.get(tuple(int(v) for v in a[y, x, :3]), "?")
    wood = name == "wood"
    leaf = (name == "leaf") | (name == "green")
    other = op & ~wood & ~leaf
    k = np.ones((7, 7))
    nw = ndimage.convolve(wood.astype(float), k, mode="constant")
    nl = ndimage.convolve(leaf.astype(float), k, mode="constant")
    trunk = wood | (other & (nw >= nl))
    return trunk, op & ~trunk


def frames(a):
    h, w = a.shape[:2]
    trunk, leaf = split(a)
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    lum = r + g + b
    lit = ndimage.binary_opening(leaf & (lum > np.percentile(lum[leaf], 55)), iterations=1)
    lab, n = ndimage.label(lit)
    sizes = ndimage.sum(lit, lab, range(1, n + 1))
    seeds = [ndimage.center_of_mass(lit, lab, i + 1) for i in range(n) if sizes[i] >= 25]
    mk = np.zeros((h, w), int)
    for i, (sy, sx) in enumerate(seeds): mk[int(sy), int(sx)] = i + 1
    ws = watershed(-lum, mk, mask=leaf)
    ys, xs = np.nonzero(leaf)
    own = ws[ys, xs] - 1
    dark = a[leaf][lum[leaf].argmin()]
    back = np.zeros_like(a)
    back[leaf] = dark                      # 1. backdrop
    back[trunk] = a[trunk]                 # 2. trunk and branches
    order = sorted(range(len(seeds)), key=lambda i: lum[ys[own == i], xs[own == i]].mean() if (own == i).any() else 0)
    rng = np.random.default_rng(len(seeds))
    phase = [seeds[i][1] / w * 2.4 + seeds[i][0] / h * 1.2 + rng.uniform(0, 1.6) for i in range(len(seeds))]
    amp = [0.7 + 0.8 * (1.0 - seeds[i][0] / h) + rng.uniform(0, 0.3) for i in range(len(seeds))]   # tops sway most
    out = []
    for f in range(NF):
        o = back.copy()
        for i in order:                    # 3. leaf balls
            sel = own == i
            if not sel.any(): continue
            th = 2 * np.pi * f / NF - phase[i]
            dx = 2 * int(round(amp[i] * 0.6 * np.sin(th)))
            dy = 2 * int(round(amp[i] * 0.3 * np.sin(2 * th)))
            py, px = ys[sel] + dy, xs[sel] + dx
            ok = (py >= 0) & (py < h) & (px >= 0) & (px < w)
            o[py[ok], px[ok]] = a[ys[sel][ok], xs[sel][ok]]
        out.append(o)
    return out, trunk, len(seeds)


def bake(name, write=True):
    a = np.array(Image.open(f"assets/town/{name}.png").convert("RGBA"))
    fr, trunk, nb = frames(a)
    h, w = a.shape[:2]
    # check: a trunk / branch cell may be hidden by a leaf stepping over it, but never shows anything else of the trunk
    moved = 0
    for o in fr:
        tr = trunk & ~split(o)[1]          # cells that are trunk-coloured in this frame
        moved += int((tr & ~trunk).sum())
    if write:
        rows = (NF + COLS - 1) // COLS
        sheet = np.zeros((h * rows, w * COLS, 4), np.uint8)
        for f, o in enumerate(fr):
            cy, cx = divmod(f, COLS)
            sheet[cy * h:(cy + 1) * h, cx * w:(cx + 1) * w] = o
        Image.fromarray(sheet).save(f"assets/town/{name}_sway.png")
    print(name, nb, "balls; trunk cells out of place:", moved)
    return fr


if __name__ == "__main__":
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    for nm in (args or ["f_oak", "f_round", "f_young", "f_tall", "f_bigtree"]):
        bake(nm, "--check" not in sys.argv)
