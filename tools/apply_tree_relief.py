#!/usr/bin/env python3
# python3 tools/apply_tree_relief.py RENDERDIR
# The trees and bushes redrawn in the town's style (owner 2026-11-08: "화풍의 통일이 중요하긴해서 그건 작업해야함"):
# each picture taken as a relief (tools/pixel3d/tree_relief.py, branch wip/layer3d) and rendered by the pixel3d viewer
# like the buildings - the 2-px grid, the palette's ramps, outlines in the part's own darkest colour, lit by the noon
# sun - then cropped back onto the picture's own frame (same size, same foot) so everything placed on it stays put.
# RENDERDIR/relief<Name>_code_bB_12.png -> assets/town/<key>.png (bushes: assets/town/hx/<key>.png).
# Run tools/make_tree_sway.py on the trees after (their leaf sway sheets).
import sys, os
from PIL import Image
R = sys.argv[1]
for name, key in (("Oak", "f_oak"), ("Round", "f_round"), ("Young", "f_young"), ("Tall", "f_tall"), ("Big", "f_bigtree"),
                  ("Bush1", "f_bush1"), ("Bush2", "f_bush2"), ("Bush3", "f_bush3")):
    dst = f"assets/town/hx/{key}.png" if os.path.exists(f"assets/town/hx/{key}.png") else f"assets/town/{key}.png"
    w, h = Image.open(dst).size
    top = 4 + (h + 4) % 2                                   # the viewer's sky rows over row 0 (units = px at CELL 2)
    r = Image.open(f"{R}/relief{name}_code_bB_12.png").convert("RGBA")
    c = r.crop((6, top // 2, 6 + w // 2, top // 2 + h // 2)).resize((w, h), Image.NEAREST)
    c.save(dst)
    print(key, dst, w, h)
