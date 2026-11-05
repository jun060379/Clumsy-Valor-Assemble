"""Black outlines to one pixel (owner 2026-11-06): the town sprites were drawn with 2-px dark outlines and line work, twice
the dot of everything else. Outer outline: the dark second row inside a dark edge is repainted with the colour inside it.
Removed pixels take the colour of the pixel just inside them (the commonest light neighbour as a fallback). Usage: python3 tools/thin_outline.py FILE.png [...]   (in place)"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.morphology import skeletonize

N4 = [(-1, 0), (1, 0), (0, -1), (0, 1)]
N8 = N4 + [(-1, -1), (-1, 1), (1, -1), (1, 1)]

def sh(m, dy, dx, fill=False):
    p = np.pad(m, 1, constant_values=fill)
    return p[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]

def thin(path):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    op = a[..., 3] > 127
    if op.sum() < 20: return 0
    lum = (a[..., 0].astype(int) * 3 + a[..., 1].astype(int) * 6 + a[..., 2].astype(int)) / 10.0
    trans_adj = np.zeros_like(op)
    for dy, dx in N4: trans_adj |= ~sh(op, dy, dx)
    border = op & trans_adj
    # the outline colour: the darkest common colour along the edge
    bl = lum[border]
    if bl.size == 0: return 0
    olum = np.percentile(bl, 30)
    dark = op & (lum <= max(olum + 22.0, 58.0))
    kill = np.zeros_like(op)
    out = a.copy()
    # outer: a dark pixel just inside a dark edge pixel, with lighter colour further in -> it takes that inner colour
    inner = op & ~border
    for dy, dx in N4:
        nb_edge_dark = sh(border & dark, dy, dx)
        further = sh(op & ~dark, -dy, -dx)
        k = inner & dark & nb_edge_dark & further & ~kill
        ys, xs = np.nonzero(k)
        out[ys, xs] = a[ys - dy, xs - dx]
        kill |= k
    Image.fromarray(out).save(path)
    return int(kill.sum())

if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(f, thin(f))
