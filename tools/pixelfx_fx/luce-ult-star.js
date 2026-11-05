// Luce's ultimate, gathering: a four-point star of light over her head, its long rays breathing and a thin second
// cross turning behind them, a ring round it, and streaks of light drawn in to it from all round. Loops.
import { clamp, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce ult star",
  desc: "A breathing four-point star with a turning thin cross behind, a ring, and light streaks drawn in from all round (loop).",
  tags: ["holy", "charge", "star", "loop"],
  size: [128, 128],
  origin: [64, 64],
  duration: 0.48,
  loop: true,
  fps: 50,
  options: { seed: 6 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

function ray(p, a, L, w) {
  // a tapering ray: wide and white at the heart, a gold hairline at the tip
  const c = Math.cos(a), s = Math.sin(a), nx = -s, ny = c;
  for (let i = 0; i <= L; i++) {
    const u = i / L, hw = w * (1 - u) * (1 - u);
    for (let j = -Math.ceil(hw); j <= Math.ceil(hw); j++) {
      if (Math.abs(j) > hw) continue;
      const q = Math.abs(j) / Math.max(0.5, hw);
      p.px(c * i + nx * j, s * i + ny * j, u < 0.25 && q < 0.6 ? WHITE : u < 0.5 && q < 0.7 ? W1 : u < 0.75 ? G0 : G1);
    }
  }
}

export function draw(p, t, o) {
  const T = meta.duration, ph = (t / T) * Math.PI * 2, F = Math.floor(t / 0.02);
  const br = 0.5 + 0.5 * Math.sin(ph);
  p.glow(0, 0, 40, G1, 0.25 + 0.15 * br);
  // the turning thin cross behind
  const sp = (t / T) * (Math.PI / 2);
  for (let k = 0; k < 4; k++) ray(p, Math.PI / 4 + sp + (k * Math.PI) / 2, 20 + 4 * br, 0.6);
  // the ring
  const R = 18 + 2 * br, n = Math.floor(R * 6);
  for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; if ((i + F) % 3 === 0) continue; p.px(Math.cos(a) * R, Math.sin(a) * R, i % 2 ? G1 : G0); }
  // the star
  for (let k = 0; k < 4; k++) ray(p, (k * Math.PI) / 2, (k % 2 ? 30 : 44) + 8 * br, 4.2 + br);
  p.disc(0, 0, 5 + br, WHITE, 1);
  // streaks drawn in from all round
  for (let i = 0; i < 10; i++) {
    const life = 0.24, q = ((t + hash(o.seed + i) * life) % life) / life;
    const a = hash(o.seed + 20 + i) * Math.PI * 2, r0 = 62 - q * 44, L = 8 * (1 - q) + 2;
    const c = Math.cos(a), s = Math.sin(a);
    p.line(c * r0, s * r0, c * (r0 + L), s * (r0 + L), q > 0.6 ? WHITE : q > 0.3 ? G0 : G2);
  }
}
