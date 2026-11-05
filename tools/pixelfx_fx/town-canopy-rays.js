// Clumsy Valor town (owner 2026-11-06): sun through a big tree's canopy. Built on weather/god-rays (its banded light,
// strands and motes, adapted there from Sprite Fusion's open-source holy light, MIT, Copyright (c) 2026 Hugo Duprez).
import { fit, clamp, rand, mix, TAU, WHITE } from "../../core/index.js";
import { clip, rows } from "./_lib.js";

export const meta = {
  name: "Town canopy rays",
  desc: "Sun through gaps in a canopy: crisp slanting shafts, banded and threaded with strands, landing as bright dapples; motes flash in them.",
  tags: ["weather", "god rays", "light", "sunbeam", "canopy", "tree", "dapple", "dust", "ambient", "loop"],
  size: [360, 230],
  origin: [180, 216],
  duration: 6,
  loop: true,
  fps: 12,
  bg: "light",
  options: {
    palette: ["#4a3410", "#8a6a2c", "#d4a94e", "#f4d886", "#fff4cc", "#ffffff"],
    seed: 5,
  },
};

const D = 6, W = 360, X0 = -180;
// the sun high on the left: shafts lean down to the right by this slope (dx per dy)
const SL = 0.32;
// gaps in the canopy: x where a shaft leaves the leaves (at y = top), half width, strength, breathing cycles
const GAPS = [
  { x: -132, top: -150, h: 6, k: 0.8, b: 1 },
  { x: -96, top: -176, h: 4, k: 0.6, b: 2 },
  { x: -56, top: -160, h: 9, k: 1.1, b: 1 },
  { x: -18, top: -184, h: 3, k: 0.6, b: 3 },
  { x: 18, top: -158, h: 7, k: 0.95, b: 2 },
  { x: 58, top: -174, h: 5, k: 0.75, b: 1 },
  { x: 96, top: -150, h: 3, k: 0.55, b: 2 },
];
const STR = new Float32Array(720);

function gaps(t, S) {
  for (let i = 0; i < 720; i++) {
    const a = i / 720;
    STR[i] = 0.5 + 0.5 * Math.sin(a * 260 + Math.sin((TAU * t) / D) * 2 + S) * Math.sin(a * 97 - (TAU * t) / D + S * 2);
  }
  return GAPS.map((g, i) => ({ ...g, x: g.x + 1.5 * Math.sin((TAU * t) / D + i * 1.3), h: g.h * (1 + 0.18 * Math.sin((TAU * g.b * t) / D + i)), k: g.k * (0.7 + 0.3 * Math.sin((TAU * g.b * t) / D + i * 2.1)) }));
}

// light at a point: inside a shaft (measured across it at that height): a cone widening as it falls, brightest just
// under the leaves and fading toward the ground, its top ragged where the leaves cut it
function lightAt(x, y, G) {
  let e = 0;
  for (const g of G) {
    const d = y - g.top;
    if (d < 0) continue;
    const cx = g.x + d * SL, w = g.h * (1 + d / 90), q = Math.abs(x - cx) / w;
    if (q >= 1) continue;
    // the top: cut by leaf edges (a few whole-pixel notches across the shaft), faded in over a dozen rows
    const notch = 4 * Math.abs(Math.sin(Math.floor(x - cx) * 0.9 + g.x));
    const fin = clamp((d - notch) / 12), fall = clamp(1.25 - d / 230, 0.3, 1);
    e += g.k * (1 - q * q) ** 0.8 * fin * fall;
  }
  return e;
}

export function drawBack(p, t, o) {
  const q = clip(p, meta), S = o.seed, C = fit(o.palette, 6);
  const G = gaps(t, S);
  const L = C.map((c) => mix(C[0], c, 0.8));
  rows(p, meta, -200, 12, (y, R) => {
    const floor = y > 0;
    for (let i = 0; i < W; i++) {
      const x = X0 + i + 0.5;
      // on the floor a shaft lands where it would have reached y = 0, spread into a dapple a few rows deep
      let e = lightAt(x, floor ? 0 : y, G);
      if (e <= 0) continue;
      const si = (((x - y * SL) + 260) * 1.3) | 0;
      e *= 0.55 + 0.6 * STR[si < 0 ? 0 : si > 719 ? 719 : si];
      if (floor) e *= 1.9 - y / 7;
      if (e < 0.1) continue;
      const lv = e > 0.95 ? 5 : e > 0.7 ? 4 : e > 0.45 ? 3 : e > 0.25 ? 2 : 1;
      R.c[i] = floor ? C[lv] : L[lv];
      R.a[i] = floor ? Math.min(0.9, 0.35 + e * 0.45) : Math.min(0.7, 0.1 + e * 0.5);
      R.b[i] = 1;
      R.l[i] = C[3];
      R.k[i] = e * (floor ? 0.3 : 0.18);
    }
  });
  motes(q, t, S, C, G, false);
}

export function draw(p, t, o) {
  const q = clip(p, meta), S = o.seed, C = fit(o.palette, 6);
  motes(q, t, S, C, gaps(t, S), true);
}

function motes(q, t, S, C, G, front) {
  for (let i = front ? 0 : 40; i < (front ? 40 : 110); i++) {
    const R = (k) => rand(S, i, k), n1 = 1 + Math.floor(R(1) * 2), n2 = 1 + Math.floor(R(2) * 2);
    const x = -170 + R(3) * 330 + (6 + R(4) * 10) * Math.sin((TAU * n1 * t) / D + R(5) * TAU);
    const y = -180 + R(6) * 176 + (5 + R(7) * 8) * Math.sin((TAU * n2 * t) / D + R(8) * TAU);
    const e = lightAt(x, y, G);
    if (e < 0.15) continue;
    const k = Math.min(1, e);
    q.px(x, y, k > 0.6 ? WHITE : k > 0.3 ? C[4] : C[3]);
    if (front && R(9) < 0.4 && k > 0.5) q.px(x + 1, y, C[3]);
    q.glow(x, y, 4, C[3], 0.35 * k);
  }
}
