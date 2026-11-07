"""Bake a code-built building viewer into one page: python3 tools/pixel3d/build.py OUT.html [hall|forge]"""
import sys, json, base64, io, re
import numpy as np
from PIL import Image

NAME = sys.argv[2] if len(sys.argv) > 2 else "hall"
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).tolist()
steps = json.load(open("assets/town/palette.json"))["steps"]
MIRRORED = {"tentL": "tent"}                  # the same solid reflected, lit by the same sun (not a flipped sprite)
js = open(f"tools/pixel3d/{MIRRORED.get(NAME, NAME)}.js").read()
if NAME in MIRRORED: js = js.replace("const MIRROR = false;", "const MIRROR = true;")
if NAME != "hall": js += f"\nconst HALL = {MIRRORED.get(NAME, NAME).upper()};\n"   # the viewer reads the building as HALL
REFN = {"forge2": "g_forge", "forge3": "g_forge", "tent": "g_tentR", "tentL": "g_tentR", "tent_a75": "g_tentR", "tent_a65": "g_tentR", "tent_a55": "g_tentR", "tent_a25": "g_tentR", "tent_a35": "g_tentR", "tent_a50": "g_tentR"}.get(NAME, "g_" + NAME)
src = Image.open(f"assets/town/hx/{REFN}.png").convert("RGBA")
if NAME in MIRRORED: src = src.transpose(Image.FLIP_LEFT_RIGHT)
ref = src.resize((src.width // 2, src.height // 2), Image.NEAREST)
b = io.BytesIO(); ref.save(b, "PNG", optimize=True)
html = open("tools/pixel3d/viewer.html").read()
html = (html.replace("__HALL_JS__", js)
            .replace("__PALETTE__", json.dumps(P)).replace("__STEPS__", json.dumps(steps))
            .replace("__REF__", "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()))
open(sys.argv[1], "w").write(html)
print("wrote", sys.argv[1], len(html) // 1024, "KB")
