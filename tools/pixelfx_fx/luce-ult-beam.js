// Luce's ultimate, the beam (fires right from the fist): its spearhead races out across the whole frame in a few
// frames, then the beam stands at full width (white core, pale body, gold edges, a breathing dither of light round
// it), light pulses running down it, halo rings standing up across it and rolling out along it, edge sparks, its far
// end thinning out through a dither; then it draws in to a hairline from the fist outwards and breaks into motes.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce ult beam",
  desc: "A spearhead races out, the beam stands full (white core, gold edges, aura dither), pulses and upright halo rings roll along it, then it draws to a hairline and breaks into motes.",
  tags: ["holy", "beam", "ultimate", "one-shot"],
  size: [500, 128],
  origin: [28, 64],
  duration: 0.86,
  loop: false,
  fps: 50,
  options: { seed: 8 },
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };
const L = 470, BAY = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 2.9;
  const T0 = 0.07, T2 = 0.5, T3 = 0.66;
  const front = L * ease.outCubic(clamp(t / T0));
  let W = 20 * (t < T0 ? 0.55 + 0.75 * (t / T0) : 1 + 0.3 * (1 - ease.outCubic(clamp((t - T0) / 0.12)))) * (1 + 0.08 * Math.sin(F * 1.9));
  if (t > T2) W *= 1 - ease.inCubic(clamp((t - T2) / (T3 - T2)));
  // the first full frame: the whole channel punched white, rimmed gold
  if (t >= T0 && t < T0 + 0.025) {
    for (let x = 0; x < L; x++) for (let y = -30; y <= 30; y++) { const u = x / L; if (u > 0.85 && BAY[y & 3][x & 3] / 16 < (u - 0.85) / 0.15) continue; p.px(x, y, Math.abs(y) > 26 ? G1 : WHITE); }
  }
  if (W > 0.4) {
    // the aura dither
    const aw = W * 1.9;
    for (let x = 0; x < front; x++) for (let y = -Math.ceil(aw); y <= Math.ceil(aw); y++) {
      const ay = Math.abs(y);
      if (ay <= W - 1 || ay > aw) continue;
      const q = (ay - W) / (aw - W);
      if (hash(x * 13 + y * 7 + F * 3) < 0.09 * (1 - q)) p.px(x, y, q < 0.4 ? G0 : G1);
    }
    // the body, thinning out over the last sixth through an ordered dither, a hot neck at the fist
    for (let x = 0; x < front; x++) {
      const u = x / L, w = W * (0.85 + 0.15 * Math.min(1, x / 30)) * (x < 14 ? 1.25 - x / 56 : 1) * (1 + 0.05 * Math.sin(x * 0.11 - t * 60));
      for (let y = -Math.ceil(w); y <= Math.ceil(w); y++) {
        const ay = Math.abs(y);
        if (ay > w) continue;
        if (u > 0.83 && BAY[(y + 64) & 3][x & 3] / 16 < (u - 0.83) / 0.17) continue;
        const q = ay / Math.max(0.5, w);
        const flow = ((Math.floor(x * 0.2 - t * 140) % 9) + 9) % 9 === 0 && q < 0.55;
        p.px(x, y, flow || q < 0.3 ? WHITE : q < 0.55 ? W1 : q < 0.8 ? G0 : q < 0.94 ? G1 : G2);
      }
    }
    // two strands of light twisting round it
    for (let x = 0; x < front * 0.86; x++) for (const s0 of [0, Math.PI]) {
      const a = x * 0.07 - t * 30 + s0, y = Math.sin(a) * (W * 1.15 + 2);
      p.px(x, y, Math.cos(a) > 0 ? (((x >> 2) + F) % 5 === 0 ? WHITE : G0) : G2);
    }
    // the root: a rounded cap swelling out of the fist (no flat cut), a hot bulb of light and a flare on it
    const R = W * 1.1;
    for (let x = -Math.ceil(R); x < 0; x++) {
      const w = W * 1.25 * Math.sqrt(Math.max(0, 1 - (x / R) * (x / R)));
      for (let y = -Math.ceil(w); y <= Math.ceil(w); y++) {
        const q = Math.abs(y) / Math.max(0.5, w);
        if (q > 1) continue;
        p.px(x, y, q < 0.45 ? WHITE : q < 0.7 ? W1 : q < 0.88 ? G0 : G1);
      }
    }
    p.disc(2, 0, W * 0.75, WHITE, 1);
    const fl = 10 + W * 0.9 + 4 * Math.sin(F * 1.3);
    for (let i = 0; i <= fl; i++) { const c = i < fl * 0.4 ? WHITE : i < fl * 0.75 ? W1 : G0; p.px(2, -W * 0.6 - i, c); p.px(2, W * 0.6 + i, c); }
    for (let i = 0; i <= fl * 0.6; i++) { const c = i < fl * 0.3 ? WHITE : G0; p.px(2 - W * 0.6 - i, 0, c); }
    p.glow(0, 0, W * 2.4, G0, 0.4);
    // the spearhead while it races out
    if (t < T0 + 0.03) for (let i = 0; i < 18; i++) { const hw = (18 - i) * 0.9; p.line(front + i, -hw * 0.3, front + i, hw * 0.3, i < 6 ? WHITE : G0); }
    // edge sparks running out along it
    for (let i = 0; i < 12; i++) {
      const life = 0.2, a = ((t + hash(sd + i) * life) % life) / life, side = i % 2 ? 1 : -1;
      const x = a * front, y = side * (W * 1.08 + 1 + Math.sin(a * 11 + i) * 2);
      p.px(x, y, a < 0.5 ? WHITE : G0); p.px(x - 1, y, G1);
    }
  } else if (t < T3 + 0.07) {
    const q = clamp((t - T3) / 0.07);
    for (let x = 0; x < L * 0.85; x++) if (hash(x * 7 + F) > q) p.px(x, 0, q < 0.5 ? W1 : G1);
  }
  // halo rings standing up across the beam, rolling out along it
  for (let i = 0; i < 4; i++) {
    const st = T0 + i * 0.07, k = clamp((t - st) / 0.32);
    if (t < st || k >= 1) continue;
    const cx = 20 + k * L * 0.8, ry = 30 + k * 14, rx = ry * 0.24, n = Math.floor(ry * 4);
    for (let j = 0; j < n; j++) {
      const a = (j / n) * Math.PI * 2, x = cx + Math.cos(a) * rx, y = Math.sin(a) * ry;
      if (Math.cos(a) < -0.1 && Math.abs(y) < W + 1) continue;        // the far side hides behind the beam
      if (k > 0.6 && j % 2) continue;
      p.px(x, y, k < 0.35 ? W1 : k < 0.7 ? G0 : G2);
    }
  }
  // motes where it stood
  const mk = clamp((t - T2) / 0.34);
  for (let i = 0; i < 22; i++) {
    const q = clamp(mk * 1.3 - hash(sd + 30 + i) * 0.3);
    if (q <= 0 || q >= 1) continue;
    const x = hash(sd + 50 + i) * L * 0.85, y = (hash(sd + 70 + i) - 0.5) * 30 - q * 22;
    if (q < 0.5 || ((i + F) & 1) === 0) p.px(x, y, q < 0.5 ? W1 : G1);
  }
  if (W > 0.4) p.glow(front * 0.4, 0, 60, G1, 0.2);
}
