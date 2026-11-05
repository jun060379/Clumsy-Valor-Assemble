// Luce's third blow, a pillar of judgement: a sigil ring draws itself on the floor with a cross at its heart, a beam of
// light erupts out of it (white core, gold edges, a dithered top), halo rings climb the beam and widen as they go, a
// four-point flare blooms at the base, a shock ring runs along the floor; then the beam draws in to a hairline and is
// gone, motes drifting up where it stood.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce pillar",
  desc: "A floor sigil with a cross, a beam of light erupting (white core, gold edges, dithered top), halo rings climbing it, a base flare and floor shock ring, then the beam draws to a hairline and fades into rising motes.",
  tags: ["holy", "ground", "pillar", "one-shot"],
  size: [180, 260],
  origin: [90, 236],
  duration: 0.6,
  loop: false,
  fps: 50,
  options: { seed: 4 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };
const H = 236;

function ellipse(p, cx, cy, rx, ry, c, skip) {
  const n = Math.max(12, Math.floor((rx + ry) * 3));
  for (let i = 0; i < n; i++) {
    if (skip && skip(i, n)) continue;
    const a = (i / n) * Math.PI * 2;
    p.px(cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, c);
  }
}

export function draw(p, t, o) {
  const sd = o.seed * 3.7, F = Math.floor(t / 0.02);
  const T0 = 0.08, T1 = 0.13, T2 = 0.34, T3 = 0.5;
  // the floor sigil: a ring drawing itself round, an inner ring, a cross at its heart, tick runes
  const sk = ease.outCubic(clamp(t / T0)), sf = 1 - clamp((t - T2) / 0.2);
  if (sf > 0) {
    const R = 40, drawn = sk;
    ellipse(p, 0, 0, R, R * 0.24, sf > 0.5 ? G1 : G2, (i, n) => i / n > drawn || (t > T2 && i % 2));
    ellipse(p, 0, 0, R * 0.62, R * 0.62 * 0.24, G2, (i, n) => i / n > drawn || i % 3 === 0);
    for (let i = 0; i < 12; i++) {
      if (i / 12 > drawn) continue;
      const a = (i / 12) * Math.PI * 2, x = Math.cos(a) * R * 0.81, y = Math.sin(a) * R * 0.81 * 0.24;
      p.px(x, y - 1, G0); p.px(x, y, G1);
    }
    // an outer ring of rune dashes turning slowly
    for (let i = 0; i < 20; i++) {
      if (i / 20 > drawn || i % 2 || t > T0 + 0.04) continue;      // the rune dashes only while it gathers
      const a = (i / 20) * Math.PI * 2 + t * 3, x0 = Math.cos(a) * (R + 6), y0 = Math.sin(a) * (R + 6) * 0.24;
      p.line(x0 - 2, y0, x0 + 2, y0, sf > 0.5 ? G0 : G2);
    }
    // the heart: a cross over a diamond
    const cw = 11 * sk;
    if (t < T0) { p.line(-cw, 0, cw, 0, W1); p.line(0, -cw * 0.3, 0, 0, W1); }
    if (t < T0) for (let i = 0; i <= 4; i++) { p.px(-4 + i, -i * 0.25, G1); p.px(4 - i, -i * 0.25, G1); p.px(-4 + i, i * 0.25, G1); p.px(4 - i, i * 0.25, G1); }
  }
  if (t < T0) { p.glow(0, -2, 24, G1, 0.35 * sk); return; }
  // the beam: erupts fast to full height, holds, then draws in to a hairline
  const ek = ease.outQuart(clamp((t - T0) / (T1 - T0)));
  const top = -H * ek;
  let W = 15 * ek * (1 + 0.15 * Math.sin(F * 1.7));
  if (t > T2) W *= 1 - ease.inCubic(clamp((t - T2) / (T3 - T2)));
  if (t > T3) W = 0;
  if (t >= T0 && t < T0 + 0.018) {
    // the eruption frame: a wide white column punched through the whole height, rimmed gold
    for (let y = -H; y <= 0; y++) for (let x = -18; x <= 18; x++) {
      if ((-y / H) > 0.85 && ((x + y) & 1)) continue;
      p.px(x, y, Math.abs(x) > 15 ? G1 : WHITE);
    }
  }
  if (W > 0.3) {
    // the aura: a loose dither of light round the beam, breathing
    const aw = W * 2.1;
    for (let y = Math.floor(top); y <= 0; y += 1) {
      const u = -y / H;
      if (u > 0.85) continue;
      for (let x = -Math.ceil(aw); x <= Math.ceil(aw); x++) {
        const ax = Math.abs(x);
        if (ax <= W + 1 || ax > aw) continue;
        const qd = (ax - W) / (aw - W);
        if (hash(x * 13 + y * 7 + F * 3) < 0.16 * (1 - qd)) p.px(x, y, qd < 0.4 ? G0 : G2);
      }
    }
    for (let y = Math.floor(top); y <= 0; y++) {
      const u = (0 - y) / H;                                   // 0 at the floor, 1 at the top
      const flare = 1;
      const w = W * flare * (0.8 + 0.2 * (1 - u)) * (1 + 0.045 * Math.sin(y * 0.09 + t * 50));
      for (let x = -Math.ceil(w); x <= Math.ceil(w); x++) {
        const ax = Math.abs(x);
        if (ax > w) continue;
        const q = ax / Math.max(0.5, w);
        // it runs off the top of the frame: thinning out through an ordered dither over its last fifth
        if (u > 0.8) { const fd = (u - 0.8) / 0.2, bay = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]][(y & 3 + 4) % 4][(x + 64) & 3] / 16; if (bay < fd) continue; }
        // light flowing up the core: two bright streaks rising
        const flow = ((Math.floor(-y * 0.25 - t * 120) % 7) + 7) % 7 === 0 && ax <= 1;
        p.px(x, y, flow || q < 0.25 ? WHITE : q < 0.5 ? W1 : q < 0.78 ? G0 : q < 0.93 ? G1 : G2);
      }
    }
    // where it meets the floor: a pool of light it sinks into (no hard cut), breathing with the beam
    const prx = W * 2.3 + 2, pry = prx * 0.24;
    for (let y = -Math.ceil(pry); y <= Math.ceil(pry); y++) for (let x = -Math.ceil(prx); x <= Math.ceil(prx); x++) {
      const d = Math.hypot(x / prx, y / pry);
      if (d > 1) continue;
      if (d > 0.75 && ((x + y + F) & 1)) continue;
      p.px(x, y, d < 0.35 ? WHITE : d < 0.6 ? W1 : d < 0.82 ? G0 : G1);
    }
    for (let y = -10; y < -Math.ceil(pry) + 1; y++) {            // the beam's foot glowing into the pool
      const ww = W * (1 + 0.6 * (y + 10) / 10);
      for (let x = -Math.ceil(ww); x <= Math.ceil(ww); x++) if (Math.abs(x) <= ww && Math.abs(x) > W * 0.9 && ((x + y + F) & 1) === 0) p.px(x, y, G0);
    }
    // edge sparks running up the beam's sides
    for (let i = 0; i < 8; i++) {
      const life = 0.18, a = ((t + hash(sd + i) * life) % life) / life;
      const side = i % 2 ? 1 : -1, y = -a * H * 0.9, x = side * (W * 1.05 + 1 + Math.sin(a * 9 + i) * 1.5);
      if (y > top) p.px(x, y, a < 0.5 ? WHITE : G0);
    }
  } else if (t < T3 + 0.06) {
    const q = clamp((t - T3) / 0.06);                          // the last hairline, splitting
    for (let y = Math.floor(top); y <= 0; y += 1) if (hash(y * 7 + F) > q) p.px(0, y, q < 0.5 ? W1 : G1);
  }
  // halo rings climbing the beam, widening as they rise
  for (let i = 0; i < 3; i++) {
    const st = T1 + i * 0.05, k = clamp((t - st) / 0.22);
    if (t < st || k >= 1) continue;
    const y = -(20 + k * (H * 0.75)), r = 18 + k * 18;
    const hid = (j, n) => Math.sin((j / n) * Math.PI * 2) < -0.1 && Math.abs(Math.cos((j / n) * Math.PI * 2)) * r < W + 1;
    ellipse(p, 0, y, r, r * 0.22, k < 0.4 ? W1 : k < 0.7 ? G0 : G2, (j, n) => (k > 0.6 && j % 2) || hid(j, n));
    if (k < 0.6) ellipse(p, 0, y + 1, r, r * 0.22, k < 0.3 ? G0 : G1, (j, n) => Math.sin((j / n) * Math.PI * 2) < 0.2 || hid(j, n));
  }
  // the base flare: a four-point star blooming where it erupts
  const fk = clamp((t - T0) / 0.16);
  if (fk < 1) {
    const L = 26 * Math.sin(fk * Math.PI) + 2, Lv = L * 0.45;
    for (let i = 0; i <= L; i++) { const c = i < L * 0.4 ? WHITE : i < L * 0.75 ? G0 : G1; p.px(i, -3, c); p.px(-i, -3, c); }
    for (let i = 0; i <= Lv; i++) { const c = i < Lv * 0.5 ? WHITE : G0; p.px(0, -3 - i, c); p.px(0, -3 + i, c); }
    p.glow(0, -6, 40, G0, 0.6 * (1 - fk));
  }
  // the floor shock ring
  const rk = clamp((t - T0) / 0.28);
  if (rk > 0 && rk < 1) {
    const R = 16 + 66 * ease.outCubic(rk);
    ellipse(p, 0, 0, R, R * 0.16, rk < 0.3 ? WHITE : rk < 0.6 ? G0 : G2, (j, n) => Math.sin((j / n) * Math.PI * 2) < -0.15 || (rk > 0.55 && j % 2));
  }
  // light flecks kicked off the floor by the eruption
  const kk = clamp((t - T0) / 0.3);
  if (kk > 0 && kk < 1) {
    for (let i = 0; i < 14; i++) {
      const side = i % 2 ? 1 : -1, v = 30 + hash(sd + 80 + i) * 60, up = 20 + hash(sd + 100 + i) * 40;
      const x = side * (6 + v * ease.outCubic(kk)), y = -up * Math.sin(kk * Math.PI) * (1 - kk * 0.3);
      if (kk < 0.7 || ((i + F) & 1) === 0) p.px(x, y, kk < 0.35 ? WHITE : kk < 0.65 ? G0 : G2);
    }
  }
  // motes rising where it stood
  const mk = clamp((t - T2) / 0.26);
  for (let i = 0; i < 12; i++) {
    const q = clamp(mk * 1.3 - hash(sd + 20 + i) * 0.3);
    if (q <= 0 || q >= 1) continue;
    const x = (hash(sd + 40 + i) - 0.5) * 30, y = -hash(sd + 60 + i) * H * 0.8 - q * 30;
    if (q < 0.5 || ((i + F) & 1) === 0) p.px(x, y, q < 0.5 ? W1 : G1);
  }
  if (W > 0.3) p.glow(0, top * 0.5, 34, G1, 0.22);
}
