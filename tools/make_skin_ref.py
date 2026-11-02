#!/usr/bin/env python3
"""Reference images for costume art (docs/skin_ref/): each member's sheets with the 448 x 352 grid, the feet line, the
cell centre and a label per row (row number, sheet / row in sheet, the animations on it with their frame counts), for
use as a pose reference in GPT / NAI. Estelle gets two: the original art (all rows) and 초심's own rows so far.
usage: python3 tools/make_skin_ref.py
"""
import os, re
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'docs/skin_ref')
os.makedirs(OUT, exist_ok=True)
F = os.path.join(ROOT, 'assets/fonts/NotoSansKR-Bold.woff2')
font, small = ImageFont.truetype(F, 22), ImageFont.truetype(F, 17)
SC = 0.4
CW, CH = int(448 * SC), int(352 * SC)
LW = 360
src = open(os.path.join(ROOT, 'scripts/chars.gd'), encoding='utf-8').read()


def table(name):
    body = src.split(f'const {name} := {{')[1].split('\n}')[0]
    out = {}
    for m in re.finditer(r'"(\w+)": \[(-?\d+), \[([^\]]*)\]', body):
        row = int(m.group(2))
        if row >= 0:
            out.setdefault(row, []).append((m.group(1), len([x for x in m.group(3).split(',') if x.strip()])))
    return out


ROWS = {'estelle': table('A_EST'), 'aida': table('A_AIDA'), 'luce': table('A_LUCE')}
COMMON = table('COMMON')
B = {}
bsrc = open(os.path.join(ROOT, 'scripts/char_bounds.gd')).read()
for c in ROWS:
    B[c] = [int(v) for v in bsrc.split(f'"{c}": [')[1].split(']')[0].split(',')]


def sheet_img(sheets, rows, labels, title, path, used):
    H = len(rows) * CH + 60
    W = LW + 9 * CW
    im = Image.new('RGB', (W, H), (232, 232, 236))
    d = ImageDraw.Draw(im)
    d.text((10, 2), title, fill=(20, 20, 30), font=font)
    for j, r in enumerate(rows):
        y = 60 + j * CH
        sh = sheets.get(r // 7)
        if sh is not None:
            strip = sh.crop((0, (r % 7) * 352, 9 * 448, (r % 7) * 352 + 352)).resize((9 * CW, CH), Image.LANCZOS)
            im.paste(strip, (LW, y), strip)
        d.rectangle([0, y, LW - 2, y + CH - 1], fill=(40, 40, 52) if used(r) else (120, 120, 130))
        sheet_no, in_sheet = r // 7, r % 7
        d.text((10, y + 8), f'ROW {r}', fill=(255, 210, 90), font=font)
        d.text((120, y + 12), f'sheet_{sheet_no}.png · 줄 {in_sheet}', fill=(220, 220, 230), font=small)
        lab = labels.get(r, [])
        txt = '\n'.join(f'{a} · {n}프레임' for a, n in lab) if lab else '(비어 있음 · 그리지 않아도 됨)'
        d.multiline_text((10, y + 40), txt, fill=(255, 255, 255), font=small, spacing=3)
        for k in range(10):
            x = LW + k * CW
            d.line([(x, y), (x, y + CH)], fill=(150, 150, 165), width=1)
        d.line([(LW, y), (W, y)], fill=(150, 150, 165), width=1)
        d.line([(LW, y + int(340 * SC)), (W, y + int(340 * SC))], fill=(230, 40, 40), width=1)
        for k in range(9):
            cx = LW + k * CW + CW // 2
            d.line([(cx, y + 4), (cx, y + CH - 4)], fill=(60, 160, 230), width=1)
            d.text((LW + k * CW + 4, y + 2), str(k), fill=(90, 90, 110), font=small)
    d.text((10, 34), '빨간 선 = 발 기준선(칸 위에서 340px) · 파란 선 = 몸(골반) 중심 x=224 · 칸 448×352, 한 장 9칸×7줄 = 4032×2464', fill=(60, 60, 80), font=small)
    im.save(path, optimize=True)
    print(path, im.size)


for c in ['estelle', 'aida', 'luce']:
    sheets = {i: Image.open(os.path.join(ROOT, f'assets/chars/{c}/{c}_{i}.png')).convert('RGBA') for i in range(5)}
    labels = {r: list(v) for r, v in ROWS[c].items()}
    for r, v in COMMON.items(): labels.setdefault(r, []).extend(v)
    used = lambda r, c=c: any(B[c][(r * 9 + k) * 2] >= 0 for k in range(9))
    title = {'estelle': '에스텔 — 원래 그림(미숙한 결의) 전체 시트', 'aida': '아이다 — 기본 시트', 'luce': '루체 — 기본 시트'}[c]
    sheet_img(sheets, list(range(35)), labels, title, os.path.join(OUT, f'{c}_ref.png'), used)

# 초심's own rows so far
cs = {}
for i in range(6):
    p = os.path.join(ROOT, f'assets/skins/estelle_base/sheet_{i}.png')
    if os.path.exists(p): cs[i] = Image.open(p).convert('RGBA')
lab = {0: [('idle', 4)], 3: [('start', 4)], 4: [('stop', 4)], 5: [('turn', 4)], 6: [('jump', 8)], 7: [('runjump', 6)],
       8: [('attack1', 5)], 9: [('attack2', 5)], 10: [('attack3', 5)], 11: [('kneel', 4)], 12: [('kneel_attack', 6)],
       13: [('attack_high', 5)], 14: [('guard', 4)], 15: [('parry (attack2)', 4)], 16: [('air_combo', 9)], 17: [('dive', 6)],
       18: [('double_jump', 6)], 19: [('hurt', 2)], 20: [('death', 4)], 21: [('dash', 6)], 22: [('vow', 3)],
       23: [('air_guard', 4)], 24: [('air_parry (air_combo)', 4)], 26: [('tag_in (dash+attack3)', 6)],
       27: [('tag_out (runjump)', 4)], 28: [('teeter', 4)], 35: [('run', 8)], 36: [('walk 0-8', 9)], 37: [('walk 9', 1)]}
sheet_img(cs, sorted(lab), lab, '에스텔 초심 — 전체 줄 (괄호 = 다른 줄 그림을 다시 씀)', os.path.join(OUT, 'estelle_chosim_ref.png'), lambda r: True)
