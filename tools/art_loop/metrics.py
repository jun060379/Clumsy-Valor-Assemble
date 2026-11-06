#!/usr/bin/env python3
"""Countable art faults for one sprite (or a folder of them). Owner 2026-11-06: "잡티·끊긴 선처럼 셀 수 있는 건
스크립트로 재". Taste ("AI 티", "어울리는지") is NOT measured here -- that is the reviewers' job.

  python3 tools/art_loop/metrics.py IMG_OR_DIR [--palette REF.png ...] [--json]

Per image (opaque = alpha >= 128):
  orphans      opaque pixels with no opaque 4-neighbour (lone specks)
  speckle      pixels whose colour matches none of their 8 neighbours inside the sprite (noise/dither junk)
  outline_gaps edge pixels of the silhouette where the 1-2 px outline breaks (an edge pixel brighter than the
               pixel just inside it -- our outline is the inner colour, darkened)
  thick_line   edge runs whose outline is 3 px or more deep (we want 1-2 px)
  semi_alpha   pixels with 0 < alpha < 255 (soft edges a pixel sprite should not have)
  colours      distinct opaque colours
  off_palette  colours farther than 24 (RGB distance) from every colour of the --palette reference images
               (default: the existing hand-made town sprites listed in REF_DEFAULT)
A lower number is better for all but colours (that one is just reported). Numbers compare rounds of the SAME
sprite; hand-made buildings also show some thick_line (deliberate dark planes), so there is no absolute pass mark.
"""
import sys, json, glob, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF_DEFAULT = ["assets/town/g_cottage.png", "assets/town/g_store.png", "assets/town/g_well.png",
               "assets/town/q_crateL.png", "assets/town/q_barrelM.png", "assets/town/k_ground.png"]


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def palette(paths):
    pal = set()
    for p in paths:
        im = Image.open(p).convert("RGBA")
        b = im.tobytes()
        for i in range(0, len(b), 4):
            if b[i + 3] >= 128: pal.add((b[i], b[i + 1], b[i + 2]))
    return list(pal)


def near(c, pal, tol=24):
    t2 = tol * tol
    for p in pal:
        if (c[0] - p[0]) ** 2 + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2 <= t2: return True
    return False


def measure(path, pal):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    op = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128
    r = dict(orphans=0, speckle=0, outline_gaps=0, thick_line=0, semi_alpha=0)
    cols = set()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if 0 < c[3] < 255: r["semi_alpha"] += 1
            if not op(x, y): continue
            cols.add(c[:3])
            n4 = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if not any(op(*q) for q in n4):
                r["orphans"] += 1
                continue
            n8 = [(x + i, y + j) for i in (-1, 0, 1) for j in (-1, 0, 1) if i or j]
            inside = [q for q in n8 if op(*q)]
            if len(inside) >= 5 and not any(px[q][:3] == c[:3] for q in inside): r["speckle"] += 1
            # silhouette edge: some 4-neighbour is transparent. look one pixel inward (away from that gap)
            for (qx, qy) in n4:
                if op(qx, qy): continue
                ix, iy = x + (x - qx), y + (y - qy)
                if op(ix, iy) and lum(c) > lum(px[ix, iy]) + 6: r["outline_gaps"] += 1
                # outline depth: how many pixels inward stay as dark as the edge pixel (+-8 lum)
                d, jx, jy = 1, ix, iy
                while op(jx, jy) and abs(lum(px[jx, jy]) - lum(c)) <= 8 and lum(c) < 90 and d < 6:
                    d += 1; jx += (x - qx); jy += (y - qy)
                if d >= 3: r["thick_line"] += 1
                break
    r["colours"] = len(cols)
    r["off_palette"] = sum(1 for c in cols if not near(c, pal)) if pal else 0
    r["size"] = f"{w}x{h}"
    return r


def main():
    a = sys.argv[1:]
    if not a: print(__doc__); sys.exit(2)
    js = "--json" in a
    a = [x for x in a if x != "--json"]
    refs = []
    if "--palette" in a:
        i = a.index("--palette"); refs = a[i + 1:]; a = a[:i]
    if not refs: refs = [os.path.join(ROOT, p) for p in REF_DEFAULT if os.path.exists(os.path.join(ROOT, p))]
    pal = palette(refs)
    files = []
    for t in a:
        files += sorted(glob.glob(os.path.join(t, "*.png"))) if os.path.isdir(t) else [t]
    out = {f: measure(f, pal) for f in files}
    tot = {k: sum(v[k] for v in out.values()) for k in ("orphans", "speckle", "outline_gaps", "thick_line", "semi_alpha", "off_palette")}
    if js:
        print(json.dumps({"files": out, "total": tot}, indent=1))
    else:
        for f, v in out.items():
            print(os.path.basename(f), " ".join(f"{k}={v[k]}" for k in v))
        print("TOTAL", " ".join(f"{k}={v}" for k, v in tot.items()))


if __name__ == "__main__":
    main()
