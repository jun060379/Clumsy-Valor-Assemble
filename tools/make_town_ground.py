"""Town ground variants and small nature sprites from a generated set (owner 2026-11-06: new ground sprites; grass that
runs down the bank, bare clearings, a thin stone edging to split green from green; AI source kept out of the repo).
Source: the 3x3 generated sheet. Each cell is scaled 0.75 (the trees' pixel size), crisp, and snapped together with the
trees to one palette. Ground strips keep their full-height middle so the runtime's mirror tiling is seamless.
Writes assets/town/k_ground_<v>.png (grass, bank, dirt, cobble, curb) and f_flowers, f_tufts, f_shrub, f_rocks.
Usage: python3 tools/make_town_ground.py SHEET.png"""
import sys, os, tempfile
import numpy as np
from PIL import Image
from skimage.color import rgb2lab
from scipy.cluster.vq import kmeans2
sys.path.insert(0, "tools")
from rebake_town import rebake_crisp

K = 0.75
TMP = os.path.join(tempfile.mkdtemp(), "c.png")
W = 208                       # strip width; the runtime mirrors it for the seam

def cells(sheet):
    m = np.array(Image.open(sheet).convert("RGBA"))
    C = m.shape[0] / 3
    out = []
    for i in range(9):
        r, c = divmod(i, 3)
        cell = m[int(r * C):int((r + 1) * C), int(c * C):int((c + 1) * C)].copy()
        cell[..., 3] = np.where(cell[..., 3] > 128, 255, 0)
        ys, xs = np.where(cell[..., 3] > 0)
        cell = cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        Image.fromarray(cell).save(TMP)
        out.append(np.array(rebake_crisp(TMP, K)))
    return out

def strip(a):
    """the middle of a strip, columns where the body is full height, cut to W (tiled by mirroring if short)"""
    h = a.shape[0]
    cov = (a[..., 3] > 0).sum(0)
    full = np.where(cov >= cov.max() * 0.9)[0]
    a = a[:, full.min() + 4:full.max() - 4]
    while a.shape[1] < W: a = np.concatenate([a, a[:, ::-1]], 1)
    return a[:, :W].copy()

def snap(arrs, n=40):
    cols = np.concatenate([a[a[..., 3] > 0][:, :3] for a in arrs])
    u, inv = np.unique(cols, axis=0, return_inverse=True)
    cnt = np.bincount(inv.ravel())
    lab = rgb2lab(u[None].astype(float) / 255)[0]
    cent, _ = kmeans2(lab[np.repeat(np.arange(len(u)), np.minimum(cnt, 200))], n, minit="++", seed=5, iter=30)
    pal = u[[((lab - c) ** 2).sum(1).argmin() for c in cent]]
    pl = rgb2lab(pal[None].astype(float) / 255)[0]
    lut = {tuple(c): pal[((pl - l) ** 2).sum(1).argmin()] for c, l in zip(map(tuple, u), lab)}
    for a in arrs:
        m = a[..., 3] > 0
        a[m, :3] = np.array([lut[tuple(c)] for c in a[m][:, :3]])

def main():
    c = cells(sys.argv[1])
    grass, bank, dirt, cobble = strip(c[0]), strip(c[1]), strip(c[2]), strip(c[3])
    curb = strip(c[4])
    # the clearing's pebbles would repeat every tile: painted out with the dirt around them
    from scipy import ndimage
    rr, gg, bb = [dirt[..., i].astype(int) for i in range(3)]
    peb = (bb > 105) & (gg > 120) & (dirt[..., 3] > 0)          # the stones are the only light, cool pixels in it
    lab, n = ndimage.label(ndimage.binary_dilation(peb, iterations=7))
    src = dirt.copy()
    for sl in ndimage.find_objects(lab):
        ys, xs = sl
        sx = slice((xs.start + 60) % (W - (xs.stop - xs.start)), None)
        sx = slice(sx.start, sx.start + xs.stop - xs.start)
        patch = src[ys, sx]
        m = patch[..., 3] > 0
        dirt[ys, xs][m] = patch[m]
    # curb: the grass strip's lawn, the stone edging, then the bank's grass face below -- green / stone / green
    ys = np.where((curb[..., 3] > 0).any(1))[0]
    # the props come out of the grid all one size: each brought to its own height in the world
    def fit(a, hh):
        Image.fromarray(a).save(TMP)
        return np.array(rebake_crisp(TMP, hh / a.shape[0]))
    cb = fit(curb[ys.min():ys.max() + 1], 14)
    while cb.shape[1] < W: cb = np.concatenate([cb, cb[:, ::-1]], 1)
    cb = cb[:, :W]
    curbv = np.zeros((28 + bank.shape[0] - 10, W, 4), np.uint8)
    curbv[16:] = (40, 64, 42, 255)                       # solid under the lawn's blades: nothing shows through
    def over(dst, src, y):
        m = src[..., 3] > 0
        dst[y:y + src.shape[0]][m] = src[m]
    over(curbv, bank[10:], 28)
    over(curbv, grass[:26], 0)
    over(curbv, cb, 18)
    props = {"f_flowers": fit(c[5], 44), "f_tufts": fit(c[6], 30), "f_shrub": fit(c[7], 86), "f_rocks": fit(c[8], 46)}
    trees = [np.array(Image.open(f"assets/town/{k}.png").convert("RGBA")) for k in ["f_oak", "f_round"]]
    arrs = [grass, bank, dirt, cobble, curbv] + list(props.values())
    snap(arrs + trees)
    for k, a in zip(["grass", "bank", "dirt", "cobble", "curb"], arrs[:5]):
        Image.fromarray(a).save(f"assets/town/k_ground_{k}.png")
        print(k, a.shape[1], "x", a.shape[0])
    for k, a in props.items():
        Image.fromarray(a).save(f"assets/town/{k}.png")
        print(k, a.shape[1], "x", a.shape[0])

main()
