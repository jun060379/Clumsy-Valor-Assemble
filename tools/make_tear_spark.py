#!/usr/bin/env python3
"""tearPx's void sparkle, sin(xx * 12.9898 + yy * 78.233) * 43758.5453 < 0.02 (fract), in double precision as the
prototype computes it (a float32 GPU cannot): white where it sparkles, art px xx, yy in [-256, 255] -> (xx + 256, yy + 256)."""
import math, os
from PIL import Image
im = Image.new('L', (512, 512), 0)
px = im.load()
for y in range(512):
    for x in range(512):
        h = math.sin((x - 256) * 12.9898 + (y - 256) * 78.233) * 43758.5453
        if h - math.floor(h) < 0.02: px[x, y] = 255
im.save(os.path.join(os.path.dirname(__file__), '..', 'assets', 'fx', 'tear_spark.png'))
