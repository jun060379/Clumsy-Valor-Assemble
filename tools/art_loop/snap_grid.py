#!/usr/bin/env python3
"""Snap a sprite onto the k-px grid (owner 2026-11-06: the town's unit is 2 px; the few 1-px bits in a tile break it).
  python3 tools/art_loop/snap_grid.py FILE.png [...] [--k 2]      (in place)
Finds the grid offset that most blocks already sit on, then every k x k block takes its commonest colour (alpha by
majority). Size and position stay the same."""
import sys
from collections import Counter
import numpy as np
from PIL import Image

args = sys.argv[1:]
K = int(args[args.index("--k") + 1]) if "--k" in args else 2
files = [a for i, a in enumerate(args) if a != "--k" and (i == 0 or args[i - 1] != "--k")]


def aligned(a, k, oy, ox):
    b = a[oy:, ox:]
    h, w = (b.shape[0] // k) * k, (b.shape[1] // k) * k
    r = b[:h, :w].reshape(h // k, k, w // k, k, 4)
    same = (r == r[:, :1, :, :1]).all(axis=(1, 3, 4))
    op = r[:, 0, :, 0, 3] > 127
    return same[op].mean() if op.any() else 0.0


for f in files:
    a = np.array(Image.open(f).convert("RGBA"))
    oy, ox = max(((y, x) for y in range(K) for x in range(K)), key=lambda o: aligned(a, K, *o))
    before = aligned(a, K, oy, ox)
    out = a.copy()
    H, W = a.shape[:2]
    for y0 in range(oy - K if oy else 0, H, K):
        for x0 in range(ox - K if ox else 0, W, K):
            ys, xs = slice(max(0, y0), min(H, y0 + K)), slice(max(0, x0), min(W, x0 + K))
            blk = a[ys, xs].reshape(-1, 4)
            if blk.size == 0: continue
            opq = blk[blk[:, 3] > 127]
            if len(opq) * 2 < len(blk):
                out[ys, xs] = 0
                continue
            c = Counter(map(tuple, opq[:, :3])).most_common(1)[0][0]
            out[ys, xs, :3] = c
            out[ys, xs, 3] = 255
    Image.fromarray(out).save(f)
    print(f, f"offset {oy},{ox}", f"aligned {before:.2f} -> {aligned(out, K, oy, ox):.2f}")
