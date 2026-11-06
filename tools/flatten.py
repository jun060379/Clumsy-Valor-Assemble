#!/usr/bin/env python3
"""Flat fills for the town sprites (owner 2026-11-07: "같은 영역 같은 구간 유사한 색의 스프라이트가 ... 불규칙하게 막 뿌려져
있으면 그게 잡티 ... 특히 지붕 ... 스프라이트 단색화 ... 팔레트 쳐 쓰라고"), on the 2-px cells, on the map palette.
  1. regions: cells of one material ramp joined side by side, cut by any other ramp (a tile is cut from the next by
     its brown joint; a plaster panel by its timbers)
  2. per region: its body colour is the step most of it has; every cell snaps to one of three steps (body, one
     darker, one lighter); a darker or lighter patch smaller than 6 cells is scatter and takes the body, so only
     shapes stay (tile joints, edge lights, a shadow under a ledge)
  3. clean-up, repeated until nothing changes: a cell keeps its colour only when it is part of a shape: at least two
     of its 4 neighbours, or three of its 8, share it (a line one cell wide keeps; a lone cell or a ragged pair goes to
     the colour most of its same-ramp neighbours have)
Outlines stay: the silhouette edge (a cell with transparency next to it) is never touched.
  python3 tools/flatten.py FILE.png [...]            in place
  python3 tools/flatten.py --preview OUT FILE.png    before / after side by side, not written"""
import json
import os
import sys
from collections import Counter
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
PJ = json.load(open(os.path.join(ROOT, "assets/town/palette.json")))
RAMPS = [PAL[i, :s] for i, s in enumerate(PJ["steps"])]
IDX = {}
for ri, r in enumerate(RAMPS):
    for si, c in enumerate(r): IDX.setdefault(tuple(int(v) for v in c), (ri, si))


MINP = 6


def flatten_cells(a):
    h, w = a.shape[:2]
    op = a[..., 3] > 127
    R = np.full((h, w), -1); S = np.full((h, w), -1)
    for y, x in zip(*np.nonzero(op)):
        t = IDX.get(tuple(int(v) for v in a[y, x, :3]))
        if t: R[y, x], S[y, x] = t
    edge = op & ~ndi.binary_erosion(op, structure=np.ones((3, 3)), border_value=0)
    S2 = S.copy()
    # 2. three steps per region
    for r in np.unique(R[R >= 0]):
        lab, n = ndi.label(R == r)
        for i in range(1, n + 1):
            m = lab == i
            if m.sum() < 6: continue
            body = Counter(S[m].tolist()).most_common(1)[0][0]
            keep = np.array(sorted({max(0, body - 1), body, min(len(RAMPS[r]) - 1, body + 1)}))
            s = S[m]
            near = np.abs(s - body) <= 2
            S2[m] = np.where(near, keep[np.abs(s[:, None] - keep[None]).argmin(1)], s)
            # a shade or light inside the region is kept only as a shape (a joint line, an edge): any patch of one
            # step smaller than MINP cells is scatter and takes the body
            reg = S2 * m
            for v in np.unique(S2[m]):
                if v == body: continue
                lab2, n2 = ndi.label(m & (S2 == v), structure=np.ones((3, 3)))
                if n2 == 0: continue
                sz = ndi.sum(np.ones_like(lab2), lab2, index=np.arange(1, n2 + 1))
                small = np.isin(lab2, np.nonzero(sz < MINP)[0] + 1)
                S2[small & ~edge] = body
    # 3. lone cells and ragged pairs take their surroundings
    for _ in range(6):
        ch = 0
        S3 = S2.copy()
        for y, x in zip(*np.nonzero((R >= 0) & ~edge)):
            r, s = R[y, x], S2[y, x]
            n4 = n8 = 0; nb = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0: continue
                    Y, X = y + dy, x + dx
                    if not (0 <= Y < h and 0 <= X < w) or R[Y, X] != r: continue
                    nb.append(S2[Y, X])
                    if S2[Y, X] == s:
                        n8 += 1
                        if dx == 0 or dy == 0: n4 += 1
            if n4 >= 2 or n8 >= 3 or len(nb) < 4: continue
            S3[y, x] = Counter(nb).most_common(1)[0][0]; ch += 1
        S2 = S3
        if ch == 0: break
    out = a.copy()
    for y, x in zip(*np.nonzero((R >= 0) & (S2 != S))):
        out[y, x, :3] = RAMPS[R[y, x]][S2[y, x]]
    return out, int(((R >= 0) & (S2 != S)).sum())


def run(p, write=True):
    a = np.array(Image.open(p).convert("RGBA"))
    cells = a[0::2, 0::2]
    grid = (np.repeat(np.repeat(cells, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]] == a).all()
    if grid:
        oc, n = flatten_cells(cells)
        out = np.repeat(np.repeat(oc, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
    else:
        out, n = flatten_cells(a)
    if write and n: Image.fromarray(out).save(p)
    return a, out, n


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[0] == "--preview":
        a, out, n = run(args[2], False)
        s = Image.new("RGBA", (a.shape[1] * 2 + 8, a.shape[0]), (40, 46, 52, 255))
        s.alpha_composite(Image.fromarray(a), (0, 0)); s.alpha_composite(Image.fromarray(out), (a.shape[1] + 8, 0))
        s.save(args[1]); print(n)
    else:
        for p in args:
            print(os.path.relpath(p, ROOT), run(p)[2])
