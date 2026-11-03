"""Render the prototype's WebAudio sound recipes to WAV files (assets/sfx).
The recipes are the same envelopes / band-passed noise / pitch sweeps as sfx() in the web build.
heavy / parry / hurt / thrust (now stab.wav) / dash (now dodge.wav) / ready (now ui1-3.wav) and the combo hits
hit1-3.wav / ult.wav are produced sounds, not these recipes: NAMES leaves them out so a run never overwrites them
(their old recipes stay below for the record)."""
import numpy as np, wave, os, sys
from scipy.signal import iirpeak, lfilter, butter
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)

def t_of(sec): return np.arange(int(SR * sec)) / SR
def osc(kind, f0, f1, sec):
    t = t_of(sec); f1 = max(20.0, f1)
    f = f0 * (f1 / f0) ** (t / sec) if f0 != f1 else np.full_like(t, f0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'sine': return np.sin(ph)
    if kind == 'square': return np.sign(np.sin(ph)) * 0.6
    if kind == 'triangle': return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == 'sawtooth': return ((ph / np.pi) % 2 - 1) * 0.6
def bandnoise(sec, lo, hi):
    n = rng.uniform(-1, 1, int(SR * sec)); fc = np.sqrt(lo * hi)
    b, a = butter(2, [max(20, fc / 1.9) / (SR / 2), min(0.99, fc * 1.9 / (SR / 2))], btype='band')
    return lfilter(b, a, n) * 1.6

class S:
    def __init__(self, length=1.0): self.buf = np.zeros(int(SR * length)); self.env = None
    def env_(self, a, d, peak):
        n = len(self.buf); t = np.arange(n) / SR
        e = np.where(t < a, 0.0001 + (peak - 0.0001) * t / max(a, 1e-4), peak * np.exp(np.log(0.0001 / peak) * np.clip((t - a) / d, 0, 1)))
        e[t > a + d] = 0.0; self.env = e
    def add(self, x, at=0.0):
        i = int(at * SR); x = x[: len(self.buf) - i]; self.buf[i:i + len(x)] += x
    def render(self, vol=0.9):
        y = self.buf * (self.env if self.env is not None else 1.0)
        return np.clip(y * vol, -1, 1)

def recipe(name):
    s = S(1.0); tone = lambda f0, f1, sec, k='sine': s.add(osc(k, f0, f1, sec)); nz = lambda sec, lo, hi: s.add(bandnoise(sec, lo, hi))
    if name == 'step': s.env_(0.002, 0.05, 0.25); nz(0.07, 200, 900); tone(110, 80, 0.05)
    elif name == 'swing': s.env_(0.03, 0.12, 0.35); nz(0.18, 600, 3800)
    elif name == 'hit': s.env_(0.001, 0.12, 0.6); nz(0.12, 1200, 6000); tone(160, 60, 0.1); tone(2300, 2300, 0.05)
    elif name == 'heavy': s.env_(0.001, 0.3, 0.8); nz(0.2, 300, 2500); tone(90, 40, 0.25); tone(1800, 1800, 0.15, 'triangle')
    elif name == 'jump': s.env_(0.005, 0.1, 0.3); tone(320, 760, 0.12)
    elif name == 'djump': s.env_(0.005, 0.12, 0.35); tone(420, 1100, 0.14); tone(630, 1650, 0.12, 'triangle'); nz(0.1, 800, 4000)
    elif name == 'dive': s.env_(0.15, 0.25, 0.4); nz(0.45, 300, 3000)
    elif name == 'slam': s.env_(0.001, 0.45, 0.9); tone(70, 30, 0.35); nz(0.15, 100, 600); nz(0.05, 1500, 6000)
    elif name == 'guard': s.env_(0.001, 0.15, 0.5); tone(900, 500, 0.12, 'square'); nz(0.08, 2000, 7000)
    elif name == 'parry': s.env_(0.001, 0.35, 0.7); tone(1600, 2400, 0.3, 'triangle'); tone(2400, 2400, 0.25); nz(0.06, 3000, 9000)
    elif name == 'hurt': s.env_(0.001, 0.2, 0.5); tone(240, 90, 0.2, 'sawtooth'); nz(0.1, 200, 1200)
    elif name == 'break': s.env_(0.001, 0.4, 0.7); nz(0.3, 150, 900); tone(120, 50, 0.3)
    elif name == 'skid': s.env_(0.01, 0.2, 0.3); nz(0.25, 400, 2500)
    elif name == 'ready': s.env_(0.005, 0.25, 0.4); tone(900, 1800, 0.18, 'triangle'); tone(2400, 2400, 0.2)
    elif name == 'dig': s.env_(0.005, 0.3, 0.5); nz(0.3, 150, 900); tone(260, 90, 0.25, 'triangle'); nz(0.06, 2000, 6000)
    elif name == 'dash': s.env_(0.01, 0.16, 0.45); nz(0.2, 500, 3500); tone(600, 250, 0.12, 'triangle')
    elif name == 'thrust': s.env_(0.005, 0.2, 0.5); nz(0.22, 900, 5000); tone(500, 180, 0.15, 'triangle')
    elif name in ('alert', 'alert_q'):
        q = name == 'alert_q'; s = S(0.4)
        for f, d, ln in ([[520, 0, 0.07], [390, 0.09, 0.12]] if q else [[880, 0, 0.06], [1320, 0.07, 0.08]]):
            x = osc('square', f, f, ln) * np.exp(-np.arange(int(SR * ln)) / SR / (ln / 4)) * (0.05 if q else 0.09) * 6; s.add(x, d)
    elif name == 'flare':
        s = S(0.5)
        for f, d in [[2093, 0], [3136, 0.035]]:
            x = osc('sine', f, f, 0.3) * np.exp(-np.arange(int(SR * 0.3)) / SR / 0.05) * 0.5; s.add(x, d)
    elif name == 'boom':
        s = S(2.0)
        for k, f0, f1, v in [['sine', 196, 46, 0.32], ['triangle', 392, 92, 0.1], ['sine', 98, 31, 0.28]]:
            x = osc(k, f0, f1, 1.9); tt = np.arange(len(x)) / SR; x *= v * 2.4 * np.minimum(1, tt / 0.03) * np.exp(-tt / 0.7); s.add(x)
    elif name == 'witch_end':
        s = S(0.4); x = osc('sine', 70, 420, 0.32); tt = np.arange(len(x)) / SR; s.add(x * 0.5 * np.minimum(1, tt / 0.05) * np.exp(-tt / 0.1))
    return s.render()

NAMES = ['step', 'swing', 'hit', 'jump', 'djump', 'dive', 'slam', 'guard', 'break', 'skid', 'dig', 'alert', 'alert_q', 'flare', 'boom', 'witch_end']
if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for n in NAMES:
        y = recipe(n); nz_ = np.nonzero(np.abs(y) > 1e-4)[0]; y = y[: (nz_[-1] + 200) if len(nz_) else 100]
        with wave.open(os.path.join(OUT, n + '.wav'), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((y * 32767).astype('<i2').tobytes())
    print('wrote', len(NAMES))
