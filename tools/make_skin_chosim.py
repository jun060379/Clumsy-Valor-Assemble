#!/usr/bin/env python3
"""Build Estelle's 초심 (skin id estelle_base, the default) from the user's deliveries into assets/skins/estelle_base/.

Inputs (one folder):
  idle_4f_magenta.png       4 idle frames (one row)                       → row 0  idle
  walkstart_4f_magenta.png  4 frames, standing → stride                   → row 3  start
  runstop_4f_magenta.png    4 frames, running lean → upright              → row 4  stop
  turn_4f_magenta.png       side, side, front, mirrored side             → row 5  turn (기본's turn has the same shape)
  jump_8f_magenta.png       crouch, take-off, rise, apex, fall, fall, land, land (2 rows of 4) → row 6 jump
  run6_magenta.png          running take-off (2 rows of 3)                → row 7  runjump
  run_18f.png               18-frame run cycle (transparent, 5 a row)     → rows 35-36 run  (skin_data anims)
  walk_43f.png              43-frame walk cycle (transparent, 7 a row)    → rows 37-41 walk (skin_data anims)
  ref_greenbg.png           side-view standing art on green               → st_base.png
Magenta / green are keyed with colour unmixing (skin_slice.key_out).

Normalisation, the same for every row so 초심 is one consistent character:
  scale     one factor per delivery image: its frames' median height matched to 기본 Estelle's median height for the same
            animation row (char_bounds.gd); run_18f and walk_43f came as one pair and share run's factor
  baseline  grounded rows: each frame's lowest solid row on the feet line (340); jump / runjump keep the image's own
            vertical layout (the ground = the lowest feet of the grounded frames), so the body rises in the cell as 기본's does
  anchor    the hips (dark belt / skirt-hem / stocking pixels of the hip band) on the cell centre, not the bounding box

Writes sheet_0.png, sheet_5.png, st_base.png, bounds.gd and prints the run / walk measurements (stride, slide, timing).
usage: python3 tools/make_skin_chosim.py <delivery folder> [contact-sheet folder]
"""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import skin_slice as S

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets/skins/estelle_base')
SRC = sys.argv[1]
CS = sys.argv[2] if len(sys.argv) > 2 else None
CSCALE = 1.3                          # chars.gd SCALE estelle: a sheet pixel is 0.5 × 1.3 world px
RUN_SPEED, WALK_SPEED = 0.36, 0.2     # px/ms: player.gd RUN, townsfolk.gd WALKSP estelle

# 기본's per-row median heights (char_bounds.gd)
sys.path.insert(0, ROOT)
src = open(os.path.join(ROOT, 'scripts/char_bounds.gd')).read()
B = json.loads(src.split('"estelle": ')[1].split('],')[0] + ']')
def base_h(row):
    hs = [B[(row * 9 + c) * 2 + 1] - B[(row * 9 + c) * 2] for c in range(9) if B[(row * 9 + c) * 2] >= 0]
    return float(np.median(hs))

SPEC = [  # name, file, key, cols, n, target row, grounded
    ('idle', 'idle_4f_magenta.png', 'magenta', 4, 4, 0, True),
    ('start', 'walkstart_4f_magenta.png', 'magenta', 4, 4, 3, True),
    ('stop', 'runstop_4f_magenta.png', 'magenta', 4, 4, 4, True),
    ('turn', 'turn_4f_magenta.png', 'magenta', 4, 4, 5, True),
    ('jump', 'jump_8f_magenta.png', 'magenta', 4, 8, 6, False),
    ('runjump', 'run6_magenta.png', 'magenta', 3, 6, 7, False),
    ('run', 'run_18f.png', None, 5, 18, 35, True),
    ('walk', 'walk_43f.png', None, 7, 43, 37, True),
]
GROUND = {'jump': [0, 6, 7], 'runjump': [0]}      # frames standing on the ground (verified by eye)

os.makedirs(OUT, exist_ok=True)
sheets, rows_out, info = {}, {}, {}
strips = {}
for nm, fn, key, cols, n, row, grounded in SPEC:
    path = os.path.join(SRC, fn)
    if key:
        im = S.key_out(path, key)
    else:
        im = np.asarray(Image.open(path).convert('RGBA'))
    fr = S.measure(S._frames(im, cols, n, 24, 30))
    H = im.shape[0]
    sh = H / ((n + cols - 1) // cols)
    for i, f in enumerate(fr):
        f['slot_bottom'] = f['box'][1] + f['bottom'] - (i // cols) * sh     # the feet's height inside the slot
    strips[nm] = (fr, row, grounded, sh)

scale = {}
for nm, (fr, row, grounded, sh) in strips.items():
    if nm == 'walk': continue
    scale[nm] = base_h(2 if nm == 'run' else row) / float(np.median([f['height'] for f in fr]))
scale['walk'] = scale['run']           # one delivery pair: one scale

for nm, (fr, row, grounded, sh) in strips.items():
    k = scale[nm]
    if not grounded:
        g = max(fr[i]['slot_bottom'] for i in GROUND[nm])
        for f in fr:                    # lift a frame by how far its feet are above the strip's ground
            f['lift'] = (g - f['slot_bottom'])
    S.place(fr, k, sheets, row)
    info[nm] = {'row': row, 'n': len(fr), 'scale': round(k, 4), 'median_h': round(float(np.median([f['height'] for f in fr])) * k, 1),
                'base_h': base_h(2 if nm in ('run', 'walk') else row), 'clipped': [i for i, f in enumerate(fr) if f['clipped']]}

# jump / runjump with their lift: redo those rows (place() puts every bottom on the feet line)
for nm in ('jump', 'runjump'):
    fr, row, _, _ = strips[nm]
    k = scale[nm]
    sheet = sheets[row // 7]
    for i, f in enumerate(fr):
        cx, cy = (i % 9) * 448, (row % 7) * 352
        sheet.paste(Image.new('RGBA', (448, 352), (0, 0, 0, 0)), (cx, cy))
        cell = Image.new('RGBA', (448, 352), (0, 0, 0, 0))
        im = Image.fromarray(f['rgba'])
        sw, shh = round(im.width * k), round(im.height * k)
        im = im.resize((sw, shh), Image.LANCZOS)
        ox = round(S.CX - f['hip'] * k)
        oy = round(S.FEET - f['bottom'] * k - f['lift'] * k)
        cell.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
        sheet.alpha_composite(cell, (cx, cy))
        f['cell'] = cell
        f['clipped'] = ox < 0 or oy < 0 or ox + sw > 448 or oy + shh > 352
    info[nm]['clipped'] = [i for i, f in enumerate(fr) if f['clipped']]

for si, im in sheets.items():
    im.save(os.path.join(OUT, f'sheet_{si}.png'), optimize=True)


# ---- the run / walk measurements ----
def contact_x(cell):
    """x of the boot touching the ground: the solid pixels of the bottom 3 rows (the sole), the lowest piece if both soles"""
    a = np.asarray(cell)[..., 3]
    rows = np.nonzero((a > 128).sum(axis=1) >= 10)[0]
    b = rows[-1]
    band = (a[b - 2:b + 1] > 128).any(axis=0)
    from scipy import ndimage
    lab, k = ndimage.label(band)
    best, bx = -1, 0.0
    for i in range(1, k + 1):
        xs = np.nonzero(lab == i)[0]
        if len(xs) < 6: continue
        low = int(np.nonzero((a[:, xs] > 128).any(axis=1))[0][-1])
        if low > best or (low == best and len(xs) > 0):
            best, bx = low, float(xs.mean())
    return bx, int(b)


def gait(nm, speed):
    fr = strips[nm][0]
    xs = [contact_x(f['cell'])[0] for f in fr]
    n = len(fr)
    d = np.diff(xs + xs[:1])
    # footfalls: the planted foot changes when the contact jumps forward by a lot
    steps = [int(i + 1) % n for i in np.nonzero(d > 25)[0]]
    # stance drift: least squares slope over each stance (between footfalls), weighted by length
    drifts, lens = [], []
    st = sorted(steps) or [0]
    for j, a0 in enumerate(st):
        a1 = st[(j + 1) % len(st)] + (n if j + 1 == len(st) else 0)
        idx = list(range(a0, a1))
        if len(idx) < 3: continue
        ys = [xs[i % n] for i in idx]
        drifts.append(-np.polyfit(range(len(ys)), ys, 1)[0])
        lens.append(len(ys))
    v = float(np.average(drifts, weights=lens)) if drifts else 0.0
    world = v * 0.5 * CSCALE
    ms = world / speed
    seam = float(np.abs(np.asarray(fr[-1]['cell'], np.float32) - np.asarray(fr[0]['cell'], np.float32)).mean())
    inner = float(np.mean([np.abs(np.asarray(fr[i + 1]['cell'], np.float32) - np.asarray(fr[i]['cell'], np.float32)).mean() for i in range(n - 1)]))
    return {'drift_px_per_frame': round(v, 2), 'world_px_per_frame': round(world, 2), 'no_slide_ms': round(ms, 1),
            'cycle_ms': round(n * ms), 'stride_world_px_per_cycle': round(world * n, 1), 'footfalls': steps,
            'contact_x': [round(x) for x in xs], 'seam_diff': round(seam, 2), 'mean_step_diff': round(inner, 2)}

info['gait_run'] = gait('run', RUN_SPEED)
info['gait_walk'] = gait('walk', WALK_SPEED)
for g, base_ms, n in [('gait_run', 680.0, 8), ('gait_walk', 1200.0, 8)]:
    G = info[g]
    # with 기본's cycle time spread over the new frames, how far the foot would slide per cycle
    per = base_ms / (18 if g == 'gait_run' else 43)
    sp = RUN_SPEED if g == 'gait_run' else WALK_SPEED
    G['slide_px_per_cycle_at_base_cycle'] = round(sp * base_ms - G['stride_world_px_per_cycle'], 1)
    G['base_cycle_ms'] = base_ms

# bounds of the costume's own rows
bnd = {}
for nm, (fr, row, _, _) in strips.items():
    for i, f in enumerate(fr):
        r, c = row + i // 9, i % 9
        a = np.asarray(f['cell'])[..., 3]
        rr = np.nonzero((a > 100).any(axis=1))[0]
        bnd.setdefault(r, [-1] * 18)
        bnd[r][c * 2:c * 2 + 2] = [int(rr[0]), int(rr[-1])]
with open(os.path.join(OUT, 'bounds.gd'), 'w') as fh:
    fh.write("## generated by tools/make_skin_chosim.py: [top, bottom] source rows (alpha > 100) of each cell of this costume's own rows\n")
    fh.write('extends RefCounted\nconst B := {\n')
    for r in sorted(bnd): fh.write(f'\t{r}: {bnd[r]},\n')
    fh.write('}\n')
info['breath_top'] = min(v for v in bnd[0][0::2] if v >= 0)

# the standing art: green keyed, on 기본's 791 × 1199 canvas, feet at the bottom, centred
st = S.key_out(os.path.join(SRC, 'ref_greenbg.png'), 'green')
ys, xs = np.nonzero(st[..., 3] > 20)
fig = Image.fromarray(st).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
W0, H0 = 791, 1199
k = min((H0 * 0.97) / fig.height, (W0 * 0.96) / fig.width)
fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
can = Image.new('RGBA', (W0, H0), (0, 0, 0, 0))
can.alpha_composite(fig, ((W0 - fig.width) // 2, H0 - fig.height - 6))
can.save(os.path.join(OUT, 'st_base.png'), optimize=True)
ca = np.asarray(can).astype(int)
info['st_green_fringe_px'] = int(((ca[..., 3] > 0) & (ca[..., 1] > np.maximum(ca[..., 0], ca[..., 2]) + 24)).sum())
print(json.dumps(info, indent=1))

if CS:
    os.makedirs(CS, exist_ok=True)
    sc = 0.5
    cw, ch = int(448 * sc), int(352 * sc)
    base = [Image.open(os.path.join(ROOT, f'assets/chars/estelle/estelle_{i}.png')) for i in range(5)]
    lines = []
    for nm, (fr, row, _, _) in strips.items():
        brow = {'run': 2, 'walk': 2}.get(nm, row)
        lines.append((f'기본 {nm} (row {brow})', [base[brow // 7].crop((c * 448, (brow % 7) * 352, c * 448 + 448, (brow % 7) * 352 + 352)) for c in range(9) if B[(brow * 9 + c) * 2] >= 0]))
        cells = [f['cell'] for f in fr]
        for j in range(0, len(cells), 9):
            lines.append((f'초심 {nm} {j}-{min(len(cells), j + 9) - 1}', cells[j:j + 9]))
    cs = Image.new('RGB', (9 * cw + 150, len(lines) * ch), (58, 58, 72))
    d = ImageDraw.Draw(cs)
    for li, (lab, cells) in enumerate(lines):
        y = li * ch
        d.rectangle([0, y, 148, y + ch - 1], fill=(30, 30, 40) if lab.startswith('초심') else (90, 60, 60))
        d.text((6, y + 6), lab.replace('초심', 'chosim').replace('기본', 'OLD'), fill=(255, 255, 255))
        for ci, cell in enumerate(cells):
            x = 150 + ci * cw
            c2 = cell.resize((cw, ch), Image.LANCZOS)
            cs.paste(c2, (x, y), c2)
            d.line([(x, y + 340 * sc), (x + cw, y + 340 * sc)], fill=(255, 70, 70))
            d.line([(x + 224 * sc, y + 20), (x + 224 * sc, y + ch)], fill=(70, 220, 255))
            d.rectangle([x, y, x + cw - 1, y + ch - 1], outline=(80, 80, 96))
    cs.save(os.path.join(CS, 'chosim_contact.png'))
