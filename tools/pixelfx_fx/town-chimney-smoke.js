// Clumsy Valor town (owner 2026-11-06): smoke off a chimney. Puffs from fire/_lib (Sprite Fusion's open-source fire
// recipe, MIT, Copyright (c) 2026 Hugo Duprez).
import { fit, mix } from "../../core/index.js";
import { looped, smokePuff } from "./_lib.js";

export const meta = {
  name: "Town chimney smoke",
  desc: "Smoke rolls out of a chimney mouth in soft lit puffs that swell, curl and lean away on a light breeze, thinning out.",
  tags: ["fire", "smoke", "chimney", "ambient", "loop"],
  size: [96, 150],
  origin: [24, 140],
  duration: 4,
  loop: true,
  fps: 20,
  bg: "sky",
  options: {
    palette: ["#5a5660", "#8a8690", "#b8b4bc"],
    size: 4,
    seed: 4,
  },
};

const D = meta.duration;

export function draw(p, t, o) {
  const C = fit(o.palette, 3), S = o.seed, sz = o.size;
  // each puff leaves the mouth slowly, rises, and the breeze takes it more the higher it gets; a slow curl on it
  looped(t, D, 30, S + 100, (r) => ({ x: r.range(-2, 2), life: r.range(3, 4), up: r.range(34, 42), lean: r.range(3.5, 6), ph: r.range(0, 6.3), s: r.range(0.8, 1.25), big: r.chance(0.3) }), (q, age) => {
    const k = 1 - age / q.life, u = age / q.life;
    const x = q.x + q.lean * age * age * 0.9 + 3 * Math.sin(age * 2.1 + q.ph) * u, y = -q.up * age * (1 - u * 0.25);
    smokePuff(p, x, y, k, sz * q.s * (1 + u * 1.4), mix(C[1], C[2], 0.5), q.big, 1.0);
  });
}
