// Town: the forge's hearth fire (owner 2026-11-08: "용광로 fx가 많이 허접해서 다시 짜야할것 같음"). Drawn on the town's
// 2-px grid: one pixel here is one 2-px cell in the game (the bake doubles it). The hearth mouth of the pixel3d forge is
// 42 cells wide and 29 tall, its floor on y = 0: inside it a back wall lit hard from below in stepped bands, a long bed
// of coals that breathe, a row of tongues licking up off the coals (a tall pair in the middle, smaller toward the
// sides), and now and then a pop that throws sparks; embers ride the draught up and out of the mouth.
// The tongue, lick and ember recipe is shared with fire/town-campfire (Sprite Fusion's open-source fire, MIT,
// Copyright (c) 2026 Hugo Duprez).
import { Rng, fit, mix, hex, rand, clamp, WHITE } from "../../core/index.js";
import { noiseFor, hotFirst, flameTongue, lick, ember, spark, drift, sparkAt, looped, LAYERS, BACK_LAYERS } from "./_lib.js";

export const meta = {
  name: "Town Forge Hearth",
  desc: "Town: the forge's hearth through its arched mouth - a stepped glowing back wall, chunky breathing coals, bold tongues, pops and embers drifting out (2-px cells).",
  tags: ["fire", "forge", "hearth", "prop", "light", "ambient", "loop"],
  size: [64, 60],
  origin: [32, 52],
  duration: 4,
  loop: true,
  fps: 12,
  bg: "dark",
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    part: "all",          // "inside": the mouth (back wall, coals, flames); "out": the embers and sparks; "all"
    seed: 5,
  },
};

const D = meta.duration, NL = noiseFor(D);
// the mouth: 42 x 29 cells, a round arch over straight jambs (the forge sprite's dark opening, x 92..175 / y 216..273)
const HW = 21, MH = 29, SPRING = 13;          // half width, height, height of the jambs before the arch
const inMouth = (x, y) => {
  if (y > 0 || y < -MH || Math.abs(x + 0.5) > HW) return false;
  const h = -y;
  if (h <= SPRING) return true;
  const ry = MH - SPRING, u = (x + 0.5) / HW, v = (h - SPRING) / ry;
  return u * u + v * v <= 1.0;
};
const WALL = [hex("#1a0607"), hex("#33100f"), hex("#561a14"), hex("#7f2617"), hex("#a8381a")];

// the tongues: [x, height, half-width, back row]
const TONGUES = [
  [-11, 9, 3.0, 1], [11, 10, 3.0, 1], [-2.5, 15, 3.4, 1], [3, 16, 3.4, 1],
  [-16, 5, 2.4, 0], [16, 5.5, 2.4, 0], [-7, 10, 3.2, 0], [7.5, 11, 3.2, 0], [0, 14, 3.8, 0],
];
// the coals: chunky lumps along the bed, [x, y, rx, ry]
const COALS = [];
{ const r = new Rng(41); let x = -HW + 1.5;
  while (x < HW - 1) { const rx = r.range(1.6, 2.6); COALS.push([x + rx, -r.range(1.2, 2.2), rx, r.range(1.2, 1.8), r.next()]); x += rx * 2 - r.range(0.2, 0.8); }
  x = -HW + 6;
  while (x < HW - 6) { const rx = r.range(1.6, 2.4); COALS.push([x + rx, -r.range(3.2, 4.4), rx, r.range(1.1, 1.6), r.next()]); x += rx * 2 + r.range(0.5, 2.5); } }

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), S = o.seed, R = new Rng(S);
  const inside = o.part !== "out", out = o.part !== "inside";
  const N = (rate, seed = 0, off = 0) => NL(t, rate, seed, off);
  const fla = (tt) => 0.78 + 0.14 * NL(tt, 3, S + 1) + 0.08 * NL(tt, 9, S + 2), fl = fla(t);
  const EMB = [H[1], H[2], H[4], H[6]], SPARKS = [H[1], H[2], H[4], H[5]];

  if (inside) {
    // the back wall: dark, lit from the coals in hard bands that rise and fall with the fire
    p.shade(-HW - 1, -MH - 1, HW + 1, 1, (x, y, q) => {
      if (!inMouth(x, y)) return;
      const d = Math.hypot(x / 1.7, (y + 1) * 1.0) / (MH * 0.95);
      const b = clamp(1.05 - d + 0.12 * (fl - 0.85) + 0.05 * N(2, S + 30, x * 0.15));
      return b > 0.8 ? WALL[4] : b > 0.62 ? WALL[3] : b > 0.42 ? WALL[2] : b > 0.22 ? WALL[1] : WALL[0];
    });
    // the coal bed: a dark heap, chunky coals in it, each with a dark rim and a heart that breathes
    p.shade(-HW, -6, HW, 0, (x, y) => {
      if (!inMouth(x, y)) return;
      const top = -3.2 - 1.6 * Math.cos((x / HW) * 1.45);
      if (y < top) return;
      return WALL[1];
    });
    for (const [cx, cy, rx, ry, h] of COALS) {
      const mid = 1 - Math.abs(cx) / HW;
      const g = (0.5 + 0.5 * Math.sin((t / D) * Math.PI * 2 * (1 + Math.floor(h * 3)) + h * 40)) * (0.5 + 0.5 * mid) * fl;
      p.ellipse(cx, cy, rx, ry, (d) => (d > 0.8 ? WALL[0] : d > 0.5 ? (g > 0.45 ? H[3] : H[4]) : g > 0.62 ? H[1] : g > 0.35 ? H[2] : H[3]));
    }
    // the flames
    const T = TONGUES.map(([dx, h, w, back], i) => ({ dx: dx + R.range(-0.3, 0.3), h: h * R.range(0.9, 1.1), w, back, n: (S * 7 + i) * 13 }));
    const height = (i, tt) => {
      const { h, n } = T[i], leap = Math.max(0, NL(tt, 2, n + 70) - 0.55) * 1.2;
      return (h + 0.25 * h * NL(tt, 3, n) + h * leap) * fla(tt);
    };
    const sway = (i, tt, h) => NL(tt, 2, T[i].n + 40) * (0.6 + h * 0.06) - clamp(T[i].dx * 0.06, -1, 1);
    const tip = (i, tt) => { const h = height(i, tt); return [T[i].dx + sway(i, tt, h) * 0.85, -2 - h * 0.85, h]; };
    const tongue = (i) => {
      const { dx, w, n, back } = T[i], h = height(i, t);
      flameTongue(p, dx, -3, h, w, sway(i, t, h), N, n, H, back ? BACK_LAYERS : LAYERS, 0.25, 0.7);
    };
    for (let i = 0; i < T.length; i++) if (T[i].back) tongue(i);
    for (let i = 0; i < T.length; i++) if (!T[i].back) tongue(i);
    looped(t, D, T.length * 4, S + 220, (r, j) => ({ i: j % T.length, vx: r.range(-1.5, 1.5), vy: -r.range(8, 14), s: r.range(0.7, 1.1), life: 0.3 }), (q, age) => {
      const [tx, ty] = tip(q.i, t - age);
      lick(p, tx + q.vx * age, ty - 1 + q.vy * age, 1 - age / q.life, q.s, H);
    });
    // the light inside the mouth only (the bake keeps it within the opening)
    // (no soft glow: the hearth light is the stepped wall and the stones round the mouth, baked by the town)
  }

  if (out) {
    // pops: a flash on the coals and a few sparks thrown up and out of the mouth
    looped(t, D, 3, S + 400, (r) => ({ x: r.range(-12, 12), y: -r.range(2, 4), n: r.int(2, 4), seed: r.int(0, 1e6), life: 0.6 }), (q, age) => {
      if (age < 0.09) p.px(q.x, q.y, WHITE);
      const r = new Rng(q.seed);
      for (let j = 0; j < q.n; j++) {
        const a = -Math.PI / 2 + r.range(-0.7, 0.7), sp = r.range(50, 90), life = r.range(0.3, 0.55);
        if (age >= life) continue;
        const [x, y, vx, vy] = sparkAt(q.x, q.y, Math.cos(a) * sp, Math.sin(a) * sp, age, 6, 200);
        spark(p, x, y, vx, vy, 1 - age / life, SPARKS);
      }
    });
    // embers on the draught: up the mouth, out under the arch's crown and away up the wall
    looped(t, D, 14, S + 500, (r) => ({ x: r.range(-8, 8), y: -r.range(6, 12), vx: r.range(-4, 4), vy: -r.range(9, 16), life: r.range(1.6, 3), a: r.range(0, 6.3) }), (q, age) => {
      const [x, y] = drift(q.x, q.y, q.vx, q.vy, age, 0, -6, 0.6, 0.4);
      ember(p, x + 2.5 * (Math.sin(age * 2.1 + q.a) - Math.sin(q.a)), y, 1 - age / q.life, 1, EMB, age * 30 + q.a);
    });
  }
}
