"""One shared palette for the town sprites (owner 2026-11-06 test): every opaque colour of the listed sprites clustered
(k-means in Lab) to N colours, each pixel snapped to its nearest. Usage: python3 tools/town_palette.py N FILE.png [...] (in place)"""
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab
from scipy.cluster.vq import kmeans2

def main():
    n = int(sys.argv[1]); files = sys.argv[2:]
    ims = [np.array(Image.open(f).convert("RGBA")) for f in files]
    cols = np.concatenate([a[a[..., 3] > 127][:, :3] for a in ims])
    u, cnt = np.unique(cols, axis=0, return_counts=True)
    lab = rgb2lab(u[None].astype(np.float64) / 255.0)[0]
    rng = np.random.default_rng(1)
    w = np.repeat(np.arange(len(u)), np.minimum(cnt, 400))      # weight by use, capped
    cent, _ = kmeans2(lab[w], n, minit="++", seed=1, iter=30)
    # snap each centre to the nearest real colour so the palette is made of colours the art used
    pal = u[np.array([((lab - c) ** 2).sum(1).argmin() for c in cent])]
    pl = rgb2lab(pal[None].astype(np.float64) / 255.0)[0]
    m = {tuple(c): pal[((pl - l) ** 2).sum(1).argmin()] for c, l in zip(map(tuple, u), lab)}
    for f, a in zip(files, ims):
        op = a[..., 3] > 127
        idx = np.argwhere(op)
        for y, x in idx: a[y, x, :3] = m[tuple(a[y, x, :3])]
        Image.fromarray(a).save(f)
    print(len(u), "->", len(set(map(tuple, pal))))

main()
