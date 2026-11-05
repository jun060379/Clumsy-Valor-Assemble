// Luce's holy orb, the spear's first form as it curves in: a white core in a gold shell, a thin ring orbiting it on a
// tilt, a cross of light breathing through it, two motes circling. Loops; the game draws its own fading wake behind.
import { WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Luce orb",
  desc: "A white core in a gold shell, a tilted ring orbiting it, a breathing cross of light, two circling motes.",
  tags: ["holy", "projectile", "orb", "loop"],
  size: [40, 40],
  origin: [20, 20],
  duration: 0.32,
  loop: true,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a"), G2 = hex("#d89a3a"), G3 = hex("#a8742a");

export function draw(p, t) {
  const ph = (t / 0.32) * Math.PI * 2, br = 0.5 + 0.5 * Math.sin(ph * 2);
  p.glow(0, 0, 14, G1, 0.3 + 0.1 * br);
  // the back half of the ring
  const ring = (front) => {
    for (let i = 0; i < 48; i++) {
      const a = (i / 48) * Math.PI * 2 + ph, x = Math.cos(a) * 9, y = Math.sin(a) * 3.2;
      const rx = x * 0.94 - y * 0.34, ry = x * 0.34 + y * 0.94;
      if ((Math.sin(a) > 0) !== front) continue;
      p.px(rx, ry, front ? (Math.cos(a - 0.6) > 0.8 ? WHITE : G1) : G3);
    }
  };
  ring(false);
  // the shell and the core
  p.shade(-6, -6, 6, 6, (x, y, out) => {
    const d = Math.hypot(x, y);
    if (d > 5.2) return;
    out.c = d < 2.2 ? WHITE : d < 3.4 ? W1 : d < 4.4 ? G0 : x + y < 0 ? G1 : G2;
  });
  // the cross of light breathing through it
  const L = 6 + Math.round(br * 3);
  for (let i = 3; i <= L; i++) { const c = i < L - 1 ? W1 : G0; p.px(i, 0, c); p.px(-i, 0, c); p.px(0, i, c); p.px(0, -i, c); }
  ring(true);
  // two motes circling wide
  for (let j = 0; j < 2; j++) {
    const a = -ph * 1.5 + j * Math.PI;
    p.px(Math.cos(a) * 12, Math.sin(a) * 12, j ? G0 : WHITE);
  }
}
