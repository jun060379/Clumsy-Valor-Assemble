// Luce's prayer, while she gathers it (0.7 s): her sigil draws itself under her feet, motes and slips of light like
// feathers lift off the floor round her and drift up, and a halo forms over her head out of a gathering ring.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce pray",
  desc: "A sigil draws itself under her feet, motes and feather-slips of light drift up round her, a halo gathers over her head.",
  tags: ["holy", "cast", "prayer", "one-shot"],
  size: [120, 120],
  origin: [60, 108],
  duration: 0.7,
  loop: false,
  fps: 50,
  options: { seed: 2, head: 66 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

function ellipse(p, cx, cy, rx, ry, c, upto, skip) {
  const n = Math.max(12, Math.floor((rx + ry) * 3));
  for (let i = 0; i < n; i++) {
    if (i / n > upto || (skip && skip(i, n))) continue;
    const a = -Math.PI / 2 + (i / n) * Math.PI * 2;
    p.px(cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, c);
  }
}

export function draw(p, t, o) {
  const k = clamp(t / 0.7), F = Math.floor(t / 0.02), sd = o.seed * 3.1, H = o.head;
  // the floor sigil: outer ring drawing round, inner ring, four ticks turning, a cross at the heart
  const dk = ease.outCubic(clamp(t / 0.35));
  ellipse(p, 0, 0, 34, 7.5, k > 0.6 ? G0 : G1, dk);
  ellipse(p, 0, 0, 22, 4.8, G2, dk, (i) => i % 3 === 0);
  for (let j = 0; j < 4; j++) {
    const a = t * 2.4 + (j * Math.PI) / 2;
    if (dk < 1) continue;
    const x = Math.cos(a) * 28, y = Math.sin(a) * 6.2;
    p.px(x, y, W1); p.px(x + 1, y, G0); p.px(x - 1, y, G0);
  }
  if (dk >= 1) { p.line(-6, 0, 6, 0, W1); p.px(0, -1, W1); p.px(0, 1, G1); }
  p.glow(0, -2, 30, G1, 0.12 + 0.18 * k);
  // motes and feather-slips lifting off the floor round her, faster as it gathers
  for (let i = 0; i < 14; i++) {
    const life = 0.5 - 0.15 * (i % 3) / 2, ph = ((t + hash(sd + i) * life) % life) / life;
    if (t < hash(sd + 20 + i) * 0.2) continue;
    const x0 = (hash(sd + 40 + i) - 0.5) * 60, x = x0 + Math.sin(ph * 5 + i) * 3 * (i % 2 ? 1 : -1), y = -ph * (50 + hash(sd + 60 + i) * 40);
    if (i % 3 === 0) { p.px(x, y, ph < 0.5 ? W1 : G0); p.px(x, y - 1, G1); p.px(x + (i % 2 ? 1 : -1), y + 1, G2); }    // a feather-slip
    else if (ph < 0.7 || ((i + F) & 1)) p.px(x, y, ph < 0.4 ? WHITE : ph < 0.7 ? G0 : G2);
  }
  // the halo gathering over her head: a wide faint ring closing in to a small bright one
  const hk = ease.inOutCubic(clamp((t - 0.15) / 0.5));
  if (t > 0.15) {
    const rx = 26 - 16 * hk, ry = rx * 0.28;
    ellipse(p, 0, -H, rx, ry, hk > 0.85 ? WHITE : hk > 0.5 ? G0 : G2, 1, (i) => hk < 0.5 && i % 2);
    if (hk > 0.6) ellipse(p, 0, -H + 1, rx, ry, G1, 1, (i, n) => Math.sin(-Math.PI / 2 + (i / n) * Math.PI * 2) < 0.2);
    if (hk > 0.85) p.glow(0, -H, 14, G0, 0.4 * (hk - 0.85) / 0.15);
  }
}
