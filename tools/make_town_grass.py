#!/usr/bin/env python3
# python3 tools/make_town_grass.py SHEET.png OUTDIR [set]   (set: "a" the first sheet, "b" the chunky grass sheet)
# The town's grass and bushes remade (owner 2026-11-08: "덤풀이랑 풀은 다시 뽑는 게 나을듯", method "생성해서 가공"):
# a generated 3x3 vegetation sheet (not kept in the repo: AI originals stay out) cut into its nine pieces, each
# brought down to the town's 2-px cell grid at a set width, its colours ranked by brightness and moved onto ONE
# material ramp of assets/town/palette.png in that order (never "the nearest colour"), 4-5 colours a piece, no outline
# on the grass (it shares the lawn's ramp), then doubled to game pixels.
import sys, os, json
import numpy as np
from PIL import Image

SHEET, OUT = sys.argv[1], sys.argv[2]
SET = sys.argv[3] if len(sys.argv) > 3 else "a"
os.makedirs(OUT, exist_ok=True)
P = np.array(Image.open(os.path.join(os.path.dirname(__file__), "..", "assets/town/palette.png")).convert("RGB")).astype(int)
ramp = lambda r, idx: [tuple(P[r, i]) for i in idx]
LAWN = ramp(4, [2, 3, 5, 7])               # the lawn's own olive ramp (k_lawn, the blades): a dark root to the light tips
BUSH = ramp(5, [2, 3, 5]) + ramp(4, [6])     # the old bushes' cool greens, the lawn's light on top
BUSH_LINE = tuple(P[5, 0])                   # a bush's 1-cell outline: its body's darkest (grass has none)
# [name, cell (row, col), width in cells, colours from the ramp (dark -> light)]
PIECES = [
    ["g_tuft_s", (0, 0), 16, LAWN],
    ["g_tuft_m", (0, 1), 26, LAWN],
    ["g_tuft_tall", (0, 2), 30, LAWN],
    ["g_strip", (1, 0), 60, LAWN],
    ["g_flower", (1, 1), 26, LAWN],
    ["b_bush_s", (1, 2), 34, BUSH],
    ["b_bush_m", (2, 0), 42, BUSH],
    ["b_bush_l", (2, 1), 58, BUSH],
    ["g_fern", (2, 2), 38, LAWN],
]
if SET == "b":
    PIECES = [
        ["g_tuft_1", (0, 0), 18, LAWN], ["g_tuft_2", (0, 1), 24, LAWN], ["g_tuft_tall", (0, 2), 30, LAWN],
        ["g_strip", (1, 0), 48, LAWN], ["g_clover", (1, 1), 26, LAWN], ["g_daisy", (1, 2), 26, LAWN],
        ["g_cattail", (2, 0), 26, LAWN], ["g_sprout", (2, 1), 22, LAWN], ["g_tuft_wind", (2, 2), 30, LAWN],
    ]
# the few colours that are not leaf: petals, hearts, seed heads (kept as their own palette steps)
ACCENT = {"white": tuple(P[3, 7]), "yellow": tuple(P[3, 4]), "tan": tuple(P[2, 3]), "tan_d": tuple(P[2, 1])}

src = np.array(Image.open(SHEET).convert("RGBA")).astype(float)
C = src.shape[0] // 3


def lum(c): return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def hsv(rgb):
    r, g, b = rgb[..., 0] / 255, rgb[..., 1] / 255, rgb[..., 2] / 255
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, d / (mx + 1e-6), mx


info = {}
for name, (r, c), wc, cols in PIECES:
    cell = src[r * C:(r + 1) * C, c * C:(c + 1) * C]
    m = cell[..., 3] > 128
    ys, xs = np.where(m)
    cell = cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h0, w0 = cell.shape[:2]
    hc = max(1, round(h0 * wc / w0))
    # area average on premultiplied colour: each cell the mean of its block; kept where it is more than half covered
    a = cell[..., 3:4] / 255.0
    pre = np.concatenate([cell[..., :3] * a, a], 2)
    im = Image.fromarray(np.clip(pre[..., :3], 0, 255).astype(np.uint8))
    am = Image.fromarray((a[..., 0] * 255).astype(np.uint8))
    rgb = np.array(im.resize((wc, hc), Image.BOX)).astype(float)
    al = np.array(am.resize((wc, hc), Image.BOX)).astype(float) / 255.0
    keep = al > 0.5
    rgb = rgb / np.maximum(al[..., None], 1e-3)
    out = np.zeros((hc, wc, 4), np.uint8)
    H, S, V = hsv(rgb)
    # accents: low saturation and bright (petals), warm hue (yellow hearts, seed heads)
    white = keep & (S < 0.22) & (V > 0.75)
    warm = keep & ~white & (H > 20) & (H < 62) & (S > 0.35)
    leaf = keep & ~white & ~warm
    # leaf colours: brightness ranks -> the ramp, in order (quantiles: equal share per step, darkest the fewest)
    L = lum(np.moveaxis(rgb, -1, 0))
    v = L[leaf]
    n = len(cols)
    w = np.array([0.6] + [1.0] * (n - 1)); w = np.cumsum(w) / w.sum()
    cuts = np.quantile(v, w[:-1]) if len(v) else []
    k = np.searchsorted(cuts, L)
    for i in range(n):
        out[leaf & (k == i), :3] = cols[i]
    out[white, :3] = ACCENT["white"]
    if warm.any():
        fl = name in ("g_flower", "g_daisy")
        hi = (V[warm] > 0.7) if fl else (L[warm] > np.median(L[warm]))
        if name == "g_cattail": a_hi, a_lo = tuple(P[1, 4]), tuple(P[1, 2])     # the heads: the wood ramp's browns
        elif fl: a_hi, a_lo = ACCENT["yellow"], ACCENT["tan"]
        else: a_hi, a_lo = ACCENT["tan"], ACCENT["tan_d"]
        out[warm, :3] = np.where(hi[:, None], a_hi, a_lo)
    out[keep, 3] = 255
    # lone cells (one cell with no neighbour of its colour) are noise: take the colour most of its neighbours have
    for y in range(hc):
        for x in range(wc):
            if not keep[y, x]: continue
            nb = [tuple(out[yy, xx, :3]) for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
                  if 0 <= yy < hc and 0 <= xx < wc and keep[yy, xx]]
            me = tuple(out[y, x, :3])
            if nb and me not in nb and not (white[y, x] or warm[y, x]):
                out[y, x, :3] = max(set(nb), key=nb.count)
    if name.startswith("b_"):
        # the outline: every empty cell beside the body (4-neighbour), in the body's darkest
        pad = np.pad(keep, 1)
        ring = ~pad[1:-1, 1:-1] & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
        out2 = np.zeros((hc + 1, wc + 2, 4), np.uint8)      # room for the ring at the sides and top
        out2[1:, 1:-1] = out
        k2 = np.zeros((hc + 1, wc + 2), bool); k2[1:, 1:-1] = keep
        p2 = np.pad(k2, 1)
        ring = ~k2 & (p2[:-2, 1:-1] | p2[2:, 1:-1] | p2[1:-1, :-2] | p2[1:-1, 2:])
        ring[-1, :] &= False                                   # the foot stays open on the ground
        out2[ring, :3] = BUSH_LINE; out2[ring, 3] = 255
        out, keep = out2, k2 | ring
        hc, wc = out.shape[:2]
    big = out.repeat(2, 0).repeat(2, 1)
    Image.fromarray(big).save(os.path.join(OUT, name + ".png"))
    info[name] = {"w": wc * 2, "h": hc * 2, "colours": len({tuple(p) for p in out[keep][:, :3]})}
json.dump(info, open(os.path.join(OUT, "pieces.json"), "w"), indent=1)
print(json.dumps(info))
