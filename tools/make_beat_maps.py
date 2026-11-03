"""Measure the dungeon / town tracks' beat maps (assets/bgm/*.ogg) and write scripts/beat_maps.gd.

The tracks are not at a fixed tempo: battle.ogg ramps from ~93.9 to ~95.9 BPM over its 106 s, boss.ogg from ~93.5 to
~96.3, lowhp.ogg from ~95.3 to ~96.2 (town.ogg sits at 96.0). A constant grid drifts up to ~300 ms against them — two
16ths — so the music clock (scripts/beat.gd) rides a measured beat map instead: the time of every beat in the file.

Method, per track: the onset-strength envelope (librosa, 2.9 ms hops); the local period from the bar-lag
autocorrelation of 12 s windows every 2 s; beats integrated from the first downbeat (the measured t0, refined to the
16th grid of the first 8 s); then every 4 s the map's 16th phase is pulled halfway toward the local comb-filter optimum
(an 8 s window), so it stays locked to the hats within a few ms. The result lands ~4x more onset energy on its 16th grid
than between (the constant grid: ~1x).

Needs ffmpeg (the .ogg files carry a Theora stream libsndfile will not open) and numpy / scipy / librosa / soundfile:
    python3 tools/make_beat_maps.py
"""
import os, subprocess, sys, tempfile
import numpy as np

try:
    import librosa, soundfile as sf
    from scipy.signal import fftconvolve
except ImportError as e:
    sys.exit("needs numpy, scipy, librosa, soundfile: " + str(e))

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'scripts', 'beat_maps.gd')
# name: nominal bpm, first downbeat (s), loop offset (s), length (s)
TRACKS = {
    'town': (96.0, 0.65, 0.0, 75.0),
    'battle': (95.7, 0.12, 4.99, 105.79),
    'boss': (95.7, 0.70, 13.49, 174.68),
    'lowhp': (95.7, 0.12, 20.18, 60.24),
}
HOP = 64
SR = 22050


def decode(name, tmp):
    wav = os.path.join(tmp, name + '.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(ROOT, 'assets', 'bgm', name + '.ogg'),
                    '-map', '0:a:0', '-ac', '1', '-ar', str(SR), wav], check=True)
    y, sr = sf.read(wav)
    return y.astype(np.float32), sr


def local_period(env, dt, beat0, ln, win=12.0, hop=2.0):
    """bar-lag autocorrelation per window -> (window centres, beat periods)"""
    ts, ps = [], []
    s = 0.0
    while s + win <= ln + 1e-6:
        e = env[int(s / dt): int((s + win) / dt)]
        e = e - e.mean()
        n = len(e)
        ac = fftconvolve(e, e[::-1], mode='full')[n - 1:]
        ac /= max(ac[0], 1e-9)
        i0, i1 = int(beat0 * 4 * 0.95 / dt), int(beat0 * 4 * 1.05 / dt)
        k = ac[i0:i1].argmax() + i0
        a_, b_, c_ = ac[k - 1], ac[k], ac[k + 1]
        d = 0.5 * (a_ - c_) / (a_ - 2 * b_ + c_) if (a_ - 2 * b_ + c_) != 0 else 0.0
        ts.append(s + win / 2)
        ps.append((k + d) * dt / 4)
        s += hop
    # a window straddling a change of pattern (the boss intro's end) can pick a spurious lag: median of five
    ps = np.array(ps)
    sm = ps.copy()
    for i in range(len(ps)):
        sm[i] = np.median(ps[max(0, i - 2): i + 3])
    return np.array(ts), sm


def comb_phase(env, dt, per, start, end):
    """the 16th-grid phase (s, in [0, per/4)) with the most onset strength over [start, end)"""
    t = np.arange(len(env)) * dt
    six = per / 4
    best = None
    for ph in np.arange(0, six, 0.002):
        g = ph + np.arange(0, int((end - ph) / six) + 1) * six
        g = g[(g >= start) & (g < end)]
        if len(g) == 0:
            continue
        s = np.interp(g, t, env).mean()
        if best is None or s > best[0]:
            best = (s, ph)
    return best[1]


def build(name, y, sr):
    bpm0, t0, loop_off, ln = TRACKS[name]
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=HOP)
    dt = HOP / sr
    beat0 = 60.0 / bpm0
    ts, ps = local_period(env, dt, beat0, ln)
    per = lambda x: float(np.interp(x, ts, ps))
    # the anchor: the 16th line of the first 8 s nearest the measured first downbeat
    p0 = per(4.0)
    ph = comb_phase(env, dt, p0, 0.0, 8.0)
    anchor = ph + round((t0 - ph) / (p0 / 4)) * (p0 / 4)
    beats = [anchor]
    while True:
        nb = beats[-1] + per(beats[-1])
        beats.append(nb)
        if nb > ln:
            break
    pre = []
    b = anchor
    while True:
        b = b - per(b)
        if b < -0.5 * per(b):
            break
        pre.append(b)
    beats = np.array(pre[::-1] + beats)
    i0 = len(pre)
    # phase lock to the hats: every 4 s the map's 16th phase is compared with the local comb optimum (an 8 s window),
    # the pulls are weighted by the window's onset energy (a quiet intro pulls nothing) and spread smoothly along the
    # track; three passes converge
    t = np.arange(len(env)) * dt
    emean = env.mean()
    log = []
    for it in range(3):
        cs, ds = [0.0], [0.0]
        s = 0.0
        while s + 8.0 <= ln:
            c = s + 4.0
            p = per(c)
            six = p / 4
            ph_c = comb_phase(env, dt, p, s, s + 8.0)
            k = int(np.argmin(np.abs(beats - c)))
            d = ph_c - beats[k] % six
            d = (d + six / 2) % six - six / 2
            w = min(1.0, env[int(s / dt): int((s + 8.0) / dt)].mean() / emean)
            cs.append(c)
            ds.append(0.6 * d * w)
            log.append(d * 1000)
            s += 4.0
        cs.append(ln)
        ds.append(ds[-1])
        beats += np.interp(beats, cs, ds)
    # how the grid does: onset energy on the 16th grid vs between
    g16 = np.concatenate([b + np.arange(4) * (nb - b) / 4 for b, nb in zip(beats[:-1], beats[1:])])
    six_m = np.diff(beats).mean() / 4
    on = np.interp(g16, t, env).mean()
    off = np.interp(g16 + six_m / 2, t, env).mean()
    cg = t0 + np.arange(0, int((ln - t0) / beat0) + 1) * beat0
    c16 = np.concatenate([b + np.arange(4) * beat0 / 4 for b in cg])
    con = np.interp(c16, t, env).mean() / np.interp(c16 + beat0 / 8, t, env).mean()
    lb = np.interp(loop_off, beats, np.arange(len(beats)))
    eb = np.interp(ln, beats, np.arange(len(beats)))
    print(f"{name}: {len(beats)} beats, downbeat [{i0}] at {beats[i0]:.3f} s (measured {t0}), tempo {60/np.diff(beats).max():.1f}..{60/np.diff(beats).min():.1f} BPM "
          f"(mean {60/np.diff(beats).mean():.2f}); 16th-grid onset ratio {on/off:.2f} (constant {bpm0} grid: {con:.2f}); "
          f"phase pulls |max| {np.abs(log).max():.0f} ms; loop {loop_off}..{ln} = beats {lb:.2f}..{eb:.2f} ({(eb-lb)/4:.2f} bars)")
    return beats, i0


def main():
    with tempfile.TemporaryDirectory() as tmp:
        lines = [
            'extends RefCounted',
            '## Measured beat maps for the music clock (scripts/beat.gd): the time (s) of every beat in each track of',
            '## assets/bgm/, with the index of the first downbeat. Generated by tools/make_beat_maps.py — the tracks ramp',
            '## in tempo (battle ~93.9 → 95.9 BPM, boss ~93.5 → 96.3, lowhp ~95.3 → 96.2, town 96.0), so a fixed BPM would',
            '## drift up to two 16ths against them; this table keeps the sfx snaps on the hats. Do not edit by hand.',
            '## (plain arrays: a PackedFloat32Array constructor is not a constant expression; bgm.gd packs them)',
            '',
            'const MAPS := {',
        ]
        for name in TRACKS:
            y, sr = decode(name, tmp)
            beats, i0 = build(name, y, sr)
            vals = ', '.join('%.4f' % b for b in beats)
            lines.append('\t"%s": {"i0": %d, "beats": [%s]},' % (name, i0, vals))
        lines.append('}')
        lines.append('')
    with open(OUT, 'w') as f:
        f.write('\n'.join(lines))
    print('wrote', os.path.relpath(OUT, ROOT))


if __name__ == '__main__':
    main()
