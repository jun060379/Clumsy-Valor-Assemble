// Luce's ultimate, the punch landing (faces right): a white flash at the fist, an eight-point flare snapping out,
// two shock rings standing up across the line of the blow and rolling forward, speed lines thrown back past her,
// sparks spraying ahead.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce ult impact",
  desc: "A white flash at the fist, an eight-point flare, two upright shock rings rolling forward, speed lines thrown back, sparks ahead.",
  tags: ["holy", "impact", "punch", "one-shot"],
  size: [240, 200],
  origin: [90, 100],
  duration: 0.5,
  loop: false,
  fps: 50,
  options: { seed: 7 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 3.3;
  // the flash
  if (t < 0.06) { p.disc(0, 0, 30 - t * 200, WHITE, 1); p.disc(0, 0, 36 - t * 200, G0, 1); p.disc(0, 0, 30 - t * 200, WHITE, 1); }
  p.glow(0, 0, 70, G0, 0.7 * (1 - clamp(t / 0.3)));
  // the flare: eight points, the four on the axes long
  const fk = clamp(t / 0.22);
  if (fk < 1) {
    const L0 = 70 * Math.sin(Math.min(1, fk * 1.6) * Math.PI * 0.5) * (1 - fk * 0.6);
    for (let k = 0; k < 8; k++) {
      const a = (k * Math.PI) / 4, L = (k % 2 ? 0.45 : k === 0 ? 1.3 : 1) * L0, c = Math.cos(a), s = Math.sin(a);
      for (let i = 0; i <= L; i++) {
        const u = i / L, col = u < 0.4 ? WHITE : u < 0.7 ? W1 : G0;
        p.px(c * i, s * i, col);
        if (k % 2 === 0 && u < 0.5) { p.px(c * i - s, s * i + c, u < 0.3 ? WHITE : G0); p.px(c * i + s, s * i - c, u < 0.3 ? WHITE : G0); }
      }
    }
  }
  // two upright shock rings rolling forward along the blow
  for (const [st, k0] of [[0, 1], [0.07, 0.7]]) {
    const k = clamp((t - st) / 0.34);
    if (t < st || k >= 1) continue;
    const ry = (20 + 70 * ease.outCubic(k)) * k0, rx = ry * 0.32, cx = 10 + 90 * ease.outCubic(k);
    const n = Math.floor(ry * 4);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      if (k > 0.55 && i % 2) continue;
      const x = cx + Math.cos(a) * rx, y = Math.sin(a) * ry, back = Math.cos(a) < 0;
      p.px(x, y, k < 0.3 ? WHITE : back ? G2 : k < 0.6 ? G0 : G1);
      if (k < 0.4 && !back) p.px(x + 1, y, G0);
    }
  }
  // speed lines thrown back past her
  const lk = clamp(t / 0.3);
  if (lk < 1) for (let i = 0; i < 12; i++) {
    const y = (hash(sd + i) - 0.5) * 140, x0 = -20 - hash(sd + 20 + i) * 30 - lk * 60, L = (30 + hash(sd + 40 + i) * 40) * (1 - lk);
    if (lk > 0.6 && (i + F) & 1) continue;
    p.line(x0, y, x0 - L, y, i % 3 ? G0 : WHITE);
  }
  // sparks sprayed ahead
  const pk = clamp((t - 0.02) / 0.4);
  if (pk > 0 && pk < 1) for (let i = 0; i < 18; i++) {
    const a = (hash(sd + 60 + i) - 0.5) * 1.6, v = 60 + hash(sd + 80 + i) * 90;
    const x = Math.cos(a) * v * ease.outCubic(pk), y = Math.sin(a) * v * ease.outCubic(pk) + 20 * pk * pk;
    if (pk < 0.6 || ((i + F) & 1) === 0) { p.px(x, y, pk < 0.3 ? WHITE : pk < 0.6 ? G0 : G2); if (pk < 0.4) p.px(x - 1, y, G1); }
  }
}
