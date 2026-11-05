// Luce's spear striking home (pointing right; the game turns it to the flight): an impact frame of a long white
// four-point star along the thrust rimmed gold, a halo ring stamped across the line of flight that rings out and
// thins to dots, the spear bursting forward into slim shards of light that slow and dim, small crosses left hanging.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce spear hit",
  desc: "Long white star along the thrust rimmed gold, a halo ring stamped across the flight ringing out to dots, the spear bursting forward into slim shards, small crosses hanging.",
  tags: ["holy", "impact", "spear", "directional", "one-shot"],
  size: [120, 96],
  origin: [44, 48],
  duration: 0.34,
  loop: false,
  fps: 50,
  options: { seed: 2 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

function star(p, ax, ay, rx, ry, rim, fill) {
  const M = Math.ceil(Math.max(rx, ry) + 2);
  p.shade(-M, -M, M, M, (x, y, out) => {
    const d = Math.pow(Math.abs(x) / rx, 0.5) + Math.pow(Math.abs(y) / ry, 0.5);   // an astroid: four sharp points
    if (d <= 0.82) out.c = fill;
    else if (d <= 1) out.c = rim;
  });
}

function cross(p, x, y, r, c) {
  p.px(x, y, WHITE);
  for (let i = 1; i <= r; i++) { p.px(x + i, y, c); p.px(x - i, y, c); p.px(x, y + i, c); p.px(x, y - i, c); }
}

export function draw(p, t, o) {
  const F = t / 0.02, sd = o.seed * 7.1;
  if (F < 1) { star(p, 0, 0, 34, 16, G1, WHITE); p.glow(0, 0, 30, G0, 0.7); return; }
  if (F < 2) { star(p, 0, 0, 40, 11, G0, WHITE); star(p, 0, 0, 10, 10, W1, WHITE); p.glow(0, 0, 26, G0, 0.5); }
  // the halo ring stamped across the flight: an upright ellipse ringing out and thinning to dots
  const rk = clamp((t - 0.02) / 0.17);
  if (rk < 1) {
    const ry = 8 + 20 * ease.outQuart(rk), rx = ry * 0.34, w = 3.4 * (1 - rk);
    const n = Math.floor(ry * 4);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2, x = Math.cos(a) * rx + 4 * rk, y = Math.sin(a) * ry;
      if (w < 0.8 && i % 2) continue;
      const c = rk < 0.25 ? WHITE : rk < 0.55 ? G0 : rk < 0.8 ? G1 : G2;
      p.px(x, y, c);
      if (w > 1.2) p.px(x - 1, y, c);
      if (w > 2.2) p.px(x + 1, y, rk < 0.3 ? W1 : G1);
    }
  }
  // the core: a white diamond shrinking out
  const ck = clamp((t - 0.02) / 0.1);
  if (ck < 1) star(p, 0, 0, 12 * (1 - ck) + 1, 7 * (1 - ck) + 1, G1, WHITE);
  // slim shards of light bursting forward, slowing and dimming
  const sk = clamp((t - 0.02) / 0.28);
  if (sk < 1) {
    for (let i = 0; i < 7; i++) {
      const a = (hash(sd + i) - 0.5) * 1.1, v = 30 + hash(sd + 9 + i) * 34;
      const d0 = 4 + v * ease.outCubic(sk), len = (10 + hash(sd + 3 + i) * 8) * (1 - sk);
      const c = Math.cos(a), s = Math.sin(a);
      for (let u = 0; u < len; u += 0.5) p.px(c * (d0 - u), s * (d0 - u), u < 2 ? WHITE : u < len * 0.5 ? G0 : G1);
    }
  }
  // a few crosses left hanging where the shards passed
  for (let i = 0; i < 4; i++) {
    const at = 0.06 + i * 0.03, k = clamp((t - at) / 0.2);
    if (t < at || k >= 1) continue;
    const a = (hash(sd + 20 + i) - 0.5) * 1.6, d = 16 + hash(sd + 30 + i) * 26;
    cross(p, Math.cos(a) * d, Math.sin(a) * d - k * 4, k < 0.4 ? 2 : 1, k < 0.6 ? G0 : G2);
  }
  const pop = Math.exp(-t / 0.05);
  if (pop > 0.03) p.glow(0, 0, 24, G1, 0.35 * pop);
}
