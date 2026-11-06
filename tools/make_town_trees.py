"""Town trees from generated sources (owner 2026-11-06: reference-quality trees, varied sizes; AI source kept out of the repo).
Each source is cropped, alpha hardened, all four snapped together to one palette, then split like the old trees:
<k>_trunk = bark, grass and the dark canopy mass (stays put), <k>_leaf = the lit leaf clumps (sway), <k> = whole.
Drawn 1:1 (not in BIGK). Usage: python3 tools/make_town_trees.py SRC1.png SRC2.png SRC3.png SRC4.png"""
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab
from scipy.cluster.vq import kmeans2

NAMES = ["f_oak", "f_round", "f_young", "f_tall"]
NPAL = 28

def main():
    ims = []
    for f in sys.argv[1:5]:
        a = np.array(Image.open(f).convert("RGBA"))
        op = a[..., 3] > 128
        ys, xs = np.where(op)
        a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
        op = a[..., 3] > 128
        a[..., 3] = np.where(op, 255, 0)
        # drop single-pixel specks
        p = np.pad(op, 1)
        nb = sum(np.roll(np.roll(p, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))[1:-1, 1:-1] - op
        a[op & (nb == 0), 3] = 0
        ims.append(a)
    cols = np.concatenate([a[a[..., 3] > 0][:, :3] for a in ims])
    u, inv = np.unique(cols, axis=0, return_inverse=True)
    cnt = np.bincount(inv.ravel())
    lab = rgb2lab(u[None].astype(np.float64) / 255.0)[0]
    w = np.repeat(np.arange(len(u)), np.minimum(cnt, 300))
    cent, _ = kmeans2(lab[w], NPAL, minit="++", seed=3, iter=40)
    pal = u[np.array([((lab - c) ** 2).sum(1).argmin() for c in cent])]
    pl = rgb2lab(pal[None].astype(np.float64) / 255.0)[0]
    for name, a in zip(NAMES, ims):
        op = a[..., 3] > 0
        px = a[op][:, :3]
        pidx = np.array([((pl - l) ** 2).sum(1).argmin() for l in rgb2lab(px[None].astype(np.float64) / 255.0)[0]])
        a[op, :3] = pal[pidx]
        r, g, b = [a[..., i].astype(int) for i in range(3)]
        h = a.shape[0]
        green = (g > b + 15) & (g + 12 > r)
        lit = green & (g > 92)
        lit[int(h * 0.86):] = False          # the grass at the foot stays planted
        leaf = a.copy(); leaf[~(lit & op), 3] = 0
        trunk = a.copy(); trunk[lit & op, 3] = 0
        # under the lit clumps the trunk layer carries the canopy's dark mass so a swaying clump never opens a hole
        dark = pal[np.argmin([c[1] if (c[1] > c[0] and c[1] > c[2]) else 999 for c in pal.astype(int)])]
        trunk[lit & op, :3] = dark; trunk[lit & op, 3] = 255
        Image.fromarray(a).save(f"assets/town/{name}.png")
        Image.fromarray(leaf).save(f"assets/town/{name}_leaf.png")
        Image.fromarray(trunk).save(f"assets/town/{name}_trunk.png")
        ys = np.where(lit.any(1))[0]
        print(name, a.shape[1], "x", h, "leaf rows", ys.min(), ys.max())

main()
