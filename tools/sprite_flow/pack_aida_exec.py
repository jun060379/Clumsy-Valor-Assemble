"""Aida's 처형 (owner 2026-11-04) → rows 30-33 of assets/chars/aida/aida_4.png (448x352 cells).
Beat 1 (in · out) from Sprite Flow Pro motion A ("attack-shovel-combo"), the rest from motion B ("attack-shovel-slam":
the toss and catch, the somersault, the slam). B frames 11, 12, 14 left the frame at the top: their shovel was replaced
by the whole one from frame 13 and they sit on a taller canvas (feet 440 px lower). One fixed anchor (feet on the idle
pose's feet), one scale (matched by head size). Sprite Flow drew her hair near black; it is moved onto the sheet's green.
Prints each frame's head height in cell px (the game carries the foe along with it).
usage: python3 -I pack_aida_exec.py A_DIR B_DIR   (each 01.png … 32.png from ffmpeg -c:v libvpx-vp9 -i x.webm dir/%02d.png)
"""
import sys
from PIL import Image

A = sys.argv[1].rstrip("/") + "/"
B = sys.argv[2].rstrip("/") + "/"
SHEET = "assets/chars/aida/aida_4.png"
# row: [(source, frame), …]; at most 9 per row
ROWS = {30: [("A", 3), ("A", 4), ("A", 5), ("A", 6), ("A", 8), ("A", 9)],
        31: [("B", n) for n in (9, 10, 11, 12, 13, 14, 15, 16)],
        32: [("B", n) for n in (17, 18, 19, 20, 21, 22, 23)],
        33: [("B", n) for n in (24, 25, 26, 27, 28, 29, 31)]}
CW, CH = 448, 352
SRC_FEET = (480, 768)          # frame 1 of both: feet centre, ground line
SRC_H = 768 - 192              # frame 1: standing height
IDLE_H = 343 - 155             # aida_0 row 0: standing height in the cell
CELL_FEET = (203, 340)
K = IDLE_H / SRC_H * 0.86      # the generated body has a bigger head: matched by head size
TALL = {11: 440, 12: 440, 14: 440}   # B frames on the taller canvas: feet this much lower
CLIP_A = 748                   # A's in · out: nothing below the ground (the dirt rim; the portal stands in for it)

HAIR = [(37, 64, 38), (57, 105, 56), (75, 112, 67), (83, 120, 68), (110, 150, 92)]
def hair_green(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 40: continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx < 30 or mx > 125 or mx - mn > 34 or r - b > 18: continue
            t = min(1.0, max(0.0, (mx - 30) / 95.0)) * (len(HAIR) - 1)
            i = min(int(t), len(HAIR) - 2)
            u = t - i
            c = [int(HAIR[i][k] * (1 - u) + HAIR[i + 1][k] * u) for k in range(3)]
            px[x, y] = (c[0], c[1], c[2], a)
    return im

def tone(im):
    r, g, b, a = im.split()
    lut = [min(255, int(255 * ((v / 255) ** 0.88))) for v in range(256)]
    return Image.merge("RGBA", (r.point(lut), g.point(lut), b.point(lut), a))

def alpha_clean(im):
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r, g, b, a.point(lambda v: 0 if v < 40 else v)))

sheet = Image.open(SHEET).convert("RGBA")
tops = {}
for row, sel in ROWS.items():
    r = row - 28
    sheet.paste((0, 0, 0, 0), (0, r * CH, 9 * CW, (r + 1) * CH))
    tops[row] = []
    for col, (src, fn) in enumerate(sel):
        im = alpha_clean(Image.open((A if src == "A" else B) + "%02d.png" % fn).convert("RGBA"))
        dy = TALL.get(fn, 0) if src == "B" else 0
        if src == "A": im.paste((0, 0, 0, 0), (0, CLIP_A, im.width, im.height))
        im = tone(im)
        w, h = int(im.width * K), int(im.height * K)
        sm = hair_green(im.resize((w, h), Image.LANCZOS))
        ox = CELL_FEET[0] - int(SRC_FEET[0] * K)
        oy = CELL_FEET[1] - int((SRC_FEET[1] + dy) * K)
        cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        cell.paste(sm, (ox, oy), sm)
        sheet.alpha_composite(cell, (col * CW, r * CH))
        bb = cell.split()[3].point(lambda v: 255 if v > 60 else 0).getbbox()
        tops[row].append(CELL_FEET[1] - (bb[1] if bb else CELL_FEET[1]))
sheet.save(SHEET)
print("scale", round(K, 4))
for row in ROWS: print(row, tops[row])
