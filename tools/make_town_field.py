#!/usr/bin/env python3
# python3 tools/make_town_field.py
# The lawn in front of the walk (owner 2026-11-08: "풀 타일부터 근경까지 풀로 이어지게 할거임"; sketch 5): below the
# walk's front edge the town's earth section gives way to the same lawn running on toward the camera. Built from
# the lawn tile's own plane rows (assets/town/k_lawn_0..3, rows 30..57), stacked in blocks each slid sideways so the
# repeat does not show, the nearer blocks one step down the lawn ramp (row 4 of assets/town/palette.png, never a
# darker mix). Out: assets/town/k_field_0..3.png (2400-px pieces like the tiles; town.gd joins them).
import numpy as np
from PIL import Image

ROWS = (30, 58)           # the plane rows copied (the back of the plane is the far end, these are near and even)
H = 462                   # town.gd's ground solid is 520 deep; the field starts at row 58
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
ramp = [tuple(P[4, i]) for i in range(8)]
lawn = np.concatenate([np.array(Image.open(f"assets/town/k_lawn_{i}.png").convert("RGBA")) for i in range(4)], 1)
plane = lawn[ROWS[0]:ROWS[1]]
W = lawn.shape[1]
bh = plane.shape[0]
out = np.zeros((H, W, 4), np.uint8)
rng = np.random.default_rng(5)


def darker(a, n):
    if n == 0: return a
    b = a.copy()
    for i, c in enumerate(ramp):
        m = (a[..., 0] == c[0]) & (a[..., 1] == c[1]) & (a[..., 2] == c[2])
        b[m, :3] = ramp[max(0, i - n)]
    return b


y = 0
k = 0
while y < H:
    sh = int(rng.integers(0, W // 2)) // 2 * 2
    blk = np.roll(plane, sh, 1)
    blk = darker(blk, 0 if y < 36 else 1 if y < 120 else 2)
    n = min(bh, H - y)
    out[y:y + n] = blk[:n]
    y += n
    k += 1
for i in range(4):
    Image.fromarray(out[:, i * 2400:(i + 1) * 2400]).save(f"assets/town/k_field_{i}.png")
print("field", out.shape)
