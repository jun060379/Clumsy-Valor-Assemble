#!/usr/bin/env python3
"""Light and shade on the town's ground from what stands around it (owner 2026-11-07: "바닥에도 주변요소에 따라 빛과
그늘이 남게하고"), on the map palette. Baked, swapped by the hour like the sprites (bake_light2):
  assets/town/light/ground_{d,m,e,n}.png   world-space maps, one texel = 4 x 2 px, x from 0, y from Y0:
        R = shade (0..1), G = sun on the ground (0..1), B = warm light from lamps / fires / windows (0..1)
      d / m / e  noon / morning / evening: the pixel3d sprites' own ground shadows (rendered with the same sun,
         assets/town/shadow, placed where the town draws them: tests/dump_light_layout.gd); the trees, bushes and
         rocks a contact shade and, morning and evening, a shade thrown along the plane as long as they are tall
      n  night: contact shade only; pools of warm light round every lamp, fire, lit window and string bulb, wider
         across the plane than up and down it
  assets/town/light/pal_lut.png   colour -> palette index (32 levels per channel; x = r*32 + g, y = b)
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

CX, CY, Y0, Y1 = 2.0, 2.0, 120.0, 820.0       # town.gd sets the shader's gmap_cell to (CX, CY)
RAISE = 42.0                                    # town.gd RAISE: the plane behind the stand line (16 px in front)


def pal_tables():
    cols = np.concatenate(RAMPS)
    labs = np.concatenate(RLAB)
    rid = np.concatenate([[i] * len(r) for i, r in enumerate(RAMPS)])
    n = len(cols)
    lut = np.zeros((32, 32 * 32), np.uint8)
    q = (np.arange(32) * 8 + 4).astype(float)
    R, Gg, B = np.meshgrid(q, q, q, indexing="ij")
    grid = np.stack([R, Gg, B], -1).reshape(-1, 3)
    d = ((grid[:, None, :] - cols[None].astype(float)) ** 2).sum(-1).argmin(1).reshape(32, 32, 32)
    for r in range(32):
        for g in range(32):
            lut[:, r * 32 + g] = d[r, g, :]
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
    def band(yf):                 # the plane round a foot line: RAISE behind it, 16 px in front
        return np.clip(1.0 - np.maximum((yf - RAISE) - Y, Y - (yf + 16.0)) / 6.0, 0, 1) * ((Y > yf - RAISE - 6) & (Y < yf + 22))
    def contact(o, k):
        kind, x0, x1, yf, h = o
        w = x1 - x0; inset = w * 0.08
        sx = np.clip(np.minimum(X - (x0 + inset), (x1 - inset) - X) / max(6.0, w * 0.12), 0, 1)
        sy = np.clip(1.0 - np.abs(Y - (yf - 2.0)) / 14.0, 0, 1)
        return sx * sy * k
    def cast(o, side, length_k, k):
        kind, x0, x1, yf, h = o
        Lh = h * length_k
        t = ((X - (x1 - (x1 - x0) * 0.25)) if side > 0 else ((x0 + (x1 - x0) * 0.25) - X)) / max(Lh, 1.0)
        f = np.clip(1.0 - t, 0, 1) * (t > 0)
        inside = (X >= x0) & (X <= x1)
        f = np.maximum(f, inside * {"tree": 0.7, "bush": 0.5, "prop": 0.6}.get(kind, 0.5))
        return f * band(yf) * k
    def sunny(o, side, k):
        kind, x0, x1, yf, h = o
        t = ((x0 - X) if side > 0 else (X - x1)) / max(h * 0.4, 1.0)
        return np.clip(1.0 - t, 0, 1) * (t > 0) * band(yf) * k
    # the pixel3d sprites' own ground shadows, rendered with the same sun (assets/town/shadow), where the town drew them
    def p3d(suf):
        S = np.zeros_like(X)
        for k, cx, cy in L["p3d"]:
            f = os.path.join(ROOT, f"assets/town/shadow/{k}{suf}.png")
            if not os.path.exists(f): continue
            a = np.array(Image.open(f).convert("RGBA"))[::2, ::2, 3].astype(float) / 150.0
            gx, gy = int(round(cx / CX)), int(round((cy - Y0) / CY))
            h, w = a.shape
            x0, y0 = max(0, gx), max(0, gy); x1, y1 = min(W, gx + w), min(H, gy + h)
            if x1 <= x0 or y1 <= y0: continue
            S[y0:y1, x0:x1] = np.maximum(S[y0:y1, x0:x1], np.clip(a[y0 - gy:y1 - gy, x0 - gx:x1 - gx], 0, 1))
        return S
    weight = {"tree": 0.75, "bush": 0.55, "prop": 0.6}
    # the lamps' and fires' light with its shadows (owner 2026-11-08: "빛이 실제로 타일과 오브젝트의 영역에 빛과 그림자로
    # 영역에 영향을 주게"): every texel, ground or sprite, traced to each light over a label map of the pixel3d sprites
    # (drawn order: the later on top); the ground warms on the palette by it, the sprites carry their own (the
    # pixel3d night renders lit by the same lamps); a texel first leaves its own sprite (its face toward the light is lit), then any
    # other sprite on the way shades it. The sprite a light sits in (the forge's hearth, the fire ring, the lamp's own
    # post) does not block it. The blue channel: the ground's warm, on the palette.
    def labels():
        lab = np.zeros((H, W), np.int16); boxes = []
        for i, (k, cx, cy) in enumerate(L["p3d"]):
            f = os.path.join(ROOT, f"assets/town/hx/{k}.png")
            if not os.path.exists(f): boxes.append(None); continue
            a = np.array(Image.open(f).convert("RGBA"))[::2, ::2, 3] > 127
            gx, gy = int(round((cx + 24.0) / CX)), int(round((cy - Y0) / CY))
            h, w = a.shape
            x0, y0 = max(0, gx), max(0, gy); x1, y1 = min(W, gx + w), min(H, gy + h)
            boxes.append((gx, gy, w, h))
            if x1 <= x0 or y1 <= y0: continue
            sub = a[y0 - gy:y1 - gy, x0 - gx:x1 - gx]
            lab[y0:y1, x0:x1][sub] = i + 1
        return lab, boxes
    def night_light(L, X, Y):
        lab, boxes = labels()
        out = np.zeros_like(X)
        for (kind, lx, ly, r, cr, cg, cb, la) in L["lights"]:
            if kind not in ("lamp", "fire", "bulb"): continue
            R_ = r * (1.7 if kind in ("lamp", "fire") else 1.2)
            gx0, gx1 = max(0, int((lx - R_) / CX)), min(W, int((lx + R_) / CX) + 1)
            gy0, gy1 = max(0, int((ly - R_ - Y0) / CY)), min(H, int((ly + R_ - Y0) / CY) + 1)
            if gx1 <= gx0 or gy1 <= gy0: continue
            xs_, ys_ = X[gy0:gy1, gx0:gx1], Y[gy0:gy1, gx0:gx1]
            d = np.hypot(xs_ - lx, (ys_ - ly) * 1.4)
            f = np.clip(1.0 - d / R_, 0, 1) ** 2 * la
            # the sprites that hold the light do not block it
            host = set()
            lgx, lgy = int(lx / CX), int((ly - Y0) / CY)
            for i, b in enumerate(boxes):
                if b and b[0] - 2 <= lgx < b[0] + b[2] + 2 and b[1] - 2 <= lgy < b[1] + b[3] + 2: host.add(i + 1)
            own = lab[gy0:gy1, gx0:gx1]
            N = 40
            t = (np.arange(N) + 0.5) / N * 0.94                      # stop short of the light itself
            sx = (xs_[..., None] + (lx - xs_)[..., None] * t) / CX
            sy = (ys_[..., None] - Y0 + (ly - ys_)[..., None] * t) / CY
            sl = lab[np.clip(sy.astype(int), 0, H - 1), np.clip(sx.astype(int), 0, W - 1)]
            for hh in host: sl = np.where(sl == hh, 0, sl)
            other = (sl != 0) & (sl != own[..., None])
            # leaving its own sprite first: only what lies past the first sample outside it counts
            out_own = np.cumsum(sl != own[..., None], -1) > 0
            blocked = (other & out_own).any(-1)
            out[gy0:gy1, gx0:gx1] += f * (~blocked)
        # only what is there takes the light: the sprites and the ground's plane and face, never the sky behind
        surf = lab > 0
        if "floors" in L:
            for fl in (0, 1):
                fy = np.array([f[fl] for f in L["floors"]], float)[:W]
                fy = np.concatenate([fy, np.full(W - len(fy), fy[-1])]) if len(fy) < W else fy
                surf |= (Y > fy[None, :] - RAISE - 2.0) & (Y < fy[None, :] + 30.0)
        return np.clip(out, 0, 1) * surf
    out = {}
    for tag, suf in (("d", ""), ("m", "_m"), ("e", "_e"), ("n", "")):
        S = p3d(suf); Su = np.zeros_like(X); Wm = np.zeros_like(X)
        for o in L["obj"]:
            k = weight.get(o[0], 0.6)
            S = np.maximum(S, contact(o, 0.75 * k))
            if tag == "m":
                S = np.maximum(S, cast(o, +1, 0.9, 0.8 * k)); Su = np.maximum(Su, sunny(o, +1, 0.6))
            if tag == "e":
                S = np.maximum(S, cast(o, -1, 1.2, 0.85 * k)); Su = np.maximum(Su, sunny(o, -1, 0.6))
        if tag == "n":
            Wm = night_light(L, X, Y)
            S *= 0.6
        Su = np.where(S > 0.15, 0, Su)
        img = np.stack([S, Su, np.clip(Wm, 0, 1), np.ones_like(S)], -1)
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, f"assets/town/light/ground_{tag}.png"))
    print("ground maps", W, "x", H, "with", len(L["p3d"]), "pixel3d shadows")


os.makedirs(os.path.join(ROOT, "assets/town/light"), exist_ok=True)
pal_tables()
maps(json.load(open(sys.argv[1])))
