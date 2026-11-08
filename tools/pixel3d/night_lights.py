#!/usr/bin/env python3
"""Puts the town's night lights near a pixel3d solid into its viewer page (HALL.NIGHT_LIGHTS), from where the town
draws it (docs/work/town-art/light_layout.json, tests/dump_light_layout.gd in the game repo).
  python3 tools/pixel3d/night_lights.py LAYOUT.json PAGE.html KEY B0 TOP UPX W H [AT]
KEY: the town sprite; AT: which placement (its game x) when the sprite is drawn in several places (each then gets
its own night look: lit/<KEY>_n_<AT>.png); B0, TOP: the module's foot row and sky rows (as the viewer takes them);
UPX: game px per module unit (2 the buildings, 1 the props); W, H: the sprite in game px. A light stands 20 units
in front of the solid's plane; the ones that reach it, nearest first (the viewer takes 8 for its rims)."""
import json, sys, math
L = json.load(open(sys.argv[1])); page, key = sys.argv[2], sys.argv[3]
B0, TOP, UPX, SW, SH = (float(v) for v in sys.argv[4:9])
AT = float(sys.argv[9]) if len(sys.argv) > 9 else None
K = 0.12
pl = [p for p in L["p3d"] if p[0] == key and (AT is None or abs(p[1] + 24.0 - AT) < 1.5)]
lights = []
if len(pl) == 1:
    sx, sy = pl[0][1] + 24.0, pl[0][2]
    for kind, gx, gy, r, cr, cg, cb, a in L["lights"]:
        if kind not in ("lamp", "fire", "bulb"): continue
        if key == "q_lamp_base" and sx <= gx <= sx + SW and sy <= gy <= sy + SH: continue   # its own lantern
        reach = r * (1.7 if kind != "bulb" else 1.2)
        dx = max(sx - gx, 0, gx - (sx + SW)); dy = max(sy - gy, 0, gy - (sy + SH))
        dd = math.hypot(dx, dy)
        if dd > reach: continue
        z = 20.0
        wx = (gx - sx) / UPX; yp = B0 + TOP - (gy - sy) / UPX
        lights.append((dd, [round(wx, 1), round(yp + K * z, 1), z, round(reach / UPX, 1), round(a, 2)]))
lights = [l for _, l in sorted(lights, key=lambda t: t[0])]
s = open(page).read()
s = s.replace("const PALETTE = ", f"HALL.NIGHT_LIGHTS = {json.dumps(lights)};\nconst PALETTE = ", 1)
open(page, "w").write(s)
print(key, AT, len(pl), "placements,", len(lights), "lights")
