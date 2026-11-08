#!/usr/bin/env python3
# python3 tools/bake_fountain_water.py WATERFALL_SHEET.png
# The fountain's water (owner 2026-11-08: "분수랑 물 효과"): pixelfx water/waterfall rendered small and without its rock
#   node tools/render.mjs water/waterfall --sheet --opts '{"height":32,"width":1.6,"ledge":false,
#     "palette":["#05222b","#08333d","#0e4549","#195a5b","#2f7771","#6aa591","#c2e2cc","#ffffff"]}'
# (the river's teal; 60 frames 144x136 at 30 fps, 8 columns, the pool's middle at 72,118), doubled onto the town's
# 2-px grid and laid on the pixel3d fountain (assets/town/hx/q_fountain.png): the stream from the niche's spout
# (sprite 140,76) down the tower's channel into the basin, whose water level is the coping's top (row 143). Only what
# shows above the coping is kept (the pool's near half is behind the basin's front wall), and only over the basin.
# -> assets/fx/town/fountain_water.png, frames 288x272, 8 columns, drawn at the sprite's (-4, -93) (town_fx.gd).
import sys, json
import numpy as np
from PIL import Image
W, H, COLS, N = 144, 136, 8, 60
PX, PY = 72, 118                      # the effect's origin (cells)
SX, SY = 140, 143                     # where it lands on the sprite (px): the stream's foot at the water level
OX, OY = SX - PX * 2, SY - PY * 2     # the frame's top-left on the sprite
BX0, BX1 = 40, 242                    # the basin's water, between the end pedestals (px)
im = Image.open(sys.argv[1]).convert("RGBA")
out = np.zeros((((N + COLS - 1) // COLS) * H * 2, COLS * W * 2, 4), np.uint8)
ys = np.arange(H * 2)[:, None] + OY
xs = np.arange(W * 2)[None, :] + OX
keep = (ys < SY) & (xs >= BX0) & (xs < BX1)
for i in range(N):
    f = np.array(im.crop(((i % COLS) * W, (i // COLS) * H, (i % COLS) * W + W, (i // COLS) * H + H)))
    f = f.repeat(2, 0).repeat(2, 1)
    f[~keep] = 0
    out[(i // COLS) * H * 2:(i // COLS + 1) * H * 2, (i % COLS) * W * 2:(i % COLS + 1) * W * 2] = f
Image.fromarray(out).save("assets/fx/town/fountain_water.png")
json.dump({"at": [OX, OY], "w": W * 2, "h": H * 2, "cols": COLS, "n": N, "fps": 30}, open("assets/fx/town/fountain_water.json", "w"))
print("at", OX, OY)
