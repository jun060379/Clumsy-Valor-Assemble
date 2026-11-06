"""Town ground plane + nature pieces, all on ONE palette (owner 2026-11-06: decorations looked pasted on because their
palette differed from the ground's and their outlines were too dark -> one shared palette, no outlines on decorations).
Sources (AI, kept out of the repo): the cleaned high-contrast scene (unfake, 1 px grid) and the pieces cut from it,
plus the code-drawn shrub frames. All are quantized together with the town trees' colours to NPAL colours.
Writes assets/town/k_lawn.png, k_clear.png (+ k_clear_cap.png), f2_<piece>.png.
Usage: python3 tools/make_town_ground2.py SCENE_HC.png PIECES_DIR SHRUB_DIR"""
import sys
import numpy as np
from PIL import Image
from skimage.color import rgb2lab
from scipy.cluster.vq import kmeans2

NPAL = 40
scene = np.array(Image.open(sys.argv[1]).convert("RGBA"))
pdir, bdir = sys.argv[2], sys.argv[3]

def strip(x0, x1, y0=282, y1=383):
    a = scene[y0:y1, x0:x1].copy()
    # the sky/forest showing between blade tips on the top rows -> clear
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    sky = (b > g - 6) & (b > r + 10)
    sky[8:] = False
    a[sky, 3] = 0
    return np.concatenate([a, a[:, ::-1]], 1)

lawn = strip(540, 600)
# stray grey specks on the lawn surface -> that row's main green (they would repeat with the tile)
# and any blotch that would mirror into a diamond: each surface row keeps its main colour only (calm, simple stretch)
for y in range(3, 28):
    row = lawn[y]; m = row[:, 3] > 0
    if not m.any(): continue
    cols, cnt = np.unique(row[m][:, :3], axis=0, return_counts=True)
    keep = cols[np.argsort(-cnt)[:1]]
    bad = m & ~np.any(np.all(row[:, None, :3] == keep[None], -1), 1)
    row[bad, :3] = keep[0]
clear = strip(290, 395)
# dark specks on the clearing (they read as dirt marks and repeat with the tile) -> that row's main colour
for y in range(3, 28):
    row = clear[y]; m = row[:, 3] > 0
    if not m.any(): continue
    cols, cnt = np.unique(row[m][:, :3], axis=0, return_counts=True)
    main = cols[cnt.argmax()]; lum = row[:, :3].astype(int).sum(1)
    row[m & (lum < main.astype(int).sum() - 70), :3] = main
cap = scene[282:383, 252:290].copy()
r, g, b = [cap[..., i].astype(int) for i in range(3)]
sky = (b > g - 6) & (b > r + 10); sky[8:] = False; cap[sky, 3] = 0

names = []     # decorations dropped (owner 2026-11-06): the code blades do that job
pieces = {n: np.array(Image.open(f"{pdir}/f_{n}.png").convert("RGBA")) for n in names}
shrubs = []
oak = np.array(Image.open("assets/town/f_oak.png").convert("RGBA"))

arrs = [lawn, clear, cap] + list(pieces.values()) + shrubs
cols = np.concatenate([a[a[..., 3] > 0][:, :3] for a in arrs + [oak]])
u, inv = np.unique(cols, axis=0, return_inverse=True)
cnt = np.bincount(inv.ravel())
lab = rgb2lab(u[None].astype(float) / 255)[0]
cent, _ = kmeans2(lab[np.repeat(np.arange(len(u)), np.minimum(cnt, 300))], NPAL, minit="++", seed=7, iter=40)
pal = u[[((lab - c) ** 2).sum(1).argmin() for c in cent]]
pl = rgb2lab(pal[None].astype(float) / 255)[0]
lut = {tuple(c): pal[((pl - l) ** 2).sum(1).argmin()] for c, l in zip(map(tuple, u), lab)}
for a in arrs:
    m = a[..., 3] > 0
    a[m, :3] = np.array([lut[tuple(c)] for c in a[m][:, :3]])
    a[..., 3] = np.where(m, 255, 0)

# the turf lip (owner 2026-11-06): where the top is lawn, the grass runs a little way down over the edge of the earth
# face -- a ragged green band of a few rows under the corner, then the brown earth as before; none under the clearing
LIP = [(112, 134, 57), (88, 108, 50)]
def lip(a, seed):
    rng = np.random.default_rng(seed)
    h, w = a.shape[:2]
    top = 28
    for x in range(w):
        d = int(5 + 2.5 * np.sin(x * 0.21 + seed) + 1.5 * np.sin(x * 0.67 + 2 * seed) + rng.integers(0, 2))
        for y in range(top, min(h, top + d)):
            a[y, x, :3] = LIP[0] if y < top + d - 1 else LIP[1]
    return a
lawn = np.tile(lawn, (1, 8, 1))
def ragged(a, seed, y0=3, y1=28):
    """the flat colour bands of the top become ragged: each band edge wanders a pixel or two along x (no straight
    stripes); the tile stays seamless (period divides the width)"""
    h, w = a.shape[:2]
    src = a.copy()
    rng = np.random.default_rng(seed)
    for y in range(y0 + 1, y1):
        if (src[y, :, :3] == src[y - 1, :, :3]).all(): continue      # not a band edge
        ph = rng.uniform(0, 6.28)
        for x in range(w):
            o = int(round(1.2 * np.sin(2 * np.pi * x / w * 24 + ph) + 0.9 * np.sin(2 * np.pi * x / w * 61 + 2 * ph)))
            if o > 0 and y + o < y1: a[y:y + o, x] = src[y - 1, x]
            elif o < 0 and y + o > y0: a[y + o:y, x] = src[y, x]
    return a
lawn = ragged(lawn, 4)      # the turf lip is drawn at run time (town.gd), from noise: it never repeats
clear = np.tile(clear, (1, 4, 1))
# the grass bits baked into the clearing would repeat at a fixed beat over a long path: painted out (the runtime weeds
# and rim blades do that job, placed by noise)
for y in range(0, 29):
    row = clear[y]; m = row[:, 3] > 0
    if not m.any(): continue
    gr = m & (row[:, 1].astype(int) > row[:, 0].astype(int) + 6)
    dirt = m & ~gr
    if dirt.any():
        cols, cnt = np.unique(row[dirt][:, :3], axis=0, return_counts=True)
        row[gr, :3] = cols[cnt.argmax()]
    elif y < 6:
        row[gr, 3] = 0
clear = ragged(clear, 6)
clear[:5, :, 3] = 0          # the strip of curb/stone the scene had above the dirt: off (it read as a grey line on the slopes)
Image.fromarray(lawn).save("assets/town/k_lawn.png")
Image.fromarray(clear).save("assets/town/k_clear.png")
Image.fromarray(cap).save("assets/town/k_clear_cap.png")
for n, a in pieces.items(): Image.fromarray(a).save(f"assets/town/f2_{n}.png")
print("palette", len(set(map(tuple, pal))), "lawn", lawn.shape, "clear", clear.shape)
