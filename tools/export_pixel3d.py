#!/usr/bin/env python3
# python3 tools/export_pixel3d.py RENDERDIR name:key:W:TOP[:2] ...
#   the pixel3d renders (branch wip/layer3d tools/pixel3d; B mode sprite, M mode ground mask, at 8/12/17 h) into the
#   town: assets/town/hx/<key>.png (noon), lit/<key>_m (8h), lit/<key>_e (17h), ground shadows into shadow/.
#   name = render name (<name>_code_bB_<h>.png), key = town sprite key, W = module width, TOP = sky rows (module units).
#   :2 for the props: modelled one unit per game px off their 1x sprite, rendered two units a cell (viewer CELL 2), so
#   W and TOP are in px; their shadow canvas is padded to the buildings' 24-px left margin.
# The crop keeps the reference's rows (render row r+TOP = reference row r) so FX anchored on the old sprite stay put;
# where the render reaches below the reference's bottom the crop grows and the sprite is set down by the same amount
# (printed as "ext"; town.gd P3D[key] = [TOP px, set-down px]).
import sys, numpy as np
from PIL import Image
S = sys.argv[1]
for spec in sys.argv[2:]:
  f = spec.split(":"); n, key, W, top = f[0], f[1], int(f[2]), int(f[3]); cell = int(f[4]) if len(f) > 4 else 1
  rk = {"g_tentL": "g_tentR", "q_benchL": "q_bench", "q_planterL": "q_planter"}.get(key, key)
  ref = Image.open(f"assets/town/{rk}.png")
  x0, pad_l = 12, 0
  if cell == 1: Hh = round(ref.height * 1.35) // 2        # 1x original: hx = round(1.35x), one cell 2 px
  else:                                                    # a prop: one unit a px, the ground row on a cell edge
    top = top + (ref.height + top) % 2
    Hh = (ref.height + top) // 2 - top // 2
    W = -(-W // 2); x0 = 6; pad_l = 6; top = top // 2
  last = 0
  for h in (8, 12, 17):
    a = np.array(Image.open(f"{S}/{n}_code_bB_{h}.png").convert("RGBA"))[:, :, 3] > 0
    last = max(last, np.where(a.any(1))[0][-1])
  ch = max(top + Hh, last + 1)
  for h, suf, dst in ((8, "_m", "lit"), (12, "", "hx"), (17, "_e", "lit")):
    im = Image.open(f"{S}/{n}_code_bB_{h}.png").convert("RGBA")
    pad = Image.new("RGBA", (im.width, max(im.height, ch)), (0, 0, 0, 0)); pad.alpha_composite(im, (0, 0))
    pad.crop((x0, 0, x0 + W, ch)).resize((W * 2, ch * 2), Image.NEAREST).save(f"assets/town/{dst}/{key}{suf}.png")
    m = np.array(Image.open(f"{S}/{n}_code_bM_{h}.png").convert("RGBA"))[:, :, 3] > 0
    b = np.array(im)[:, :, 3] > 0
    # contact shade under the base (3 cells, fading), over the ground mask (cool shade colour, never black)
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
  print(key, "size", W * 2, ch * 2, "top_px", top * 2, "ext_px", (ch - top - Hh) * 2, "gap_cells", top + Hh - 1 - last)
