"""Pack Kenin's trimmed frames into the game's sheets: kenin_<n>.png, 9 x 7 cells of 448 x 352.
Rows are picked by ORIGINAL Sprite Flow frame numbers (1-based) so the firing / release frame lands where the table expects.
usage: python3 -I pack.py OUTDIR
"""
import sys, os, json, runpy
import numpy as np
from PIL import Image

out = sys.argv[1]
SEL = runpy.run_path("trim_sel.py")["SEL"]
CW, CH, COLS, ROWS = 448, 352, 9, 7

# row: (anim, motion, original frame numbers)
LAYOUT = [
    ("idle", "idle", [1, 5, 9, 13, 17, 21, 25, 29]),
    ("run", "run", [6, 7, 9, 10, 11, 12, 14, 15]),
    ("start", "start", [6, 10, 16, 22]),
    ("stop", "stop", [23, 25, 27, 30]),
    ("turn", "turnb", [3, 6, 9, 12]),
    ("jump", "jumpb", [3, 6, 9, 12, 15, 18, 25, 29]),
    ("runjump", "runjump", [7, 10, 13, 16, 19, 22, 28, 31]),
    ("attack1", "shot1", [2, 5, 10, 14, 16, 26]),
    ("attack2", "shot2", [5, 8, 12, 16, 18, 27]),
    ("attack3", "shot3b", [10, 13, 16, 18, 20, 24, 29]),
    ("kneel", "crouch", [13, 16, 18, 20]),
    ("kneel_attack", "crouchshotb", [4, 8, 12, 20, 24, 28, 32]),
    ("attack_high", "upshot", [3, 6, 10, 15, 18, 24]),
    ("air_combo", "airshots", [3, 6, 9, 11, 14, 17, 20, 23, 25]),
    ("dive", "plunge", [2, 6, 10, 17, 19, 22, 26, 29]),
    ("double_jump", "djump", [7, 9, 11, 13, 15, 17, 19, 21, 23]),
    ("hurt", "hurtb", [2, 7, 9, 14]),
    ("death", "death", [8, 16, 22, 30]),
    ("bomb", "skill", [4, 8, 11, 14, 17, 19, 21, 25, 30]),
    ("detonate", "ult", [3, 8, 12, 14, 16, 20, 24, 28, 32]),
    ("headshot", "qte", [3, 7, 11, 15, 18, 21, 23, 26, 28]),
    ("tag_out", "tagout", [1, 8, 14, 17, 20]),
    ("teeter", "teeter", [4, 8, 12, 16, 20, 24]),
    ("dash", "roll", [3, 5, 7, 9, 11, 13, 15, 23, 27]),
]

# Tone: Sprite Flow's frames came out much darker than the other members' art (luminance median 0.16 vs 0.33-0.45,
# 95th percentile 0.42 vs ~0.9). Each pixel's luminance goes through this curve (the trimmed set's percentiles ->
# targets between his own and the others'), colour kept, saturation eased a touch (it was the highest of the four).
TONE_SRC = [0.05, 0.122, 0.161, 0.222, 0.418, 1.0]
TONE_DST = [0.10, 0.235, 0.30, 0.42, 0.74, 1.0]
SAT_K = 0.92

def tone(im):
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255
    rgb = a[..., :3]
    L = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    L2 = np.interp(L, [0] + TONE_SRC, [0] + TONE_DST)
    k = np.where(L > 1e-4, L2 / np.maximum(L, 1e-4), 1.0)
    o = rgb * k[..., None]
    g = (0.2126 * o[..., 0] + 0.7152 * o[..., 1] + 0.0722 * o[..., 2])[..., None]
    o = np.clip(g + (o - g) * SAT_K, 0, 1)
    return Image.fromarray((np.dstack([o, a[..., 3:4]]) * 255).round().astype(np.uint8), "RGBA")

os.makedirs(out, exist_ok=True)
nsheets = (len(LAYOUT) + ROWS - 1) // ROWS
sheets = [Image.new("RGBA", (CW * COLS, CH * ROWS), (0, 0, 0, 0)) for _ in range(nsheets)]
table = {}
for r, (anim, m, frames) in enumerate(LAYOUT):
    assert len(frames) <= COLS, anim
    for c, orig in enumerate(frames):
        idx = SEL[m].index(orig)
        im = tone(Image.open(f"trimmed/{m}/{idx + 1:02d}.png"))
        sheets[r // ROWS].paste(im, (c * CW, (r % ROWS) * CH))
    table[anim] = [r, len(frames)]
for i, s in enumerate(sheets):
    s.save(f"{out}/kenin_{i}.png", optimize=True)
json.dump(table, open(f"{out}/kenin_rows.json", "w"))
print(nsheets, "sheets;", json.dumps(table))
