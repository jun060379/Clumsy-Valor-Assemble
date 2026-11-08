#!/usr/bin/env python3
# python3 tools/split_wide.py
# The ground tiles are drawn 9600 px wide (one piece along the town, no repeat), wider than phones' largest texture
# (owner 2026-11-08, a phone at night: "지면이 사라짐" - a 9600-px texture fails to load there). The full-width
# sources live in assets/town/wide/ (not imported: .gdignore); the game loads them as 2400-px pieces
# assets/town/k_<name>_<i>.png and joins them on the CPU (town.gd _build_ground2), drawing from 2400-px textures.
from PIL import Image
PIECE = 2400
def split(name):
    im = Image.open(f"assets/town/wide/{name}.png")
    n = -(-im.width // PIECE)
    for i in range(n):
        im.crop((i * PIECE, 0, min(im.width, (i + 1) * PIECE), im.height)).save(f"assets/town/{name}_{i}.png")
    print(name, im.size, "->", n, "pieces")
if __name__ == "__main__":
    for k in ("k_lawn", "k_clear", "k_stone"): split(k)
