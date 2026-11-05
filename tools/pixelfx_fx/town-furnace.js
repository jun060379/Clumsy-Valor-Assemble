// Clumsy Valor town (owner 2026-11-06): the forge's hearth. Fire recipe from fire/brazier (adapted there from
// Sprite Fusion's open-source fire, MIT, Copyright (c) 2026 Hugo Duprez).
import { fit, mix, rand, WHITE } from "../../core/index.js";
import { noiseFor, hotFirst, burn, looped, drift, spark, ember } from "./_lib.js";

export const meta = {
  name: "Town furnace",
  desc: "A forge hearth roaring: a wide bed of white-hot coals breathing, a wall of flame drawn up into the flue, sparks spat out.",
  tags: ["fire", "forge", "furnace", "hearth", "coals", "sparks", "ambient", "loop"],
  size: [100, 75],
  origin: [50, 73],
  duration: 3,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
    seed: 11,
  },
};

const D = meta.duration, NL = noiseFor(D), BED = -4, RX = 30;
// a wall of tongues across the hearth: [x, y from the bed, height share, half-width, back row?]
const TONGUES = [
  [-24, 0.5, 0.35, 2.2, 1], [-16, -0.5, 0.62, 2.6, 1], [-8, -1, 0.85, 2.8, 1], [0, -1.5, 1, 3.2, 1], [8, -1, 0.88, 2.8, 1], [16, -0.5, 0.66, 2.6, 1], [24, 0.5, 0.38, 2.2, 1],
  [-20, 1, 0.28, 1.8, 0], [-12, 0.5, 0.5, 2.4, 0], [-4, 0, 0.72, 3, 0], [4, 0, 0.75, 3, 0], [12, 0.5, 0.52, 2.4, 0], [20, 1, 0.3, 1.8, 0],
];

// the coal bed: a low heap filling the hearth, lumps breathing white to red, hottest in the middle
function coals(p, H, t, S) {
  p.shade(-RX, BED - 6, RX, 1, (x, y, out) => {
    const top = BED - 1 - 4 * Math.max(0, 1 - (x / RX) ** 2) - 1.5 * Math.sin(x * 0.7 + S);
    if (y < top || y > 0.5 || Math.abs(x) > RX - 0.5) return;
    const lump = rand(Math.floor((x + Math.floor(y) * 1.5) / 3), Math.floor(y / 2), S + 20), edge = y < top + 1;
    if (rand(Math.floor(x), Math.floor(y), S + 21) < 0.12 || (edge && lump < 0.25)) return H[8];
    const mid = 1 - Math.abs(x) / RX;
    const g = (0.5 + 0.5 * Math.sin((t / D) * Math.PI * 4 + lump * 40)) * (0.55 + 0.45 * mid) * (edge ? 0.75 : 1);
    out.k = 0.4 * g;
    return g > 0.7 ? H[0] : g > 0.52 ? H[1] : g > 0.36 ? H[2] : g > 0.22 ? H[3] : g > 0.12 ? H[4] : H[5];
  });
}

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), S = o.seed;
  const fl = 0.78 + 0.14 * NL(t, 7.3, S + 1) + 0.08 * NL(t, 19, S + 2), GLOW = mix(mix(H[2], H[3], 0.5), WHITE, 0.2);
  // the back of the hearth glowing with the heat
  p.glow(0, -20, 46, GLOW, 0.5 * fl);
  p.glow(0, -6, 26, H[1], 0.45 * fl);
  burn(p, t, TONGUES, {
    H, D, NL, S, x: 0, y: BED, height: 44, lean: -0.05, spread: 14,
    puffs: 10, licks: 6, smoke: 0, smokeSize: 2, smokeLife: [1, 1.5], embers: 8, glowR: 52, glow: 1.5, wind: 1,
    mid: () => coals(p, H, t, S),
  });
  // sparks spat out of the coals: quick arcs that fall back, and a few drawn up the flue
  const SPARKS = [H[1], H[2], H[4], H[5]], EMB = [H[1], H[2], H[4], H[6]];
  looped(t, D, 26, S + 600, (r) => {
    const side = r.range(-1, 1), up = r.chance(0.45);
    return { x: side * 20, y: BED - r.range(1, 6), vx: side * r.range(15, 45), vy: -r.range(up ? 80 : 40, up ? 140 : 90), g: up ? -20 : 160, life: r.range(0.4, 0.9), big: r.chance(0.15), a: r.range(0, 6.3) };
  }, (q, age) => {
    const [x, y, vx, vy] = drift(q.x, q.y, q.vx, q.vy, age, 0, q.g, 1.4, 1.4), k = 1 - age / q.life;
    if (y > 0) return;
    if (Math.hypot(vx, vy) > 40) spark(p, x, y, vx, vy, k, SPARKS);
    else ember(p, x, y, k, q.big ? 2 : 1, EMB, age * 40 + q.a);
  });
}
