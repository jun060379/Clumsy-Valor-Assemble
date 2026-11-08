#!/usr/bin/env python3
# python3 tools/make_bg_ranges.py
# The town's far mountains as three wide ranges (owner 2026-11-08: "원경도 반복임. 공기 산란도 없음"), built from the
# painted range (assets/town/hx/bg_mountains.png): copies laid at irregular steps, flipped, raised or sunk, so no stretch
# repeats within a range's parallax travel; each range farther back is recoloured onto a paler ramp (aerial perspective:
# far = the blue ramp's two lightest, mid = violet one step lighter, near = as painted), and the foot of each range sits
# in valley haze (one step lighter below a ragged line). Palette colours only, brightness order kept.
import random, numpy as np
from PIL import Image
SRC = "assets/town/hx/bg_mountains.png"
V2, V3, V4, V5, W7 = (73, 50, 108), (90, 63, 123), (99, 83, 134), (229, 149, 174), (184, 143, 107)
B4, B5 = (64, 133, 146), (95, 147, 159)
MAPS = {
  "far": {V2: B4, V3: B4, V4: B5, W7: B5, V5: B5},
  "mid": {V2: V3, V3: V3, V4: V4, W7: V4, V5: V4},
  "near": {},
}
HAZE = {"far": {B4: B5}, "mid": {V3: V4}, "near": {V2: V3}}
# width = parallax travel over the town (9450 px) + a wide view, and a margin
SPEC = {"far": (1900, 11, 0.62, 0.42, 0.7, 6), "mid": (2600, 23, 0.6, 0.5, 0.9, 10), "near": (3400, 37, 0.62, 0.65, 1.1, 14)}
src = np.array(Image.open(SRC).convert("RGBA"))
H, W = src.shape[:2]
PADY = 56
for name, (width, seed, haze_frac, s0, s1, jy) in SPEC.items():
  rnd = random.Random(seed)
  out = np.zeros((H + PADY, width, 4), np.uint8)
  x = -rnd.randint(0, W // 2)
  while x < width:
    im = src[:, ::-1] if rnd.random() < 0.5 else src
    dy = PADY // 2 + 2 * rnd.randint(-jy, jy)
    a = im[:, :, 3] > 0
    for yy in range(H):
      ty = yy + dy
      if ty >= H + PADY: break
      cols = np.where(a[yy])[0]
      cols = cols[(cols + x >= 0) & (cols + x < width)]
      out[ty, cols + x] = im[yy, cols]
    # everything below a copy's base row is base colour (its foot never shows sky under a raised copy)
    x += 2 * (int(W * rnd.uniform(s0, s1)) // 2)
  # fill the bottom under every column's lowest painted row with the base colour
  for c in range(width):
    rows = np.where(out[:, c, 3] > 0)[0]
    if len(rows): out[rows[-1]:, c] = (*V2, 255)
  # recolour (farther = paler ramp)
  m = MAPS[name]
  rgb = [tuple(p) for p in out[:, :, :3].reshape(-1, 3)]
  flat = out.reshape(-1, 4)
  for i, p in enumerate(rgb):
    if flat[i, 3] and p in m: flat[i, :3] = m[p]
  # valley haze: below a ragged line (2-px steps) one step lighter
  hz = HAZE[name]
  base = int((H + PADY) * haze_frac)
  ph = rnd.uniform(0, 6.28)
  for c in range(0, width, 2):
    t = c / width * 6.28
    ly = base + int(10 * np.sin(t * 7 + ph) + 6 * np.sin(t * 19 + ph * 2) + 3 * np.sin(t * 43)) // 2 * 2
    for cc in (c, c + 1):
      if cc >= width: break
      for r in range(ly, H + PADY):
        p = tuple(out[r, cc, :3])
        if out[r, cc, 3] and p in hz: out[r, cc, :3] = hz[p]
  Image.fromarray(out).save(f"assets/town/hx/bg_range_{name}.png")
  print(name, out.shape)
