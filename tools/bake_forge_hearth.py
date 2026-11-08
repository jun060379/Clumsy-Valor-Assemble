#!/usr/bin/env python3
# python3 tools/bake_forge_hearth.py INSIDE_SHEET.png OUT_SHEET.png
# The forge's hearth (owner 2026-11-08: "용광로 fx가 많이 허접해서 다시 짜야할것 같음") from pixelfx fire/town-forge-hearth
# (tools/pixelfx_fx/town-forge-hearth.js, rendered with part "inside" and part "out": 48 frames 64x60 cells, 7 columns,
# the mouth's floor-middle at 32,52), on the town's 2-px grid:
#   assets/fx/town/hearth.png       the fire, cut to the pixel3d forge's dark mouth (assets/town/hx/g_forge.png)
#   assets/fx/town/hearth_out.png   the embers and sparks that leave the mouth (not cut)
#   assets/fx/town/hearth_rim.png   the stones round the mouth lit by the fire: one or two steps up their own palette
#                                   ramp (never another colour), nearest the mouth the most, rising and falling with
#                                   the fire's strength each frame; hard steps, no glow
# Each frame 128x120 px, 8 columns, drawn at the forge sprite's (70, 168) (town_fx.gd HEARTH_AT).
import sys, json
from collections import deque
import numpy as np
from PIL import Image

W, H, COLS, N, FPS = 64, 60, 7, 48, 12
AT = (35, 84)                                  # the frame's top-left in sprite cells (the origin 32,52 -> cell 67,136)
src = np.array(Image.open("assets/town/hx/g_forge.png").convert("RGBA")).astype(int)
cell = src[::2, ::2]                           # the sprite in 2-px cells (the pixel3d forge is on the cell grid)
CH, CW = cell.shape[:2]

# the mouth: the dark opening (sprite px 92..175 x 216..273), flood-filled from its middle within that box
seed = (124, 67)
c0 = tuple(cell[seed][:3])
mouth = np.zeros((CH, CW), bool)
q = deque([seed])
while q:
    y, x = q.popleft()
    if not (108 <= y <= 136 and 46 <= x <= 87) or mouth[y, x] or tuple(cell[y, x, :3]) != c0: continue
    mouth[y, x] = True
    q.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])
print("mouth cells", mouth.sum())

# distance (cells, 8-neighbour) from the mouth, up to 3 (the first cell is mostly the arch's outline)
dist = np.full((CH, CW), 99)
dist[mouth] = 0
for d in range(1, 6):
    prev = dist == d - 1
    grow = np.zeros_like(prev)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            grow |= np.roll(np.roll(prev, dy, 0), dx, 1)
    dist[(dist == 99) & grow] = d

# the palette's ramps: each colour's (row, index); a lit step moves up its own row
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
where = {}
for r in range(P.shape[0]):
    n = sum(1 for i in range(P.shape[1]) if tuple(P[r, i]) != (0, 0, 0))
    for i in range(n): where.setdefault(tuple(P[r, i]), (r, i, n))
STONE_ROWS = {2, 3, 8}                          # ochre, cream, stone: the arch, jambs and sill (not the outlines)


def frames(path):
    im = Image.open(path).convert("RGBA")
    return [np.array(im.crop(((i % COLS) * W, (i // COLS) * H, (i % COLS) * W + W, (i // COLS) * H + H))) for i in range(N)]


inside, out = frames(sys.argv[1]), frames(sys.argv[2])
OC = 8
sheets = {k: np.zeros((H * 2 * ((N + OC - 1) // OC), W * 2 * OC, 4), np.uint8) for k in ("hearth", "hearth_out", "hearth_rim")}
ax, ay = AT
win = (slice(ay, ay + H), slice(ax, ax + W))
mwin = np.zeros((H, W), bool)
ys, xs = np.where(mouth)
mwin[ys - ay, xs - ax] = True
dwin = dist[win]
cwin = cell[win]
# the fire's strength per frame: the share of hot cells in the mouth, normalised over the loop
heat = np.array([((f[:, :, :3].sum(2) > 520) & mwin & (f[:, :, 3] > 0)).sum() for f in inside], float)
heat = (heat - heat.min()) / max(1.0, heat.max() - heat.min())
for i in range(N):
    fin = inside[i].copy()
    fin[~mwin] = 0
    rim = np.zeros((H, W, 4), np.uint8)
    lv = 3 if heat[i] > 0.7 else 2
    for y in range(H):
        for x in range(W):
            d = dwin[y, x]
            if d < 1 or d > 5 or cwin[y, x, 3] == 0: continue
            k = where.get(tuple(cwin[y, x, :3]))
            if not k or k[0] not in STONE_ROWS: continue
            up = lv if d <= 2 else lv - 1 if d <= 3 else lv - 2           # the stones' first two cells off the mouth (past its outline)
            if up <= 0: continue
            r, idx, n = k
            rim[y, x, :3] = P[r, min(n - 1, idx + up)]
            rim[y, x, 3] = 255
    oy, ox = (i // OC) * H * 2, (i % OC) * W * 2
    for k, arr in (("hearth", fin), ("hearth_out", out[i]), ("hearth_rim", rim)):
        big = arr.repeat(2, 0).repeat(2, 1)
        sheets[k][oy:oy + H * 2, ox:ox + W * 2] = big
# the white-hot cores in the ramp's last cream (white is no fire colour of its own: shaders/amb_light.gdshader keeps the
# fire's colours out of the night's dark, and white is left out of that list for the characters' sake)
for k in ("hearth", "hearth_out"):
    a = sheets[k]
    wh = (a[:, :, 0] == 255) & (a[:, :, 1] == 255) & (a[:, :, 2] == 255) & (a[:, :, 3] > 0)
    a[wh, :3] = (255, 243, 166)
for k, a in sheets.items():
    Image.fromarray(a).save(f"assets/fx/town/{k}.png")
json.dump({"at": [AT[0] * 2, AT[1] * 2], "w": W * 2, "h": H * 2, "cols": OC, "n": N, "fps": FPS}, open("assets/fx/town/hearth.json", "w"))
print("heat levels", "".join("2" if h > 0.7 else "1" for h in heat))
