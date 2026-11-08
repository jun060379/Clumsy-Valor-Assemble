#!/usr/bin/env python3
# python3 tools/bake_grass_sway.py PIECES_DIR OUT_DIR
# The grass tufts' sway frames (owner 2026-11-08: "아래 풀은 두고 위 영역의 포기는 전환"): each tuft from
# tools/make_town_grass.py (set b; 2-px cells doubled) into one strip of LEANS.size frames side by side, the frame k
# leaning its top k cells (2 px each) to the right, the rows in between following u^2 (u: 0 at the planted bottom 30%,
# 1 at the top), whole cells only: the 2-px grid holds. town.gd picks the frame from the wind at the tuft's x.
import sys, os, json
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
LEANS = [-2, -1, 0, 1, 2, 3, 4]
KINDS = ["g_tuft_1", "g_tuft_2", "g_tuft_tall", "g_strip", "g_clover", "g_daisy", "g_cattail", "g_sprout", "g_tuft_wind"]
info = {"leans": LEANS, "kinds": {}}
for k in KINDS:
    a = np.array(Image.open(os.path.join(SRC, k + ".png")).convert("RGBA"))[::2, ::2]     # back to cells
    h, w = a.shape[:2]
    pad = max(abs(min(LEANS)), max(LEANS))
    fw = w + 2 * pad
    sheet = np.zeros((h, fw * len(LEANS), 4), np.uint8)
    for i, L in enumerate(LEANS):
        for y in range(h):
            u = max(0.0, (0.7 * h - y) / (0.7 * h))      # 1 at the top row, 0 from 30% above the bottom down
            o = int(round(L * u * u))
            sheet[y, i * fw + pad + o:i * fw + pad + o + w] = np.where(a[y, :, 3:4] > 0, a[y], sheet[y, i * fw + pad + o:i * fw + pad + o + w])
    Image.fromarray(sheet.repeat(2, 0).repeat(2, 1)).save(os.path.join(OUT, k + ".png"))
    info["kinds"][k] = {"fw": fw * 2, "h": h * 2, "pad": pad * 2}
json.dump(info, open(os.path.join(OUT, "sway.json"), "w"), indent=1)
print(json.dumps(info))
