// Estelle's dive landing, in the swing's Limbus-like language: an ink half-dome rimmed white on the impact frame,
// then two flat rose shock arcs thrown out along the floor with an ink stroke inside, brush spikes raking up off
// them, ink cracks run out, and a long straight cut line slices the floor both ways and shrinks away.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Estelle dive land",
  desc: "An ink half-dome on impact, flat rose shock arcs along the floor with ink strokes and brush spikes, ink cracks, a long cut line across the floor.",
  tags: ["impact", "ground", "rose", "one-shot"],
  size: [240, 80],
  origin: [120, 60],
  duration: 0.36,
  loop: false,
  fps: 50,
  options: {},
};

const W2 = hex("#ffd3ea"), P1 = hex("#ff96d2"), P2 = hex("#d650aa"), P3 = hex("#7a2a66"), INK = hex("#0a0308"), INK2 = hex("#2a0a20");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = t / 0.04;
  // the impact frame: an ink half-dome rimmed white
  if (F < 1.7) {
    const R = 16 + 10 * F;
    p.shade(-R - 1, -R * 0.5 - 1, R + 1, 0, (xx, yy, out) => {
      const e = Math.hypot((xx + 0.5) / R, (yy + 0.5) / (R * 0.5));
      if (e > 1) return;
      out.c = e > 0.85 ? WHITE : INK;
    });
    p.line(-R * 2, 0, R * 2, 0, WHITE);
    return;
  }
  const u = clamp((t - 0.06) / 0.26), fade = clamp((t - 0.16) / 0.2);
  // two flat shock arcs, half-ellipses thrown out along the floor
  for (const [k, lag] of [[0, 0], [1, 0.08]]) {
    const v = clamp((t - 0.06 - lag) / 0.24);
    if (v <= 0 || v >= 1) continue;
    const rx = 18 + 90 * ease.outCubic(v), ry = rx * 0.28, th = (6.5 - 6.5 * Math.pow(v, 1.4)) * (k ? 0.6 : 1);
    if (th < 0.7) continue;
    p.shade(-Math.ceil(rx) - 2, -Math.ceil(ry) - 14, Math.ceil(rx) + 2, 0, (xx, yy, out) => {
      const X = xx + 0.5, Y = yy + 0.5, e = Math.hypot(X / rx, Y / ry), d = (1 - e) * ry;
      if (Y > 0) return;
      if (d >= 0 && d < th) {
        const q = d / th;
        out.c = q < 0.2 ? (v < 0.3 ? WHITE : W2) : q < 0.32 ? INK2 : q < 0.7 ? (k ? P2 : P1) : (k ? P3 : P2);
        return;
      }
      // brush spikes raking up off the outer edge
      if (d < 0 && !k) {
        const sp = hash(Math.floor(Math.atan2(Y, X) * 18)), len = sp > 0.75 ? (2 + 10 * (sp - 0.75) / 0.25) * (1 - v) : 0;
        if (-d < len && Math.floor(X + Y) % 3 === 0) out.c = P1;
      }
    });
  }
  // ink cracks running out along the floor
  for (const sd of [1, -1]) {
    let x = sd * 4, y = 0;
    const n = Math.min(10, 2 + Math.floor(F * 2));
    for (let i = 0; i < n; i++) {
      const nx = x + sd * (4 + 4 * hash(i * 3 + sd)), ny = Math.max(0, Math.min(3, y + (hash(i * 7 + sd) < 0.5 ? 1 : -1)));
      p.line(x, y + 1, nx, ny + 1, INK2, 1 - fade);
      x = nx; y = ny;
    }
  }
  // the cut line across the floor, both ways, shrinking
  const cl = clamp((F - 1) / 4);
  if (cl < 1) {
    const L = (60 + 70 * ease.outExpo(clamp(cl * 4))) * (1 - ease.inCubic(clamp((cl - 0.35) / 0.65)));
    p.line(-L + 1, 1, L + 1, 1, INK, 1 - cl * 0.5);
    p.line(-L, 0, L, 0, WHITE);
    if (cl < 0.3) p.beam(-L, 0, L, 0, 3 * (1 - cl / 0.3), WHITE, 0.9);
    p.glowLine(-L, 0, L, 0, 6, P1, 0.5 * (1 - cl));
  }
  p.glow(0, -4, 30, P1, 0.4 * (1 - u));
}
