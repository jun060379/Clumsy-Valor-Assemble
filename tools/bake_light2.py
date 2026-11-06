#!/usr/bin/env python3
"""Time-of-day and light-source contrast for the town sprites, by colour theory, on the map palette (owner 2026-11-06:
"시간과 조명에 따른 대비 굽기. 명도만 신경쓰지 말고 채도 색조 전부 신경 써서 색상 이론을 기반으로").
Replaces tools/bake_sun_light.py. Per sprite, on its 2-px cells, with normals from a silhouette dome + the art's own
brightness (as before), four looks:
  _m  morning: low sun from the left, golden light; faces toward it lighter, warmer (hue toward yellow), a little
      more saturated; faces away darker, cooler (hue toward blue-violet), greyer
  noon: the art as drawn
  _e  evening: low sun from the right, orange-red light, violet shadows, stronger warm/cool split than morning
  _n  night: cool moonlight from above-left (tops a touch lighter and bluer, the rest dimmer and greyer) and every
      lamp, fire, lit window and string bulb near the sprite's place in the town (tools reads their layout) warming the
      faces turned to it: lighter, hue toward the light's colour, more saturated, falling off with distance
Every result is snapped back onto the map palette (assets/town/palette.png), choosing only from the pixel's own
material ramp and the neighbouring ramp in the direction the light turns its hue (wood may warm into ochre, never into
leaf green), nearest by Lab distance.
  python3 tools/bake_light2.py docs/work/town-art/light_layout.json   (town.bld boxes + light_sources at night, dumped
  from Godot; redump when buildings or lights move)"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.color import rgb2lab, lab2rgb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGBA"))
PJ = json.load(open(os.path.join(ROOT, "assets/town/palette.json")))
RAMPS = [PAL[i, :s, :3] for i, s in enumerate(PJ["steps"])]
RLAB = [rgb2lab(r[None].astype(float) / 255.0)[0] for r in RAMPS]
NCH = 8                                    # chromatic ramps 0..7 in hue order (red, wood, ochre, cream, leaf, green, blue, violet)
STONE, IRON = 8, 9
NB_PENALTY = 14.0       # Lab distance a neighbouring ramp must win by
GENERIC = ["q_crateL", "q_crateS", "q_barrelL", "q_barrelM", "q_barrelS", "q_bench", "q_board", "q_planter", "q_pot",
           "q_lamp_base", "q_fountain", "g_wagon2"]


def norm(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)


def ramp_of(lab):
    """which palette ramp each Lab colour sits on (exact palette colours: by nearest palette entry)"""
    best = np.full(len(lab), 1e9); r = np.zeros(len(lab), int)
    for i, rl in enumerate(RLAB):
        d = ((lab[:, None] - rl[None]) ** 2).sum(-1).min(1)
        sel = d < best; best[sel] = d[sel]; r[sel] = i
    return r


def neighbour(r, warm):
    """the ramp next to r in the direction the light turns the hue (warm: toward yellow, else toward blue-violet)"""
    if r >= NCH: return STONE if r == IRON else IRON          # greys: the other grey
    order = [7, 0, 1, 2, 3, 4, 5, 6]                          # violet, red, wood, ochre, cream, leaf, green, blue
    i = order.index(r)
    return order[min(i + 1, 4)] if warm and i < 4 else (order[max(i - 1, 0)] if not warm and i > 0 else r)


def snap(target, r, warm):
    """nearest palette colour to the target, from the pixel's own ramp; the neighbouring ramp only when it is clearly
    closer (a penalty keeps a roof a roof: the light tints it, it does not turn it into another material)"""
    own = np.sqrt(((RLAB[r] - target) ** 2).sum(-1))
    nb = neighbour(r, warm)
    if nb != r:
        other = np.sqrt(((RLAB[nb] - target) ** 2).sum(-1)) + NB_PENALTY
        if other.min() < own.min(): return RAMPS[nb][other.argmin()]
    return RAMPS[r][own.argmin()]


def hue_toward(a, b, h_to, k):
    """rotate the (a, b) hue toward h_to (degrees) by up to k (0..1 of the way, max 1 turn of 35 degrees)"""
    C = np.hypot(a, b); h = np.degrees(np.arctan2(b, a))
    d = ((h_to - h + 180.0) % 360.0) - 180.0
    h2 = h + np.clip(d, -28.0, 28.0) * k
    return C, h2


def shade(lab, amt, h_light, h_shadow, dl, csat):
    """lab: N x 3; amt in [-1, 1] (+ toward the light): the colour-theory move"""
    out = lab.copy()
    lit = amt > 0
    out[:, 0] = lab[:, 0] + dl * amt
    C, h = hue_toward(lab[:, 1], lab[:, 2], np.where(lit, h_light, h_shadow), np.abs(amt))
    C = C * np.where(lit, 1.0 + csat * amt, 1.0 + 0.8 * csat * amt)       # lit: richer; shadow: greyer
    out[:, 1] = C * np.cos(np.radians(h)); out[:, 2] = C * np.sin(np.radians(h))
    return out


def load(k):
    p = os.path.join(ROOT, "assets/town/hx", k + ".png")
    if not os.path.exists(p): p = os.path.join(ROOT, "assets/town", k + ".png")
    return np.array(Image.open(p).convert("RGBA"))


def normals(nat, m, rmp_img=None):
    """The form (owner 2026-11-06: "건물이나 물건의 기본적인 형태감을 고려하고"): the sprite is split into its parts
    (connected runs of one material ramp: a roof, a beam, a plank wall, a barrel, a chimney) and each part is shaped
    by its own size -- narrow parts (posts, beams, barrels, chimneys, trunks) round across their width like
    cylinders, wide parts (walls, roof planes) stay nearly flat with bevelled edges, a roof seen face-on splits into a
    left and a right slope at its ridge. A soft silhouette dome ties the whole together."""
    h, w = m.shape
    nx = np.zeros((h, w)); ny = np.zeros((h, w))
    if rmp_img is not None:
        for r in np.unique(rmp_img[m]):
            lab, n = ndi.label((rmp_img == r) & m)
            for i in range(1, n + 1):
                reg = lab == i
                area = reg.sum()
                if area < 6: continue
                ys, xs = np.nonzero(reg)
                x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
                rw, rh = x1 - x0 + 1, y1 - y0 + 1
                # across: per row, -1 at the left edge .. +1 at the right edge of the part
                for y in range(y0, y1 + 1):
                    row = np.nonzero(reg[y])[0]
                    if len(row) == 0: continue
                    c = (row.min() + row.max()) / 2.0; hw_ = max(1.0, (row.max() - row.min()) / 2.0)
                    t = (row - c) / hw_
                    narrow = hw_ < 9.0
                    if r == 0 and hw_ > 12:          # a roof face-on: two planes meeting at the ridge
                        nx[y, row] += np.sign(t) * 0.55 + t * 0.15
                    elif narrow:                      # a post, a beam, a barrel stave group, a chimney: a cylinder
                        nx[y, row] += np.sin(np.clip(t, -1, 1) * np.pi / 2) * 0.85
                    else:                             # a wall or a panel: flat, bevelled at its sides
                        edge = np.minimum(row - row.min(), row.max() - row) < 1.5      # the outer cell on each side
                        nx[y, row] += np.sign(t) * edge * 0.6
                # down: the top of a part turns up a little (light from above catches it), the bottom away
                for x in range(x0, x1 + 1):
                    col = np.nonzero(reg[:, x])[0]
                    if len(col) == 0: continue
                    c = (col.min() + col.max()) / 2.0; hh_ = max(1.0, (col.max() - col.min()) / 2.0)
                    t = (col - c) / hh_
                    ny[col, x] += np.clip((np.abs(t) - 0.6) / 0.4, 0, 1) * np.sign(t) * (0.5 if hh_ < 9 else 0.3)
    H0 = max(3.0, min(14.0, min(h, w) * 0.18))
    d = np.minimum(ndi.distance_transform_edt(m), H0) / H0
    hgt = np.sqrt(np.clip(1.0 - (1.0 - d) ** 2, 0, 1)) * H0
    dx = -ndi.sobel(hgt, 1) / 8.0; dy = -ndi.sobel(hgt, 0) / 8.0
    N = np.stack([nx + 0.35 * dx, ny + 0.35 * dy, np.full((h, w), 0.6)], -1)
    return norm(N)


def write(k, a, nat, m, cols, tag):
    big = np.repeat(np.repeat(nat, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
    out = a.copy(); out[..., :3] = 0
    out[:big.shape[0], :big.shape[1], :3] = big[..., :3]
    out[..., 3] = a[..., 3]
    os.makedirs(os.path.join(ROOT, "assets/town/lit"), exist_ok=True)
    Image.fromarray(out).save(os.path.join(ROOT, "assets/town/lit", f"{k}_{tag}.png"))


def masses(m, rimg, lab_img):
    """The big masses first (owner 2026-11-07: "자잘한 곳이 먼저가 아니라 큰 덩어리를 기준으로 빛이 들어올 수 있는가 없는가를
    먼저"): a 2.5-D height toward the camera for each big block, and the block's own facing.
      roof   = the red parts that reach the top of their column: it leans out to the eave (z 2 at the ridge -> 8 at
               the eave), faces up, and a face-on gable splits into a left and a right plane at its ridge
      tower  = stone / brick rising to the top of its column above the roof line (chimney, the forge stack): z 7,
               rounded across like a box with two side faces
      walls  = everything else at z 0 facing the camera; dark openings (doors, windows) sit back at z -1
    Returns z (cells) and the mass normals."""
    h, w = m.shape
    z = np.zeros((h, w)); N = np.zeros((h, w, 3)); N[..., 2] = 1.0
    top = np.full(w, h)
    for x in range(w):
        c = np.nonzero(m[:, x])[0]
        if len(c): top[x] = c.min()
    L = lab_img[..., 0]
    z[m & (L < 22.0)] = -1.0
    for r, kind in ((0, "roof"), (STONE, "tower")):
        # one block = this material with its own tile / mortar lines closed over (the dark seams between roof tiles or
        # stones are part of the block, not a gap in it)
        # the 1-cell dark seams between tiles / stones are closed over; a beam or an eave board (2+ cells) still cuts
        blk = ndi.binary_closing((rimg == r) & m, np.ones((2, 2)), iterations=1) & m
        lab_, n = ndi.label(blk)
        for i in range(1, n + 1):
            reg = lab_ == i
            ys, xs = np.nonzero(reg)
            if len(ys) < 30: continue
            cols_ = np.unique(xs)
            ctop = np.array([ys[xs == x].min() for x in cols_])
            reach = (ctop <= top[cols_] + 3).mean()          # how much of the block is the top of the building
            if reach < 0.5: continue
            if kind == "roof":
                # the roof plane faces where its top edge falls: a flat ridge = one plane looking up at us, a gable =
                # the left plane looking left and the right one right, a hipped wing = toward its low side
                ct = np.array([ys[xs == x].min() for x in cols_], float)
                ct = ndi.uniform_filter1d(ct, 9, mode="nearest")
                g = np.gradient(ct)
                for x, gx in zip(cols_, g):
                    col = ys[xs == x]; yt, yb = col.min(), col.max()
                    v = (col - yt) / max(1.0, yb - yt)
                    z[col, x] = 2.0 + 9.0 * v
                    N[col, x] = norm(np.array([float(np.clip(gx * 1.2, -0.7, 0.7)), -0.55, 0.65]))
            else:
                if (xs.max() - xs.min()) > w * 0.35: continue
                z[ys, xs] = 7.0
                cx = (xs.min() + xs.max()) / 2.0; hw = max(1.0, (xs.max() - xs.min()) / 2.0)
                t = (xs - cx) / hw
                N[ys, xs] = norm(np.stack([np.sign(t) * (np.abs(t) > 0.35) * 0.7, np.full(len(t), -0.1), np.full(len(t), 0.7)], -1))
    return z, N


def lit_mask(m, z, Ld, reach=60):
    """can the sun reach this cell? march toward the light over the height field; a higher block in the way = shade"""
    h, w = m.shape
    ys, xs = np.nonzero(m)
    dxy = np.hypot(Ld[0], Ld[1]); sx, sy = Ld[0] / dxy, Ld[1] / dxy; rise = Ld[2] / dxy
    z0 = z[ys, xs]
    shade = np.zeros(len(ys), bool)
    for t in range(1, reach):
        X = np.round(xs + sx * t).astype(int); Y = np.round(ys + sy * t).astype(int)
        ok = (X >= 0) & (X < w) & (Y >= 0) & (Y < h)
        zz = np.full(len(ys), -9.0); zz[ok] = np.where(m[Y[ok], X[ok]], z[Y[ok], X[ok]], -9.0)
        shade |= zz > z0 + rise * t + 0.5
    return ~shade


def bake(k, box, lights):
    a = load(k)
    nat0 = a[0::2, 0::2].copy()
    m = nat0[..., 3] > 127
    if not m.any(): return
    ys, xs = np.nonzero(m)
    cols = nat0[m][:, :3]
    lab = rgb2lab(cols[None].astype(float) / 255.0)[0]
    rmp = ramp_of(lab)
    rimg = np.full(m.shape, -1); rimg[m] = rmp
    N = normals(nat0, m, rimg)
    Nm = N[m]
    looks = {
        # tag: (side sign, light hue, shadow hue, lightness range, saturation gain, strength)
        "m": (-1.0, 85.0, 285.0, 17.0, 0.45, 1.0),       # owner 2026-11-07: "더 세게 ... 대비가 강하게"
        "e": (1.0, 55.0, 300.0, 20.0, 0.55, 1.2),
    }
    lab_img = np.zeros(m.shape + (3,)); lab_img[m] = lab
    Z, NM = masses(m, rimg, lab_img)
    NMm = NM[m]
    for tag, (sg, hl, hs, dl, cs, st) in looks.items():
        Ld = norm(np.array([sg * 0.8, -0.38, 0.42]))            # the low sun: from the side, a little above
        # 1) the big blocks: can the sun reach it at all (cast shade from roofs, eaves, chimneys), and how does the
        #    block face it -- this decides light or shade; 2) only then the small parts' own turning, weakly
        sun = lit_mask(m, Z, Ld)[...]
        big = np.clip(2.6 * st * (NMm @ Ld - Ld[2]), -0.9, 0.9)
        small = np.clip(2.0 * (Nm @ Ld - Ld[2]), -0.5, 0.5)
        amt = np.where(sun, np.clip(0.3 * st + big + 0.25 * small, -0.9, 1.0), -0.85 * st + 0.15 * small)
        amt = np.where(np.abs(amt) < 0.08, 0.0, np.clip(amt, -1, 1))
        tgt = shade(lab, amt, hl, hs, dl, cs)
        nat = nat0.copy()
        new = np.array([snap(tgt[i], rmp[i], amt[i] > 0) if amt[i] != 0 else cols[i] for i in range(len(cols))])
        nat[m, :3] = new
        write(k, a, nat, m, cols, tag)
    # night: moon from above-left, then the town's lights near this sprite
    moon = norm(np.array([-0.35, -0.8, 0.5]))
    amt = np.clip((Nm @ moon - 0.62) * 2.2, -1, 1) * 0.6 - 0.15                 # mostly a touch dimmer and cooler
    tgt = shade(lab, amt, 230.0, 270.0, 7.0, 0.25)
    warmth = np.zeros(len(cols)); whue = np.zeros(len(cols)); wsum = np.zeros(len(cols))
    if box is not None:
        X = box[0] + xs * 2.0 + 1.0; Y = box[1] + ys * 2.0 + 1.0
        for (kind, lx, ly, r, cr, cg, cb, la) in lights:
            if kind == "soft": continue
            dx = lx - X; dy = ly - Y
            dist = np.hypot(dx, dy)
            R = r * (1.6 if kind in ("lamp", "fire") else (0.75 if kind == "win" else 1.1))
            if kind == "win": la = la * 0.55            # a window spills a soft glow on the wall around it
            near = dist < R
            if not near.any(): continue
            Lv = norm(np.stack([dx, dy, np.full_like(dx, 60.0)], -1))
            facing = np.clip((Nm * Lv).sum(-1), 0, 1)
            I = la * (1.0 - dist / R) ** 2 * (0.35 + 0.65 * facing) * near
            lc = rgb2lab(np.array([[[cr, cg, cb]]]))[0, 0]
            h_l = np.degrees(np.arctan2(lc[2], lc[1]))
            warmth += I; whue += I * h_l; wsum += I
    lit = warmth > 0.05
    if lit.any():
        w = np.clip(warmth[lit], 0, 1.3)
        hl = whue[lit] / np.maximum(wsum[lit], 1e-6)
        t2 = tgt[lit].copy()
        t2[:, 0] = lab[lit, 0] + 30.0 * w                                    # back up out of the night, toward the light
        C, h = hue_toward(lab[lit, 1], lab[lit, 2], hl, np.minimum(1.0, w * 1.2))
        C = C * (1.0 + 0.6 * w)
        t2[:, 1] = C * np.cos(np.radians(h)); t2[:, 2] = C * np.sin(np.radians(h))
        tgt[lit] = t2
    nat = nat0.copy()
    new = np.array([snap(tgt[i], rmp[i], bool(lit[i])) for i in range(len(cols))])
    nat[m, :3] = new
    write(k, a, nat, m, cols, "n")
    print(k, "cells", m.shape[::-1], "lit by", int(lit.sum()), "cells at night")


def main():
    L = json.load(open(sys.argv[1]))
    lights = L["lights"]
    seen = set()
    for b in L["bld"] + [L["hall"]]:
        k = b[0]
        if k in seen or k in ("g_tentR", "g_ring"): continue        # tents move (cloth); the ring is under the fire
        seen.add(k)
        bake(k, (b[1], b[2]), lights)
    for k in GENERIC:
        if k not in seen: bake(k, None, lights)


main()
