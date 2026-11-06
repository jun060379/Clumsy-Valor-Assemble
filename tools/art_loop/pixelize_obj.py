#!/usr/bin/env python3
"""A high-resolution object picture -> a town sprite at its real size on the 1-px grid (owner 2026-11-06: the fence,
yard, buildings, wagon, horse and lamp were drawn small and blown up, their pixels 2-3x the grass's).
  python3 tools/art_loop/pixelize_obj.py IN.png OUT.png WIDTH [--colours N] [--bg white|alpha] [--crop x0,y0,x1,y1]
Steps: background off (flat white flood-filled from the border, or the alpha) -> crop -> area-average down to WIDTH px
(colour averaged over the covered part only, alpha by coverage) -> k-means palette in Lab -> lone pixels to their
neighbours -> a 1-px outline on the silhouette in the darker shade of the colour inside it (our rule: never black).
The source (AI or not) stays out of the repo; only OUT goes in."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from sklearn.cluster import KMeans
from skimage.color import rgb2lab, lab2rgb

a = sys.argv[1:]
src, out, TW = a[0], a[1], int(a[2])
NC = int(a[a.index("--colours") + 1]) if "--colours" in a else 24
BG = a[a.index("--bg") + 1] if "--bg" in a else "white"
im = Image.open(src).convert("RGBA")
if "--crop" in a:
    im = im.crop(tuple(int(v) for v in a[a.index("--crop") + 1].split(",")))
A = np.array(im).astype(float)
if BG == "white":
    # flat near-white connected to the border = background
    lite = (A[..., :3].min(2) > 232) & (A[..., :3].max(2) - A[..., :3].min(2) < 14)
    lab, _ = ndi.label(lite)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(edge))
    A[..., 3] = np.where(bgm, 0, 255)
else:
    A[..., 3] = np.where(A[..., 3] > 200, 255, 0)      # soft glow / halo around a cut-out -> off
im = Image.fromarray(A.astype(np.uint8))
bb = im.getbbox()
im = im.crop(bb)
s = TW / im.width
w, h = TW, max(1, round(im.height * s))
big = np.array(im).astype(float)
al = big[..., 3:] / 255.0
pm = Image.fromarray(np.uint8(np.clip(big[..., :3] * al, 0, 255))).resize((w, h), Image.BOX)
am = im.getchannel("A").resize((w, h), Image.BOX)
Al = np.array(am).astype(float) / 255
C = np.array(pm).astype(float) / np.maximum(Al[..., None], 1e-3)
op = Al > 0.5
op = ndi.binary_opening(op, np.ones((2, 1))) | ndi.binary_opening(op, np.ones((1, 2)))   # no 1-px hairs
labc = rgb2lab(np.clip(C / 255, 0, 1))
km = KMeans(NC, n_init=4, random_state=0).fit(labc[op])
pal = np.clip(lab2rgb(km.cluster_centers_[None])[0] * 255, 0, 255)
idx = np.full(op.shape, -1)
idx[op] = km.labels_
for _ in range(2):                                   # lone pixels -> their neighbours' colour
    P = np.pad(idx, 1, constant_values=-1)
    N = [P[:-2, 1:-1], P[2:, 1:-1], P[1:-1, :-2], P[1:-1, 2:]]
    o = idx.copy()
    for y, x in zip(*np.nonzero(op)):
        nb = [n[y, x] for n in N]
        if idx[y, x] in nb: continue
        v, c = np.unique(nb, return_counts=True)
        i = c.argmax()
        if c[i] >= 3 and v[i] >= 0: o[y, x] = v[i]
    idx = o
rgb = np.zeros((h, w, 4), np.uint8)
rgb[op, :3] = pal[idx[op]].astype(np.uint8)
rgb[op, 3] = 255
# outline: silhouette edge pixels become the darker shade of their own colour (x0.55, a little warmer)
P = np.pad(op, 1)
edge = op & ~(P[:-2, 1:-1] & P[2:, 1:-1] & P[1:-1, :-2] & P[1:-1, 2:])
c = rgb[edge, :3].astype(float)
d = c * 0.55
d[:, 0] = np.minimum(255, d[:, 0] * 1.08)
rgb[edge, :3] = d.astype(np.uint8)
Image.fromarray(rgb).save(out)
print(out, f"{w}x{h}", NC, "colours")
