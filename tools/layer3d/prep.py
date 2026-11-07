"""Split a town sprite into its depth layers and strip the baked light, for the three.js layer viewer (tools/layer3d).

Owner 2026-11-07: "three.js로 변환해서 층 분리한다음 명암은 따로 주고싶다. 코드로 작성해라"

  python3 tools/layer3d/prep.py g_hall PROXY.json OUT.json

- cells: assets/town/hx/<k>.png at half size (1 cell = 2 px)
- each cell -> (ramp, step) of assets/town/palette.png (the sprite is all palette colours)
- the baked light is taken out per region (4-connected cells of one ramp): the region keeps one body step (its most
  used); cells 2+ steps darker than the body are line work and keep their offset; everything else becomes the body
- layers: the proxy's planes (tools/proxy/<k>.json, planes later in the list lie over earlier ones); a cell belongs to
  the last plane whose polygon holds its centre; cells no plane holds go to the nearest plane's layer (by bbox)
Writes OUT.json: {w, h, ramp[], idx[] (flat, body/line steps), layer[], planes, solids, palette, steps, names}
"""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage
from matplotlib.path import Path

k, proxy_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).astype(int)
PJ = json.load(open("assets/town/palette.json"))
lut = {}
for r, s in enumerate(PJ["steps"]):
    for i in range(s):
        lut.setdefault(tuple(P[r, i]), (r, i))

A = np.array(Image.open(f"assets/town/hx/{k}.png").convert("RGBA"))[::2, ::2]
h, w = A.shape[:2]
op = A[..., 3] > 127
ramp = np.full((h, w), -1, int)
step = np.zeros((h, w), int)
for y, x in zip(*np.nonzero(op)):
    ramp[y, x], step[y, x] = lut[tuple(int(v) for v in A[y, x, :3])]

# take the baked light out: one body step per region, line work kept as an offset below it
flat = step.copy()
for r in range(len(PJ["steps"])):
    lab, n = ndimage.label(ramp == r)
    for i in range(1, n + 1):
        m = lab == i
        st = step[m]
        body = int(np.bincount(st).argmax())
        line = st <= body - 2
        flat[m] = np.where(line, st, body)

# layers from the proxy planes
proxy = json.load(open(proxy_path))
planes = proxy["planes"]
layer = np.full((h, w), -1, int)
yy, xx = np.mgrid[0:h, 0:w]
pts = np.c_[xx.ravel() + 0.5, yy.ravel() + 0.5]
for li, pl in enumerate(planes):
    inside = Path(pl["poly"]).contains_points(pts).reshape(h, w)
    layer[inside & op] = li
left = op & (layer < 0)
if left.any():
    # nearest owned cell's layer
    idx = ndimage.distance_transform_edt(layer < 0, return_distances=False, return_indices=True)
    layer[left] = layer[idx[0][left], idx[1][left]]
print(k, w, "x", h, "cells;", "layers", [int((layer == i).sum()) for i in range(len(planes))])

json.dump({
    "sprite": k, "w": w, "h": h,
    "ramp": ramp.ravel().tolist(), "idx": flat.ravel().tolist(), "layer": layer.ravel().tolist(),
    "planes": planes, "solids": proxy.get("solids", []),
    "palette": P.tolist(), "steps": PJ["steps"], "names": PJ["names"],
}, open(out_path, "w"), separators=(",", ":"))
