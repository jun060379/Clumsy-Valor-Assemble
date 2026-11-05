// Luce's holy orb in flight (moving right; the game turns it to its heading): a living ball of light, not a still badge.
// A white core that throbs, a corona of flickering tongues that stream back into a comet tail, two bright swirls
// turning inside the shell, a tilted ring orbiting it with a travelling glint, and sparks flowing off the tail.
import { WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce orb",
  desc: "A throbbing white core, a flickering corona streaming back into a comet tail, swirls turning inside, a tilted orbiting ring and sparks flowing off the tail.",
  tags: ["holy", "projectile", "orb", "loop"],
  size: [72, 40],
  origin: [44, 20],
  duration: 0.32,
  loop: true,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };
// a looping 1D noise over angle and time (the period divides the loop)
const nz = (a, ph, k) => 0.5 * Math.sin(a * 3 + ph * 2 + k) + 0.3 * Math.sin(a * 5 - ph * 3 + k * 2) + 0.2 * Math.sin(a * 9 + ph * 5);

export function draw(p, t) {
  const ph = (t / 0.32) * Math.PI * 2, F = Math.floor(t / 0.02);
  const throb = 0.5 + 0.5 * Math.sin(ph * 2);
  p.glow(0, 0, 18, G0, 0.35 + 0.15 * throb);
  // the comet tail: a tapering stream behind, its edges licking
  p.shade(-34, -9, 0, 9, (x, y, out) => {
    const u = -x / 34, w = 3.4 * Math.pow(1 - u, 1.4) * (1 + 0.25 * Math.sin(u * 11 - ph * 3));
    const yy = y - Math.sin(u * 6 - ph * 2) * 1.2 * u;
    if (Math.abs(yy) > w) return;
    if (u > 0.55 && ((x + y + F) & 1)) return;           // the end breaks into dither
    const q = Math.abs(yy) / Math.max(0.5, w);
    out.c = u < 0.2 && q < 0.4 ? WHITE : q < 0.45 ? (u < 0.45 ? W1 : G0) : u < 0.5 ? G1 : G2;
  });
  // the corona: flickering tongues all round, longer at the back where they stream away
  p.shade(-14, -11, 11, 11, (x, y, out) => {
    const d = Math.hypot(x, y), a = Math.atan2(y, x), back = Math.max(0, -Math.cos(a));
    const R = 6.4 + 1.1 * nz(a, ph, 0) + back * (2 + 1.6 * nz(a, ph, 4));
    if (d > R || d < 5) return;
    out.c = d > R - 1 ? (back > 0.5 ? G1 : W1) : W1;     // a crisp flickering rim of light, not a fire
  });
  // the shell and the throbbing core
  p.shade(-6, -6, 6, 6, (x, y, out) => {
    const d = Math.hypot(x, y);
    if (d > 5.4) return;
    const core = 2.2 + throb * 1.2;
    out.c = d < core ? WHITE : d < core + 1.4 ? W1 : d < 4.8 ? G0 : x + y < 0 ? G0 : G1;
  });
  // two bright swirls turning inside the shell
  for (let j = 0; j < 2; j++) {
    for (let i = 0; i < 6; i++) {
      const a = ph * 2 + j * Math.PI + i * 0.22, r = 3.6 - i * 0.15;
      p.px(Math.cos(a) * r, Math.sin(a) * r, i < 2 ? WHITE : W1);
    }
  }
  // the tilted ring orbiting it, the back half behind the shell and the front half over it
  for (const front of [false, true]) {
    for (let i = 0; i < 52; i++) {
      const a = (i / 52) * Math.PI * 2 + ph, x = Math.cos(a) * 13, y = Math.sin(a) * 4.2;
      if ((Math.sin(a) > 0) !== front) continue;
      const rx = x * 0.92 - y * 0.4, ry = x * 0.4 + y * 0.92;
      if (!front && Math.hypot(rx, ry) < 7) continue;
      p.px(rx, ry, front ? (Math.cos(a - ph * 2) > 0.85 ? WHITE : G1) : G3);
    }
  }
  // sparks flowing off the tail, drifting back and winking out
  for (let i = 0; i < 7; i++) {
    const life = 0.32 / (1 + (i % 2)), a = ((t + hash(i) * life) % life) / life;
    const x = -6 - a * (26 + hash(i + 3) * 10), y = (hash(i + 5) - 0.5) * 12 * (0.4 + a) + Math.sin(a * 7 + i) * 1.2;
    if (a < 0.45) { p.px(x, y, WHITE); p.px(x + 1, y, G0); }
    else if (a < 0.85 && ((i + F) & 1) === 0) p.px(x, y, a < 0.65 ? G0 : G2);
  }
}
