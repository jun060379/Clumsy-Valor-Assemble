"""Black outlines to one pixel (owner 2026-11-06): the town sprites were drawn with 2-px dark outlines and line work, twice
the dot of everything else. Outer outline: the dark second row inside a dark edge is repainted with the colour inside it.
Inner line work: dark strokes at most 2 px thick (not part of a 3x3 dark patch) are skeletonised to 1 px. Removed pixels take
the commonest light neighbour colour. Usage: python3 tools/thin_outline.py FILE.png [...]   (in place)"""
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
    # outer: a dark pixel just inside a dark edge pixel, with lighter colour further in
    inner = op & ~border
    for dy, dx in N4:
        nb_edge_dark = sh(border & dark, dy, dx)
        further = sh(op & ~dark, -dy, -dx)
        kill |= inner & dark & nb_edge_dark & further
    # inner line work: thin dark strokes (no 3x3 dark patch) inside the sprite, not on the edge
    patch = ndi.binary_dilation(ndi.binary_erosion(dark, np.ones((3, 3))), np.ones((3, 3)))
    stroke = dark & ~patch & ~border & ~kill
    skel = skeletonize(stroke)
    # keep stroke pixels touching the edge outline so lines still meet it
    kill |= stroke & ~skel
    out = a.copy()
    keep = op & ~kill
    for _ in range(4):
        todo = np.argwhere(kill & ~keep)
        if len(todo) == 0: break
        newly = []
        for y, x in todo:
            cols = {}
            for dy, dx in N8:
                yy, xx = y + dy, x + dx
                if 0 <= yy < a.shape[0] and 0 <= xx < a.shape[1] and keep[yy, xx] and not dark[yy, xx]:
                    c = tuple(out[yy, xx])
                    cols[c] = cols.get(c, 0) + (2 if (dy == 0 or dx == 0) else 1)
            if cols:
                out[y, x] = max(cols, key=cols.get)
                newly.append((y, x))
        for y, x in newly:
            keep[y, x] = True
            dark[y, x] = False
    Image.fromarray(out).save(path)
    return int(kill.sum())

if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(f, thin(f))
