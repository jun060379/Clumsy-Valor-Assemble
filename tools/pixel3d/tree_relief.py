#!/usr/bin/env python3
# python3 tools/pixel3d/tree_relief.py KEY [KEY ...]   (run in the game repo's root: reads assets/town/KEY.png, _leaf.png)
# The town's trees as solids taken straight from their pictures (owner 2026-11-08: "코드를 래퍼런스 삼되 아예 그대로 찍으면
# 되는 거 아님?"): every pixel of the tree a column of the relief, its height from where it lies in its own part - each
# lit leaf clump a dome (higher in its middle, so clumps round off and their edges show), the shaded canopy mass behind
# them, the trunk and limbs rounded across their width - and its material from its colour (bark, the dark of the bark's
# grooves, lit leaves, the canopy's shade). Lit by the viewer's sun like the buildings; the picture's own outlines give
# way to the viewer's. -> tools/pixel3d/relief_<key>.js (module RELIEF, one unit a game px, rendered at CELL 2).
import sys, json, os
import numpy as np
from PIL import Image
from scipy import ndimage

# --flat: a standing card instead (owner 2026-11-08: "굳이 입체일 필요는 없어. 판떼기로 만들어도 결국 그림자만 손보면
# 되는거잖아"): the picture's silhouette as an upright board at the stand line, only for the ground shadow it casts
# -> relief_<key>_card.js (the town keeps drawing the picture itself)
FLAT = "--flat" in sys.argv
for key in [k for k in sys.argv[1:] if not k.startswith("--")]:
    src = f"assets/town/hx/{key}.png" if os.path.exists(f"assets/town/hx/{key}.png") else f"assets/town/{key}.png"
    a = np.array(Image.open(src).convert("RGBA")).astype(int)
    if FLAT:
        H, W = a.shape[:2]
        mat = np.where(a[:, :, 3] > 0, 3, 0).astype(np.uint8)
        # a slab as deep as a third of its width (a flat board would cast only a line under a high sun; a tree's crown
        # has depth), centred on the stand line
        D = min(240, int(W * 0.33 * 4))
        data = {"w": W, "h": H, "card": 1, "depth": D / 4, "mat": "".join(str(int(v)) for v in mat.ravel()), "z": [D] * (W * H)}
        js = open(os.path.join(os.path.dirname(__file__), "relief.js")).read()
        js = js.replace("const DATA = null;", "const DATA = " + json.dumps(data, separators=(",", ":")) + ";")
        open(os.path.join(os.path.dirname(__file__), f"relief_{key}_card.js"), "w").write(js)
        print(key, W, H, "card")
        continue
    lf = np.array(Image.open(f"assets/town/{key}_leaf.png").convert("RGBA"))[:, :, 3] > 0
    H, W = a.shape[:2]
    op = a[:, :, 3] > 0
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    green = (g > b + 15) & (g + 12 > r)
    dark = lum < 55                                   # the picture's own outlines
    mat = np.zeros((H, W), np.uint8)
    mat[op & lf] = 3                                  # lit leaves
    mat[op & ~lf & green] = 4                         # the canopy's shaded mass (and the grass at the foot)
    bark = op & ~lf & ~green
    mat[bark] = np.where(lum[bark] < 95, 2, 1)        # bark, its grooves darker
    # outlines join the part they edge (the viewer draws its own): the most common part among the 8 neighbours
    for _ in range(3):
        o = op & dark & (mat != 0)
        for y, x in zip(*np.where(o)):
            nb = mat[max(0, y - 1):y + 2, max(0, x - 1):x + 2].ravel()
            nb = nb[nb != 0]
            if len(nb):
                v = np.bincount(nb).argmax()
                if v: mat[y, x] = v
    # heights: each lit clump a dome over its own area; the mass behind them; the wood rounded across its width
    z = np.zeros((H, W), np.float32)
    lab, n = ndimage.label(mat == 3)
    for i in range(1, n + 1):
        m = lab == i
        d = ndimage.distance_transform_edt(m)
        R = max(1.0, d.max())
        z[m] = 15.0 + 6.0 * np.sqrt(np.clip(d[m] / R, 0, 1)) * min(1.6, R / 4.0)
    m = mat == 4
    d = ndimage.distance_transform_edt(m)
    z[m] = 11.0 + 2.0 * np.sqrt(np.minimum(d[m], 9.0))
    m = (mat == 1) | (mat == 2)
    d = ndimage.distance_transform_edt(m)
    z[m] = 4.0 + 2.2 * np.sqrt(np.minimum(d[m], 25.0)) - np.where(mat[m] == 2, 0.8, 0.0)
    # the picture's bottom row is the ground line
    zq = np.clip(np.round(z * 4), 0, 255).astype(np.uint8)
    data = {"w": W, "h": H, "mat": "".join(str(int(v)) for v in mat.ravel()), "z": [int(v) for v in zq.ravel()]}
    js = open(os.path.join(os.path.dirname(__file__), "relief.js")).read()
    js = js.replace("const DATA = null;", "const DATA = " + json.dumps(data, separators=(",", ":")) + ";")
    open(os.path.join(os.path.dirname(__file__), f"relief_{key}.js"), "w").write(js)
    print(key, W, H, "clumps", n)
