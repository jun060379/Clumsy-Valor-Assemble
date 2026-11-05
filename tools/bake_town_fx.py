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

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] not in ("rim", "rays"):
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
