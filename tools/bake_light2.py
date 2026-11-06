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
    cand = [r, neighbour(r, warm)]
    labs = np.concatenate([RLAB[c] for c in cand]); rgbs = np.concatenate([RAMPS[c] for c in cand])
    return rgbs[((labs - target) ** 2).sum(-1).argmin()]


def hue_toward(a, b, h_to, k):
    """rotate the (a, b) hue toward h_to (degrees) by up to k (0..1 of the way, max 1 turn of 35 degrees)"""
    C = np.hypot(a, b); h = np.degrees(np.arctan2(b, a))
    d = ((h_to - h + 180.0) % 360.0) - 180.0
    h2 = h + np.clip(d, -35.0, 35.0) * k
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


def normals(nat, m):
    h, w = m.shape
    H0 = max(3.0, min(14.0, min(h, w) * 0.18))
    d = np.minimum(ndi.distance_transform_edt(m), H0) / H0
    hgt = np.sqrt(np.clip(1.0 - (1.0 - d) ** 2, 0, 1)) * H0
    lum = (0.299 * nat[..., 0] + 0.587 * nat[..., 1] + 0.114 * nat[..., 2]) / 255.0
    hgt = ndi.gaussian_filter(hgt + 0.5 * ndi.gaussian_filter(lum, 1.0) * m, 0.8)
    return norm(np.stack([-ndi.sobel(hgt, 1) / 8.0, -ndi.sobel(hgt, 0) / 8.0, np.full((h, w), 0.55)], -1))


def write(k, a, nat, m, cols, tag):
    big = np.repeat(np.repeat(nat, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
    out = a.copy(); out[..., :3] = 0
    out[:big.shape[0], :big.shape[1], :3] = big[..., :3]
    out[..., 3] = a[..., 3]
    os.makedirs(os.path.join(ROOT, "assets/town/lit"), exist_ok=True)
    Image.fromarray(out).save(os.path.join(ROOT, "assets/town/lit", f"{k}_{tag}.png"))


def bake(k, box, lights):
    a = load(k)
    nat0 = a[0::2, 0::2].copy()
    m = nat0[..., 3] > 127
    if not m.any(): return
    N = normals(nat0, m)
    ys, xs = np.nonzero(m)
    cols = nat0[m][:, :3]
    lab = rgb2lab(cols[None].astype(float) / 255.0)[0]
    rmp = ramp_of(lab)
    Nm = N[m]
    looks = {
        # tag: (side sign, light hue, shadow hue, lightness range, saturation gain, strength)
        "m": (-1.0, 85.0, 285.0, 9.0, 0.30, 1.0),
        "e": (1.0, 55.0, 300.0, 11.0, 0.40, 1.15),
    }
    for tag, (sg, hl, hs, dl, cs, st) in looks.items():
        side = np.clip(sg * Nm[:, 0] * 1.6 * st, -1, 1)
        side = np.where(np.abs(side) < 0.18, 0.0, side)
        # the low sun also warms the faces looking at the camera a little (golden / orange hour); the sides split warm/cool
        amt = np.clip(side + 0.22 * st * (side >= 0), -1, 1)
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
        t2[:, 0] = lab[lit, 0] + 20.0 * w                                    # back up out of the night, toward the light
        C, h = hue_toward(lab[lit, 1], lab[lit, 2], hl, np.minimum(1.0, w * 1.2))
        C = C * (1.0 + 0.45 * w)
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
