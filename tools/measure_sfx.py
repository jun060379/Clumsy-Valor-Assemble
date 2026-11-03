#!/usr/bin/env python3
"""Loudness of the sound files (for arena.gd LEVEL): peak and the loudest 100 ms RMS window, in dBFS.

    python3 tools/measure_sfx.py assets/sfx/*.wav assets/sfx/*.ogg

A LEVEL entry puts a file at its target at volume 1: LEVEL = 10 ** ((target_dBFS - rms100_dBFS) / 20)
(pickups / UI / jump / land -18, jingles -14, boss impacts -10, ult_sub -12). OGGs are decoded through ffmpeg.
"""
import math, os, subprocess, sys, tempfile, wave
import numpy as np


def read(path):
    if not path.lower().endswith(".wav"):
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-c:a", "pcm_s16le", tmp.name], check=True)
        try:
            return read(tmp.name)
        finally:
            os.unlink(tmp.name)
    w = wave.open(path, "rb")
    ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    w.close()
    if sw == 2:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 4:
        x = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    else:
        x = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, sr


def rms_max(x, sr, win=0.1):
    n = int(sr * win)
    if len(x) < n:
        return math.sqrt(np.mean(x ** 2)) if len(x) else 0.0
    c = np.cumsum(np.concatenate([[0.0], x ** 2]))
    return math.sqrt(((c[n:] - c[:-n]) / n).max())


def db(v):
    return 20.0 * math.log10(max(v, 1e-9))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        x, sr = read(p)
        print("%-22s %6.3f s  peak %6.1f dBFS  rms100 %6.1f dBFS" % (os.path.basename(p), len(x) / sr, db(np.abs(x).max() if len(x) else 0.0), db(rms_max(x, sr))))
