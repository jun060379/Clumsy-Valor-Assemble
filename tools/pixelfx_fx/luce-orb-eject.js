// The orb kicking off (moving right; the game turns it to the heading): a white cross flash where it was, a round ring
// of light popping out and breaking into dots, a few beads thrown back, and two short trails whipping back.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce orb eject",
  desc: "White cross flash, a round ring popping out to dots, beads thrown back, two short trails whipping back.",
  tags: ["holy", "launch", "orb", "one-shot"],
  size: [64, 48],
  origin: [40, 24],
  duration: 0.2,
  loop: false,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t) {
  const k = clamp(t / 0.2), e = ease.outCubic(k);
  // the cross flash
  if (k < 0.3) {
    const L = Math.round(9 * (1 - k / 0.3)) + 2;
    for (let i = 0; i <= L; i++) { const c = i < L - 2 ? WHITE : G0; p.px(i, 0, c); p.px(-i, 0, c); p.px(0, i, c); p.px(0, -i, c); }
    p.disc(0, 0, 3 * (1 - k / 0.3) + 1, WHITE, 1);
    p.glow(0, 0, 14, G0, 0.6 * (1 - k / 0.3));
  }
  // the round ring popping out
  const R = 4 + 12 * e, n = Math.floor(R * 5);
  for (let i = 0; i < n; i++) {
    if (k > 0.5 && i % 2) continue;
    const a = (i / n) * Math.PI * 2;
    p.px(Math.cos(a) * R - 3 * e, Math.sin(a) * R, k < 0.25 ? WHITE : k < 0.5 ? G0 : k < 0.75 ? G1 : G2);
    if (k < 0.35) p.px(Math.cos(a) * (R - 1) - 3 * e, Math.sin(a) * (R - 1), W1);
  }
  // beads thrown back
  for (let i = 0; i < 6; i++) {
    const a = Math.PI + (hash(i) - 0.5) * 1.6, d = 4 + (12 + hash(i + 7) * 14) * e;
    if (k < 0.85) p.px(Math.cos(a) * d, Math.sin(a) * d, k < 0.4 ? WHITE : G1);
  }
  // two short trails whipping back
  for (const j of [-1, 1]) {
    const L = 18 * (1 - k), xs = -4 - 14 * e;
    for (let u = 0; u < L; u += 0.5) p.px(xs - u, j * (3 + u * 0.12), u < 2 ? WHITE : u < L * 0.5 ? G0 : G1);
  }
}
