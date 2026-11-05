// Aida's ult rift (땅 밑의 문), after the game's hollow, toward a ZZZ-style Hollow: a slow-churning hole of pitch-black
// void whose lobes breathe like a bubble, edged by an oily iridescent band whose colours flow slowly round it
// (dithered between neighbouring hues), aurora streaks sliding over its rim, flakes of ether drifting off, and now
// and then a glitch line slipping sideways. Springs open, holds in a seamless 1.2 s loop, sinks shut.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Aida ult portal",
  desc: "A slow pitch-black hollow with breathing lobes, an oily iridescent edge flowing round it, aurora streaks, drifting ether flakes and glitch lines.",
  tags: ["arcane", "portal", "rift", "void", "hollow", "one-shot"],
  size: [136, 136],
  origin: [68, 68],
  duration: 1.7,
  loop: false,
  fps: 30,
  options: { R: 37, seed: 2 },
};

const IRIS = ["#ff6fae", "#ffa96b", "#ffe97a", "#86ffb4", "#6fd8ff", "#8f8cff", "#e07aff"].map(hex);
const RIMV = hex("#b06cff"), EDGE = hex("#1c0830"), CORE = hex("#030106"), DEEP = hex("#0c0418");
const TAU = Math.PI * 2, OPEN = 0.25, HOLD = 1.2, CLOSE = OPEN + HOLD, OM = TAU / HOLD;
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

export function draw(p, t, o) {
  const R = o.R, sd = o.seed;
  const ta = t < OPEN || t >= CLOSE ? t : OPEN + ((t - OPEN) % HOLD);
  const op = t < OPEN ? ease.outBack(clamp(t / OPEN), 1.3) : t < CLOSE ? 1 : 1 - ease.inCubic(clamp((t - CLOSE) / OPEN));
  const R0 = R * op, ph = ta * OM;
  if (R0 < 1) return;
  const B = [[0, 0, 0.8, 0]];
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * TAU + sd + ph * (i % 2 ? -1 : 1);
    B.push([Math.cos(a) * 0.5, Math.sin(a) * 0.46, 0.5 + 0.06 * Math.sin(sd + i), i + 1]);
  }
  const lobes = B.map(([x, y, r, k]) => [x * R0, y * R0, r * R0 * (1 + 0.07 * Math.sin(ph + k * 1.7))]);
  const field = (X, Y) => { let d = 1e9; for (const [x, y, r] of lobes) d = Math.min(d, Math.hypot(X - x, Y - y) - r); return d; };
  const M = Math.ceil(R0 * 1.2) + 8;
  // the glitch: twice a loop a few rows slip sideways for a moment
  const gl = Math.sin(ph * 2 + 1.3) > 0.93 ? Math.round(3 * Math.sin(ph * 7)) : 0, gy0 = Math.round(-R0 * 0.3 + R0 * 0.6 * ((Math.floor(ta * 5) * 0.37) % 1));
  p.shade(-M, -M, M, M, (xx, yy, out) => {
    const sx = gl && yy >= gy0 && yy < gy0 + 3 ? xx - gl : xx;
    const X = sx + 0.5, Y = yy + 0.5, d = field(X, Y);
    if (d > 4.5) return;
    const ang = Math.atan2(Y, X), bay = BAYER[(yy & 3) * 4 + (xx & 3)] / 16;
    if (d > 0) {
      // the oily edge: hue flowing slowly round, dithered between neighbours, fading out at its outer side
      const hu = ((ang / TAU + ta / HOLD) % 1 + 1) % 1 * 7, i0 = Math.floor(hu), f = hu - i0;
      const fade = 1 - d / 4.5;
      if (bay > fade * 1.2) return;
      out.c = IRIS[(f > bay ? i0 + 1 : i0) % 7];
      return;
    }
    if (d > -1) { out.c = RIMV; return; }
    // inside: pitch black, a deep edge, and aurora streaks sliding round just inside the rim
    const au = Math.sin(ang * 3 - ph + Math.sin(ph * 0.5) * 0.6), band = d > -6 && d < -2.5 && au > 0.75;
    if (band) { out.c = IRIS[Math.floor(((ang / TAU + ta / HOLD) % 1 + 1) % 1 * 7)]; out.a = bay < 0.5 ? 0.85 : 0.0; if (out.a > 0) return; }
    out.c = d > -2.5 ? EDGE : d > -8 ? DEEP : CORE;
  });
  // flakes of ether drifting off the edge, slow, in and out of the loop
  for (let i = 0; i < 9; i++) {
    const k = ((ta / HOLD) * 1 + i / 9) % 1, a = sd * 2 + i * 2.4 + k * 0.6, rr = R0 * (1.02 + 0.45 * k);
    const x = Math.round(Math.cos(a) * rr), y = Math.round(Math.sin(a) * rr - k * 6), c = IRIS[(i * 3) % 7];
    if (k < 0.85) { p.px(x, y, c, 1 - k); if (i % 3 === 0) p.px(x + 1, y, c, (1 - k) * 0.7); }
  }
  p.glow(0, 0, R0 * 1.1, RIMV, 0.12);
}
