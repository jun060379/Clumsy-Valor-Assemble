#!/usr/bin/env python3
# python3 tools/export_pixel3d.py RENDERDIR D name:TOP ... - the pixel3d renders (B mode sprite, M mode ground mask; branch
# wip/layer3d tools/pixel3d) into assets/town/hx (noon), lit/_m (8h), lit/_e (17h), ground shadows into assets/town/shadow.
# D = cells set down inside the sprite: keep 0 (town.gd SETDOWN lowers the whole sprite, so the base is never cut)
# export pixel3d renders into the town: sprite (hx / lit), ground shadow (shadow/), set down D cells
import sys, numpy as np
from PIL import Image
S, D = sys.argv[1], int(sys.argv[2])
for spec in sys.argv[3:]:
  n, top = spec.split(":"); top = int(top)
  hx = Image.open(f"assets/town/hx/g_{n}.png") if False else None
  ref = Image.open(f"assets/town/g_{n}.png")                   # 1x original: W, H at hx = round(1.35x)
  W2 = round(ref.width * 1.35); H2 = round(ref.height * 1.35)
  W = W2 // 2; Hh = H2 // 2
  for h, suf, dst in ((8, "_m", "lit"), (12, "", "hx"), (17, "_e", "lit")):
    im = Image.open(f"{S}/{n}_code_bB_{h}.png").convert("RGBA")
    pad = Image.new("RGBA", (im.width, im.height + D), (0, 0, 0, 0)); pad.alpha_composite(im, (0, D))
    pad.crop((12, 0, 12 + W, top + Hh)).resize((W * 2, (top + Hh) * 2), Image.NEAREST).save(f"assets/town/{dst}/g_{n}{suf}.png")
    m = np.array(Image.open(f"{S}/{n}_code_bM_{h}.png").convert("RGBA"))[:, :, 3] > 0
    b = np.array(im)[:, :, 3] > 0
    foot = np.zeros_like(m)
    for c in range(b.shape[1]):
      rows = np.where(b[:, c])[0]
      if len(rows): r = rows[-1]; foot[r + 1:r + 3, c] = True
    sh = np.vstack([np.zeros((D, m.shape[1]), bool), m | foot])
    bb = np.vstack([np.zeros((D, b.shape[1]), bool), b])
    sh = sh & ~bb
    out = np.zeros(sh.shape + (4,), np.uint8); out[sh] = (38, 70, 76, 110)
    Image.fromarray(out).resize((sh.shape[1] * 2, sh.shape[0] * 2), Image.NEAREST).save(f"assets/town/shadow/g_{n}{suf}.png")
  print(n, "ok", W * 2, (top + Hh) * 2)
