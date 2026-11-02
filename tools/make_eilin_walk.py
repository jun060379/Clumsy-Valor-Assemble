#!/usr/bin/env python3
"""Eilin's walk: slice the delivered walk sheet (6 x 5 loose grid, 29 frames facing right, transparent background) and
pack the loop into assets/eilin/walkL.png in the eilin.gd sheet format (one row of cells, feet on the cell's bottom line,
body centred in the cell; eilin.gd draws it at EILS_SIDE / 2 and mirrors it for walking left).

Source analysis (2026-11, bd10706d-image.png): the 29 frames are one full two-step cycle plus a repeat of the first pose
(frame 28 ~ frame 0). Frames 0-12 are the step on one leg, 13-27 on the other. The planted foot slides back about 8
source px per frame, evenly, so every second frame (0, 2, ..., 26) keeps the motion even and thins the near-duplicate
passing poses (5/6/7, 19/20); 26 -> 0 closes the loop at the same spacing.

Per frame:
  * frame = the alpha pieces whose centre falls in its grid slot (so a stray hair tip that crosses a gap stays with it);
  * baseline: the lowest solid row (the planted shoe) goes on the feet line, so her own up-and-down is kept;
  * horizontal anchor: the body (mean of the jacket centroid and the face centroid), not the bbox, goes on the cell's
    centre, so swinging hair and legs don't push her around;
  * scale: one factor for the strip: the tallest (passing) pose -> TARGET_H sheet px, the height of her standing idle art
    (idleA/idleS: 310 px of a 320 cell), so she keeps her size when she starts and stops walking.

usage: python3 tools/make_eilin_walk.py <source.png> [out.png]       (prints the cell size and the EILM / EILSPD values)
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

COLS, ROWS, N = 6, 5, 29
LOOP = list(range(0, 28, 2))      # 14 frames, every second one of the 28-frame cycle
TARGET_H = 306                    # sheet px of the tallest frame (idleA stands 310 px tall incl. the hair crown)
CELL_H = 316                      # same as the old walkL / run sheets
FEET = CELL_H - 2                 # the lowest solid row lands here (walkL / run: 314)
PAD = 3
SRC_STEP = 8.1                    # source px her planted foot slides back per source frame (measured, see above)
EILS_SIDE = 0.79                  # eilin.gd: drawn at EILS_SIDE / 2 of the sheet
EIL_SPD = 0.075                   # eilin.gd: world px per ms


def frames(im):
    """[(rgba crop, x0, y0)] for the N frames in reading order"""
    H, W = im.shape[:2]
    mask = im[..., 3] > 20
    lab, k = ndimage.label(mask, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(mask, lab, range(1, k + 1))
    # rows / columns of the loose grid from the empty bands between the figures
    def bands(prof, n):
        on = prof > 0
        runs, s = [], None
        for i, v in enumerate(list(on) + [False]):
            if v and s is None: s = i
            if not v and s is not None: runs.append((s, i)); s = None
        runs = [r for r in runs if r[1] - r[0] > 40]
        assert len(runs) == n, (len(runs), n, runs)
        return runs
    rows = bands(mask.sum(1), ROWS)
    slots = {}
    for i, sl in enumerate(objs):
        if sizes[i] < 4: continue
        cy, cx = (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2
        r = min(range(ROWS), key=lambda j: 0 if rows[j][0] <= cy < rows[j][1] else min(abs(cy - rows[j][0]), abs(cy - rows[j][1])))
        slots.setdefault(r, []).append((i + 1, sl, cx))
    out = []
    for r in range(ROWS):
        y0, y1 = rows[r]
        # columns in this row
        rm = np.zeros(W, bool)
        for lid, sl, cx in slots[r]:
            if sizes[lid - 1] > 500: rm[sl[1]] = True
        cols, s = [], None
        for i, v in enumerate(list(rm) + [False]):
            if v and s is None: s = i
            if not v and s is not None: cols.append((s, i)); s = None
        for c0, c1 in cols:
            keep = [(lid, sl) for lid, sl, cx in slots[r] if c0 - 8 <= cx < c1 + 8]
            ys0 = min(sl[0].start for _, sl in keep); ys1 = max(sl[0].stop for _, sl in keep)
            xs0 = min(sl[1].start for _, sl in keep); xs1 = max(sl[1].stop for _, sl in keep)
            m = np.isin(lab[ys0:ys1, xs0:xs1], [lid for lid, _ in keep])
            crop = im[ys0:ys1, xs0:xs1].copy()
            crop[~m] = 0
            out.append((crop, xs0, ys0))
    assert len(out) == N, len(out)
    return out


def body_x(crop):
    """the body's centre column: mean of the jacket's and the face's centroids (hair, legs and the notebook left out)"""
    f = crop.astype(np.float32)
    r, g, b, a = f[..., 0], f[..., 1], f[..., 2], f[..., 3]
    H = crop.shape[0]
    jacket = (a > 128) & (g > r + 8) & (g > b + 15) & (g < 150) & (r < 130)
    jacket[: int(H * 0.15)] = False
    jacket[int(H * 0.62):] = False
    face = (a > 128) & (r > 220) & (g > 170) & (g < 225) & (b > 150) & (r - b > 25)
    face[int(H * 0.25):] = False
    xs = [np.nonzero(m)[1].mean() for m in (jacket, face) if m.sum() > 50]
    return float(np.mean(xs))


def baseline(crop):
    """one past the lowest solid row (thin stray pixels ignored)"""
    rows = np.nonzero((crop[..., 3] > 128).sum(1) >= 3)[0]
    return int(rows[-1]) + 1


def main(src, dst):
    im = np.asarray(Image.open(src).convert('RGBA'))
    F = frames(im)
    sel = [F[i] for i in LOOP]
    heights = [baseline(c) - np.nonzero((c[..., 3] > 20).any(1))[0][0] for c, _, _ in sel]
    k = TARGET_H / max(heights)
    # cell width: the widest reach left / right of the body centre, scaled
    reach = 0.0
    for c, _, _ in sel:
        bx = body_x(c)
        cols = np.nonzero((c[..., 3] > 8).any(0))[0]
        reach = max(reach, bx - cols[0], cols[-1] + 1 - bx)
    half = int(np.ceil(reach * k)) + PAD
    cw = half * 2
    sheet = Image.new('RGBA', (cw * len(sel), CELL_H), (0, 0, 0, 0))
    for n, (c, _, _) in enumerate(sel):
        bx, by = body_x(c), baseline(c)
        pad = int(np.ceil(half / k)) + 4
        H0 = int(np.ceil(FEET / k)) + 8
        # the frame on its own transparent canvas, big enough for the cell's source box
        can = np.zeros((H0 + pad * 2 + c.shape[0], c.shape[1] + pad * 2, 4), np.uint8)
        oy = H0 + pad
        can[oy:oy + c.shape[0], pad:pad + c.shape[1]] = c
        img = Image.fromarray(can).convert('RGBa')     # premultiplied: no dark fringe from the transparent pixels
        sx, sy = pad + bx, oy + by                       # the body centre / the feet line in canvas px
        box = (sx - half / k, sy - FEET / k, sx + half / k, sy + (CELL_H - FEET) / k)
        fr = img.resize((cw, CELL_H), Image.LANCZOS, box=box).convert('RGBA')
        a = np.asarray(fr)
        assert not a[0, :, 3].any() and not a[:, 0, 3].any() and not a[:, -1, 3].any(), 'frame %d touches the cell edge' % LOOP[n]
        sheet.alpha_composite(fr, (n * cw, 0))
    sheet.save(dst, optimize=True)
    cycle = len(F) - 1                              # source frames in one full cycle (the last frame repeats the first)
    travel = cycle * SRC_STEP * k * EILS_SIDE / 2.0     # world px per cycle
    ms = travel / EIL_SPD / len(sel)
    print('scale %.4f (src -> sheet), %.4f on screen; cell %d x %d, %d frames' % (k, k * EILS_SIDE / 2, cw, CELL_H, len(sel)))
    print('EILM "walkL": [%d, %d, %d]   EILSPD "walkL": %.0f ms  (%.1f world px per cycle)' % (len(sel), cw, CELL_H, ms, travel))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'assets/eilin/walkL.png')
