"""Bake the code-built hall viewer into one page: python3 tools/pixel3d/build.py OUT.html"""
import sys, json, base64, io
import numpy as np
from PIL import Image

P = np.array(Image.open("assets/town/palette.png").convert("RGB")).tolist()
steps = json.load(open("assets/town/palette.json"))["steps"]
ref = Image.open("assets/town/hx/g_hall.png").convert("RGBA").resize((436, 296), Image.NEAREST)
b = io.BytesIO(); ref.save(b, "PNG", optimize=True)
html = open("tools/pixel3d/viewer.html").read()
html = (html.replace("__HALL_JS__", open("tools/pixel3d/hall.js").read())
            .replace("__PALETTE__", json.dumps(P)).replace("__STEPS__", json.dumps(steps))
            .replace("__REF__", "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()))
open(sys.argv[1], "w").write(html)
print("wrote", sys.argv[1], len(html) // 1024, "KB")
