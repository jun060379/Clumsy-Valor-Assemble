#!/usr/bin/env python3
"""Rebuild the town's 1.35x sprites on the 2-px grid (owner 2026-11-06: the blown-up buildings broke into 2-3 px
pixels). The 1x originals sit on the 2-px grid; each is read at its native resolution (one value per 2x2 block),
resampled 1.35x (Lanczos on premultiplied colour), every pixel snapped back to the original's own palette, cleaned
(refine_dot), and doubled -> assets/town/hx/<k>.png at the old hx size. Same design, same size, so door positions,
climb tops and effect boxes still line up.
  python3 tools/art_loop/rescale_dot.py [names...]     (default: every BIGK sprite)"""
import os
import subprocess
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BS = 1.35
DEFAULT = ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_anvil", "g_kiln", "g_hall",
           "g_hall_win", "q_fountain", "f_bush1", "f_bush2", "f_bush3"]


def offset(a):
    best = (0, 0, -1)
    for oy in (0, 1):
        for ox in (0, 1):
            b = a[oy:, ox:]
            h, w = (b.shape[0] // 2) * 2, (b.shape[1] // 2) * 2
            r = b[:h, :w].reshape(h // 2, 2, w // 2, 2, 4)
            same = (r == r[:, :1, :, :1]).all(axis=(1, 3, 4))
            op = r[:, 0, :, 0, 3] > 127
            f = same[op].mean() if op.any() else 0
            if f > best[2]: best = (oy, ox, f)
    return best[:2]


def one(k):
    src = os.path.join(ROOT, "assets/town", k + ".png")
    a = np.array(Image.open(src).convert("RGBA"))
    oy, ox = offset(a)
    nat = a[oy::2, ox::2]
    hxp = os.path.join(ROOT, "assets/town/hx", k + ".png")
    if os.path.exists(hxp):
        hw, hh = Image.open(hxp).size
    else:
        hw, hh = round(a.shape[1] * BS), round(a.shape[0] * BS)
    W, H = max(1, round(hw / 2)), max(1, round(hh / 2))
    soft = ((a[..., 3] > 0) & (a[..., 3] < 255)).mean() > 0.02          # a glow layer (g_hall_win): keep its alpha
    f = nat.astype(float)
    al = f[..., 3:] / 255
    up = np.array(Image.fromarray(np.uint8(np.clip(f[..., :3] * al, 0, 255))).resize((W, H), Image.LANCZOS)).astype(float)
    ua = np.array(Image.fromarray(nat[..., 3]).resize((W, H), Image.LANCZOS)).astype(float) / 255
    col = up / np.maximum(ua[..., None], 1e-3)
    op = ua > (0.02 if soft else 0.5)
    pal = np.unique(nat[nat[..., 3] > 127][:, :3], axis=0).astype(float)
    out = np.zeros((H, W, 4), np.uint8)
    for y0 in range(0, H, 64):                                           # nearest palette colour, in strips
        c = col[y0:y0 + 64]
        d = ((c[:, :, None, :] - pal[None, None]) ** 2).sum(-1)
        out[y0:y0 + 64, :, :3] = pal[d.argmin(-1)].astype(np.uint8)
    out[..., 3] = np.where(op, np.clip(ua * 255, 0, 255) if soft else 255, 0).astype(np.uint8)
    tmp = os.path.join(ROOT, "assets/town/hx", f".{k}_nat.png")
    Image.fromarray(out).save(tmp)
    if not soft:
        subprocess.run([sys.executable, os.path.join(ROOT, "tools/art_loop/refine_dot.py"), tmp], check=True, capture_output=True)
    im = Image.open(tmp)
    im.resize((W * 2, H * 2), Image.NEAREST).save(hxp)
    os.remove(tmp)
    print(k, "native", (W, H), "->", (W * 2, H * 2), "(was", (hw, hh), ")", "glow" if soft else "")


for k in (sys.argv[1:] or DEFAULT): one(k)
