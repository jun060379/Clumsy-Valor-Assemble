#!/usr/bin/env python3
"""The town's ground plane, drawn in code on the 2-px grid from the map palette's material ramps (owner 2026-11-08:
"래퍼런스 찾아서 제작하기"; replaces the AI-scene tiles of make_town_ground2.py for the top of the ground).

The plane is what shows of the street's surface: 54 px (27 cells) from its back edge, 42 px behind the people's stand
line, to the front lip. The camera looks down a little (pixel3d K 0.12), so whatever lies on the ground is flattened:
tufts, worn patches, ruts, pebbles and cobbles are wide and low. Detail is calm - clumps and lines of 2+ cells, no
lone dots (owner 2026-11-06: "잔털같은 너무 짧은 풀은 굳이 넣으면 난잡해보임"); the runtime blades do the tall grass.

Each strip is as long as the town (no repeat), with the earth face under it kept from the old tile:
  assets/town/k_lawn.png, k_clear.png (worn dirt path), k_stone.png (paving), k_clear_cap.png, k_stone_cap.png
  rows 0-3 clear, 4-57 the plane, 58- the earth face (town.gd: RAISE 42, LIPY 58)
References (style only, not in the repo): side-on beat 'em up streets (wide low cobbles, ruts along the road) and
Kingdom-like grass strips (flat lawn, sparse tufts)."""
import numpy as np
from PIL import Image

PAL = np.array(Image.open("assets/town/palette.png").convert("RGBA"))
def ramp(r): return [tuple(int(v) for v in c[:3]) for c in PAL[r] if c[3] > 0]
WOOD, OCHRE, CREAM, LEAF, STONE, VIOLET, RED = ramp(1), ramp(2), ramp(3), ramp(4), ramp(8), ramp(7), ramp(0)

WC = 4800                 # cells along the town (9600 px > TOWN_W)
PR = 27                   # cell rows of the plane
TOP = 4                   # clear rows over it (px)

def vnoise(n, period, seed):
    """smooth value noise along x, in [-1, 1]"""
    rng = np.random.default_rng(seed)
    k = n // period + 3
    v = rng.uniform(-1, 1, k)
    x = np.arange(n) / period
    i = x.astype(int); f = x - i; f = f * f * (3 - 2 * f)
    return v[i] + (v[i + 1] - v[i]) * f

def blank(): return np.zeros((PR, WC, 4), np.uint8)
def put(a, r, x, c):
    if 0 <= r < PR and 0 <= x < WC: a[r, x] = (*c, 255)

def lawn():
    a = blank()
    # three bands, far lighter, near darker; their edges wander in long soft waves (no straight seams, no chops)
    b1 = 5 + np.round(1.6 * vnoise(WC, 34, 1) + 0.8 * vnoise(WC, 11, 4)).astype(int)
    b2 = 16 + np.round(2.0 * vnoise(WC, 46, 2) + 0.8 * vnoise(WC, 13, 5)).astype(int)
    for x in range(WC):
        for r in range(PR): a[r, x] = (*LEAF[6 if r < b1[x] else 4 if r >= b2[x] else 5], 255)
    rng = np.random.default_rng(3)
    # the grain of the lawn: short lines along x, a step lighter on the far lawn, a step darker on the near
    for _ in range(WC // 6):
        x, r = int(rng.integers(0, WC - 8)), int(rng.integers(0, PR))
        base = LEAF.index(tuple(a[r, x, :3])); L = int(rng.integers(3, 7))
        c = LEAF[min(7, base + 1)] if r < 9 else LEAF[max(2, base - 1)]
        for dx in range(L):
            if LEAF.index(tuple(a[r, x + dx, :3])) == base: put(a, r, x + dx, c)
    # worn patches: wide, low, ragged, one step down, in the middle and front
    for _ in range(WC // 90):
        cx, cr, w, h = int(rng.integers(0, WC)), int(rng.integers(9, PR - 3)), int(rng.integers(12, 30)), int(rng.integers(2, 4))
        e = vnoise(w + 4, 3, cx)
        for x in range(cx - w // 2, cx + w // 2):
            u = (x - cx) / (w / 2)
            hh = int(round(h * np.sqrt(max(0, 1 - u * u)) + 0.7 * e[x - cx + w // 2]))
            for r in range(cr, cr + hh):
                if 0 <= x < WC and r < PR: a[r, x, :3] = LEAF[max(2, LEAF.index(tuple(a[r, x, :3])) - 1)]
    # tufts on the near lawn: a dark foot two or three cells wide, light tips over it, in a few shapes
    shapes = [[(0, -1, "d"), (0, 0, "d"), (0, 1, "d"), (-1, -1, "l"), (-1, 1, "l")],
              [(0, 0, "d"), (0, 1, "d"), (-1, 0, "l"), (-1, 2, "l"), (0, 2, "d")],
              [(0, -1, "d"), (0, 0, "d"), (-1, 0, "l"), (-2, 0, "l")]]
    for _ in range(WC // 14):
        x, r = int(rng.integers(2, WC - 3)), int(rng.integers(10, PR))
        base = LEAF.index(tuple(a[r, x, :3]))
        for dr, dx, k in shapes[int(rng.integers(0, 3))]:
            put(a, r + dr, x + dx, LEAF[max(2, base - 1)] if k == "d" else LEAF[min(7, base + 1)])
    # a few low flowers: a pair of petals on a leaf (no outline: the town's flowers)
    for _ in range(WC // 200):
        x, r = int(rng.integers(2, WC - 4)), int(rng.integers(11, PR - 1))
        c = VIOLET[4] if rng.random() < 0.5 else RED[6]
        put(a, r, x, c); put(a, r, x + 1, c); put(a, r + 1, x, LEAF[3]); put(a, r + 1, x + 1, LEAF[3])
    return a

def clear():
    a = blank()
    b1 = 3 + np.round(1.2 * vnoise(WC, 30, 11)).astype(int)
    for x in range(WC):
        for r in range(PR): a[r, x] = (*OCHRE[3 if r < b1[x] else 2], 255)
    rng = np.random.default_rng(12)
    # the grain of the dirt: short lighter and darker dashes along x
    for _ in range(WC // 8):
        x, r, L = int(rng.integers(0, WC - 6)), int(rng.integers(3, PR)), int(rng.integers(2, 5))
        c = OCHRE[3] if rng.random() < 0.5 else OCHRE[1]
        for dx in range(L): put(a, r, x + dx, c)
    # damp, trodden patches: wide and low, a step darker
    for _ in range(WC // 80):
        cx, cr, w, h = int(rng.integers(0, WC)), int(rng.integers(6, PR - 2)), int(rng.integers(10, 26)), int(rng.integers(2, 4))
        for x in range(cx - w // 2, cx + w // 2):
            u = (x - cx) / (w / 2); hh = int(round(h * np.sqrt(max(0, 1 - u * u))))
            for r in range(cr, cr + hh): put(a, r, x, OCHRE[1])
    # ruts along the road: a groove that wanders a cell up or down, comes and goes, a lit lip on its far side
    for r0 in (11, 20):
        on = (vnoise(WC, 26, r0) + 0.5 * vnoise(WC, 7, r0 + 3)) > -0.35
        wob = np.round(1.2 * vnoise(WC, 38, r0 + 7)).astype(int)
        for x in range(WC):
            if not on[x]: continue
            put(a, r0 + wob[x], x, OCHRE[0] if (x // 5) % 3 else OCHRE[1]); put(a, r0 - 1 + wob[x], x, OCHRE[4])
    # pebbles: flat stones, a lit top over a shaded foot, three or four cells wide on the near road
    for _ in range(WC // 22):
        x, r = int(rng.integers(1, WC - 4)), int(rng.integers(4, PR - 1))
        w = 2 if r < 12 else int(rng.integers(2, 4))
        for dx in range(w): put(a, r, x + dx, STONE[7])
        for dx in range(1, w + 1): put(a, r + 1, x + dx, STONE[5])
    # the lawn creeping in at the back edge
    g = vnoise(WC, 9, 13)
    for x in range(WC):
        for r in range(0, 3):
            if g[x] > 0.25 + 0.3 * r: a[r, x] = (*LEAF[5 if r == 0 else 4], 255)
    return a

def stone(curb=True):
    a = blank()
    rng = np.random.default_rng(21)
    STEPS, JOINT = [CREAM[0], CREAM[1], CREAM[2], CREAM[3]], STONE[6]
    heights = [2, 3, 3, 3, 3, 3, 3, 4]                         # courses, a little lower at the back (sum 24; the curb takes 3;
                                                               # owner 2026-11-08: "돌은 너무 작아지는 게 가파른듯")
    r = 0
    for ci, h in enumerate(heights):
        x = -int(rng.integers(0, 8))
        while x < WC:
            w = int(rng.integers(6, 10) if ci < 3 else rng.integers(7, 12))
            tone = 1 + int(rng.random() < 0.25) - int(rng.random() < 0.15)    # each stone a step lighter or darker now and then
            for xx in range(max(0, x), min(WC, x + w)):
                for rr in range(r, min(PR, r + h)):
                    last, top = xx == x + w - 1, rr == r
                    if last or top: c = JOINT if (last and not top) or (top and (xx == x or last)) else STEPS[0]
                    elif rr == r + 1 and x < xx < x + w - 2: c = STEPS[min(3, tone + 1)]        # the lit crown
                    else: c = STEPS[tone]
                    a[rr, xx] = (*c, 255)
            if rng.random() < 0.1 and 0 <= x + w - 1 < WC and r + 1 < PR: a[r + 1, x + w - 1] = (*LEAF[3], 255)   # moss
            x += w
        r += h
    if curb:                                                     # the front curb: long stones, a lit top
        x = 0
        while x < WC:
            w = int(rng.integers(12, 20))
            for xx in range(x, min(WC, x + w)):
                j = xx == x + w - 1
                a[PR - 3, xx] = (*(JOINT if j else CREAM[3]), 255)
                for rr in (PR - 2, PR - 1): a[rr, xx] = (*(JOINT if j else CREAM[1]), 255)
            x += w
    return a

def cap(mat, cw, solid_from, seed):
    """a cap over a zone's end: the material thinning out to the left over the lawn (transparent where it has gone)"""
    src = {"clear": clear, "stone": lambda: stone(True)}[mat]()[:, :cw].copy()
    e = vnoise(PR + 8, 3, seed)
    for r in range(PR):
        edge = solid_from - int(round(solid_from * (0.35 + 0.25 * e[r]) * (1 - r / PR * 0.3)))
        src[r, :max(0, edge)] = 0
    return src

def save(name, plane, face_src, face_row=29):
    old = np.array(Image.open(face_src).convert("RGBA"))
    face = old[face_row:, :]
    face = np.concatenate([face, face[-1:]], 0)                  # rows 29.. of the old tile: blocks on even rows here
    W = plane.shape[1] * 2
    reps = -(-W // face.shape[1])
    face = np.tile(face, (1, reps, 1))[:, :W]
    top = np.repeat(np.repeat(plane, 2, 0), 2, 1)
    out = np.concatenate([np.zeros((TOP, W, 4), np.uint8), top, face], 0)
    Image.fromarray(out).save(f"assets/town/{name}.png")
    print(name, out.shape)

if __name__ == "__main__":
    # OLD: a folder with the old tiles (git show <rev>:assets/town/k_*.png), whose earth face is kept
    import sys
    O = sys.argv[1]
    save("k_lawn", lawn(), f"{O}/k_lawn.png")
    save("k_clear", clear(), f"{O}/k_clear.png")
    save("k_stone", stone(), f"{O}/k_stone.png")
    save("k_clear_cap", cap("clear", 19, 10, 31), f"{O}/k_clear_cap.png")
    save("k_stone_cap", cap("stone", 48, 20, 32), f"{O}/k_stone_cap.png")
