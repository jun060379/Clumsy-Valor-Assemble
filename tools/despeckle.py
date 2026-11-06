#!/usr/bin/env python3
"""Specks out of the town sprites (owner 2026-11-07: "지붕이나 등등에 잡티 남은 거 제거"), on the 2-px cells.
A speck: a cell whose colour belongs to a different material ramp than most of the cells round it (a violet or grey dot
on a red roof, a green fleck on a wall), and which no more than one of its 8 neighbours shares. It takes the colour
most of its neighbours have. Outlines and the art's own same-material shading are left alone (same ramp = not a speck).
  python3 tools/despeckle.py FILE.png [...]          in place; prints the count per file
  python3 tools/despeckle.py --check FILE.png [...]  count only"""
import json
import os
import sys
from collections import Counter
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
PJ = json.load(open(os.path.join(ROOT, "assets/town/palette.json")))
RAMP = {}
for ri, s in enumerate(PJ["steps"]):
    for c in PAL[ri, :s]: RAMP.setdefault(tuple(int(v) for v in c), ri)


def clean_cells(a):
    """a: cells (h, w, 4) uint8 -> (cleaned, count)"""
    h, w = a.shape[:2]
    out = a.copy()
    n = 0
    op = a[..., 3] > 127
    for y in range(h):
        for x in range(w):
            if not op[y, x]: continue
            c = tuple(int(v) for v in a[y, x, :3])
            nb = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0: continue
                    Y, X = y + dy, x + dx
                    if 0 <= Y < h and 0 <= X < w and op[Y, X]: nb.append(tuple(int(v) for v in a[Y, X, :3]))
            if len(nb) < 6: continue                        # the silhouette's edge: an outline, not a speck
            same = sum(1 for q in nb if q == c)
            if same > 1: continue
            r = RAMP.get(c, -1)
            ramps = Counter(RAMP.get(q, -1) for q in nb)
            top_r, top_n = ramps.most_common(1)[0]
            if top_r == r or top_n < 5: continue            # its own material round it, or no clear surrounding
            best = Counter(q for q in nb if RAMP.get(q, -1) == top_r).most_common(1)[0][0]
            out[y, x, :3] = best
            n += 1
    return out, n


def clean_file(p, write=True):
    a = np.array(Image.open(p).convert("RGBA"))
    cells = a[0::2, 0::2]
    on_grid = (np.repeat(np.repeat(cells, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]] == a).all()
    if not on_grid:
        out, n = clean_cells(a)
    else:
        oc, n = clean_cells(cells)
        out = np.repeat(np.repeat(oc, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
    if write and n: Image.fromarray(out).save(p)
    return n


if __name__ == "__main__":
    args = sys.argv[1:]
    chk = "--check" in args
    for p in [a for a in args if a != "--check"]:
        print(os.path.relpath(p, ROOT), clean_file(p, not chk))
