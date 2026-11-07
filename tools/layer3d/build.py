"""Bake prep.py's output into the one-file three.js viewer (tools/layer3d/viewer.html -> OUT.html).
  python3 tools/layer3d/build.py PREP.json OUT.html"""
import sys, json, base64, io
import numpy as np
from PIL import Image

d = json.load(open(sys.argv[1]))
w, h = d["w"], d["h"]
ramp = np.array(d["ramp"]).reshape(h, w)
idx = np.array(d["idx"]).reshape(h, w)
layer = np.array(d["layer"]).reshape(h, w)
m = np.zeros((h, w, 4), np.uint8)
op = ramp >= 0
m[..., 0] = np.where(op, ramp + 1, 0)
m[..., 1] = np.where(op, idx, 0)
m[..., 2] = np.where(op, layer, 0)
m[..., 3] = np.where(op, 255, 0)


def png64(a):
    b = io.BytesIO()
    Image.fromarray(a).save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


orig = np.array(Image.open(f"assets/town/hx/{d['sprite']}.png").convert("RGBA"))[::2, ::2]
meta = {k: d[k] for k in ("sprite", "w", "h", "planes", "solids", "palette", "steps", "names")}
html = open("tools/layer3d/viewer.html").read()
html = html.replace("__MAT__", png64(m)).replace("__ORIG__", png64(orig)).replace("__META__", json.dumps(meta, separators=(",", ":")))
open(sys.argv[2], "w").write(html)
print("wrote", sys.argv[2], len(html) // 1024, "KB")
