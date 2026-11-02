## 초심 run_7f (fourth delivery): the generator's rainbow fringes in the hair and on the armour. Off-hue pixels among the
## hair take the local pink's hue (keeping their value); off-hue pixels by the armour go neutral grey. Run in a folder with
## src.png (the delivered sheet); writes fixed.png, then pack the 7 frames into a strip (run_7f.png, bottoms aligned).
import numpy as np, colorsys, sys
from PIL import Image
from scipy import ndimage
im = np.asarray(Image.open('src.png').convert('RGBA')).astype(np.float32) / 255
rgb, a = im[..., :3], im[..., 3]
mx, mn = rgb.max(-1), rgb.min(-1)
v = mx; s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
d = np.maximum(mx - mn, 1e-6)
h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
vis = a > 0.08
pink = vis & (s > 0.35) & ((h >= 330) | (h <= 25)) & (v > 0.45)
off = vis & (s > 0.15) & (h > 28) & (h < 255) & (v > 0.15)
frac = ndimage.uniform_filter(pink.astype(np.float32), 25)
met = vis & (s < 0.16) & (v > 0.5)
mfrac = ndimage.uniform_filter(met.astype(np.float32), 25)
frac2 = ndimage.uniform_filter(pink.astype(np.float32), 61)
bright = ndimage.uniform_filter((vis & (s < 0.12) & (v > 0.78)).astype(np.float32), 9)
hair = (vis & ~pink & (frac2 > 0.3) & (((v < 0.62) & (v > 0.34)) | (a < 0.7)) & (s < 0.45) & (bright < 0.12) & ((h > 25) & (h < 330) | (s < 0.15))) | (off & (frac >= mfrac)) | (vis & ~pink & (frac > 0.4) & (mfrac < 0.08) & (s < 0.35) & (v > 0.2))
metal = off & ~hair
# hair: the local pink's hue/sat at this pixel's value
ph = np.where(pink, h, 0); ph = np.where(ph > 180, ph - 360, ph)
w = ndimage.uniform_filter(pink.astype(np.float32), 31) + 1e-6
hue_l = ndimage.uniform_filter(ph * pink, 31) / w
sat_l = ndimage.uniform_filter(s * pink, 31) / w
out = rgb.copy()
ys, xs = np.where(hair)
for y, x in zip(ys, xs):
    hh = (hue_l[y, x] % 360) / 360
    out[y, x] = colorsys.hsv_to_rgb(hh, min(0.9, sat_l[y, x]), v[y, x])
lum = (0.3 * r + 0.59 * g + 0.11 * b)
out[metal] = np.stack([lum, lum, lum * 1.04], -1)[metal]
print('hair px', hair.sum(), 'metal px', metal.sum())
res = np.dstack([np.clip(out, 0, 1), a])
Image.fromarray((res * 255).astype(np.uint8)).save('fixed.png')
