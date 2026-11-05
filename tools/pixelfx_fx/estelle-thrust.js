// Estelle's thrust, in the swing's Limbus-like language: a spear-wedge of light lunges out from her (thin at the
// back, widest near the point, a sharp tip), the first frames an ink wedge rimmed white, then flat rose steps with
// an ink stroke riding inside; brush spikes rake off its edges, speed lines streak behind, and a long straight cut
// line shoots on through the point and shrinks away.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Estelle thrust",
  desc: "A rose spear-wedge lunges out, an ink impact frame, flat steps with an ink stroke, brush spikes, speed lines and a long cut line through the point.",
  tags: ["melee", "thrust", "spear", "rose", "one-shot"],
  size: [240, 64],
  origin: [12, 32],
  duration: 0.28,
  loop: false,
  fps: 50,
  options: { len: 66, seed: 5 },
};

const W2 = hex("#ffd3ea"), P1 = hex("#ff96d2"), P2 = hex("#d650aa"), P3 = hex("#7a2a66"), INK = hex("#0a0308"), INK2 = hex("#2a0a20");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 4.1) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const L = o.len, F = t / 0.04;
  const head = ease.outExpo(clamp(t / 0.05)), tail = ease.inCubic(clamp((t - 0.07) / 0.17)), W = 9 * Math.min(1.4, L / 66);
  const fade = clamp((t - 0.1) / 0.16), dk = fade > 0.6 ? 2 : fade > 0.3 ? 1 : 0;
  const cols = [WHITE, W2, P1, P2, P3];
  const col = (n) => cols[Math.min(4, n + dk)];
  const x0 = L * tail, x1 = L * head;
  if (x1 - x0 > 1) p.shade(Math.floor(x0) - 1, -Math.ceil(W) - 12, Math.ceil(x1) + 2, Math.ceil(W) + 12, (xx, yy, out) => {
    const X = xx + 0.5, Y = yy + 0.5, u = (X - x0) / (x1 - x0);
    if (u < 0 || u > 1) return;
    const prof = u < 0.82 ? 0.08 + 0.92 * Math.pow(u / 0.82, 1.5) : Math.pow(Math.max(0, 1 - (u - 0.82) / 0.18), 0.6);
    const hw = W * prof * (1 - fade * 0.6) * (0.85 + 0.3 * hash(Math.floor(X / 3)));
    const ay = Math.abs(Y);
    if (ay <= hw) {
      const q = ay / Math.max(1, hw);
      if (F < 1.6) { out.c = q > 0.8 || u > 0.94 ? WHITE : INK; return; }       // the impact frame
      out.c = q < 0.25 ? col(0) : q < 0.33 ? INK2 : q < 0.62 ? col(1) : q < 0.85 ? col(2) : col(3);
      if (q > 0.93) out.c = INK2;
      return;
    }
    // brush spikes raking back off both edges
    const sp = hash(Math.floor(X / 2) + (Y < 0 ? 31 : 77)), len = sp > 0.8 ? (2 + 10 * (sp - 0.8) / 0.2) * (1 - fade) * u : 0;
    if (ay - hw < len && ((X + ay) % 3) < 1.5) { out.c = F < 1.6 ? INK : P1; return; }
  });
  // speed lines streaking behind, along the lunge
  const sl = clamp(t / 0.2);
  for (const [y, len, d0] of [[-7, 26, 0], [5, 34, 0.1], [-2, 18, 0.2], [9, 14, 0.3]]) {
    const s = clamp((sl - d0) / (1 - d0));
    if (s <= 0 || s >= 1) continue;
    const xa = L * 0.7 - 50 * s, xb = xa - len * (1 - s);
    p.line(xb, y, xa, y, y === 5 ? WHITE : P1, 1 - s);
  }
  // the cut line, shooting on through the point and shrinking
  const cl = clamp((F - 0.5) / 3.2);
  if (cl > 0 && cl < 1) {
    const sh = ease.inCubic(clamp((cl - 0.35) / 0.65)), xa = L * 0.2 + L * 0.8 * sh, xb = L + (40 + 70 * ease.outExpo(clamp(cl * 4))) * (1 - sh * 0.4);
    p.line(xa + 1, 1, xb + 1, 1, INK, 1 - cl * 0.5);
    p.line(xa, 0, xb, 0, WHITE);
    if (cl < 0.3) p.beam(xa, 0, xb, 0, 3 * (1 - cl / 0.3), WHITE, 0.9);
    p.glowLine(xa, 0, xb, 0, 5, P1, 0.5 * (1 - cl));
  }
  // the point flares as it arrives
  const g = 1 - clamp((t - 0.03) / 0.12);
  if (g > 0 && t > 0.03) {
    const Lg = Math.round(3 + 8 * g);
    p.line(L - Lg, 0, L + Lg * 1.5, 0, WHITE, g); p.line(L, -Lg, L, Lg, WHITE, g);
    p.glow(L, 0, 12, P1, 0.8 * g);
  }
}
