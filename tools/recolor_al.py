## 아이다 / 루체 sprites matched to their new standing art (2026-11): Aida's green under-skirt → the apron's brown
## (the illustration's skirt is brown), Luce's navy habit and veil → the illustration's dark grey-violet. Hair, skin,
## the shovel and the sprites' shading are kept. python3 tools/recolor_al.py <out dir> (writes <out>/<c>/<c>_<i>.png)
import sys, os, numpy as np
from PIL import Image
from skimage import color
from scipy import ndimage
OUT = sys.argv[1]
def cells(a):
    return [(r, c) for r in range(7) for c in range(9)]
def aida(rgba):
    out = rgba.copy()
    for r, c in cells(rgba):
        cell = rgba[r * 352:(r + 1) * 352, c * 448:(c + 1) * 448]
        a = cell[..., 3]
        if a.max() < 0.5: continue
        lab = color.rgb2lab(cell[..., :3]); L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
        C = np.hypot(A, B); H = np.degrees(np.arctan2(B, A)) % 360
        vis = a > 0.5
        green = vis & (C > 10) & (H >= 95) & (H < 165)
        ys, xs = np.nonzero(vis); fb = ys.max(); fw = xs.max() - xs.min()
        flower = vis & (H >= 285) & (H < 335) & (C > 20) & (C < 45) & (L > 36) & (L < 60)
        # hair and skirt are the same green: part them by shape. Opening drops the thin hair tails, leaving the head's
        # mass (the one with the flower on it) and the skirt's; every green pixel then joins the nearer mass along the
        # green itself (a tail that lies over the skirt still runs back to the head)
        from skimage.morphology import opening, disk
        from skimage.graph import MCP_Geometric
        core = opening(green, disk(4))
        lab_, n = ndimage.label(core, structure=np.ones((3, 3)))
        if n < 2: continue
        sizes = ndimage.sum(core, lab_, range(1, n + 1))
        big = [k + 1 for k in range(n) if sizes[k] >= 60]
        if len(big) < 2: continue
        # the head's mass carries the flower (one compact purple blob of its size; rift sweeps are big, charge sparks
        # small, a half-hidden flower is skipped); with no clear flower, the mass farthest from the boots (the skirt
        # sits on them, whichever way she lies), else the topmost
        cents = [np.array(ndimage.center_of_mass(lab_ == k)) for k in big]
        purple = vis & (H >= 280) & (H < 340) & (C > 15)
        pl, pn = ndimage.label(purple, structure=np.ones((3, 3)))
        fls = []
        for k in range(1, pn + 1):
            m = pl == k
            yy, xx = np.nonzero(m)
            if 100 <= m.sum() <= 220 and np.ptp(yy) <= 24 and np.ptp(xx) <= 24: fls.append(m)
        ov = [(ndimage.binary_dilation(fls[0], iterations=3) & (lab_ == k)).sum() for k in big] if len(fls) == 1 else [0]
        boots = vis & (H >= 15) & (H < 70) & (C > 10) & (L < 42)
        if max(ov) > 0:
            hair_k = big[int(np.argmax(ov))]
        elif boots.sum() > 20:
            bc = np.array(ndimage.center_of_mass(boots))
            hair_k = big[int(np.argmax([np.linalg.norm(c_ - bc) for c_ in cents]))]
        else:
            hair_k = big[int(np.argmin([c_[0] for c_ in cents]))]
        cost = np.where(green, 1.0, np.inf)
        def dist(seed):
            m = MCP_Geometric(cost, fully_connected=True)
            d, _ = m.find_costs(np.argwhere(seed))
            return d
        dh = dist(lab_ == hair_k)
        ds = dist(core & (lab_ != hair_k))
        skirt = green & (ds < dh)
        if not skirt.any(): continue
        # soft edge so the anti-aliased rim turns too
        w = np.clip(ndimage.gaussian_filter(skirt.astype(np.float32), 0.8) * 1.6, 0, 1) * (C > 6) * vis
        # apron brown (the sprite's own): hue 78, chroma 34; the skirt a touch darker than the apron
        H2 = H + w * (78 - H); C2 = C * (1 + w * (34 / np.maximum(C, 1) - 1)) ; L2 = L + w * 6
        A2 = C2 * np.cos(np.radians(H2)); B2 = C2 * np.sin(np.radians(H2))
        rgb = np.clip(color.lab2rgb(np.dstack([L2, A2, B2])), 0, 1)
        out[r * 352:(r + 1) * 352, c * 448:(c + 1) * 448, :3] = np.where(vis[..., None], rgb, cell[..., :3])
    return out
def luce(rgba):
    out = rgba.copy()
    a = rgba[..., 3]; vis = a > 0.5
    lab = color.rgb2lab(rgba[..., :3]); L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    C = np.hypot(A, B); H = np.degrees(np.arctan2(B, A)) % 360
    navy = vis & (C > 12) & (H >= 215) & (H < 300) & (L < 55)
    w = np.clip(ndimage.gaussian_filter(navy.astype(np.float32), 0.8) * 1.6, 0, 1) * vis * np.clip((60 - L) / 10, 0, 1)
    # the illustration's habit: hue 315, chroma 19, a little lighter than the sprite's navy
    H2 = H + w * (((315 - H + 180) % 360) - 180); C2 = C * (1 + w * (0.6 - 1)); L2 = L + w * 4
    A2 = C2 * np.cos(np.radians(H2)); B2 = C2 * np.sin(np.radians(H2))
    rgb = np.clip(color.lab2rgb(np.dstack([L2, A2, B2])), 0, 1)
    out[..., :3] = np.where(vis[..., None], rgb, rgba[..., :3])
    return out
for c, fn in [('aida', aida), ('luce', luce)]:
    os.makedirs(f'{OUT}/{c}', exist_ok=True)
    for i in range(6):
        p = f'assets/chars/{c}/{c}_{i}.png'
        if not os.path.exists(p): continue
        im = np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255
        res = fn(im)
        Image.fromarray((res * 255 + 0.5).astype(np.uint8)).save(f'{OUT}/{c}/{c}_{i}.png')
        print(c, i)
