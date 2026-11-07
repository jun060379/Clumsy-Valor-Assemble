"""Bake a code-built building viewer into one page: python3 tools/pixel3d/build.py OUT.html [hall|forge]"""
import sys, json, base64, io, re
import numpy as np
from PIL import Image

NAME = sys.argv[2] if len(sys.argv) > 2 else "hall"
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).tolist()
steps = json.load(open("assets/town/palette.json"))["steps"]
MIRRORED = {"tentL": "tent", "benchL": "bench", "planterL": "planter"}                  # the same solid reflected, lit by the same sun (not a flipped sprite)
js = open(f"tools/pixel3d/{MIRRORED.get(NAME, NAME)}.js").read()
if NAME in MIRRORED: js = js.replace("const MIRROR = false;", "const MIRROR = true;")
if NAME != "hall": js += f"\nconst HALL = {MIRRORED.get(NAME, NAME).upper()};\n"   # the viewer reads the building as HALL
REFN = {"forge2": "g_forge", "forge3": "g_forge", "tent": "g_tentR", "tentL": "g_tentR", "fountain": "q_fountain", "bench": "q_bench", "benchL": "q_bench", "board": "q_board", "bridge": "q_bridge", "lamp": "q_lamp", "planter": "q_planter", "planterL": "q_planter", "pot": "q_pot", "ring": "g_ring"}.get(NAME, "g_" + NAME)
import os
# the big buildings' references are drawn at twice the cell (assets/town/hx, halved here); the props are drawn at
# one cell per pixel (assets/town) and taken as they are
HX = os.path.exists(f"assets/town/hx/{REFN}.png")
src = Image.open(f"assets/town/hx/{REFN}.png" if HX else f"assets/town/{REFN}.png").convert("RGBA")
if NAME in MIRRORED: src = src.transpose(Image.FLIP_LEFT_RIGHT)
ref = src.resize((src.width // 2, src.height // 2), Image.NEAREST) if HX else src
b = io.BytesIO(); ref.save(b, "PNG", optimize=True)
html = open("tools/pixel3d/viewer.html").read()
html = (html.replace("__HALL_JS__", js)
            .replace("__PALETTE__", json.dumps(P)).replace("__STEPS__", json.dumps(steps))
            .replace("__REF__", "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()))
# each page names its own building (it said 본관 on every one)
KO = {"hall": "본관", "forge": "대장간", "barn": "헛간", "cottage": "목욕집", "store": "창고", "tent": "텐트", "tentL": "텐트(반대쪽)",
      "kiln": "숯가마", "well": "우물", "anvil": "모루", "fountain": "분수", "bench": "벤치", "benchL": "벤치(반대쪽)",
      "board": "게시판", "bridge": "다리", "lamp": "가로등", "planter": "화분 상자", "planterL": "화분 상자(반대쪽)", "pot": "화분", "ring": "모닥불"}
if NAME in KO:
    html = (html.replace("<title>본관 코드 도트</title>", f"<title>{KO[NAME]} 코드 도트</title>")
                .replace("<h1>본관 · 코드로 쌓은 도트</h1>", f"<h1>{KO[NAME]} · 코드로 쌓은 도트</h1>")
                .replace("레퍼런스는 지금 본관 그림.", f"레퍼런스는 지금 {KO[NAME]} 그림."))
open(sys.argv[1], "w").write(html)
print("wrote", sys.argv[1], len(html) // 1024, "KB")
