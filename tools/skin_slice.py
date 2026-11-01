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


def _gray(rgba):
    """luminance over a flat mid-grey (so the transparent surround reads as one neutral tone)"""
    a = rgba[..., 3:4].astype(np.float32) / 255.0
    g = rgba[..., :3].astype(np.float32) * a + np.float32([70, 70, 80]) * (1 - a)
    return g @ np.float32([0.299, 0.587, 0.114])


def head_match(ref_rgba, box, frame_rgba, region=0.7, half=0.5, scales=(0.40, 1.31), min_frac=0.15):
    """the reference head (box in ref_rgba) found in one frame: (score, scale, tilt, x, y of the box's top-left in the frame).
    A head is never under min_frac of the frame's height (a crouch, a lying body or a somersault is at most ~5-6 heads
    tall): the search starts there, so a tiny template can't lock onto a bow or a strand of hair"""
    scales = (max(scales[0], min_frac * frame_rgba.shape[0] / (box[3] - box[1])), scales[1])
    import cv2
    x0, y0, x1, y1 = box
    tpl = _gray(ref_rgba)[y0:y1, x0:x1]
    g = _gray(frame_rgba)
    im = cv2.resize(g[:int(g.shape[0] * region)], None, fx=half, fy=half, interpolation=cv2.INTER_AREA)

    def score(s, r):
        t = cv2.resize(tpl, None, fx=s * half, fy=s * half, interpolation=cv2.INTER_AREA)
        h, w = t.shape
        if h >= im.shape[0] or w >= im.shape[1]: return (-1.0, (0, 0))
        t = cv2.warpAffine(t, cv2.getRotationMatrix2D((w / 2, h / 2), r, 1.0), (w, h), borderMode=cv2.BORDER_REPLICATE)
        _, v, _, loc = cv2.minMaxLoc(cv2.matchTemplate(im, t, cv2.TM_CCOEFF_NORMED))
        return (float(v), loc)
    best = max(((score(s, r), s, r) for s in np.arange(scales[0], scales[1], 0.03) for r in range(-15, 11, 5)), key=lambda q: q[0][0])
    best = max([best] + [(score(s, r), s, r) for s in np.arange(best[1] - 0.03, best[1] + 0.031, 0.006)
                         for r in (best[2] - 2, best[2], best[2] + 2)], key=lambda q: q[0][0])
    (v, loc), s, r = best
    return round(v, 3), round(float(s), 3), r, loc[0] / half, loc[1] / half


def head_size(ref_rgba, box, frames, every=1, region=0.55, min_score=0.85, half=0.5, scales=(0.40, 1.31)):
    """the head's size in each frame relative to the reference frame (1.0 = the same pixel size): the reference's head
    (box = x0, y0, x1, y1 around crown, bow and chin, no loose hair) is matched over the upper part of each frame at
    scales 0.40-1.30 and tilts -15..+10 deg (normalised cross-correlation, half resolution, then refined).
    A head is a body measure that does not change with the pose (a crouch or a lean shortens the bounding box, never the
    head), so one factor per delivery that brings its head to the reference's size keeps the figure one size everywhere.
    Returns (median of the good matches, [(frame, score, scale, tilt) ...])."""
    import cv2
    x0, y0, x1, y1 = box
    tpl = _gray(ref_rgba)[y0:y1, x0:x1]
    res = []
    for i in range(0, len(frames), every):
        g = _gray(frames[i]['rgba'])
        im = cv2.resize(g[:int(g.shape[0] * region)], None, fx=half, fy=half, interpolation=cv2.INTER_AREA)

        def score(s, r):
            t = cv2.resize(tpl, None, fx=s * half, fy=s * half, interpolation=cv2.INTER_AREA)
            h, w = t.shape
            if h >= im.shape[0] or w >= im.shape[1]: return -1.0
            t = cv2.warpAffine(t, cv2.getRotationMatrix2D((w / 2, h / 2), r, 1.0), (w, h), borderMode=cv2.BORDER_REPLICATE)
            return float(cv2.minMaxLoc(cv2.matchTemplate(im, t, cv2.TM_CCOEFF_NORMED))[1])
        best = max((score(s, r), s, r) for s in np.arange(scales[0], scales[1], 0.03) for r in range(-15, 11, 5))
        best = max([best] + [(score(s, r), s, r) for s in np.arange(best[1] - 0.03, best[1] + 0.031, 0.006)
                             for r in (best[2] - 2, best[2], best[2] + 2)])
        res.append((i, round(best[0], 3), round(float(best[1]), 3), best[2]))
    good = [s for _, v, s, _ in res if v >= min_score] or [s for _, v, s, _ in res]
    return float(np.median(good)), res


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


def key_out(path, kind, smear=False):
    """flat-background key with colour unmixing: alpha from how far a pixel leans toward the key colour along the key's own
    chroma axis (magenta: min(R, B) − G; green: G − max(R, B)), then the background's share is taken back out of the colour
    (c = (c − (1 − a)·K) / a), so anti-aliased hair edges keep their own pink instead of a magenta / green fringe.
    Pink hair is safe: its G sits close to its B (min(R, B) − G stays small), pure magenta's is ~245.
    smear=True (magenta only): the translucent sword-smear fans drawn into attack frames are white laid over the magenta at
    partial alpha, so their pixels sit on the line from the key to white (R and B high, G = how much white). The plain key
    cuts their faint tail (alpha under ~0.2 went to 0) and leaves the rest pink; for those pixels alpha is refit on that line
    (a = (G − K_G) / (1 − K_G)) and the colour unmixed to white (a hint of pink at most), blended in smoothly so solid pinks
    stay solid. Their faint tail is kept up to 14 px from the solid smear."""
    if smear and kind == 'magenta':
        return _key_smear(path)
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


def _key_smear(path):
    base = key_out(path, 'magenta').astype(np.float32) / 255.0
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    bd = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    K = np.median(bd, axis=0)
    m = np.minimum(r, b) - g
    # on the key → white line: R and B stay near the key's, G carries the white
    on = (r >= K[0] - 0.16) & (b >= K[2] - 0.18) & (np.abs(r - b) <= 0.10) & (m > 0.03)
    t = np.clip((m - 0.03) / 0.09, 0.0, 1.0)
    w = np.where(on, t * t * (3 - 2 * t), 0.0)
    ar = np.clip((g - K[1]) / (0.97 - K[1]), 0.0, 1.0)
    ar = np.where(ar < 0.06, 0.0, ar)                   # the background's own noise (G std ~4/255) stays out
    a3 = np.maximum(ar, 0.02)[..., None]
    fr = np.clip((rgb - (1.0 - a3) * K) / a3, 0.0, 1.0)
    fr[..., 0] = np.minimum(fr[..., 0], fr[..., 1] + 0.04)   # despill: white, at most a breath of pink
    fr[..., 2] = np.minimum(fr[..., 2], fr[..., 1] + 0.05)
    # only next to what the plain key kept (the smear's solid part, the sword, the body): no stray specks
    near = ndimage.binary_dilation(base[..., 3] > 40 / 255.0, iterations=14)
    w = np.where(near, w, 0.0)
    a = w * ar + (1 - w) * base[..., 3]
    col = w[..., None] * fr + (1 - w[..., None]) * base[..., :3]
    a8 = (a * 255).astype(np.uint8)
    lab, k = ndimage.label(a8 > 12)
    if k:
        sizes = ndimage.sum(a8 > 12, lab, range(1, k + 1))
        small = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s <= 60])
        a8 = np.where(small, 0, a8).astype(np.uint8)
    return np.dstack([(np.clip(col, 0, 1) * 255).astype(np.uint8), a8])


def split_frames(im, n, cols=None, alpha_min=24, min_piece=30):
    """the n frames of a keyed strip (one row) or grid (cols a row), in reading order, each cropped to its own pixels.
    Deliveries don't space their frames evenly and a sword tip or smear can touch the next frame's hair, so frames are not
    found by grid slot but grown from body cores: the solid pixels' distance transform, thresholded until exactly n large
    cores remain (one torso each), seeds a watershed over −distance, which parts touching frames at the thinnest neck
    between them (the tip of a blade, a strand of hair). Specks under min_piece go."""
    from skimage.segmentation import watershed
    a = im[..., 3]
    mask = a > alpha_min
    lab, k = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, lab, range(1, k + 1))
    mask = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= min_piece])
    dt = ndimage.distance_transform_edt(a > 128)
    for rr in range(8, 80, 2):
        cl, ck = ndimage.label(dt > rr)
        if ck < n: continue
        cs = ndimage.sum(dt > rr, cl, range(1, ck + 1))
        big = [i + 1 for i, s in enumerate(cs) if s >= 0.12 * cs.max()]
        if len(big) == n: break
    else:
        raise SystemExit(f'split_frames: no {n} body cores')
    cen = ndimage.center_of_mass(dt > rr, cl, big)
    H, W = a.shape
    if cols:
        rows = (n + cols - 1) // cols
        key = [int(cy // (H / rows)) * W * 4 + cx for cy, cx in cen]
    else:
        key = [cx for cy, cx in cen]
    markers = np.zeros(a.shape, np.int32)
    for j, i in enumerate([big[i] for i in np.argsort(key)]):
        markers[cl == i] = j + 1
    seg = watershed(-dt, markers, mask=mask)
    out = []
    for j in range(n):
        m = seg == j + 1
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        fr = im[y0:y1, x0:x1].copy()
        fr[..., 3] = np.where(m[y0:y1, x0:x1], fr[..., 3], 0)
        out.append({'rgba': fr, 'box': (int(x0), int(y0), int(x1), int(y1))})
    return out


def frames_from_rgba(im, cols, n, alpha_min=24, min_piece=30, rows=None):
    """frames_from_strip on an array already keyed"""
    tmp = Image.fromarray(im, 'RGBA')
    return _frames(np.asarray(tmp), cols, n, alpha_min, min_piece, rows)
