// Luce's orb being born: motes of light spiral in from all round, a thin ring closes in on the point, a small cross
// flashes as they meet; the orb itself (drawn by the game) swells out of the flash.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce orb born",
  desc: "Motes spiral in, a thin ring closes on the point, a small cross flashes as they meet.",
  tags: ["holy", "summon", "orb", "one-shot"],
  size: [56, 56],
  origin: [28, 28],
  duration: 0.24,
  loop: false,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");

export function draw(p, t) {
  const k = clamp(t / 0.24);
  // motes spiralling in, each dragging a short thread
  for (let i = 0; i < 8; i++) {
    const a0 = i * 0.785, kk = clamp((k - i * 0.02) / 0.75);
    if (kk <= 0 || kk >= 1) continue;
    const r = 24 * (1 - ease.inCubic(kk)), a = a0 + kk * 2.2;
    const x = Math.cos(a) * r, y = Math.sin(a) * r;
    p.px(x, y, WHITE);
    for (let j = 1; j < 5; j++) {
      const r2 = 24 * (1 - ease.inCubic(Math.max(0, kk - j * 0.03))), a2 = a0 + Math.max(0, kk - j * 0.03) * 2.2;
      p.px(Math.cos(a2) * r2, Math.sin(a2) * r2, j < 2 ? G0 : j < 4 ? G1 : G2);
    }
  }
  // the ring closing in
  if (k < 0.8) {
    const R = 18 * (1 - ease.inQuad(k / 0.8)) + 2, n = Math.max(8, Math.floor(R * 5));
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; if (i % 2 === 0 || k > 0.5) p.px(Math.cos(a) * R, Math.sin(a) * R, k < 0.5 ? G1 : G0); }
  }
  // the flash where they meet
  if (k > 0.72) {
    const q = (k - 0.72) / 0.28, L = Math.round(3 + 7 * Math.sin(q * Math.PI));
    for (let i = 0; i <= L; i++) { const c = i < L - 1 ? WHITE : G0; p.px(i, 0, c); p.px(-i, 0, c); p.px(0, i, c); p.px(0, -i, c); }
    p.glow(0, 0, 12, G0, 0.5 * Math.sin(q * Math.PI));
  }
  p.glow(0, 0, 10, G1, 0.15 + 0.2 * k);
}
