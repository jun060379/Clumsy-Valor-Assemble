// Luce's holy spear in flight, after the game's luceBoltFx (a long blade forward, a crossbar hilt, light streaks behind),
// redrawn with more care: a slender lance with a white core, pale-gold flats and a hard gold edge, a winged crossguard
// with a jewel, a thin halo ring round the shaft seen edge-on, a tip glint that pulses, and three silk ribbons of light
// trailing and rippling behind, shedding small four-point twinkles. Points right; the game rotates it to its flight.
import { clamp, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce spear",
  desc: "A slender holy lance (white core, pale-gold flats, gold edge), winged crossguard with a jewel, an edge-on halo, a pulsing tip glint and three rippling silk ribbons of light shedding twinkles.",
  tags: ["holy", "projectile", "spear", "loop"],
  size: [132, 32],
  origin: [84, 16],
  duration: 0.32,
  loop: true,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a"), G4 = hex("#5a3a18");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

function twinkle(p, x, y, r, c) {
  p.px(x, y, WHITE);
  for (let i = 1; i <= r; i++) { const cc = i === r ? c : W1; p.px(x + i, y, cc); p.px(x - i, y, cc); p.px(x, y + i, cc); p.px(x, y - i, cc); }
}

export function draw(p, t) {
  const ph = (t / 0.32) * Math.PI * 2;
  // the wake: one silk ribbon of light tapering behind, rippling, its end breaking into dither, and two hairline
  // threads either side that weave across it
  const tailL = 54;
  for (let u = 0; u < tailL; u += 0.5) {
    const k = u / tailL, x = -15 - u, y = Math.sin(ph - u * 0.15) * 1 * k;
    const w = 1.8 * (1 - k) ** 1.1;
    if (k > 0.55 && ((Math.floor(u * 2) + Math.floor(t * 50)) & 1) === 1) continue;
    const c = k < 0.12 ? WHITE : k < 0.35 ? W1 : k < 0.6 ? G0 : k < 0.8 ? G1 : G2;
    p.px(x, y, c);
    for (let o = 0.5; o <= w; o += 0.5) { p.px(x, y - o, o > w - 0.6 ? G1 : c); p.px(x, y + o, o > w - 0.6 ? G2 : c); }
  }
  for (const sg of [-1, 1]) {
    const len = 42;
    for (let u = 0; u < len; u += 0.5) {
      const k = u / len, x = -14 - u, y = sg * (2.5 * Math.sin(u * 0.14 + ph * sg) * (0.4 + k));
      if (k > 0.6 && ((Math.floor(u * 2)) & 1) === 1) continue;
      p.px(x, y, k < 0.3 ? G0 : k < 0.65 ? G1 : G2);
    }
  }
  // twinkles shed along the wake, drifting back and fading
  for (let i = 0; i < 4; i++) {
    const life = 0.32, a = ((t + i * life / 5) % life) / life;
    const x = -20 - a * 40 - hash(i) * 6, y = (hash(i + 9) - 0.5) * 10 + Math.sin(a * 6 + i) * 1.5;
    if (a < 0.7) twinkle(p, x, y, a < 0.3 ? 1 : 0, a < 0.35 ? G0 : G1);
    else if (((i + Math.floor(t * 50)) & 1) === 0) p.px(x, y, G2);
  }
  // the grip behind the guard, a pommel jewel at its end
  p.line(-13, 0, -4, 0, G2);
  p.line(-13, -1, -4, -1, G1);
  for (let x = -12; x < -4; x += 3) p.px(x, 0, G4);
  p.disc(-14, 0, 1.4, G1, 1);
  p.px(-14, -1, WHITE);
  // the ring of the cross (a Celtic halo round the guard), its bright arc travelling round
  const cx = -2, hr = 5;
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * Math.PI * 2, lit = Math.cos(a - ph * 2) > 0.75;
    p.px(cx + Math.cos(a) * hr, Math.sin(a) * hr, lit ? WHITE : G1);
  }
  // the blade: long, slim, swelling a little past the guard and drawing to a needle point
  const L = 40;
  for (let u = 0; u <= L; u += 0.5) {
    const k = u / L, hw = k < 0.1 ? 1.2 + k * 8 : 2.0 * Math.pow(1 - (k - 0.1) / 0.9, 0.7);
    const x = u - 1;
    for (let v = -Math.ceil(hw); v <= Math.ceil(hw); v++) {
      const av = Math.abs(v);
      if (av > hw + 0.3) continue;
      p.px(x, v, av < 0.5 ? WHITE : av >= hw - 0.4 ? (v < 0 ? G1 : G3) : v < 0 ? W1 : G0);
    }
  }
  for (let u = 3; u < 18; u++) if ((u + Math.floor(t * 50)) % 5 < 2) p.px(u, 0, W1);
  // the crossbar: upright, tapering to diamond tips, a jewel at the crossing
  for (let y = -7; y <= 7; y++) {
    const ay = Math.abs(y), w = ay > 5 ? 0 : 1;
    p.px(cx - 1, y, ay > 5 ? G2 : G1);
    p.px(cx, y, ay > 5 ? G1 : ay < 2 ? WHITE : W1);
    if (w) p.px(cx + 1, y, G3);
  }
  for (const s of [-1, 1]) { p.px(cx, s * 8, G0); }
  p.disc(cx, 0, 1.6, G1, 1);
  p.px(cx, 0, WHITE);
  const L_TIP = L - 1;
  // the tip glint: a four-point star breathing at the point
  const gk = 0.5 + 0.5 * Math.sin(ph * 2);
  twinkle(p, L_TIP + 2, 0, 1 + Math.round(gk * 2), G0);
  p.glow(L_TIP + 2, 0, 7, G0, 0.25 + 0.2 * gk);
  p.glow(cx, 0, 14, G1, 0.18);
}
