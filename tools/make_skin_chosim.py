#!/usr/bin/env python3
"""Build Estelle's 초심 (skin id estelle_base, the default) from the user's two deliveries into assets/skins/estelle_base/.

usage: python3 tools/make_skin_chosim.py <estelle_v1 folder> <estelle_v2 folder> [contact-sheet folder] [--v1-loco] [--v1-st]

estelle_v1 (the first delivery; magenta sheets on a loose grid, run / walk transparent):
  idle_4f_magenta.png       4 idle frames                                        → row 0  idle (the size reference)
  jump_8f_magenta.png       crouch, take-off, rise, apex, fall, fall, land, land → row 6  jump
  run6_magenta.png          running take-off (2 rows of 3)                       → row 7  runjump
  walk_43f.png              43-frame walk cycle (7 a row)                        → rows 36-37 walk, 10 of its frames (KEEP)
  walkstart / runstop / turn_4f_magenta.png, run_18f.png, ref_greenbg.png: the first start, stop, turn, run and standing
                            art, replaced by v2's; --v1-loco / --v1-st build from them again
estelle_v2 (one row per file, facing right, magenta unless noted):
  run_15f.png (transparent, 4 a row) → row 35 run, 8 of 15     start_4f / stop_4f / turn_4f → rows 3 / 4 / 5
  attack1_5f (overhead slash) → 8   attack2_rising_5f → 9   attack3_thrust_5f → 10   kneel_4f → 11   kneel_attack_6f → 12
  attack_high_5f → 13   guard_4f → 14   air_combo_9f → 16   dive_6f → 17 (6 of 6, one held twice, one left out)
  double_jump_6f (somersault) → 18   hurt_2f → 19   death_4f → 20   dash_6f → 21   vow_3f → 22   air_guard_4f → 23
  teeter_4f → 28   ref_greenbg.png (green) → st_base.png
no art of their own, made from the cells above (COMPOSE): parry (15) and air_parry (24) — the user's call, "패링 모션은 공격
  모션으로 충당": attack2's rising cut and air_combo's rising cut; tag_in (26): dash into attack3's thrust; tag_out (27): runjump.

Keying: magenta / green by colour unmixing (skin_slice.key_out); the attack rows with a smear fan keep it translucent and
  white (key_out smear=True). Frames of a v2 strip are found from body cores (skin_slice.split_frames), not grid slots: the
  frames sit unevenly and touch.
Normalisation, the same for every row so 초심 is one character:
  scale     one factor per delivery image from the HEAD (idle frame 0's crown-to-chin, matched at many scales / tilts), so a
            crouch, a lean, a somersault or a body lying on the floor is never blown up to a standing height. Idle keeps its
            factor (its median height on 기본's). v2 strips: the matches within 0.05 of the strip's best score (a turned-away,
            upside-down or lying head matches badly and is left out).
  baseline  'ground' rows: each frame's lowest solid row (24+ solid source pixels wide, so a blade tip or a smear under the
            boots doesn't count) on the feet line (340). 'air' rows keep the image's own vertical layout: frames listed as
            standing are on the line, the others rise by how far their feet are above those (jump, dive's take-off, the
            somersault); with none listed the lowest frame is on the line.
  anchor    'hip': the hips (dark belt / skirt-hem / stocking pixels in the hip band, the band found from the head's match so a
            raised sword doesn't move it) on x 224. 'plant' (lunges): the listed frames keep the back foot where frame 0 has
            it, so the body drives forward off a planted foot and is back on the hips by the last frame. 'body' (somersault):
            the centre of the dark pixels (sleeves, belt, stockings, bow), set by frame 0's hips, so the turn spins about the
            body instead of jumping around a hip band that isn't there upside down.
  frames    PICK: which source frame each game frame shows (the game's frame count and hit frames, chars.gd A_EST / ATK).
Writes sheet_0..5.png, st_base.png, bounds.gd, prints the measurements (scale, head matches, run gait) as JSON.
"""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import skin_slice as S

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets/skins/estelle_base')
args = [a for a in sys.argv[1:] if not a.startswith('--')]
FLAGS = {a for a in sys.argv[1:] if a.startswith('--')}
SRC1, SRC2 = args[0], args[1]
CS = args[2] if len(args) > 2 else None
V1_LOCO = '--v1-loco' in FLAGS
CSCALE = 1.3                          # chars.gd SCALE estelle: a sheet pixel is 0.5 × 1.3 world px
RUN_SPEED, WALK_SPEED = 0.36, 0.2     # px/ms: player.gd RUN, townsfolk.gd WALKSP estelle

# 기본's per-row median heights (char_bounds.gd)
src = open(os.path.join(ROOT, 'scripts/char_bounds.gd')).read()
B = json.loads(src.split('"estelle": ')[1].split('],')[0] + ']')
def base_h(row):
    hs = [B[(row * 9 + c) * 2 + 1] - B[(row * 9 + c) * 2] for c in range(9) if B[(row * 9 + c) * 2] >= 0]
    return float(np.median(hs))

# ---------------- v1: as the first build made them ----------------
SPEC1 = [  # name, file, key, cols, n, target row, grounded
    ('idle', 'idle_4f_magenta.png', 'magenta', 4, 4, 0, True),
    ('jump', 'jump_8f_magenta.png', 'magenta', 4, 8, 6, False),
    ('runjump', 'run6_magenta.png', 'magenta', 3, 6, 7, False),
    ('walk', 'walk_43f.png', None, 7, 43, 36, True),
]
if V1_LOCO:
    SPEC1 += [('start', 'walkstart_4f_magenta.png', 'magenta', 4, 4, 3, True), ('stop', 'runstop_4f_magenta.png', 'magenta', 4, 4, 4, True),
              ('turn', 'turn_4f_magenta.png', 'magenta', 4, 4, 5, True), ('run', 'run_18f.png', None, 5, 18, 35, True)]
# walk: footfalls at 13 and 37, passing near 3 and 26; steps of 24 and 19 frames → 5 a step. (v1 run: 16, 1, 3, 5, 7, 10, 12, 14)
KEEP = {'walk': [2, 5, 9, 13, 18, 22, 26, 31, 37, 41]}
if V1_LOCO: KEEP['run'] = [16, 1, 3, 5, 7, 10, 12, 14]
HEAD_BOX = (150, 10, 275, 135)          # idle frame 0's head in the source pixels: crown, bow and chin
GROUND1 = {'jump': [0, 6, 7], 'runjump': [0]}      # frames standing on the ground (verified by eye)

# ---------------- v2 ----------------
# file, frames in it, row, options:
#   cols   a grid (else one row)          key   'magenta' (default) / None (transparent)     smear  key the smear fans
#   y      'ground' / 'air'               ground  for 'air': the frames standing on the floor
#   x      'hip' / 'plant' / 'body'       plant   for 'plant': the frames that keep frame 0's back foot
#   pick   source frame per game frame (default: all, in order)
SPEC2 = {
    'attack1': dict(file='attack1_5f.png', n=5, row=8, smear=True, x='plant', plant=[1, 2, 3]),
    'attack2': dict(file='attack2_rising_5f.png', n=5, row=9, smear=True, x='plant', plant=[1, 2, 3]),
    'attack3': dict(file='attack3_thrust_5f.png', n=5, row=10, smear=True, x='plant', plant=[1, 2, 3]),
    'kneel': dict(file='kneel_4f.png', n=4, row=11),
    'kneel_attack': dict(file='kneel_attack_6f.png', n=6, row=12, smear=True),
    'attack_high': dict(file='attack_high_5f.png', n=5, row=13, smear=True, x='plant', plant=[1, 2, 3]),
    'guard': dict(file='guard_4f.png', n=4, row=14),
    'air_combo': dict(file='air_combo_9f.png', n=9, row=16, smear=True, y='air'),
    # dive: the game holds frame 2 while falling (chars.gd dive, player.gd: f 3 waits for the ground), 3 is the slam,
    # 4-5 the recovery. Source 1 turns the blade down, 3 plunges feet first (the held fall); source 2 (a slanted forward
    # dive) doesn't fit a straight drop and is left out; the landing kneel shows for the slam and the next frame
    'dive': dict(file='dive_6f.png', n=6, row=17, y='air', ground=[4, 5], pick=[0, 1, 3, 4, 4, 5]),
    'double_jump': dict(file='double_jump_6f.png', n=6, row=18, y='air', x='body'),
    'hurt': dict(file='hurt_2f.png', n=2, row=19),
    'death': dict(file='death_4f.png', n=4, row=20),
    'dash': dict(file='dash_6f.png', n=6, row=21, y='air', ground=[0, 4, 5]),
    'vow': dict(file='vow_3f.png', n=3, row=22),
    'air_guard': dict(file='air_guard_4f.png', n=4, row=23, y='air'),
    'teeter': dict(file='teeter_4f.png', n=4, row=28),
}
if not V1_LOCO:
    SPEC2.update({
        'start': dict(file='start_4f.png', n=4, row=3),
        'stop': dict(file='stop_4f.png', n=4, row=4),
        'turn': dict(file='turn_4f.png', n=4, row=5),
        # 15 frames for two steps, footfalls at 1 and 8: reach, contact, down, passing of each step, two source frames
        # apart (7 → 8 is one); contacts land on game frames 1 and 5 like 기본's run (skins.steps' default)
        'run': dict(file='run_15f.png', n=15, row=35, cols=4, key=None, pick=[14, 1, 3, 5, 7, 8, 10, 12]),
    })
# rows with no art of their own: [anim, game frame] cells of the rows above
COMPOSE = {
    'parry': (15, [('attack2', 1), ('attack2', 1), ('attack2', 2), ('attack2', 3)]),   # held low, the rising cut knocks it up
    'air_parry': (24, [('air_combo', 3), ('air_combo', 3), ('air_combo', 4), ('air_combo', 5)]),
    'tag_in': (26, [('dash', 1), ('dash', 2), ('attack3', 1), ('attack3', 2), ('attack3', 3), ('attack3', 4)]),
    'tag_out': (27, [('runjump', 1), ('runjump', 2), ('runjump', 3), ('runjump', 4)]),
}

os.makedirs(OUT, exist_ok=True)
sheets, info, cells = {}, {}, {}


def put(row, col, cell):
    sheet = sheets.setdefault(row // 7, Image.new('RGBA', (448 * 9, 352 * 7), (0, 0, 0, 0)))
    sheet.paste(Image.new('RGBA', (448, 352), (0, 0, 0, 0)), (col * 448, (row % 7) * 352))
    sheet.alpha_composite(cell, (col * 448, (row % 7) * 352))


def render(f, k, ax, lift=0.0):
    """one frame on a cell: scaled by k, source x `ax` on the centre column, feet (bottom) on the feet line raised by lift"""
    im = Image.fromarray(f['rgba'])
    sw, sh = max(1, round(im.width * k)), max(1, round(im.height * k))
    im = im.resize((sw, sh), Image.LANCZOS)
    ox = round(S.CX - ax * k)
    oy = round(S.FEET - f['bottom'] * k - lift * k)
    cell = Image.new('RGBA', (448, 352), (0, 0, 0, 0))
    cell.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
    return cell, (ox < 0 or oy < 0 or ox + sw > 448 or oy + sh > 352)


# ---- v1 ----
strips = {}
for nm, fn, key, cols, n, row, grounded in SPEC1:
    path = os.path.join(SRC1, fn)
    im = S.key_out(path, key) if key else np.asarray(Image.open(path).convert('RGBA'))
    fr = S.measure(S._frames(im, cols, n, 24, 30))
    sh = im.shape[0] / ((n + cols - 1) // cols)
    for i, f in enumerate(fr):
        f['slot_bottom'] = f['box'][1] + f['bottom'] - (i // cols) * sh
    strips[nm] = (fr, row, grounded, sh)

scale, head = {}, {}
idle_fr = strips['idle'][0]
REF = idle_fr[0]['rgba']
k_idle = base_h(0) / float(np.median([f['height'] for f in idle_fr]))
for nm, (fr, row, grounded, sh) in strips.items():
    rel, per = S.head_size(REF, HEAD_BOX, fr, every=max(1, len(fr) // 6))
    if nm == 'idle': rel = 1.0
    head[nm] = {'head_vs_idle': round(rel, 3), 'frames': per}
    scale[nm] = k_idle / rel

full_cells = {}
if V1_LOCO:
    scratch = {}
    S.place(strips['run'][0], scale['run'], scratch, 35)
    full_cells['run'] = [f['cell'] for f in strips['run'][0]]
for nm, keep in KEEP.items():
    fr, row, grounded, sh = strips[nm]
    strips[nm] = ([fr[i] for i in keep], row, grounded, sh)

for nm, (fr, row, grounded, sh) in strips.items():
    k = scale[nm]
    if not grounded:
        g = max(fr[i]['slot_bottom'] for i in GROUND1[nm])
        for f in fr: f['lift'] = g - f['slot_bottom']
    for i, f in enumerate(fr):
        f['cell'], f['clipped'] = render(f, k, f['hip'], f.get('lift', 0.0))
        put(row + i // 9, i % 9, f['cell'])
    cells[nm] = [f['cell'] for f in fr]
    info[nm] = {'src': 'v1', 'row': row, 'n': len(fr), 'scale': round(k, 4), 'head_vs_idle': head[nm]['head_vs_idle'],
                'median_h': round(float(np.median([f['height'] for f in fr])) * k, 1), 'keep': KEEP.get(nm),
                'clipped': [i for i, f in enumerate(fr) if f['clipped']]}


# ---- v2 ----
def measure2(f):
    """top / bottom / height from solid pixels (alpha > 200: the translucent smear never counts), the bottom as the lowest
    row 24+ solid pixels wide (boots, not a blade's tip); the back foot (leftmost solid x of the bottom 10 rows); the dark
    pixels' centre; the head's match (crown) and the hips in the band below it"""
    a = f['rgba'][..., 3]
    f['top'] = S.solid_top(a)
    f['bottom'] = S.solid_bottom(np.where(a > 200, 255, 0), min_w=24)
    band = (a[max(0, f['bottom'] - 10):f['bottom'] + 1] > 200).any(axis=0)
    xs = np.nonzero(band)[0]
    f['back'] = float(xs.min()) if len(xs) else 0.0
    rgb = f['rgba'][..., :3].astype(np.float32)
    lum = rgb @ np.float32([0.299, 0.587, 0.114])
    ys, xs = np.nonzero((a > 200) & (lum < 70))
    f['dark'] = (float(xs.mean()), float(ys.mean())) if len(xs) else (a.shape[1] / 2, a.shape[0] / 2)
    hm = S.head_match(REF, HEAD_BOX, f['rgba'])
    f['head'] = hm
    crown = hm[4] - HEAD_BOX[1] * hm[1]
    f['crown'] = crown if hm[0] >= 0.6 and abs(hm[2]) <= 10 and crown < f['bottom'] - 40 else f['top']
    f['height'] = f['bottom'] - f['top']
    f['hip'] = S.hip_x(f['rgba'], int(f['crown']), f['bottom'])
    return f


raw2 = {}
for nm, o in SPEC2.items():
    path = os.path.join(SRC2, o['file'])
    key = o.get('key', 'magenta')
    im = S.key_out(path, key, smear=o.get('smear', False)) if key else np.asarray(Image.open(path).convert('RGBA'))
    fr = [measure2(f) for f in S.split_frames(im, o['n'], o.get('cols'))]
    for f in fr:
        f['slot_bottom'] = f['box'][1] + f['bottom']
    # the head's size: the matches within 0.05 of the strip's best (the head turned away, upside down or lying matches badly)
    sc = [f['head'][0] for f in fr]
    good = [f['head'][1] for f in fr if f['head'][0] >= max(sc) - 0.05]
    rel = float(np.median(good))
    k = k_idle / rel
    raw2[nm] = fr
    # anchors
    ax = [f['hip'] for f in fr]
    if o.get('x') == 'plant':
        for i in o['plant']: ax[i] = fr[i]['back'] + (fr[0]['hip'] - fr[0]['back'])
    elif o.get('x') == 'body':
        ax = [f['dark'][0] + (fr[0]['hip'] - fr[0]['dark'][0]) for f in fr]
    lift = [0.0] * len(fr)
    if o.get('y') == 'air':
        gr = o.get('ground')
        g = float(np.median([fr[i]['slot_bottom'] for i in gr])) if gr else max(f['slot_bottom'] for f in fr)
        lift = [0.0 if gr and i in gr else max(0.0, g - f['slot_bottom']) for i, f in enumerate(fr)]
    rendered = [render(f, k, ax[i], lift[i]) for i, f in enumerate(fr)]
    pick = o.get('pick', list(range(len(fr))))
    cells[nm] = [rendered[i][0] for i in pick]
    for j, c in enumerate(cells[nm]): put(o['row'] + j // 9, j % 9, c)
    if nm == 'run': full_cells['run'] = [c for c, _ in rendered]
    info[nm] = {'src': 'v2', 'row': o['row'], 'n': len(pick), 'pick': pick, 'scale': round(k, 4), 'head_vs_idle': round(rel, 3),
                'head': [(f['head'][0], f['head'][1], f['head'][2]) for f in fr],
                'h': [round(f['height'] * k) for f in fr], 'lift_px': [round(l * k) for l in lift],
                'anchor_vs_hip_px': [round((ax[i] - f['hip']) * k) for i, f in enumerate(fr)],
                'clipped': [i for i in range(len(fr)) if rendered[i][1]]}

for nm, (row, L) in COMPOSE.items():
    cells[nm] = [cells[a][j] for a, j in L]
    for j, c in enumerate(cells[nm]): put(row, j, c)
    info[nm] = {'row': row, 'from': L}

for si, im in sheets.items():
    im.save(os.path.join(OUT, f'sheet_{si}.png'), optimize=True)


# ---- the run / walk measurements ----
def contact_x(cell):
    """x of the boot touching the ground: the solid pixels of the bottom 3 rows (the sole), the lowest piece if both soles"""
    from scipy import ndimage
    a = np.asarray(cell)[..., 3]
    rows = np.nonzero((a > 128).sum(axis=1) >= 10)[0]
    b = rows[-1]
    band = (a[b - 2:b + 1] > 128).any(axis=0)
    lab, kk = ndimage.label(band)
    best, bx = -1, 0.0
    for i in range(1, kk + 1):
        xs = np.nonzero(lab == i)[0]
        if len(xs) < 6: continue
        low = int(np.nonzero((a[:, xs] > 128).any(axis=1))[0][-1])
        if low > best:
            best, bx = low, float(xs.mean())
    return bx, int(b)


def gait(full, kept, speed, n_ms):
    xs = [contact_x(c)[0] for c in full]
    n = len(full)
    d = np.diff(xs + xs[:1])
    steps = [int(i + 1) % n for i in np.nonzero(d > 25)[0]]
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
    seam = float(np.abs(np.asarray(kept[-1], np.float32) - np.asarray(kept[0], np.float32)).mean())
    inner = float(np.mean([np.abs(np.asarray(kept[i + 1], np.float32) - np.asarray(kept[i], np.float32)).mean() for i in range(len(kept) - 1)]))
    return {'footfalls': steps, 'contact_x': [round(x) for x in xs], 'stride_world_px_per_cycle': round(world * n, 1),
            'no_slide_cycle_ms': round(world * n / speed), 'slide_px_per_cycle': round(speed * n_ms - world * n, 1),
            'seam_diff': round(seam, 2), 'mean_step_diff': round(inner, 2)}


info['gait_run'] = gait(full_cells['run'], cells['run'], RUN_SPEED, 610.0)

# bounds of the costume's own rows
bnd = {}
rows_of = {nm: info[nm]['row'] for nm in cells}
for nm, cl in cells.items():
    for i, c in enumerate(cl):
        r, col = rows_of[nm] + i // 9, i % 9
        a = np.asarray(c)[..., 3]
        rr = np.nonzero((a > 100).any(axis=1))[0]
        bnd.setdefault(r, [-1] * 18)
        bnd[r][col * 2:col * 2 + 2] = [int(rr[0]), int(rr[-1])] if len(rr) else [-1, -1]
with open(os.path.join(OUT, 'bounds.gd'), 'w') as fh:
    fh.write("## generated by tools/make_skin_chosim.py: [top, bottom] source rows (alpha > 100) of each cell of this costume's own rows\n")
    fh.write('extends RefCounted\nconst B := {\n')
    for r in sorted(bnd): fh.write(f'\t{r}: {bnd[r]},\n')
    fh.write('}\n')
info['rows'] = sorted(bnd)
info['breath_top'] = min(v for v in bnd[0][0::2] if v >= 0)

# the standing art: green keyed, on 기본's 791 × 1199 canvas, feet at the bottom, centred
st = S.key_out(os.path.join(SRC1 if '--v1-st' in FLAGS else SRC2, 'ref_greenbg.png'), 'green')
ys, xs = np.nonzero(st[..., 3] > 20)
fig = Image.fromarray(st).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
W0, H0 = 791, 1199
k = min((H0 * 0.97) / fig.height, (W0 * 0.96) / fig.width)
fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
can = Image.new('RGBA', (W0, H0), (0, 0, 0, 0))
can.alpha_composite(fig, ((W0 - fig.width) // 2, H0 - fig.height - 6))
cv = np.asarray(can).copy()           # resampling brings a faint green back on the soft edge: never greener than R / B
edge = cv[..., 3] < 255
cv[..., 1] = np.where(edge, np.minimum(cv[..., 1], np.maximum(cv[..., 0], cv[..., 2]) + 8), cv[..., 1])
can = Image.fromarray(cv)
can.save(os.path.join(OUT, 'st_base.png'), optimize=True)
ca = np.asarray(can).astype(int)
info['st_green_fringe_px'] = int(((ca[..., 3] > 0) & (ca[..., 1] > np.maximum(ca[..., 0], ca[..., 2]) + 24)).sum())
print(json.dumps(info, indent=1, default=str))

if CS:
    os.makedirs(CS, exist_ok=True)
    sc = 0.5
    cw, ch = int(448 * sc), int(352 * sc)
    base = [Image.open(os.path.join(ROOT, f'assets/chars/estelle/estelle_{i}.png')) for i in range(5)]
    order = sorted(cells, key=lambda nm: rows_of[nm])
    lines = []
    for nm in order:
        row = rows_of[nm]
        brow = {'run': 2, 'walk': 2}.get(nm, row)
        lines.append((f'OLD {nm} (row {brow})', [base[brow // 7].crop((c * 448, (brow % 7) * 352, c * 448 + 448, (brow % 7) * 352 + 352)) for c in range(9) if B[(brow * 9 + c) * 2] >= 0]))
        cl = cells[nm]
        for j in range(0, len(cl), 9):
            lines.append((f'NEW {nm} {j}-{min(len(cl), j + 9) - 1}', cl[j:j + 9]))
    cs = Image.new('RGB', (9 * cw + 150, len(lines) * ch), (58, 58, 72))
    d = ImageDraw.Draw(cs)
    for li, (lab, cl) in enumerate(lines):
        y = li * ch
        d.rectangle([0, y, 148, y + ch - 1], fill=(30, 30, 40) if lab.startswith('NEW') else (90, 60, 60))
        d.text((6, y + 6), lab, fill=(255, 255, 255))
        for ci, cell in enumerate(cl):
            x = 150 + ci * cw
            c2 = cell.resize((cw, ch), Image.LANCZOS)
            cs.paste(c2, (x, y), c2)
            d.line([(x, y + 340 * sc), (x + cw, y + 340 * sc)], fill=(255, 70, 70))
            d.line([(x + 224 * sc, y + 20), (x + 224 * sc, y + ch)], fill=(70, 220, 255))
            d.rectangle([x, y, x + cw - 1, y + ch - 1], outline=(80, 80, 96))
    cs.save(os.path.join(CS, 'chosim_contact.png'))
    # the same in three parts, for reading at full size
    per = 18
    for p in range(0, len(lines), per):
        cs.crop((0, p * ch, cs.width, min(len(lines), p + per) * ch)).save(os.path.join(CS, f'chosim_contact_{p // per}.png'))
