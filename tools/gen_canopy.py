"""The big tree's canopy, redrawn (owner 2026-11-06: "기존 스프라이트에서 나뭇잎을 다 걷어내고 새로 찍기").
The trunk and branches stay the art's own (its brown pixels and their outline); the leaves become separate clumps,
drawn here pixel by pixel the pixelfx way: a domed mass of leaf clusters lit from the upper left in hard ramp steps,
each cluster a small scallop with its own lit top and shaded underside, a 1-px dark outline, back clumps a step
darker. The clumps cover the old canopy's footprint but leave real gaps, so the sun can come through.
-> assets/town/canopy/bigtree_branches.png, bigtree_clumps.png (atlas) + bigtree.json (each clump's rect in the
atlas, its place on the tree, its layer and sway phase; the gaps). Usage: python3 tools/gen_canopy.py [seed]"""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 7
rng = np.random.default_rng(SEED)
HEX = lambda c: np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], np.uint8)
# the art's own greens, plus two lit steps above them; the outline is the art's dark purple
RAMP = [HEX(c) for c in ["#2c4136", "#38533f", "#4b6741", "#5e7843", "#798e51", "#a9b961", "#c8d27a", "#e2e6a0"]]
OUT = HEX("#2b1f30")
LIGHT = np.array([-0.62, -0.72, 0.55]); LIGHT /= np.linalg.norm(LIGHT)

trunk = np.array(Image.open("assets/town/hx/f_bigtree_trunk.png").convert("RGBA"))
leaf = np.array(Image.open("assets/town/hx/f_bigtree_leaf.png").convert("RGBA"))
H, W = trunk.shape[:2]

# ---- branches: the brown pixels and the outline that touches them ----
r, g, b, a = [trunk[..., i].astype(int) for i in range(4)]
brown = (a > 127) & (r > g + 12) & (r > b) & ~((r < 70) & (g < 50) & (b > 40))
outl = (a > 127) & (r < 70) & (g < 50)
near = ndi.binary_dilation(brown, np.ones((3, 3)))
keep = brown | (outl & near)
branches = trunk.copy()
branches[~keep, 3] = 0
Image.fromarray(branches).save("assets/town/canopy/bigtree_branches.png")

# ---- where the canopy was ----
foot = (leaf[..., 3] > 127) | ((a > 127) & ~keep)
foot = ndi.binary_closing(foot, np.ones((5, 5)))

# ---- clump centres: spread over the footprint, bigger at the crown, a few left out for gaps ----
ys, xs = np.nonzero(foot)
cands = []
tries = 0
while len(cands) < 60 and tries < 20000:
    tries += 1
    i = rng.integers(len(xs))
    x, y = xs[i], ys[i]
    if y > H * 0.78: continue
    rad = 30 + 16 * (1 - y / H) + rng.uniform(-5, 5)
    if any((x - cx) ** 2 + (y - cy) ** 2 < (0.62 * (rad + cr)) ** 2 for cx, cy, cr in cands): continue
    cands.append((int(x), int(y), float(rad)))
# gaps: drop clumps whose removal opens the canopy low and in the middle-outer bands (light comes through there)
cands.sort(key=lambda c: c[1])
gaps = []
lowband = [c for c in cands if c[1] > H * 0.42 and abs(c[0] - W / 2) > W * 0.12]
rng.shuffle(lowband)
for c in lowband[:5]:
    cands.remove(c)
    gaps.append(c)

def cluster_dome(w, h, ox, oy, rad):
    """one clump: height field from a dome of leaf clusters, with a scalloped outline"""
    Y, X = np.mgrid[0:h, 0:w].astype(np.float32)
    hgt = np.zeros((h, w), np.float32)
    # the big dome
    d = np.sqrt(((X - ox) / rad) ** 2 + ((Y - oy) / (rad * 0.78)) ** 2)
    hgt = np.maximum(hgt, np.sqrt(np.clip(1 - d * d, 0, 1)) * 0.6)
    # leaf clusters: small bumps over the dome, denser on top; along the rim they make the scallop
    n = int(rad * 2.6)
    for k in range(n):
        ang = rng.uniform(0, 2 * np.pi)
        rr = rad * np.sqrt(rng.uniform(0.0, 1.0)) * 0.98
        cx, cy = ox + np.cos(ang) * rr, oy + np.sin(ang) * rr * 0.78
        cr = rng.uniform(5.0, 8.5)
        dd = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / cr
        bump = np.sqrt(np.clip(1 - dd * dd, 0, 1)) * 0.42
        base = np.sqrt(np.clip(1 - (((cx - ox) / rad) ** 2 + ((cy - oy) / (rad * 0.78)) ** 2), 0, 1)) * 0.6
        hgt = np.maximum(hgt, np.where(dd < 1, base * 0.85 + bump, 0))
    return hgt

def shade_clump(hgt, back):
    m = hgt > 0.08
    m = ndi.binary_opening(m, np.ones((2, 2)))
    gy, gx = np.gradient(ndi.gaussian_filter(hgt, 0.6))
    nrm = np.stack([-gx * 5, -gy * 5, np.ones_like(hgt)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    lit = nrm @ LIGHT
    # self shadow low in the clump, ambient occlusion in the creases between clusters
    ao = ndi.gaussian_filter(hgt, 2.0) - hgt
    v = lit * 0.9 + hgt * 0.5 - np.clip(ao, 0, 1) * 1.6
    v = v - (0.55 if back else 0.0)
    q = np.clip(((v + 0.25) / 1.25) * 7.0, 0, 7)
    lv = np.floor(q).astype(int)
    img = np.zeros(hgt.shape + (4,), np.uint8)
    img[m, :3] = np.array(RAMP)[lv[m]]
    img[m, 3] = 255
    # the outline: 1 px, dark; on the lit upper-left rim a ramp step instead, the way the art does it
    pad = np.pad(m, 1)
    edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    outer = ndi.binary_dilation(m, np.ones((3, 3))) & ~m
    img[outer, :3] = OUT
    img[outer, 3] = 255
    return img

clumps = []
for x, y, rad in cands:
    back = y > H * 0.5 and abs(x - W / 2) < W * 0.3 or rng.uniform() < 0.25
    w, h = int(rad * 2 + 20), int(rad * 1.6 + 20)
    hgt = cluster_dome(w, h, w / 2, h / 2, rad)
    img = shade_clump(hgt, back)
    clumps.append({"img": img, "x": x - w // 2, "y": y - h // 2, "back": bool(back), "ph": float(rng.uniform(0, 6.28))})
# back clumps first, then front from the bottom up (higher clumps overlap lower ones)
clumps.sort(key=lambda c: (not c["back"], -c["y"]))

# ---- atlas ----
pad = 1
atlas_w = 1024
x = y = rowh = 0
for c in clumps:
    h, w = c["img"].shape[:2]
    if x + w > atlas_w: x, y, rowh = 0, y + rowh + pad, 0
    c["ax"], c["ay"] = x, y
    x += w + pad
    rowh = max(rowh, h)
atlas = np.zeros((y + rowh, atlas_w, 4), np.uint8)
for c in clumps:
    h, w = c["img"].shape[:2]
    atlas[c["ay"]:c["ay"] + h, c["ax"]:c["ax"] + w] = c["img"]
Image.fromarray(atlas).save("assets/town/canopy/bigtree_clumps.png")
json.dump({"clumps": [[c["ax"], c["ay"], int(c["img"].shape[1]), int(c["img"].shape[0]), int(c["x"]), int(c["y"]), c["back"], round(c["ph"], 3)] for c in clumps],
           "gaps": [[int(g[0]), int(g[1]), round(g[2], 1)] for g in gaps], "size": [W, H]}, open("assets/town/canopy/bigtree.json", "w"))

# preview
pv = np.zeros((H, W, 4), np.uint8); pv[...] = (126, 178, 156, 255)
def over(dst, src, ox, oy):
    h, w = src.shape[:2]
    x0, y0 = max(0, ox), max(0, oy); x1, y1 = min(dst.shape[1], ox + w), min(dst.shape[0], oy + h)
    s = src[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    m = s[..., 3] > 127
    dst[y0:y1, x0:x1][m] = s[m]
over(pv, branches, 0, 0)
for c in clumps: over(pv, c["img"], c["x"], c["y"])
Image.fromarray(pv).save(sys.argv[2] if len(sys.argv) > 2 else "/tmp/canopy_preview.png")
print(len(clumps), "clumps,", len(gaps), "gaps")
