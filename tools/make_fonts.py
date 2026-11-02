#!/usr/bin/env python3
"""Rebuild the game's Korean fonts from the upstream sources: python3 tools/make_fonts.py [SRC_DIR]

Needs fonttools + brotli (pip install fonttools brotli). The sources are fetched into SRC_DIR (default /tmp/cv-font-src)
the first time; they are not kept in the repo.

  NotoSansKR-Bold.woff2 / NotoSansKR-Black.woff2   Noto Sans KR (noto-cjk SubsetOTF/KR): every modern Hangul syllable
      (U+AC00-D7A3, 11,172), Hangul Jamo, Compatibility Jamo, Latin-1 and the punctuation / arrow / box / shape /
      symbol blocks the UI draws (· — … › Ⅰ-Ⅳ ← → − ≫ Ⓧ ╳ █ ▓ ■ ▶ ◆ ● ★ ♪ ⚠ ✓ 《》「」 …). Every other font ends in one of these.
  NotoSerifKR-Black.woff2 / NotoSerifKR-Bold.woff2   Noto Serif KR (the guild titles / the rune codex), the same ranges, so
      the serif keeps its look for any syllable instead of dropping to the sans.
  DejaVuSans-sym.ttf   DejaVu Sans Bold: the arrows / Misc Symbols / Dingbats Noto Sans KR lacks (☠ ✉ ✂ ☺ …).
  BlackHanSans.woff2   Black Han Sans as published (Google Fonts): it only has 2,581 syllables upstream, so it can't be
      grown; the code puts Noto Sans KR Black behind it for the others.

WOFF2 (Brotli) because the web build is loaded on phones; Godot reads it directly.
"""
import os
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "fonts")
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cv-font-src"
NOTO = "https://raw.githubusercontent.com/notofonts/noto-cjk/main/"
SOURCES = {
    "NotoSansKR-Bold.otf": NOTO + "Sans/SubsetOTF/KR/NotoSansKR-Bold.otf",
    "NotoSansKR-Black.otf": NOTO + "Sans/SubsetOTF/KR/NotoSansKR-Black.otf",
    "NotoSerifKR-Black.otf": NOTO + "Serif/SubsetOTF/KR/NotoSerifKR-Black.otf",
    "NotoSerifKR-Bold.otf": NOTO + "Serif/SubsetOTF/KR/NotoSerifKR-Bold.otf",
    "BlackHanSans-Regular.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/blackhansans/BlackHanSans-Regular.ttf",
    "DejaVuSans-Bold.ttf": "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
}

KOREAN = [
    (0x0020, 0x007E), (0x00A0, 0x00FF),          # ASCII, Latin-1
    (0x1100, 0x11FF),                            # Hangul Jamo
    (0x2000, 0x206F),                            # General Punctuation (· is 00B7; – — … ‹ › ※ ‥)
    (0x2150, 0x218F),                            # Number Forms (Ⅰ-Ⅻ)
    (0x2190, 0x21FF),                            # Arrows
    (0x2200, 0x22FF),                            # Math (− × ≫ ∞)
    (0x2460, 0x24FF),                            # Enclosed Alphanumerics (① Ⓧ)
    (0x2500, 0x25FF),                            # Box Drawing, Blocks, Geometric Shapes
    (0x2600, 0x27BF),                            # Misc Symbols, Dingbats (what Noto has: ★ ☆ ♪ ⚠ ✓ ♥)
    (0x3000, 0x303F),                            # CJK Symbols and Punctuation (《》「」『』〜)
    (0x3130, 0x318F),                            # Hangul Compatibility Jamo
    (0x3200, 0x32FF),                            # Enclosed CJK (㈜ ㉠)
    (0xAC00, 0xD7A3),                            # Hangul Syllables, all 11,172
    (0xFF01, 0xFF5E),                            # fullwidth forms
]


def fetch(name: str) -> str:
    os.makedirs(SRC, exist_ok=True)
    dst = os.path.join(SRC, name)
    src = SOURCES[name]
    if not os.path.exists(dst):
        if src.startswith("/"):
            return src
        print("fetch", src)
        urllib.request.urlretrieve(src, dst)
    return dst


def cps(ranges):
    return [c for a, b in ranges for c in range(a, b + 1)]


def make(src: str, out: str, ranges, flavor="woff2", hint=False) -> None:
    o = subset.Options()
    o.flavor = flavor
    o.layout_features = ["kern", "palt", "vert", "liga", "ccmp", "ljmo", "vjmo", "tjmo", "locl"]
    o.name_IDs = ["*"]
    o.name_languages = ["*"]
    o.notdef_outline = True
    o.hinting = hint
    o.desubroutinize = False
    f = TTFont(src)
    s = subset.Subsetter(o)
    s.populate(unicodes=cps(ranges))
    s.subset(f)
    f.flavor = flavor
    f.save(os.path.join(OUT, out))
    cm = f.getBestCmap()
    print("%-26s %8d bytes  %5d chars  %5d syllables" % (out, os.path.getsize(os.path.join(OUT, out)), len(cm),
                                                       sum(1 for c in cm if 0xAC00 <= c <= 0xD7A3)))


def main() -> None:
    make(fetch("NotoSansKR-Bold.otf"), "NotoSansKR-Bold.woff2", KOREAN)
    make(fetch("NotoSansKR-Black.otf"), "NotoSansKR-Black.woff2", KOREAN)
    make(fetch("NotoSerifKR-Black.otf"), "NotoSerifKR-Black.woff2", KOREAN)
    make(fetch("NotoSerifKR-Bold.otf"), "NotoSerifKR-Bold.woff2", KOREAN)
    make(fetch("BlackHanSans-Regular.ttf"), "BlackHanSans.woff2", [(0x0000, 0xFFFF)], hint=True)
    # only what Noto Sans KR lacks in the symbol blocks
    have = TTFont(os.path.join(OUT, "NotoSansKR-Bold.woff2")).getBestCmap()
    make(fetch("DejaVuSans-Bold.ttf"), "DejaVuSans-sym.ttf",
         [(c, c) for c in cps([(0x2190, 0x21FF), (0x2600, 0x27BF)]) if c not in have], flavor=None)


if __name__ == "__main__":
    main()
