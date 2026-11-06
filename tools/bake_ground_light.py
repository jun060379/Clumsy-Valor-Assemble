#!/usr/bin/env python3
"""Light and shade on the town's ground from what stands around it (owner 2026-11-07: "바닥에도 주변요소에 따라 빛과
그늘이 남게하고"), on the map palette. Baked, swapped by the hour like the sprites (bake_light2):
  assets/town/light/ground_{d,m,e,n}.png   world-space maps, one texel = 4 x 2 px, x from 0, y from Y0:
        R = shade (0..1), G = sun on the ground (0..1), B = warm light from lamps / fires / windows (0..1)
      d  noon: a short contact shade under everything standing on the ground
      m  morning, sun from the left: each building, tree, prop and lamp throws its shade to the right along the
         plane, as long as it is tall, fading off; the ground on its sunny side catches a little extra sun
      e  evening, sun from the right: the same to the left, longer
      n  night: contact shade only; pools of warm light round every lamp, fire, lit window and string bulb, wider
         across the plane than up and down it
  assets/town/light/pal_lut.png   colour -> palette index (64 levels per channel; x = r*64 + g, y = b)
  assets/town/light/pal_fx.png    per palette colour (row): [shade 2, shade 1, as is, sunlit, warm 1, warm 2] by the
                                  colour-theory move of bake_light2 (cool + greyer in shade, warm + richer in light),
                                  snapped back onto the palette
shaders/ground_lit.gdshader reads them; the ground stays palette colours.
  python3 tools/bake_ground_light.py docs/work/town-art/light_layout.json"""
import json
import os
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.argv, _argv = sys.argv[:1], sys.argv
src = open(os.path.join(ROOT, "tools/bake_light2.py")).read().replace("\nmain()\n", "\n")
exec(compile(src, "bake_light2", "exec"))           # palette, ramps, shade(), snap()
sys.argv = _argv

CX, CY, Y0, Y1 = 4.0, 2.0, 120.0, 820.0
RAISE = 12.0


def pal_tables():
    cols = np.concatenate(RAMPS)
    labs = np.concatenate(RLAB)
    rid = np.concatenate([[i] * len(r) for i, r in enumerate(RAMPS)])
    n = len(cols)
    # 64 levels a channel (x = r * 64 + g, y = b); every palette colour owns its own bin exactly (the 32-level table
    # took each bin's CENTRE's nearest colour, which sent 55 of the 73 palette colours to a neighbour: speckle)
    Q = 64
    lut = np.zeros((Q, Q * Q), np.uint8)
    q = (np.arange(Q) * (256 // Q) + (128 // Q)).astype(float)
    R, Gg, B = np.meshgrid(q, q, q, indexing="ij")
    grid = np.stack([R, Gg, B], -1).reshape(-1, 3)
    d = ((grid[:, None, :] - cols[None].astype(float)) ** 2).sum(-1).argmin(1).reshape(Q, Q, Q)
    for i, c in enumerate(cols):
        b_ = (c.astype(int) * Q) // 256
        d[b_[0], b_[1], b_[2]] = i
    for r in range(Q):
        for g in range(Q):
            lut[:, r * Q + g] = d[r, g, :]
    for i, c in enumerate(cols):
        b_ = (c.astype(int) * Q) // 256
        assert lut[b_[2], b_[0] * Q + b_[1]] == i, "palette colours share a bin"
    Image.fromarray(lut).save(os.path.join(ROOT, "assets/town/light/pal_lut.png"))
    looks = [(-1.0, 285.0, 17.0, 0.45), (-1.0, 285.0, 9.0, 0.35), (0.0, 0, 0, 0), (1.0, 80.0, 8.0, 0.35),
             (1.0, 55.0, 14.0, 0.55), (1.0, 55.0, 24.0, 0.7)]
    fx = np.zeros((n, len(looks), 4), np.uint8); fx[..., 3] = 255
    for j, (amt, hue_, dl, cs) in enumerate(looks):
        for i in range(n):
            if amt == 0: fx[i, j, :3] = cols[i]; continue
            t = shade(labs[i:i + 1], np.array([amt]), hue_, hue_, dl, cs)[0]
            fx[i, j, :3] = snap(t, rid[i], amt > 0)
    Image.fromarray(fx).save(os.path.join(ROOT, "assets/town/light/pal_fx.png"))
    print("palette tables", n, "colours")


def maps(L):
    W = int(L["W"] / CX) + 1; H = int((Y1 - Y0) / CY) + 1
    xs = (np.arange(W) + 0.5) * CX; ys = Y0 + (np.arange(H) + 0.5) * CY
    X, Y = np.meshgrid(xs, ys)
    # buildings by name: a fence or a wagon lets light through, a house does not
    nb = len(L["bld"]) + 1
    objs = []
    for b, o in zip(L["bld"], L["obj"][:len(L["bld"])]):
        kind = {"g_yard": "fence", "g_ring": "prop", "g_wagon2": "wagon", "g_tentR": "tent"}.get(b[0], "bld")
        objs.append([kind] + o[1:])
    objs.append(L["obj"][len(L["bld"])])
    objs += L["obj"][nb:]
    def band(yf):                 # the plane round a foot line: behind it (RAISE) and in front of it
        return np.clip(1.0 - np.maximum((yf - RAISE - 4.0) - Y, Y - (yf + 26.0)) / 6.0, 0, 1) * ((Y > yf - RAISE - 10) & (Y < yf + 32))
    def contact(o, k):
        kind, x0, x1, yf, h = o
        w = x1 - x0; inset = w * 0.08
        sx = np.clip(np.minimum(X - (x0 + inset), (x1 - inset) - X) / max(6.0, w * 0.12), 0, 1)
        sy = np.clip(1.0 - np.abs(Y - (yf - 2.0)) / 14.0, 0, 1)
        return sx * sy * k
    def cast(o, side, length_k, k):
        kind, x0, x1, yf, h = o
        Lh = h * length_k
        if side > 0:
            t = (X - (x1 - (x1 - x0) * 0.25)) / max(Lh, 1.0)
        else:
            t = ((x0 + (x1 - x0) * 0.25) - X) / max(Lh, 1.0)
        f = np.clip(1.0 - t, 0, 1) * (t > 0)
        inside = (X >= x0) & (X <= x1)
        solid = {"bld": 0.9, "tent": 0.8, "tree": 0.7, "wagon": 0.5, "bush": 0.5, "prop": 0.6, "fence": 0.15, "lamp": 0.1}
        f = np.maximum(f, inside * solid.get(kind, 0.5))
        return f * band(yf) * k
    def sunny(o, side, k):
        kind, x0, x1, yf, h = o
        t = ((x0 - X) if side > 0 else (X - x1)) / max(h * 0.4, 1.0)
        return np.clip(1.0 - t, 0, 1) * (t > 0) * band(yf) * k
    weight = {"bld": 1.0, "tent": 0.85, "tree": 0.75, "bush": 0.55, "prop": 0.6, "wagon": 0.6, "fence": 0.35, "lamp": 0.3}
    out = {}
    for tag in "dmen":
        S = np.zeros_like(X); Su = np.zeros_like(X); Wm = np.zeros_like(X)
        for o in objs:
            k = weight.get(o[0], 0.6)
            S = np.maximum(S, contact(o, 0.75 * k))
            if tag == "m":
                S = np.maximum(S, cast(o, +1, 0.9, 0.8 * k)); Su = np.maximum(Su, sunny(o, +1, 0.6))
            if tag == "e":
                S = np.maximum(S, cast(o, -1, 1.2, 0.85 * k)); Su = np.maximum(Su, sunny(o, -1, 0.6))
        if tag == "n":
            for (kind, lx, ly, r, cr, cg, cb, la) in L["lights"]:
                if kind == "soft": continue
                R_ = r * (1.7 if kind in ("lamp", "fire") else (0.9 if kind == "win" else 1.2))
                d = np.hypot(X - lx, (Y - (ly + (60.0 if kind == "lamp" else 0.0))) * 2.2)
                Wm += la * (0.55 if kind == "win" else 1.0) * np.clip(1.0 - d / R_, 0, 1) ** 2
            S *= 0.6
        Su = np.where(S > 0.15, 0, Su)
        img = np.stack([S, Su, np.clip(Wm, 0, 1), np.ones_like(S)], -1)
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, f"assets/town/light/ground_{tag}.png"))
    print("ground maps", W, "x", H)


os.makedirs(os.path.join(ROOT, "assets/town/light"), exist_ok=True)
pal_tables()
maps(json.load(open(sys.argv[1])))
