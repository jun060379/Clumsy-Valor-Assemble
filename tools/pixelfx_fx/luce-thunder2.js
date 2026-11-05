// Luce's holy thunder for the up-attack, built on the library's lightning strike (Sprite Fusion lineage, MIT) in her
// gold: its sigil, stepped leader, stroke flicker, floor cracks with racing arcs and cooling channel kept, the clock
// re-timed for an attack — the sigil and leader squeezed into the first 0.16 s, the strike and its arcs at full
// speed, the long cooling hurried — so the whole thing reads in about 0.9 s.
import { create as strike } from "./luce-strike.js";

export const meta = {
  name: "Luce thunder (strike)",
  desc: "The library lightning strike in Luce's gold, re-timed for an attack: quick sigil and leader, full-speed strike and floor arcs, hurried cooling (6x).",
  tags: ["holy", "lightning", "strike", "one-shot"],
  size: [240, 264],
  origin: [120, 228],
  duration: 1.0,
  loop: false,
  fps: 50,
  options: { seed: 5 },
};

const GOLD = ["#2a1a08", "#5a3a18", "#a8742a", "#d89a3a", "#ffc85a", "#ffecaa", "#fff8dc", "#ffffff"];
const SPARK = ["#ffffff", "#fff8dc", "#ffecaa", "#ffc85a"];

// real time -> the strike's own time: 0..0.16 s covers its 0.30..0.76 (sigil up, leader down), then 1:1 through the
// strike and re-strikes (to 1.36), then 3x through the cooling
function libT(t) {
  if (t < 0.16) return 0.3 + (t / 0.16) * 0.46;
  if (t < 0.76) return 0.76 + (t - 0.16);
  return 1.36 + (t - 0.76) * 6.0;
}

export function create(o) {
  const inner = strike({ palette: GOLD, sparks: SPARK, seed: o.seed });
  let t = 0, lt = 0;
  // run it up to where we start (its sigil already drawn in)
  while (lt < 0.3) { inner.update(1 / 100); lt += 1 / 100; }
  return {
    update(dt) {
      t += dt;
      const want = libT(t);
      while (lt < want - 1e-6) { const s = Math.min(1 / 100, want - lt); inner.update(s); lt += s; }
    },
    drawBack(p) { if (inner.drawBack) inner.drawBack(p); },
    draw(p) { inner.draw(p); },
  };
}
