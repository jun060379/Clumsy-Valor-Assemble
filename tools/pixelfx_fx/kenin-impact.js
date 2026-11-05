// Kenin's round striking (faces right: the round came from the left): a small white pop, a spray of brass and orange
// sparks thrown back toward the shooter and out, a little dust puff, one bright ricochet streak.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin impact",
  desc: "A white pop, brass/orange sparks sprayed back and out, a dust puff, a ricochet streak.",
  tags: ["gun", "impact", "kenin", "one-shot"],
  size: [72, 64],
  origin: [40, 32],
  duration: 0.3,
  loop: false,
  fps: 50,
  options: { seed: 3 },
};

const CR = hex("#fff4cf"), Y = hex("#ffd06a"), O = hex("#f08a3a"), BR = hex("#f1c35a"), OL = hex("#e2f5b8");
const S1 = hex("#8a8276"), S2 = hex("#5e584f");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 4.1;
  if (F < 3) {
    const k = [1, 0.7, 0.35][F], L = 9 * k;
    p.disc(0, 0, 4 * k + 1, F ? CR : WHITE, 1);
    for (let i = 0; i <= L; i++) { p.px(-i, 0, i < L * 0.5 ? WHITE : Y); p.px(0, -i * 0.7, CR); p.px(0, i * 0.7, CR); p.px(i * 0.5, 0, Y); }
    p.glow(0, 0, 12, Y, 0.5 * k);
  }
  // sparks thrown back toward the shooter (left) and out
  const pk = clamp(t / 0.24);
  if (pk < 1) for (let i = 0; i < 9; i++) {
    const a = Math.PI + (hash(sd + i) - 0.5) * 2.2, v = 14 + hash(sd + 10 + i) * 22;
    const x = Math.cos(a) * v * ease.outCubic(pk), y = Math.sin(a) * v * ease.outCubic(pk) + 16 * pk * pk;
    if (pk > 0.6 && ((i + F) & 1)) continue;
    p.px(x, y, pk < 0.3 ? WHITE : i % 3 === 0 ? OL : pk < 0.6 ? BR : O);
    if (pk < 0.4) p.px(x + Math.cos(a) * -1.5, y + Math.sin(a) * -1.5, O);
  }
  // the ricochet streak
  const sk = clamp(t / 0.1);
  if (sk < 1) { const a = -2.4 + hash(sd + 30) * 0.6, r0 = sk * 26, r1 = r0 + 8 * (1 - sk); p.line(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * r1, Math.sin(a) * r1, sk < 0.5 ? WHITE : Y); }
  // dust puff
  for (let i = 0; i < 3; i++) {
    const k = clamp((t - 0.02) / 0.26);
    if (k <= 0 || k >= 1 || (k > 0.6 && ((i + F) & 1))) continue;
    p.disc(-3 - i * 3 - k * 6, (i - 1) * 3 - k * 4, 1.2 + k * 2, k < 0.5 ? S1 : S2, 1);
  }
}
