#!/usr/bin/env python3
"""Real walk cycles from the user's one-row walk sheets (2026-11): 에스텔 (초심, estelle_base), 아이다 (aida_base),
루체 (luce_base) and the blacksmith 브랜 (assets/bran/walk.png).

usage: python3 tools/make_walk.py <estelle|aida|luce|bran> <source sheet> [preview dir]

Sources (transparent, one row, side view facing right). A frame is one big alpha piece (sorted left to right); the
small loose pieces are dropped (아이다's dust dots at her heels) or, for 에스텔 (stray hair tips), kept with the frame
they sit in. The frames are not on an exact grid (루체's sit 272 px apart, 브랜's 178-190), so nothing is cut by slots.
  estelle  5915 x 203, 35 frames, one two-step cycle, all different: all kept
  aida     7776 x 407, 24 frames on twos and threes: 12 different poses (a frame within 3 levels of the one before is a
           hold); source frame 11 has a magenta smear down the shovel (a generator glitch) and is dropped → 11 poses
  luce     7344 x 407, 27 frames (not 24 at 306: the pieces are 272 px apart), one cycle, all different: all kept
  bran     4587 x 208, 25 frames, one cycle: all kept

Per frame:
  * horizontal: a head + torso box (face, chest, waist; long hair, arms, legs, the sword / shovel / tongs left out)
    tracked against frame 0 by a sub-pixel least-squares shift (starting from the upper body's centroid); that body
    point goes on the cell's centre column — the art proved registered within ~1 source px, the tracking keeps it
    exact, so nothing jitters;
  * baseline: the lowest row with 10+ solid source px (the planted sole) on the feet line — 340 for 에스텔 (초심's
    rows), 339 for 아이다 / 루체 (their idle rows), art row 69 for 브랜 (his forge cells) — so every frame stands on the
    line and the body's own rise and fall is kept;
  * scale, one factor a character: 에스텔 1 / 1.08, the size of 초심's idle head found in the walk frames
    (skin_slice.head_match, scores 0.90-0.95: the passing frames then stand 184 px, like her earlier walk's 184.5); the
    others face the viewer in their idle (a head match is unreliable), so by height: the tallest (passing) frame stands
    1.011 x the idle's height — 에스텔's passing-to-idle ratio (아이다 182, 루체 189 cell px; 브랜 62 art px, drawn x2).
Colour:
  * 에스텔: tools/color_match_chosim.py's transform, its targets from 초심's other rows (sheets 0-5 minus the walk);
  * 아이다: the under-skirt green → the apron's brown as tools/recolor_al.py did her sprites (hair and skirt parted by
    shape, the flower marks the head; the pale shovel blade kept out), then hair / brown / blouse / flower each pulled to
    the median of the same part on her in-game rows 0-1;
  * 루체: the navy habit → the grey-violet of her sprites (recolor_al.py's luce transform), then habit / hair / skin /
    white trim pulled to her in-game rows 0-1;
  * 브랜: his pixel-art cells (px.png) use 38 colours and hard alpha: the walk is shrunk to his art pixel grid, each part
    (coat, leather, helmet / scarf, iron) pulled to the same part on px.png, then every pixel snapped to px.png's palette
    (nearest in Lab), alpha cut at 50 %.
Stride: the planted sole's shift between consecutive frames, measured on the cells (the band of rows just above the feet
  line: the best overlap of one frame's soles with the next's, shifted, sub-pixel; boots picked by colour where a blade
  drags low; colours compared tightly for 아이다, whose near and far boots differ only in shade, so one boot is never
  matched to the other — and her search stops at 16 cell px a frame: further on, one boot lines up with the other a
  step ahead). Each frame's time is its shift over the walk speed (floored at MIN_MS; 50 ms for 아이다, whose
  art is on twos and threes: a pose must not flash by), so the foot under the walker stays put frame by frame even where
  the art spaces its frames unevenly. 아이다's art has one pose (her frame 1 → 2) where the planted boot creeps forward
  3 cell px instead of back: there the sole slides ~4 world px however the frame is timed. The cycle time is chosen (cycle) and the speed
  follows: speed = stride / cycle. 브랜's shift is measured on a 4x render of his cells (his art pixels are 2 world px).
Writes the cells (skins: sheet_5.png rows from `row`, 9 a row, plus the bounds.gd rows; 브랜: assets/bran/walk.png, one
row) and prints the frame times / stride / speed (skin_data.gd WALK_*, townsfolk.gd STRIDE, bran.gd WALK).
"""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage import color

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
CW, CH, CX = 448, 352, 224
MIN_MS = 20
CFG = {
    'estelle': dict(k=1 / 1.08, feet=340, row=36, scale=1.3, out='assets/skins/estelle_base', box=(55, 8, 95, 95),
                    cycle=1050.0, loose=True, drop=[], hold=0.0),
    'aida': dict(k=182 * 1.011 / 401, feet=339, row=35, scale=1.25, out='assets/skins/aida_base', box=(120, 10, 215, 200),
                 cycle=1100.0, loose=False, drop=[11], hold=3.0, sim=30.0, min_ms=50, smax=16),
    'luce': dict(k=189 * 1.011 / 402, feet=339, row=35, scale=1.2, out='assets/skins/luce_base', box=(140, 20, 212, 165),
                 cycle=1150.0, loose=False, drop=[], hold=0.0),
    # 브랜: art px (one = 2 world px); his idle stands 62 art px (rows 8-69 of a 70-row cell)
    'bran': dict(k=62 * 1.011 / 205, feet=69, scale=2.0, out='assets/bran', box=(40, 8, 100, 105), cycle=1250.0,
                 loose=False, drop=[], hold=0.0, art=True),
}
who, SRC = sys.argv[1], sys.argv[2]
PREV = sys.argv[3] if len(sys.argv) > 3 else None
C = CFG[who]
OUT = os.path.join(ROOT, C['out'])
lab_of = color.rgb2lab


# ---------------- frames ----------------
def pieces(im):
    """[(the frame: the full-width image with only its pieces, its upper body's centroid x), ...] left to right"""
    m = im[..., 3] > 20
    lab, k = ndimage.label(m, np.ones((3, 3)))
    sz = ndimage.sum(m, lab, range(1, k + 1))
    sl = ndimage.find_objects(lab)
    big = sorted([j + 1 for j in range(k) if sz[j] >= 0.25 * sz.max()], key=lambda j: sl[j - 1][1].start)
    owner = {b: [b] for b in big}
    if C['loose']:
        for j in range(1, k + 1):
            if j in owner: continue
            cx = (sl[j - 1][1].start + sl[j - 1][1].stop) / 2
            b = min(big, key=lambda b: 0 if sl[b - 1][1].start <= cx < sl[b - 1][1].stop else min(abs(cx - sl[b - 1][1].start), abs(cx - sl[b - 1][1].stop)))
            owner[b].append(j)
    out = []
    for b in big:
        f = im.copy()
        f[~np.isin(lab, owner[b])] = 0
        a = f[..., 3] > 128
        rows = np.nonzero(a.any(1))[0]
        up = a[rows[0]:rows[0] + int((rows[-1] - rows[0]) * 0.45)]
        out.append((f, float(np.nonzero(up)[1].mean())))
    return out


def holds(F):
    """the frames that differ from the last kept one (registered on the upper bodies) by >= hold levels"""
    keep = [0]
    if C['hold'] <= 0: return list(range(len(F)))
    for i in range(1, len(F)):
        p, c = F[keep[-1]], F[i]
        dx = int(round(c[1] - p[1]))
        x0 = max(0, int(p[1]) - 200); x1 = int(p[1]) + 200
        A = p[0][:, x0:x1].astype(np.int16)
        B = np.roll(c[0], -dx, 1)[:, x0:x1].astype(np.int16)
        if np.abs(A - B).mean() >= C['hold']: keep.append(i)
    return keep


def baseline(f):
    rows = np.nonzero((f[..., 3] > 128).sum(1) >= 10)[0]
    return int(rows[-1])


def over_grey(f):
    a = f[..., 3:4].astype(np.float32) / 255.0
    return f[..., :3].astype(np.float32) * a + np.float32([70, 70, 80]) * (1 - a)


def track(F):
    """each frame's body x (source px, global): frame 0's head + torso box found in it by a sub-pixel least-squares
    shift, searched around the upper body's centroid"""
    x0, y0, x1, y1 = C['box']
    P = 14
    R = over_grey(F[0][0][:, :x1 + 60])[y0:y1, x0:x1]
    out = []
    for f, uc in F:
        guess = int(round(uc - F[0][1]))
        lo = max(0, x0 + guess - 40); hi = min(f.shape[1], x1 + guess + 40)
        g = np.pad(over_grey(f[:, lo:hi]), ((P, P), (P, P), (0, 0)), mode='edge')
        E = np.full((25, 25), np.inf)
        for dy in range(-12, 13):
            for dx in range(-12, 13):
                xs = x0 + guess + dx - lo + P
                E[dy + 12, dx + 12] = ((g[y0 + P + dy:y1 + P + dy, xs:xs + (x1 - x0)] - R) ** 2).mean()
        iy, ix = np.unravel_index(np.argmin(E), E.shape)
        d = E[iy, ix - 1] - 2 * E[iy, ix] + E[iy, ix + 1] if 0 < ix < 24 else 0
        fx = ix - 12 + (0.5 * (E[iy, ix - 1] - E[iy, ix + 1]) / d if d > 0 else 0)
        out.append((x0 + x1) / 2.0 + guess + float(fx))
    return out


def render(f, k, ax, by, cw, ch, cx, feet, art=False):
    """the frame on a cw x ch cell: scaled by k about (ax, by) → (cx, feet), premultiplied (no dark fringe)"""
    lo = max(0, int(ax - cx / k) - 4); hi = min(f.shape[1], int(ax + (cw - cx) / k) + 4)
    f = f[:, lo:hi]; ax -= lo
    pad = int(max(cw, ch) / k) + 8
    can = np.zeros((f.shape[0] + 2 * pad, f.shape[1] + 2 * pad, 4), np.uint8)
    can[pad:pad + f.shape[0], pad:pad + f.shape[1]] = f
    img = Image.fromarray(can).convert('RGBa')
    sx, sy = ax + pad, by + pad + 1.0        # the sole row's bottom edge
    e = feet + 1                             # … lands on the bottom edge of the feet row
    box = (sx - cx / k, sy - e / k, sx + (cw - cx) / k, sy + (ch - e) / k)
    cell = img.resize((cw, ch), Image.BOX if art else Image.LANCZOS, box=box).convert('RGBA')
    a = np.asarray(cell).copy()
    a[a[..., 3] < 6] = 0                     # resampling dust
    return a


# ---------------- colour ----------------
def hcl(lab):
    return np.hypot(lab[..., 1], lab[..., 2]), np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360


def warm_stats(R):
    m = R[..., 3] > 0.5
    lab = lab_of(R[..., :3])[m]; Cc = np.hypot(lab[:, 1], lab[:, 2]); H = np.degrees(np.arctan2(lab[:, 2], lab[:, 1]))
    w = (Cc > 25) & (H > -30) & (H < 75)
    return np.median(H[w]), np.percentile(Cc[(Cc > 20) & (H > -30) & (H < 75)], 90), np.median(lab[w, 0])


def neutral_stats(R):
    m = R[..., 3] > 0.5
    lab = lab_of(R[..., :3])[m]; Cc = np.hypot(lab[:, 1], lab[:, 2])
    wh = (Cc < 10) & (lab[:, 0] > 65); dk = lab[:, 0] < 25
    return lab[wh, 1:].mean(0), lab[wh, 0].mean(), lab[dk, 1:].mean(0)


def estelle_colour(cells):
    """color_match_chosim.py's transform; targets from 초심's rows but the walk, the source stats from the whole walk"""
    sh = [np.asarray(Image.open(os.path.join(OUT, f'sheet_{i}.png')).convert('RGBA')).astype(np.float32) / 255 for i in range(6)]
    def row(r): return sh[r // 7][(r % 7) * 352:(r % 7 + 1) * 352]
    rows = [r for r in range(42) if r not in range(36, 42) and row(r)[..., 3].max() > 0]
    WS = [warm_stats(row(r)) for r in rows]; NS = [neutral_stats(row(r)) for r in rows]
    tH = float(np.median([w[0] for w in WS])); tC = float(np.median([w[1] for w in WS])); tL = float(np.median([w[2] for w in WS]))
    tWab = np.median([n[0] for n in NS], 0); tWL = float(np.median([n[1] for n in NS])); tDab = np.median([n[2] for n in NS], 0)
    strip = np.concatenate([c.astype(np.float32) / 255 for c in cells], 1)
    h0, c0, l0 = warm_stats(strip); wab, wl, dab = neutral_stats(strip)
    dh = tH - h0; kc = float(np.clip(tC / c0, 0.85, 1.3)); dl = (tL - l0) * 0.6
    out = []
    for c in cells:
        R = c.astype(np.float32) / 255; a = R[..., 3]
        lab = lab_of(R[..., :3]); L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
        Cc = np.hypot(A, B); H = np.degrees(np.arctan2(B, A))
        hw = np.clip((H + 50) / 20, 0, 1) * np.clip((95 - H) / 20, 0, 1)
        w = np.clip((Cc - 12) / 13, 0, 1) * hw
        H2 = H + w * dh; C2 = Cc * (1 + w * (kc - 1)); L2 = L + w * dl
        A2 = C2 * np.cos(np.radians(H2)); B2 = C2 * np.sin(np.radians(H2))
        wn = np.clip((10 - Cc) / 6, 0, 1) * np.clip((L - 55) / 10, 0, 1)
        wd = np.clip((30 - L) / 8, 0, 1) * (1 - w)
        A2 = A2 + wn * (tWab[0] - wab[0]) + wd * (tDab[0] - dab[0]) * 0.7
        B2 = B2 + wn * (tWab[1] - wab[1]) + wd * (tDab[1] - dab[1]) * 0.7
        L2 = L2 + wn * (tWL - wl) * 0.5
        skinh = np.clip((H - 20) / 8, 0, 1) * np.clip((75 - H) / 8, 0, 1)
        wm = np.clip((20 - Cc) / 8, 0, 1) * np.clip((L - 48) / 10, 0, 1) * (1 - skinh) * (1 - wn) * 0.65
        A2 = A2 * (1 - wm) + tWab[0] * wm
        B2 = B2 * (1 - wm) + tWab[1] * wm
        rgb2 = np.clip(color.lab2rgb(np.dstack([L2, A2, B2])), 0, 1)
        R[..., :3] = np.where((a > 0)[..., None], rgb2, R[..., :3])
        out.append((R * 255 + 0.5).astype(np.uint8))
    return out, {'hue_shift': round(float(dh), 1), 'chroma_k': round(kc, 2), 'warm_L_shift': round(float(dl), 1)}


def aida_skirt(cell):
    """recolor_al.py's aida() on one cell: the under-skirt green → the apron's brown; hair (and the pale blade) kept"""
    from skimage.morphology import opening, disk
    from skimage.graph import MCP_Geometric
    cellf = cell.astype(np.float32) / 255
    a = cellf[..., 3]
    lab = lab_of(cellf[..., :3]); L = lab[..., 0]
    Cc, H = hcl(lab)
    vis = a > 0.5
    green = vis & (Cc > 10) & (H >= 95) & (H < 165) & (L < 68)
    core = opening(green, disk(4))
    lab_, n = ndimage.label(core, structure=np.ones((3, 3)))
    if n < 2: return cell, 0
    sizes = ndimage.sum(core, lab_, range(1, n + 1))
    big = [k + 1 for k in range(n) if sizes[k] >= 60]
    if len(big) < 2: return cell, 0
    purple = vis & (H >= 280) & (H < 340) & (Cc > 15)
    pl, pn = ndimage.label(purple, structure=np.ones((3, 3)))
    fls = []
    for k in range(1, pn + 1):
        m = pl == k
        yy, xx = np.nonzero(m)
        if 60 <= m.sum() <= 260 and np.ptp(yy) <= 26 and np.ptp(xx) <= 26: fls.append(m)
    ov = [(ndimage.binary_dilation(fls[0], iterations=3) & (lab_ == k)).sum() for k in big] if len(fls) == 1 else [0]
    if max(ov) > 0: hair_k = big[int(np.argmax(ov))]
    else: hair_k = big[int(np.argmin([ndimage.center_of_mass(lab_ == k)[0] for k in big]))]
    cost = np.where(green, 1.0, np.inf)
    def dist(seed):
        d, _ = MCP_Geometric(cost, fully_connected=True).find_costs(np.argwhere(seed))
        return d
    skirt = green & (dist(core & (lab_ != hair_k)) < dist(lab_ == hair_k))
    w = np.clip(ndimage.gaussian_filter(skirt.astype(np.float32), 0.8) * 1.6, 0, 1) * (Cc > 6) * vis * (L < 72)
    H2 = H + w * (78 - H); C2 = Cc * (1 + w * (34 / np.maximum(Cc, 1) - 1)); L2 = L + w * 6
    rgb = np.clip(color.lab2rgb(np.dstack([L2, C2 * np.cos(np.radians(H2)), C2 * np.sin(np.radians(H2))])), 0, 1)
    out = cellf.copy()
    out[..., :3] = np.where(vis[..., None], rgb, cellf[..., :3])
    return (out * 255 + 0.5).astype(np.uint8), int(skirt.sum())


def luce_habit(cell):
    """recolor_al.py's luce(): the navy habit and veil → her sprites' dark grey-violet"""
    R = cell.astype(np.float32) / 255
    vis = R[..., 3] > 0.5
    lab = lab_of(R[..., :3]); L = lab[..., 0]
    Cc, H = hcl(lab)
    navy = vis & (Cc > 12) & (H >= 215) & (H < 300) & (L < 55)
    w = np.clip(ndimage.gaussian_filter(navy.astype(np.float32), 0.8) * 1.6, 0, 1) * vis * np.clip((60 - L) / 10, 0, 1)
    H2 = H + w * (((315 - H + 180) % 360) - 180); C2 = Cc * (1 + w * (0.6 - 1)); L2 = L + w * 4
    rgb = np.clip(color.lab2rgb(np.dstack([L2, C2 * np.cos(np.radians(H2)), C2 * np.sin(np.radians(H2))])), 0, 1)
    R[..., :3] = np.where(vis[..., None], rgb, R[..., :3])
    return (R * 255 + 0.5).astype(np.uint8)


def parts(lab):
    """each character's parts by colour (Lab masks)"""
    L = lab[..., 0]
    Cc, H = hcl(lab)
    if who == 'aida':
        return {'hair': (Cc > 12) & (H >= 100) & (H < 170) & (L < 68), 'brown': (Cc > 14) & (H >= 50) & (H < 95) & (L < 72),
                'white': (Cc < 9) & (L > 78), 'flower': (Cc > 15) & (H >= 280) & (H < 340)}
    if who == 'luce':
        return {'habit': (L < 45) & ((H >= 250) | (H < 20)), 'hair': (L > 70) & (Cc < 30) & (Cc > 4) & ((H >= 270) | (H < 30)),
                'white': (L > 85) & (Cc <= 4), 'skin': (Cc > 12) & (H >= 20) & (H < 70) & (L > 60)}
    if who == 'bran':
        return {'coat': (Cc > 6) & (H >= 240) & (H < 330) & (L >= 25) & (L < 60), 'leather': (Cc > 12) & ((H < 75) | (H >= 345)) & (L < 55),
                'light': (L >= 60) & (Cc < 18), 'iron': (L < 30) & (Cc < 8)}
    return {}


def ref_rows():
    if who == 'bran':
        return np.asarray(Image.open(os.path.join(ROOT, 'assets/bran/px.png')).convert('RGBA')).astype(np.float32) / 255
    return np.asarray(Image.open(os.path.join(ROOT, f'assets/chars/{who}/{who}_0.png')).convert('RGBA'))[:704].astype(np.float32) / 255


def lch_stats(labs):
    """median L, chroma, hue (circular) of Lab rows"""
    Cc = np.hypot(labs[:, 1], labs[:, 2]); H = np.arctan2(labs[:, 2], labs[:, 1])
    h0 = np.arctan2(np.sin(H).mean(), np.cos(H).mean())
    hm = np.degrees(h0 + np.median((H - h0 + np.pi) % (2 * np.pi) - np.pi))
    return float(np.median(labs[:, 0])), float(np.median(Cc)), float(hm)


def part_match(cells, shift=None):
    """each part's median lightness / chroma / hue on the walk → the same part's on the in-game sprites
    (shift = {part: [dL, chroma factor, dH degrees]})"""
    if shift is None:
        ref = ref_rows()
        rv = ref[..., 3] > 0.9
        rl = lab_of(ref[..., :3])
        rp = {k: rl[m & rv] for k, m in parts(rl).items()}
        strip = np.concatenate(cells, 1).astype(np.float32) / 255
        sl = lab_of(strip[..., :3]); sv = strip[..., 3] > 0.9
        sp = {k: sl[m & sv] for k, m in parts(sl).items()}
        shift = {}
        for k in rp:
            if len(rp[k]) <= 20 or len(sp[k]) <= 20: continue
            r, w = lch_stats(rp[k]), lch_stats(sp[k])
            dh = (r[2] - w[2] + 180) % 360 - 180
            shift[k] = [r[0] - w[0], float(np.clip(r[1] / max(w[1], 1e-3), 0.6, 1.6)), float(np.clip(dh, -12, 12)) if r[1] > 8 and w[1] > 8 else 0.0]
    out = []
    for c in cells:
        R = c.astype(np.float32) / 255
        lab = lab_of(R[..., :3])
        L = lab[..., 0]; Cc, H = hcl(lab)
        dL = np.zeros_like(L); kC = np.zeros_like(L); dH = np.zeros_like(L)
        for k, m in parts(lab).items():
            if k not in shift: continue
            w = np.clip(ndimage.gaussian_filter(m.astype(np.float32), 0.7) * 1.5, 0, 1)
            dL += w * shift[k][0]; kC += w * (shift[k][1] - 1); dH += w * shift[k][2]
        C2 = Cc * (1 + kC); H2 = np.radians(H + dH)
        rgb = np.clip(color.lab2rgb(np.dstack([L + dL, C2 * np.cos(H2), C2 * np.sin(H2)])), 0, 1)
        R[..., :3] = np.where((R[..., 3] > 0)[..., None], rgb, R[..., :3])
        out.append((R * 255 + 0.5).astype(np.uint8))
    return out, shift


def bran_palette(cells):
    """snap to px.png's colours (nearest in Lab), hard alpha"""
    ref = np.asarray(Image.open(os.path.join(ROOT, 'assets/bran/px.png')).convert('RGBA'))
    pal = np.unique(ref[ref[..., 3] > 128][:, :3], axis=0)
    pl = lab_of(pal[None].astype(np.float32) / 255)[0]
    out = []
    for c in cells:
        lab = lab_of(c[..., :3].astype(np.float32) / 255).reshape(-1, 3)
        idx = np.argmin(((lab[:, None, :] - pl[None]) ** 2).sum(-1), 1)
        rgb = pal[idx].reshape(c.shape[0], c.shape[1], 3)
        a = np.where(c[..., 3] >= 128, 255, 0).astype(np.uint8)
        out.append(np.dstack([np.where(a[..., None] > 0, rgb, 0).astype(np.uint8), a]))
    return out


# ---------------- stride ----------------
def sole_mask(c):
    """the shoes, not a blade dragging near the ground (아이다's boots are brown)"""
    if who != 'aida': return 1.0
    lab = lab_of(c[..., :3].astype(np.float32) / 255)
    Cc, H = hcl(lab)
    return ((Cc > 10) & (H > 35) & (H < 100) & (lab[..., 0] < 75)).astype(np.float32)


def sole_shift(c0, c1, feet, band=9):
    """how far the planted sole moves from c0 to c1 (cell px, + = backwards): the shift of c1's sole band that best
    overlaps c0's, colour-weighted, sub-pixel"""
    y0, y1 = feet - band, feet + 2
    a0 = c0[y0:y1, :, 3].astype(np.float32) / 255 * sole_mask(c0[y0:y1]); a1 = c1[y0:y1, :, 3].astype(np.float32) / 255 * sole_mask(c1[y0:y1])
    g0 = c0[y0:y1, :, :3].astype(np.float32); g1 = c1[y0:y1, :, :3].astype(np.float32)
    S = {}
    for s in range(-6, min(C.get('smax', 99), 3 * band + 3) + 1):
        A1 = np.roll(a1, s, 1); G1 = np.roll(g1, s, 1)
        S[s] = float((np.minimum(a0, A1) * np.exp(-np.abs(G1 - g0).sum(-1) / C.get('sim', 90.0))).sum())
    peaks = [t for t in S if t - 1 in S and t + 1 in S and S[t] >= S[t - 1] and S[t] >= S[t + 1]]
    b = max(peaks or S, key=S.get)         # an overlap that peaks inside the search, not one still rising at its edge
    if b - 1 in S and b + 1 in S:
        d = S[b - 1] - 2 * S[b] + S[b + 1]
        if d < 0: return b + 0.5 * (S[b - 1] - S[b + 1]) / d
    return float(b)


def main():
    im = np.asarray(Image.open(SRC).convert('RGBA'))
    F = pieces(im)
    info = {'source': os.path.basename(SRC), 'frames_in_source': len(F)}
    keep = [i for i in holds(F) if i not in C['drop']]
    info['kept'] = keep
    F = [F[i] for i in keep]
    X = track(F)
    k = C['k']
    art = C.get('art', False)
    if art:
        # 브랜: cells in art px; the cell spans the widest reach either side of the body point
        L_ = R_ = 0.0
        for (f, _), x in zip(F, X):
            cols = np.nonzero((f[..., 3] > 60).any(0))[0]
            L_ = max(L_, x - cols[0]); R_ = max(R_, cols[-1] + 1 - x)
        cx = int(np.ceil(L_ * k)) + 2
        cw = cx + int(np.ceil(R_ * k)) + 2
        ch = C['feet'] + 1
        cells = [render(f, k, X[i], baseline(f), cw, ch, cx, C['feet'], True) for i, (f, _) in enumerate(F)]
        hi = [render(f, k * 4, X[i], baseline(f), cw * 4, ch * 4, cx * 4, C['feet'] * 4 + 3) for i, (f, _) in enumerate(F)]
        info['cell'] = [cw, ch]; info['body_x'] = cx
    else:
        cw, ch, cx = CW, CH, CX
        cells = [render(f, k, X[i], baseline(f), cw, ch, cx, C['feet']) for i, (f, _) in enumerate(F)]
    info['track_x'] = [round(x - X[0], 2) for x in X]
    if who == 'estelle':
        cells, info['colour'] = estelle_colour(cells)
    elif who == 'aida':
        sk = []
        for i, c in enumerate(cells):
            cells[i], nn = aida_skirt(c)
            sk.append(nn)
        cells, sh = part_match(cells)
        info['colour'] = {'skirt_px': sk, 'part_shift_dL_kC_dH': {a: [round(float(x), 1) for x in b] for a, b in sh.items()}}
    elif who == 'luce':
        cells = [luce_habit(c) for c in cells]
        cells, sh = part_match(cells)
        info['colour'] = {a: [round(float(x), 1) for x in b] for a, b in sh.items()}
    else:
        cells, sh = part_match(cells)
        hi, _ = part_match(hi, sh)
        info['colour'] = {a: [round(float(x), 1) for x in b] for a, b in sh.items()}
        cells = bran_palette(cells)
    bots = [int(np.nonzero((c[..., 3] > 128).sum(1) >= 3)[0][-1]) for c in cells]
    tops = [int(np.nonzero((c[..., 3] > 100).any(1))[0][0]) for c in cells]
    info['bottoms'] = bots
    info['heights'] = [C['feet'] + 1 - t for t in tops]
    for c in cells:
        assert not c[:, 0, 3].any() and not c[:, -1, 3].any() and not c[0, :, 3].any(), 'a frame touches the cell edge'
    n = len(cells)
    if art:
        sh = [sole_shift(hi[i], hi[(i + 1) % n], C['feet'] * 4 + 3, 24) / 4.0 for i in range(n)]
    else:
        sh = [sole_shift(cells[i], cells[(i + 1) % n], C['feet']) for i in range(n)]
    sh = [max(0.0, s) for s in sh]
    stride = float(sum(sh))
    wk = C['scale'] if art else 0.5 * C['scale']        # world px per cell px
    world = stride * wk
    spd = world / C['cycle']
    ms = [max(C.get('min_ms', MIN_MS), int(round(s * wk / spd))) for s in sh]
    info['shift_cell_px'] = [round(s, 2) for s in sh]
    info['stride_cell_px_cycle'] = round(stride, 1)
    info['stride_world_px_cycle'] = round(world, 1)
    info['ms'] = ms
    info['cycle_ms'] = sum(ms)
    info['speed_px_ms'] = round(world / sum(ms), 4)
    if art:
        path = os.path.join(OUT, 'walk.png')
        strip = Image.new('RGBA', (cw * n, ch), (0, 0, 0, 0))
        for i, c in enumerate(cells): strip.paste(Image.fromarray(c), (i * cw, 0))
        strip.save(path, optimize=True)
    else:
        path = os.path.join(OUT, 'sheet_5.png')
        r0 = C['row'] - 35
        if r0 > 0:
            sheet = Image.open(path).convert('RGBA')
            sheet.paste(Image.new('RGBA', (CW * 9, CH * (7 - r0)), (0, 0, 0, 0)), (0, r0 * CH))
        else:
            sheet = Image.new('RGBA', (CW * 9, CH * 7), (0, 0, 0, 0))     # a sheet holding only the walk
        for i, c in enumerate(cells):
            sheet.paste(Image.fromarray(c), ((i % 9) * CW, (r0 + i // 9) * CH))
        sheet.save(path, optimize=True)
        bp = os.path.join(OUT, 'bounds.gd')
        B = {}
        if os.path.exists(bp):
            for line in open(bp):
                line = line.strip()
                if line[:1].isdigit():
                    r, v = line.split(':', 1)
                    B[int(r)] = json.loads(v.strip().rstrip(','))
        for r in range(C['row'], 42): B.pop(r, None)
        for i, c in enumerate(cells):
            r = C['row'] + i // 9
            B.setdefault(r, [-1] * 18)
            rr = np.nonzero((c[..., 3] > 100).any(axis=1))[0]
            B[r][(i % 9) * 2:(i % 9) * 2 + 2] = [int(rr[0]), int(rr[-1])]
        hdr = open(bp).readline() if os.path.exists(bp) else "## generated by tools/make_walk.py: [top, bottom] source rows (alpha > 100) of each cell of this costume's own rows\n"
        with open(bp, 'w') as fh:
            fh.write(hdr)
            fh.write('extends RefCounted\nconst B := {\n')
            for r in sorted(B): fh.write(f'\t{r}: {B[r]},\n')
            fh.write('}\n')
    info['file'] = os.path.relpath(path, ROOT)
    info['kb'] = round(os.path.getsize(path) / 1024)
    print(json.dumps(info, default=float))
    if PREV:
        os.makedirs(PREV, exist_ok=True)
        s = 4 if art else 0.75
        w, h = int(cw * s), int(ch * s)
        cols = 9
        cs = Image.new('RGB', (cols * w, ((n + cols - 1) // cols) * h), (58, 58, 72))
        d = ImageDraw.Draw(cs)
        for i, c in enumerate(cells):
            x, y = (i % cols) * w, (i // cols) * h
            c2 = Image.fromarray(c).resize((w, h), Image.NEAREST if art else Image.LANCZOS)
            cs.paste(c2, (x, y), c2)
            d.line([(x, y + (C['feet'] + 1) * s), (x + w, y + (C['feet'] + 1) * s)], fill=(255, 70, 70))
            d.line([(x + cx * s, y), (x + cx * s, y + h)], fill=(70, 220, 255))
            d.text((x + 4, y + 4), '%d  %dms' % (i, ms[i]), fill=(255, 255, 255))
        cs.save(os.path.join(PREV, f'{who}_walk_cells.png'))


main()
