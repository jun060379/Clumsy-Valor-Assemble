#!/usr/bin/env python3
"""Sun-side light for the town sprites (owner 2026-11-06, after MGD Dev Log 6 "2D 아트 명암, AI로 자동화": normal-map
light that turns with the sun, but kept pixel art: light computed once per pixel cell, colours only from the sprite's
own colours). Baked, not live: a morning (sun from the left) and an evening (sun from the right) version of each
sprite; noon is the art as drawn. town.gd swaps them by the hour.
Per sprite, on its native grid (one cell = 2 screen px):
  - height: a dome from the silhouette inwards (distance to the edge, eased) plus a little of the art's own
    brightness (bricks, planks, leaf clumps stand out) -> normals
  - ramps: the sprite's colours grouped by material (hue; greys apart) and each group ordered dark -> light
  - light: shift = round(GAIN * (N.L - N.L_noon)); every cell moves that many steps along ITS ramp (never into another
    material's colour); the cells facing the sun brighten, the ones turned away darken
Writes assets/town/lit/<k>_m.png and <k>_e.png at the size of the drawn sprite (hx/ when it has one).
  python3 tools/bake_sun_light.py [names...]"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.color import rgb2lab
from scipy.cluster.vq import kmeans2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT = ["g_store", "g_barn", "g_cottage", "g_well", "g_forge", "g_kiln", "g_hall", "q_fountain", "g_wagon2",
           "g_yard", "q_crateL", "q_crateS", "q_barrelL", "q_barrelM", "q_barrelS", "q_bench", "q_board", "q_planter",
           "q_pot", "g_anvil", "q_lamp_base"]
GAIN = 4.0
LSTEP = 7.0        # one light step = this much lightness (Lab L), then the nearest colour of the same ramp
LIGHTS = {"m": np.array([-0.72, -0.55, 0.42]), "e": np.array([0.72, -0.55, 0.42])}
NOON = np.array([0.0, -0.62, 0.78])


def norm(v):
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def ramps_of(cols):
    """cols: N x 3 rgb -> (group id per colour, rank within its group, list of index arrays per group sorted by L)"""
    lab = rgb2lab(cols[None].astype(float) / 255.0)[0]
    C = np.hypot(lab[:, 1], lab[:, 2])
    grey = C < 10.0
    g = np.zeros(len(cols), int)
    chrom = np.where(~grey)[0]
    k = int(min(6, max(1, len(chrom) // 4)))
    if len(chrom) >= 2 and k > 1:
        cent, lbl = kmeans2(lab[chrom][:, 1:], k, minit="++", seed=3, iter=40)
        g[chrom] = lbl + 1
    g[grey] = 0
    groups = []
    rank = np.zeros(len(cols), int)
    for gi in np.unique(g):
        idx = np.where(g == gi)[0]
        idx = idx[np.argsort(lab[idx, 0])]
        rank[idx] = np.arange(len(idx))
        groups.append(idx)
    gid = np.zeros(len(cols), int)
    for n_, idx in enumerate(groups): gid[idx] = n_
    return gid, rank, groups


def bake(k):
    src = os.path.join(ROOT, "assets/town/hx", k + ".png")
    if not os.path.exists(src): src = os.path.join(ROOT, "assets/town", k + ".png")
    a = np.array(Image.open(src).convert("RGBA"))
    nat = a[0::2, 0::2].copy()
    m = nat[..., 3] > 127
    h, w = m.shape
    # height: eased distance to the silhouette edge + a little brightness
    H0 = max(3.0, min(14.0, min(h, w) * 0.18))
    d = np.minimum(ndi.distance_transform_edt(m), H0) / H0
    hgt = np.sqrt(np.clip(1.0 - (1.0 - d) ** 2, 0, 1)) * H0
    lum = (0.299 * nat[..., 0] + 0.587 * nat[..., 1] + 0.114 * nat[..., 2]) / 255.0
    hgt = hgt + 0.5 * ndi.gaussian_filter(lum, 1.0) * m
    hgt = ndi.gaussian_filter(hgt, 0.8)
    gx = ndi.sobel(hgt, 1) / 8.0
    gy = ndi.sobel(hgt, 0) / 8.0
    N = norm(np.stack([-gx, -gy, np.full_like(gx, 0.55)], -1))
    cols, inv = np.unique(nat[m][:, :3], axis=0, return_inverse=True)
    gid, rank, groups = ramps_of(cols)
    labs = rgb2lab(cols[None].astype(float) / 255.0)[0]
    ci = inv.ravel()
    os.makedirs(os.path.join(ROOT, "assets/town/lit"), exist_ok=True)
    for tag, L in LIGHTS.items():
        Ld = norm(L)
        # only the sideways turn counts: faces turned toward the low sun brighten, the far sides darken; a face looking
        # at the camera keeps the art's colour (noon = as drawn; the time-of-day ambient does the overall dimming)
        sh = np.rint(GAIN * N[m][:, 0] * np.sign(Ld[0])).astype(int)
        out = nat.copy()
        g = gid[ci]
        tl = labs[ci, 0] + sh * LSTEP
        newc = cols[ci].copy()
        for gi, idx in enumerate(groups):
            sel = np.where((g == gi) & (sh != 0))[0]
            if len(sel) == 0: continue
            j = np.abs(tl[sel, None] - labs[idx][None, :, 0]).argmin(1)
            newc[sel] = cols[idx[j]]
        out[m, :3] = newc
        big = np.repeat(np.repeat(out, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
        if big.shape[:2] != a.shape[:2]:
            pad = np.zeros_like(a); pad[:big.shape[0], :big.shape[1]] = big; big = pad
        big[..., 3] = a[..., 3]
        Image.fromarray(big).save(os.path.join(ROOT, "assets/town/lit", f"{k}_{tag}.png"))
    print(k, "cells", (w, h), "colours", len(cols), "ramps", len(groups))


for k in (sys.argv[1:] or DEFAULT): bake(k)
