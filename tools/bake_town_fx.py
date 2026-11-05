"""Bakes the town's ambient effect sheets from pixelfx renders and the town art (owner 2026-11-06).
forge_fire.png: fire/town-furnace (tools/pixelfx_fx/town-furnace.js) clipped to the forge's hearth arch (the art's own fire
pixels, largest blob), 90 frames 100x75, cols 10; drawn at the arch box (FORGE_BOX in town.gd).
rim/<k>.png: each sprite's edge pixels (alpha 255, the second row 110) with the outward normal in RG.
Usage: python3 tools/bake_town_fx.py FURNACE_SHEET.png | python3 tools/bake_town_fx.py rim"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

BOX = (80, 177, 180, 252)        # x0, y0, x1, y1 in assets/town/hx/g_forge.png

def frames(path, fw, fh, cols, n):
    im = Image.open(path).convert("RGBA")
    return [im.crop(((i % cols) * fw, (i // cols) * fh, (i % cols) * fw + fw, (i // cols) * fh + fh)) for i in range(n)]

def forge(furnace):
    a = np.array(Image.open("assets/town/hx/g_forge.png").convert("RGBA")).astype(int)
    x0, y0, x1, y1 = BOX
    c = a[y0:y1, x0:x1]
    m = (c[..., 0] > 120) & (c[..., 0] > c[..., 2] + 50) & (c[..., 3] > 0)
    lab, n = ndi.label(m)
    big = 1 + np.argmax(ndi.sum(m, lab, range(1, n + 1)))
    mask = ndi.binary_fill_holes(lab == big)
    W, H = x1 - x0, y1 - y0
    ff = frames(furnace, W, H, 9, 90)          # fire/town-furnace: 100x75, the hearth floor on its bottom row
    sheet = Image.new("RGBA", (W * 10, H * 9))
    for i in range(90):
        arr = np.array(ff[i])
        arr[..., 3] = (arr[..., 3] * mask).astype(np.uint8)
        sheet.paste(Image.fromarray(arr), ((i % 10) * W, (i // 10) * H))
    sheet.save("assets/fx/town/forge_fire.png")

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] not in ("rim", "rays", "furnace"):
    forge(sys.argv[1])


# ---------- rim normals (town_fx.gd RIM_SH): per sprite, its edge pixels with the outward normal ----------
RIM_KEYS = ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_kiln", "g_hall", "q_fountain", "g_yard", "g_ring",
            "q_barrelL", "q_barrelM", "q_barrelS", "q_bench", "q_board", "q_crateL", "q_crateS", "q_planter", "q_pot", "q_lamp_base"]

def rim(k):
    import os
    src = "assets/town/hx/%s.png" % k if os.path.exists("assets/town/hx/%s.png" % k) else "assets/town/%s.png" % k
    a = np.array(Image.open(src).convert("RGBA"))[..., 3] > 127
    h, w = a.shape
    # outward normal: the direction away from the opaque mass, from a 5x5 neighbourhood
    f = a.astype(np.float32)
    gx = ndi.sobel(ndi.uniform_filter(f, 3), axis=1)
    gy = ndi.sobel(ndi.uniform_filter(f, 3), axis=0)
    pad = np.pad(a, 1)
    edge1 = a & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    inner = a & ~edge1
    p2 = np.pad(edge1, 1)
    edge2 = inner & (p2[:-2, 1:-1] | p2[2:, 1:-1] | p2[1:-1, :-2] | p2[1:-1, 2:])
    n = np.stack([-gx, -gy], -1)
    ln = np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    n = n / ln
    out = np.zeros((h, w, 4), np.uint8)
    m = edge1 | edge2
    out[m, 0] = np.clip(n[m, 0] * 127.5 + 127.5, 0, 255)
    out[m, 1] = np.clip(n[m, 1] * 127.5 + 127.5, 0, 255)
    out[edge1, 3] = 255
    out[edge2, 3] = 110
    os.makedirs("assets/town/rim", exist_ok=True)
    Image.fromarray(out).save("assets/town/rim/%s.png" % k)

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "rim":
    for k in RIM_KEYS: rim(k)


# ---------- the big tree's sun rays (pixelfx weather/town-bigtree-rays, tools/pixelfx_fx/town-bigtree-rays.js) ----------
# 48 frames 718x513 (the tree's hx sprite plus 12 rows of ground under it), cols 6. Kept only where the tree is not
# (rays in the air under the canopy and the dapples), cropped to what is lit -> assets/fx/town/tree_rays.png + .json
def rays(sheet):
    import json
    L = np.array(Image.open("assets/town/hx/f_bigtree_leaf.png").convert("RGBA"))[..., 3] > 127
    T = np.array(Image.open("assets/town/hx/f_bigtree_trunk.png").convert("RGBA"))[..., 3] > 127
    air = np.ones((513, 718), bool)
    air[:501] = ~(L | T)
    fr = frames(sheet, 718, 513, 6, 48)
    arrs = []
    for f in fr:
        a = np.array(f)
        a[..., 3] = (a[..., 3] * air).astype(np.uint8)
        arrs.append(a)
    tot = np.max([a[..., 3] for a in arrs], axis=0) > 0
    ys, xs = np.nonzero(tot)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    W, H = int(x1 - x0), int(y1 - y0)
    sheet_o = Image.new("RGBA", (W * 6, H * 8))
    for i, a in enumerate(arrs):
        sheet_o.paste(Image.fromarray(a[y0:y1, x0:x1]), ((i % 6) * W, (i // 6) * H))
    sheet_o.save("assets/fx/town/tree_rays.png")
    json.dump({"x": int(x0), "y": int(y0) - 501, "w": W, "h": H, "cols": 6, "n": 48, "fps": 8}, open("assets/fx/town/tree_rays.json", "w"))

if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[1] == "rays":
    rays(sys.argv[2])


# ---------- the forge's furnace, painted (owner 2026-11-06: "빛이 내부에서 윤곽선으로 번지는 것과 번뜩이는 것") ----------
# Not a fire sprite: the hearth itself redrawn per frame. Inside the arch a posterized heat ramp (white-hot at the
# coal bed, through yellow and orange to a deep red back wall) whose tongues of heat crawl upward; the coals breathe;
# the light spills out over the arch: the stones around the mouth warm in hard dithered steps and their dark outlines
# pick up the glow most; twice a loop the fire flares and everything brightens for a few frames.
# 48 frames at 12 fps over the box below -> assets/fx/town/furnace.png (the mouth, emissive) and furnace_spill.png (the
# stones, under the scene light) (+ .json), drawn over the forge sprite.
FUR_BOX = (60, 150, 210, 262)
FUR_RAMP = ["#22090b", "#4a1311", "#7c1f16", "#b3331a", "#e2591e", "#ff8f2e", "#ffc04a", "#ffe58a", "#fff8d6"]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0

def _hex(c):
    return np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], np.float32)

def _vnoise(x, y, seed):
    # smooth value noise on a lattice, vectorised
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - xi, y - yi
    def h(a, b):
        v = (a * 374761393 + b * 668265263 + seed * 2246822519) & 0xFFFFFFFF
        v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
        return (v & 0xFFFF) / 65535.0
    u, v = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    return (h(xi, yi) * (1 - u) + h(xi + 1, yi) * u) * (1 - v) + (h(xi, yi + 1) * (1 - u) + h(xi + 1, yi + 1) * u) * v

def furnace():
    import json
    src = np.array(Image.open("assets/town/hx/g_forge.png").convert("RGBA")).astype(np.float32)
    x0, y0, x1, y1 = FUR_BOX
    reg = src[y0:y1, x0:x1]
    H, W = reg.shape[:2]
    # the mouth: the art's own fire pixels, largest blob, holes filled
    # the mouth: the whole opening, its dark red back ring included (reddish, not the grey-beige stone), largest blob
    c = reg
    m = (c[..., 0] - c[..., 1] > 18) & (c[..., 0] - c[..., 2] > 10) & (c[..., 3] > 0)
    lab, n = ndi.label(m)
    mouth = ndi.binary_fill_holes(lab == 1 + np.argmax(ndi.sum(m, lab, range(1, n + 1))))
    mouth = ndi.binary_opening(mouth, np.ones((2, 2)))
    ys, xs = np.nonzero(mouth)
    bot, top, cx = ys.max(), ys.min(), (xs.min() + xs.max()) / 2.0
    half = (xs.max() - xs.min()) / 2.0
    dist_out = ndi.distance_transform_edt(~mouth)            # how far a stone pixel is from the mouth
    Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
    ramp = np.array([_hex(c) for c in FUR_RAMP])
    lum = (reg[..., 0] * 3 + reg[..., 1] * 6 + reg[..., 2]) / 10.0
    opaque = reg[..., 3] > 127
    bay = BAYER[(Y.astype(int)) % 4, (X.astype(int)) % 4]
    N, fps = 48, 12
    sheet = Image.new("RGBA", (W * 8, H * 6))
    sheet2 = Image.new("RGBA", (W * 8, H * 6))          # the spill on its own: lit by the scene's own light
    for f in range(N):
        ph = f / N
        # brightness: a slow breath, a fast flutter, and two flares a loop (sharp rise, a few frames' fall)
        I = 0.84 + 0.07 * np.sin(2 * np.pi * ph * 2) + 0.05 * np.sin(2 * np.pi * ph * 7 + 1.3)
        for fl in (0.18, 0.64):
            d = (ph - fl) % 1.0
            if d < 0.12: I += 0.32 * (1 - d / 0.12) ** 2
        out = np.zeros((H, W, 4), np.float32)
        # inside: heat falls off from the coal bed upward and toward the sides; tongues of it crawl up the back wall
        rel_y = (bot - Y) / max(1.0, bot - top)               # 0 at the coals, 1 at the crown
        rel_x = np.abs(X - cx) / max(1.0, half)
        crawl = _vnoise(X / 6.0, (Y + ph * 2 * 24) / 6.0, 7) * 0.7 + _vnoise(X / 3.0, (Y + ph * 4 * 24) / 3.0, 9) * 0.3
        edge_in = ndi.distance_transform_edt(mouth)
        heat = I * (1.2 - rel_y * 0.9 - rel_x * 0.5) + (crawl - 0.5) * 0.45 * (0.3 + rel_y)
        heat = heat - np.clip(3.0 - edge_in, 0, 3) * 0.12           # the back ring darkens toward the stone
        # the coal bed: the bottom rows, lumps breathing on their own clocks
        bed = (bot - Y) < 5
        lump = _vnoise(X / 2.2, Y / 1.6 + 30, 3)
        heat = np.where(bed, I * (0.95 + 0.3 * np.sin(2 * np.pi * (ph * 3 + lump * 2))) - (Y < bot - 3) * 0.1, heat)
        lv = np.clip(heat * 8.0 + (bay - 0.5) * 0.28, 0, 8).astype(int)
        inside = mouth
        out[inside, :3] = ramp[lv[inside]]
        out[inside, 3] = 255
        # the spill: stones within reach of the mouth warm in hard steps (dithered), outlines and the mouth's own rim most
        reach = 22.0 * (0.85 + 0.35 * (I - 0.84))
        s = np.clip(1.0 - dist_out / reach, 0, 1) ** 1.3 * I * 1.15
        s = np.where(lum < 75, s * 1.5, s)                     # dark outline pixels take the glow
        s = np.where(dist_out <= 1.5, s * 1.3, s)               # the rim of the mouth
        st = np.floor(np.clip(s * 4 + bay - 0.5, 0, 4)) / 4.0    # four hard steps
        warm = np.array([255, 128, 40], np.float32)
        spill = opaque & ~inside & (st > 0)
        base = reg[..., :3]
        col = base * (1 - 0.4 * st[..., None]) + warm * (0.8 * st[..., None])
        col = np.where((st >= 0.75)[..., None] & (lum[..., None] < 75), _hex("#ff9a3a") * 0.9, col)
        out2 = np.zeros((H, W, 4), np.float32)
        out2[spill, :3] = np.clip(col[spill], 0, 255)
        out2[spill, 3] = 255
        sheet.paste(Image.fromarray(out.astype(np.uint8)), ((f % 8) * W, (f // 8) * H))
        sheet2.paste(Image.fromarray(out2.astype(np.uint8)), ((f % 8) * W, (f // 8) * H))
    sheet.save("assets/fx/town/furnace.png")
    sheet2.save("assets/fx/town/furnace_spill.png")
    json.dump({"x": x0, "y": y0, "w": W, "h": H, "cols": 8, "n": N, "fps": fps}, open("assets/fx/town/furnace.json", "w"))

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "furnace":
    furnace()
