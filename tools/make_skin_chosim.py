#!/usr/bin/env python3
"""Build Estelle's 초심 (skin id estelle_base, the default) from the user's two deliveries into assets/skins/estelle_base/.

usage: python3 tools/make_skin_chosim.py <estelle_v1 folder> <estelle_v2 folder> <estelle_v3 folder> [contact-sheet folder]
       [--v1-idle] [--v1-loco] [--v1-st]

estelle_v1 (the first delivery; magenta sheets on a loose grid, run / walk transparent):
  walk_43f.png              43-frame walk cycle (7 a row)                        → rows 36-37 walk, 10 of its frames (KEEP)
  jump_8f_magenta.png, run6_magenta.png: the first jump / runjump, replaced by v3's
  idle_4f_magenta.png, walkstart / runstop / turn_4f_magenta.png, run_18f.png, ref_greenbg.png: the first idle, start,
                            stop, turn, run and standing art, replaced by v2's; --v1-idle / --v1-loco / --v1-st build them again
estelle_v2 (one row per file, facing right, magenta unless noted):
  ref_greenbg.png (green) → row 0 idle: the standing picture, the same in all 4 frames (the game's idle breathing,
                            player.gd draw_frame, stretches the torso for the motion); the size reference; also st_base.png
  start_4f / stop_4f / turn_4f → rows 3 / 4 / 5
  attack1_5f (overhead slash) → 8   attack2_rising_5f → 9   attack3_thrust_5f → 10   kneel_4f → 11   kneel_attack_6f → 12
  attack_high_5f → 13   guard_4f → 14   air_combo_9f → 16   double_jump_6f (somersault) → 18   hurt_2f → 19   death_4f → 20   dash_6f → 21   vow_3f → 22   air_guard_4f → 23
  ref_greenbg.png (green) → st_base.png
  (v2's run_15f, kneel_attack_6f, dive_6f and teeter_4f: replaced by v3's)
estelle_v3 (one row per file, facing right, magenta):
  jump_8f → 6 (8 of 8: the fall held twice, the landing crouch and standing)   runjump_6f → 7   kneel_attack_6f → 12
  dive_6f → 17   teeter_4f → 28   run_8f → 35 (8 a cycle, no sword: the user's choice)
no art of their own, made from the cells above (COMPOSE): parry (15) and air_parry (24) — the user's call, "패링 모션은 공격
  모션으로 충당": attack2's rising cut and air_combo's rising cut; tag_in (26): dash into attack3's thrust; tag_out (27): runjump.

Keying: magenta / green by colour unmixing (skin_slice.key_out); the attack rows with a smear fan keep it translucent and
  white (key_out smear=True). Frames of a v2 strip are found from body cores (skin_slice.split_frames), not grid slots: the
  frames sit unevenly and touch.
Normalisation, the same for every row so 초심 is one character:
  scale     one factor per delivery image from the BODY: every row is one standing height, T_BODY px crown (no ahoge) to
            sole. The deliveries come from different generator runs with different head-to-body ratios, so matching heads
            (as before) left stop / turn / idle visibly different sizes. BODY holds each image's standing height in its own
            pixels, read by eye on a gridded frame (crown, hip = the lower belt's bottom, knee, sole): an upright frame's
            crown-to-sole, else the length along the body (crown→hip + hip→knee + knee→sole of the straighter leg), which
            equals crown-to-sole on the upright frames (idle 834 / 833, stop 597 / 597). Where the legs are foreshortened
            (kneeling, tucked in the air, lying) that reading is loose: 'blend' rows take the mean of its head size and the
            measured rows' median head size (relative to idle's head, skin_slice.head_match), at most HEAD_MAX. A crouch, a
            lean, a somersault or a body lying on the floor is never blown up: the factor is per image, from its upright
            length, not from the frame's box. Rows not in BODY (the --v1-* rebuilds) fall back to the median head size.
  baseline  'ground' rows: each frame's lowest solid row (24+ solid source pixels wide, so a blade tip or a smear under the
            boots doesn't count) on the feet line (340). 'air' rows keep the image's own vertical layout: frames listed as
            standing are on the line, the others rise by how far their feet are above those (jump, dive's take-off, the
            somersault); with none listed the lowest frame is on the line. If a raised blade or smear would cross the cell's
            top, the row's rise is lowered just enough (never below the line).
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
SRC1, SRC2, SRC3 = args[0], args[1], args[2]
CS = args[3] if len(args) > 3 else None
V1_LOCO = '--v1-loco' in FLAGS
V1_IDLE = '--v1-idle' in FLAGS
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
    ('walk', 'walk_43f.png', None, 7, 43, 36, True),
]
if V1_LOCO:
    SPEC1 += [('start', 'walkstart_4f_magenta.png', 'magenta', 4, 4, 3, True), ('stop', 'runstop_4f_magenta.png', 'magenta', 4, 4, 4, True),
              ('turn', 'turn_4f_magenta.png', 'magenta', 4, 4, 5, True), ('run', 'run_18f.png', None, 5, 18, 35, True)]
# walk: footfalls at 13 and 37, passing near 3 and 26; steps of 24 and 19 frames → 5 a step. (v1 run: 16, 1, 3, 5, 7, 10, 12, 14)
KEEP = {'walk': [2, 5, 9, 13, 18, 22, 26, 31, 37, 41]}
if V1_LOCO: KEEP['run'] = [16, 1, 3, 5, 7, 10, 12, 14]
if V1_IDLE: SPEC1.insert(0, ('idle', 'idle_4f_magenta.png', 'magenta', 4, 4, 0, True))
# idle frame 0's head in its source pixels (cropped to the figure): crown, bow, face and chin, no loose hair
HEAD_BOX = (150, 10, 275, 135) if V1_IDLE else (185, 20, 330, 170)
HEAD_SCALES = (0.25, 1.31)              # the v2 idle's head is ~1.25x the v1 idle's in source pixels: room below 0.40
GROUND1 = {}                            # v1 rows off the ground: none left (jump / runjump are v3's)

# ---------------- v2 ----------------
# file, frames in it, row, options:
#   cols   a grid (else one row)          key   'magenta' (default) / None (transparent)     smear  key the smear fans
#   y      'ground' / 'air'               ground  for 'air': the frames standing on the floor
#   x      'hip' / 'plant' / 'body'       plant   for 'plant': the frames that keep frame 0's back foot
#   pick   source frame per game frame (default: all, in order)
RUN_PICK = [7, 0, 1, 2, 3, 4, 5, 6]     # run_8f (sword version): heel contacts are its frames 0 and 4 (by eye) → game frames 1 and 5
SPEC2 = {
    'attack1': dict(file='attack1_5f.png', n=5, row=8, smear=True, x='plant', plant=[1, 2, 3]),
    'attack2': dict(file='attack2_rising_5f.png', n=5, row=9, smear=True, x='plant', plant=[1, 2, 3]),
    'attack3': dict(file='attack3_thrust_5f.png', n=5, row=10, smear=True, x='plant', plant=[1, 2, 3]),
    'kneel': dict(file='kneel_4f.png', n=4, row=11),
    'kneel_attack': dict(file='kneel_attack_6f.png', n=6, row=12, smear=True, src=3),     # the smear on frame 3 = the hit
    'attack_high': dict(file='attack_high_5f.png', n=5, row=13, smear=True, x='plant', plant=[1, 2, 3]),
    'guard': dict(file='guard_4f.png', n=4, row=14),
    'air_combo': dict(file='air_combo_9f.png', n=9, row=16, smear=True, y='air'),
    # dive: the game holds frame 2 while falling (chars.gd dive, player.gd: f 3 waits for the ground), 3 is the slam,
    # 4-5 the recovery: the art matches (blade down, the plunge held, landing kneel with the sword planted, rise, stand)
    'dive': dict(file='dive_6f.png', n=6, row=17, y='air', ground=[3, 4, 5], src=3),
    # jump: the game starts a standing jump on 2, holds 5 while falling (player.gd locomotion), lands on 6-7; the art's
    # 5 is already the landing crouch, so its fall (4) is held for 4-5, then the crouch and the stand (7 = 6, unused)
    'jump': dict(file='jump_8f.png', n=8, row=6, y='air', ground=[0, 5, 6, 7], pick=[0, 1, 2, 3, 4, 4, 5, 6], src=3),
    # runjump: starts on 1, holds 4 in the air (the front foot reaching down), 5 lands into the run
    'runjump': dict(file='runjump_6f.png', n=6, row=7, y='air', ground=[0, 5], src=3),
    'double_jump': dict(file='double_jump_6f.png', n=6, row=18, y='air', x='body'),
    'hurt': dict(file='hurt_2f.png', n=2, row=19),
    'death': dict(file='death_4f.png', n=4, row=20),
    'dash': dict(file='dash_6f.png', n=6, row=21, y='air', ground=[0, 4, 5]),
    'vow': dict(file='vow_3f.png', n=3, row=22),
    'air_guard': dict(file='air_guard_4f.png', n=4, row=23, y='air'),
    'teeter': dict(file='teeter_4f.png', n=4, row=28, src=3),
}
if not V1_LOCO:
    SPEC2.update({
        'start': dict(file='start_4f.png', n=4, row=3),
        'stop': dict(file='stop_4f.png', n=4, row=4),
        'turn': dict(file='turn_4f.png', n=4, row=5),
        # 8 frames for two steps (contact, down, passing, flight each); rotated so the contacts are game frames 1 and 5
        # like 기본's run (skins.steps' default) and the bob's dip (skin_data.gd) lands on them
        'run': dict(file='run_8f.png', n=8, row=35, src=3, pick=RUN_PICK),
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


# idle's 6 % vertical squash (the standing picture looked tall) is dropped: with every row at one body height it made idle
# the one short figure. render() keeps the parameter for a shape tweak.
IDLE_SY = 1.0

# standing height in each image's own pixels and how it was read (frame, crown / hip / knee / sole by eye on a gridded frame)
T_BODY = 178          # px in the cell, crown to sole: stop f3, the largest well-proportioned upright frame (was 177)
HEAD_MAX = 1.12       # a 'blend' row's head at most this × idle's (the largest head among the measured upright rows, teeter)
BODY = {
    'idle': (833, 'measured'),        # upright: crown 20, sole 853 (ahoge above 20)
    'stop': (597, 'measured'),        # f3 upright: 11 → 608
    'start': (555, 'measured'),       # f0, knees a little bent: crown 20, hip 260, knee 382, sole 566
    'turn': (573, 'measured'),        # f1 (stride): crown→hip 239, hip→knee 149, knee→sole 185
    'run': (387, 'measured'),         # sword run f0: 107 + 162 + 118 (front leg)
    'walk': (382, 'measured'),        # v1 walk f2 upright: 156 + 96 + 130
    'vow': (601, 'measured'),         # f0 upright: 19 → 620
    'teeter': (522, 'measured'),      # f3 upright: 26 → 548
    'hurt': (700, 'measured'),        # f1, wide stance: 22 → 708 vertical, legs splayed
    'dive': (458, 'measured'),        # f5 standing: 12 → 470
    'jump': (391, 'measured'),        # f6 standing: 13 → 404
    'dash': (392, 'measured'),        # f5 standing: 11 → 403
    'attack1': (485, 'measured'),     # f0 wide stance: 202 + 137 + 147 (front leg)
    'attack2': (490, 'measured'),     # f0: 211 + 140 + 140
    'attack3': (393, 'measured'),     # f0 lunge stance: 163 + 109 + 121 (back leg)
    'attack_high': (479, 'measured'), # f0: 203 + 136 + 140
    'guard': (646, 'measured'),       # f1 wide stance: 277 + 189 + 180
    'kneel': (565, 'blend'),          # f0 kneeling: torso 195, back thigh ~180, front shin 183
    'kneel_attack': (410, 'blend'),   # f0 kneeling: torso 166, back thigh 108, front shin 127
    'air_combo': (284, 'blend'),      # f0 tucked: torso 114 (legs foreshortened)
    'air_guard': (636, 'blend'),      # f0 tucked: 266 + 173 + 199
    'double_jump': (425, 'blend'),    # f5 legs out, hair flying: torso 173, thigh 86 (foreshortened), shin 180
    'death': (520, 'blend'),          # f0 stooped: 216 + 127 + 180
    'runjump': (359, 'blend'),        # f0 take-off: torso 142, front leg 88 + 150
}
K_IDLE = T_BODY / BODY['idle'][0]


def head_ratio(nm, rel):
    """the head's on-screen size relative to idle's if this image stood T_BODY tall"""
    return rel * (T_BODY / BODY[nm][0]) / K_IDLE


def body_k(nm, rel, med):
    """the image's scale: T_BODY over its standing height; 'blend' rows meet the median head halfway"""
    if nm in BODY and BODY[nm][1] == 'measured':
        return T_BODY / BODY[nm][0]
    h = min(HEAD_MAX, (head_ratio(nm, rel) + med) / 2) if nm in BODY else med
    return h * K_IDLE / rel


def render(f, k, ax, lift=0.0, sy=1.0):
    """one frame on a cell: scaled by k (and by sy more, vertically), source x `ax` on the centre column, feet (bottom) on
    the feet line raised by lift"""
    im = Image.fromarray(f['rgba'])
    sw, sh = max(1, round(im.width * k)), max(1, round(im.height * k * sy))
    im = im.resize((sw, sh), Image.LANCZOS)
    ox = round(S.CX - ax * k)
    oy = round(S.FEET - f['bottom'] * k * sy - lift * k * sy)
    cell = Image.new('RGBA', (448, 352), (0, 0, 0, 0))
    cell.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
    over = (max(0, -ox), max(0, -oy), max(0, ox + sw - 448), max(0, oy + sh - 352))     # px outside: left, top, right, bottom
    return cell, over if any(over) else False


# ---- v1 ----
strips = {}
if not V1_IDLE:
    st0 = S.key_out(os.path.join(SRC2, 'ref_greenbg.png'), 'green')
    f0 = S.measure(S.frames_from_rgba(st0, 1, 1))[0]
    f0['slot_bottom'] = f0['bottom']
    strips['idle'] = ([dict(f0) for _ in range(4)], 0, True, st0.shape[0])
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
for nm, (fr, row, grounded, sh) in strips.items():
    rel, per = S.head_size(REF, HEAD_BOX, fr, every=max(1, len(fr) // 6), scales=HEAD_SCALES)
    if nm == 'idle': rel = 1.0
    head[nm] = {'head_vs_idle': round(rel, 3), 'frames': per}

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
    hm = S.head_match(REF, HEAD_BOX, f['rgba'], scales=HEAD_SCALES)
    f['head'] = hm
    crown = hm[4] - HEAD_BOX[1] * hm[1]
    f['crown'] = crown if hm[0] >= 0.6 and abs(hm[2]) <= 10 and crown < f['bottom'] - 40 else f['top']
    f['height'] = f['bottom'] - f['top']
    f['hip'] = S.hip_x(f['rgba'], int(f['crown']), f['bottom'])
    return f


raw2, rel2 = {}, {}
for nm, o in SPEC2.items():
    path = os.path.join(SRC3 if o.get('src') == 3 else SRC2, o['file'])
    key = o.get('key', 'magenta')
    im = S.key_out(path, key, smear=o.get('smear', False)) if key else np.asarray(Image.open(path).convert('RGBA'))
    fr = [measure2(f) for f in S.split_frames(im, o['n'], o.get('cols'))]
    for f in fr:
        f['slot_bottom'] = f['box'][1] + f['bottom']
    # the head's size: the strip's best match (an upright head), with the other good matches (score within 0.08 of it)
    # that agree with it within 12 %; a head turned away, tumbling or lying on the floor can score well at a wrong size
    bi = int(np.argmax([f['head'][0] for f in fr]))
    s0, v0 = fr[bi]['head'][1], fr[bi]['head'][0]
    good = [f['head'][1] for f in fr if f['head'][0] >= v0 - 0.08 and abs(f['head'][1] / s0 - 1) <= 0.12]
    rel2[nm] = float(np.median(good))
    raw2[nm] = fr

# the measured rows' median head size (relative to idle's), for the 'blend' rows and the rows not in BODY
rels = {**{nm: head[nm]['head_vs_idle'] for nm in strips}, **rel2}
MED = float(np.median([head_ratio(nm, r) for nm, r in rels.items() if nm in BODY and BODY[nm][1] == 'measured']))
for nm in strips: scale[nm] = body_k(nm, rels[nm], MED)

# ---- v1 rows on the sheets ----
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
        f['cell'], f['clipped'] = render(f, k, f['hip'], f.get('lift', 0.0), IDLE_SY if nm == 'idle' and not V1_IDLE else 1.0)
        put(row + i // 9, i % 9, f['cell'])
    cells[nm] = [f['cell'] for f in fr]
    info[nm] = {'src': 'v2 ref' if nm == 'idle' and not V1_IDLE else 'v1', 'row': row, 'n': len(fr), 'scale': round(k, 4), 'head_vs_idle': head[nm]['head_vs_idle'],
                'median_h': round(float(np.median([f['height'] for f in fr])) * k, 1), 'keep': KEEP.get(nm),
                'clipped': [i for i, f in enumerate(fr) if f['clipped']]}



for nm, o in SPEC2.items():
    fr, rel = raw2[nm], rel2[nm]
    k = body_k(nm, rel, MED)
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
        # a smear or blade reaching more than 12 px under the soles (the cell's room below the feet line): raise the whole row
        under = max((f['rgba'].shape[0] - f['bottom'] - lift[i]) * k - (352 - S.FEET) for i, f in enumerate(fr))
        if under > 0: lift = [l + under / k for l in lift]
        # a raised blade or smear must stay inside the cell: lower the rise just enough (2 px margin)
        over = max(2 - (S.FEET - (f['bottom'] + lift[i]) * k) for i, f in enumerate(fr))
        if over > 0: lift = [max(0.0, l - over / k) for l in lift]
    rendered = [render(f, k, ax[i], lift[i]) for i, f in enumerate(fr)]
    if nm == 'run':
        # the frame with both feet off the ground is drawn crouched with its low foot on the floor, so the whole body
        # dropped there and the run limped: put every head at the same height instead (the airborne frame rises off
        # the floor); the bounce on top comes from BOB_RUN in skin_data.gd
        tops = [int(np.where(np.asarray(c)[:, :, 3].max(1) > 40)[0][0]) for c, _ in rendered]
        t0 = int(np.median(tops))
        sh = []
        for i, (c, cl) in enumerate(rendered):
            d = t0 - tops[i]
            if d:
                c2 = Image.new('RGBA', c.size, (0, 0, 0, 0)); c2.alpha_composite(c, (0, d) if d > 0 else (0, 0), (0, 0) if d > 0 else (0, -d))
                rendered[i] = (c2, cl)
            sh.append(d)
        info['run_head_align_px'] = sh
    pick = o.get('pick', list(range(len(fr))))
    cells[nm] = [rendered[i][0] for i in pick]
    for j, c in enumerate(cells[nm]): put(o['row'] + j // 9, j % 9, c)
    if nm == 'run': full_cells['run'] = [c for c, _ in rendered]
    info[nm] = {'src': 'v%d' % o.get('src', 2), 'row': o['row'], 'n': len(pick), 'pick': pick, 'scale': round(k, 4), 'head_vs_idle': round(rel, 3),
                'head': [(f['head'][0], f['head'][1], f['head'][2]) for f in fr],
                'h': [round(f['height'] * k) for f in fr], 'lift_px': [round(l * k) for l in lift],
                'anchor_vs_hip_px': [round((ax[i] - f['hip']) * k) for i, f in enumerate(fr)],
                'clipped': {i: rendered[i][1] for i in range(len(fr)) if rendered[i][1]}}

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


info['gait_run'] = gait(full_cells['run'], cells['run'], RUN_SPEED, 620.0)

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
# st_base.png is now the user's own character-screen picture (상세): only write the keyed reference with --write-st
if '--write-st' in FLAGS: can.save(os.path.join(OUT, 'st_base.png'), optimize=True)
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
