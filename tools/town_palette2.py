#!/usr/bin/env python3
"""The whole town map on one palette of material ramps (owner 2026-11-06: "맵 전체의 팔레트 통일", after MGD EP14).
Materials are fixed hue sectors of the art (Lab hue), greys apart; each material is one ramp dark -> light built from
the colours the art already uses at each lightness, then bent by colour theory: the shadow end turns cooler (toward
blue-violet), the light end warmer (toward yellow), saturation peaks in the middle and eases at both ends.
A pixel is moved only inside ITS material's ramp, to the step of the nearest lightness (never "the nearest colour
anywhere": a brown shadow cannot become a green one).
  python3 tools/town_palette2.py build            -> assets/town/palette.png (row = ramp, dark -> light) + palette.json
  python3 tools/town_palette2.py apply [FILES]    -> remap in place (default: every town map sprite)
  python3 tools/town_palette2.py check [FILES]    -> off-palette count and colours per sprite
  python3 tools/town_palette2.py near R G B       -> the palette colour a colour maps to (for colours in code)"""
import glob
import json
import os
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab, lab2rgb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# name, hue from, hue to (Lab degrees), steps
MATS = [("red", 8, 38, 8), ("wood", 38, 62, 8), ("ochre", 62, 78, 8), ("cream", 78, 96, 8),
        ("leaf", 96, 118, 8), ("green", 118, 170, 7), ("blue", 170, 262, 6), ("violet", 262, 8, 6)]
GREYS = [("stone", 8), ("iron", 6)]       # chroma under GREY_C: warm-ish (stone) / cool-ish (iron)
GREY_C = 9.0
SHADOW_TURN = -9.0       # degrees of hue at the darkest step (toward blue-violet)
LIGHT_TURN = 10.0
MIN_DL = 6.0            # lightness gap between neighbouring steps        # at the lightest step (toward yellow)


def files():
    fs = glob.glob(os.path.join(ROOT, "assets/town/*.png")) + glob.glob(os.path.join(ROOT, "assets/town/hx/*.png"))
    keep = []
    for f in fs:
        b = os.path.basename(f)
        if b in ("palette.png", "bg_sky.png") or "_sway" in b: continue
        keep.append(f)
    return sorted(keep)


def lab(rgb):
    return rgb2lab(np.asarray(rgb, float)[None] / 255.0)[0]


def hue(L):
    return (np.degrees(np.arctan2(L[:, 2], L[:, 1])) + 360.0) % 360.0


def mat_of(L):
    """material index per Lab colour: 0..len(MATS)-1 by hue, then the greys"""
    C = np.hypot(L[:, 1], L[:, 2]); h = hue(L)
    m = np.zeros(len(L), int)
    for i, (_, a, b, _) in enumerate(MATS):
        sel = ((h >= a) & (h < b)) if a < b else ((h >= a) | (h < b))
        m[sel] = i
    # a dull reddish brown (earth, dark wood) is wood, not roof red: red needs real saturation
    m[(m == 0) & (C < 24.0)] = 1
    grey = C < GREY_C
    warm = (h < 170) | (h >= 345)
    m[grey & warm] = len(MATS)
    m[grey & ~warm] = len(MATS) + 1
    return m


def gather():
    cols, w = [], []
    for f in files():
        a = np.array(Image.open(f).convert("RGBA"))
        c = a[a[..., 3] > 127][:, :3]
        if len(c) == 0: continue
        u, n = np.unique(c, axis=0, return_counts=True)
        cols.append(u); w.append(n)
    u = np.concatenate(cols); n = np.concatenate(w).astype(float)
    u, inv = np.unique(u, axis=0, return_inverse=True)
    return u, np.bincount(inv.ravel(), weights=n)


def build():
    u, n = gather()
    L = lab(u); m = mat_of(L)
    allm = [(x[0], x[3]) for x in MATS] + list(GREYS)
    ramps, names = [], []
    W = max(s for _, s in allm)
    for i, (name, steps) in enumerate(allm):
        sel = m == i
        Ls, ws = L[sel], n[sel]
        if sel.sum() < 3:
            Ls, ws = L, n
        rep = np.repeat(np.arange(len(Ls)), np.clip((ws / ws.max() * 50).astype(int), 1, 50))
        qs = np.quantile(Ls[rep, 0], np.linspace(0.03, 0.98, steps))
        for q_ in range(1, steps):                       # every step a visible step: at least MIN_DL lighter
            qs[q_] = max(qs[q_], qs[q_ - 1] + MIN_DL)
        if qs[-1] > 97.0: qs = qs[0] + (qs - qs[0]) * (97.0 - qs[0]) / (qs[-1] - qs[0])
        out = []
        for t, q in zip(np.linspace(0, 1, steps), qs):
            near = np.abs(Ls[:, 0] - q) < 7.0
            if near.sum() < 2: near = np.argsort(np.abs(Ls[:, 0] - q))[:4]
            cw = ws[near] * (np.hypot(Ls[near, 1], Ls[near, 2]) + 1.0) ** 1.5     # saturated colours speak for the material
            a_ = np.average(Ls[near, 1], weights=cw); b_ = np.average(Ls[near, 2], weights=cw)
            C = np.hypot(a_, b_); h = np.arctan2(b_, a_)
            if i < len(MATS):
                h += np.radians(SHADOW_TURN + (LIGHT_TURN - SHADOW_TURN) * t)       # cool shadows, warm lights
                C *= 0.82 + 0.3 * np.sin(np.pi * t)                                  # saturation peaks mid-ramp
            else:
                C = min(C, GREY_C * 0.8)
                h += np.radians(-25.0 + 35.0 * t) if name == "stone" else 0.0          # stone: violet-grey shadows, warm lights
            out.append([q, C * np.cos(h), C * np.sin(h)])
        out = np.array(out)
        if i < len(MATS):                    # no washed-out step inside a coloured ramp
            Cs = np.hypot(out[:, 1], out[:, 2]); floor = 0.6 * Cs.max()
            k = np.where(Cs < floor, floor / np.maximum(Cs, 1e-3), 1.0)
            k[0] = min(k[0], 1.0) if Cs[0] > 0 else 1.0
            out[1:, 1:] *= k[1:, None]
            out[0, 1:] *= min(1.0, 0.55 * Cs[1:].mean() / max(Cs[0], 1e-3))   # the darkest step: a calm dark, not a neon one
        out[:, 0] = np.maximum.accumulate(out[:, 0] + np.arange(steps) * 1e-3)      # strictly lighter along the ramp
        rgb = np.clip(lab2rgb(out[None])[0] * 255, 0, 255).round().astype(np.uint8)
        row = np.zeros((W, 4), np.uint8); row[:steps, :3] = rgb; row[:steps, 3] = 255
        ramps.append(row); names.append(name)
    img = np.array(ramps)
    Image.fromarray(img).save(os.path.join(ROOT, "assets/town/palette.png"))
    json.dump({"names": names, "steps": [s for _, s in allm]}, open(os.path.join(ROOT, "assets/town/palette.json"), "w"))
    print("palette", sum(s for _, s in allm), "colours in", len(allm), "ramps, from", len(u))


def load():
    img = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGBA"))
    j = json.load(open(os.path.join(ROOT, "assets/town/palette.json")))
    ramps = [img[i, :s, :3] for i, s in enumerate(j["steps"])]
    return ramps, [lab(r) for r in ramps]


def mapper(ramps, rl):
    def f(cols):
        L = lab(cols); m = mat_of(L)
        out = np.empty_like(cols)
        for i in range(len(ramps)):
            sel = m == i
            if not sel.any(): continue
            j = np.abs(L[sel, 0][:, None] - rl[i][None, :, 0]).argmin(1)
            out[sel] = ramps[i][j]
        return out
    return f


def apply(fs):
    ramps, rl = load(); f = mapper(ramps, rl)
    for p in fs:
        a = np.array(Image.open(p).convert("RGBA"))
        op = a[..., 3] > 0
        if not op.any(): continue
        u, inv = np.unique(a[op][:, :3], axis=0, return_inverse=True)
        a[op, :3] = f(u)[inv.ravel()]
        Image.fromarray(a).save(p)
    print("remapped", len(fs), "files")


def check(fs):
    ramps, _ = load()
    pal = {tuple(c) for r in ramps for c in r}
    for p in fs:
        a = np.array(Image.open(p).convert("RGBA"))
        c = {tuple(x) for x in np.unique(a[a[..., 3] > 127][:, :3], axis=0)}
        print(f"{os.path.relpath(p, ROOT)}: colours {len(c)} off-palette {len(c - pal)}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "build": build()
    elif cmd == "apply": apply(sys.argv[2:] or files())
    elif cmd == "check": check(sys.argv[2:] or files())
    elif cmd == "near":
        ramps, rl = load(); print(mapper(ramps, rl)(np.array([[int(v) for v in sys.argv[2:5]]], np.uint8))[0])
    else: print(__doc__)
