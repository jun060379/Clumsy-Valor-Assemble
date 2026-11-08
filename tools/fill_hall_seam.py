#!/usr/bin/env python3
# python3 tools/fill_hall_seam.py
# The pixel3d hall's walls end one cell above its plinth, and the cell between was empty: the sky showed through, so the
# hall looked to float over its stones (owner 2026-11-08: "건물 자체가 돌 위로 살짝 떠 있네. 틈 좀 매꿔주고"). Fills that
# seam in every export of the hall (day, sun sides, night, normal map) with the outline's dark above it.
import numpy as np
from PIL import Image
for f in ("hx/g_hall", "lit/g_hall_m", "lit/g_hall_e", "lit/g_hall_n", "nrm/g_hall"):
    p = f"assets/town/{f}.png"
    a = np.array(Image.open(p).convert("RGBA"))
    H = a.shape[0]
    op = a[:, :, 3] > 0
    n = 0
    for y in range(H - 60, H - 2):
        for x in range(a.shape[1]):
            if op[y, x]: continue
            # a gap of up to 2 rows with the wall above and the plinth below
            dn = op[y + 1, x] or (y + 2 < H and op[y + 2, x])
            if op[y - 1, x] and dn:
                a[y, x] = a[y - 1, x]
                op[y, x] = True
                n += 1
    Image.fromarray(a).save(p)
    print(f, n, "px filled")
