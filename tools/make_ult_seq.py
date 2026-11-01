#!/usr/bin/env python3
"""Turn the ult clips (Theora .ogv, which the web export can't decode) into frame packs the game decodes itself.

Pack format (little endian): b"USEQ", u16 fps, u16 width, u16 height, u16 count, then count x (u32 size, JPEG bytes).
Usage: python3 tools/make_ult_seq.py SRC_DIR   (SRC_DIR holds ult_estelle.ogv / ult_aida.ogv / ult_luce.ogv)
Writes assets/ult/ult_<who>.useq.
"""
import glob, os, struct, subprocess, sys, tempfile

FPS, W, H, Q = 24, 640, 360, 5
src = sys.argv[1] if len(sys.argv) > 1 else "tools/ult_src"
for who in ["estelle", "aida", "luce"]:
    clip = os.path.join(src, "ult_%s.ogv" % who)
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["ffmpeg", "-v", "error", "-i", clip, "-vf", "fps=%d,scale=%d:%d:flags=lanczos" % (FPS, W, H),
                        "-q:v", str(Q), os.path.join(d, "%03d.jpg")], check=True)
        fr = sorted(glob.glob(os.path.join(d, "*.jpg")))
        out = os.path.join("assets/ult", "ult_%s.useq" % who)
        with open(out, "wb") as f:
            f.write(b"USEQ" + struct.pack("<HHHH", FPS, W, H, len(fr)))
            for p in fr:
                b = open(p, "rb").read()
                f.write(struct.pack("<I", len(b)) + b)
        print(out, len(fr), "frames", os.path.getsize(out) // 1024, "KB")
