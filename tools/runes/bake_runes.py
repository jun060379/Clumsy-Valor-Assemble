"""Bake the rune icons: 16 carved stones (a Sprite Flow 4x4 sheet, glyphs glowing white-cyan) x 7 grades.
Each grade recolours the glyph's glow and puts the stone on a frame whose shape climbs with the grade:
common none (grey glyph) / uncommon bronze ring / rare silver square / elite hexagon / epic 8-point star /
legend 12-point gold sun / unique double ring with points. Writes assets/ui/runes/r<NN>_<grade>.png (128 px).
usage: python3 -I tools/runes/bake_runes.py SHEET.png
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw

SHEET = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "runes")
os.makedirs(OUT, exist_ok=True)
GRADES = {"common": "#b9b2a3", "uncommon": "#7fc77a", "rare": "#6aa7ff", "elite": "#b48cff", "epic": "#ff9d4d", "legend": "#ffd34d", "unique": "#ff6fae"}
FRAME = {"uncommon": ("#a5703a", "#e0a868"), "rare": ("#7d8896", "#d6dde6"), "elite": ("#5e4a8a", "#b9a2f0"), "epic": ("#9a4e1e", "#ffb070"),
         "legend": ("#a8781c", "#ffe08a"), "unique": ("#9a2f5c", "#ff9cc8")}
S = 512   # work size (drawn big, scaled down)

def hexc(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255

def stones():
    im = Image.open(SHEET).convert("RGBA"); cs = im.width / 4; out = []
    for i in range(16):
        c = im.crop((int((i % 4) * cs), int((i // 4) * cs), int((i % 4 + 1) * cs), int((i // 4 + 1) * cs)))
        a = c.getchannel("A").point(lambda v: 255 if v > 20 else 0); c = c.crop(a.getbbox())
        out.append(c)
    return out

def recolour(st, grade):
    a = np.asarray(st).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:4]
    v = rgb.max(-1); mn = rgb.min(-1)
    cyan = (rgb[..., 1] + rgb[..., 2]) / 2 - rgb[..., 0]
    m = np.clip((v - 0.5) / 0.2, 0, 1) * np.clip(cyan / 0.08 + (mn > 0.8) * 1.0, 0, 1)
    m = m[..., None]
    gc = hexc(GRADES[grade])
    if grade == "common": gc = np.array([0.80, 0.78, 0.74], np.float32)
    # saturate toward the grade colour: the glyph keeps its shading, a lighter core
    core = np.clip((v[..., None] - 0.93) / 0.07, 0, 1) * 0.5
    tint = gc * (0.35 + 0.85 * v[..., None]); tint = tint * (1 - core) + (gc * 0.5 + 0.5) * core
    o = rgb * (1 - m) + np.clip(tint, 0, 1) * m
    return Image.fromarray((np.dstack([o, al]) * 255).astype(np.uint8), "RGBA")

def star(cx, cy, n, r1, r2, rot=0.0):
    return [(cx + math.cos(rot + k * math.pi / n) * (r1 if k % 2 == 0 else r2), cy + math.sin(rot + k * math.pi / n) * (r1 if k % 2 == 0 else r2)) for k in range(2 * n)]

def poly(cx, cy, n, r, rot=0.0):
    return [(cx + math.cos(rot + k * 2 * math.pi / n) * r, cy + math.sin(rot + k * 2 * math.pi / n) * r) for k in range(n)]

def frame(grade):
    f = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if grade == "common": return f
    d = ImageDraw.Draw(f); dk, lt = FRAME[grade]; c = S / 2; ol = (20, 16, 24, 255)
    def shape(fn, *args, w=10):
        d.polygon(fn(*args), fill=ol); return
    if grade == "uncommon":
        d.ellipse((c - 236, c - 236, c + 236, c + 236), fill=ol); d.ellipse((c - 224, c - 224, c + 224, c + 224), fill=dk)
        d.ellipse((c - 206, c - 206, c + 206, c + 206), fill=lt); d.ellipse((c - 192, c - 192, c + 192, c + 192), fill="#1c1820")
    elif grade == "rare":
        d.rounded_rectangle((c - 226, c - 226, c + 226, c + 226), 40, fill=ol); d.rounded_rectangle((c - 214, c - 214, c + 214, c + 214), 34, fill=dk)
        d.rounded_rectangle((c - 196, c - 196, c + 196, c + 196), 28, fill=lt); d.rounded_rectangle((c - 182, c - 182, c + 182, c + 182), 24, fill="#1c1820")
        for sx in (-1, 1):
            for sy in (-1, 1): d.ellipse((c + sx * 196 - 14, c + sy * 196 - 14, c + sx * 196 + 14, c + sy * 196 + 14), fill=lt, outline=ol, width=4)
    elif grade == "elite":
        d.polygon(poly(c, c, 6, 250, math.pi / 6), fill=ol); d.polygon(poly(c, c, 6, 236, math.pi / 6), fill=dk)
        d.polygon(poly(c, c, 6, 214, math.pi / 6), fill=lt); d.polygon(poly(c, c, 6, 198, math.pi / 6), fill="#1c1820")
    elif grade == "epic":
        d.polygon(star(c, c, 8, 254, 196, -math.pi / 2), fill=ol); d.polygon(star(c, c, 8, 238, 184, -math.pi / 2), fill=lt)
        d.ellipse((c - 196, c - 196, c + 196, c + 196), fill=ol); d.ellipse((c - 186, c - 186, c + 186, c + 186), fill="#1c1820")
    elif grade == "legend":
        d.polygon(star(c, c, 12, 256, 206, -math.pi / 2), fill=ol); d.polygon(star(c, c, 12, 242, 198, -math.pi / 2), fill=lt)
        d.polygon(star(c, c, 4, 256, 150, -math.pi / 2), fill=ol); d.polygon(star(c, c, 4, 240, 150, -math.pi / 2), fill="#fff4c4")
        d.ellipse((c - 200, c - 200, c + 200, c + 200), fill=ol); d.ellipse((c - 190, c - 190, c + 190, c + 190), fill=dk)
        d.ellipse((c - 174, c - 174, c + 174, c + 174), fill=lt); d.ellipse((c - 164, c - 164, c + 164, c + 164), fill="#1c1820")
    elif grade == "unique":
        d.polygon(star(c, c, 4, 258, 150, -math.pi / 4), fill=ol); d.polygon(star(c, c, 4, 242, 146, -math.pi / 4), fill=lt)
        d.polygon(star(c, c, 4, 258, 150, -math.pi / 2), fill=ol); d.polygon(star(c, c, 4, 242, 146, -math.pi / 2), fill=lt)
        d.ellipse((c - 224, c - 224, c + 224, c + 224), fill=ol); d.ellipse((c - 212, c - 212, c + 212, c + 212), fill=dk)
        d.ellipse((c - 196, c - 196, c + 196, c + 196), fill=lt); d.ellipse((c - 186, c - 186, c + 186, c + 186), fill=ol)
        d.ellipse((c - 178, c - 178, c + 178, c + 178), fill="#1c1820")
    return f

frames = {g: frame(g) for g in GRADES}
for i, st in enumerate(stones()):
    for g in GRADES:
        cv = frames[g].copy()
        inner = 352 if g != "common" else 440
        k = inner / max(st.size)
        s2 = recolour(st, g).resize((int(st.width * k), int(st.height * k)), Image.LANCZOS)
        cv.alpha_composite(s2, ((S - s2.width) // 2, (S - s2.height) // 2))
        cv.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, "r%02d_%s.png" % (i, g)), optimize=True)
print("baked", 16 * len(GRADES))
