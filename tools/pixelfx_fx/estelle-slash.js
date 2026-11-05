// Estelle's swing, after the game's SLASHFX shader (the swing crescent: sharp head, needle tail, ragged edges, the
// air wake outside, two speed arcs inside), its seven keyframes eased into a smooth 50 fps run, with light added:
// a rose bloom along the body, a glint on the point as the edge arrives, a brief flare at the head.
import { clamp, ease, WHITE, hex, Rng } from "../../core/index.js";

export const meta = {
  name: "Estelle slash",
  desc: "Estelle's swing crescent (sharp head, needle tail, ragged edges, air wake, speed arcs), smoothed to 50 fps, with a rose bloom and a glint on the point.",
  tags: ["melee", "slash", "sword", "rose", "one-shot"],
  size: [260, 260],
  origin: [130, 126],
  duration: 0.3,
  loop: false,
  fps: 50,
  options: { a0: -100, a1: 30, r: 80, sy: 1, seed: 3 },   // r: the game's slash radius in world px (r * 1.2 / 2 art px)
};

const PAL = ["#ffffff", "#ffffff", "#ff96d2", "#d650aa", "#7a2a66"].map(hex), GLOW = hex("#ff96d2"), BLUSH = hex("#ffd3ea"), INK = hex("#0a0308"), INK2 = hex("#2a0a20");
// h, tl, w, darken per 40 ms frame (the game's REFK)
const REFK = [[0.35, 0, 0, 0], [0.8, 0, 0.85, 0], [1.04, 0.04, 1, 0], [1.04, 0.25, 0.7, 0], [1.04, 0.48, 0.45, 1], [1.04, 0.68, 0.26, 1], [1.04, 0.84, 0.12, 2], [1.04, 1.0, 0, 2]];
const deg = Math.PI / 180;

function key(F) {
  const i = Math.min(REFK.length - 2, Math.floor(F)), f = clamp(F - i), A = REFK[i], B = REFK[i + 1];
  return [A[0] + (B[0] - A[0]) * f, A[1] + (B[1] - A[1]) * f, A[2] + (B[2] - A[2]) * f, f < 0.5 ? A[3] : B[3]];
}

function world(o) {
  const k = JSON.stringify([o.seed]);
  if (o._w && o._w.k === k) return o._w;
  const R = new Rng(o.seed);
  return (o._w = { k, h1: Array.from({ length: 25 }, () => R.next()), h2: Array.from({ length: 17 }, () => R.next()), h3: Array.from({ length: 91 }, () => R.next()) });
}

export function draw(p, t, o) {
  const { h1, h2, h3 } = world(o);
  const F = t / 0.04, [H, TL, Wk, DK] = key(F), fi = Math.floor(F);
  const ro = (o.r * 1.2) / 2, thick = (o.r * 0.62) / 2, span = o.a1 - o.a0, sy = o.sy;
  const col = (n) => PAL[Math.min(4, n + DK)];
  const prof = (u) => {
    const v = u < 0.8 ? 0.04 + 0.96 * Math.pow(u / 0.8, 1.7) : Math.pow(Math.max(0, 1 - (u - 0.8) / 0.2), 0.55);
    return thick * v * Wk * (1 + 0.24 * Math.abs(Math.sin(u * 13 + o.seed)) * Math.pow(u, 0.6) + 0.12 * Math.abs(Math.sin(u * 47 + o.seed * 3)));
  };
  const M = Math.ceil(ro + 10);
  p.shade(-M, -Math.ceil(M * sy) - 2, M, Math.ceil(M * sy) + 2, (xx, yy, out) => {
    const ye = yy / sy, rr = Math.hypot(xx, ye);
    if (rr > ro + 8 || rr < ro - thick * 1.6 - 9) return;
    let d = Math.atan2(ye, xx) / deg - o.a0;
    d = span > 0 ? ((d % 360) + 360) % 360 : -((((-d) % 360) + 360) % 360);
    const s0 = d / span;
    if (s0 < TL || s0 > H) return;
    const u = (s0 - TL) / Math.max(1e-3, H - TL);
    if (Wk < 0.02) { if (Math.abs(rr - ro) < 0.7) out.c = col(1); return; }
    const w = prof(u) * (0.72 + 0.56 * h1[Math.min(24, Math.floor(u * 24))]), dep = ro + (h2[Math.min(16, Math.floor(u * 16))] - 0.5) * 2.2 - rr;
    if (dep > 0.8 && dep < 2.6 && h3[Math.min(90, Math.floor(u * 90))] < 0.12) return;   // the ragged notches
    if (dep >= -0.5 && dep <= Math.max(0.9, w)) {
      const q = dep / Math.max(1, w);
      if (F < 1.7) { out.c = dep < 1.2 || q > 0.9 ? WHITE : INK; return; }          // the impact frame: an ink crescent rimmed white
      // flat steps with a hard ink stroke riding inside the colour, Limbus-like
      out.c = dep < 0.6 ? col(0) : q < 0.34 ? col(1) : q < 0.42 ? INK2 : q < 0.8 ? col(2) : q < 0.92 ? col(3) : INK2;
      return;
    }
    // brush spikes thrown off the outer edge, sharp and flat (they shorten as it fades)
    if (dep < -0.5 && Wk > 0.3) {
      const sp = h3[Math.min(90, Math.floor(u * 90))], len = (sp > 0.78 ? 3 + 9 * (sp - 0.78) / 0.22 : 0) * Wk * Math.min(1, u * 1.6);
      const cell = (u * 90) % 1, wid = 1 - Math.abs(cell - 0.5) * 2;
      if (-dep < len * wid) { out.c = F < 1.7 ? INK : -dep < 1.5 ? col(1) : col(2); return; }
    }
    // the air wake outside, two broken arcs
    if (fi >= 2 && fi <= 5) for (let n = 1; n <= 2; n++) {
      const rw = ro + 1.5 + n * 2.2;
      if (Math.abs(rr - rw) > 0.5) continue;
      const hi = H - 0.12 * n - 0.06 * (F - 2), lo = Math.max(TL, hi - 0.35 + 0.05 * F);
      if (s0 < lo || s0 > hi || Math.floor(s0 * 40 + n) % 5 === 0) continue;
      out.c = F < 4 ? col(1) : col(3);
      return;
    }
    // two speed arcs inside
    if (fi >= 1 && fi <= 5) for (let n = 1; n <= 2; n++) {
      const rw = ro - thick - 1.5 - n * 2.6;
      if (Math.abs(rr - rw) > 0.5) continue;
      const lo = TL + 0.08 * n, hi = H - 0.18 * n;
      if (s0 < lo || s0 > hi) continue;
      out.c = n === 1 ? col(2) : col(3);
      return;
    }
  });
  // the cut: a long straight line drawn through the end of the stroke along its tangent, ink under white, snapping in
  const cl = clamp((F - 0.6) / 3.2);
  if (cl > 0 && cl < 1) {
    const a = (o.a0 + span * 0.92) * deg, cx = Math.cos(a) * (ro - thick * 0.25), cy = Math.sin(a) * (ro - thick * 0.25) * sy;
    const tx = -Math.sin(a) * Math.sign(span), ty = Math.cos(a) * sy * Math.sign(span), L = (60 + 50 * ease.outExpo(clamp(cl * 4))) * (o.r / 100), shrink = ease.inCubic(clamp((cl - 0.35) / 0.65));
    const x0 = cx - tx * L * (1 - shrink), y0 = cy - ty * L * (1 - shrink), x1 = cx + tx * L * (1 - shrink * 0.3), y1 = cy + ty * L * (1 - shrink * 0.3);
    p.line(x0 + 1, y0 + 1, x1 + 1, y1 + 1, INK, 1 - cl * 0.5);
    p.line(x0, y0, x1, y1, WHITE, 1);
    if (cl < 0.3) p.beam(x0, y0, x1, y1, 3 * (1 - cl / 0.3), WHITE, 0.9);
    p.glowLine(x0, y0, x1, y1, 5, GLOW, 0.5 * (1 - cl));
  }
  // light: a rose bloom along the body, fading as it thins
  if (Wk > 0.05) for (let i = 0; i <= 10; i++) {
    const u = i / 10, s0 = TL + (Math.min(1, H) - TL) * u, a = (o.a0 + span * s0) * deg, w = prof(u);
    p.glow(Math.cos(a) * (ro - w * 0.4), Math.sin(a) * (ro - w * 0.4) * sy, 6 + w, GLOW, 0.2 * Wk * (0.3 + u));
  }
  // the head flares as it sweeps, and the point glints as the edge arrives
  if (F < 2.2) {
    const a = (o.a0 + span * Math.min(1, H)) * deg, x = Math.cos(a) * (ro - 3), y = Math.sin(a) * (ro - 3) * sy;
    p.glow(x, y, 18, BLUSH, 0.7 * (1 - F / 2.2));
  }
  const g = (F - 1.6) / 2.4;
  if (g > 0 && g < 1) {
    const a = o.a1 * deg, x = Math.round(Math.cos(a) * (ro - thick * 0.3)), y = Math.round(Math.sin(a) * (ro - thick * 0.3) * sy);
    const L = Math.round(3 + 8 * (1 - g) * ease.outBack(Math.min(1, g * 4)));
    p.line(x - L, y, x + L, y, WHITE, 1 - g); p.line(x, y - L, x, y + L, WHITE, 1 - g);
    const L2 = Math.round(L * 0.45);
    p.line(x - L2, y - L2, x + L2, y + L2, BLUSH, 1 - g); p.line(x - L2, y + L2, x + L2, y - L2, BLUSH, 1 - g);
    p.glow(x, y, 9, GLOW, 0.7 * (1 - g));
  }
}
