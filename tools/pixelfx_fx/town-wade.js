// Clumsy Valor town (owner 2026-11-06): a foot kicking through river water. Beads and rings from water/_lib.
import { fit, rand, clamp, ease } from "../../core/index.js";
import { WATER, bead, ring } from "./_lib.js";

export const meta = {
  name: "Town wade",
  desc: "A stride through knee-deep water: a fan of beads kicked forward and up off the waterline, a white lip where the leg cuts it, rings spreading as the beads fall back in.",
  tags: ["water", "splash", "wade", "step", "river", "one-shot"],
  size: [80, 48],
  origin: [30, 36],
  duration: 0.95,
  loop: false,
  fps: 30,
  bg: "ground",
  options: { palette: ["#16304a", "#1d3d5e", "#264f78", "#3f6f9e", "#5f93c4", "#9fc7e6", "#e3f4ff", "#ffffff"], seed: 4 },
};

const G = 520, SY = 0.25, N = 11;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), S = o.seed;
  // the lip: water pushed up white where the leg cuts it, gone in a few frames
  const lk = 1 - clamp(t / 0.22);
  if (lk > 0) {
    const w = 4 + 6 * ease.outCubic(clamp(t / 0.15));
    for (let x = -w; x <= w; x++) {
      const h = Math.round((1 - (x / w) ** 2) * 3 * lk);
      for (let y = 0; y <= h; y++) p.px(x + 0.5, -y - 0.5, y === h ? C[7] : C[6], lk);
    }
  }
  // the kicked beads: most go forward (right) and up, a few back; each lands with a ring of its own
  for (let i = 0; i < N; i++) {
    const R = (k) => rand(S, i, k);
    const t0 = R(1) * 0.08, a = t - t0;
    if (a < 0) continue;
    const vx = (R(2) < 0.75 ? 1 : -0.6) * (25 + R(3) * 55), vy = -(70 + R(4) * 90), s = R(5) < 0.3 ? 3 : R(5) < 0.7 ? 2 : 1;
    const x = vx * a, y = vy * a + 0.5 * G * a * a, land = (-2 * vy) / G;
    if (a < land) bead(p, x, y, vx, vy + G * a, s, C);
    else {
      const k = 1 - clamp((a - land) / 0.25);
      ring(p, vx * land, 0, 1.5 + (a - land) * 22, SY, k * 0.8, C, { n: 1 });
    }
  }
  // the ring round the leg
  const rk = clamp(t / 0.1) * (1 - clamp((t - 0.1) / 0.6));
  ring(p, 0, 0, 3 + t * 30, SY, rk, C, { n: 2, gap: 3 });
}
