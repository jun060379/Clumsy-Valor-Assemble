// The spear kicking off (pointing right): a halo ring snapping out at the tail across the line of flight, a puff of
// light thrown back, three speed lines whipping back from the guard.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce spear launch",
  desc: "A halo ring snapping out at the tail across the flight, a puff of light thrown back, speed lines whipping back.",
  tags: ["holy", "launch", "spear", "one-shot"],
  size: [96, 48],
  origin: [64, 24],
  duration: 0.18,
  loop: false,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");

export function draw(p, t) {
  const k = clamp(t / 0.18), e = ease.outCubic(k);
  const ry = 5 + 13 * e, rx = ry * 0.3, x0 = -6 - 10 * e;
  const n = Math.floor(ry * 4);
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    if (k > 0.6 && i % 2) continue;
    p.px(x0 + Math.cos(a) * rx, Math.sin(a) * ry, k < 0.2 ? WHITE : k < 0.5 ? G0 : k < 0.8 ? G1 : G2);
  }
  for (let j = -1; j <= 1; j++) {
    const y = j * 4, L = 40 * (1 - k) * (j ? 0.7 : 1), xs = -8 - 30 * e;
    for (let u = 0; u < L; u += 0.5) p.px(xs - u, y + j * u * 0.04, u < 3 ? WHITE : u < L * 0.5 ? G0 : G1);
  }
  if (k < 0.35) { p.disc(-4, 0, 5 * (1 - k * 2), W1, 1); p.glow(-4, 0, 14, G0, 0.6 * (1 - k * 2.8)); }
}
