#!/usr/bin/env python3
"""Pixel-level clean-up pass for a sprite on its own grid (owner 2026-11-06: "한번 더 다듬긴 해야할듯 수동으로" ->
Claude does it pixel by pixel). In place, repeatable:
  python3 tools/art_loop/refine_dot.py FILE.png [...]
  1. lone pixels (no opaque 4-neighbour) and 1-2 px islands off
  2. a pixel whose 4 neighbours all share one other colour takes that colour (speckle)
  3. the silhouette edge is one closed line: an edge pixel lighter than the pixel inside it becomes that inner colour,
     darkened (our outline: the inner colour's dark shade, never black)
  4. pure-black-ish line pixels inside (lum < 28) become the darker shade of their lightest neighbour"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

N4 = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def lum(c):
    return 0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2]


def dark(c):
    d = c.astype(float) * 0.55
    d[..., 0] = np.minimum(255, d[..., 0] * 1.08)
    return d.astype(np.uint8)


def refine(path):
    a = np.array(Image.open(path).convert("RGBA"))
    op = a[..., 3] > 127
    lab, n = ndi.label(op)
    sizes = ndi.sum(op, lab, range(1, n + 1))
    for i, s in enumerate(sizes, 1):
        if s <= 2: op[lab == i] = False
    h, w = op.shape
    rgb = a[..., :3].copy()
    for _ in range(2):
        out = rgb.copy()
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if not op[y, x]: continue
                nb = [(y + dy, x + dx) for dy, dx in N4]
                if not all(op[q] for q in nb): continue
                cs = {tuple(rgb[q]) for q in nb}
                if len(cs) == 1 and tuple(rgb[y, x]) not in cs: out[y, x] = list(cs)[0]
        rgb = out
    # edge: the silhouette ring
    P = np.pad(op, 1)
    inner = P[:-2, 1:-1] & P[2:, 1:-1] & P[1:-1, :-2] & P[1:-1, 2:]
    edge = op & ~inner
    L = lum(rgb.astype(float))
    for y, x in zip(*np.nonzero(edge)):
        best = None
        for dy, dx in N4:
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and op[yy, xx] and not edge[yy, xx]:
                best = (yy, xx) if best is None or L[yy, xx] > L[best] else best
        if best is not None and L[y, x] > L[best] - 10: rgb[y, x] = dark(rgb[best])
    L = lum(rgb.astype(float))
    for y, x in zip(*np.nonzero(op & inner)):
        if L[y, x] >= 28: continue
        nb = [(y + dy, x + dx) for dy, dx in N4]
        q = max(nb, key=lambda q: L[q])
        rgb[y, x] = dark(rgb[q])
    a[..., :3] = rgb
    a[..., 3] = np.where(op, 255, 0)
    Image.fromarray(a).save(path)
    print(path, "refined")


for p in sys.argv[1:]: refine(p)
