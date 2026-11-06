#!/usr/bin/env python3
"""Light from structure (owner 2026-11-07: "빛 이론의 기본 구조는 큰 덩어리, 그리고 그 이후에 빛 영역에서의 세부 그림자
표현"; the rules: docs/work/town-art/LIGHT.md). A building's solid form is written by hand (tools/proxy/<sprite>.json:
its walls, roof planes, eaves, chimneys as planes with a depth), never guessed from the picture. Then, per look:
  1. big masses: each plane's facing to the sun (N . L) gives the whole plane ONE light level
  2. cast shadow: from each cell, a ray toward the sun, tested exactly against the building's SOLIDS ("solids": boxes
     and roof prisms with their real depth, not faces with a guessed thickness): any solid on the way = shade
     (eaves over walls, chimneys on the roof, the gable's roof on the wings)
  3. detail, inside the light only: a plane's small relief by material ("relief": timbers out of the plaster, panes
     sunk in their frames) throws one-step shadows a few cells long, and the relief's edge turned to the sun gets +1
  4. colour: the level moves each pixel along ITS material ramp (never "the nearest colour"): the ramps are cool and
     greyer at the dark end and warm and richer at the light end (tools/town_palette2.py), so a step is a move in
     value, hue, saturation and temperature together. Off-palette colours: none.
Light levels (relative to the art as drawn, which is the noon look), each a change of lightness (DL, Lab L) taken as
the nearest step of the pixel's own ramp:
  sunlit, facing the sun squarely (N.L > .75)  +2
  sunlit (N.L > .3)                            +1
  sunlit, glancing                             0 (the evening's orange is the ambient's, lit.gd: not a second step)
  shade, facing up (sees the sky)              -1
  shade, facing front / down                   -2
  rim: the silhouette's sun-side edge          at least +1 (a backlit edge glows)
  night: -1 everywhere, then each lamp, fire, window: +1 / +2 / +3 by its light on the cell (facing it, unblocked,
         falling off with distance)
  python3 tools/light_proxy.py diagram g_hall OUT.png        the proxy over the sprite (planes by facing)
  python3 tools/light_proxy.py bake g_hall [--preview OUT]   assets/town/lit/g_hall_{m,e,n}.png"""
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = np.array(Image.open(os.path.join(ROOT, "assets/town/palette.png")).convert("RGB"))
PJ = json.load(open(os.path.join(ROOT, "assets/town/palette.json")))
RAMPS = [PAL[i, :s] for i, s in enumerate(PJ["steps"])]
INDEX = {}
for ri, r in enumerate(RAMPS):
    for si, c in enumerate(r): INDEX.setdefault(tuple(int(v) for v in c), (ri, si))


def sun3(h):
    """lit.gd sun3: toward the sun, x right, y up, z toward the viewer"""
    day = np.clip((h % 24.0 - 5.5) / 13.5, 0.0, 1.0)
    ang = day * np.pi
    el = np.radians(16.0 + 46.0 * np.sin(ang))
    hz = np.array([-np.cos(ang), -0.6 + 1.0 * np.sin(ang)]); hz /= np.linalg.norm(hz)
    return np.array([hz[0] * np.cos(el), np.sin(el), hz[1] * np.cos(el)])


CELL = {}


def load_sprite(k):
    """the sprite's cells: 2-px cells when it is drawn on the town's 2-px grid, else its own pixels"""
    p = os.path.join(ROOT, "assets/town/hx", k + ".png")
    if not os.path.exists(p): p = os.path.join(ROOT, "assets/town", k + ".png")
    a = np.array(Image.open(p).convert("RGBA"))
    b = a[0::2, 0::2]
    if (np.repeat(np.repeat(b, 2, 0), 2, 1)[:a.shape[0], :a.shape[1]] == a).all():
        CELL[k] = 2; return b.copy()
    CELL[k] = 1
    return a


def from_spec(spec):
    """a building's proxy from a few numbers per part (tools/proxy/specs.json):
      wall  r [x0,y0,x1,y1], z (front), d (depth): a front face and the box behind it
      roof  poly (its outline), eave (y), z (depth at the eave), pitch (dz per cell up), d: a roof sloping down
            toward the viewer and its solid prism (back slope as deep again)
      gable apex, l, r ([x,y] its top and eave ends), z, d, w (verge width): a gable end facing the viewer, its verge
            boards turned left / right, and the roof behind it running back d cells
      box   r, z [back, front], cap (rows of top face): a chimney, a block
      top   r, z: a face turned up (a sill, a step, a rim)
      cyl   r, z, d: an upright round thing (barrel, post, pot)
      dome  c [x, ground y], rad, z: a dome (the kiln)
    each part may carry "relief" (as in the planes) and "reach" (its shadow's longest run)"""
    planes, solids = [], []
    for p in spec:
        t = p["t"]; nm = p.get("name", t)
        if t == "wall":
            x0, y0, x1, y1 = p["r"]; z = p.get("z", 0); d = p.get("d", 80)
            pl = {"name": nm, "poly": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": z, "thick": d}
            if "relief" in p: pl["relief"] = p["relief"]
            planes.append(pl)
            if not p.get("nosolid"): solids.append({"name": nm, "xy": pl["poly"], "z": [z - d, z]})
        elif t == "roof":
            e = p["eave"]; z = p["z"]; k_ = p.get("pitch", 0.84); d = p.get("d", 80)
            top = min(q[1] for q in p["poly"])
            planes.append({"name": nm, "poly": p["poly"], "at": [0, e], "z": z, "dzdy": k_, "thick": d})
            ridge_z = z - k_ * (e - top)
            solids.append({"name": nm, "xy": p["poly"], "yz": [[e + 1, z + 1], [top, ridge_z], [e + 1, ridge_z - (z - ridge_z) - 2]]})
        elif t == "gable":
            (ax, ay), (lx, ly), (rx, ry) = p["apex"], p["l"], p["r"]; z = p.get("z", 8); d = p.get("d", 80); w = p.get("w", 7)
            planes.append({"name": nm + " wall", "poly": [[ax, ay + w], [rx - w, ry], [lx + w, ly]], "z": z, "thick": d})
            def strip(x0, y0, x1, y1):
                return [[x0, y0], [x1, y1], [x1, y1 + w], [x0, y0 + w]]
            planes.append({"name": nm + " verge L", "poly": strip(ax, ay, lx, ly), "z": z + 3, "n": [-0.72, 0.69, 0.08], "thick": d})
            planes.append({"name": nm + " verge R", "poly": strip(ax, ay, rx, ry), "z": z + 3, "n": [0.72, 0.69, 0.08], "thick": d})
            solids.append({"name": nm, "xy": [[ax, ay], [rx, ry + w], [lx, ly + w]], "z": [z - d, z + 3]})
        elif t == "box":
            x0, y0, x1, y1 = p["r"]; zb, zf = p["z"]; cap = p.get("cap", 0)
            planes.append({"name": nm, "poly": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": zf, "thick": zf - zb})
            if cap: planes.append({"name": nm + " top", "poly": [[x0, y0], [x1, y0], [x1, y0 + cap], [x0, y0 + cap]], "z": zf, "n": [0, 1, 0.25], "thick": zf - zb})
            so = {"name": nm, "xy": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": [zb, zf]}
            if "reach" in p: so["reach"] = p["reach"]
            solids.append(so)
        elif t == "top":
            x0, y0, x1, y1 = p["r"]
            planes.append({"name": nm, "poly": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": p.get("z", 0), "n": [0, 1, 0.15], "thick": 20})
        elif t == "cyl":
            x0, y0, x1, y1 = p["r"]; z = p.get("z", 0); d = p.get("d", (x1 - x0))
            planes.append({"name": nm, "poly": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": z, "cyl": [x0, x1], "thick": d})
            if not p.get("nosolid"): solids.append({"name": nm, "xy": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "z": [z - d, z]})
        elif t == "dome":
            cx, cy = p["c"]; R = p["rad"]; z = p.get("z", 0)
            planes.append({"name": nm, "poly": [[cx - R, cy - R], [cx + R, cy - R], [cx + R, cy], [cx - R, cy]], "z": z, "dome": [cx, cy, R], "thick": R})
    return {"planes": planes, "solids": solids}


def load_proxy(k, shape=None):
    f = os.path.join(ROOT, "tools/proxy", k + ".json")
    if os.path.exists(f): return json.load(open(f))
    specs = json.load(open(os.path.join(ROOT, "tools/proxy/specs.json")))
    if k in specs: return from_spec(specs[k])
    # a prop with no spec: a block (its top rows face up), or a round thing when its name says so
    h, w = shape
    round_ = any(t in k for t in ("barrel", "pot", "lamp"))
    return from_spec([{"t": "cyl" if round_ else "box", "r": [0, 0, w, h], "z": [-w * 0.8, 0] if not round_ else 0, "cap": max(2, h // 8)}]
                     + ([{"t": "top", "r": [0, 0, w, max(2, h // 10)]}] if round_ else []))


def proxy_maps(k, shape):
    """per cell: plane id, normal, depth z, thickness"""
    P = load_proxy(k, shape)
    h, w = shape
    pid = np.full((h, w), -1, int); N = np.zeros((h, w, 3)); Z = np.zeros((h, w)); T = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    for i, pl in enumerate(P["planes"]):
        im = Image.new("L", (w, h), 0)
        ImageDraw.Draw(im).polygon([tuple(p) for p in pl["poly"]], fill=255)
        m = np.array(im) > 0
        at = pl.get("at", [0, 0]); a = pl.get("dzdx", 0.0); b = pl.get("dzdy", 0.0)
        z = pl["z"] + a * (xx - at[0]) + b * (yy - at[1])
        if "cyl" in pl:                       # an upright cylinder across the poly's width: its facing turns with x
            x0, x1 = pl["cyl"]; u = np.clip((xx - (x0 + x1) / 2.0) / max((x1 - x0) / 2.0, 1.0), -0.95, 0.95)
            n = np.stack([u, np.zeros_like(u), np.sqrt(1 - u * u)], -1)
            pid[m] = i; N[m] = n[m]; Z[m] = z[m]; T[m] = pl.get("thick", 10); continue
        if "dome" in pl:                      # a dome (centre x, ground y, radius): faces turn all round
            cx, cy, R = pl["dome"]; u = (xx - cx) / R; v = (cy - yy) / R
            w = np.sqrt(np.clip(1 - u * u - v * v, 0.02, 1))
            n = np.stack([u, v, w], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
            pid[m] = i; N[m] = n[m]; Z[m] = z[m]; T[m] = pl.get("thick", 10); continue
        n = np.array(pl["n"], float) if "n" in pl else np.array([-a, b, 1.0])
        n /= np.linalg.norm(n)
        pid[m] = i; N[m] = n; Z[m] = z[m]; T[m] = pl.get("thick", 10)
    return P, pid, N, Z, T


def relief_map(nat, P, pid):
    """the small relief inside a plane (its "relief": {ramp name: cells out (+) or in (-)}): timbers standing out of
    the plaster, window panes sunk behind their frames. Only the detail pass sees it."""
    R = np.zeros(pid.shape)
    names = PJ["names"]
    ys, xs = np.nonzero(pid >= 0)
    for y, x in zip(ys, xs):
        rel = P["planes"][pid[y, x]].get("relief")
        if not rel: continue
        c = tuple(int(v) for v in nat[y, x, :3])
        if c in INDEX: R[y, x] = rel.get(names[INDEX[c][0]], 0.0)
    return R


def in_sun(ys, xs, Z, T, solid, L, reach=160, t0=2):
    """march each cell's ray toward the sun through the proxy: it is in shade when it passes inside a solid"""
    h, w = Z.shape
    d = L / max(np.hypot(L[0], L[1]), 1e-6)            # per cell of screen travel
    z0 = Z[ys, xs]
    shade = np.zeros(len(ys), bool)
    for t in np.arange(t0, reach, 0.5):          # half-cell steps: a ray must not slip past a thin edge
        X = np.round(xs + d[0] * t).astype(int); Y = np.round(ys - d[1] * t).astype(int)
        ok = (X >= 0) & (X < w) & (Y >= 0) & (Y < h)
        zr = z0 + d[2] * t
        zs = np.full(len(ys), -1e9); th = np.zeros(len(ys)); s = np.zeros(len(ys), bool)
        zs[ok] = Z[Y[ok], X[ok]]; th[ok] = T[Y[ok], X[ok]]; s[ok] = solid[Y[ok], X[ok]]
        shade |= s & (zr < zs - 0.5) & (zr > zs - th)
    return ~shade


def solids_of(P):
    """the building as true solids ("solids" in the proxy): each the intersection of extrusions -- "xy": a convex
    outline on screen pushed through the depth, "yz": a convex section (screen y, depth z) pushed along x, "z": a depth
    range [back, front]; "reach": the longest shadow it throws, in cells (a small part's shadow is kept short and
    tidy, as a pixel artist keeps it: the long thin wedge of a low sun across a whole roof reads as a stain).
    Returned as half-spaces a.(x, y, z) <= c in screen cells (y down)."""
    out = []
    for so in P.get("solids", []):
        H = []
        def poly(pts, axes):
            pts = np.array(pts, float); c = pts.mean(0)
            for i in range(len(pts)):
                p0, p1 = pts[i], pts[(i + 1) % len(pts)]
                e = p1 - p0; nrm = np.array([e[1], -e[0]])
                if nrm @ (c - p0) > 0: nrm = -nrm               # outward
                a = np.zeros(3); a[axes[0]] = nrm[0]; a[axes[1]] = nrm[1]
                H.append((a, nrm @ p0))
        if "xy" in so: poly(so["xy"], (0, 1))
        if "yz" in so: poly(so["yz"], (1, 2))
        if "z" in so:
            H.append((np.array([0, 0, -1.0]), -so["z"][0])); H.append((np.array([0, 0, 1.0]), so["z"][1]))
        out.append((so.get("name", ""), H, so.get("reach", 1e9)))
    return out


def sunlit(ys, xs, Z, L, solids, eps=0.75):
    """a ray from each visible cell toward the sun: in shade when it passes through any solid (exact, no marching)"""
    if not solids: return np.ones(len(ys), bool)
    P0 = np.stack([xs.astype(float), ys.astype(float), Z[ys, xs]], -1)
    D = np.array([L[0], -L[1], L[2]])
    hit = np.zeros(len(ys), bool)
    for sol in solids:
        H = sol[1]; reach = sol[2] if len(sol) > 2 else 1e9
        t0 = np.full(len(ys), -1e9); t1 = np.full(len(ys), 1e9)
        for a, c in H:
            den = a @ D; num = c - P0 @ a
            if abs(den) < 1e-9:
                t1 = np.where(num < 0, -1e9, t1); continue
            t = num / den
            if den > 0: t1 = np.minimum(t1, t)
            else: t0 = np.maximum(t0, t)
        hit |= (t1 > np.maximum(t0, eps) + 0.25) & (np.maximum(t0, eps) < reach)
    return ~hit


def levels_sun(N, Z, T, m, solid, h, evening, R=None, solids=None):
    L = sun3(h)
    ys, xs = np.nonzero(m)
    n = N[ys, xs]
    ndl = n @ L
    # 1. the big masses: a plane's facing, and what the big solids throw on it
    sun = (ndl > 0.05) & (sunlit(ys, xs, Z, L, solids) if solids else in_sun(ys, xs, Z, T, solid, L))
    lv = np.zeros(len(ys), int)
    up = n[:, 1] > 0.45
    lv[sun & (ndl > 0.3)] = 1
    lv[sun & up & (ndl > 0.2)] = 1                 # a roof that sees the sun at all reads as lit
    lv[sun & (ndl > 0.75)] = 2
    lv[~sun & up] = -1                             # shade that sees the sky
    lv[~sun & ~up] = -2
    # rim: the sun-side edge of the silhouette catches the light even when the face behind it is turned away (backlit
    # edges glow); one cell, on the outline facing the sun and on the tops when the sun is up
    h_, w_ = m.shape
    sx = 1 if L[0] > 0.15 else (-1 if L[0] < -0.15 else 0)
    def outside(dx, dy):
        X = xs + dx; Y = ys + dy
        ok = (X >= 0) & (X < w_) & (Y >= 0) & (Y < h_)
        r = np.ones(len(ys), bool); r[ok] = ~m[Y[ok], X[ok]]
        return r
    rim = np.zeros(len(ys), bool)
    if sx != 0: rim |= outside(sx, 0)
    if L[1] > 0.2: rim |= outside(0, -1)
    rim &= ndl > -0.45
    lv[rim] = np.maximum(lv[rim], 1)
    # 2. the detail, only inside the light: timbers throw a short shadow on the plaster and into the window recesses
    #    (one step: it must not break the mass), and the timber edge turned to the sun catches it (+1)
    if R is not None and R.any():
        Zd = Z + R
        det = sun & ~in_sun(ys, xs, Zd, T, solid, L, reach=10, t0=1)
        lv[det] -= 1
        d = L / max(np.hypot(L[0], L[1]), 1e-6)
        sx = int(np.sign(np.round(d[0]))); sy = -int(np.sign(np.round(d[1] * 0.999)))
        nx = np.clip(xs + sx, 0, Z.shape[1] - 1); ny = np.clip(ys + sy, 0, Z.shape[0] - 1)
        edge = sun & ~det & (R[ys, xs] > 0) & (R[ny, nx] < R[ys, xs] - 0.5)
        lv[edge] += 1
    out = np.zeros(m.shape, int); out[ys, xs] = lv
    return out, sun, ys, xs, ndl


# a light level as a change of lightness (Lab L): the same for every material, so a pale plaster in shade drops as far
# as a red roof does (its ramp's steps are closer together); the step taken is the one in the pixel's OWN ramp nearest
# to that lightness (brightness order, never another material)
DL = {3: 21.0, 2: 14.0, 1: 7.0, 0: 0.0, -1: -11.0, -2: -22.0, -3: -30.0}
from skimage.color import rgb2lab
RL = [rgb2lab(r[None].astype(float) / 255.0)[0][:, 0] for r in RAMPS]


def recolor(nat, m, lv, extra=None):
    out = nat.copy()
    ys, xs = np.nonzero(m)
    miss = 0
    for y, x in zip(ys, xs):
        c = tuple(int(v) for v in nat[y, x, :3])
        if c not in INDEX: miss += 1; continue
        ri, si = INDEX[c]
        k = int(np.clip(lv[y, x] + (0 if extra is None else extra[y, x]), -3, 3))
        if k == 0: continue
        s2 = int(np.abs(RL[ri] - (RL[ri][si] + DL[k])).argmin())
        if k > 0: s2 = max(s2, min(si + 1, len(RL[ri]) - 1))      # a step of light always shows
        else: s2 = min(s2, max(si - 1, 0))
        out[y, x, :3] = RAMPS[ri][s2]
    return out, miss


def diagram(k, outp):
    nat = load_sprite(k)
    m = nat[..., 3] > 127
    P, pid, N, Z, T = proxy_maps(k, m.shape)
    col = np.zeros(m.shape + (3,))
    col[:] = (N * 0.5 + 0.5)              # normal as colour: x red, y green, z blue
    grey = nat[..., :3].mean(-1, keepdims=True) / 255.0
    img = (0.35 * grey + 0.65 * col) * 255
    img[~m] = (40, 46, 52)
    big = Image.fromarray(img.astype(np.uint8)).resize((m.shape[1] * 3, m.shape[0] * 3), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for pl in P["planes"]:
        pts = [(p[0] * 3, p[1] * 3) for p in pl["poly"]]
        d.line(pts + [pts[0]], fill=(255, 255, 255), width=1)
    big.save(outp)


def bake(k, preview=None, lights=None, box=None):
    nat = load_sprite(k)
    m = nat[..., 3] > 127
    P, pid, N, Z, T = proxy_maps(k, m.shape)
    solid = (pid >= 0) & m
    out = {}
    R = relief_map(nat, P, pid)
    for tag, h in (("m", 7.5), ("e", 17.5)):
        lv, _, _, _, _ = levels_sun(N, Z, T, m & (pid >= 0), solid, h, tag == "e", R, solids_of(P))
        img, miss = recolor(nat, m & (pid >= 0), lv)
        out[tag] = img
        print(k, tag, "off-palette cells kept as drawn:", miss)
    # night: the lights near its place in the town (a prop without a place: moonlight only)
    out["n"] = bake_night(nat, m, pid, N, Z, T, solid, lights if box is not None else [], box or (0, 0))
    for tag, img in out.items():
        c = CELL.get(k, 2)
        big = np.repeat(np.repeat(img, c, 0), c, 1)
        Image.fromarray(big).save(os.path.join(ROOT, "assets/town/lit", f"{k}_{tag}.png"))
    if preview:
        row = [nat] + [out[t] for t in ("m", "e", "n") if t in out]
        W = sum(r.shape[1] for r in row) + 8 * (len(row) - 1)
        canvas = Image.new("RGBA", (W, nat.shape[0]), (60, 80, 90, 255))
        x = 0
        for r in row:
            canvas.alpha_composite(Image.fromarray(r), (x, 0)); x += r.shape[1] + 8
        canvas.resize((W * 2, nat.shape[0] * 2), Image.NEAREST).save(preview)


def bake_night(nat, m, pid, N, Z, T, solid, lights, box):
    """night: one step down everywhere (no sun), then every lamp, fire and window near it: + by its light on the cell"""
    ys, xs = np.nonzero(m & (pid >= 0))
    lv = np.full(m.shape, -1, int)
    add = np.zeros(len(ys))
    P3 = np.stack([xs.astype(float), -ys.astype(float), Z[ys, xs]], -1)
    n = N[ys, xs]
    for (kind, lx, ly, r, cr, cg, cb, la) in lights:
        if kind == "soft": continue
        cx = (lx - box[0]) / 2.0; cy = (ly - box[1]) / 2.0
        reach = r * (0.9 if kind == "win" else 1.4) / 2.0
        if cx < -reach or cy < -reach or cx > m.shape[1] + reach or cy > m.shape[0] + reach: continue
        lz = 30.0 if kind in ("lamp", "fire", "bulb") else 18.0      # lamps stand in front of the walls
        lp = np.array([cx, -cy, lz])
        v = lp - P3; dist = np.linalg.norm(v, axis=-1); v /= np.maximum(dist[:, None], 1e-6)
        face = np.clip((n * v).sum(-1), 0, 1)
        if kind == "win": face = np.where(n[:, 2] > 0.9, np.maximum(face, 0.6), 0.0)   # its own wall, never the roof
        fall = np.clip(1.0 - dist / reach, 0, 1) ** 1.5
        add += la * face * fall * (0.5 if kind == "win" else 1.6)
    step = np.where(add > 1.1, 3, np.where(add > 0.55, 2, np.where(add > 0.18, 1, 0)))
    lv[ys, xs] += step
    img, miss = recolor(nat, m & (pid >= 0), lv)
    return img


ALL = ["g_hall", "g_store", "g_barn", "g_cottage", "g_well", "g_forge", "g_kiln", "g_anvil", "q_fountain", "g_wagon2",
       "q_crateL", "q_crateS", "q_barrelL", "q_barrelM", "q_barrelS", "q_bench", "q_board", "q_planter", "q_pot", "q_lamp_base"]


if __name__ == "__main__":
    cmd, k = sys.argv[1], sys.argv[2]
    if cmd == "all":                       # every town sprite that takes the light: python3 tools/light_proxy.py all OUTDIR
        L = json.load(open(os.path.join(ROOT, "docs/work/town-art/light_layout.json")))
        os.makedirs(k, exist_ok=True)
        for kk in ALL:
            box = None
            for b in L["bld"] + [L["hall"]]:
                if b[0] == kk: box = (b[1], b[2])
            bake(kk, os.path.join(k, kk + ".png"), L["lights"], box)
            diagram(kk, os.path.join(k, kk + "_proxy.png"))
        sys.exit(0)
    if cmd == "diagram": diagram(k, sys.argv[3])
    elif cmd == "bake":
        pv = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
        L = json.load(open(os.path.join(ROOT, "docs/work/town-art/light_layout.json")))
        box = None
        for b in L["bld"] + [L["hall"]]:
            if b[0] == k: box = (b[1], b[2])
        bake(k, pv, L["lights"], box)
