"""Pack Kenin's trimmed frames into the game's sheets: kenin_<n>.png, 9 x 7 cells of 448 x 352.
Rows are picked by ORIGINAL Sprite Flow frame numbers (1-based) so the firing / release frame lands where the table expects.
usage: python3 -I pack.py OUTDIR
"""
import sys, os, json, runpy
from PIL import Image

out = sys.argv[1]
SEL = runpy.run_path("trim_sel.py")["SEL"]
CW, CH, COLS, ROWS = 448, 352, 9, 7

# row: (anim, motion, original frame numbers)
LAYOUT = [
    ("idle", "idle", [1, 5, 9, 13, 17, 21, 25, 29]),
    ("run", "run", [6, 7, 9, 10, 11, 12, 14, 15]),
    ("start", "start", [6, 10, 16, 22]),
    ("stop", "stop", [18, 21, 24, 27, 30]),
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

os.makedirs(out, exist_ok=True)
nsheets = (len(LAYOUT) + ROWS - 1) // ROWS
sheets = [Image.new("RGBA", (CW * COLS, CH * ROWS), (0, 0, 0, 0)) for _ in range(nsheets)]
table = {}
for r, (anim, m, frames) in enumerate(LAYOUT):
    assert len(frames) <= COLS, anim
    for c, orig in enumerate(frames):
        idx = SEL[m].index(orig)
        im = Image.open(f"trimmed/{m}/{idx + 1:02d}.png")
        sheets[r // ROWS].paste(im, (c * CW, (r % ROWS) * CH))
    table[anim] = [r, len(frames)]
for i, s in enumerate(sheets):
    s.save(f"{out}/kenin_{i}.png", optimize=True)
json.dump(table, open(f"{out}/kenin_rows.json", "w"))
print(nsheets, "sheets;", json.dumps(table))
