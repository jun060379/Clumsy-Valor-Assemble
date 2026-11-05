// Clumsy Valor town (owner 2026-11-06): the river under the bridge, a seamless loop that tiles left to right.
import { fit, tileFbm, wrap, rand, TAU } from "../../core/index.js";

export const meta = {
  name: "Town river",
  desc: "A slow river seen side-on: a bright broken waterline, flow streaks sliding downstream, glints winking on the swell, and the water stepping darker with depth.",
  tags: ["water", "river", "stream", "surface", "flow", "ambient", "loop", "tile"],
  size: [240, 96],
  origin: [0, 0],
  duration: 4,
  loop: true,
  fps: 15,
  bg: "ground",
  options: {
    palette: ["#16304a", "#1d3d5e", "#264f78", "#3f6f9e", "#5f93c4", "#9fc7e6", "#e3f4ff"],
    seed: 3,
  },
};

const D = meta.duration, W = 240, H = 96;

export function drawBack(p, t, o) {
  const C = fit(o.palette, 7), S = o.seed, ph = t / D;
  // the flow: everything scrolls downstream (right) by exactly one tile per loop near the top, slower deeper down
  p.shade(0, 0, W, H, (x, y, out) => {
    const yy = Math.floor(y), xx = Math.floor(x);
    const sp = yy < 6 ? 2 : 1;                          // tiles per loop: the surface runs faster
    const u = wrap(xx - ph * W * sp, W);
    const n = (tileFbm(u / 30, yy / 9, W / 30, 0, S, 3) + 1) / 2;
    // depth: hard ramp steps, the steps wobbling with the noise so they are not ruler lines
    const d = yy + (n - 0.5) * 10;
    let lv = d < 3 ? 4 : d < 12 ? 3 : d < 30 ? 2 : d < 58 ? 1 : 0;
    // the waterline: bright, broken where the swell dips
    if (yy === 0) lv = n > 0.42 ? 6 : 5;
    else if (yy === 1 && n > 0.62) lv = 5;
    // flow streaks: thin light dashes riding the surface layers downstream
    if (yy > 1 && yy < 30) {
      const s = (tileFbm(u / 18, yy / 2.2, W / 18, 0, S + 7, 2) + 1) / 2;
      if (s > 0.72 - yy * 0.004) lv = Math.min(6, lv + (yy < 10 ? 2 : 1));
    }
    out.k = lv >= 5 ? 0.12 : 0;
    return C[lv];
  });
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), S = o.seed, ph = t / D;
  // glints: single pixels that wink on the swell crests, each on its own whole-number blink rate
  for (let i = 0; i < 26; i++) {
    const R = (k) => rand(S, i, k);
    const y = Math.floor(R(1) ** 2 * 22) + 1, sp = y < 6 ? 2 : 1;
    const x = Math.floor(wrap(R(2) * W + ph * W * sp, W));
    const b = Math.sin(TAU * (ph * (1 + Math.floor(R(3) * 3)) + R(4)));
    if (b < 0.55) continue;
    p.px(x + 0.5, y + 0.5, C[6]);
    if (b > 0.85) { p.px(x - 0.5, y + 0.5, C[5]); p.px(x + 1.5, y + 0.5, C[5]); }
    p.glow(x + 0.5, y + 0.5, 3, C[5], 0.25);
  }
}
