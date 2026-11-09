#!/usr/bin/env python3
# python3 tools/export_p3d_shadow.py RENDERDIR SHPAD name:key[:2] ...
# The pixel3d solids' ground shadows only (assets/town/shadow/<key>{,_m,_e}.png), from renders widened by SHPAD units
# each side (wip/layer3d tools/pixel3d: SHPAD=<n> build.py ..., sweep2.js "B:8,B:12,B:17,M:8,M:12,M:17").
# Before, the render was the sprite's own width, so a low sun's shadow running off along the ground was cut at the
# sprite's edge and only the contact line under the base was left (owner 2026-11-09: "그림자 작업해야지 그래").
# The sprites themselves are not touched (tools/export_pixel3d.py made them).
# A shadow canvas now starts PAD px left of where it did (x - 24 - PAD): PAD = SHPAD for a prop (:2, one unit a px),
# 2 * SHPAD for a building (one unit a cell); written to data/shadow_pad.json for town.gd and the bake.
# With SHPAD 0 it gives what export_pixel3d.py gave (the check that the crop is the same).
import json
import os
import sys
import numpy as np
from PIL import Image

S, SHPAD = sys.argv[1], int(sys.argv[2])
padf = "data/shadow_pad.json"
pads = json.load(open(padf)) if os.path.exists(padf) else {}
for spec in sys.argv[3:]:
    f = spec.split(":")
    n, key, cell = f[0], f[1], int(f[2]) if len(f) > 2 else 1
    pad_l = 6 if cell == 2 else 0                       # the props' canvas padded to the buildings' 24-px margin
    PAD = SHPAD if cell == 2 else 2 * SHPAD
    for h, suf in ((8, "_m"), (12, ""), (17, "_e")):
        m = np.array(Image.open(f"{S}/{n}_code_bM_{h}.png").convert("RGBA"))[:, :, 3] > 0
        b = np.array(Image.open(f"{S}/{n}_code_bB_{h}.png").convert("RGBA"))[:, :, 3] > 0
        # as export_pixel3d.py: the ground in the solid's shadow (cool shade colour, never black), and a contact
        # shade under the base (3 cells, fading)
        out = np.zeros(m.shape + (4,), np.uint8)
        out[m & ~b] = (38, 70, 76, 110)
        for c in range(b.shape[1]):
            rows = np.where(b[:, c])[0]
            if not len(rows): continue
            r = rows[-1]
            for i, al in enumerate((150, 100, 55)):
                if r + 1 + i < b.shape[0] and not b[r + 1 + i, c]:
                    out[r + 1 + i, c] = (38, 70, 76, max(al, int(out[r + 1 + i, c, 3])))
        if pad_l: out = np.concatenate([np.zeros((out.shape[0], pad_l, 4), np.uint8), out], 1)
        Image.fromarray(out).resize((out.shape[1] * 2, out.shape[0] * 2), Image.NEAREST).save(f"assets/town/shadow/{key}{suf}.png")
    pads[key] = PAD
    print(key, "pad", PAD, "size", out.shape[1] * 2, out.shape[0] * 2)
json.dump(pads, open(padf, "w"), indent=0, sort_keys=True)
