"""Aida's 처형 (owner 2026-11-04): Sprite Flow Pro motion "attack-shovel-combo" (32 frames, transparent webm) →
rows 30-33 of assets/chars/aida/aida_4.png (448x352 cells), one fixed anchor for the whole motion (feet of frame 1 on
the idle pose's feet), one scale (her standing height matched to the idle pose). Prints each frame's head height in
cell px (the game carries the foe along with it).
usage: python3 -I pack_aida_exec.py FRAMES_DIR (01.png … 32.png, e.g. ffmpeg -c:v libvpx-vp9 -i x.webm dir/%02d.png)
"""
import sys
from PIL import Image

D = sys.argv[1].rstrip("/") + "/"
SHEET = "assets/chars/aida/aida_4.png"
ROWS = {30: [2, 4, 5, 6], 31: [9, 10, 11, 12, 13, 14], 32: [15, 16, 17, 18, 19, 20, 21, 22, 23], 33: [24, 25, 26, 27, 28, 29, 30, 31]}
CW, CH = 448, 352
SRC_FEET = (480, 768)          # frame 1: feet centre, ground line (alpha > 60)
SRC_H = 768 - 192              # frame 1: standing height
IDLE_H = 343 - 155             # aida_0 row 0: standing height in the cell
CELL_FEET = (203, 340)         # aida_0 row 0: feet centre in the cell
K = IDLE_H / SRC_H

def alpha_clean(im):
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 40 else v)
    return Image.merge("RGBA", (r, g, b, a))

def tone(im):
    # Sprite Flow frames run a little dark next to the hand-drawn sheet: lift the mids
    r, g, b, a = im.split()
    lut = [min(255, int(255 * ((v / 255) ** 0.88))) for v in range(256)]
    return Image.merge("RGBA", (r.point(lut), g.point(lut), b.point(lut), a))

sheet = Image.open(SHEET).convert("RGBA")
tops = {}
for row, sel in ROWS.items():
    r = row - 28
    sheet.paste((0, 0, 0, 0), (0, r * CH, 9 * CW, (r + 1) * CH))
    tops[row] = []
    for col, fn in enumerate(sel):
        im = tone(alpha_clean(Image.open(D + "%02d.png" % fn).convert("RGBA")))
        w, h = int(im.width * K), int(im.height * K)
        sm = im.resize((w, h), Image.LANCZOS)
        ox = CELL_FEET[0] - int(SRC_FEET[0] * K)
        oy = CELL_FEET[1] - int(SRC_FEET[1] * K)
        cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        cell.alpha_composite(sm, (ox, oy)) if ox >= 0 and oy >= 0 else cell.paste(sm, (ox, oy), sm)
        sheet.alpha_composite(cell, (col * CW, r * CH))
        bb = cell.split()[3].point(lambda v: 255 if v > 60 else 0).getbbox()
        tops[row].append(CELL_FEET[1] - (bb[1] if bb else CELL_FEET[1]))
sheet.save(SHEET)
print("scale", round(K, 4))
for row in ROWS: print(row, tops[row])
