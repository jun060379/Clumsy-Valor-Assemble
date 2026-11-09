"""Bake a code-built building viewer into one page: python3 tools/pixel3d/build.py OUT.html [hall|forge]"""
import sys, os, json, base64, io, re
import numpy as np
from PIL import Image

NAME = sys.argv[2] if len(sys.argv) > 2 else "hall"
P = np.array(Image.open("assets/town/palette.png").convert("RGB")).tolist()
steps = json.load(open("assets/town/palette.json"))["steps"]
MIRRORED = {"tentL": "tent", "benchL": "bench", "planterL": "planter"}                  # the same solid reflected, lit by the same sun (not a flipped sprite)
SIZED = {"bushL": "bush", "bushM": "bush", "bushS": "bush", "barrelL": "barrel", "barrelM": "barrel", "barrelS": "barrel", "crateL": "crate", "crateS": "crate"}   # one module, SIZE picked
VARIANTS = {"bgwood": "wood", "bghills": "hills", "treeOak": "oak", "treeRound": "round", "treeYoung": "young", "treeTall": "tall"}      # the town's middle distance (one module, two strips)
RELIEFS = {"reliefOak": "f_oak", "reliefRound": "f_round", "reliefYoung": "f_young", "reliefTall": "f_tall", "reliefBig": "f_bigtree", "reliefBush1": "f_bush1", "reliefBush2": "f_bush2", "reliefBush3": "f_bush3"}   # trees from their pictures (tree_relief.py)
BASE = ("relief_" + RELIEFS[NAME]) if NAME in RELIEFS else ("relief_" + NAME) if NAME.endswith("_card") else MIRRORED.get(NAME) or SIZED.get(NAME) or (("tree" if NAME.startswith("tree") else "bgmid") if NAME in VARIANTS else NAME)
js = open(f"tools/pixel3d/{BASE}.js").read()
if NAME in MIRRORED: js = js.replace("const MIRROR = false;", "const MIRROR = true;")
if NAME in VARIANTS: js = js.replace('const VARIANT = "hills";', f'const VARIANT = "{VARIANTS[NAME]}";').replace('const VARIANT = "oak";', f'const VARIANT = "{VARIANTS[NAME]}";')
if NAME in SIZED: js = js.replace('const SIZE = "L";', f'const SIZE = "{NAME[-1]}";')
if NAME != "hall": js += ("\nconst HALL = RELIEF;\n" if NAME in RELIEFS or NAME.endswith("_card") else f"\nconst HALL = {BASE.upper()};\n")   # the viewer reads the building as HALL
# the props (modelled one unit per game px) render on the town's 2-px grid: two units a cell (owner 2026-11-08)
PROPS = {"bush", "relief_f_bigtree", "relief_f_bush1", "relief_f_bush2", "relief_f_bush3", "relief_f_oak", "relief_f_round", "relief_f_young", "relief_f_tall", "anvil", "bgmid", "paving", "bench", "board", "bridge", "lamp", "planter", "pot", "ring", "lights", "yard", "wagon", "barrel", "crate"}
if BASE in PROPS or NAME.endswith("_card"): js += "\nHALL.CELL = 2;\n"
if os.environ.get("SHPAD"): js += f"\nvar SHPAD_IN = {int(os.environ['SHPAD'])};\n"   # widened for the ground shadows (viewer SHPAD)
if os.environ.get("SHK"): js += f"\nvar SHK_IN = {float(os.environ['SHK'])}; var SHDN_IN = {int(os.environ.get('SHDN', '0'))};\n"   # the ground shadow's depth (viewer SHK)
REFN = {"bushL": "f_bush1", "bushM": "f_bush2", "bushS": "f_bush3", "forge2": "g_forge", "forge3": "g_forge", "tent": "g_tentR", "tentL": "g_tentR", "fountain": "q_fountain", "bench": "q_bench", "benchL": "q_bench", "board": "q_board", "bridge": "q_bridge", "lamp": "q_lamp", "planter": "q_planter", "planterL": "q_planter", "pot": "q_pot", "ring": "g_ring", "lights": "q_lights", "yard": "g_yard", "wagon": "g_wagon2", "paving": "k_stone_cap", "barrelL": "q_barrelL", "barrelM": "q_barrelM", "barrelS": "q_barrelS", "crateL": "q_crateL", "crateS": "q_crateS", "bgwood": "bg_wood", "bghills": "bg_hills", "treeOak": "f_oak", "treeRound": "f_round", "treeYoung": "f_young", "treeTall": "f_tall", "reliefOak": "f_oak", "reliefRound": "f_round", "reliefYoung": "f_young", "reliefTall": "f_tall", "reliefBig": "f_bigtree", "reliefBush1": "f_bush1", "reliefBush2": "f_bush2", "reliefBush3": "f_bush3"}.get(NAME, NAME[:-5] if NAME.endswith("_card") else "g_" + NAME)
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
      "board": "게시판", "bridge": "다리", "lamp": "가로등", "planter": "화분 상자", "planterL": "화분 상자(반대쪽)", "pot": "화분", "ring": "모닥불", "lights": "줄 조명", "yard": "훈련장 울타리", "wagon": "마차", "barrelL": "통(대)", "barrelM": "통(중)", "barrelS": "통(소)", "crateL": "상자(대)", "crateS": "상자(소)", "bushL": "덤불(대)", "bushM": "덤불(중)", "bushS": "덤불(소)", "paving": "돌길"}
if NAME in KO:
    html = (html.replace("<title>본관 코드 도트</title>", f"<title>{KO[NAME]} 코드 도트</title>")
                .replace("<h1>본관 · 코드로 쌓은 도트</h1>", f"<h1>{KO[NAME]} · 코드로 쌓은 도트</h1>")
                .replace("레퍼런스는 지금 본관 그림.", f"레퍼런스는 지금 {KO[NAME]} 그림."))
open(sys.argv[1], "w").write(html)
print("wrote", sys.argv[1], len(html) // 1024, "KB")
