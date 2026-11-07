#!/usr/bin/env python3
"""Puts the town's night lights near a pixel3d solid into its viewer page (HALL.NIGHT_LIGHTS), from where the town
draws it (docs/work/town-art/light_layout.json, tests/dump_light_layout.gd in the game repo).
  python3 tools/pixel3d/night_lights.py LAYOUT.json PAGE.html KEY B0 TOP UPX [K]
KEY: the town sprite (one placement only: a sprite drawn in several places shares one night look, so it gets none);
B0, TOP: the module's foot row and sky rows (viewer TOP, with CELL 2 made even with B0); UPX: game px per module unit
(2 for the buildings, 1 for the props). A light stands 20 units in front of the solid's plane."""
import json, sys
L = json.load(open(sys.argv[1])); page, key = sys.argv[2], sys.argv[3]
B0, TOP, UPX = float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]); K = float(sys.argv[7]) if len(sys.argv) > 7 else 0.12
pl = [p for p in L["p3d"] if p[0] == key]
lights = []
if len(pl) == 1:
    sx, sy = pl[0][1] + 24.0, pl[0][2]
    for kind, gx, gy, r, cr, cg, cb, a in L["lights"]:
        if kind not in ("lamp", "fire", "bulb", "win"): continue
        wx = (gx - sx) / UPX; yp = B0 + TOP - (gy - sy) / UPX; z = 20.0
        reach = r * 1.7 / UPX
        if wx < -reach or wx > 2000 / UPX + reach: continue
        if abs(yp) > 4000: continue
        lights.append([round(wx, 1), round(yp + K * z, 1), z, round(reach, 1), round(a, 2)])
s = open(page).read()
s = s.replace("const PALETTE = ", f"HALL.NIGHT_LIGHTS = {json.dumps(lights)};\nconst PALETTE = ", 1)
open(page, "w").write(s)
print(key, len(lights), "lights")
