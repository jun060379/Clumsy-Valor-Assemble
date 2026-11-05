// Luce's prayer let go: the halo over her flashes, a thin ring of light rolls out across the floor like the stroke of
// a bell (a second, fainter one after it), and small crosses and slips of light rain softly down over the party.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce bless",
  desc: "The halo flashes, a thin bell-stroke ring rolls out across the floor (and a fainter echo), small crosses and light slips rain down.",
  tags: ["holy", "heal", "buff", "one-shot"],
  size: [320, 180],
  origin: [160, 160],
  duration: 0.9,
  loop: false,
  fps: 50,
  options: { seed: 3, head: 66 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

function ring(p, rx, ry, c, skip) {
  const n = Math.max(16, Math.floor((rx + ry) * 3));
  for (let i = 0; i < n; i++) {
    if (skip && skip(i, n)) continue;
    const a = (i / n) * Math.PI * 2;
    p.px(Math.cos(a) * rx, Math.sin(a) * ry, c);
  }
}

function cross(p, x, y, r, c) {
  p.px(x, y, WHITE);
  for (let i = 1; i <= r; i++) { p.px(x + i, y, c); p.px(x - i, y, c); p.px(x, y - i, c); p.px(x, y + i * 1.6, c); }
}

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 2.3, H = o.head;
  // the halo flash
  const fk = clamp(t / 0.18);
  if (fk < 1) {
    const L = 22 * Math.sin(fk * Math.PI) + 3;
    for (let i = 0; i <= L; i++) { const c = i < L * 0.4 ? WHITE : G0; p.px(i, -H, c); p.px(-i, -H, c); }
    for (let i = 0; i <= L * 0.6; i++) { p.px(0, -H - i, i < L * 0.3 ? WHITE : G0); p.px(0, -H + i, i < L * 0.3 ? WHITE : G0); }
    ring(p, 10 + 8 * fk, (10 + 8 * fk) * 0.28, fk < 0.5 ? WHITE : G0);
    p.glow(0, -H, 30, G0, 0.6 * (1 - fk));
  }
  // the bell stroke: a thin ring rolling out across the floor, an echo after it
  for (const [st, a0] of [[0.02, 1], [0.16, 0.55]]) {
    const k = clamp((t - st) / 0.55);
    if (t < st || k >= 1) continue;
    const rx = 18 + 142 * ease.outCubic(k), ry = rx * 0.2;
    const col = a0 < 1 ? (k < 0.5 ? G1 : G2) : k < 0.25 ? WHITE : k < 0.55 ? G0 : G1;
    ring(p, rx, ry, col, (i, n) => (k > 0.6 && i % 2) || (a0 < 1 && i % 2));
    if (a0 >= 1 && k < 0.4) ring(p, rx - 1.5, ry - 0.5, G0, (i, n) => Math.sin((i / n) * Math.PI * 2) < 0);
  }
  // crosses and slips of light raining softly down over the party
  for (let i = 0; i < 16; i++) {
    const st = 0.08 + hash(sd + i) * 0.35, k = clamp((t - st) / 0.42);
    if (t < st || k >= 1) continue;
    const x = (hash(sd + 20 + i) - 0.5) * 280, y = -H - 40 - hash(sd + 40 + i) * 30 + k * (70 + hash(sd + 60 + i) * 40) + Math.sin(k * 6 + i) * 2;
    if (i % 3 === 0) cross(p, x, y, k < 0.5 ? 2 : 1, k < 0.6 ? G0 : G2);
    else if (k < 0.75 || ((i + F) & 1)) { p.px(x, y, k < 0.4 ? WHITE : G0); p.px(x, y - 1, G1); }
  }
}
