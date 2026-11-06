"""Re-draw the town sprites drawn scaled (town.gd BS 1.35, the far layers PXK 1.78) at that scale on the 1-px grid, crisp:
each target pixel takes the source pixel it overlaps most (a near tie -> the darker, so line work survives); no blending,
so no smeared colours (owner 2026-11-06). Then tools/thin_outline.py puts the outlines back to one pixel.
Usage: python3 tools/rebake_town.py  (-> assets/town/hx/)"""
import sys, numpy as np
from PIL import Image
def rebake_crisp(src, K):
    a = np.array(Image.open(src).convert("RGBA")).astype(np.int32)
    h, w = a.shape[:2]; W, H = round(w * K), round(h * K)
    lum = a[..., 0] * 3 + a[..., 1] * 6 + a[..., 2]
    def pick(n, N):
        # for each target index: the source index with the largest overlap; a tie (two sources half each) -> both kept as
        # candidates, resolved per pixel toward the darker one (line work survives)
        out = []
        for t in range(N):
            s0, s1 = t / K, (t + 1) / K
            i0 = int(np.floor(s0)); best = []
            for i in range(i0, min(n, int(np.ceil(s1)))):
                ov = min(s1, i + 1) - max(s0, i)
                best.append((ov, i))
            best.sort(reverse=True)
            c = [best[0][1]]
            if len(best) > 1 and best[1][0] > best[0][0] * 0.8: c.append(best[1][1])
            out.append(c)
        return out
    px, py = pick(w, W), pick(h, H)
    o = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            cands = [(yy, xx) for yy in py[y] for xx in px[x]]
            op = [c for c in cands if a[c][3] > 127]
            if not op: continue
            c = min(op, key=lambda c: lum[c])
            o[y, x] = a[c]
    return Image.fromarray(o)

KEYS = ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_anvil", "g_kiln", "g_hall", "g_hall_win", "q_fountain",
        # f_tree2 / f_tree3 are drawn natively at this size now (owner's reference tree, 2026-11-06): not rebaked
        "f_bigtree", "f_bigtree_leaf", "f_bigtree_trunk",
        "f_bush1", "f_bush2", "f_bush3"]
FAR = ["bg_mountains", "bg_forest"]
if __name__ == "__main__":
    import os, subprocess
    os.makedirs("assets/town/hx", exist_ok=True)
    for k in KEYS: rebake_crisp("assets/town/%s.png" % k, 1.35).save("assets/town/hx/%s.png" % k)
    for k in FAR: rebake_crisp("assets/town/%s.png" % k, 1.78).save("assets/town/hx/%s.png" % k)
    subprocess.run(["python3", "tools/thin_outline.py"] + ["assets/town/hx/%s.png" % k for k in KEYS], check=True)
