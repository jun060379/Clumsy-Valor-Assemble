"""Town nature pass (owner 2026-11-06: art by the principles -- far planes recede, the play plane carries the contrast).
1. far planes: mountains and forest pulled toward the sky's horizon colour and desaturated (atmospheric perspective),
   then re-baked to hx as before.
2. ground: the grass cap made thicker (grass about a third of the top band instead of a sliver), the black top line in
   the darkest grass, the dirt muted and darkened so it recedes under the walkway.
Works from the git originals each run (idempotent). Usage: python3 tools/town_nature_pass.py"""
import subprocess, io, colorsys
import numpy as np
from PIL import Image
from rebake_town import rebake_crisp

def orig(path):
    return Image.open(io.BytesIO(subprocess.run(["git", "show", "HEAD:" + path], capture_output=True, check=True).stdout)).convert("RGBA")

def toward(a, col, k, desat):
    rgb = a[..., :3].astype(float)
    g = rgb.mean(-1, keepdims=True)
    rgb = rgb + (g - rgb) * desat
    rgb = rgb + (np.array(col, float) - rgb) * k
    a[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return a

SKY = (140, 200, 175)        # the sky near the horizon (bg_sky's lower rows, a touch lighter)

def far():
    for k, amt, des, fac in [("bg_mountains", 0.42, 0.35, 1.78), ("bg_forest", 0.24, 0.25, 1.78)]:
        a = np.array(orig(f"assets/town/{k}.png"))
        a = toward(a, SKY, amt, des)
        Image.fromarray(a).save(f"assets/town/{k}.png")
        rebake_crisp(f"assets/town/{k}.png", fac).save(f"assets/town/hx/{k}.png")

GRASS = [(150, 178, 70), (118, 152, 58), (86, 122, 52), (58, 92, 50)]     # top lit -> under edge (the trees' greens)

def ground():
    a = np.array(orig("assets/town/k_ground.png"))
    h, w = a.shape[:2]
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    green = (g > r + 10) & (al > 0)
    out = a.copy()
    for x in range(w):
        col = np.where(green[:, x])[0]
        if len(col) == 0: continue
        top, bot = col.min(), col.max()
        nb = min(h - 8, bot + 15)                         # grass reaches 15 px further down: a grassy bank, the dirt only at its foot
        for y in range(top, nb + 1):
            u = (y - top) / max(1, nb - top)
            out[y, x, :3] = GRASS[min(3, int(u * 3.2))] if y < nb else GRASS[3]
        if top > 0 and al[top - 1, x] > 0 and (r[top - 1, x] + g[top - 1, x] + b[top - 1, x]) < 90:
            out[top - 1, x, :3] = (40, 64, 42)            # the black lip in the darkest grass
    # dirt: muted, darker, toward a cool brown so it sits back
    dirt = (out[..., 3] > 0) & ~((out[..., 1].astype(int) > out[..., 0].astype(int) + 10))
    sub = out[dirt]
    sub = toward(sub[None], (74, 56, 58), 0.35, 0.3)[0]
    out[dirt] = sub
    Image.fromarray(out).save("assets/town/k_ground.png")
    for k in ["k_dirt", "k_under"]:
        a = np.array(orig(f"assets/town/{k}.png"))
        m = a[..., 3] > 0
        a[m] = toward(a[m][None], (74, 56, 58), 0.35, 0.3)[0]
        Image.fromarray(a).save(f"assets/town/{k}.png")

far()
ground()
print("done")
