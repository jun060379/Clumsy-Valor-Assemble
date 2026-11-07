"""Bake a code-built building viewer into one page: python3 tools/pixel3d/build.py OUT.html [hall|forge]"""
import sys, json, base64, io, re
import numpy as np
from PIL import Image

NAME = sys.argv[2] if len(sys.argv) > 2 else "hall"
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).tolist()
steps = json.load(open("assets/town/palette.json"))["steps"]
js = open(f"tools/pixel3d/{NAME}.js").read()
if NAME != "hall": js += f"\nconst HALL = {NAME.upper()};\n"   # the viewer reads the building as HALL
src = Image.open(f"assets/town/hx/g_{NAME}.png" if NAME != "forge2" else "assets/town/hx/g_forge.png").convert("RGBA")
ref = src.resize((src.width // 2, src.height // 2), Image.NEAREST)
b = io.BytesIO(); ref.save(b, "PNG", optimize=True)
html = open("tools/pixel3d/viewer.html").read()
html = (html.replace("__HALL_JS__", js)
            .replace("__PALETTE__", json.dumps(P)).replace("__STEPS__", json.dumps(steps))
            .replace("__REF__", "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()))
open(sys.argv[1], "w").write(html)
print("wrote", sys.argv[1], len(html) // 1024, "KB")
