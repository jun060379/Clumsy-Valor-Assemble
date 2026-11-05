// Kenin's mark on a foe (white/greys, tinted in game by how many stamps it wears): 0-0.12 s the stamp slams in — a
// wide ring snapping down past its size and settling, a white flash, four short burst lines; then (0.12-0.6 s, the
// loop) a hard-edged reticle: a ring with notches, four corner brackets that breathe in and out, a centre pip.
import { clamp, ease, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin mark",
  desc: "A reticle stamp slamming in (ring overshoot, flash, burst lines), then a breathing bracketed reticle loop; greys for tinting.",
  tags: ["ui", "mark", "kenin", "one-shot"],
  size: [40, 40],
  origin: [20, 20],
  duration: 0.6,
  loop: false,
  fps: 50,
  options: {},
};

const W = hex("#ffffff"), L = hex("#d8d8d8"), M = hex("#a0a0a0"), D = hex("#5a5a5a"), K = hex("#141414");

function ring(p, r, c, notch) {
  const n = Math.max(12, Math.floor(r * 7));
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    if (notch && Math.abs(Math.sin(a * 2)) < 0.22) continue;       // four notches, on the axes
    p.px(Math.round(Math.cos(a) * r), Math.round(Math.sin(a) * r), c);
  }
}

export function draw(p, t) {
  if (t < 0.12) {
    const k = t / 0.12;
    const r = k < 0.5 ? 13 - 11 * ease.inQuad(k / 0.5) : 2 + 3 * ease.outBack((k - 0.5) / 0.5);
    ring(p, r + 1, K); ring(p, r, k < 0.6 ? W : L);
    if (k < 0.5) ring(p, r - 1, M);
    if (k > 0.4 && k < 0.8) { p.disc(0, 0, 3, W, 1); for (let i = 0; i < 4; i++) { const a = Math.PI / 4 + (i * Math.PI) / 2, r0 = 7 + (k - 0.4) * 10; p.line(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * (r0 + 3), Math.sin(a) * (r0 + 3), W); } }
    return;
  }
  const u = (t - 0.12) / 0.48, br = Math.sin(u * Math.PI * 2);
  // the outline under everything, so it reads on any foe
  ring(p, 6, K); ring(p, 4, K);
  ring(p, 5, L, true);
  // corner brackets breathing
  const b = 8 + Math.round(br * 1);
  for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) {
    for (const [x, y, c] of [[b, b, W], [b - 1, b, L], [b - 2, b, M], [b, b - 1, L], [b, b - 2, M]]) { p.px(sx * (x + 1), sy * y, K); p.px(sx * x, sy * (y + 1), K); }
    for (const [x, y, c] of [[b, b, W], [b - 1, b, L], [b - 2, b, M], [b, b - 1, L], [b, b - 2, M]]) p.px(sx * x, sy * y, c);
  }
  // axis ticks through the notches
  for (const [x, y] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { p.px(x * 4, y * 4, M); p.px(x * 6, y * 6, W); p.px(x * 7, y * 7, L); }
  // centre pip
  p.px(0, 0, br > 0 ? W : L); p.px(1, 0, K); p.px(-1, 0, K); p.px(0, 1, K); p.px(0, -1, K);
}
