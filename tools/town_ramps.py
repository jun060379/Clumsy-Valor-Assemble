#!/usr/bin/env python3
"""One town palette as material ramps (owner 2026-11-06, MGD EP14 "AI 아트 색 맞추는 법"): every colour of the town
art is grouped by material (hue/chroma: wood, roof red, foliage, stone, cloth, ...), each group a ramp dark -> light
of a few steps. Remapping keeps a pixel in ITS ramp and moves it by brightness order -- never "the nearest colour
anywhere" (a pot's brown shadow must not turn into a leaf's green shadow).
  python3 tools/town_ramps.py build          -> assets/town/ramps.png (row = ramp, column = step) + ramps.json
  python3 tools/town_ramps.py apply FILES... -> each file remapped in place onto the ramps (+ reports colours/object)
  python3 tools/town_ramps.py check FILES... -> off-palette count and colours per object (numbers, no changes)
The ramps PNG is also the lighting LUT (shaders/town_lit.gdshader): light moves a pixel along its ramp."""
import glob
import json
import os
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab, lab2rgb
from scipy.cluster.vq import kmeans2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NG = 11            # material groups
STEPS = 7          # steps per ramp (dark -> light)
NEUTRAL_C = 9.0    # chroma under this -> the neutral (stone / iron) group


def sources():
    fs = glob.glob(os.path.join(ROOT, "assets/town/*.png")) + glob.glob(os.path.join(ROOT, "assets/town/hx/*.png"))
    out = []
    for f in fs:
        b = os.path.basename(f)
        if b.startswith("bg_") or "_sway" in b or b in ("ramps.png",) or "rim" in f: continue
        out.append(f)
    return sorted(out)


def lab_of(rgb):
    return rgb2lab(rgb[None].astype(float) / 255.0)[0]


def build():
    cols, w = [], []
    for f in sources():
        a = np.array(Image.open(f).convert("RGBA"))
        c = a[a[..., 3] > 127][:, :3]
        if len(c) == 0: continue
        u, n = np.unique(c, axis=0, return_counts=True)
        cols.append(u); w.append(n)
    u = np.concatenate(cols); n = np.concatenate(w)
    u, inv = np.unique(u, axis=0, return_inverse=True)
    n = np.bincount(inv.ravel(), weights=n)
    L = lab_of(u)
    C = np.hypot(L[:, 1], L[:, 2])
    neutral = C < NEUTRAL_C
    # hue groups on the chromatic colours (a*, b* direction and strength), weighted by use
    ch = ~neutral
    ab = L[ch][:, 1:]
    rep = np.repeat(np.arange(ch.sum()), np.clip((n[ch] / n[ch].max() * 40).astype(int), 1, 40))
    cent, _ = kmeans2(ab[rep], NG - 1, minit="++", seed=5, iter=60)
    groups = [cent[i] for i in range(len(cent))]
    ramps = []
    def ramp(sel):
        Ls = L[sel][:, 0]; ww = n[sel]
        qs = np.quantile(np.repeat(Ls, np.clip((ww / ww.max() * 30).astype(int), 1, 30)), np.linspace(0.04, 0.96, STEPS))
        steps = []
        for q in qs:
            k = np.argsort(np.abs(Ls - q))[:max(3, sel.sum() // STEPS)]
            m = (L[sel][k] * ww[k, None]).sum(0) / ww[k].sum()
            m[0] = q
            steps.append(m)
        return np.array(steps)
    lab_g = np.full(len(u), -1)
    d = ((L[ch][:, None, 1:] - cent[None]) ** 2).sum(-1)
    lab_g[np.where(ch)[0]] = d.argmin(1)
    lab_g[neutral] = NG - 1
    for g in range(NG):
        sel = lab_g == g
        if sel.sum() < 2: sel = np.ones(len(u), bool)
        ramps.append(ramp(sel))
    ramps = np.array(ramps)                                   # NG x STEPS x 3 (Lab)
    rgb = np.clip(lab2rgb(ramps) * 255, 0, 255).round().astype(np.uint8)
    Image.fromarray(rgb).save(os.path.join(ROOT, "assets/town/ramps.png"))
    json.dump({"groups_ab": [list(map(float, c)) for c in cent], "neutral_c": NEUTRAL_C, "steps": STEPS,
               "ramps_lab": ramps.tolist()}, open(os.path.join(ROOT, "assets/town/ramps.json"), "w"), indent=0)
    print("ramps", ramps.shape, "from", len(u), "colours")


def load():
    j = json.load(open(os.path.join(ROOT, "assets/town/ramps.json")))
    return np.array(j["groups_ab"]), j["neutral_c"], np.array(j["ramps_lab"])


def assign(rgb, cent, nc, ramps):
    """rgb N x 3 -> (group, step) per colour: the material by hue (neutral by low chroma), the step by lightness in it"""
    L = lab_of(rgb)
    C = np.hypot(L[:, 1], L[:, 2])
    # the group: nearest hue centre; a near-neutral colour goes to the neutral ramp. Judged on the ramp colours' own
    # chroma so a dark wood brown stays wood
    g = ((L[:, None, 1:] - cent[None]) ** 2).sum(-1).argmin(1)
    g[C < nc] = len(ramps) - 1
    s = np.abs(L[:, None, 0] - ramps[g][:, :, 0]).argmin(1)
    return g, s


def apply(files):
    cent, nc, ramps = load()
    rgb = np.array(Image.open(os.path.join(ROOT, "assets/town/ramps.png")).convert("RGB"))
    for f in files:
        a = np.array(Image.open(f).convert("RGBA"))
        m = a[..., 3] > 127
        u, inv = np.unique(a[m][:, :3], axis=0, return_inverse=True)
        g, s = assign(u, cent, nc, ramps)
        a[m, :3] = rgb[g, s][inv.ravel()]
        Image.fromarray(a).save(f)
        print(os.path.relpath(f, ROOT), "colours", len(np.unique(a[m][:, :3], axis=0)))


def check(files):
    rgb = np.array(Image.open(os.path.join(ROOT, "assets/town/ramps.png")).convert("RGB")).reshape(-1, 3)
    pal = {tuple(c) for c in rgb}
    for f in files:
        a = np.array(Image.open(f).convert("RGBA"))
        c = a[a[..., 3] > 127][:, :3]
        u = {tuple(x) for x in np.unique(c, axis=0)}
        print(os.path.relpath(f, ROOT), "colours", len(u), "off-palette", len(u - pal))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "build": build()
    elif cmd == "apply": apply(sys.argv[2:])
    elif cmd == "check": check(sys.argv[2:])
    else: print(__doc__)
