#!/usr/bin/env python3
"""Slice a delivered animation strip (frames on a loose grid, transparent background) into frames, normalise them to the
game's sheet format and place them into a skin's sheets.

Each frame is found from alpha (connected pieces, grouped by the grid slot their centre falls in, so a sword tip or hair
lock that crosses a slot edge stays with its frame). Normalisation, per frame:
  * scale: one factor per strip (the strip's median figure height matched to a target height in sheet pixels);
  * baseline: the lowest solid row of the frame (the boots; thin pixels such as a sword tip are ignored) goes on the
    feet line (row 340 of the 448 x 352 cell), so the body's own up-and-down inside the frames is kept;
  * horizontal anchor: the hips (the median x of the dark belt / skirt-hem / stocking pixels in the hip band), not the
    bounding box, goes on the cell's centre (x 224), so swinging hair and sword don't push the body around.

usage (as a module): see tools/make_skin_estelle_v1.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

CELL_W, CELL_H, COLS, ROWS = 448, 352, 9, 7
FEET = 340          # the feet line in a cell (player.gd BASE 170 at half size)
CX = 224            # the cell's centre column


def frames_from_strip(path, cols, n, alpha_min=24, min_piece=30):
    """the n frames (RGBA arrays, cropped to their own bbox, plus the bbox) in reading order"""
    return _frames(np.asarray(Image.open(path).convert('RGBA')), cols, n, alpha_min, min_piece)


def _frames(im, cols, n, alpha_min, min_piece, rows=None):
    H, W = im.shape[:2]
    rows = rows or (n + cols - 1) // cols
    sw, sh = W / cols, H / rows
    mask = im[..., 3] > alpha_min
    lab, k = ndimage.label(mask, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(mask, lab, range(1, k + 1))
    slots = {}
    for i, sl in enumerate(objs):
        if sizes[i] < min_piece:
            continue
        ys, xs = np.nonzero(lab[sl] == i + 1)
        cy, cx = ys.mean() + sl[0].start, xs.mean() + sl[1].start
        slot = int(cy // sh) * cols + int(cx // sw)
        slots.setdefault(slot, []).append(i + 1)
    out = []
    for s in range(n):
        ids = slots.get(s, [])
        if not ids:
            raise SystemExit(f'{path}: no frame found in slot {s}')
        m = np.isin(lab, ids)
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        fr = im[y0:y1, x0:x1].copy()
        fr[..., 3] = np.where(m[y0:y1, x0:x1], fr[..., 3], 0)
        out.append({'rgba': fr, 'box': (int(x0), int(y0), int(x1), int(y1))})
    return out


def solid_bottom(a, min_w=10):
    """lowest row with at least min_w solid pixels (boots, not a sword tip)"""
    cnt = (a > 128).sum(axis=1)
    rows = np.nonzero(cnt >= min_w)[0]
    return int(rows[-1]) if len(rows) else a.shape[0] - 1


def solid_top(a):
    rows = np.nonzero((a > 128).any(axis=1))[0]
    return int(rows[0])


def hip_x(rgba, top, bottom, band=(0.40, 0.56), dark=70):
    """median x of the dark pixels (belt, skirt hem, stockings) in the hip band of the figure"""
    h = bottom - top
    y0, y1 = int(top + h * band[0]), int(top + h * band[1])
    reg = rgba[y0:y1].astype(np.float32)
    lum = reg[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    m = (reg[..., 3] > 160) & (lum < dark)
    ys, xs = np.nonzero(m)
    if len(xs) < 20:          # nothing dark there: the solid pixels' median
        ys, xs = np.nonzero(reg[..., 3] > 160)
    return float(np.median(xs))


def measure(frames):
    for f in frames:
        a = f['rgba'][..., 3]
        f['top'] = solid_top(a)
        f['bottom'] = solid_bottom(a)
        f['height'] = f['bottom'] - f['top']
        f['hip'] = hip_x(f['rgba'], f['top'], f['bottom'])
    return frames


def place(frames, scale, sheet_imgs, row0, flip=False):
    """write frames into the sheets from sheet row row0 on (9 a row, wrapping); sheet_imgs: {sheet index: Image}"""
    for i, f in enumerate(frames):
        row, col = row0 + i // COLS, i % COLS
        im = Image.fromarray(f['rgba'])
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        w, h = im.size
        sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
        im = im.resize((sw, sh), Image.LANCZOS)
        hip = (w - f['hip'] if flip else f['hip']) * scale
        ox = round(CX - hip)
        oy = round(FEET - f['bottom'] * scale)
        cell = Image.new('RGBA', (CELL_W, CELL_H), (0, 0, 0, 0))
        cell.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
        sheet = sheet_imgs.setdefault(row // ROWS, Image.new('RGBA', (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0)))
        sheet.alpha_composite(cell, (col * CELL_W, (row % ROWS) * CELL_H))
        f['cell'] = cell
        f['clipped'] = ox < 0 or oy < 0 or ox + sw > CELL_W or oy + sh > CELL_H
    return frames


def key_out(path, kind):
    """flat-background key with colour unmixing: alpha from how far a pixel leans toward the key colour along the key's own
    chroma axis (magenta: min(R, B) − G; green: G − max(R, B)), then the background's share is taken back out of the colour
    (c = (c − (1 − a)·K) / a), so anti-aliased hair edges keep their own pink instead of a magenta / green fringe.
    Pink hair is safe: its G sits close to its B (min(R, B) − G stays small), pure magenta's is ~245."""
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if kind == 'magenta':
        m = np.minimum(r, b) - g
    else:
        m = g - np.maximum(r, b)
    # the key colour: the median of the border pixels
    bd = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    K = np.median(bd, axis=0)
    mk = float(np.median(np.concatenate([m[0], m[-1], m[:, 0], m[:, -1]])))
    lo, hi = 0.22 * mk, 0.80 * mk          # at or under lo: solid; at or over hi: background
    a = np.clip((hi - m) / (hi - lo), 0.0, 1.0)
    a3 = a[..., None]
    fg = np.where(a3 > 0.02, (rgb - (1.0 - a3) * K) / np.maximum(a3, 0.02), 0.0)
    fg = np.clip(fg, 0.0, 1.0)
    # what is left of the key's cast on the edge: never more magenta / green than the solid neighbours allow
    if kind == 'magenta':
        cap = np.maximum(fg[..., 1] + 0.06, 0.0)
        fg[..., 0] = np.where(a < 1.0, np.minimum(fg[..., 0], np.maximum(cap, fg[..., 0] * a + cap * (1 - a))), fg[..., 0])
        fg[..., 2] = np.where(a < 1.0, np.minimum(fg[..., 2], np.maximum(fg[..., 1] + 0.12, fg[..., 2] * a)), fg[..., 2])
    else:
        fg[..., 1] = np.minimum(fg[..., 1], np.maximum(fg[..., 0], fg[..., 2]))
    a8 = (a * 255).astype(np.uint8)
    lab, k = ndimage.label(a8 > 40)
    if k:
        sizes = ndimage.sum(a8 > 40, lab, range(1, k + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 60])
        a8 = np.where(keep | (a8 <= 40), a8, 0).astype(np.uint8)
        a8 = np.where(ndimage.binary_dilation(keep, iterations=2), a8, 0).astype(np.uint8)
    return np.dstack([(fg * 255).astype(np.uint8), a8])


def frames_from_rgba(im, cols, n, alpha_min=24, min_piece=30, rows=None):
    """frames_from_strip on an array already keyed"""
    tmp = Image.fromarray(im, 'RGBA')
    return _frames(np.asarray(tmp), cols, n, alpha_min, min_piece, rows)
